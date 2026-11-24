import '../errors/rgb_sdk_exception.dart';
import '../models/rln_models.dart';
import 'rln_wallet.dart';
import 'utexo_wallet.dart';
import 'utexo_wallet_types.dart';

/// Advanced native-shaped compatibility calls on an explicitly selected RLN
/// engine. Prefer [RlnWalletRawApi] on [RlnWallet] for new integrations.
extension UtexoWalletRawApi on UtexoWallet {
  RlnWallet get _rawEngine {
    final selected = rlnEngine;
    if (selected != null) return selected;
    throw const UnsupportedWalletFeatureException(
      'Raw RLN operations require an RGB_LN engine.',
      feature: 'RGB_LN',
    );
  }

  Future<RlnNodeInfo> nodeInfoRaw() => _rawEngine.nodeInfoRaw();
  Future<RlnNodeInfo> getNodeInfoRaw() => _rawEngine.getNodeInfoRaw();
  Future<RlnNetworkInfo> networkInfoRaw() => _rawEngine.networkInfoRaw();
  Future<RlnNetworkInfo> getNetworkInfoRaw() => _rawEngine.getNetworkInfoRaw();
  Future<RlnBtcBalance> getBtcBalanceRaw({bool skipSync = false}) =>
      _rawEngine.getBtcBalanceRaw(skipSync: skipSync);
  Future<List<RlnUnspent>> listUnspentsRaw({bool skipSync = false}) =>
      _rawEngine.listUnspentsRaw(skipSync: skipSync);
  Future<RlnAssets> listAssetsRaw({
    List<String> filterAssetSchemas = const [],
  }) => _rawEngine.listAssetsRaw(filterAssetSchemas: filterAssetSchemas);
  Future<RlnAssetBalance> getAssetBalanceRaw(String assetId) =>
      _rawEngine.getAssetBalanceRaw(assetId);
  Future<RlnAssetNia> issueAssetNiaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) => _rawEngine.issueAssetNiaRaw(
    ticker: ticker,
    name: name,
    precision: precision,
    amounts: amounts,
  );
  Future<RlnAssetIfa> issueAssetIfaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) => _rawEngine.issueAssetIfaRaw(
    ticker: ticker,
    name: name,
    precision: precision,
    amounts: amounts,
    inflationAmounts: inflationAmounts,
    rejectListUrl: rejectListUrl,
  );
  Future<RlnInvoice> blindReceiveRaw(RgbInvoiceRequest request) =>
      _rawEngine.blindReceiveRaw(request);
  Future<RlnInvoice> witnessReceiveRaw(RgbInvoiceRequest request) =>
      _rawEngine.witnessReceiveRaw(request);
  Future<RlnDecodedRgbInvoice> decodeRgbInvoiceRaw(String invoice) =>
      _rawEngine.decodeRgbInvoiceRaw(invoice);
  Future<RlnInflateResult> inflateRaw(InflateAssetIfaRequest request) =>
      _rawEngine.inflateRaw(request);
  Future<List<RlnTransaction>> listTransactionsRaw({bool skipSync = false}) =>
      _rawEngine.listTransactionsRaw(skipSync: skipSync);
  Future<List<RlnTransaction>> listTransactionsByTxidRaw(
    String txid, {
    bool skipSync = false,
  }) => _rawEngine.listTransactionsByTxidRaw(txid, skipSync: skipSync);
  Future<List<RlnTransfer>> listTransfersRaw({String? assetId}) =>
      _rawEngine.listTransfersRaw(assetId: assetId);
  Future<List<RlnTransfer>> listTransfersByTxidRaw(String txid) =>
      _rawEngine.listTransfersByTxidRaw(txid);
  Future<RlnRefreshTransfersResult> refreshTransfersRaw({
    bool skipSync = false,
  }) => _rawEngine.refreshTransfersRaw(skipSync: skipSync);
  Future<RlnFeeRate> estimateFeeRateRaw(int blocks) =>
      _rawEngine.estimateFeeRateRaw(blocks);
  Future<RlnIndexerCheck> checkIndexerUrlRaw(String url) =>
      _rawEngine.checkIndexerUrlRaw(url);
  Future<RlnLnInvoice> createRlnLightningInvoice({
    int? amtMsat,
    int expirySec = 3600,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) => _rawEngine.createRlnLightningInvoice(
    amtMsat: amtMsat,
    expirySec: expirySec,
    assetId: assetId,
    assetAmount: assetAmount,
    paymentHash: paymentHash,
    minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
    descriptionHash: descriptionHash,
    description: description,
  );
  Future<RlnDecodedLnInvoice> decodeLnInvoiceRaw(String invoice) =>
      _rawEngine.decodeLnInvoiceRaw(invoice);
  Future<RlnPaymentResult> payRlnLightningInvoice({
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) => _rawEngine.payRlnLightningInvoice(
    invoice: invoice,
    amtMsat: amtMsat,
    assetId: assetId,
    assetAmount: assetAmount,
  );
  Future<RlnInvoiceStatus> invoiceStatusRaw(String invoice) =>
      _rawEngine.invoiceStatusRaw(invoice);
  Future<List<RlnPayment>> listPaymentsRaw() => _rawEngine.listPaymentsRaw();
  Future<List<RlnPeer>> listPeersRaw() => _rawEngine.listPeersRaw();
  Future<List<RlnChannel>> listChannelsRaw() => _rawEngine.listChannelsRaw();
  Future<RlnOpenChannelResult> openChannelRaw({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) => _rawEngine.openChannelRaw(
    peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
    capacitySat: capacitySat,
    pushMsat: pushMsat,
    publicChannel: publicChannel,
    withAnchors: withAnchors,
    feeBaseMsat: feeBaseMsat,
    feeProportionalMillionths: feeProportionalMillionths,
    temporaryChannelId: temporaryChannelId,
    assetId: assetId,
    assetAmount: assetAmount,
    pushAssetAmount: pushAssetAmount,
    virtualOpenMode: virtualOpenMode,
  );
  Future<RlnPaymentResult> keysendRaw({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) => _rawEngine.keysendRaw(
    destPubkey: destPubkey,
    amtMsat: amtMsat,
    assetId: assetId,
    assetAmount: assetAmount,
  );
  Future<RlnPayment> getPaymentRaw(String paymentHash) =>
      _rawEngine.getPaymentRaw(paymentHash);
}
