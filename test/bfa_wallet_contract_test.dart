import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

import 'utexo_wallet_test.dart' show FakeRlnHostApi;

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _params = BurnParams(
  assetId: 'rgb:asset',
  amount: '18446744073709551615',
  feeRate: 2,
  minConfirmations: 3,
);

class _Host extends FakeRlnHostApi {
  int burns = 0;
  String? amount;
  String? ethRpc;
  @override
  Future<void> rlnUnlockNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
    String? user,
    String? pass,
    String? host,
    int? port,
    String? indexer,
    String? proxy,
    List<String> addresses,
    String? alias,
    String? rgs,
    String? eth,
  ) async {
    ethRpc = eth;
    await super.rlnUnlockNodeWithNativeExternalSigner(
      nodeId,
      signerId,
      user,
      pass,
      host,
      port,
      indexer,
      proxy,
      addresses,
      alias,
      rgs,
      eth,
    );
  }

  @override
  Future<RlnWireResponse> rlnBfaCapabilities() async =>
      RlnWireResponse(json: '{"burn":true,"consignment":true,"bfa":true}');
  @override
  Future<RlnWireResponse> rlnBurn(
    int nodeId,
    String assetId,
    String amount,
    String? recipient,
    int feeRate,
    int minConfirmations,
  ) async {
    burns++;
    this.amount = amount;
    return RlnWireResponse(
      json: jsonEncode({'txid': 'ab' * 32, 'batchTransferIdx': 42}),
    );
  }

  @override
  Future<String> rlnGetConsignment(
    int nodeId,
    String assetId,
    String txid,
  ) async => 'YWJj';
  @override
  Future<String> rlnGetConsignmentPath(
    int nodeId,
    String assetId,
    String txid,
  ) async => '/wallet/proof';
  @override
  Future<void> rlnUnlockNode(
    int nodeId,
    String password,
    String? user,
    String? pass,
    String? host,
    int? port,
    String? indexer,
    String? proxy,
    List<String> addresses,
    String? alias,
    String? rgs,
    String? eth,
  ) async {
    ethRpc = eth;
    await super.rlnUnlockNode(
      nodeId,
      password,
      user,
      pass,
      host,
      port,
      indexer,
      proxy,
      addresses,
      alias,
      rgs,
      eth,
    );
  }
}

void main() {
  test('BFA capability responses reject missing and non-boolean flags', () {
    for (final value in <Map<Object?, Object?>>[
      {},
      {'burn': true, 'consignment': true},
      {'burn': 1, 'consignment': true, 'bfa': true},
      {'burn': false, 'consignment': 'true', 'bfa': true},
      {'burn': false, 'consignment': true, 'bfa': null},
    ]) {
      expect(
        () => BfaCapabilities.fromMap(value),
        throwsA(isA<NativeProtocolException>()),
      );
    }
    final unavailable = BfaCapabilities.fromMap({
      'burn': false,
      'consignment': false,
      'bfa': false,
    });
    expect(
      unavailable.burn || unavailable.consignment || unavailable.bfa,
      false,
    );
  });

  test(
    'burn native results fail closed on invalid identity or integer range',
    () {
      for (final value in <Map<Object?, Object?>>[
        {},
        {'txid': 'invalid', 'batchTransferIdx': 1},
        {'txid': 'ab' * 32, 'batchTransferIdx': -1},
        {'txid': 'ab' * 32, 'batchTransferIdx': '1'},
        {'txid': 'ab' * 32, 'batchTransferIdx': 9007199254740992},
      ]) {
        expect(
          () => BurnResult.fromMap(value),
          throwsA(isA<NativeProtocolException>()),
        );
      }
    },
  );

  test(
    'canonical BFA methods enforce lifecycle and exact native contract',
    () async {
      final host = _Host();
      final wallet = createAdvancedUtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/bfa-test'),
        signer: PasswordRlnSigner(password: 'test-only', mnemonic: _mnemonic),
        client: RlnClient(hostApi: host),
      );
      addTearDown(wallet.destroy);
      expect((await wallet.getBfaCapabilities()).burn, true);
      await expectLater(wallet.burn(_params), throwsA(isA<WalletException>()));
      expect(host.burns, 0);
      await wallet.init();
      await wallet.unlock(
        config: UtexoUnlockConfig(ethRpcUrl: 'https://eth.example/rpc'),
      );
      expect(host.ethRpc, 'https://eth.example/rpc');
      final burned = await wallet.burn(_params);
      expect(burned.batchTransferIdx, 42);
      expect(host.amount, _params.amount);
      expect(await wallet.getConsignment('rgb:asset', 'ab' * 32), 'YWJj');
      expect(
        await wallet.getConsignmentPath('rgb:asset', 'ab' * 32),
        '/wallet/proof',
      );
      await wallet.shutdown();
      await expectLater(wallet.burn(_params), throwsA(isA<WalletException>()));
      expect(host.burns, 1);
    },
  );

  test(
    'external signer forwards eth RPC but retains RN burn capability policy',
    () async {
      final host = _Host();
      final wallet = createAdvancedUtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/bfa-external'),
        signer: NativeExternalRlnSigner(
          keys: RlnKeyMaterial.mnemonic(_mnemonic),
          network: 'regtest',
        ),
        client: RlnClient(hostApi: host),
      );
      addTearDown(wallet.destroy);
      final caps = await wallet.getBfaCapabilities();
      expect(caps.burn, false);
      expect(caps.consignment, true);
      await wallet.init();
      await wallet.unlock(
        config: UtexoUnlockConfig(ethRpcUrl: 'https://eth.example'),
      );
      expect(host.ethRpc, 'https://eth.example');
      expect(host.unlockNodeCount, 0);
      await expectLater(
        wallet.burn(_params),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      expect(host.burns, 0);
    },
  );

  test(
    'BFA decoding carries full unsigned supply and immutable asset list',
    () {
      final core = RlnAssets.fromMap({
        'bfa': [
          {
            'assetId': 'rgb:bfa',
            'ticker': 'BFA',
            'name': 'Bridged asset',
            'precision': 6,
            'timestamp': 1,
            'addedAt': 2,
            'initialSupply': '18446744073709551615',
            'rejectListUrl': 'https://example/list',
            'balance': {
              'settled': '18446744073709551615',
              'future': '1',
              'spendable': '1',
              'offchainOutbound': '0',
              'offchainInbound': '0',
            },
          },
        ],
        'nia': [],
        'cfa': [],
        'ifa': [],
        'uda': [],
      }).toCore();
      expect(
        core.bfa.single.initialSupply,
        BigInt.parse('18446744073709551615'),
      );
      expect(core.bfa.single.balance.settled, core.bfa.single.initialSupply);
      expect(core.bfa.single.knownCirculatingSupply, isNull);
      expect(core.bfa.single.rejectListUrl, 'https://example/list');
      expect(core.assetIds, ['rgb:bfa']);
      expect(() => core.bfa.clear(), throwsUnsupportedError);
    },
  );

  for (final network in ['mainnet']) {
    test(
      'every RN mainnet Lightning entrypoint fails before native dispatch ($network)',
      () async {
        final host = _Host();
        final wallet = createAdvancedUtexoWallet(
          config: UtexoWalletConfig(
            storageDirPath: '/tmp/mainnet-policy',
            network: network,
          ),
          signer: PasswordRlnSigner(password: 'test-only', mnemonic: _mnemonic),
          client: RlnClient(hostApi: host),
        );
        addTearDown(wallet.destroy);
        final calls = <Future<Object?> Function()>[
          () => wallet.createLightningInvoice(),
          () => wallet.createHodlInvoice(
            CreateHodlInvoiceParams(paymentHash: 'ab' * 32, expirySec: 3600),
          ),
          () => wallet.claimHodlInvoice('ab' * 32, 'cd' * 32),
          () => wallet.cancelHodlInvoice('ab' * 32),
          wallet.listPayments,
          () => wallet.apayNew('node'),
          () => wallet.apayNewWithAddress('node', 'user', 'example.com'),
          wallet.createLsp,
          () => wallet.getLightningReceiveStatus('id'),
          () => wallet.getLightningSendStatus('id'),
          () => wallet.payLightningInvoice(lnInvoice: 'lnbc'),
          wallet.listLightningPayments,
          () => wallet.connectPeer('peer@host:9735'),
          wallet.listPeers,
          () => wallet.disconnectPeer('peer'),
          wallet.listChannels,
          () => wallet.openChannel(peerPubkey: 'peer', capacitySat: 100000),
          () => wallet.closeChannel(channelId: 'channel', peerPubkey: 'peer'),
          () => wallet.getChannelId('temporary'),
          () => wallet.keysend(destPubkey: 'peer', amtMsat: 1000),
          () => wallet.decodeLnInvoice('lnbc'),
          () => wallet.invoiceStatus('lnbc'),
        ];
        for (final call in calls) {
          await expectLater(
            call(),
            throwsA(
              isA<WalletException>().having(
                (error) => error.code,
                'code',
                'LIGHTNING_DISABLED_ON_MAINNET',
              ),
            ),
          );
        }
        expect(host.createNodeCount, 0);
        expect(host.lifecycleCalls, isEmpty);
        await wallet.init();
        await wallet.unlock(config: UtexoUnlockConfig());
        expect(await wallet.getAddress(), 'bcrt1address');
      },
    );
  }
}
