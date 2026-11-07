import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/src/wallet/rgb_lib/network_profile.dart';

void main() {
  test('logical Dev uses native Signet and explicit checkpoint resolvers', () {
    expect(rgbLibNativeNetwork('utexo'), 'signet');
    expect(rgbLibNativeNetwork('signet'), 'signet');
    expect(rgbLibNativeNetwork('regtest'), 'regtest');
    expect(rgbLibNativeIndexerKind('utexo', 'esplora'), 'devSignetEsplora');
    expect(rgbLibNativeIndexerKind('utexo', 'electrum'), 'devSignetElectrum');
    expect(rgbLibNativeIndexerKind('utexo', 'bitcoind'), isNull);
    for (final kind in ['esplora', 'electrum', 'bitcoind']) {
      expect(rgbLibNativeIndexerKind('signet', kind), kind);
    }
    expect(rgbLibNativeIndexerKind('signet', 'devSignetEsplora'), isNull);
  });
  test(
    'Dev invoice compatibility requires native chain, verified checkpoint and registered asset',
    () {
      bool matches({
        String logical = 'utexo',
        String invoice = 'signet',
        String? resolver = 'devSignetEsplora',
        String? expected = 'rgb:approved',
        String? registered = 'rgb:approved',
        String? invoiceAsset = 'rgb:approved',
      }) => rgbLibInvoiceMatchesProfile(
        logicalNetwork: logical,
        invoiceNetwork: invoice,
        verifiedIndexerKind: resolver,
        expectedAssetId: expected,
        registeredAssetId: registered,
        invoiceAssetId: invoiceAsset,
      );
      expect(matches(), isTrue);
      expect(matches(invoiceAsset: null), isFalse);
      expect(matches(invoice: 'utexo'), isFalse);
      expect(matches(invoice: 'mainnet'), isFalse);
      expect(matches(resolver: 'esplora'), isFalse);
      expect(matches(resolver: null), isFalse);
      expect(matches(registered: null), isFalse);
      expect(matches(registered: 'rgb:other'), isFalse);
      expect(matches(expected: null), isFalse);
      expect(matches(invoiceAsset: 'rgb:other'), isFalse);
      expect(matches(logical: 'signet', resolver: 'esplora'), isTrue);
      expect(matches(logical: 'signet', resolver: 'devSignetEsplora'), isFalse);
      expect(matches(logical: 'signet', invoice: 'utexo'), isFalse);
      expect(matches(logical: 'mainnet', invoice: 'signet'), isFalse);
    },
  );
}
