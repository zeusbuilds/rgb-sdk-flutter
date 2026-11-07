import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_public_api_docs.dart';

void main() {
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
