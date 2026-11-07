part of 'utexo_wallet.dart';

/// Native-shaped wallet operations for diagnostics, parity testing, and
/// migrations.
///
/// This extension is exported only from `rgb_sdk_flutter_advanced.dart`.
/// Application code should use the canonical methods on [UtexoWallet].
extension UtexoWalletRawApi on UtexoWallet {
  Future<RlnNodeInfo> nodeInfoRaw() => _nodeInfoRaw();

  Future<RlnNodeInfo> getNodeInfoRaw() => _nodeInfoRaw();

  Future<RlnNetworkInfo> networkInfoRaw() => _networkInfoRaw();

  Future<RlnNetworkInfo> getNetworkInfoRaw() => _networkInfoRaw();

  Future<RlnBtcBalance> getBtcBalanceRaw({bool skipSync = false}) {
    return _getBtcBalanceRaw(skipSync: skipSync);
  }

  Future<List<RlnUnspent>> listUnspentsRaw({bool skipSync = false}) {
    return _listUnspentsRaw(skipSync: skipSync);
  }

  Future<RlnAssets> listAssetsRaw({
    List<String> filterAssetSchemas = const [],
  }) {
    return _listAssetsRaw(filterAssetSchemas: filterAssetSchemas);
  }

  Future<RlnAssetBalance> getAssetBalanceRaw(String assetId) {
    return _getAssetBalanceRaw(assetId);
  }

  Future<RlnAssetNia> issueAssetNiaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) {
    return _issueAssetNiaRaw(
      ticker: ticker,
      name: name,
      precision: precision,
      amounts: amounts,
    );
  }

  Future<RlnAssetIfa> issueAssetIfaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) {
    return _issueAssetIfaRaw(
      ticker: ticker,
      name: name,
      precision: precision,
      amounts: amounts,
      inflationAmounts: inflationAmounts,
      rejectListUrl: rejectListUrl,
    );
  }

  Future<RlnInvoice> blindReceiveRaw(RgbInvoiceRequest request) {
    return _blindReceiveRaw(request);
  }

  Future<RlnInvoice> witnessReceiveRaw(RgbInvoiceRequest request) {
    return _witnessReceiveRaw(request);
  }

  Future<RlnDecodedRgbInvoice> decodeRgbInvoiceRaw(String invoice) {
    return _decodeRgbInvoiceRaw(invoice);
  }

  Future<RlnInflateResult> inflateRaw(InflateAssetIfaRequest request) {
    return _inflateRaw(request);
  }

  Future<List<RlnTransaction>> listTransactionsRaw({bool skipSync = false}) {
    return _listTransactionsRaw(skipSync: skipSync);
  }

  Future<List<RlnTransaction>> listTransactionsByTxidRaw(
    String txid, {
    bool skipSync = false,
  }) {
    return _listTransactionsByTxidRaw(txid, skipSync: skipSync);
  }

  Future<List<RlnTransfer>> listTransfersRaw({String? assetId}) {
    return _listTransfersRaw(assetId: assetId);
  }

  Future<List<RlnTransfer>> listTransfersByTxidRaw(String txid) {
    return _listTransfersByTxidRaw(txid);
  }

  Future<RlnRefreshTransfersResult> refreshTransfersRaw({
    bool skipSync = false,
  }) {
    return _refreshTransfersRaw(skipSync: skipSync);
  }

  Future<RlnFeeRate> estimateFeeRateRaw(int blocks) {
    return _estimateFeeRateRaw(blocks);
  }

  Future<RlnIndexerCheck> checkIndexerUrlRaw(String url) {
    return _checkIndexerUrlRaw(url);
  }

  Future<RlnLnInvoice> createRlnLightningInvoice({
    int? amtMsat,
    int expirySec = 3600,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) {
    return _createRlnLightningInvoice(
      amtMsat: amtMsat,
      expirySec: expirySec,
      assetId: assetId,
      assetAmount: assetAmount,
      paymentHash: paymentHash,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
      description: description,
    );
  }

  Future<RlnDecodedLnInvoice> decodeLnInvoiceRaw(String invoice) {
    return _decodeLnInvoiceRaw(invoice);
  }

  Future<RlnPaymentResult> payRlnLightningInvoice({
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _payRlnLightningInvoice(
      invoice: invoice,
      amtMsat: amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
  }

  Future<RlnInvoiceStatus> invoiceStatusRaw(String invoice) {
    return _invoiceStatusRaw(invoice);
  }

  Future<List<RlnPayment>> listPaymentsRaw() => _listPaymentsRaw();

  Future<List<RlnPeer>> listPeersRaw() => _listPeersRaw();

  Future<List<RlnChannel>> listChannelsRaw() => _listChannelsRaw();

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
  }) {
    return _openChannelRaw(
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
  }

  Future<RlnPaymentResult> keysendRaw({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _keysendRaw(
      destPubkey: destPubkey,
      amtMsat: amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    );
  }

  Future<RlnPayment> getPaymentRaw(String paymentHash) {
    return _getPaymentRaw(paymentHash);
  }
}
