import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/rln_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.utexo.rgb_sdk_flutter'),
    swiftOut: 'ios/Classes/RlnApi.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'rgb_sdk_flutter',
  ),
)
class RlnNativeArtifactInfo {
  RlnNativeArtifactInfo({
    required this.platform,
    required this.rlnVersion,
    required this.reactNativeParityVersion,
    required this.bridge,
    required this.nativeArtifact,
  });

  String platform;
  String rlnVersion;
  String reactNativeParityVersion;
  String bridge;
  String nativeArtifact;
}

class RlnWireResponse {
  RlnWireResponse({required this.json});

  String json;
}

class RlnRefreshFailureData {
  RlnRefreshFailureData({required this.name, required this.message});

  String name;
  String message;
}

class RlnRefreshedTransferData {
  RlnRefreshedTransferData({
    required this.index,
    this.updatedStatus,
    this.failure,
  });

  int index;
  String? updatedStatus;
  RlnRefreshFailureData? failure;
}

class RlnRefreshTransfersData {
  RlnRefreshTransfersData({required this.transfers});

  List<RlnRefreshedTransferData> transfers;
}

@HostApi()
abstract class RlnHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnImportRgbContract(
    int nodeId,
    String contractBase64,
    String expectedAssetId,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnBfaCapabilities();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnBurn(
    int nodeId,
    String assetId,
    String amount,
    String? burnRecipient,
    int feeRate,
    int minConfirmations,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnGetConsignment(int nodeId, String assetId, String txid);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnGetConsignmentPath(int nodeId, String assetId, String txid);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnNativeArtifactInfo getNativeArtifactInfo();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int rlnCreateNode(
    String storageDirPath,
    int daemonListeningPort,
    int ldkPeerListeningPort,
    String network,
    int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp,
    bool vssAllowEmptyRestore,
    String? lspBaseUrl,
    String? lspBearerToken,
    bool reuseAddresses,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnInitNode(int nodeId, String password, String? mnemonic);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int rlnCreateNativeExternalSigner(
    String seedHex,
    String network,
    bool permissivePolicy,
    String? storageDirPath,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnInitNodeWithNativeExternalSigner(int nodeId, int signerId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnAttachNativeExternalSigner(int nodeId, int signerId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnUnlockNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
    String? ethRpcUrl,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnDestroyNativeExternalSigner(int signerId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnInitNodeWithExternalSigner(
    int nodeId,
    String nodePublicKeyHex,
    String accountXpubVanilla,
    String accountXpubColored,
    String masterFingerprint,
    String protocolVersion,
    int apiLevel,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnUnlockNode(
    int nodeId,
    String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses,
    String? announceAlias,
    String? gossipRgsServerUrl,
    String? ethRpcUrl,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnDestroyNode(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnNodeInfo(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnNetworkInfo(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListPeers(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnConnectPeer(int nodeId, String peerPubkeyAndAddr);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnDisconnectPeer(int nodeId, String peerPubkey);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListChannels(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnOpenChannel(
    int nodeId,
    String peerPubkeyAndOptAddr,
    int capacitySat,
    int pushMsat,
    bool publicChannel,
    bool withAnchors,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnCloseChannel(
    int nodeId,
    String channelId,
    String peerPubkey,
    bool force,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListPayments(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnAddress(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnRotateAddress(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnSignMessage(int nodeId, String message);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnVerifyMessage(
    int nodeId,
    String message,
    String signature,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnAssetBalance(int nodeId, String assetId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnBackup(int nodeId, String backupPath, String password);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnBtcBalance(int nodeId, bool skipSync);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnCheckIndexerUrl(int nodeId, String indexerUrl);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnCheckProxyEndpoint(int nodeId, String proxyEndpoint);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnCreateUtxos(
    int nodeId,
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnDecodeLnInvoice(int nodeId, String invoice);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnDecodeRgbInvoice(int nodeId, String invoice);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnEstimateFee(int nodeId, int blocks);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnFailTransfers(
    int nodeId,
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnGetChannelId(int nodeId, String temporaryChannelId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnGetPayment(int nodeId, String paymentHash);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnInvoiceStatus(int nodeId, String invoice);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnKeysend(
    int nodeId,
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnListAssets(int nodeId, List<String> filterAssetSchemas);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListTransactions(int nodeId, bool skipSync);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListTransactionsByTxid(
    int nodeId,
    String txid,
    bool skipSync,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListTransfers(int nodeId, String assetId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListTransfersByTxid(int nodeId, String txid);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<RlnWireResponse> rlnListUnspents(int nodeId, bool skipSync);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnLnInvoice(
    int nodeId,
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnClaimHodlInvoice(
    int nodeId,
    String paymentHash,
    String paymentPreimage,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnCancelHodlInvoice(int nodeId, String paymentHash);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnApayNew(int nodeId, String hostNodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnApayNewWithAddress(
    int nodeId,
    String hostNodeId,
    String username,
    String domain,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnRefreshTransfersData rlnRefreshTransfers(int nodeId, bool skipSync);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnRgbInvoice(
    int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
    String? assignmentKind,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnSendBtc(
    int nodeId,
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnPrepareOnchainSend(int nodeId, String requestJson);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnCommitOnchainSend(int nodeId, String requestJson);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnOnchainSendStatus(int nodeId, String requestJson);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String rlnCancelOnchainSend(int nodeId, String requestJson);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnSendPayment(
    int nodeId,
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnSendRgb(
    int nodeId,
    bool donation,
    double feeRate,
    int minConfirmations,
    bool skipSync,
    String assetId,
    String recipientId,
    int amount,
    List<String> transportEndpoints,
    int? witnessAmountSat,
    int? witnessBlinding,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnShutdown(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnSync(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnIssueAssetNia(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnIssueAssetCfa(
    int nodeId,
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnIssueAssetIfa(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnInflate(
    int nodeId,
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  RlnWireResponse rlnIssueAssetUda(
    int nodeId,
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  int rlnVssBackup(int nodeId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void rlnVssClearFence(int nodeId, String password);
}
