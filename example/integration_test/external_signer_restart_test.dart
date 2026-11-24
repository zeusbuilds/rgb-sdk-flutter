import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';

const _configuredPhase = String.fromEnvironment(
  'RGB_SDK_FLUTTER_RESTART_PHASE',
);
const _runId = String.fromEnvironment('RGB_SDK_FLUTTER_RESTART_RUN_ID');
const _bitcoindRpcPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_BITCOIND_RPC_PORT',
  defaultValue: 18444,
);
const _electrsPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_ELECTRS_PORT',
  defaultValue: 50002,
);
const _rgbProxyPort = int.fromEnvironment(
  'RGB_SDK_FLUTTER_RGB_PROXY_PORT',
  defaultValue: 3013,
);
const _deviceSeed = String.fromEnvironment(
  'RGB_SDK_FLUTTER_RESTART_DEVICE_SEED_HEX',
);
const _hostPassword = 'Restart-Host-Password-2026!';
const _deviceDaemonPort = 34131;
const _devicePeerPort = 34132;
const _hostDaemonPort = 34133;
const _hostPeerPort = 34134;
const _paymentAmountMsat = 3000000;
const _virtualChannelCapacitySat = 100000;
const _virtualChannelPushMsat = 30000000;
const _virtualOpenMode = 'trusted_no_broadcast';

String get _host => Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disk-backed external signer survives process restart and pays again',
    (WidgetTester tester) async {
      if (_configuredPhase != 'prepare' &&
          _configuredPhase != 'verify' &&
          _configuredPhase != 'auto') {
        markTestSkipped(
          'Run tool/test_external_signer_restart.sh to execute both phases.',
        );
        return;
      }
      if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(_runId)) {
        fail('RGB_SDK_FLUTTER_RESTART_RUN_ID must be non-empty and safe.');
      }
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(_deviceSeed)) {
        fail(
          'RGB_SDK_FLUTTER_RESTART_DEVICE_SEED_HEX must be exactly '
          '32 lowercase hexadecimal bytes.',
        );
      }

      final root = Directory(
        '${Directory.systemTemp.path}/rgb-sdk-flutter-restart-$_runId',
      );
      final stateFile = File('${root.path}/restart-state.json');
      final resultFile = File(
        '${Directory.systemTemp.path}/'
        'rgb-sdk-flutter-restart-result-$_runId.json',
      );
      final phase = _configuredPhase == 'auto'
          ? (await stateFile.exists() ? 'verify' : 'prepare')
          : _configuredPhase;
      _step('selected $phase phase');

      try {
        if (phase == 'prepare') {
          if (await resultFile.exists()) await resultFile.delete();
          await _prepareRestartFixture(root, stateFile);
          await _writeResult(resultFile, phase: phase, status: 'prepared');
        } else {
          await _verifyRestartFixture(root, stateFile);
          await _writeResult(resultFile, phase: phase, status: 'passed');
        }
      } catch (error, stackTrace) {
        await _writeResultSafely(
          resultFile,
          phase: phase,
          status: 'failed',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _prepareRestartFixture(Directory root, File stateFile) async {
  if (await root.exists()) {
    await root.delete(recursive: true);
  }

  final device = _externalSignerWallet(
    storageDirPath: '${root.path}/device',
    seedHex: _deviceSeed,
    daemonPort: _deviceDaemonPort,
    peerPort: _devicePeerPort,
  );
  UtexoWallet? host;
  var prepared = false;

  try {
    _step('initialize durable external-signer device');
    await _initialize(device);
    final deviceInfo = await device.getNodeInfo();

    final initializedHost = _passwordWallet(
      storageDirPath: '${root.path}/host',
      daemonPort: _hostDaemonPort,
      peerPort: _hostPeerPort,
      virtualPeerPubkeys: <String>[deviceInfo.pubkey],
    );
    host = initializedHost;
    _step('initialize password-backed virtual-channel host');
    await _initialize(initializedHost);
    final hostInfo = await initializedHost.getNodeInfo();

    _step('fund external-signer device');
    await _requestFunding(await device.getAddress(), '0.003');
    await _waitForSpendable(device, 200000, label: 'external-signer device');

    final hostPeer = '${hostInfo.pubkey}@127.0.0.1:$_hostPeerPort';
    _step('open trusted virtual BTC channel');
    await _ensurePeer(device, hostInfo.pubkey, hostPeer);
    final opened = await device.openChannel(
      peerPubkey: hostPeer,
      capacitySat: _virtualChannelCapacitySat,
      pushMsat: _virtualChannelPushMsat,
      isPublic: false,
      withAnchors: true,
      virtualOpenMode: _virtualOpenMode,
    );
    final channelId = await _waitForUsableChannelPair(
      device: device,
      host: initializedHost,
      devicePeerPubkey: hostInfo.pubkey,
      hostPeerPubkey: deviceInfo.pubkey,
    );

    _step('pay device to host before process restart');
    await _payLightningInvoice(
      payer: device,
      payee: initializedHost,
      label: 'fresh device->host',
    );
    _step('pay host to device before process restart');
    await _payLightningInvoice(
      payer: initializedHost,
      payee: device,
      label: 'fresh host->device',
    );

    await stateFile.parent.create(recursive: true);
    await stateFile.writeAsString(
      jsonEncode(<String, Object>{
        'schemaVersion': 2,
        'runId': _runId,
        'devicePubkey': deviceInfo.pubkey,
        'hostPubkey': hostInfo.pubkey,
        'temporaryChannelId': opened.temporaryChannelId,
        'channelId': channelId,
        'virtualOpenMode': _virtualOpenMode,
      }),
      flush: true,
    );

    _step('shutdown both nodes before process boundary');
    await device.shutdown();
    await initializedHost.shutdown();
    prepared = true;
  } finally {
    if (!prepared) {
      final wallets = <String, UtexoWallet>{'device': device};
      if (host != null) wallets['host'] = host;
      final cleanupFailures = await _cleanupWallets(wallets);
      await _deleteForCleanup(root, cleanupFailures);
      _reportCleanupFailures(cleanupFailures);
    }
  }
}

Future<void> _verifyRestartFixture(Directory root, File stateFile) async {
  if (!await stateFile.exists()) {
    fail(
      'Restart fixture is absent. Phase prepare did not persist app data at '
      '${stateFile.path}.',
    );
  }
  final state = jsonDecode(await stateFile.readAsString());
  if (state is! Map<String, Object?> ||
      state['schemaVersion'] != 2 ||
      state['runId'] != _runId) {
    fail('Restart fixture is malformed or belongs to another run.');
  }
  final expectedDevicePubkey = state['devicePubkey'];
  final expectedHostPubkey = state['hostPubkey'];
  final expectedTemporaryChannelId = state['temporaryChannelId'];
  final expectedChannelId = state['channelId'];
  if (expectedDevicePubkey is! String ||
      expectedDevicePubkey.isEmpty ||
      expectedHostPubkey is! String ||
      expectedHostPubkey.isEmpty ||
      expectedTemporaryChannelId is! String ||
      expectedTemporaryChannelId.isEmpty ||
      expectedChannelId is! String ||
      expectedChannelId.isEmpty ||
      state['virtualOpenMode'] != _virtualOpenMode) {
    fail('Restart fixture is missing required identities or channel state.');
  }

  final device = _externalSignerWallet(
    storageDirPath: '${root.path}/device',
    seedHex: _deviceSeed,
    daemonPort: _deviceDaemonPort,
    peerPort: _devicePeerPort,
  );
  final host = _passwordWallet(
    storageDirPath: '${root.path}/host',
    daemonPort: _hostDaemonPort,
    peerPort: _hostPeerPort,
    virtualPeerPubkeys: <String>[expectedDevicePubkey],
  );
  var verificationCompleted = false;

  try {
    _step('cold reinit password host and external-signer device');
    await _reinitialize(host, password: _hostPassword);
    await _reinitialize(device);

    final hostInfo = await host.getNodeInfo();
    final deviceInfo = await device.getNodeInfo();
    expect(hostInfo.pubkey, expectedHostPubkey);
    expect(deviceInfo.pubkey, expectedDevicePubkey);

    final hostPeer = '${hostInfo.pubkey}@127.0.0.1:$_hostPeerPort';
    await _ensurePeer(device, hostInfo.pubkey, hostPeer);
    final restoredChannelId = await _waitForUsableChannelPair(
      device: device,
      host: host,
      devicePeerPubkey: hostInfo.pubkey,
      hostPeerPubkey: deviceInfo.pubkey,
    );
    expect(restoredChannelId, expectedChannelId);

    _step('pay device to host after process restart');
    await _payLightningInvoice(
      payer: device,
      payee: host,
      label: 'restored device->host',
    );
    _step('pay host to device after process restart');
    await _payLightningInvoice(
      payer: host,
      payee: device,
      label: 'restored host->device',
    );
    verificationCompleted = true;
  } finally {
    final cleanupFailures = await _cleanupWallets(<String, UtexoWallet>{
      'device': device,
      'host': host,
    });
    await _deleteForCleanup(root, cleanupFailures);
    _reportCleanupFailures(cleanupFailures);
    if (verificationCompleted && cleanupFailures.isNotEmpty) {
      fail(
        'Restart verification cleanup failed: ${cleanupFailures.join('; ')}',
      );
    }
  }
}

UtexoWallet _externalSignerWallet({
  required String storageDirPath,
  required String seedHex,
  required int daemonPort,
  required int peerPort,
}) {
  return UtexoWallet.rln(
    config: UtexoWalletConfig(
      storageDirPath: storageDirPath,
      daemonListeningPort: daemonPort,
      ldkPeerListeningPort: peerPort,
      network: 'regtest',
      maxMediaUploadSizeMb: 5,
      enableVirtualChannelsV0: true,
    ),
    signer: NativeExternalRlnSigner(
      keys: RlnKeyMaterial.seedHex(seedHex),
      network: 'regtest',
      permissivePolicy: true,
    ),
  );
}

UtexoWallet _passwordWallet({
  required String storageDirPath,
  required int daemonPort,
  required int peerPort,
  required List<String> virtualPeerPubkeys,
}) {
  return UtexoWallet.rln(
    config: UtexoWalletConfig(
      storageDirPath: storageDirPath,
      daemonListeningPort: daemonPort,
      ldkPeerListeningPort: peerPort,
      network: 'regtest',
      maxMediaUploadSizeMb: 5,
      enableVirtualChannelsV0: true,
      virtualPeerPubkeys: virtualPeerPubkeys,
    ),
    signer: PasswordRlnSigner(password: _hostPassword),
  );
}

UtexoUnlockConfig _unlockConfig() {
  return UtexoUnlockConfig(
    bitcoindRpcUsername: 'user',
    bitcoindRpcPassword: 'password',
    bitcoindRpcHost: _host,
    bitcoindRpcPort: _bitcoindRpcPort,
    indexerUrl: '$_host:$_electrsPort',
    proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
  );
}

Future<void> _initialize(UtexoWallet wallet) async {
  await wallet.init();
  await wallet.unlock(config: _unlockConfig());
  await wallet.syncWallet();
}

Future<void> _reinitialize(UtexoWallet wallet, {String? password}) async {
  await wallet.reinit(password: password, unlockConfig: _unlockConfig());
  await wallet.syncWallet();
}

Future<void> _requestFunding(String address, String amountBtc) async {
  debugPrintSynchronously(
    'RGB_SDK_FLUTTER_HOST FUND address=$address amount=$amountBtc',
  );
  final commandFile = File(
    '${Directory.systemTemp.path}/'
    'rgb-sdk-flutter-host-command-$_runId.json',
  );
  final temporaryCommandFile = File('${commandFile.path}.tmp');
  await temporaryCommandFile.writeAsString(
    jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'runId': _runId,
      'command': 'fund',
      'address': address,
      'amountBtc': amountBtc,
    }),
    flush: true,
  );
  if (await commandFile.exists()) await commandFile.delete();
  await temporaryCommandFile.rename(commandFile.path);
}

void _step(String label) {
  debugPrintSynchronously('RGB_SDK_FLUTTER_STEP $label');
}

Future<void> _waitForSpendable(
  UtexoWallet wallet,
  int minSat, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 90; attempt++) {
    await wallet.syncWallet();
    if ((await wallet.getBtcBalance()).vanilla.spendable >= minSat) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label did not reach $minSat spendable sats.');
}

Future<void> _ensurePeer(
  UtexoWallet wallet,
  String pubkey,
  String peerUri,
) async {
  if ((await wallet.listPeers()).any((peer) => peer.pubkey == pubkey)) return;
  Object? lastError;
  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      await wallet.connectPeer(peerUri);
      lastError = null;
    } catch (error) {
      lastError = error;
    }
    if ((await wallet.listPeers()).any((peer) => peer.pubkey == pubkey)) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('Peer $pubkey did not connect. Last error: $lastError');
}

Future<String> _waitForUsableChannelPair({
  required UtexoWallet device,
  required UtexoWallet host,
  required String devicePeerPubkey,
  required String hostPeerPubkey,
}) async {
  var lastDevice = const <LightningChannel>[];
  var lastHost = const <LightningChannel>[];
  for (var attempt = 0; attempt < 120; attempt++) {
    lastDevice = await device.listChannels();
    lastHost = await host.listChannels();
    final deviceChannel = _usableVirtualChannel(
      lastDevice,
      devicePeerPubkey,
      requireVirtualMode: true,
    );
    final hostChannel = _usableVirtualChannel(
      lastHost,
      hostPeerPubkey,
      requireVirtualMode: false,
    );
    if (deviceChannel != null &&
        hostChannel != null &&
        deviceChannel.channelId == hostChannel.channelId &&
        deviceChannel.capacitySat == hostChannel.capacitySat &&
        deviceChannel.fundingTxid == hostChannel.fundingTxid) {
      return deviceChannel.channelId;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail(
    'Peers did not expose the same usable $_virtualOpenMode channel. '
    'device=${_channelSummary(lastDevice)} host=${_channelSummary(lastHost)}',
  );
}

LightningChannel? _usableVirtualChannel(
  List<LightningChannel> channels,
  String peerPubkey, {
  required bool requireVirtualMode,
}) {
  for (final channel in channels) {
    if (channel.peerPubkey == peerPubkey &&
        channel.ready &&
        channel.isUsable == true &&
        channel.assetId == null &&
        channel.capacitySat == _virtualChannelCapacitySat &&
        (requireVirtualMode
            ? channel.virtualOpenMode == _virtualOpenMode
            : channel.virtualOpenMode == null ||
                  channel.virtualOpenMode == _virtualOpenMode)) {
      return channel;
    }
  }
  return null;
}

String _channelSummary(List<LightningChannel> channels) {
  return channels
      .map(
        (channel) =>
            '{id=${channel.channelId}, peer=${channel.peerPubkey}, '
            'status=${channel.status}, ready=${channel.ready}, '
            'usable=${channel.isUsable}, asset=${channel.assetId}, '
            'virtualMode=${channel.virtualOpenMode}, '
            'funding=${channel.fundingTxid}}',
      )
      .join(', ');
}

Future<void> _payLightningInvoice({
  required UtexoWallet payer,
  required UtexoWallet payee,
  required String label,
}) async {
  final invoice = await payee.createRlnLightningInvoice(
    amtMsat: _paymentAmountMsat,
    expirySec: 900,
  );
  expect(invoice.invoice, isNotEmpty, reason: '$label invoice');
  final payment = await payer.payRlnLightningInvoice(invoice: invoice.invoice);
  final paymentHash = payment.paymentHash;
  if (paymentHash == null || paymentHash.isEmpty) {
    fail('$label did not return a payment hash (status=${payment.status}).');
  }
  await _waitForPaymentFinal(payer, paymentHash, label: '$label payer');
  await _waitForPaymentFinal(payee, paymentHash, label: '$label payee');
  await _waitForInvoiceFinal(payee, invoice.invoice, label: label);
}

Future<void> _waitForPaymentFinal(
  UtexoWallet wallet,
  String paymentHash, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    final payments = await wallet.listPayments();
    for (final payment in payments) {
      if (payment.paymentHash != paymentHash) continue;
      final status = payment.status.toLowerCase();
      if (status == 'succeeded') return;
      if (status == 'failed' || status == 'expired' || status == 'cancelled') {
        fail('$label payment reached terminal failure state: $status.');
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label payment $paymentHash did not reach succeeded state.');
}

Future<void> _waitForInvoiceFinal(
  UtexoWallet wallet,
  String invoice, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    final status = (await wallet.invoiceStatus(invoice)).toLowerCase();
    if (status == 'succeeded') return;
    if (status == 'failed' || status == 'expired' || status == 'cancelled') {
      fail('$label invoice reached terminal failure state: $status.');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label invoice did not reach succeeded state.');
}

Future<List<String>> _cleanupWallets(Map<String, UtexoWallet> wallets) async {
  final failures = <String>[];
  for (final entry in wallets.entries) {
    try {
      await entry.value.destroy();
    } catch (error) {
      failures.add('${entry.key}: $error');
    }
  }
  return failures;
}

Future<void> _deleteForCleanup(
  Directory directory,
  List<String> failures,
) async {
  try {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  } catch (error) {
    failures.add('fixture directory: $error');
  }
}

void _reportCleanupFailures(List<String> failures) {
  for (final failure in failures) {
    debugPrintSynchronously('RGB_SDK_FLUTTER_CLEANUP_ERROR $failure');
  }
}

Future<void> _writeResult(
  File resultFile, {
  required String phase,
  required String status,
  Object? error,
  StackTrace? stackTrace,
}) async {
  final temporaryResultFile = File('${resultFile.path}.tmp');
  await temporaryResultFile.writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 2,
      'runId': _runId,
      'phase': phase,
      'status': status,
      'platform': Platform.operatingSystem,
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    }),
    flush: true,
  );
  if (await resultFile.exists()) await resultFile.delete();
  await temporaryResultFile.rename(resultFile.path);
}

Future<void> _writeResultSafely(
  File resultFile, {
  required String phase,
  required String status,
  required Object error,
  required StackTrace stackTrace,
}) async {
  try {
    await _writeResult(
      resultFile,
      phase: phase,
      status: status,
      error: error,
      stackTrace: stackTrace,
    );
  } catch (resultError) {
    debugPrintSynchronously(
      'RGB_SDK_FLUTTER_RESULT_ERROR failed to persist result: $resultError',
    );
  }
}
