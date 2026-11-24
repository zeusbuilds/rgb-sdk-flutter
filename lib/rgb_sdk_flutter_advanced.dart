/// Advanced RN/native parity entrypoint.
///
/// Import this library only for parity tests, diagnostics, migration tools, or
/// low-level integrations that intentionally need the pinned RN/native shape.
/// App code should prefer `package:rgb_sdk_flutter/rgb_sdk_flutter.dart`.
library;

import 'src/models/utexo_core_models.dart';
import 'src/wallet/utexo_wallet.dart';

export 'rgb_sdk_flutter.dart';
export 'src/binding/rln_binding.dart';
export 'src/client/rln_client.dart';
export 'src/errors/native_bridge_error_mapper.dart';
export 'src/lsp/utexo_lsp_client.dart';
export 'src/models/rln_models.dart';
export 'src/models/utexo_core_models.dart';
export 'src/utils/logger.dart';
export 'src/wallet/network_defaults.dart';
export 'src/wallet/rln_manager.dart';
export 'src/wallet/rln_wallet.dart';
export 'src/wallet/utexo_wallet.dart';
export 'src/wallet/utexo_wallet_raw_compatibility.dart';

/// RN spelling kept behind the advanced/parity import boundary.
extension UtexoWalletRnCompatibility on UtexoWallet {
  Future<CoreInvoiceData> decodeRGBInvoice(String invoice) {
    return decodeRgbInvoice(invoice);
  }
}
