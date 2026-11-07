import '../../models/burn_models.dart';
import '../../models/utexo_core_models.dart';
import '../../wallet/burn_operations.dart';
import '../../wallet/rgb_lib/rgb_lib_wallet.dart';
import '../../wallet/utexo_wallet.dart';
import '../../wallet/utexo_wallet_types.dart';

/// Shared WebRGB calls without granting either engine the other's capabilities.
final class WebRgbWallet {
  WebRgbWallet.rln(UtexoWallet wallet)
    : burnWallet = wallet,
      protocol = 'RGB_LN',
      getNetwork = wallet.getNetwork,
      isDisposed = wallet.isDisposed,
      getAddress = wallet.getAddress,
      blindReceive = wallet.blindReceive,
      witnessReceive = wallet.witnessReceive,
      listAssets = wallet.listAssets,
      getAssetBalance = wallet.getAssetBalance,
      decodeRgbInvoice = wallet.decodeRgbInvoice,
      refreshWallet = wallet.refreshWallet,
      getBfaCapabilities = wallet.getBfaCapabilities,
      listTransactionsByTxid = wallet.listTransactionsByTxid,
      getBlockHeight = (() async =>
          (await wallet.getNetworkInfo()).blockHeight),
      signMessage = wallet.signMessage;

  WebRgbWallet.rgbLib(RgbLibWallet wallet)
    : burnWallet = wallet,
      protocol = 'RGB_L1',
      getNetwork = wallet.getNetwork,
      isDisposed = wallet.isDisposed,
      getAddress = wallet.getAddress,
      blindReceive = ((request) => wallet.blindReceive(
        assetId: request.assetId,
        amount: request.amount == null ? null : BigInt.from(request.amount!),
        durationSeconds: request.durationSeconds!,
        minConfirmations: request.minConfirmations,
      )),
      witnessReceive = ((request) => wallet.witnessReceive(
        assetId: request.assetId,
        amount: request.amount == null ? null : BigInt.from(request.amount!),
        durationSeconds: request.durationSeconds!,
        minConfirmations: request.minConfirmations,
      )),
      listAssets = wallet.listAssets,
      getAssetBalance = wallet.getAssetBalance,
      decodeRgbInvoice = wallet.decodeRgbInvoice,
      refreshWallet = wallet.refreshWallet,
      getBfaCapabilities = wallet.getBfaCapabilities,
      listTransactionsByTxid = wallet.listTransactionsByTxid,
      getBlockHeight = (() async =>
          (await wallet.getNetworkInfo()).blockHeight),
      signMessage = null;

  final BurnWallet burnWallet;
  final String protocol;
  final String Function() getNetwork;
  final bool Function() isDisposed;
  final Future<String> Function() getAddress;
  final Future<CoreInvoiceReceiveData> Function(RgbInvoiceRequest) blindReceive;
  final Future<CoreInvoiceReceiveData> Function(RgbInvoiceRequest)
  witnessReceive;
  final Future<CoreListAssets> Function() listAssets;
  final Future<CoreAssetBalance> Function(String) getAssetBalance;
  final Future<CoreInvoiceData> Function(String) decodeRgbInvoice;
  final Future<void> Function() refreshWallet;
  final Future<BfaCapabilities> Function() getBfaCapabilities;
  final Future<List<CoreTransaction>> Function(String) listTransactionsByTxid;
  final Future<int?> Function() getBlockHeight;
  final Future<String> Function(String)? signMessage;
}
