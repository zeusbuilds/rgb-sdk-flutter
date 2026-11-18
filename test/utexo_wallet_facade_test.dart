import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart'
    show UtexoWalletRawApi;
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

import 'burn_operations_test.dart'
    as burn_test
    show MemoryBurnStore, metadata, params;

const _rgbChannel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _walletId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _cohort = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _operationId = 'cccccccccccccccccccccccccccccccc';
const _txid =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _assetId = 'rgb:required-contract';
const _recipientId = 'native-witness-recipient';
const _address = 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn';
const _invoice = 'rgb:mock-invoice';
const _handle = 'rgb-lib-test-handle';
const _storage = '/private/facade-rgb-test';
const _proxy = 'rpc://127.0.0.1:29300/json-rpc';
const _balance = {'settled': '21', 'future': '23', 'spendable': '20'};

const _rgbRuntime = {
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
  'contractRegistration': true,
  'durableOnchainRecovery': true,
};

const _mint = {
  'opid': 'native-operation-id',
  'lockId': 'transaction-bound-native-lock-id',
  'amount': '18446744073709551615',
  'beforeBlock': '18446744073709551614',
  'evmChainId': '42161',
  'bridgeContract': '0x1111111111111111111111111111111111111111',
};

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  final rgbCalls = <MethodCall>[];
  final rlnCalls = <(String, Object?)>[];
  final rlnReplies = <String, Object?>{
    'rlnCreateNode': 14,
    'rlnInitNode': 'test-init-response',
    'rlnShutdown': null,
    'rlnDestroyNode': null,
    'rlnLnInvoice': null,
    'rlnBtcBalance': null,
  };
  final rlnChannels = {
    for (final method in rlnReplies.keys)
      method: BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.rgb_sdk_flutter.RlnHostApi.$method',
        RlnHostApi.pigeonChannelCodec,
      ),
  };
  late Object? Function(MethodCall) rgbReply;
  late String sendPhase;

  Object? defaultRgbReply(MethodCall call) {
    switch (call.method) {
      case 'getRuntimeInfo':
        return _rgbRuntime;
      case 'openWallet':
        return _handle;
      case 'getWalletIdentity':
        return {
          'id': _walletId,
          'network': 'regtest',
          'masterFingerprint': 'a1b2c3d4',
          'recoveryCohort': _cohort,
        };
      case 'getAddress':
        return _address;
      case 'getBtcBalance':
        return {'vanilla': _balance, 'colored': _balance};
      case 'getAssetBalance':
        return _balance;
      case 'getReceivedMint':
        return _mint;
      case 'receive':
        return {
          'invoice': _invoice,
          'recipientId': _recipientId,
          'expirationTimestamp': call.arguments['expirationTimestamp'],
          'batchTransferIdx': 5,
          'publicKey': 'public',
        };
      case 'send':
        return {'txid': _txid, 'batchTransferIdx': 6};
      case 'importContract':
        return jsonEncode({
          'assetId': _assetId,
          'alreadyImported': false,
          'metadata': {
            'assetSchema': 'Bfa',
            'name': 'Test USDT',
            'ticker': 'USDT',
            'precision': 6,
            'initialSupply': '0',
            'maxSupply': '1000000000',
            'knownCirculatingSupply': '0',
          },
        });
      case 'closeWallet':
      case 'goOnline':
        return null;
      case 'prepareOnchainSend':
        sendPhase = 'prepared';
        return _sendStatus(call, sendPhase);
      case 'commitOnchainSend':
        sendPhase = 'accepted';
        return _sendStatus(call, sendPhase);
      case 'onchainSendStatus':
      case 'cancelOnchainSend':
        return _sendStatus(call, sendPhase);
      default:
        throw StateError('Unexpected RGB_L1 method: ${call.method}');
    }
  }

  RgbLibWallet rgbEngine() => RgbLibWallet(
    params: const RgbLibWalletParams(
      network: 'regtest',
      storageDirPath: _storage,
    ),
    keys: RgbLibKeys.reader(() => 'test-only-key-source'),
    online: RgbLibUnlockParams(
      indexer: const RgbLibIndexer.esplora('http://127.0.0.1:29302'),
      proxyEndpoint: _proxy,
    ),
  );

  setUp(() {
    rgbCalls.clear();
    rlnCalls.clear();
    rgbReply = defaultRgbReply;
    sendPhase = 'absent';
    messenger.setMockMethodCallHandler(_rgbChannel, (call) async {
      rgbCalls.add(call);
      return rgbReply(call);
    });
    for (final MapEntry(:key, :value) in rlnChannels.entries) {
      messenger.setMockDecodedMessageHandler<Object?>(value, (message) async {
        rlnCalls.add((key, message));
        return <Object?>[rlnReplies[key]];
      });
    }
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_rgbChannel, null);
    for (final channel in rlnChannels.values) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
  });

  test(
    'legacy and named RLN constructors keep the same native backend',
    () async {
      final config = UtexoWalletConfig(
        storageDirPath: '/private/facade-rln-test',
      );
      final wallets = [
        UtexoWallet(config: config),
        UtexoWallet.rln(config: config),
        const RgbSdkFlutter().wallet(config: config),
      ];
      for (final wallet in wallets) {
        expect(wallet.protocol, 'RGB_LN');
        expect(wallet.rgbLibEngine, isNull);
        await expectLater(
          () => wallet.getReceivedMint(_recipientId),
          throwsA(isA<UnsupportedWalletFeatureException>()),
        );
        expect(rlnCalls, isEmpty);
        await wallet.init(password: 'test-password');
        expect(wallet.isInitialized, isTrue);
        await wallet.destroy();
        expect(wallet.isDisposed(), isTrue);
        expect(rlnCalls.map((call) => call.$1), [
          'rlnCreateNode',
          'rlnInitNode',
          'rlnShutdown',
          'rlnDestroyNode',
        ]);
        expect(
          (rlnCalls.first.$2 as List<Object?>).first,
          config.storageDirPath,
        );
        rlnCalls.clear();
      }
      expect(rgbCalls, isEmpty);
    },
  );

  test(
    'RGB_L1 dispatch preserves the supplied engine and native session',
    () async {
      final engine = rgbEngine();
      final wallet = UtexoWallet.rgbLib(engine: engine);
      expect(wallet.protocol, 'RGB_L1');
      expect(wallet.rgbLibEngine, same(engine));
      expect(wallet.isInitialized, isFalse);
      expect(rgbCalls, isEmpty);

      await wallet.initialize();
      expect(wallet.isInitialized, isTrue);
      expect(engine.isInitialized, isTrue);
      expect(wallet.isUnlocked, isFalse);
      expect(await wallet.getAddress(), _address);
      expect((await wallet.getBtcBalance(skipSync: true)).vanilla.settled, 21);
      expect(
        (await wallet.getAssetBalance(_assetId)).spendable,
        BigInt.from(20),
      );
      expect(rgbCalls.map((call) => call.method), [
        'getRuntimeInfo',
        'openWallet',
        'getWalletIdentity',
        'getAddress',
        'getBtcBalance',
        'getAssetBalance',
      ]);
      expect(rgbCalls[1].arguments['dataDir'], _storage);
      expect(rgbCalls[4].arguments['skipSync'], isTrue);
      expect(rgbCalls[5].arguments['assetId'], _assetId);
      for (final call in rgbCalls.skip(2)) {
        expect(call.arguments['handle'], _handle);
      }

      await wallet.shutdown();
      expect(rgbCalls.last.method, 'closeWallet');
      expect(wallet.isShutdown, isTrue);
      expect(engine.isShutdown, isTrue);
      expect(wallet.isInitialized, isFalse);
      await wallet.reinit();
      expect(wallet.isShutdown, isFalse);
      expect(await wallet.getAddress(), _address);
      await engine.goOnline();
      expect(wallet.isUnlocked, isTrue);
      await wallet.dispose();
      expect(wallet.isDisposed(), isTrue);
      expect(engine.isDisposed(), isTrue);
      expect(
        rgbCalls.where((call) => call.method == 'closeWallet'),
        hasLength(2),
      );
      expect(rlnCalls, isEmpty);
    },
  );

  test(
    'the RGB_L1 facade exposes WebRGB capabilities without signing',
    () async {
      final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
      await wallet.init();
      var prompts = 0;
      final provider = WebRgbProvider(
        wallet,
        WebRgbOptions(
          origin: 'https://wallet.example',
          sessionApproved: true,
          confirm: (_) async {
            prompts++;
            return true;
          },
        ),
      );
      final info = await provider.getInfo();
      expect(info.network, 'regtest');
      expect(info.protocol, 'RGB_L1');
      expect(info.methods, contains('getAddress'));
      expect(info.methods, isNot(contains('signMessage')));
      expect((await provider.getAddress()).address, _address);
      await expectLater(
        provider.signMessage('a dApp request'),
        throwsA(
          isA<WebRgbError>().having(
            (error) => error.code,
            'code',
            'METHOD_NOT_SUPPORTED',
          ),
        ),
      );
      expect(prompts, 0);
      expect(rgbCalls.skip(3).map((call) => call.method), ['getAddress']);
      expect(rlnCalls, isEmpty);
      provider.revoke();
      await wallet.destroy();
    },
  );

  test('the facade and RGB_L1 engine share one durable burn owner', () async {
    final engine = rgbEngine();
    final wallet = UtexoWallet.rgbLib(engine: engine);
    final anotherFacade = UtexoWallet.rgbLib(engine: engine);
    final store = burn_test.MemoryBurnStore();
    final facadeBurns = BurnOperations(wallet, store);
    final directBurns = BurnOperations(engine, store);
    expect(facadeBurns.belongsTo(engine), isTrue);
    expect(directBurns.belongsTo(anotherFacade), isTrue);
    expect(facadeBurns.belongsTo(rgbEngine()), isFalse);
    expect(
      () => BurnOperations(anotherFacade, burn_test.MemoryBurnStore()),
      throwsA(isA<ConfigurationError>()),
    );

    await wallet.init();
    final webRgb = WebRgbProvider(
      anotherFacade,
      WebRgbOptions(
        origin: burn_test.metadata.origin,
        confirm: (_) async => true,
        sessionApproved: true,
        burn: WebRgbBurnOptions(
          operations: facadeBurns,
          allowedPayoutChainIds: [burn_test.metadata.payout.chainId],
        ),
      ),
    );
    expect((await webRgb.getInfo()).methods, contains('burnAsset'));
    webRgb.revoke();

    rgbReply = (call) {
      if (call.method == 'burn') {
        throw PlatformException(code: 'NATIVE_BRIDGE_ERROR');
      }
      return defaultRgbReply(call);
    };
    await expectLater(
      facadeBurns.execute(burn_test.params, burn_test.metadata, () {}),
      throwsA(isA<RgbLibWalletException>()),
    );
    final saved = (await directBurns.records()).single;
    expect(saved.state, BurnOperationState.pending);
    await expectLater(
      directBurns.execute(burn_test.params, burn_test.metadata, () {}),
      throwsA(
        isA<WalletError>().having(
          (error) => error.code,
          'code',
          'BURN_OUTCOME_UNRESOLVED',
        ),
      ),
    );
    expect(rgbCalls.where((call) => call.method == 'burn'), hasLength(1));
    expect(rlnCalls, isEmpty);
    await wallet.destroy();
  });

  test('the RGB_L1 facade rejects direct LSP construction on regtest', () {
    final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
    expect(wallet.network, 'regtest');
    expect(
      () => UtexoLsp(
        wallet: wallet,
        peer: const LspPeer(
          baseUrl: 'https://lsp.example',
          peerPubkey: 'peer',
          peerHost: 'lsp.example',
          peerPort: 9735,
        ),
      ),
      throwsA(isA<UnsupportedWalletFeatureException>()),
    );
    expect(rgbCalls, isEmpty);
    expect(rlnCalls, isEmpty);
  });

  test('on-chain receive and send forward the RGB_L1 arguments', () async {
    final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
    await wallet.init();
    final receive = await wallet.onchainReceive(
      const RgbInvoiceRequest(
        assetId: _assetId,
        amount: 25,
        assignmentKind: RgbReceiveAssignmentKind.fungible,
        durationSeconds: 3600,
        minConfirmations: 3,
      ),
    );
    expect(receive.invoice, _invoice);
    expect(receive.recipientId, _recipientId);
    expect(receive.batchTransferIdx, 5);
    expect(rgbCalls.last.arguments, {
      'handle': _handle,
      'witness': true,
      'assetId': _assetId,
      'amount': '25',
      'minConfirmations': 3,
      'assignmentKind': 'Fungible',
      'transportEndpoints': [_proxy],
      'expirationTimestamp': receive.expirationTimestamp.toString(),
    });

    final send = await wallet.onchainSend(
      const RgbSendRequest(
        invoice: _invoice,
        assetId: _assetId,
        amount: 25,
        feeRate: 2,
        minConfirmations: 3,
        witnessAmountSat: 1000,
        witnessBlinding: 9,
      ),
    );
    expect(send.txid, _txid);
    expect(send.batchTransferIdx, 6);
    expect(rgbCalls.last.arguments, {
      'handle': _handle,
      'invoice': _invoice,
      'assetId': _assetId,
      'amount': '25',
      'witnessAmountSat': '1000',
      'witnessBlinding': '9',
      'donation': false,
      'feeRate': '2',
      'minConfirmations': 3,
      'skipSync': false,
      'senderTransportEndpoint': _proxy,
    });
    expect(rgbCalls.skip(3).map((call) => call.method), [
      'goOnline',
      'receive',
      'send',
    ]);
    expect(rlnCalls, isEmpty);
    await wallet.destroy();
  });

  test(
    'RGB_L1 facade preserves registration and received-mint semantics',
    () async {
      final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
      await wallet.init();
      final imported = await wallet.importRgbContract(
        contractBase64: 'YWJj',
        expectedAssetId: _assetId,
      );
      expect(imported.assetId, _assetId);
      expect(imported.initialSupply, BigInt.zero);
      expect(rgbCalls.last.arguments['contractBase64'], 'YWJj');
      expect(rgbCalls.last.arguments['expectedAssetId'], _assetId);

      final mint = await wallet.getReceivedMint(_recipientId);
      expect(mint?.amount, BigInt.parse('18446744073709551615'));
      expect(mint?.evmChainId, BigInt.from(42161));
      expect(rgbCalls.last.arguments['recipientId'], _recipientId);
      rgbReply = (call) =>
          call.method == 'getReceivedMint' ? null : defaultRgbReply(call);
      expect(await wallet.getReceivedMint(_recipientId), isNull);

      expect(rgbCalls.skip(3).map((call) => call.method), [
        'importContract',
        'getReceivedMint',
        'getReceivedMint',
      ]);
      expect(rlnCalls, isEmpty);
      await wallet.destroy();
    },
  );

  test(
    'durable send reuses the same command without replay or fallback',
    () async {
      final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
      await wallet.init();
      final command = await wallet.createRecoverableBtcSendCommand(
        operationId: _operationId,
        amount: 1500,
        address: _address,
        feeRate: 2,
      );
      expect(command.version, 3);
      expect(
        (await wallet.onchainSendStatus(command)).phase,
        RecoverableOnchainSendPhase.absent,
      );
      expect(
        (await wallet.prepareOnchainSend(command)).phase,
        RecoverableOnchainSendPhase.prepared,
      );
      expect(wallet.isUnlocked, isTrue);

      rgbReply = (call) {
        final reply = defaultRgbReply(call);
        if (call.method == 'commitOnchainSend') {
          throw PlatformException(code: 'NATIVE_BRIDGE_ERROR');
        }
        return reply;
      };
      await expectLater(
        wallet.commitOnchainSend(command),
        throwsA(
          isA<RgbLibWalletException>().having(
            (error) => error.operation,
            'operation',
            'commitOnchainSend',
          ),
        ),
      );
      final accepted = await wallet.onchainSendStatus(command);
      expect(accepted.phase, RecoverableOnchainSendPhase.accepted);
      expect(accepted.txid, _txid);
      expect((await wallet.cancelOnchainSend(command)).endAuthorized, isTrue);
      final sendCalls = rgbCalls.skip(3);
      expect(sendCalls.map((call) => call.method), [
        'onchainSendStatus',
        'goOnline',
        'prepareOnchainSend',
        'commitOnchainSend',
        'onchainSendStatus',
        'cancelOnchainSend',
      ]);
      for (final call in sendCalls.where((call) => call.method != 'goOnline')) {
        expect(call.arguments['requestJson'], command.requestJson);
        expect(call.arguments['handle'], _handle);
      }
      expect(rlnCalls, isEmpty);
      await wallet.destroy();
    },
  );

  test(
    'RGB_L1 rejects RLN-only operations locally and preserves native errors',
    () async {
      final wallet = UtexoWallet.rgbLib(engine: rgbEngine());
      await expectLater(
        wallet.init(password: 'an RLN credential'),
        throwsA(isA<WalletValidationException>()),
      );
      expect(rgbCalls, isEmpty);
      await wallet.init();
      rgbCalls.clear();
      await expectLater(
        wallet.unlock(config: UtexoUnlockConfig()),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      for (final operation in <Future<Object?> Function()>[
        () => wallet.createLightningInvoice(amountSats: 1500),
        () => wallet.getBtcBalanceRaw(),
      ]) {
        await expectLater(
          operation,
          throwsA(isA<UnsupportedWalletFeatureException>()),
        );
      }
      expect(rgbCalls, isEmpty);
      expect(rlnCalls, isEmpty);

      rgbReply = (call) => throw PlatformException(
        code: 'NATIVE_BRIDGE_ERROR',
        message: 'private native diagnostic',
      );
      await expectLater(
        wallet.getAddress(),
        throwsA(
          isA<RgbLibWalletException>()
              .having((error) => error.code, 'code', 'NATIVE_ERROR')
              .having((error) => error.operation, 'operation', 'getAddress')
              .having(
                (error) => error.toString(),
                'public text',
                isNot(contains('private native diagnostic')),
              ),
        ),
      );
      expect(rgbCalls.map((call) => call.method), ['getAddress']);
      expect(rlnCalls, isEmpty);
      rgbReply = defaultRgbReply;
      await wallet.destroy();
    },
  );
}

String _sendStatus(MethodCall call, String phase) {
  final request =
      jsonDecode(call.arguments['requestJson'] as String)
          as Map<String, dynamic>;
  final payment = request['request'] as Map<String, dynamic>;
  return jsonEncode({
    'version': 1,
    'operationId': payment['operationId'],
    'fingerprint': phase == 'absent' ? null : payment['fingerprint'],
    'kind': phase == 'absent' ? null : payment['kind'],
    'phase': phase,
    'txid': phase == 'absent' ? null : _txid,
    'batchTransferIndex': null,
    'failureCode': null,
    'endAuthorized': phase == 'accepted',
  });
}
