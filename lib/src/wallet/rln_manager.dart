import '../binding/rln_binding.dart';
import '../models/burn_models.dart';
import '../models/rln_models.dart';

class RLNManager {
  Future<BfaCapabilities> rlnBfaCapabilities() =>
      rlnBinding.rlnBfaCapabilities();
  Future<BurnResult> rlnBurn(BurnParams params) => rlnBinding.rlnBurn(params);
  Future<String> rlnGetConsignment(String assetId, String txid) =>
      rlnBinding.rlnGetConsignment(assetId, txid);
  Future<String> rlnGetConsignmentPath(String assetId, String txid) =>
      rlnBinding.rlnGetConsignmentPath(assetId, txid);

  RLNManager({RLNBinding? binding}) : rlnBinding = binding ?? RLNBinding();

  final RLNBinding rlnBinding;

  Future<int> rlnCreateNode(IRLNNodeCreateParams params) {
    return rlnBinding.rlnCreateNode(params);
  }

  Future<String> rlnInitNode(String password, [String? mnemonic]) {
    return rlnBinding.rlnInitNode(password, mnemonic);
  }

  Future<void> rlnUnlockNode({
    required String password,
    IRLNUnlockParams? params,
  }) {
    return rlnBinding.rlnUnlockNode(password: password, params: params);
  }

  Future<void> rlnShutdown() => rlnBinding.rlnShutdown();

  Future<void> rlnDestroyNode() => rlnBinding.rlnDestroyNode();

  bool consumeRlnUnlockConflictNormalized() {
    return rlnBinding.consumeRlnUnlockConflictNormalized();
  }

  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network, {
    bool permissivePolicy = true,
    String? storageDirPath,
  }) {
    return rlnBinding.rlnCreateNativeExternalSigner(
      seedHex,
      network,
      permissivePolicy: permissivePolicy,
      storageDirPath: storageDirPath,
    );
  }

  Future<void> rlnInitNodeWithNativeExternalSigner(int signerId) {
    return rlnBinding.rlnInitNodeWithNativeExternalSigner(signerId);
  }

  Future<void> rlnAttachNativeExternalSigner(int signerId) {
    return rlnBinding.rlnAttachNativeExternalSigner(signerId);
  }

  Future<void> rlnUnlockNodeWithNativeExternalSigner(
    int signerId, [
    IRLNUnlockParams? params,
  ]) {
    return rlnBinding.rlnUnlockNodeWithNativeExternalSigner(signerId, params);
  }

  Future<void> rlnDestroyNativeExternalSigner(int signerId) {
    return rlnBinding.rlnDestroyNativeExternalSigner(signerId);
  }

  Future<void> rlnInitNodeWithExternalSigner(
    IRLNExternalSignerBootstrap bootstrap,
  ) {
    return rlnBinding.rlnInitNodeWithExternalSigner(bootstrap);
  }

  Future<RlnNodeInfo> rlnNodeInfo() => rlnBinding.rlnNodeInfo();
  Future<RlnNetworkInfo> rlnNetworkInfo() => rlnBinding.rlnNetworkInfo();
  Future<void> rlnConnectPeer(String peerPubkeyAndAddr) {
    return rlnBinding.rlnConnectPeer(peerPubkeyAndAddr);
  }

  Future<List<RlnPeer>> rlnListPeers() => rlnBinding.rlnListPeers();
  Future<void> rlnDisconnectPeer(String peerPubkey) {
    return rlnBinding.rlnDisconnectPeer(peerPubkey);
  }

  Future<List<RlnChannel>> rlnListChannels() => rlnBinding.rlnListChannels();
  Future<RlnOpenChannelResult> rlnOpenChannel(RlnOpenChannelRequest request) {
    return rlnBinding.rlnOpenChannel(request);
  }

  Future<void> rlnCloseChannel(
    String channelId,
    String peerPubkey,
    bool force,
  ) {
    return rlnBinding.rlnCloseChannel(channelId, peerPubkey, force);
  }

  Future<String> rlnGetChannelId(String temporaryChannelId) {
    return rlnBinding.rlnGetChannelId(temporaryChannelId);
  }

  Future<List<RlnPayment>> rlnListPayments() => rlnBinding.rlnListPayments();
  Future<RlnPayment> rlnGetPayment(String paymentHash) {
    return rlnBinding.rlnGetPayment(paymentHash);
  }

  Future<RlnInvoiceStatus> rlnInvoiceStatus(String invoice) {
    return rlnBinding.rlnInvoiceStatus(invoice);
  }

  Future<RlnLnInvoice> rlnLnInvoice(
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount, {
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) {
    return rlnBinding.rlnLnInvoice(
      amtMsat,
      expirySec,
      assetId,
      assetAmount,
      paymentHash: paymentHash,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
      description: description,
    );
  }

  Future<RlnMap> rlnClaimHodlInvoice(
    String paymentHash,
    String paymentPreimage,
  ) {
    return rlnBinding.rlnClaimHodlInvoice(paymentHash, paymentPreimage);
  }

  Future<void> rlnCancelHodlInvoice(String paymentHash) {
    return rlnBinding.rlnCancelHodlInvoice(paymentHash);
  }

  Future<RlnMap> rlnApayNew(String hostNodeId) {
    return rlnBinding.rlnApayNew(hostNodeId);
  }

  Future<RlnMap> rlnApayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) {
    return rlnBinding.rlnApayNewWithAddress(hostNodeId, username, domain);
  }

  Future<RlnDecodedLnInvoice> rlnDecodeLnInvoice(String invoice) {
    return rlnBinding.rlnDecodeLnInvoice(invoice);
  }

  Future<RlnDecodedRgbInvoice> rlnDecodeRgbInvoice(String invoice) {
    return rlnBinding.rlnDecodeRgbInvoice(invoice);
  }

  Future<RlnPaymentResult> rlnSendPayment(
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  ) {
    return rlnBinding.rlnSendPayment(invoice, amtMsat, assetId, assetAmount);
  }

  Future<RlnPaymentResult> rlnKeysend(
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  ) {
    return rlnBinding.rlnKeysend(destPubkey, amtMsat, assetId, assetAmount);
  }

  Future<RlnAddress> rlnAddress() => rlnBinding.rlnAddress();
  Future<RlnAddress> rlnRotateAddress() => rlnBinding.rlnRotateAddress();
  Future<RlnSignMessageResult> rlnSignMessage(String message) {
    return rlnBinding.rlnSignMessage(message);
  }

  Future<RlnVerifyMessageResult> rlnVerifyMessage(
    String message,
    String signature,
  ) {
    return rlnBinding.rlnVerifyMessage(message, signature);
  }

  Future<RlnBtcBalance> rlnBtcBalance([bool skipSync = false]) {
    return rlnBinding.rlnBtcBalance(skipSync);
  }

  Future<RlnMap> rlnSendBtc(
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  ) {
    return rlnBinding.rlnSendBtc(amount, address, feeRate, skipSync);
  }

  Future<Object?> rlnIssueAssetNia(
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  ) {
    return rlnBinding.rlnIssueAssetNia(ticker, name, precision, amounts);
  }

  Future<Object?> rlnIssueAssetCfa(
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  ) {
    return rlnBinding.rlnIssueAssetCfa(
      name,
      details,
      precision,
      amounts,
      fileDigest,
    );
  }

  Future<Object?> rlnIssueAssetIfa(
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  ) {
    return rlnBinding.rlnIssueAssetIfa(
      ticker,
      name,
      precision,
      amounts,
      inflationAmounts,
      rejectListUrl,
    );
  }

  Future<Object?> rlnIssueAssetUda(
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  ) {
    return rlnBinding.rlnIssueAssetUda(
      ticker,
      name,
      details,
      precision,
      mediaFileDigest,
      attachmentsFileDigests,
    );
  }

  Future<RlnAssets> rlnListAssets(List<String> filterAssetSchemas) {
    return rlnBinding.rlnListAssets(filterAssetSchemas);
  }

  Future<RlnAssetBalance> rlnAssetBalance(String assetId) {
    return rlnBinding.rlnAssetBalance(assetId);
  }

  Future<RlnInvoice> rlnRgbInvoice(
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness, {
    RlnAssignmentKind? assignmentKind,
  }) {
    return rlnBinding.rlnRgbInvoice(
      assetId,
      assignmentAmount,
      durationSeconds,
      minConfirmations,
      witness,
      assignmentKind: assignmentKind,
    );
  }

  Future<RlnSendResult> rlnSendRgb(
    bool donation,
    double feeRate,
    int minConfirmations,
    bool skipSync,
    String assetId,
    String recipientId,
    int amount,
    List<String> transportEndpoints, [
    RlnWitnessData? witnessData,
  ]) {
    return rlnBinding.rlnSendRgb(
      donation,
      feeRate,
      minConfirmations,
      skipSync,
      assetId,
      recipientId,
      amount,
      transportEndpoints,
      witnessData,
    );
  }

  Future<RlnInflateResult> rlnInflate(
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  ) {
    return rlnBinding.rlnInflate(
      assetId,
      inflationAmounts,
      feeRate,
      minConfirmations,
    );
  }

  Future<List<RlnTransaction>> rlnListTransactions(bool skipSync) {
    return rlnBinding.rlnListTransactions(skipSync);
  }

  Future<List<RlnTransaction>> rlnListTransactionsByTxid(
    String txid,
    bool skipSync,
  ) {
    return rlnBinding.rlnListTransactionsByTxid(txid, skipSync);
  }

  Future<List<RlnTransfer>> rlnListTransfers(String assetId) {
    return rlnBinding.rlnListTransfers(assetId);
  }

  Future<List<RlnTransfer>> rlnListTransfersByTxid(String txid) {
    return rlnBinding.rlnListTransfersByTxid(txid);
  }

  Future<List<RlnUnspent>> rlnListUnspents(bool skipSync) {
    return rlnBinding.rlnListUnspents(skipSync);
  }

  Future<RlnRefreshTransfersResult> rlnRefreshTransfers(bool skipSync) {
    return rlnBinding.rlnRefreshTransfers(skipSync);
  }

  Future<RlnMap> rlnFailTransfers(
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  ) {
    return rlnBinding.rlnFailTransfers(batchTransferIdx, noAssetOnly, skipSync);
  }

  Future<RlnFeeRate> rlnEstimateFee(int blocks) {
    return rlnBinding.rlnEstimateFee(blocks);
  }

  Future<RlnIndexerCheck> rlnCheckIndexerUrl(String indexerUrl) {
    return rlnBinding.rlnCheckIndexerUrl(indexerUrl);
  }

  Future<void> rlnCheckProxyEndpoint(String proxyEndpoint) {
    return rlnBinding.rlnCheckProxyEndpoint(proxyEndpoint);
  }

  Future<void> rlnSync() => rlnBinding.rlnSync();

  Future<void> rlnCreateUtxos(
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) {
    return rlnBinding.rlnCreateUtxos(upTo, num, size, feeRate, skipSync);
  }

  Future<void> rlnBackup(String backupPath, String password) {
    return rlnBinding.rlnBackup(backupPath, password);
  }

  Future<void> rlnVssClearFence(String password) {
    return rlnBinding.rlnVssClearFence(password);
  }

  Future<int> rlnVssBackup() => rlnBinding.rlnVssBackup();
}

RLNManager createRLNManager() => RLNManager();
