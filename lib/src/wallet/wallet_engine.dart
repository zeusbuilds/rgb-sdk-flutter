import '../models/utexo_core_models.dart';
import 'burn_operations.dart';
import 'rgb_lib/wire.dart' show RgbLibAssetMetadata;
import 'utexo_wallet_types.dart';

/// Operations with identical meanings on the independent RGB_L1 and RLN engines.
///
/// Engines own their credentials, connection configuration, lifecycle and native
/// session. A facade borrows that same engine; it never opens a second session.
/// Engine-specific configuration and capabilities stay on the typed engine.
abstract interface class WalletEngine implements BurnCapabilityWallet {
  String get protocol;
  String get contractVersion;
  String get network;
  String getNetwork();
  bool get isInitialized;
  bool get isUnlocked;
  bool get isShutdown;
  bool isDisposed();

  Future<void> init();
  Future<void> reinit();
  Future<void> shutdown();
  Future<void> destroy();
  Future<String> getAddress();
  Future<String> rotateVanillaAddress();
  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false});
  Future<CoreAssetBalance> getAssetBalance(String assetId);
  Future<RgbLibAssetMetadata> getAssetMetadata(String assetId);
  Future<List<CoreUnspent>> listUnspents({bool skipSync = false});
  Future<List<CoreTransaction>> listTransactions({bool skipSync = false});
  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  });
  Future<List<CoreTransfer>> listTransfersByTxid(String txid);
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice);
  Future<RefreshTransfersResult> refreshTransfers({bool skipSync = false});
  Future<void> refreshWallet();
  Future<void> syncWallet();
  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  });
  Future<String> getConsignmentPath(String assetId, String txid);
}
