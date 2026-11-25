import 'dart:async';
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
  'assetId': _assetId,
  'opid': 'native-operation-id',
  'lockId': 'transaction-bound-native-lock-id',
  'amount': '18446744073709551615',
  'beforeBlock': '18446744073709551614',
  'evmChainId': '42161',
  'bridgeContract': '0x1111111111111111111111111111111111111111',
};

/// An integration-owned engine exercises only the advertised shared contract.
class _CustomEngine implements WalletEngine {
  _CustomEngine({this.protocol = 'RGB_L1', this.contractVersion = '1'});

  @override
  final String protocol;
  @override
  final String contractVersion;
  @override
  String get network => 'regtest';
  @override
  String getNetwork() => network;
  @override
  bool isInitialized = false;
  @override
  bool isUnlocked = false;
  @override
  bool isShutdown = false;
  bool disposed = false;
  final calls = <String>[];
  Future<String>? addressReply;

  @override
  bool isDisposed() => disposed;
  @override
  Future<void> init() async {
    calls.add('init');
    isInitialized = true;
  }

  @override
  Future<void> reinit() async {
    calls.add('reinit');
    isInitialized = true;
    isShutdown = false;
  }

  @override
  Future<void> shutdown() async {
    calls.add('shutdown');
    isInitialized = false;
    isShutdown = true;
  }

  @override
  Future<void> destroy() async {
    calls.add('destroy');
    isInitialized = false;
    disposed = true;
  }

  @override
  Future<String> getAddress() {
    calls.add('getAddress');
    return addressReply ?? Future.value('custom-engine-address');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  final rgbCalls = <MethodCall>[];
  final rlnCalls = <(String, Object?)>[];
  final rlnReplies = <String, Object?>{
    'rlnCreateNode': 14,
    'rlnInitNode': 'test-init-response',
    'rlnUnlockNode': null,
    'rlnAddress': RlnWireResponse(json: jsonEncode({'address': _address})),
    'rlnBfaCapabilities': RlnWireResponse(
      json: '{"burn":true,"consignment":true,"bfa":true}',
    ),
    'rlnBurn': RlnWireResponse(
      json: jsonEncode({'txid': _txid, 'batchTransferIdx': 6}),
    ),
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
  late Object? Function(String, Object?) rlnReply;
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
    rlnReply = (method, _) => rlnReplies[method];
    sendPhase = 'absent';
    messenger.setMockMethodCallHandler(_rgbChannel, (call) async {
      rgbCalls.add(call);
      return rgbReply(call);
    });
    for (final MapEntry(:key, :value) in rlnChannels.entries) {
      messenger.setMockDecodedMessageHandler<Object?>(value, (message) async {
        rlnCalls.add((key, message));
        try {
          return <Object?>[rlnReply(key, message)];
        } on PlatformException catch (error) {
          return <Object?>[error.code, error.message, error.details];
        }
      });
    }
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_rgbChannel, null);
    for (final channel in rlnChannels.values) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
  });

  test('default and package constructors select RGB_L1 only', () async {
    const params = RgbLibWalletParams(
      network: 'regtest',
      storageDirPath: _storage,
    );
    final keys = RgbLibKeys.reader(() => 'test-only-key-source');
    final wallets = [
      UtexoWallet(params: params, keys: keys),
      const RgbSdkFlutter().wallet(params: params, keys: keys),
    ];
    for (final wallet in wallets) {
      expect(wallet.protocol, 'RGB_L1');
      expect(wallet.contractVersion, '1');
      expect(wallet.engine, same(wallet.rgbLibEngine));
      expect(wallet.engine, isA<RgbLibWallet>());
      expect(wallet.rlnEngine, isNull);
      expect(wallet, isNot(isA<RlnWallet>()));
      expect(rgbCalls, isEmpty);
      expect(rlnCalls, isEmpty);
      await wallet.init();
      expect(await wallet.getAddress(), _address);
      await wallet.destroy();
      expect(rgbCalls.map((call) => call.method), [
        'getRuntimeInfo',
        'openWallet',
        'getWalletIdentity',
        'getAddress',
        'closeWallet',
      ]);
      expect(rgbCalls[1].arguments['dataDir'], _storage);
      expect(rlnCalls, isEmpty);
      rgbCalls.clear();
    }
  });

  test('default RGB_L1 failure never creates an RLN fallback', () async {
    final wallet = UtexoWallet(
      params: const RgbLibWalletParams(
        network: 'regtest',
        storageDirPath: _storage,
      ),
      keys: RgbLibKeys.reader(() => 'test-only-key-source'),
    );
    final selected = wallet.engine;
    rgbReply = (call) {
      if (call.method == 'openWallet') {
        throw PlatformException(code: 'NATIVE_BRIDGE_ERROR');
      }
      return defaultRgbReply(call);
    };
    await expectLater(wallet.init(), throwsA(isA<RgbLibWalletException>()));
    expect(wallet.engine, same(selected));
    expect(wallet.protocol, 'RGB_L1');
    expect(wallet.isInitialized, isFalse);
    expect(rlnCalls, isEmpty);
    expect(rgbCalls.map((call) => call.method), [
      'getRuntimeInfo',
      'openWallet',
    ]);
    rgbReply = defaultRgbReply;
    await wallet.init();
    expect(wallet.engine, same(selected));
    expect(await wallet.getAddress(), _address);
    expect(rlnCalls, isEmpty);
    await wallet.destroy();
  });

  test('default construction rejects incomplete or mixed engine input', () {
    const params = RgbLibWalletParams(
      network: 'regtest',
      storageDirPath: _storage,
    );
    final keys = RgbLibKeys.reader(() => 'test-only-key-source');
    final engine = rgbEngine();
    for (final construct in <UtexoWallet Function()>[
      () => UtexoWallet(),
      () => UtexoWallet(params: params),
      () => UtexoWallet(keys: keys),
      () => UtexoWallet(engine: engine, params: params),
      () => UtexoWallet(engine: engine, keys: keys),
      () => UtexoWallet(engine: engine, online: RgbLibUnlockParams()),
      () => const RgbSdkFlutter().wallet(),
    ]) {
      expect(construct, throwsA(isA<WalletValidationException>()));
    }
    expect(rgbCalls, isEmpty);
    expect(rlnCalls, isEmpty);
    expect(engine.isDisposed(), isFalse);
  });

  test('a facade cannot be supplied as another facade engine', () {
    final engines = <WalletEngine>[
      rgbEngine(),
      RlnWallet(config: RlnWalletConfig(storageDirPath: '/private/facade-rln')),
    ];
    for (final engine in engines) {
      final inner = UtexoWallet(engine: engine);
      expect(
        () => UtexoWallet(engine: inner),
        throwsA(isA<WalletValidationException>()),
      );
      expect(
        () => const RgbSdkFlutter().wallet(engine: inner),
        throwsA(isA<WalletValidationException>()),
      );
      final alias = UtexoWallet(engine: inner.engine);
      final store = burn_test.MemoryBurnStore();
      final operations = BurnOperations(inner, store);
      expect(operations.belongsTo(alias), isTrue);
      expect(operations.belongsTo(engine), isTrue);
    }
    expect(rgbCalls, isEmpty);
    expect(rlnCalls, isEmpty);
  });

  test(
    'custom engine shared operations preserve lifecycle and errors',
    () async {
      final engine = _CustomEngine();
      final wallet = UtexoWallet(engine: engine);
      expect(wallet.engine, same(engine));
      expect(wallet.protocol, 'RGB_L1');
      expect(wallet.getNetwork(), 'regtest');
      expect(wallet.rgbLibEngine, isNull);
      expect(wallet.rlnEngine, isNull);
      await wallet.init();
      expect(wallet.isInitialized, isTrue);
      final pending = Completer<String>();
      engine.addressReply = pending.future;
      final address = wallet.getAddress();
      expect(address, same(pending.future));
      pending.complete('custom-engine-address');
      expect(await address, 'custom-engine-address');
      const failure = WalletException('A custom engine failure');
      engine.addressReply = Future.error(failure);
      await expectLater(wallet.getAddress(), throwsA(same(failure)));
      await wallet.shutdown();
      expect(wallet.isShutdown, isTrue);
      await wallet.reinit();
      expect(wallet.isInitialized, isTrue);
      expect(wallet.isShutdown, isFalse);
      for (final operation in <Future<void> Function()>[
        () => wallet.init(password: 'RLN credentials'),
        () => wallet.reinit(unlockConfig: RlnUnlockConfig()),
        () => wallet.unlock(config: RlnUnlockConfig()),
      ]) {
        await expectLater(
          operation,
          throwsA(isA<UnsupportedWalletFeatureException>()),
        );
      }
      await wallet.destroy();
      expect(wallet.isDisposed(), isTrue);
      expect(engine.calls, [
        'init',
        'getAddress',
        'getAddress',
        'shutdown',
        'reinit',
        'destroy',
      ]);
      expect(rgbCalls, isEmpty);
      expect(rlnCalls, isEmpty);
    },
  );

  test('WebRGB never infers native capabilities for a custom engine', () {
    for (final protocol in ['RGB_L1', 'RGB_LN']) {
      final engine = _CustomEngine(protocol: protocol);
      final wallet = UtexoWallet(engine: engine);
      var prompts = 0;
      expect(
        () => WebRgbProvider(
          wallet,
          WebRgbOptions(
            origin: 'https://wallet.example',
            sessionApproved: true,
            confirm: (_) async {
              prompts++;
              return true;
            },
          ),
        ),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      expect(prompts, 0);
      expect(engine.calls, isEmpty);
      expect(wallet.protocol, protocol);
    }
    expect(rgbCalls, isEmpty);
    expect(rlnCalls, isEmpty);
  });

  test('unknown engine contracts are rejected before lifecycle', () {
    final invalidEngines = [
      _CustomEngine(protocol: 'future-protocol'),
      _CustomEngine(contractVersion: '2'),
    ];
    for (final engine in invalidEngines) {
      expect(
        () => UtexoWallet(engine: engine),
        throwsA(isA<WalletValidationException>()),
      );
      expect(engine.calls, isEmpty);
    }
    expect(rgbCalls, isEmpty);
    expect(rlnCalls, isEmpty);
  });

  test('RLN constructor and package helper select RLN explicitly', () async {
    final config = RlnWalletConfig(storageDirPath: '/private/facade-rln-test');
    final wallets = [
      UtexoWallet.rln(config: config),
      const RgbSdkFlutter().rlnWallet(config: config),
    ];
    for (final wallet in wallets) {
      expect(wallet.protocol, 'RGB_LN');
      expect(wallet.contractVersion, '1');
      expect(wallet.engine, same(wallet.rlnEngine));
      expect(wallet.engine, isA<RlnWallet>());
      expect(wallet.rgbLibEngine, isNull);
      expect(wallet, isNot(isA<RlnWallet>()));
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
      expect((rlnCalls.first.$2 as List<Object?>).first, config.storageDirPath);
      rlnCalls.clear();
    }
    expect(rgbCalls, isEmpty);
  });

  test(
    'supplied RLN engine shares its lifecycle across facade aliases',
    () async {
      final engine = RlnWallet(
        config: RlnWalletConfig(storageDirPath: '/private/facade-rln-test'),
      );
      final wallet = UtexoWallet(engine: engine);
      final alias = UtexoWallet(engine: engine);
      expect(wallet.engine, same(engine));
      expect(alias.rlnEngine, same(engine));
      expect(wallet.protocol, 'RGB_LN');
      expect(engine.isInitialized, isFalse);
      expect(rlnCalls, isEmpty);

      await Future.wait([
        engine.init(password: 'test-password'),
        wallet.init(password: 'test-password'),
        alias.initialize(password: 'test-password'),
      ]);
      expect(rlnCalls.map((call) => call.$1), ['rlnCreateNode', 'rlnInitNode']);
      expect(wallet.isInitialized, isTrue);
      expect(alias.isInitialized, isTrue);
      await engine.unlock(password: 'test-password', config: RlnUnlockConfig());
      expect(wallet.isUnlocked, isTrue);
      expect(alias.isUnlocked, isTrue);
      expect(await wallet.getAddress(), _address);
      expect(await alias.getAddress(), _address);
      expect(rlnCalls.where((call) => call.$1 == 'rlnAddress'), hasLength(2));
      for (final call in rlnCalls.where((call) => call.$1 == 'rlnAddress')) {
        expect((call.$2 as List<Object?>).first, 14);
      }
      await alias.shutdown();
      expect(engine.isShutdown, isTrue);
      expect(wallet.isShutdown, isTrue);
      expect(alias.isShutdown, isTrue);
      await engine.destroy();
      expect(wallet.isDisposed(), isTrue);
      expect(alias.isDisposed(), isTrue);
      expect(
        rlnCalls.where((call) => call.$1 == 'rlnCreateNode'),
        hasLength(1),
      );
      expect(
        rlnCalls.where((call) => call.$1 == 'rlnDestroyNode'),
        hasLength(1),
      );
      expect(rgbCalls, isEmpty);
    },
  );

  test(
    'RLN engine and every facade share one uncertain burn journal',
    () async {
      final engine = RlnWallet(
        config: RlnWalletConfig(storageDirPath: '/private/facade-rln-test'),
      );
      final wallet = UtexoWallet(engine: engine);
      final alias = UtexoWallet(engine: engine);
      final store = burn_test.MemoryBurnStore();
      final facadeBurns = BurnOperations(wallet, store);
      final directBurns = BurnOperations(engine, store);
      expect(facadeBurns.belongsTo(engine), isTrue);
      expect(directBurns.belongsTo(alias), isTrue);
      expect(
        () => BurnOperations(alias, burn_test.MemoryBurnStore()),
        throwsA(isA<ConfigurationError>()),
      );
      expect(
        facadeBurns.belongsTo(
          RlnWallet(config: RlnWalletConfig(storageDirPath: '/private/other')),
        ),
        isFalse,
      );
      await wallet.init(password: 'test-password');
      await engine.unlock(password: 'test-password', config: RlnUnlockConfig());
      final webRgb = WebRgbProvider(
        alias,
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
      expect((await webRgb.getInfo()).protocol, 'RGB_LN');
      expect((await webRgb.getInfo()).methods, contains('burnAsset'));
      webRgb.revoke();
      rlnReply = (method, _) {
        if (method == 'rlnBurn') {
          throw PlatformException(code: 'NATIVE_BRIDGE_ERROR');
        }
        return rlnReplies[method];
      };
      await expectLater(
        facadeBurns.execute(burn_test.params, burn_test.metadata, () {}),
        throwsA(isA<RgbSdkException>()),
      );
      expect(
        (await directBurns.records()).single.state,
        BurnOperationState.pending,
      );
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
      expect(rlnCalls.where((call) => call.$1 == 'rlnBurn'), hasLength(1));
      expect(rgbCalls, isEmpty);
      await wallet.destroy();
    },
  );

  test(
    'RGB_L1 dispatch preserves the supplied engine and native session',
    () async {
      final engine = rgbEngine();
      final wallet = UtexoWallet(engine: engine);
      expect(wallet.engine, same(engine));
      expect(wallet.rlnEngine, isNull);
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
      expect(mint?.assetId, _assetId);
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
