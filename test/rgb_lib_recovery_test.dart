import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _binding =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _cohort = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _publicKey =
    'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';
const _operation = 'cccccccccccccccccccccccccccccccc';
const _asset = 'rgb:A6k89KtR-e3oXqRP-uH3jUrz-LU_sYL3-hMZ0k3O-6u8DXbE';
const _txid =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _devProxy = 'rpcs://dev.rgb-proxy.utexo.com/json-rpc';

Map<String, Object?> _status(String requestJson, String phase) {
  final envelope = jsonDecode(requestJson) as Map<String, dynamic>;
  final request = envelope['request'] as Map<String, dynamic>;
  final withPlan = {'prepared', 'committing', 'accepted'}.contains(phase);
  return {
    'version': 1,
    'operationId': request['operationId'],
    'fingerprint': phase == 'absent' ? null : request['fingerprint'],
    'kind': phase == 'absent' ? null : request['kind'],
    'phase': phase,
    'txid': withPlan ? _txid : null,
    'batchTransferIndex': withPlan && request['kind'] == 'rgb' ? 9 : null,
    'failureCode': phase == 'rejected' ? 'cancelled' : null,
    'endAuthorized': {'committing', 'accepted'}.contains(phase),
  };
}

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  late List<MethodCall> calls;
  late FutureOr<Object?> Function(MethodCall) dispatch;
  var cohort = _cohort;
  var phase = 'absent';
  var invoiceExpiry = 2000000000;
  var capabilities = true;
  var dev = false;
  var devInvoiceEndpoints = const [_devProxy];
  String? devInvoiceAssetId = _asset;
  const fixedAssignment = {
    'type': 'Fungible',
    'amount': '18446744073709551615',
  };
  Map<String, String> devInvoiceAssignment = fixedAssignment;

  Object? reply(MethodCall call) => switch (call.method) {
    'getRuntimeInfo' => {
      'version': RgbLibRuntimeInfo.expectedVersion,
      'sourceRevision': RgbLibRuntimeInfo.expectedSourceRevision,
      'integrationTree': RgbLibRuntimeInfo.expectedIntegrationTree,
      'overlayPatchSha256': RgbLibRuntimeInfo.expectedOverlayPatchSha256,
      'sourceLockSha256': RgbLibRuntimeInfo.expectedSourceLockSha256,
      'sourceManifestSha256': RgbLibRuntimeInfo.expectedSourceManifestSha256,
      'bridgeVersion': RgbLibRuntimeInfo.expectedBridgeVersion,
      'nativeOverlay': 'flutter-bfa7-durable-v1',
      'bfa': true,
      'burn': true,
      'consignment': true,
      'contractRegistration': capabilities,
      'durableOnchainRecovery': capabilities,
      'supportsHostedDevSignet': dev,
    },
    'openWallet' => 'native-handle',
    'getWalletIdentity' => {
      'id': _binding,
      'network': dev ? 'utexo' : 'regtest',
      'masterFingerprint': 'a1b2c3d4',
      'recoveryCohort': cohort,
    },
    'closeWallet' || 'goOnline' => null,
    'decodeInvoice' => {
      'recipientId': 'native-witness-recipient',
      'recipientType': 'Witness',
      'assetSchema': 'Bfa',
      'assetId': dev ? devInvoiceAssetId : _asset,
      'assignment': dev ? devInvoiceAssignment : fixedAssignment,
      'assignmentName': null,
      'network': dev ? 'signet' : 'regtest',
      'expirationTimestamp': invoiceExpiry.toString(),
      'transportEndpoints': dev
          ? devInvoiceEndpoints
          : ['rpc://127.0.0.1:29300/json-rpc'],
      'publicKey': _publicKey,
      'encryption': 'Required',
      'unknownQueryParams': <Map<String, Object?>>[],
    },
    'getAssetMetadata' => {
      'assetSchema': 'Bfa',
      'initialSupply': '0',
      'maxSupply': '18446744073709551615',
      'knownCirculatingSupply': '0',
      'timestamp': '1',
      'name': 'Bridged USDT',
      'ticker': 'BUSDT',
      'precision': 6,
    },
    'prepareOnchainSend' ||
    'commitOnchainSend' ||
    'onchainSendStatus' ||
    'cancelOnchainSend' ||
    'revokeOnchainSend' => jsonEncode(
      _status(call.arguments['requestJson'] as String, phase),
    ),
    'onchainRecoveryState' => jsonEncode({
      'version': 1,
      'walletBinding': _binding,
      'cohort': cohort,
      'restoredSnapshot': false,
      'pending': <Map<String, Object?>>[],
    }),
    'importContract' => jsonEncode({
      'assetId': _asset,
      'alreadyImported': false,
      'metadata': {
        'assetSchema': 'Bfa',
        'name': 'Bridged USDT',
        'ticker': 'BUSDT',
        'precision': 6,
        'initialSupply': '0',
        'maxSupply': '18446744073709551615',
        'knownCirculatingSupply': '0',
      },
    }),
    _ => throw StateError('Unexpected native operation ${call.method}'),
  };

  Future<RgbLibWallet> wallet() async {
    final session = RgbLibWallet(
      params: RgbLibWalletParams(
        network: dev ? 'utexo' : 'regtest',
        storageDirPath: '/private/new-bfa7-wallet',
        allowUtexoDevSignet: dev,
      ),
      keys: RgbLibKeys.reader(() => 'test-only-key-source'),
    );
    await session.init();
    await session.unlock(
      RgbLibUnlockParams(
        indexerUrl: dev
            ? 'https://dev.esplora-01.mint.utexo.com'
            : 'tcp://127.0.0.1:29302',
        proxyEndpoint: dev ? _devProxy : 'rpc://127.0.0.1:29300/json-rpc',
        evmChains: dev
            ? const {
                '42161': RgbLibEvmChain(
                  rpcUrl: 'https://arb1.arbitrum.io/rpc',
                  minMintLockBlocks: 2,
                  maxMintLockBlocks: 7200,
                ),
              }
            : const {},
      ),
    );
    addTearDown(session.destroy);
    return session;
  }

  setUp(() {
    calls = [];
    cohort = _cohort;
    phase = 'absent';
    invoiceExpiry = 2000000000;
    capabilities = true;
    dev = false;
    devInvoiceEndpoints = const [_devProxy];
    devInvoiceAssetId = _asset;
    devInvoiceAssignment = fixedAssignment;
    dispatch = reply;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return dispatch(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  Future<RecoverableOnchainSendCommand> btc(RgbLibWallet session) =>
      session.createRecoverableBtcSendCommand(
        operationId: _operation,
        amount: 1500,
        address: 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn',
        feeRate: 2,
      );

  RgbLibWallet unopened({void Function()? readKey}) => RgbLibWallet(
    params: const RgbLibWalletParams(
      network: 'regtest',
      storageDirPath: '/private/existing-bfa7-wallet',
    ),
    keys: RgbLibKeys.reader(() {
      readKey?.call();
      return 'test-only-key-source';
    }),
  );

  test(
    'existing-only open requires wrapper capability before reading keys',
    () async {
      expect(
        (await RgbLibWallet.getRuntimeInfo()).supportsExistingOnlyOpen,
        isFalse,
      );
      for (final capability in [null, false]) {
        var reads = 0;
        dispatch = (call) {
          final value = reply(call);
          if (call.method != 'getRuntimeInfo') return value;
          return {
            ...value! as Map<String, Object?>,
            'supportsExistingOnlyOpen': ?capability,
          };
        };
        calls.clear();
        final session = unopened(readKey: () => reads++);
        await expectLater(
          session.openExisting(),
          throwsA(
            isA<RgbLibWalletException>().having(
              (error) => error.code,
              'code',
              'UNSUPPORTED_CAPABILITY',
            ),
          ),
        );
        expect(reads, 0);
        expect(calls.map((call) => call.method), ['getRuntimeInfo']);
        await session.destroy();
      }
    },
  );

  test(
    'malformed existing-only wrapper claims cannot reach keys or open',
    () async {
      for (final capability in [null, 'true', 1]) {
        var reads = 0;
        dispatch = (call) {
          final value = reply(call);
          return call.method == 'getRuntimeInfo'
              ? {
                  ...value! as Map<String, Object?>,
                  'supportsExistingOnlyOpen': capability,
                }
              : value;
        };
        calls.clear();
        final session = unopened(readKey: () => reads++);
        await expectLater(
          session.openExisting(),
          throwsA(isA<NativeProtocolException>()),
        );
        expect(reads, 0);
        expect(calls.map((call) => call.method), ['getRuntimeInfo']);
        await session.destroy();
      }
    },
  );

  test(
    'existing-only open forwards strict mode and never replaces a missing profile',
    () async {
      dispatch = (call) {
        final value = call.method == 'openWallet' ? null : reply(call);
        if (call.method == 'getRuntimeInfo') {
          return {
            ...value! as Map<String, Object?>,
            'supportsExistingOnlyOpen': true,
          };
        }
        if (call.method == 'openWallet') {
          expect((call.arguments as Map)['requireExisting'], isTrue);
          throw PlatformException(
            code: 'WALLET_STORAGE_MISSING',
            message: 'private path',
          );
        }
        return value;
      };
      final session = unopened();
      await expectLater(
        session.openExisting(),
        throwsA(
          isA<RgbLibWalletException>()
              .having((error) => error.code, 'code', 'WALLET_STORAGE_MISSING')
              .having(
                (error) => error.message.contains('private path'),
                'redacted',
                isFalse,
              ),
        ),
      );
      expect(calls.map((call) => call.method), [
        'getRuntimeInfo',
        'openWallet',
      ]);
      await session.destroy();
    },
  );

  test(
    'existing-only reopen preserves queue lifecycle and legacy open modes',
    () async {
      dispatch = (call) {
        final value = reply(call);
        return call.method == 'getRuntimeInfo'
            ? {
                ...value! as Map<String, Object?>,
                'supportsExistingOnlyOpen': true,
              }
            : value;
      };
      final session = unopened();
      await session.openExisting();
      expect(
        calls
            .singleWhere((call) => call.method == 'openWallet')
            .arguments['requireExisting'],
        isTrue,
      );
      final before = calls.length;
      await expectLater(
        session.openExisting(),
        throwsA(
          isA<RgbLibWalletException>().having(
            (error) => error.code,
            'code',
            'WALLET_CONFIG_MISMATCH',
          ),
        ),
      );
      expect(calls.length, before);
      await session.shutdown();
      calls.clear();
      await session.reinit();
      expect(
        calls
            .singleWhere((call) => call.method == 'openWallet')
            .arguments['requireExisting'],
        isFalse,
      );
      await session.destroy();
    },
  );

  test('fixed vectors remain canonical and preserve exact uint64 values', () {
    final document =
        jsonDecode(
              File(
                'test/fixtures/bfa7_recovery_vectors.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final row in document['vectors'] as List<dynamic>) {
      final vector = row as Map<String, dynamic>;
      final command = RecoverableOnchainSendCommand.fromJson(
        vector['requestJson'] as String,
      );
      expect(command.version, 3);
      expect(command.backend, 'RGB_L1');
      expect(command.recoveryCohort, _cohort);
      expect(command.fingerprint, vector['fingerprint']);
      expect(command.requestJson, vector['requestJson']);
      final altered = jsonDecode(command.requestJson) as Map<String, dynamic>;
      altered['recoveryCohort'] = 'f' * 32;
      expect(
        () => RecoverableOnchainSendCommand.fromJson(jsonEncode(altered)),
        throwsA(isA<WalletValidationException>()),
      );
    }
  });

  test(
    'Bitcoin factory matches the independently consumed native hash vector',
    () async {
      final command = await btc(await wallet());
      expect(
        command.fingerprint,
        '30b58ec1795f6958f3642f85ec43759c9b31d0cc39cb2d41a4062ff17fd9f7bb',
      );
      expect(calls.where((c) => c.method.contains('OnchainSend')), isEmpty);
    },
  );

  test(
    'restored exact commands inspect receipt without replaying payment',
    () async {
      final first = await wallet();
      final original = await btc(first);
      phase = 'prepared';
      await first.prepareOnchainSend(original);
      phase = 'accepted';
      await first.commitOnchainSend(original);
      await first.shutdown();
      final reopened = await wallet();
      final restored = RecoverableOnchainSendCommand.fromJson(
        original.requestJson,
      );
      final accepted = await reopened.onchainSendStatus(restored);
      expect(accepted.phase, RecoverableOnchainSendPhase.accepted);
      expect(accepted.txid, _txid);
      expect(calls.where((c) => c.method == 'prepareOnchainSend').length, 1);
      expect(calls.where((c) => c.method == 'commitOnchainSend').length, 1);
      expect(
        calls.where((c) => {'sendBtc', 'send'}.contains(c.method)),
        isEmpty,
      );
      expect(calls.last.arguments['requestJson'], original.requestJson);
    },
  );

  test(
    'a missing acknowledgement never causes a fallback or automatic retry',
    () async {
      final session = await wallet();
      final command = await btc(session);
      dispatch = (call) {
        if (call.method == 'commitOnchainSend') {
          throw PlatformException(
            code: 'RECOVERY_BUSY',
            message: 'private/path',
          );
        }
        return reply(call);
      };
      await expectLater(
        session.commitOnchainSend(command),
        throwsA(
          isA<RgbLibWalletException>().having(
            (e) => e.code,
            'code',
            'RECOVERY_BUSY',
          ),
        ),
      );
      phase = 'accepted';
      expect(
        (await session.onchainSendStatus(command)).phase,
        RecoverableOnchainSendPhase.accepted,
      );
      expect(calls.where((c) => c.method == 'commitOnchainSend').length, 1);
      expect(
        calls.where((c) => {'sendBtc', 'send'}.contains(c.method)),
        isEmpty,
      );
    },
  );

  test(
    'storage cohort or backend mismatch fails before native mutation',
    () async {
      final first = await wallet();
      final command = await btc(first);
      await first.shutdown();
      cohort = 'f' * 32;
      final next = await wallet();
      final before = calls.length;
      await expectLater(
        next.prepareOnchainSend(command),
        throwsA(isA<WalletValidationException>()),
      );
      expect(calls.length, before);
    },
  );

  test('malformed accepted identity cannot authorize success', () async {
    final session = await wallet();
    final command = await btc(session);
    dispatch = (call) => call.method == 'onchainSendStatus'
        ? jsonEncode({
            ..._status(command.requestJson, 'accepted'),
            'txid': null,
          })
        : reply(call);
    await expectLater(
      session.onchainSendStatus(command),
      throwsA(isA<NativeProtocolException>()),
    );
  });

  test(
    'RGB binds full uint64 amount, encrypted recipient and sender endpoint',
    () async {
      final session = await wallet();
      final command = await session.createRecoverableRgbSendCommand(
        operationId: _operation,
        request: const RgbSendRequest(
          invoice: 'rgb:native-validated-invoice',
          assetId: _asset,
          feeRate: 2,
          witnessAmountSat: 1000,
        ),
        exactAmount: BigInt.parse('18446744073709551615'),
        exactWitnessBlinding: BigInt.parse('18446744073709551615'),
      );
      final payload =
          (jsonDecode(command.requestJson) as Map<String, dynamic>)['request']
              as Map<String, dynamic>;
      expect(payload['amount'], '18446744073709551615');
      expect(payload['witnessBlinding'], '18446744073709551615');
      expect(payload['invoicePublicKey'], _publicKey);
      expect(payload['invoiceEncryption'], 'Required');
      expect(
        payload['senderTransportEndpoint'],
        'rpc://127.0.0.1:29300/json-rpc',
      );
    },
  );

  test('Dev rejects injected invoice and restored command proxies', () async {
    dev = true;
    final session = await wallet();
    const request = RgbSendRequest(
      invoice: 'rgb:native-validated-invoice',
      assetId: _asset,
      feeRate: 2,
      witnessAmountSat: 1000,
    );
    final invalid = isA<WalletValidationException>();
    for (final endpoints in [
      <String>[],
      ['rpcs://outside.example/json-rpc'],
      [_devProxy, 'rpcs://outside.example/json-rpc'],
    ]) {
      devInvoiceEndpoints = endpoints;
      await expectLater(
        session.createRecoverableRgbSendCommand(
          operationId: _operation,
          request: request,
        ),
        throwsA(invalid),
      );
      await expectLater(
        session.onchainSend(
          invoice: request.invoice,
          assetId: _asset,
          feeRate: 2,
          witnessAmountSat: 1000,
        ),
        throwsA(invalid),
      );
    }
    expect(
      calls.where(
        (call) => {'send', 'prepareOnchainSend'}.contains(call.method),
      ),
      isEmpty,
    );

    devInvoiceEndpoints = const [_devProxy];
    final command = await session.createRecoverableRgbSendCommand(
      operationId: _operation,
      request: request,
    );
    expect(
      RecoverableOnchainSendCommand.fromJson(command.requestJson).requestJson,
      command.requestJson,
    );
    for (final field in ['transportEndpoints', 'senderTransportEndpoint']) {
      final envelope = jsonDecode(command.requestJson) as Map<String, dynamic>;
      final payload = envelope['request'] as Map<String, dynamic>;
      payload[field] = field == 'transportEndpoints'
          ? ['rpcs://outside.example/json-rpc']
          : 'rpcs://outside.example/json-rpc';
      payload.remove('fingerprint');
      payload['fingerprint'] = crypto.sha256
          .convert(utf8.encode(jsonEncode(envelope)))
          .toString();
      expect(
        () => RecoverableOnchainSendCommand.fromJson(jsonEncode(envelope)),
        throwsA(invalid),
      );
    }
  });

  test(
    'Dev open invoice requires explicit selection and native registration',
    () async {
      dev = true;
      devInvoiceAssetId = null;
      final session = await wallet();
      Future<RecoverableOnchainSendCommand> create(String? selectedAssetId) =>
          session.createRecoverableRgbSendCommand(
            operationId: _operation,
            request: RgbSendRequest(
              invoice: 'rgb:native-validated-open-invoice',
              assetId: selectedAssetId,
              feeRate: 2,
              witnessAmountSat: 1000,
            ),
            exactAmount: BigInt.from(1234567),
          );
      await expectLater(
        create(_asset),
        throwsA(isA<WalletValidationException>()),
      );
      devInvoiceAssignment = const {'type': 'Any'};
      await expectLater(
        create(null),
        throwsA(isA<WalletValidationException>()),
      );
      dispatch = (call) {
        if (call.method == 'getAssetMetadata') {
          throw PlatformException(code: 'RGB_LIB_AssetNotFound');
        }
        return reply(call);
      };
      await expectLater(
        create(_asset),
        throwsA(
          isA<RgbLibWalletException>().having(
            (error) => error.code,
            'code',
            'ASSET_NOT_FOUND',
          ),
        ),
      );
      dispatch = reply;
      final command = await create(_asset);
      final payload =
          (jsonDecode(command.requestJson) as Map<String, dynamic>)['request']
              as Map<String, dynamic>;
      expect(payload['assetId'], _asset);
      expect(payload['amount'], '1234567');
      expect(payload['transportEndpoints'], [_devProxy]);
      expect(
        calls.where((call) => call.method == 'prepareOnchainSend'),
        isEmpty,
      );
    },
  );

  test(
    'omitted witness blinding remains absent from the exact approved command',
    () async {
      final session = await wallet();
      final command = await session.createRecoverableRgbSendCommand(
        operationId: _operation,
        request: const RgbSendRequest(
          invoice: 'rgb:native-validated-invoice',
          assetId: _asset,
          feeRate: 2,
          witnessAmountSat: 1000,
        ),
      );
      final envelope = jsonDecode(command.requestJson) as Map<String, dynamic>;
      final fields = envelope['request'] as Map<String, dynamic>;
      expect(fields['witnessBlinding'], isNull);
      expect(fields['invoicePublicKey'], _publicKey);
      expect(fields['witnessAmountSat'], '1000');
      expect(
        RecoverableOnchainSendCommand.fromJson(command.requestJson).requestJson,
        command.requestJson,
      );
      expect(
        calls.where(
          (call) => const {
            'prepareOnchainSend',
            'commitOnchainSend',
            'send',
          }.contains(call.method),
        ),
        isEmpty,
      );
    },
  );

  test(
    'expired RGB commands remain reconstructable for read-only recovery',
    () async {
      final session = await wallet();
      invoiceExpiry = 123;
      const request = RgbSendRequest(
        invoice: 'rgb:expired',
        assetId: _asset,
        feeRate: 2,
        witnessAmountSat: 1000,
      );
      await expectLater(
        session.createRecoverableRgbSendCommand(
          operationId: _operation,
          request: request,
        ),
        throwsA(isA<WalletValidationException>()),
      );
      final command = await session.createRecoverableRgbSendCommand(
        operationId: _operation,
        request: request,
        requireFreshInvoice: false,
      );
      expect(
        (jsonDecode(command.requestJson)
            as Map<String, dynamic>)['request']['expirationTimestamp'],
        '123',
      );
      phase = 'accepted';
      expect(
        (await session.onchainSendStatus(command)).phase,
        RecoverableOnchainSendPhase.accepted,
      );
    },
  );

  test(
    'canonical contract import validates identity and preserves exact metadata',
    () async {
      final session = await wallet();
      final imported = await session.importContract(
        contractBase64: 'AQID',
        expectedAssetId: _asset,
      );
      expect(imported.assetSchema, 'Bfa');
      expect(imported.name, 'Bridged USDT');
      expect(imported.knownCirculatingSupply, BigInt.zero);
      expect(imported.maxSupply, BigInt.parse('18446744073709551615'));
      dispatch = (call) => call.method == 'importContract'
          ? jsonEncode({'assetId': 'wrong'})
          : reply(call);
      await expectLater(
        session.importContract(contractBase64: 'AQID', expectedAssetId: _asset),
        throwsA(isA<NativeProtocolException>()),
      );
      final before = calls.length;
      expect(
        () => session.importContract(
          contractBase64: 'notbase64',
          expectedAssetId: _asset,
        ),
        throwsA(isA<WalletValidationException>()),
      );
      expect(calls.length, before);
    },
  );

  test(
    'pending audit cannot turn missing or foreign state into safe deletion',
    () async {
      final session = await wallet();
      expect(await session.hasPendingOnchainSends(), isFalse);
      dispatch = (call) => call.method == 'onchainRecoveryState'
          ? jsonEncode({
              'version': 1,
              'walletBinding': _binding,
              'cohort': 'f' * 32,
              'restoredSnapshot': false,
              'pending': <Map<String, Object?>>[],
            })
          : reply(call);
      await expectLater(
        session.hasPendingOnchainSends(),
        throwsA(isA<NativeProtocolException>()),
      );
      dispatch = (call) =>
          call.method == 'onchainRecoveryState' ? '{not valid' : reply(call);
      await expectLater(
        session.hasPendingOnchainSends(),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test(
    'native discovery recovers the exact command without reauthorizing End',
    () async {
      final session = await wallet();
      final command = await btc(session);
      dispatch = (call) => call.method == 'onchainRecoveryState'
          ? jsonEncode({
              'version': 1,
              'walletBinding': _binding,
              'cohort': _cohort,
              'restoredSnapshot': false,
              'pending': [
                {
                  ..._status(command.requestJson, 'committing'),
                  'commandJson': command.requestJson,
                },
              ],
            })
          : reply(call);
      final entries = await session.listPendingOnchainSends();
      expect(entries.single.commandJson, command.requestJson);
      expect(entries.single.phase, RecoverableOnchainSendPhase.committing);
      expect(entries.single.endAuthorized, isTrue);
      expect(await session.hasPendingOnchainSends(), isTrue);
      expect(
        calls.where(
          (c) => {
            'prepareOnchainSend',
            'commitOnchainSend',
            'sendBtc',
            'send',
          }.contains(c.method),
        ),
        isEmpty,
      );
      dispatch = (call) => call.method == 'onchainRecoveryState'
          ? jsonEncode({
              'version': 1,
              'walletBinding': _binding,
              'cohort': _cohort,
              'restoredSnapshot': false,
              'pending': [
                {
                  ..._status(command.requestJson, 'prepared'),
                  'commandJson': command.requestJson.replaceFirst(
                    _cohort,
                    'f' * 32,
                  ),
                },
              ],
            })
          : reply(call);
      await expectLater(
        session.listPendingOnchainSends(),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test(
    'old coherent backups and missing freshness information never certify absence',
    () async {
      final session = await wallet();
      for (final flag in [true, null]) {
        dispatch = (call) => call.method == 'onchainRecoveryState'
            ? jsonEncode({
                'version': 1,
                'walletBinding': _binding,
                'cohort': _cohort,
                'restoredSnapshot': ?flag,
                'pending': <Object?>[],
              })
            : reply(call);
        await expectLater(
          session.hasPendingOnchainSends(),
          flag == true
              ? throwsA(
                  isA<RgbLibWalletException>().having(
                    (e) => e.code,
                    'code',
                    'RECOVERY_RESTORE_UNCERTAIN',
                  ),
                )
              : throwsA(isA<NativeProtocolException>()),
        );
      }
    },
  );

  test(
    'accepted gross receipts preserve submission truth and page identity',
    () async {
      final session = await wallet();
      final command = await btc(session);
      final receipt = {
        ..._status(command.requestJson, 'accepted'),
        'amount': '1500',
        'feeRate': '2',
        'assetId': null,
        'address': 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn',
        'recipientId': null,
      };
      var revision = '7';
      dispatch = (call) => call.method == 'listOnchainSendReceipts'
          ? jsonEncode({
              'version': 1,
              'walletBinding': _binding,
              'cohort': _cohort,
              'revision': revision,
              'restoredSnapshot': true,
              'total': 2,
              'receipts': [receipt],
            })
          : reply(call);
      final page = await session.listOnchainSendReceipts(limit: 1);
      expect(page.revision, BigInt.from(7));
      expect(page.restoredSnapshot, isTrue);
      expect(page.receipts.single.amount, BigInt.from(1500));
      expect(page.receipts.single.phase, RecoverableOnchainSendPhase.accepted);
      expect(page.receipts.single.txid, _txid);
      revision = '8';
      final next = await session.listOnchainSendReceipts(offset: 1, limit: 1);
      expect(next.revision, isNot(page.revision));
      expect(next.offset, 1);
      expect(
        calls.where(
          (c) => {
            'prepareOnchainSend',
            'commitOnchainSend',
            'sendBtc',
            'send',
          }.contains(c.method),
        ),
        isEmpty,
      );
    },
  );

  test(
    'receipt inventory rejects failed operations, narrowed amounts and partial pages',
    () async {
      final session = await wallet();
      final command = await btc(session);
      final receipt = {
        ..._status(command.requestJson, 'accepted'),
        'amount': '1500',
        'feeRate': '2',
        'assetId': null,
        'address': 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn',
        'recipientId': null,
      };
      for (final altered in [
        {...receipt, 'amount': 1500},
        {
          ...receipt,
          'phase': 'rejected',
          'endAuthorized': false,
          'failureCode': 'cancelled',
          'txid': null,
        },
      ]) {
        dispatch = (call) => call.method == 'listOnchainSendReceipts'
            ? jsonEncode({
                'version': 1,
                'walletBinding': _binding,
                'cohort': _cohort,
                'revision': '8',
                'restoredSnapshot': false,
                'total': 1,
                'receipts': [altered],
              })
            : reply(call);
        await expectLater(
          session.listOnchainSendReceipts(),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      dispatch = (call) => call.method == 'listOnchainSendReceipts'
          ? jsonEncode({
              'version': 1,
              'walletBinding': _binding,
              'cohort': _cohort,
              'revision': '8',
              'restoredSnapshot': false,
              'total': 2,
              'receipts': [receipt],
            })
          : reply(call);
      await expectLater(
        session.listOnchainSendReceipts(),
        throwsA(isA<NativeProtocolException>()),
      );
      final before = calls.length;
      expect(
        () => session.listOnchainSendReceipts(limit: 501),
        throwsA(isA<WalletValidationException>()),
      );
      expect(calls.length, before);
    },
  );

  test('public key disclosure is bound to native account identity', () async {
    final keys = await deriveKeysFromMnemonic(
      'regtest',
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final identity = crypto.sha256
        .convert(
          utf8.encode(
            'regtest:taproot:${keys.accountXpubVanilla}:${keys.accountXpubColored}',
          ),
        )
        .toString();
    var altered = false;
    dispatch = (call) => switch (call.method) {
      'getWalletIdentity' => {
        'id': identity,
        'network': 'regtest',
        'masterFingerprint': keys.masterFingerprint,
        'recoveryCohort': _cohort,
      },
      'getPublicKeys' => {
        'accountXpubVanilla': keys.accountXpubVanilla,
        'accountXpubColored': altered
            ? keys.accountXpubVanilla
            : keys.accountXpubColored,
        'masterFingerprint': keys.masterFingerprint,
      },
      _ => reply(call),
    };
    final session = await wallet();
    expect(
      (await session.getPublicKeys()).accountXpubColored,
      keys.accountXpubColored,
    );
    altered = true;
    await expectLater(
      session.getPublicKeys(),
      throwsA(isA<NativeProtocolException>()),
    );
  });

  test(
    'watch-only sessions can audit recovery without gaining signing authority',
    () async {
      final keys = await deriveKeysFromMnemonic(
        'regtest',
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      dispatch = (call) => call.method == 'getWalletIdentity'
          ? {
              'id': _binding,
              'network': 'regtest',
              'masterFingerprint': keys.masterFingerprint,
              'recoveryCohort': _cohort,
            }
          : reply(call);
      final session = RgbLibWallet(
        params: const RgbLibWalletParams(
          network: 'regtest',
          storageDirPath: '/private/watch-only',
        ),
        keys: RgbLibKeys.watchOnly(
          RgbLibPublicKeys(
            accountXpubVanilla: keys.accountXpubVanilla,
            accountXpubColored: keys.accountXpubColored,
            masterFingerprint: keys.masterFingerprint,
          ),
        ),
      );
      await session.init();
      addTearDown(session.destroy);
      expect(session.supportsRecoverableOnchainSend, isFalse);
      expect(await session.hasPendingOnchainSends(), isFalse);
      final before = calls.length;
      await expectLater(
        btc(session),
        throwsA(
          isA<RgbLibWalletException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_CAPABILITY',
          ),
        ),
      );
      expect(calls.length, before);
    },
  );

  test(
    'BFA.7 requires explicit validated backing-chain lock bounds before dispatch',
    () async {
      final session = RgbLibWallet(
        params: const RgbLibWalletParams(
          network: 'regtest',
          storageDirPath: '/private/chain-policy',
        ),
        keys: RgbLibKeys.mnemonic('test-only-key-source'),
      );
      await session.init();
      addTearDown(session.destroy);
      RgbLibUnlockParams config({int minimum = 2, int maximum = 7200}) =>
          RgbLibUnlockParams(
            indexerUrl: 'tcp://127.0.0.1:29302',
            proxyEndpoint: 'rpc://127.0.0.1:29300/json-rpc',
            evmChains: {
              '42161': RgbLibEvmChain(
                rpcUrl: 'https://rpc.example',
                minMintLockBlocks: minimum,
                maxMintLockBlocks: maximum,
              ),
            },
          );
      for (final invalid in [
        RgbLibUnlockParams(
          indexerUrl: 'tcp://127.0.0.1:29302',
          proxyEndpoint: 'rpc://127.0.0.1:29300/json-rpc',
          evmRpcUrls: {'42161': 'https://rpc.example'},
        ),
        config(minimum: 1),
        config(minimum: 10, maximum: 9),
      ]) {
        await expectLater(
          session.unlock(invalid),
          throwsA(
            isA<RgbLibWalletException>().having(
              (e) => e.code,
              'code',
              'INVALID_CONFIG',
            ),
          ),
        );
      }
      expect(calls.where((c) => c.method == 'goOnline'), isEmpty);
      await session.unlock(config());
      final native = calls.singleWhere((c) => c.method == 'goOnline');
      expect(native.arguments['evmChainIds'], ['42161']);
      expect(native.arguments['evmRpcUrls'], ['https://rpc.example']);
      expect(native.arguments['evmMinMintLockBlocks'], ['2']);
      expect(native.arguments['evmMaxMintLockBlocks'], ['7200']);
    },
  );

  test(
    'received mint preserves exact native lock requirements and absence',
    () async {
      final session = await wallet();
      final expected = <String, Object?>{
        'opid': 'native-operation-id',
        'lockId': 'transaction-bound-native-lock-id',
        'amount': '18446744073709551615',
        'beforeBlock': '18446744073709551614',
        'evmChainId': '42161',
        'bridgeContract': '0x1111111111111111111111111111111111111111',
      };
      dispatch = (call) =>
          call.method == 'getReceivedMint' ? expected : reply(call);
      final mint = (await session.getReceivedMint('native-witness-recipient'))!;
      expect(mint.opid, expected['opid']);
      expect(mint.lockId, expected['lockId']);
      expect(mint.amount, BigInt.parse('18446744073709551615'));
      expect(mint.beforeBlock, BigInt.parse('18446744073709551614'));
      expect(mint.evmChainId, BigInt.from(42161));
      expect(mint.bridgeContract, expected['bridgeContract']);
      expect(calls.last.arguments['recipientId'], 'native-witness-recipient');
      dispatch = (call) =>
          call.method == 'getReceivedMint' ? null : reply(call);
      expect(await session.getReceivedMint('native-witness-recipient'), isNull);
      for (final invalid in ['-1', '18446744073709551616', 42, '01']) {
        dispatch = (call) => call.method == 'getReceivedMint'
            ? {...expected, 'beforeBlock': invalid}
            : reply(call);
        await expectLater(
          session.getReceivedMint('native-witness-recipient'),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      final count = calls.length;
      expect(
        () => session.getReceivedMint(''),
        throwsA(isA<WalletValidationException>()),
      );
      expect(calls.length, count);
    },
  );

  test(
    'sealed artifact digests are required before reading wallet keys',
    () async {
      var secretReads = 0;
      final session = RgbLibWallet(
        params: const RgbLibWalletParams(
          network: 'regtest',
          storageDirPath: '/private/digest-rejected',
        ),
        keys: RgbLibKeys.reader(() {
          secretReads++;
          return 'never-read';
        }),
      );
      for (final key in [
        'integrationTree',
        'overlayPatchSha256',
        'sourceLockSha256',
        'sourceManifestSha256',
      ]) {
        dispatch = (call) => call.method == 'getRuntimeInfo'
            ? {...reply(call) as Map<String, Object?>, key: 'wrong'}
            : reply(call);
        await expectLater(
          session.init(),
          throwsA(
            isA<RgbLibWalletException>().having(
              (error) => error.code,
              'code',
              'NATIVE_VERSION_MISMATCH',
            ),
          ),
        );
      }
      expect(secretReads, 0);
      expect(calls.any((call) => call.method == 'openWallet'), isFalse);
      await session.destroy();
    },
  );

  test(
    'missing native capabilities cannot be advertised or dispatched',
    () async {
      capabilities = false;
      final session = await wallet();
      expect(session.supportsRecoverableOnchainSend, isFalse);
      final before = calls.length;
      await expectLater(
        btc(session),
        throwsA(
          isA<RgbLibWalletException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_CAPABILITY',
          ),
        ),
      );
      await expectLater(
        session.importContract(contractBase64: 'AQID', expectedAssetId: _asset),
        throwsA(
          isA<RgbLibWalletException>().having(
            (e) => e.code,
            'code',
            'UNSUPPORTED_CAPABILITY',
          ),
        ),
      );
      expect(calls.length, before);
    },
  );

  test(
    'dispatched revocation capability is explicit and identity verified',
    () async {
      expect(
        (await RgbLibWallet.getRuntimeInfo()).supportsDispatchedRgbRevocation,
        isFalse,
      );
      dispatch = (call) {
        final value = reply(call);
        return call.method == 'getRuntimeInfo'
            ? {
                ...value! as Map<String, Object?>,
                'supportsDispatchedRgbRevocation': true,
              }
            : value;
      };
      expect(
        (await RgbLibWallet.getRuntimeInfo()).supportsDispatchedRgbRevocation,
        isTrue,
      );
      dispatch = (call) {
        final value = reply(call);
        return call.method == 'getRuntimeInfo'
            ? {
                ...value! as Map<String, Object?>,
                'supportsDispatchedRgbRevocation': true,
                'integrationTree': 'f' * 40,
              }
            : value;
      };
      await expectLater(
        RgbLibWallet.getRuntimeInfo(),
        throwsA(isA<RgbLibWalletException>()),
      );
      expect(calls.where((call) => call.method == 'openWallet'), isEmpty);
    },
  );

  test(
    'dispatched revocation capability rejects malformed or incoherent claims',
    () async {
      for (final invalid in <Object?>['true', 1, null]) {
        dispatch = (call) {
          final value = reply(call);
          return call.method == 'getRuntimeInfo'
              ? {
                  ...value! as Map<String, Object?>,
                  'supportsDispatchedRgbRevocation': invalid,
                }
              : value;
        };
        await expectLater(
          RgbLibWallet.getRuntimeInfo(),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      dispatch = (call) {
        final value = reply(call);
        return call.method == 'getRuntimeInfo'
            ? {
                ...value! as Map<String, Object?>,
                'supportsDispatchedRgbRevocation': true,
                'durableOnchainRecovery': false,
              }
            : value;
      };
      await expectLater(
        RgbLibWallet.getRuntimeInfo(),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test(
    'invalid native backup is a stable payload-free typed failure',
    () async {
      dispatch = (call) => throw PlatformException(
        code: 'RECOVERY_BACKUP_INVALID',
        message: 'private native diagnostics',
      );
      await expectLater(
        RgbLibWallet.getRuntimeInfo(),
        throwsA(
          isA<RgbLibWalletException>()
              .having((error) => error.code, 'code', 'RECOVERY_BACKUP_INVALID')
              .having(
                (error) => error.message.contains('private native diagnostics'),
                'redacted',
                isFalse,
              ),
        ),
      );
    },
  );

  test(
    'explicit revocation requires its verified capability before native dispatch',
    () async {
      final session = await wallet();
      final command = await btc(session);
      final before = calls.length;
      await expectLater(
        session.revokeOnchainSend(command),
        throwsA(
          isA<RgbLibWalletException>().having(
            (error) => error.code,
            'code',
            'UNSUPPORTED_CAPABILITY',
          ),
        ),
      );
      expect(calls.length, before);
    },
  );

  test(
    'ordinary cancellation never dispatches explicit revocation after a commit race',
    () async {
      dispatch = (call) {
        final value = reply(call);
        return call.method == 'getRuntimeInfo'
            ? {
                ...value! as Map<String, Object?>,
                'supportsDispatchedRgbRevocation': true,
              }
            : value;
      };
      final session = await wallet();
      final command = await session.createRecoverableRgbSendCommand(
        operationId: _operation,
        request: const RgbSendRequest(
          invoice: 'rgb:native-validated-invoice',
          assetId: _asset,
          feeRate: 2,
          witnessAmountSat: 1000,
        ),
      );
      phase = 'prepared';
      expect((await session.onchainSendStatus(command)).endAuthorized, isFalse);
      phase = 'committing';
      await session.commitOnchainSend(command);
      expect(
        (await session.cancelOnchainSend(command)).phase,
        RecoverableOnchainSendPhase.committing,
      );
      expect(
        calls.where((call) => call.method == 'revokeOnchainSend'),
        isEmpty,
      );
      phase = 'rejected';
      final cancelled = await session.revokeOnchainSend(command);
      expect(cancelled.phase, RecoverableOnchainSendPhase.rejected);
      expect(cancelled.endAuthorized, isFalse);
      expect(
        calls.where((call) => call.method == 'revokeOnchainSend').length,
        1,
      );
      expect(
        calls.where((call) => call.method == 'cancelOnchainSend').length,
        1,
      );
      expect(
        calls.where((call) => call.method == 'commitOnchainSend').length,
        1,
      );
    },
  );

  test(
    'L1 convenience refresh fails once on partial native observations',
    () async {
      final session = await wallet();
      dispatch = (call) => call.method == 'refresh'
          ? [
              {
                'batchTransferIdx': 1,
                'updatedStatus': 'WaitingConfirmations',
                'failure': {
                  'name': 'RGB_LIB_Network',
                  'message': 'private native diagnostics',
                },
              },
              {
                'batchTransferIdx': 2,
                'updatedStatus': 'Settled',
                'failure': null,
              },
            ]
          : reply(call);
      final detailed = await session.refreshTransfers();
      expect(detailed.transfers[1]!.failure, isNotNull);
      expect(detailed.transfers[2]!.failure, isNull);
      final before = calls.where((call) => call.method == 'refresh').length;
      await expectLater(
        session.refreshWallet(),
        throwsA(
          isA<RgbLibWalletException>()
              .having((error) => error.code, 'code', 'REFRESH_INCOMPLETE')
              .having(
                (error) => error.message.contains('private native diagnostics'),
                'redacted',
                isFalse,
              ),
        ),
      );
      expect(
        calls.where((call) => call.method == 'refresh').length,
        before + 1,
      );
    },
  );
}
