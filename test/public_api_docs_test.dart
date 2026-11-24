import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_public_api_docs.dart';

void main() {
  test(
    'wallet architecture gate rejects engine inheritance and hidden state',
    () {
      final source = File(
        'lib/src/wallet/utexo_wallet.dart',
      ).readAsStringSync();
      expect(walletFacadeArchitectureErrors(source), isEmpty);
      expect(
        walletFacadeArchitectureErrors(
          source.replaceFirst(
            'class UtexoWallet implements',
            'class UtexoWallet extends RlnWallet implements',
          ),
        ),
        contains(contains('without engine inheritance')),
      );
      expect(
        walletFacadeArchitectureErrors(
          source.replaceFirst(
            'final WalletEngine engine;',
            'final WalletEngine engine; int? _nodeId;',
          ),
        ),
        contains(contains('only the immutable engine')),
      );
      expect(
        walletFacadeArchitectureErrors(
          source.replaceFirst('return RgbLibWallet(', 'return RlnWallet('),
        ),
        contains(contains('never implicitly create RLN')),
      );
      expect(
        walletFacadeArchitectureErrors(
          source.replaceFirst(
            'RgbLibWalletParams? params,',
            'RlnWalletConfig? params,',
          ),
        ),
        contains(contains('typed RGB_L1 configuration')),
      );
    },
  );

  test(
    'public symbol enumeration includes final classes and excludes private ones',
    () {
      expect(
        publicSymbolsIn('''
final class RgbLibWallet {}
final class RgbLibRuntimeInfo {}
final class _PrivateWallet {}
abstract interface class BurnCapabilityWallet {}
class ExistingWallet {}
enum RgbLibAssetSchema { nia }
typedef WalletReader = String Function();
'''),
        {
          'RgbLibWallet',
          'RgbLibRuntimeInfo',
          'BurnCapabilityWallet',
          'ExistingWallet',
          'RgbLibAssetSchema',
          'WalletReader',
        },
      );
    },
  );

  test('checklist ignores later sections and prose about public members', () {
    expect(
      checklistSymbols('''
## Before
- `Unrelated`
## Symbol Coverage Checklist
The public wallet exposes `reinit`.
- `UtexoWallet`, `PasswordRlnSigner`
- `StaleExport`
### Checklist notes
`notAnExport`
## Mainnet Support
- `reinit`
- `init`
'''),
      {'UtexoWallet', 'PasswordRlnSigner', 'StaleExport'},
    );
    expect(checklistSymbols('## Other\n- `NotChecklist`\n'), isEmpty);
  });
}
