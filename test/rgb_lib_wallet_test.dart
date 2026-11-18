import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _txid =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _runtime = {
  'version': RgbLibRuntimeInfo.expectedVersion,
  'sourceRevision': RgbLibRuntimeInfo.expectedSourceRevision,
  'integrationTree': RgbLibRuntimeInfo.expectedIntegrationTree,
  'overlayPatchSha256': RgbLibRuntimeInfo.expectedOverlayPatchSha256,
  'sourceLockSha256': RgbLibRuntimeInfo.expectedSourceLockSha256,
  'sourceManifestSha256': RgbLibRuntimeInfo.expectedSourceManifestSha256,
  'bridgeVersion': RgbLibRuntimeInfo.expectedBridgeVersion,
  'bfa': true,
  'burn': true,
  'consignment': true,
};
const _assetId = 'rgb:asset';
const _fingerprint = 'a1b2c3d4';
const _identity = {
  'id': 'native-identity',
  'network': 'mainnet',
  'masterFingerprint': _fingerprint,
};
const _zeroBalance = {'settled': '0', 'future': '0', 'spendable': '0'};
const _online = 'goOnline';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late FutureOr<Object?> Function(MethodCall) dispatch;
  const path = '/private/wallet';

  RgbLibWallet wallet({
    String network = 'mainnet',
    RgbLibKeys? keys,
    bool allowUtexoDevSignet = false,
    RgbLibUnlockParams? online,
  }) => RgbLibWallet(
    params: RgbLibWalletParams(
      network: network,
      storageDirPath: path,
      allowUtexoDevSignet: allowUtexoDevSignet,
    ),
    keys: keys ?? RgbLibKeys.mnemonic('test key source'),
    online: online,
  );

  setUp(() {
    calls.clear();
    dispatch = (call) => _defaultReply(call.method);
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return dispatch(call);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test(
    'mismatched artifacts fail before reading secrets or opening storage',
    () async {
      var reads = 0;
      dispatch = (call) => {..._runtime, 'sourceRevision': 'wrong'};
      final session = wallet(
        keys: RgbLibKeys.reader(() {
          reads++;
          return 'test key source';
        }),
      );
      await expectLater(
        session.init(),
        throwsA(_code('NATIVE_VERSION_MISMATCH')),
      );
      expect(reads, 0);
      expect(calls.map((c) => c.method), ['getRuntimeInfo']);
    },
  );

  test('absent native module surfaces a typed error', () async {
    messenger.setMockMethodCallHandler(_channel, null);
    await expectLater(
      wallet().init(),
      throwsA(
        _code('NATIVE_BACKEND_UNAVAILABLE')
            .having((e) => e.operation, 'operation', 'init')
            .having((e) => e.protocol, 'protocol', 'RGB_L1'),
      ),
    );
  });

  test(
    'watch-only validates extended keys and blocks signing before connecting',
    () async {
      const invalid = RgbLibPublicKeys(
        accountXpubVanilla: 'xpub-invalid',
        accountXpubColored: 'xpub-invalid',
        masterFingerprint: _fingerprint,
      );
      expect(
        () => wallet(keys: const RgbLibKeys.watchOnly(invalid)),
        throwsA(_code('INVALID_CONFIG')),
      );

      final keys = await deriveKeysFromMnemonic(
        'mainnet',
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      final session = wallet(
        keys: RgbLibKeys.watchOnly(
          RgbLibPublicKeys(
            accountXpubVanilla: keys.accountXpubVanilla,
            accountXpubColored: keys.accountXpubColored,
            masterFingerprint: _fingerprint,
          ),
        ),
      );
      expect(session.contractVersion, '1');
      expect(session.capabilities, (
        canSignTransactions: false,
        psbtSigning: false,
        beginEndFlows: false,
      ));
      await session.init();
      final capabilities = await session.getBfaCapabilities();
      expect(capabilities.burn, isFalse);
      expect(capabilities.consignment, isTrue);
      await expectLater(
        session.sendBtc(address: 'test', amount: 1000, feeRate: 1),
        throwsA(_code('UNSUPPORTED_CAPABILITY')),
      );
      expect(calls.map((c) => c.method), [
        'getRuntimeInfo',
        'openWallet',
        'getWalletIdentity',
      ]);
      expect(calls[1].arguments['mnemonic'], isNull);
      await session.destroy();
    },
  );

  test('shutdown/reinit reads keys again; destroy is terminal', () async {
    var reads = 0;
    final session = wallet(
      keys: RgbLibKeys.reader(() async => 'test-${++reads}'),
    );
    await Future.wait([session.init(), session.init()]);
    expect(reads, 1);
    expect((await session.getWalletIdentity()).id, _identity['id']);
    await session.shutdown();
    await session.reinit();
    expect(reads, 2);
    await session.destroy();
    expect(session.isDisposed(), isTrue);
    await expectLater(session.init(), throwsA(_code('WALLET_DISPOSED')));
  });

  test('a failed key reader is retryable without exposing its error', () async {
    var reads = 0;
    final session = wallet(
      keys: RgbLibKeys.reader(() {
        if (reads++ == 0) throw StateError('private credential payload');
        return 'valid key source';
      }),
    );
    await expectLater(
      session.init(),
      throwsA(
        _code('KEYS_UNAVAILABLE').having(
          (e) => e.toString(),
          'safe message',
          isNot(contains('credential')),
        ),
      ),
    );
    expect(calls.map((c) => c.method), ['getRuntimeInfo']);
    await session.init();
    await session.destroy();
  });

  test(
    'failed close retains ownership until explicit cleanup succeeds',
    () async {
      var closeCount = 0;
      dispatch = (call) {
        if (call.method == 'closeWallet' && closeCount++ == 0) {
          throw PlatformException(
            code: 'NATIVE_BRIDGE_ERROR',
            message: 'private path',
          );
        }
        return _defaultReply(call.method);
      };
      final session = wallet();
      await session.init();
      await expectLater(session.shutdown(), throwsA(_code('NATIVE_ERROR')));
      await expectLater(
        session.getAddress(),
        throwsA(_code('WALLET_STOPPING')),
      );
      await session.shutdown();
      await session.reinit();
      await session.destroy();
      expect(closeCount, 3);
    },
  );

  test(
    'identity mismatch closes the candidate before returning failure',
    () async {
      dispatch = (call) => call.method == 'getWalletIdentity'
          ? {..._identity, 'network': 'signet'}
          : _defaultReply(call.method);
      final session = wallet();
      await expectLater(
        session.init(),
        throwsA(_code('WALLET_CONFIG_MISMATCH')),
      );
      expect(calls.last.method, 'closeWallet');
      await expectLater(
        session.getAddress(),
        throwsA(_code('WALLET_NOT_INITIALIZED')),
      );
    },
  );

  test('concurrent first online reads connect once, then serialize', () async {
    final goOnline = Completer<void>();
    final started = Completer<void>();
    dispatch = (call) {
      if (call.method == _online) {
        started.complete();
        return goOnline.future;
      }
      return _defaultReply(call.method);
    };
    final session = wallet();
    await session.init();
    final first = session.getBtcBalance();
    final second = session.listTransactions();
    await started.future;
    expect(calls.last.method, _online);
    goOnline.complete();
    await Future.wait<Object?>([first, second]);
    expect(calls.map((c) => c.method).skip(3), [
      _online,
      'getBtcBalance',
      'listTransactions',
    ]);
    expect(
      calls[3].arguments['indexerUrl'],
      'ssl://electrs-01.utexo.com:50002',
    );
    expect(calls[4].arguments['skipSync'], isFalse);
    await session.destroy();
  });

  test(
    'regtest never infers deployment and snapshots explicit configuration',
    () async {
      dispatch = (call) => call.method == 'getWalletIdentity'
          ? {..._identity, 'network': 'regtest'}
          : _defaultReply(call.method);
      final session = wallet(network: 'regtest');
      await session.init();
      await expectLater(
        session.getBtcBalance(),
        throwsA(_code('WALLET_OFFLINE')),
      );
      final rpc = {'42161': 'https://example.test'};
      final policies = {
        '42161': const RgbLibEvmChain(
          rpcUrl: 'https://example.test',
          minMintLockBlocks: 2,
          maxMintLockBlocks: 512,
        ),
      };
      final params = RgbLibUnlockParams(
        indexer: const RgbLibIndexer.bitcoindCookie(
          'http://127.0.0.1:18443',
          '/private/.cookie',
        ),
        proxyEndpoint: 'https://proxy.example.test/json-rpc',
        evmRpcUrls: rpc,
        evmChains: policies,
      );
      rpc['42161'] = 'https://unintended.test';
      policies.clear();
      await session.goOnline(params);
      await session.goOnline(params);
      final online = calls.where((call) => call.method == _online).single;
      expect(online.arguments['cookieFile'], '/private/.cookie');
      expect(online.arguments['evmRpcUrls'], ['https://example.test']);
      await expectLater(
        session.goOnline(
          RgbLibUnlockParams(
            indexerUrl: 'ssl://unintended.test:50002',
            proxyEndpoint: 'rpcs://proxy.example.test/json-rpc',
          ),
        ),
        throwsA(_code('WALLET_CONFIG_MISMATCH')),
      );
      await session.destroy();
    },
  );

  test(
    'offline skip-sync reads do not connect or require regtest defaults',
    () async {
      dispatch = (call) => switch (call.method) {
        'getWalletIdentity' => {..._identity, 'network': 'regtest'},
        'listUnspents' => <Object?>[],
        _ => _defaultReply(call.method),
      };
      final session = wallet(network: 'regtest');
      addTearDown(session.destroy);
      await session.init();
      await session.getBtcBalance(skipSync: true);
      await session.listTransactions(skipSync: true);
      await session.listUnspents(skipSync: true);
      expect(calls.skip(3).map((c) => c.method), [
        'getBtcBalance',
        'listTransactions',
        'listUnspents',
      ]);
      expect(
        calls.skip(3).every((c) => c.arguments['skipSync'] == true),
        isTrue,
      );
      await expectLater(
        session.getBtcBalance(),
        throwsA(_code('WALLET_OFFLINE')),
      );
    },
  );

  test('constructor connection stays lazy and resolves EVM policies', () async {
    dispatch = (call) => call.method == 'getWalletIdentity'
        ? {..._identity, 'network': 'regtest'}
        : _defaultReply(call.method);
    final bounds = {'42161': (min: 2, max: 10800)};
    final session = wallet(
      network: 'regtest',
      online: RgbLibUnlockParams(
        indexerUrl: 'https://esplora.example.test',
        proxyEndpoint: 'https://proxy.example.test/json-rpc',
        evmRpcUrls: {
          '42161': 'https://arb.example.test',
          '1': 'https://eth.example.test',
        },
        evmMintLockBlocks: bounds,
      ),
    );
    addTearDown(session.destroy);
    bounds.clear();
    await session.init();
    expect(calls.where((c) => c.method == _online), isEmpty);
    await session.getBtcBalance();
    await session.unlock();
    final config = calls.singleWhere((c) => c.method == _online).arguments;
    expect(config['indexerUrl'], 'https://esplora.example.test');
    expect(config['evmChainIds'], ['1', '42161']);
    expect(config['evmMinMintLockBlocks'], ['1200', '2']);
    expect(config['evmMaxMintLockBlocks'], ['28800', '10800']);
    await session.shutdown();
    await session.reinit(
      RgbLibUnlockParams(
        indexer: const RgbLibIndexer.electrum('tcp://127.0.0.1:55001'),
        evmMintLockBlocks: const {},
      ),
    );
    expect(calls.last.arguments['indexerUrl'], 'tcp://127.0.0.1:55001');
    expect(calls.last.arguments['evmMinMintLockBlocks'], ['1200', '1200']);
    await expectLater(session.reinit(), throwsA(_code('WALLET_INVALID_STATE')));
  });

  test(
    'bad constructor online config and skip-sync send fail before dispatch',
    () async {
      expect(
        () => wallet(
          online: RgbLibUnlockParams(
            evmMintLockBlocks: {'42161': (min: 2, max: 100)},
          ),
        ),
        throwsA(_code('INVALID_CONFIG')),
      );
      await expectLater(
        wallet().onchainSend(
          invoice: 'rgb:invalid',
          feeRate: 1,
          skipSync: true,
        ),
        throwsA(_code('UNSUPPORTED_CAPABILITY')),
      );
      expect(calls, isEmpty);
    },
  );

  test('exact BFA balances and allocations retain all UInt64 digits', () async {
    const units = '18446744073709551615';
    dispatch = (call) => switch (call.method) {
      'getAssetBalance' => {
        'settled': units,
        'future': units,
        'spendable': units,
      },
      'listTransfers' => [
        _transfer('Send', requested: units, allocations: ['7']),
        _transfer('ReceiveWitness', requested: '1', allocations: [units]),
        _transfer('Link', requested: null, allocations: []),
      ],
      _ => _defaultReply(call.method),
    };
    final session = wallet();
    await session.init();
    final balance = await session.getAssetBalance(_assetId);
    expect(balance.spendable.toString(), units);
    final transfers = await session.listTransfers(assetId: _assetId);
    expect(transfers.map((t) => t.amountBaseUnits), [units, units, null]);
    expect(() => transfers.clear(), throwsUnsupportedError);
    await session.destroy();
  });

  test('BFA asset listings preserve exact known circulating supply', () async {
    const units = '18446744073709551615';
    Object? supply = units;
    dispatch = (call) => switch (call.method) {
      'listAssets' => [
        {
          ..._asset('Bfa'),
          'ticker': 'BFA',
          'initialSupply': '1',
          'knownCirculatingSupply': supply,
        },
      ],
      _ => _defaultReply(call.method),
    };
    final session = wallet();
    await session.init();
    final listed = await session.listAssets();
    expect(listed.bfa.single.initialSupply, BigInt.one);
    expect(listed.bfa.single.knownCirculatingSupply, BigInt.parse(units));

    supply = '0';
    expect(
      (await session.listAssets()).bfa.single.knownCirculatingSupply,
      BigInt.zero,
    );
    supply = null;
    expect(
      (await session.listAssets()).bfa.single.knownCirculatingSupply,
      isNull,
    );

    for (final malformed in [42, '-1', '01', '18446744073709551616']) {
      supply = malformed;
      await expectLater(
        session.listAssets(),
        throwsA(isA<NativeProtocolException>()),
      );
    }
    await session.destroy();
  });

  test(
    'transfer history preserves every change output in native order',
    () async {
      final first = {'txid': _txid, 'vout': 3};
      final second = {'txid': 'fe' * 32, 'vout': 1};
      Object? changeOutputs = [first, second];
      dispatch = (call) => switch (call.method) {
        'listTransfers' => [
          {
            ..._transfer('Send', requested: '7', allocations: ['100']),
            'changeUtxos': changeOutputs,
          },
        ],
        _ => _defaultReply(call.method),
      };
      final session = wallet();
      await session.init();
      final CoreTransfer multiple = (await session.listTransfers()).single;
      expect(multiple.changeUtxos.map((output) => (output.txid, output.vout)), [
        (_txid, 3),
        ('fe' * 32, 1),
      ]);
      expect(() => multiple.changeUtxos.clear(), throwsUnsupportedError);
      expect(_legacyChangeOutput(multiple), same(multiple.changeUtxos.first));
      expect(multiple.amount, BigInt.from(7));

      changeOutputs = [second];
      final single = (await session.listTransfers()).single;
      expect(_legacyChangeOutput(single), same(single.changeUtxos.single));
      changeOutputs = <Object?>[];
      final none = (await session.listTransfers()).single;
      expect(none.changeUtxos, isEmpty);
      expect(_legacyChangeOutput(none), isNull);

      changeOutputs = [
        first,
        {'txid': _txid, 'vout': -1},
      ];
      await expectLater(
        session.listTransfers(),
        throwsA(isA<NativeProtocolException>()),
      );
      await session.destroy();
    },
  );

  test('malformed values do not become zero or truncated values', () async {
    dispatch = (call) => switch (call.method) {
      'getAssetBalance' => {
        ..._zeroBalance,
        'spendable': '18446744073709551616',
      },
      'listTransactions' => [
        {'txid': _txid, 'transactionType': 'Incoming', 'received': 1.2},
      ],
      _ => _defaultReply(call.method),
    };
    final session = wallet();
    await session.init();
    await expectLater(
      session.getAssetBalance(_assetId),
      throwsA(isA<NativeProtocolException>()),
    );
    await expectLater(
      session.listTransactions(),
      throwsA(isA<NativeProtocolException>()),
    );
    await session.destroy();
  });

  test(
    'receive validates rights and uses only the configured sender proxy',
    () async {
      final session = wallet();
      await session.init();
      expect(
        () => session.witnessReceive(
          amount: BigInt.one,
          assignmentKind: RgbLibReceiveAssignment.mintRight,
        ),
        throwsA(isA<WalletValidationException>()),
      );
      dispatch = (call) => call.method == 'receive'
          ? {
              'invoice': 'rgb:invoice',
              'recipientId': 'recipient',
              'expirationTimestamp': call.arguments['expirationTimestamp'],
              'batchTransferIdx': 5.0,
              'publicKey': 'public',
            }
          : _defaultReply(call.method);
      await session.witnessReceive(
        assetId: _assetId,
        assignmentKind: RgbLibReceiveAssignment.mintRight,
      );
      expect(calls.last.arguments['transportEndpoints'], [
        'rpcs://rgb-proxy.utexo.com/json-rpc',
      ]);
      expect(calls.last.arguments['assignmentKind'], 'MintRight');
      expect(calls.last.arguments['amount'], isNull);
      await session.destroy();
    },
  );

  test('one-shot send error is redacted and the SDK never resubmits', () async {
    dispatch = (call) {
      if (call.method == 'send') {
        throw PlatformException(
          code: 'RGB_LIB_Internal',
          message: 'private credential payload',
        );
      }
      return _defaultReply(call.method);
    };
    final session = wallet();
    await session.init();
    await expectLater(
      session.onchainSend(
        invoice: 'rgb:invoice',
        feeRate: 1,
        amount: BigInt.one,
      ),
      throwsA(
        _code('NATIVE_ERROR').having(
          (e) => e.toString(),
          'safe message',
          isNot(contains('credential')),
        ),
      ),
    );
    expect(calls.where((call) => call.method == 'send'), hasLength(1));
    expect(session.supportsRecoverableOnchainSend, isFalse);
    await session.destroy();
  });

  test('health preserves the explicitly connected indexer profile', () async {
    final session = wallet();
    await session.init();
    const url = 'https://public-indexer.example.test';
    await session.unlock(
      RgbLibUnlockParams(
        indexer: const RgbLibIndexer.esplora(url),
        proxyEndpoint: 'rpcs://proxy.example.test/json-rpc',
      ),
    );
    dispatch = (call) => call.method == 'checkIndexerUrl'
        ? 'esplora'
        : _defaultReply(call.method);
    expect((await session.checkIndexerUrl(url)).indexerProtocol, 'esplora');
    expect(calls.last.arguments['indexerKind'], 'esplora');
    await session.checkIndexerUrl('https://other-indexer.example.test');
    expect(calls.last.arguments['indexerKind'], isNull);
    await session.destroy();
  });

  test(
    'fee estimates round up and file paths are validated before dispatch',
    () async {
      final session = wallet();
      await session.init();
      expect(await session.estimateFeeRate(6), 2);
      expect(
        () => session.issueAssetCfa(
          name: 'Test',
          precision: 0,
          amounts: [BigInt.one],
          filePath: 'https://unintended.test/file',
        ),
        throwsA(_code('INVALID_CONFIG')),
      );
      expect(
        () => session.issueAssetNia(
          name: 'Test',
          ticker: 'TEST',
          precision: 0,
          amounts: [BigInt.from(9007199254740992)],
        ),
        throwsA(_code('AMOUNT_OVERFLOW')),
      );
      dispatch = (call) => call.method == 'issueAssetCfa'
          ? _asset('Cfa')
          : _defaultReply(call.method);
      final asset = await session.issueAssetCfa(
        name: 'Test',
        precision: 0,
        amounts: [BigInt.one],
        filePath: 'file:///private/media%20file%2520.png',
      );
      expect(asset.issuedSupply, BigInt.one);
      expect(calls.last.arguments['filePath'], '/private/media file%20.png');
      await session.destroy();
    },
  );

  test('Dev Signet fails before secrets or native wallet access', () async {
    var reads = 0;
    final session = wallet(
      network: 'utexo',
      keys: RgbLibKeys.reader(() {
        reads++;
        return 'private test-only key source';
      }),
    );
    final unavailable = isA<WalletException>().having(
      (error) => error.code,
      'code',
      'DEPLOYMENT_UNQUALIFIED',
    );
    await expectLater(session.init(), throwsA(unavailable));
    await expectLater(session.reinit(), throwsA(unavailable));
    await expectLater(
      session.checkIndexerUrl('https://dev.esplora-01.mint.utexo.com'),
      throwsA(unavailable),
    );
    expect(() => getRgbLibNetworkDefaults('utexo'), throwsA(unavailable));
    expect(reads, 0);
    expect(calls, isEmpty);
    await session.destroy();
    expect(calls, isEmpty);
  });

  test('explicit hosted Dev requires a current wrapper before keys', () async {
    var reads = 0;
    final session = wallet(
      network: 'utexo',
      allowUtexoDevSignet: true,
      keys: RgbLibKeys.reader(() {
        reads++;
        return 'private test-only key source';
      }),
    );
    await expectLater(
      session.init(),
      throwsA(_walletCode('DEPLOYMENT_UNQUALIFIED')),
    );
    expect(reads, 0);
    expect(calls.map((call) => call.method), ['getRuntimeInfo']);
    await session.destroy();
  });

  test(
    'explicit hosted Dev validates config and dispatches its resolver',
    () async {
      const indexer = 'https://dev.esplora-01.mint.utexo.com';
      const proxy = 'rpcs://dev.rgb-proxy.utexo.com/json-rpc';
      dispatch = (call) => switch (call.method) {
        'getRuntimeInfo' => {
          ..._runtime,
          'nativeOverlay': 'flutter-bfa7-durable-v1',
          'contractRegistration': true,
          'durableOnchainRecovery': true,
          'supportsHostedDevSignet': true,
          'supportsExistingOnlyOpen': true,
        },
        'getWalletIdentity' => {
          ..._identity,
          'network': 'utexo',
          'id': 'a' * 64,
          'recoveryCohort': 'b' * 32,
        },
        'checkIndexerUrl' => 'esplora',
        _ => _defaultReply(call.method),
      };
      final session = wallet(network: 'utexo', allowUtexoDevSignet: true);
      await expectLater(
        session.openExisting(RgbLibUnlockParams(indexerUrl: indexer)),
        throwsA(_walletCode('DEPLOYMENT_UNQUALIFIED')),
      );
      expect(calls, isEmpty);
      await session.init();
      expect(
        calls[1].arguments['devSignetDeployment'],
        'utexo-dev-busdt-20261109-v1',
      );
      expect(await session.checkIndexerUrl(indexer), (
        indexerProtocol: 'esplora',
      ));
      expect(calls.last.arguments['indexerKind'], 'devSignetEsplora');
      final capabilities = await session.getBfaCapabilities();
      expect(capabilities.bfa, isTrue);
      expect(capabilities.burn, isFalse);
      await expectLater(
        session.burn(
          const BurnParams(
            assetId: _assetId,
            amount: '1',
            feeRate: 1,
            minConfirmations: 3,
          ),
        ),
        throwsA(_code('UNSUPPORTED_CAPABILITY')),
      );
      await expectLater(
        session.getBtcBalance(),
        throwsA(_code('WALLET_OFFLINE')),
      );
      expect(calls.last.method, 'checkIndexerUrl');
      await session.unlock(
        RgbLibUnlockParams(
          indexerUrl: indexer,
          proxyEndpoint: proxy,
          evmChains: const {
            '42161': RgbLibEvmChain(
              rpcUrl: 'https://arb1.arbitrum.io/rpc',
              minMintLockBlocks: 2,
              maxMintLockBlocks: 7200,
            ),
          },
        ),
      );
      expect(calls.last.method, _online);
      expect(calls.last.arguments['indexerKind'], 'devSignetEsplora');
      expect(calls.last.arguments['proxyEndpoint'], proxy);
      expect(calls.last.arguments['evmMaxMintLockBlocks'], ['7200']);
      expect((await session.getWalletIdentity()).network, 'utexo');
      await session.destroy();
    },
  );

  test(
    'only the native missing estimate code maps to FEE_UNAVAILABLE',
    () async {
      String feeCode = 'RGB_LIB_CannotEstimateFees';
      dispatch = (call) {
        if (call.method == 'estimateFeeRate') {
          throw PlatformException(code: feeCode);
        }
        return _defaultReply(call.method);
      };
      final session = wallet();
      await session.init();
      await expectLater(
        session.estimateFeeRate(1),
        throwsA(_code('FEE_UNAVAILABLE')),
      );
      feeCode = 'RGB_LIB_Indexer';
      await expectLater(
        session.estimateFeeRate(1),
        throwsA(_code('NATIVE_ERROR')),
      );
      await session.destroy();
    },
  );

  test('public Signet retains its own chain identity', () async {
    dispatch = (call) => call.method == 'getWalletIdentity'
        ? {..._identity, 'network': 'signet'}
        : _defaultReply(call.method);
    final session = wallet(network: 'signet');
    await session.init();
    expect(calls[1].arguments['network'], 'signet');
    expect((await session.getWalletIdentity()).network, 'signet');
    expect(
      getRgbLibNetworkDefaults('signet')!.proxyEndpoint,
      'rpcs://staging.rgb-proxy.utexo.com/json-rpc',
    );
    await session.destroy();
  });

  test('Dev overrides fail reinit before secrets or native access', () async {
    final configurations = [
      RgbLibUnlockParams(indexerUrl: 'https://dev.esplora-01.mint.utexo.com'),
      RgbLibUnlockParams(
        indexer: const RgbLibIndexer.esplora(
          'https://DEV.ESPLORA-01.MINT.UTEXO.COM./',
        ),
      ),
      RgbLibUnlockParams(
        proxyEndpoint: 'rpcs://dev.rgb-proxy.utexo.com/json-rpc',
      ),
      RgbLibUnlockParams(
        proxyAuthKeys: {'https://dev.rgb-proxy.utexo.com/json-rpc': 'a' * 64},
      ),
      RgbLibUnlockParams(
        evmRpcUrls: {'42161': 'https://dev.esplora-01.mint.utexo.com'},
      ),
    ];
    for (final config in configurations) {
      var reads = 0;
      final session = wallet(
        network: 'signet',
        keys: RgbLibKeys.reader(() {
          reads++;
          return 'private test-only key source';
        }),
      );
      await expectLater(
        session.reinit(config),
        throwsA(
          isA<WalletException>().having(
            (error) => error.code,
            'code',
            'DEPLOYMENT_UNQUALIFIED',
          ),
        ),
      );
      expect(reads, 0);
      expect(calls, isEmpty);
      await session.destroy();
    }
  });

  test(
    'backup restore verifies runtime before handing native the destination',
    () async {
      await RgbLibWallet.restoreFromBackup(
        backupFilePath: '/private/test.backup',
        password: 'test-only-password',
        dataDir: '/private/restore',
      );
      expect(calls.map((c) => c.method), ['getRuntimeInfo', 'restoreBackup']);
      expect(calls.last.arguments['dataDir'], '/private/restore');
    },
  );

  test(
    'canonical file restore and exports use the offline backup route',
    () async {
      const password = 'test-only-password';
      const filePath = '/private/test.backup';
      final restored = await restoreBackupFromFile(
        filePath: filePath,
        password: password,
        dataDir: '/private/restore',
      );
      expect(restored.message, 'Wallet restored successfully');
      expect(calls.map((call) => call.method), [
        'getRuntimeInfo',
        'restoreBackup',
      ]);
      expect(calls.last.arguments, {
        'dataDir': '/private/restore',
        'backupPath': filePath,
        'password': password,
      });

      final session = wallet();
      addTearDown(session.destroy);
      final encrypted = Uint8List.fromList([0, 1, 127, 128, 255]);
      dispatch = (call) => switch (call.method) {
        'backup' => null,
        'exportBackup' => encrypted,
        _ => _defaultReply(call.method),
      };
      await session.init();
      calls.clear();
      final fileExport = await session.exportBackupToFile(
        filePath: filePath,
        password: password,
      );
      expect(fileExport.backupPath, filePath);
      expect(
        await session.createBackup(backupPath: filePath, password: password),
        fileExport,
      );
      expect(await session.exportBackup(password: password), encrypted);
      expect(calls.map((call) => call.method), [
        'backup',
        'backup',
        'exportBackup',
      ]);
      expect(calls.last.arguments, {
        'handle': 'opaque-session',
        'password': password,
      });
    },
  );

  test('backup errors identify the invoked public method', () async {
    const password = 'test-only-password';
    const filePath = '/private/test.backup';
    const dataDir = '/private/restore';
    dispatch = (call) {
      if (call.method == 'backup' || call.method == 'restoreBackup') {
        throw PlatformException(code: 'RECOVERY_BACKUP_INVALID');
      }
      return _defaultReply(call.method);
    };
    final session = wallet();
    addTearDown(session.destroy);
    await session.init();
    final backupCalls = <String, Future<Object?> Function()>{
      'exportBackupToFile': () =>
          session.exportBackupToFile(filePath: filePath, password: password),
      'createBackup': () =>
          session.createBackup(backupPath: filePath, password: password),
      'restoreBackupFromFile': () => restoreBackupFromFile(
        filePath: filePath,
        password: password,
        dataDir: dataDir,
      ),
      'restoreFromBackup': () async {
        await RgbLibWallet.restoreFromBackup(
          backupFilePath: filePath,
          password: password,
          dataDir: dataDir,
        );
        return null;
      },
    };
    for (final entry in backupCalls.entries) {
      await expectLater(
        entry.value(),
        throwsA(
          _code(
            'RECOVERY_BACKUP_INVALID',
          ).having((error) => error.operation, 'operation', entry.key),
        ),
      );
    }
  });

  test(
    'byte backup rejects invalid results and preserves size errors',
    () async {
      final session = wallet();
      addTearDown(session.destroy);
      final outcomes = <Object?>[null, 'AQ==', Uint8List(0)];
      dispatch = (call) {
        if (call.method == 'exportBackup') {
          if (outcomes.isNotEmpty) return outcomes.removeAt(0);
          throw PlatformException(
            code: 'BACKUP_TOO_LARGE',
            message: '/private/cache',
          );
        }
        return _defaultReply(call.method);
      };
      await session.init();
      calls.clear();
      expect(
        () => session.exportBackup(password: ''),
        throwsA(_code('INVALID_CONFIG')),
      );
      expect(calls, isEmpty);
      const password = 'test-only-password';
      for (var index = 0; index < 3; index++) {
        await expectLater(
          session.exportBackup(password: password),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      await expectLater(
        session.exportBackup(password: password),
        throwsA(
          _code('BACKUP_TOO_LARGE').having(
            (error) => error.toString(),
            'safe message',
            isNot(contains('/private/cache')),
          ),
        ),
      );
    },
  );
}

TypeMatcher<RgbLibWalletException> _code(String value) =>
    isA<RgbLibWalletException>().having((error) => error.code, 'code', value);

TypeMatcher<WalletException> _walletCode(String value) =>
    isA<WalletException>().having((error) => error.code, 'code', value);

Outpoint? _legacyChangeOutput(CoreTransfer transfer) {
  // ignore: deprecated_member_use_from_same_package
  return transfer.changeUtxo;
}

Object? _defaultReply(String method) => switch (method) {
  'getRuntimeInfo' => _runtime,
  'openWallet' => 'opaque-session',
  'getWalletIdentity' => _identity,
  'goOnline' || 'closeWallet' || 'restoreBackup' => null,
  'getBtcBalance' => {'vanilla': _zeroBalance, 'colored': _zeroBalance},
  'listTransactions' => <Object?>[],
  'estimateFeeRate' => 1.1,
  _ => throw StateError('Unexpected test operation $method'),
};

Map<String, Object?> _transfer(
  String kind, {
  required String? requested,
  required List<String> allocations,
}) => {
  'idx': 1,
  'batchTransferIdx': 2.0,
  'createdAt': '1',
  'updatedAt': '2',
  'status': 'Settled',
  'kind': kind,
  'requestedAssignment': requested == null
      ? null
      : {'type': 'Fungible', 'amount': requested},
  'assignments': [
    for (final amount in allocations) {'type': 'Fungible', 'amount': amount},
  ],
  'txid': _txid,
  'transportEndpoints': <Object?>[],
  'changeUtxos': <Object?>[],
};

Map<String, Object?> _asset(String schema) => {
  'schema': schema,
  'assetId': _assetId,
  'name': 'Test',
  'precision': 0,
  'timestamp': '1',
  'addedAt': '2',
  'balance': _zeroBalance,
  'issuedSupply': '1',
};
