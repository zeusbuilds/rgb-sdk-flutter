import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/wallet/dev_signet_policy.dart';
import 'package:rgb_sdk_flutter/src/wallet/rgb_lib/config.dart';

import 'utexo_wallet_test.dart' show FakeRlnHostApi;

void main() {
  final unavailable = isA<WalletException>().having(
    (error) => error.code,
    'code',
    'DEPLOYMENT_UNQUALIFIED',
  );

  test('reviewed Dev requirements remain unadmitted and match the runtime', () {
    final requirements = _json('tool/dev_signet_deployment_requirements.json');
    final nativeBaseline = _json('tool/rgb_lib_native_baseline.json');
    final bitcoin = requirements['bitcoin'] as Map<String, Object?>;
    final rgb = requirements['rgb'] as Map<String, Object?>;
    final bundled = requirements['bundledRgbL1'] as Map<String, Object?>;
    final historical =
        requirements['historicalEvidence'] as Map<String, Object?>;
    expect(requirements['enabled'], isFalse);
    expect(requirements['failureCode'], 'DEPLOYMENT_UNQUALIFIED');
    expect(bitcoin['sdkRgbL1Network'], 'utexo');
    expect(utexoDevSignetServiceHosts, {
      Uri.parse(bitcoin['indexerUrl']! as String).host,
      Uri.parse(rgb['proxyEndpoint']! as String).host,
      ...(requirements['formerServiceHosts']! as List<Object?>).cast<String>(),
    });
    expect(rgb['proxyProtocol'], '1.0');
    expect(rgb['schemaCompatibleGenerations'], ['BFA.6', 'BFA.7']);
    expect(rgb['approvedAsset'], isNull);
    expect(rgb['approvedContractBase64'], isNull);
    expect(rgb['approvedContractSha256'], isNull);
    expect(bundled['generation'], 'BFA.7');
    expect(bundled['sourceRevision'], nativeBaseline['sourceRevision']);
    expect(bundled['sourceRevision'], RgbLibRuntimeInfo.expectedSourceRevision);
    expect(bundled['standaloneContractRegistration'], isTrue);
    expect(bundled['durablePaymentRecoveryImplemented'], isTrue);
    expect(bundled['nativeOverlay'], 'flutter-bfa7-durable-v1');
    expect(bundled['durablePaymentRecoveryQualified'], isFalse);
    expect(historical['admitted'], isFalse);
    expect(historical['assetId'], isNot(rgb['reportedDeployedAssetId']));
    expect(
      (bitcoin['checkpoint']! as Map<String, Object?>)['blockHash'],
      isNot(bitcoin['publicSignetBlockOne']),
    );
  });

  test('known Dev services cannot be assigned to another network', () {
    for (final network in ['signet', 'mainnet', 'regtest']) {
      for (final endpoint in [
        'https://dev.esplora-01.mint.utexo.com',
        'https://DEV.ESPLORA-01.MINT.UTEXO.COM.:443/another-path',
        'rpcs://dev.rgb-proxy.utexo.com/json-rpc',
        'https://esplora-api.utexo.com',
        'rpcs://rgb-proxy.dev.utexo.com/json-rpc',
        'esplora-api.utexo.com:443',
        'RGB-PROXY.DEV.UTEXO.COM.:443/json-rpc',
        '//dev.esplora-01.mint.utexo.com/',
      ]) {
        expect(
          () => resolveRgbLibOnline(
            network,
            RgbLibUnlockParams(indexerUrl: endpoint),
          ),
          throwsA(unavailable),
        );
      }
    }
  });

  test('unrelated custom profiles and public Signet remain available', () {
    final result = resolveRgbLibOnline(
      'signet',
      RgbLibUnlockParams(
        indexer: const RgbLibIndexer.esplora('https://indexer.example.test'),
        proxyEndpoint: 'rpcs://proxy.example.test/json-rpc',
        evmChains: const {
          '42161': RgbLibEvmChain(
            rpcUrl: 'https://arb1.arbitrum.io/rpc',
            minMintLockBlocks: 2,
            maxMintLockBlocks: 512,
          ),
        },
      ),
    );
    expect(
      result.nativeArguments['indexerUrl'],
      'https://indexer.example.test',
    );
    expect(result.proxyEndpoint, 'rpcs://proxy.example.test/json-rpc');
    expect(result.nativeArguments['evmChainIds'], ['42161']);
    expect(getRgbLibNetworkDefaults('signet'), isNotNull);
    expect(getRgbLibNetworkDefaults('mainnet'), isNotNull);
    expect(getRgbLibNetworkDefaults('regtest'), isNull);
    // A shared EVM endpoint is not a Bitcoin chain or asset identity.
    expect(
      () => requireQualifiedUtexoDevSignet(
        endpoints: ['https://arb1.arbitrum.io/rpc'],
      ),
      returnsNormally,
    );
  });

  test(
    'legacy RLN rejects Dev overrides before unlock or reinit dispatch',
    () async {
      final host = FakeRlnHostApi();
      final wallet = createAdvancedUtexoWallet(
        config: UtexoWalletConfig(
          storageDirPath: '/private/test-only-dev-gate',
          network: 'signet',
        ),
        client: RlnClient(hostApi: host),
      );
      await wallet.init(password: 'test-only-password');
      final before = List<String>.of(host.lifecycleCalls);
      for (final config in [
        UtexoUnlockConfig(indexerUrl: 'https://dev.esplora-01.mint.utexo.com'),
        UtexoUnlockConfig(
          proxyEndpoint: 'rpcs://dev.rgb-proxy.utexo.com/json-rpc',
        ),
        UtexoUnlockConfig(indexerUrl: 'esplora-api.utexo.com:443'),
        UtexoUnlockConfig(
          ethRpcUrl: 'https://dev.rgb-proxy.utexo.com/json-rpc',
        ),
      ]) {
        await expectLater(
          wallet.unlock(password: 'test-only-password', config: config),
          throwsA(unavailable),
        );
        await expectLater(
          wallet.reinit(password: 'test-only-password', unlockConfig: config),
          throwsA(unavailable),
        );
        expect(host.lifecycleCalls, before);
        expect(host.unlockNodeCount, 0);
      }
      await expectLater(
        wallet.checkIndexerUrl('https://dev.esplora-01.mint.utexo.com'),
        throwsA(unavailable),
      );
      expect(
        () => wallet.checkProxyEndpoint(
          'rpcs://dev.rgb-proxy.utexo.com/json-rpc',
        ),
        throwsA(unavailable),
      );
      expect(host.lifecycleCalls, before);
      await wallet.destroy();
    },
  );

  test(
    'legacy utexo alias still permits an explicit public Signet profile',
    () {
      final config = resolveUnlockParams(
        'utexo',
        UtexoUnlockConfig(
          indexerUrl: 'https://mempool.space/signet/api',
          proxyEndpoint: 'rpcs://proxy.iriswallet.com/0.2/json-rpc',
        ),
      );
      expect(config.indexerUrl, 'https://mempool.space/signet/api');
      expect(config.proxyEndpoint, 'rpcs://proxy.iriswallet.com/0.2/json-rpc');
    },
  );
  test(
    'legacy public Signet default unlock uses the protocol 0.2 proxy',
    () async {
      final host = FakeRlnHostApi();
      final wallet = createAdvancedUtexoWallet(
        config: UtexoWalletConfig(
          storageDirPath: '/private/test-only-public-signet',
          network: 'signet',
        ),
        client: RlnClient(hostApi: host),
      );
      await wallet.init(password: 'test-only-password');
      await wallet.unlock(
        password: 'test-only-password',
        config: UtexoUnlockConfig(),
      );
      expect(host.unlockedIndexerUrl, 'ssl://electrum.iriswallet.com:50033');
      expect(
        host.unlockedProxyEndpoint,
        'rpcs://proxy.iriswallet.com/0.2/json-rpc',
      );
      expect(
        getRgbLibNetworkDefaults('signet')!.proxyEndpoint,
        'rpcs://staging.rgb-proxy.utexo.com/json-rpc',
      );
      await wallet.destroy();
    },
  );
}

Map<String, Object?> _json(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>);
