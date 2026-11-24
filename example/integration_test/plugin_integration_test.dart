import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';

const _runRegtest = bool.fromEnvironment('RGB_SDK_FLUTTER_REGTEST');
const _runFundedRegtest = bool.fromEnvironment(
  'RGB_SDK_FLUTTER_FUNDED_REGTEST',
);
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
const _password = 'password';

String get _host => Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nativeArtifactInfo test', (WidgetTester tester) async {
    const plugin = RgbSdkFlutter();
    final info = await plugin.nativeArtifactInfo();

    expect(info.rlnVersion, RgbSdkFlutter.rlnVersion);
    expect(
      info.reactNativeParityVersion,
      RgbSdkFlutter.reactNativeParityVersion,
    );
    expect(info.nativeArtifact.isNotEmpty, true);
  });

  testWidgets('regtest lifecycle and bitcoin read smoke', (
    WidgetTester tester,
  ) async {
    if (!_runRegtest) {
      markTestSkipped('Set --dart-define=RGB_SDK_FLUTTER_REGTEST=true to run.');
      return;
    }

    final client = RlnClient();
    final storageDir = await Directory.systemTemp.createTemp(
      'rgb-sdk-flutter-regtest-',
    );
    int? nodeId;
    var completed = false;

    try {
      nodeId = await client.createNode(
        storageDirPath: storageDir.path,
        daemonListeningPort: 34011,
        ldkPeerListeningPort: 34012,
        network: 'regtest',
        maxMediaUploadSizeMb: 5,
      );
      final pubkey = await client.initNode(nodeId: nodeId, password: _password);
      expect(pubkey, isNotEmpty);

      await client.unlockNode(
        nodeId: nodeId,
        password: _password,
        bitcoindRpcUsername: 'user',
        bitcoindRpcPassword: 'password',
        bitcoindRpcHost: _host,
        bitcoindRpcPort: _bitcoindRpcPort,
        indexerUrl: '$_host:$_electrsPort',
        proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
      );

      await client.sync(nodeId);

      final network = await client.networkInfo(nodeId);
      expect(network['network'].toString().toLowerCase(), contains('regtest'));
      expect(network['height'], greaterThanOrEqualTo(103));

      final nodeInfo = await client.nodeInfo(nodeId);
      expect(nodeInfo['pubkey'], isNotEmpty);
      expect(nodeInfo['accountXpubVanilla'], isNotEmpty);
      expect(nodeInfo['accountXpubColored'], isNotEmpty);

      final address = await client.address(nodeId);
      expect(address['address'], startsWith('bcrt'));

      final balance = await client.btcBalance(nodeId: nodeId, skipSync: true);
      expect(balance['vanilla'], isA<Map<Object?, Object?>>());
      expect(balance['colored'], isA<Map<Object?, Object?>>());

      final peers = await client.listPeers(nodeId);
      final channels = await client.listChannels(nodeId);
      final payments = await client.listPayments(nodeId);
      expect(peers, isEmpty);
      expect(channels, isEmpty);
      expect(payments, isEmpty);

      final indexer = await client.checkIndexerUrl(
        nodeId: nodeId,
        indexerUrl: '$_host:$_electrsPort',
      );
      expect(indexer['indexerProtocol'], isNotEmpty);

      await client.checkProxyEndpoint(
        nodeId: nodeId,
        proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
      );

      final assets = await client.listAssets(nodeId: nodeId);
      expect(assets['bfa'], isA<List<Object?>>());
      expect(await client.bfaCapabilities(), {
        'burn': true,
        'consignment': true,
        'bfa': true,
      });
      expect(assets['nia'], isA<List<Object?>>());
      expect(assets['uda'], isA<List<Object?>>());
      expect(assets['cfa'], isA<List<Object?>>());
      expect(assets['ifa'], isA<List<Object?>>());

      await client.refreshTransfers(nodeId: nodeId, skipSync: true);

      final failed = await client.failTransfers(
        nodeId: nodeId,
        batchTransferIdx: null,
        noAssetOnly: true,
        skipSync: true,
      );
      expect(failed['transfersChanged'], isA<bool>());
      completed = true;
    } finally {
      final cleanupFailures = <String>[];
      final id = nodeId;
      if (id != null) {
        await _recordCleanup(
          cleanupFailures,
          'low-level shutdown',
          () => client.shutdown(id),
        );
        await _recordCleanup(
          cleanupFailures,
          'low-level destroy',
          () => client.destroyNode(id),
        );
      }
      await _deleteForCleanup(storageDir, cleanupFailures);
      _reportCleanupFailures(cleanupFailures);
      if (completed && cleanupFailures.isNotEmpty) {
        fail('Low-level regtest cleanup failed: ${cleanupFailures.join('; ')}');
      }
    }
  });

  testWidgets('regtest UtexoWallet facade smoke', (WidgetTester tester) async {
    if (!_runRegtest) {
      markTestSkipped('Set --dart-define=RGB_SDK_FLUTTER_REGTEST=true to run.');
      return;
    }

    final storageDir = await Directory.systemTemp.createTemp(
      'rgb-sdk-flutter-wallet-regtest-',
    );
    final wallet = UtexoWallet.rln(
      config: UtexoWalletConfig(
        storageDirPath: storageDir.path,
        daemonListeningPort: 34021,
        ldkPeerListeningPort: 34022,
        network: 'regtest',
        maxMediaUploadSizeMb: 5,
      ),
    );

    var completed = false;
    try {
      await wallet.init(password: _password);
      expect(wallet.isInitialized, true);

      await wallet.unlock(
        password: _password,
        config: UtexoUnlockConfig(
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'password',
          bitcoindRpcHost: _host,
          bitcoindRpcPort: _bitcoindRpcPort,
          indexerUrl: '$_host:$_electrsPort',
          proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
        ),
      );
      expect(wallet.isUnlocked, true);

      await wallet.syncWallet();
      expect(await wallet.getAddress(), startsWith('bcrt'));

      final balance = await wallet.getBtcBalance();
      expect(balance.vanilla.settled, greaterThanOrEqualTo(0));
      expect(balance.colored.settled, greaterThanOrEqualTo(0));

      final assets = await wallet.listAssets();
      expect(assets.bfa, isEmpty);
      final bfa = await wallet.getBfaCapabilities();
      expect(bfa.bfa, true);
      expect(bfa.consignment, true);
      expect(assets.nia, isEmpty);
      expect(assets.uda, isEmpty);
      expect(assets.cfa, isEmpty);
      expect(assets.ifa, isEmpty);

      await wallet.refreshWallet();
      expect(
        await wallet.failTransfers(noAssetOnly: true, skipSync: true),
        isA<bool>(),
      );

      await wallet.shutdown();
      expect(wallet.isUnlocked, false);

      await wallet.reinit(
        password: _password,
        unlockConfig: UtexoUnlockConfig(
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'password',
          bitcoindRpcHost: _host,
          bitcoindRpcPort: _bitcoindRpcPort,
          indexerUrl: '$_host:$_electrsPort',
          proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
        ),
      );
      expect(wallet.isInitialized, true);
      expect(wallet.isUnlocked, true);
      await wallet.syncWallet();
      expect(await wallet.getAddress(), startsWith('bcrt'));
      completed = true;
    } finally {
      final cleanupFailures = <String>[];
      await _recordCleanup(
        cleanupFailures,
        'wallet destroy',
        () => wallet.destroy(),
      );
      await _deleteForCleanup(storageDir, cleanupFailures);
      _reportCleanupFailures(cleanupFailures);
      if (completed && cleanupFailures.isNotEmpty) {
        fail('Wallet regtest cleanup failed: ${cleanupFailures.join('; ')}');
      }
    }
  });
  testWidgets('funded regtest RGB send smoke', (WidgetTester tester) async {
    if (!_runFundedRegtest) {
      markTestSkipped(
        'Run tool/regtest/flutter_funded_smoke.sh to enable host funding.',
      );
      return;
    }

    final fixtureA = await _makeRegtestWallet('a', 34031, 34032);
    final fixtureB = await _makeRegtestWallet('b', 34033, 34034);
    final walletA = fixtureA.wallet;
    final walletB = fixtureB.wallet;

    var completed = false;
    try {
      await _startWallet(walletA);
      await _startWallet(walletB);

      _step('fund wallet A');
      _requestFunding(await walletA.getAddress(), '0.03');
      _step('fund wallet B');
      _requestFunding(await walletB.getAddress(), '0.02');
      _step('wait wallet A spendable');
      await _waitForSpendable(walletA, 1, label: 'wallet A');
      _step('wait wallet B spendable');
      await _waitForSpendable(walletB, 1, label: 'wallet B');

      _step('send and confirm Bitcoin');
      final bitcoinTxid = await walletA.sendBtc(
        amount: 20000,
        address: await walletB.getAddress(),
      );
      expect(bitcoinTxid, matches(RegExp(r'^[0-9a-f]{64}$')));
      await _mineAndWait(walletA, blocks: 1);
      await _waitForConfirmedBitcoinTransfer(walletA, bitcoinTxid);
      final receivedBitcoin = await _waitForConfirmedBitcoinTransfer(
        walletB,
        bitcoinTxid,
      );
      expect(receivedBitcoin.received, 20000);

      _step('create wallet A utxos');
      await walletA.createUtxos(num: 10, size: 100000, feeRate: 1);
      _step('create wallet B utxos');
      await walletB.createUtxos(num: 10, size: 100000, feeRate: 1);
      _step('confirm created utxos');
      await _mineAndWait(walletA, blocks: 1);
      await walletB.syncWallet();

      _step('issue NIA asset');
      final issued = await walletA.issueAssetNia(
        ticker: 'TST',
        name: 'Test Asset',
        precision: 0,
        amounts: const <int>[1000],
      );
      expect(issued.assetId, isNotEmpty);

      _step('blind receive asset');
      final invoice = await walletB.blindReceive(const RgbInvoiceRequest());
      _step('send RGB asset');
      final send = await walletA.onchainSend(
        RgbSendRequest(
          invoice: invoice.invoice,
          assetId: issued.assetId,
          amount: 100,
          donation: true,
          skipSync: false,
        ),
      );
      expect(send.txid, isNotEmpty);

      _step('confirm RGB transfer');
      await _mineAndWait(walletA, blocks: 1);
      _step('wait wallet B asset spendable');
      await _waitForAssetSpendable(
        walletB,
        issued.assetId,
        100,
        label: 'wallet B',
      );
      final walletBTransfers = await walletB.listTransfers(
        assetId: issued.assetId,
      );
      expect(walletBTransfers, isNotEmpty);
      expect(
        walletBTransfers.any(
          (transfer) => transfer.assignments.any(
            (assignment) => assignment.amount == BigInt.from(100),
          ),
        ),
        true,
      );
      await _waitForAssetSpendable(
        walletA,
        issued.assetId,
        900,
        label: 'wallet A',
      );

      // Native outgoing allocations can describe the 900-unit change. The
      // normalized history must describe this recipient's 100-unit payment.
      final outgoing = (await walletA.listTransfers(assetId: issued.assetId))
          .singleWhere(
            (transfer) => transfer.txid == send.txid && transfer.kind == 'Send',
          );
      final incoming = walletBTransfers.singleWhere(
        (transfer) =>
            transfer.txid == send.txid && transfer.kind == 'ReceiveBlind',
      );
      expect(outgoing.amountBaseUnits, '100');
      expect(outgoing.amount, BigInt.from(100));
      expect(incoming.amountBaseUnits, '100');
      expect(incoming.amount, BigInt.from(100));

      _step('read wallet A asset balance');
      final walletABalance = await walletA.getAssetBalance(issued.assetId);
      expect(walletABalance.spendable, lessThanOrEqualTo(BigInt.from(900)));

      _step('read node info');
      final walletAInfo = await walletA.getNodeInfo();
      final walletBInfo = await walletB.getNodeInfo();
      final walletAPeer = '${walletAInfo.pubkey}@127.0.0.1:34032';
      final walletBPeer = '${walletBInfo.pubkey}@127.0.0.1:34034';
      _step('connect wallet A to wallet B');
      await walletA.connectPeer(walletBPeer);
      await _waitForPeer(walletA, walletBInfo.pubkey);
      _step('connect wallet B to wallet A');
      await walletB.connectPeer(walletAPeer);
      await _waitForPeer(walletB, walletAInfo.pubkey);

      _step('open RGB channel');
      final opened = await walletA.openChannel(
        peerPubkey: walletBPeer,
        capacitySat: 500000,
        pushMsat: 0,
        isPublic: false,
        withAnchors: true,
        assetId: issued.assetId,
        assetLocalAmount: 200,
      );
      expect(opened.temporaryChannelId, isNotEmpty);

      _step('confirm RGB channel');
      await _mineAndWait(walletA, blocks: 6);
      _step('wait usable RGB channel');
      await _waitForUsableChannelPair(walletA, walletB, issued.assetId);

      _step('create RGB lightning invoice');
      final lnInvoice = await walletB.createLightningInvoice(
        amountSats: 3000,
        asset: LightningAsset(assetId: issued.assetId, amount: 50),
      );
      expect(lnInvoice.lnInvoice, isNotEmpty);

      _step('pay RGB lightning invoice');
      final payment = await walletA.payLightningInvoice(
        lnInvoice: lnInvoice.lnInvoice,
      );
      expect(payment.status, isNotEmpty);

      _step('wait RGB lightning invoice final');
      await _waitForInvoiceFinal(walletB, lnInvoice.lnInvoice);
      completed = true;
    } finally {
      final cleanupFailures = <String>[];
      await fixtureA.cleanup(cleanupFailures);
      await fixtureB.cleanup(cleanupFailures);
      _reportCleanupFailures(cleanupFailures);
      if (completed && cleanupFailures.isNotEmpty) {
        fail('Funded regtest cleanup failed: ${cleanupFailures.join('; ')}');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}

class _RegtestWalletFixture {
  _RegtestWalletFixture({required this.wallet, required this.storageDir});

  final UtexoWallet wallet;
  final Directory storageDir;

  Future<void> cleanup(List<String> failures) async {
    await _recordCleanup(failures, '${storageDir.path} wallet destroy', () {
      return wallet.destroy();
    });
    await _deleteForCleanup(storageDir, failures);
  }
}

Future<_RegtestWalletFixture> _makeRegtestWallet(
  String label,
  int daemonPort,
  int peerPort,
) async {
  final storageDir = await Directory.systemTemp.createTemp(
    'rgb-sdk-flutter-funded-$label-',
  );
  return _RegtestWalletFixture(
    storageDir: storageDir,
    wallet: UtexoWallet.rln(
      config: UtexoWalletConfig(
        storageDirPath: storageDir.path,
        daemonListeningPort: daemonPort,
        ldkPeerListeningPort: peerPort,
        network: 'regtest',
        maxMediaUploadSizeMb: 5,
      ),
    ),
  );
}

Future<void> _recordCleanup(
  List<String> failures,
  String label,
  Future<void> Function() cleanup,
) async {
  try {
    await cleanup();
  } catch (error) {
    failures.add('$label: $error');
  }
}

Future<void> _deleteForCleanup(
  Directory directory,
  List<String> failures,
) async {
  try {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    if (await directory.exists()) {
      failures.add('${directory.path}: directory still exists after cleanup');
    }
  } catch (error) {
    failures.add('${directory.path}: $error');
  }
}

void _reportCleanupFailures(List<String> failures) {
  for (final failure in failures) {
    debugPrintSynchronously('RGB_SDK_FLUTTER_CLEANUP_ERROR $failure');
  }
}

Future<void> _startWallet(UtexoWallet wallet) async {
  await wallet.init(password: _password);
  await wallet.unlock(
    password: _password,
    config: UtexoUnlockConfig(
      bitcoindRpcUsername: 'user',
      bitcoindRpcPassword: 'password',
      bitcoindRpcHost: _host,
      bitcoindRpcPort: _bitcoindRpcPort,
      indexerUrl: '$_host:$_electrsPort',
      proxyEndpoint: 'rpc://$_host:$_rgbProxyPort/json-rpc',
    ),
  );
  await wallet.syncWallet();
}

void _requestFunding(String address, String amountBtc) {
  debugPrintSynchronously(
    'RGB_SDK_FLUTTER_HOST FUND address=$address amount=$amountBtc',
  );
}

void _step(String label) {
  debugPrintSynchronously('RGB_SDK_FLUTTER_STEP $label');
}

void _requestMine(int blocks) {
  debugPrintSynchronously('RGB_SDK_FLUTTER_HOST MINE blocks=$blocks');
}

Future<void> _mineAndWait(UtexoWallet wallet, {required int blocks}) async {
  final startHeight = (await wallet.getNetworkInfo()).height;
  _requestMine(blocks);
  await _waitForHeight(wallet, startHeight + blocks);
}

Future<void> _waitForHeight(UtexoWallet wallet, int targetHeight) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await wallet.syncWallet();
    final height = (await wallet.getNetworkInfo()).height;
    if (height >= targetHeight) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Regtest height did not reach $targetHeight.');
}

Future<void> _waitForSpendable(
  UtexoWallet wallet,
  int minSat, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await wallet.syncWallet();
    final balance = await wallet.getBtcBalance();
    if (balance.vanilla.spendable >= minSat) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label did not reach $minSat spendable sats.');
}

Future<CoreTransaction> _waitForConfirmedBitcoinTransfer(
  UtexoWallet wallet,
  String txid,
) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await wallet.syncWallet();
    final transactions = await wallet.listTransactionsByTxid(txid);
    final match = transactions.where(
      (transaction) =>
          transaction.txid == txid && transaction.confirmationTime != null,
    );
    if (match.isNotEmpty) return match.single;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError(
    'Bitcoin transfer was not confirmed within the test deadline.',
  );
}

Future<void> _waitForAssetSpendable(
  UtexoWallet wallet,
  String assetId,
  int minAmount, {
  required String label,
}) async {
  for (var attempt = 0; attempt < 90; attempt++) {
    await wallet.refreshWallet();
    final balance = await wallet.getAssetBalance(assetId);
    if (balance.spendable >= BigInt.from(minAmount)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$label did not reach $minAmount spendable units for $assetId.');
}

Future<void> _waitForPeer(UtexoWallet wallet, String pubkey) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final peers = await wallet.listPeers();
    if (peers.any((peer) => peer.pubkey == pubkey)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Peer $pubkey did not connect.');
}

Future<void> _waitForUsableChannelPair(
  UtexoWallet walletA,
  UtexoWallet walletB,
  String assetId,
) async {
  var lastA = const <LightningChannel>[];
  var lastB = const <LightningChannel>[];
  for (var attempt = 0; attempt < 90; attempt++) {
    await walletA.syncWallet();
    await walletB.syncWallet();
    lastA = await walletA.listChannels();
    lastB = await walletB.listChannels();
    if (_hasUsableRgbChannel(lastA, assetId) &&
        _hasUsableRgbChannel(lastB, assetId)) {
      return;
    }
    if (attempt % 5 == 4) {
      await _mineAndWait(walletA, blocks: 1);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail(
    'Wallets did not reach a usable RGB channel for $assetId. '
    'walletA=${_channelSummary(lastA)} walletB=${_channelSummary(lastB)}',
  );
}

bool _hasUsableRgbChannel(List<LightningChannel> channels, String assetId) {
  return channels.any(
    (channel) =>
        channel.assetId == assetId &&
        (channel.ready || channel.isUsable == true),
  );
}

String _channelSummary(List<LightningChannel> channels) {
  return channels
      .map(
        (channel) =>
            '{id=${channel.channelId}, status=${channel.status}, '
            'ready=${channel.ready}, usable=${channel.isUsable}, '
            'asset=${channel.assetId}, funding=${channel.fundingTxid}}',
      )
      .join(', ');
}

Future<void> _waitForInvoiceFinal(UtexoWallet wallet, String invoice) async {
  for (var attempt = 0; attempt < 90; attempt++) {
    final status = (await wallet.invoiceStatus(invoice)).toLowerCase();
    if (status == 'succeeded') return;
    if (status == 'failed' || status == 'expired' || status == 'cancelled') {
      fail('Invoice reached terminal failure state: $status.');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Invoice did not reach succeeded state.');
}
