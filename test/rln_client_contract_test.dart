import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

class _RecordedCall {
  const _RecordedCall(this.method, this.args);

  final String method;
  final List<Object?> args;
}

class _EveryOperationFailsHost implements RlnHostApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw PlatformException(
    code: 'FailedPeerConnection',
    message: 'private native diagnostics',
    details: <String, Object?>{'category': 'network', 'retryable': true},
  );
}

class _ContractCase {
  const _ContractCase({
    required this.name,
    required this.invoke,
    required this.method,
    required this.args,
  });

  final String name;
  final Future<Object?> Function(RlnClient client) invoke;
  final String method;
  final List<Object?> args;
}

class _RecordingRlnHostApi extends RlnHostApi {
  final List<_RecordedCall> calls = <_RecordedCall>[];
  RlnRefreshTransfersData refreshTransfersData = RlnRefreshTransfersData(
    transfers: <RlnRefreshedTransferData>[],
  );

  void _record(String method, List<Object?> args) {
    calls.add(_RecordedCall(method, args));
  }

  Map<Object?, Object?> _map(String method) {
    return <Object?, Object?>{'method': method, 'ok': true};
  }

  RlnWireResponse _wire(String method) {
    return _wireMap(_map(method));
  }

  RlnWireResponse _wireMap(Map<Object?, Object?> map) {
    return RlnWireResponse(json: jsonEncode(map));
  }

  List<RlnWireResponse> _list(String method) {
    return <RlnWireResponse>[
      _wireMap(<Object?, Object?>{
        'method': method,
        'ok': true,
        if (method == 'rlnListUnspents') ...{
          'utxo': {
            'outpoint': '${'ab' * 32}:3',
            'btcAmount': 20000,
            'colorable': true,
            'exists': true,
          },
          'rgbAllocations': <Object?>[],
          'pendingBlinded': 3,
        },
      }),
    ];
  }

  @override
  Future<String> rlnPrepareOnchainSend(int nodeId, String requestJson) async {
    _record('rlnPrepareOnchainSend', [nodeId, requestJson]);
    return '{}';
  }

  @override
  Future<String> rlnCommitOnchainSend(int nodeId, String requestJson) async {
    _record('rlnCommitOnchainSend', [nodeId, requestJson]);
    return '{}';
  }

  @override
  Future<String> rlnOnchainSendStatus(int nodeId, String requestJson) async {
    _record('rlnOnchainSendStatus', [nodeId, requestJson]);
    return '{}';
  }

  @override
  Future<String> rlnCancelOnchainSend(int nodeId, String requestJson) async {
    _record('rlnCancelOnchainSend', [nodeId, requestJson]);
    return '{}';
  }

  @override
  Future<RlnWireResponse> rlnImportRgbContract(
    int nodeId,
    String contractBase64,
    String expectedAssetId,
  ) async {
    _record('rlnImportRgbContract', [nodeId, contractBase64, expectedAssetId]);
    return _wire('rlnImportRgbContract');
  }

  @override
  Future<RlnWireResponse> rlnBfaCapabilities() async {
    _record('rlnBfaCapabilities', []);
    return _wire('rlnBfaCapabilities');
  }

  @override
  Future<RlnWireResponse> rlnBurn(
    int nodeId,
    String assetId,
    String amount,
    String? burnRecipient,
    int feeRate,
    int minConfirmations,
  ) async {
    _record('rlnBurn', [
      nodeId,
      assetId,
      amount,
      burnRecipient,
      feeRate,
      minConfirmations,
    ]);
    return _wire('rlnBurn');
  }

  @override
  Future<String> rlnGetConsignment(
    int nodeId,
    String assetId,
    String txid,
  ) async {
    _record('rlnGetConsignment', [nodeId, assetId, txid]);
    return 'cHJvb2Y=';
  }

  @override
  Future<String> rlnGetConsignmentPath(
    int nodeId,
    String assetId,
    String txid,
  ) async {
    _record('rlnGetConsignmentPath', [nodeId, assetId, txid]);
    return '/wallet/proof';
  }

  @override
  Future<RlnNativeArtifactInfo> getNativeArtifactInfo() async {
    _record('getNativeArtifactInfo', <Object?>[]);
    return RlnNativeArtifactInfo(
      platform: 'test',
      rlnVersion: '0.0.0',
      reactNativeParityVersion: '0.0.0',
      bridge: 'fake',
      nativeArtifact: 'fake',
    );
  }

  @override
  Future<int> rlnCreateNode(
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
  ) async {
    _record('rlnCreateNode', <Object?>[
      storageDirPath,
      daemonListeningPort,
      ldkPeerListeningPort,
      network,
      maxMediaUploadSizeMb,
      enableVirtualChannelsV0,
      virtualPeerPubkeys,
      vssUrl,
      vssAllowHttp,
      vssAllowEmptyRestore,
      lspBaseUrl,
      lspBearerToken,
      reuseAddresses,
    ]);
    return 101;
  }

  @override
  Future<String> rlnInitNode(
    int nodeId,
    String password,
    String? mnemonic,
  ) async {
    _record('rlnInitNode', <Object?>[nodeId, password, mnemonic]);
    return 'pubkey';
  }

  @override
  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network,
    bool permissivePolicy,
    String? storageDirPath,
  ) async {
    _record('rlnCreateNativeExternalSigner', <Object?>[
      seedHex,
      network,
      permissivePolicy,
      storageDirPath,
    ]);
    return 202;
  }

  @override
  Future<void> rlnInitNodeWithNativeExternalSigner(
    int nodeId,
    int signerId,
  ) async {
    _record('rlnInitNodeWithNativeExternalSigner', <Object?>[nodeId, signerId]);
  }

  @override
  Future<void> rlnAttachNativeExternalSigner(int nodeId, int signerId) async {
    _record('rlnAttachNativeExternalSigner', <Object?>[nodeId, signerId]);
  }

  @override
  Future<void> rlnUnlockNodeWithNativeExternalSigner(
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
  ) async {
    _record('rlnUnlockNodeWithNativeExternalSigner', <Object?>[
      nodeId,
      signerId,
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
      indexerUrl,
      proxyEndpoint,
      announceAddresses,
      announceAlias,
      gossipRgsServerUrl,
      ethRpcUrl,
    ]);
  }

  @override
  Future<void> rlnDestroyNativeExternalSigner(int signerId) async {
    _record('rlnDestroyNativeExternalSigner', <Object?>[signerId]);
  }

  @override
  Future<void> rlnInitNodeWithExternalSigner(
    int nodeId,
    String nodePublicKeyHex,
    String accountXpubVanilla,
    String accountXpubColored,
    String masterFingerprint,
    String protocolVersion,
    int apiLevel,
  ) async {
    _record('rlnInitNodeWithExternalSigner', <Object?>[
      nodeId,
      nodePublicKeyHex,
      accountXpubVanilla,
      accountXpubColored,
      masterFingerprint,
      protocolVersion,
      apiLevel,
    ]);
  }

  @override
  Future<void> rlnUnlockNode(
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
  ) async {
    _record('rlnUnlockNode', <Object?>[
      nodeId,
      password,
      bitcoindRpcUsername,
      bitcoindRpcPassword,
      bitcoindRpcHost,
      bitcoindRpcPort,
      indexerUrl,
      proxyEndpoint,
      announceAddresses,
      announceAlias,
      gossipRgsServerUrl,
      ethRpcUrl,
    ]);
  }

  @override
  Future<void> rlnDestroyNode(int nodeId) async {
    _record('rlnDestroyNode', <Object?>[nodeId]);
  }

  @override
  Future<RlnWireResponse> rlnNodeInfo(int nodeId) async {
    _record('rlnNodeInfo', <Object?>[nodeId]);
    return _wire('rlnNodeInfo');
  }

  @override
  Future<RlnWireResponse> rlnNetworkInfo(int nodeId) async {
    _record('rlnNetworkInfo', <Object?>[nodeId]);
    return _wire('rlnNetworkInfo');
  }

  @override
  Future<List<RlnWireResponse>> rlnListPeers(int nodeId) async {
    _record('rlnListPeers', <Object?>[nodeId]);
    return _list('rlnListPeers');
  }

  @override
  Future<void> rlnConnectPeer(int nodeId, String peerPubkeyAndAddr) async {
    _record('rlnConnectPeer', <Object?>[nodeId, peerPubkeyAndAddr]);
  }

  @override
  Future<void> rlnDisconnectPeer(int nodeId, String peerPubkey) async {
    _record('rlnDisconnectPeer', <Object?>[nodeId, peerPubkey]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListChannels(int nodeId) async {
    _record('rlnListChannels', <Object?>[nodeId]);
    return _list('rlnListChannels');
  }

  @override
  Future<RlnWireResponse> rlnOpenChannel(
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
  ) async {
    _record('rlnOpenChannel', <Object?>[
      nodeId,
      peerPubkeyAndOptAddr,
      capacitySat,
      pushMsat,
      publicChannel,
      withAnchors,
      feeBaseMsat,
      feeProportionalMillionths,
      temporaryChannelId,
      assetId,
      assetAmount,
      pushAssetAmount,
      virtualOpenMode,
    ]);
    return _wire('rlnOpenChannel');
  }

  @override
  Future<void> rlnCloseChannel(
    int nodeId,
    String channelId,
    String peerPubkey,
    bool force,
  ) async {
    _record('rlnCloseChannel', <Object?>[nodeId, channelId, peerPubkey, force]);
  }

  @override
  Future<List<RlnWireResponse>> rlnListPayments(int nodeId) async {
    _record('rlnListPayments', <Object?>[nodeId]);
    return _list('rlnListPayments');
  }

  @override
  Future<RlnWireResponse> rlnAddress(int nodeId) async {
    _record('rlnAddress', <Object?>[nodeId]);
    return _wire('rlnAddress');
  }

  @override
  Future<RlnWireResponse> rlnRotateAddress(int nodeId) async {
    _record('rlnRotateAddress', <Object?>[nodeId]);
    return _wire('rlnRotateAddress');
  }

  @override
  Future<RlnWireResponse> rlnSignMessage(int nodeId, String message) async {
    _record('rlnSignMessage', <Object?>[nodeId, message]);
    return _wire('rlnSignMessage');
  }

  @override
  Future<RlnWireResponse> rlnVerifyMessage(
    int nodeId,
    String message,
    String signature,
  ) async {
    _record('rlnVerifyMessage', <Object?>[nodeId, message, signature]);
    return _wire('rlnVerifyMessage');
  }

  @override
  Future<RlnWireResponse> rlnAssetBalance(int nodeId, String assetId) async {
    _record('rlnAssetBalance', <Object?>[nodeId, assetId]);
    return _wire('rlnAssetBalance');
  }

  @override
  Future<void> rlnBackup(int nodeId, String backupPath, String password) async {
    _record('rlnBackup', <Object?>[nodeId, backupPath, password]);
  }

  @override
  Future<RlnWireResponse> rlnBtcBalance(int nodeId, bool skipSync) async {
    _record('rlnBtcBalance', <Object?>[nodeId, skipSync]);
    return _wire('rlnBtcBalance');
  }

  @override
  Future<RlnWireResponse> rlnCheckIndexerUrl(
    int nodeId,
    String indexerUrl,
  ) async {
    _record('rlnCheckIndexerUrl', <Object?>[nodeId, indexerUrl]);
    return _wire('rlnCheckIndexerUrl');
  }

  @override
  Future<void> rlnCheckProxyEndpoint(int nodeId, String proxyEndpoint) async {
    _record('rlnCheckProxyEndpoint', <Object?>[nodeId, proxyEndpoint]);
  }

  @override
  Future<void> rlnCreateUtxos(
    int nodeId,
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) async {
    _record('rlnCreateUtxos', <Object?>[
      nodeId,
      upTo,
      num,
      size,
      feeRate,
      skipSync,
    ]);
  }

  @override
  Future<RlnWireResponse> rlnDecodeLnInvoice(int nodeId, String invoice) async {
    _record('rlnDecodeLnInvoice', <Object?>[nodeId, invoice]);
    return _wire('rlnDecodeLnInvoice');
  }

  @override
  Future<RlnWireResponse> rlnDecodeRgbInvoice(
    int nodeId,
    String invoice,
  ) async {
    _record('rlnDecodeRgbInvoice', <Object?>[nodeId, invoice]);
    return _wire('rlnDecodeRgbInvoice');
  }

  @override
  Future<RlnWireResponse> rlnEstimateFee(int nodeId, int blocks) async {
    _record('rlnEstimateFee', <Object?>[nodeId, blocks]);
    return _wire('rlnEstimateFee');
  }

  @override
  Future<RlnWireResponse> rlnFailTransfers(
    int nodeId,
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  ) async {
    _record('rlnFailTransfers', <Object?>[
      nodeId,
      batchTransferIdx,
      noAssetOnly,
      skipSync,
    ]);
    return _wire('rlnFailTransfers');
  }

  @override
  Future<String> rlnGetChannelId(int nodeId, String temporaryChannelId) async {
    _record('rlnGetChannelId', <Object?>[nodeId, temporaryChannelId]);
    return 'channel-id';
  }

  @override
  Future<RlnWireResponse> rlnGetPayment(int nodeId, String paymentHash) async {
    _record('rlnGetPayment', <Object?>[nodeId, paymentHash]);
    return _wire('rlnGetPayment');
  }

  @override
  Future<RlnWireResponse> rlnInvoiceStatus(int nodeId, String invoice) async {
    _record('rlnInvoiceStatus', <Object?>[nodeId, invoice]);
    return _wire('rlnInvoiceStatus');
  }

  @override
  Future<RlnWireResponse> rlnKeysend(
    int nodeId,
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    _record('rlnKeysend', <Object?>[
      nodeId,
      destPubkey,
      amtMsat,
      assetId,
      assetAmount,
    ]);
    return _wire('rlnKeysend');
  }

  @override
  Future<RlnWireResponse> rlnListAssets(
    int nodeId,
    List<String> filterAssetSchemas,
  ) async {
    _record('rlnListAssets', <Object?>[nodeId, filterAssetSchemas]);
    return _wire('rlnListAssets');
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransactions(
    int nodeId,
    bool skipSync,
  ) async {
    _record('rlnListTransactions', <Object?>[nodeId, skipSync]);
    return _list('rlnListTransactions');
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransactionsByTxid(
    int nodeId,
    String txid,
    bool skipSync,
  ) async {
    _record('rlnListTransactionsByTxid', <Object?>[nodeId, txid, skipSync]);
    return _list('rlnListTransactionsByTxid');
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransfers(
    int nodeId,
    String assetId,
  ) async {
    _record('rlnListTransfers', <Object?>[nodeId, assetId]);
    return _list('rlnListTransfers');
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransfersByTxid(
    int nodeId,
    String txid,
  ) async {
    _record('rlnListTransfersByTxid', <Object?>[nodeId, txid]);
    return _list('rlnListTransfersByTxid');
  }

  @override
  Future<List<RlnWireResponse>> rlnListUnspents(
    int nodeId,
    bool skipSync,
  ) async {
    _record('rlnListUnspents', <Object?>[nodeId, skipSync]);
    return _list('rlnListUnspents');
  }

  @override
  Future<RlnWireResponse> rlnLnInvoice(
    int nodeId,
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  ) async {
    _record('rlnLnInvoice', <Object?>[
      nodeId,
      amtMsat,
      expirySec,
      assetId,
      assetAmount,
      paymentHash,
      minFinalCltvExpiryDelta,
      descriptionHash,
      description,
    ]);
    return _wire('rlnLnInvoice');
  }

  @override
  Future<RlnWireResponse> rlnClaimHodlInvoice(
    int nodeId,
    String paymentHash,
    String paymentPreimage,
  ) async {
    _record('rlnClaimHodlInvoice', <Object?>[
      nodeId,
      paymentHash,
      paymentPreimage,
    ]);
    return _wireMap(<Object?, Object?>{'changed': true});
  }

  @override
  Future<void> rlnCancelHodlInvoice(int nodeId, String paymentHash) async {
    _record('rlnCancelHodlInvoice', <Object?>[nodeId, paymentHash]);
  }

  @override
  Future<RlnWireResponse> rlnApayNew(int nodeId, String hostNodeId) async {
    _record('rlnApayNew', <Object?>[nodeId, hostNodeId]);
    return _wire('rlnApayNew');
  }

  @override
  Future<RlnWireResponse> rlnApayNewWithAddress(
    int nodeId,
    String hostNodeId,
    String username,
    String domain,
  ) async {
    _record('rlnApayNewWithAddress', <Object?>[
      nodeId,
      hostNodeId,
      username,
      domain,
    ]);
    return _wire('rlnApayNewWithAddress');
  }

  @override
  Future<RlnRefreshTransfersData> rlnRefreshTransfers(
    int nodeId,
    bool skipSync,
  ) async {
    _record('rlnRefreshTransfers', <Object?>[nodeId, skipSync]);
    return refreshTransfersData;
  }

  @override
  Future<RlnWireResponse> rlnRgbInvoice(
    int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness,
    String? assignmentKind,
  ) async {
    _record('rlnRgbInvoice', <Object?>[
      nodeId,
      assetId,
      assignmentAmount,
      durationSeconds,
      minConfirmations,
      witness,
      assignmentKind,
    ]);
    return _wire('rlnRgbInvoice');
  }

  @override
  Future<RlnWireResponse> rlnSendBtc(
    int nodeId,
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  ) async {
    _record('rlnSendBtc', <Object?>[
      nodeId,
      amount,
      address,
      feeRate,
      skipSync,
    ]);
    return _wire('rlnSendBtc');
  }

  @override
  Future<RlnWireResponse> rlnSendPayment(
    int nodeId,
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    _record('rlnSendPayment', <Object?>[
      nodeId,
      invoice,
      amtMsat,
      assetId,
      assetAmount,
    ]);
    return _wire('rlnSendPayment');
  }

  @override
  Future<RlnWireResponse> rlnSendRgb(
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
  ) async {
    _record('rlnSendRgb', <Object?>[
      nodeId,
      donation,
      feeRate,
      minConfirmations,
      skipSync,
      assetId,
      recipientId,
      amount,
      transportEndpoints,
      witnessAmountSat,
      witnessBlinding,
    ]);
    return _wire('rlnSendRgb');
  }

  @override
  Future<void> rlnShutdown(int nodeId) async {
    _record('rlnShutdown', <Object?>[nodeId]);
  }

  @override
  Future<void> rlnSync(int nodeId) async {
    _record('rlnSync', <Object?>[nodeId]);
  }

  @override
  Future<RlnWireResponse> rlnAssetMetadata(int nodeId, String assetId) async {
    _record('rlnAssetMetadata', <Object?>[nodeId, assetId]);
    return _wire('rlnAssetMetadata');
  }

  @override
  Future<RlnWireResponse> rlnPostAssetMedia(int nodeId, Uint8List bytes) async {
    _record('rlnPostAssetMedia', <Object?>[nodeId, bytes]);
    return _wire('rlnPostAssetMedia');
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetNia(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  ) async {
    _record('rlnIssueAssetNia', <Object?>[
      nodeId,
      ticker,
      name,
      precision,
      amounts,
    ]);
    return _wire('rlnIssueAssetNia');
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetCfa(
    int nodeId,
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  ) async {
    _record('rlnIssueAssetCfa', <Object?>[
      nodeId,
      name,
      details,
      precision,
      amounts,
      fileDigest,
    ]);
    return _wire('rlnIssueAssetCfa');
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetIfa(
    int nodeId,
    String ticker,
    String name,
    int precision,
    List<int> amounts,
    List<int> inflationAmounts,
    String? rejectListUrl,
  ) async {
    _record('rlnIssueAssetIfa', <Object?>[
      nodeId,
      ticker,
      name,
      precision,
      amounts,
      inflationAmounts,
      rejectListUrl,
    ]);
    return _wire('rlnIssueAssetIfa');
  }

  @override
  Future<RlnWireResponse> rlnInflate(
    int nodeId,
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  ) async {
    _record('rlnInflate', <Object?>[
      nodeId,
      assetId,
      inflationAmounts,
      feeRate,
      minConfirmations,
    ]);
    return _wire('rlnInflate');
  }

  @override
  Future<RlnWireResponse> rlnIssueAssetUda(
    int nodeId,
    String ticker,
    String name,
    String? details,
    int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests,
  ) async {
    _record('rlnIssueAssetUda', <Object?>[
      nodeId,
      ticker,
      name,
      details,
      precision,
      mediaFileDigest,
      attachmentsFileDigests,
    ]);
    return _wire('rlnIssueAssetUda');
  }

  @override
  Future<void> rlnVssClearFence(int nodeId, String password) async {
    _record('rlnVssClearFence', <Object?>[nodeId, password]);
  }

  @override
  Future<int> rlnVssBackup(int nodeId) async {
    _record('rlnVssBackup', <Object?>[nodeId]);
    return 1;
  }
}

class _ThrowingRlnHostApi extends _RecordingRlnHostApi {
  @override
  Future<RlnWireResponse> rlnNodeInfo(int nodeId) async {
    throw PlatformException(
      code: 'RlnError',
      message: 'native message text can change without changing taxonomy',
      details: <String, Object?>{
        'operation': 'rlnNodeInfo',
        'category': 'invalidRequest',
        'retryable': false,
      },
    );
  }
}

class _MalformedWireRlnHostApi extends _RecordingRlnHostApi {
  @override
  Future<RlnWireResponse> rlnSignMessage(int nodeId, String message) async {
    return RlnWireResponse(json: '{not-json');
  }

  @override
  Future<RlnWireResponse> rlnVerifyMessage(
    int nodeId,
    String message,
    String signature,
  ) async {
    return RlnWireResponse(json: '["not", "an", "object"]');
  }

  @override
  Future<List<RlnWireResponse>> rlnListTransactionsByTxid(
    int nodeId,
    String txid,
    bool skipSync,
  ) async {
    return <RlnWireResponse>[
      RlnWireResponse(json: '{"txid":"ok"}'),
      RlnWireResponse(json: '42'),
    ];
  }
}

class _InvalidJsonHostApi extends _RecordingRlnHostApi {
  _InvalidJsonHostApi(this.json);

  final String json;

  @override
  RlnWireResponse _wireMap(Map<Object?, Object?> map) =>
      RlnWireResponse(json: json);

  @override
  List<RlnWireResponse> _list(String method) => <RlnWireResponse>[
    RlnWireResponse(json: '{"valid":"prefix"}'),
    RlnWireResponse(json: json),
    RlnWireResponse(json: '{"valid":"suffix"}'),
  ];
}

void main() {
  const nodeId = 7;
  const signerId = 9;
  const announceAddresses = <String>['127.0.0.1:9735'];
  const schemas = <String>['nia', 'uda'];
  const amounts = <int>[100, 200];
  const inflationAmounts = <int>[10, 20];
  const transports = <String>['rpc://127.0.0.1:3003/json-rpc'];
  const attachments = <String>['attachment-digest'];
  const seedHex =
      '0000000000000000000000000000000000000000000000000000000000000000';

  final cases = <_ContractCase>[
    _ContractCase(
      name: 'prepareOnchainSend',
      invoke: (client) => client.prepareOnchainSend(
        nodeId: nodeId,
        requestJson: 'opaque-input',
      ),
      method: 'rlnPrepareOnchainSend',
      args: const <Object?>[nodeId, 'opaque-input'],
    ),
    _ContractCase(
      name: 'commitOnchainSend',
      invoke: (client) =>
          client.commitOnchainSend(nodeId: nodeId, requestJson: 'opaque-input'),
      method: 'rlnCommitOnchainSend',
      args: const <Object?>[nodeId, 'opaque-input'],
    ),
    _ContractCase(
      name: 'onchainSendStatus',
      invoke: (client) =>
          client.onchainSendStatus(nodeId: nodeId, requestJson: 'opaque-input'),
      method: 'rlnOnchainSendStatus',
      args: const <Object?>[nodeId, 'opaque-input'],
    ),
    _ContractCase(
      name: 'cancelOnchainSend',
      invoke: (client) =>
          client.cancelOnchainSend(nodeId: nodeId, requestJson: 'opaque-input'),
      method: 'rlnCancelOnchainSend',
      args: const <Object?>[nodeId, 'opaque-input'],
    ),
    _ContractCase(
      name: 'importRgbContract',
      invoke: (client) => client.importRgbContract(
        nodeId: nodeId,
        contractBase64: 'YWJj',
        expectedAssetId: 'rgb:asset',
      ),
      method: 'rlnImportRgbContract',
      args: const [nodeId, 'YWJj', 'rgb:asset'],
    ),
    _ContractCase(
      name: 'bfaCapabilities',
      invoke: (client) => client.bfaCapabilities(),
      method: 'rlnBfaCapabilities',
      args: const [],
    ),
    _ContractCase(
      name: 'burn',
      invoke: (client) => client.burn(
        nodeId: nodeId,
        assetId: 'rgb:asset',
        amount: '18446744073709551615',
        burnRecipient: 'ab' * 32,
        feeRate: 2,
        minConfirmations: 3,
      ),
      method: 'rlnBurn',
      args: [nodeId, 'rgb:asset', '18446744073709551615', 'ab' * 32, 2, 3],
    ),
    _ContractCase(
      name: 'getConsignment',
      invoke: (client) => client.getConsignment(nodeId, 'rgb:asset', 'ab' * 32),
      method: 'rlnGetConsignment',
      args: [nodeId, 'rgb:asset', 'ab' * 32],
    ),
    _ContractCase(
      name: 'getConsignmentPath',
      invoke: (client) =>
          client.getConsignmentPath(nodeId, 'rgb:asset', 'ab' * 32),
      method: 'rlnGetConsignmentPath',
      args: [nodeId, 'rgb:asset', 'ab' * 32],
    ),
    _ContractCase(
      name: 'createNode',
      invoke: (client) => client.createNode(
        storageDirPath: '/tmp/rln',
        daemonListeningPort: 3400,
        ldkPeerListeningPort: 9735,
        network: 'regtest',
        maxMediaUploadSizeMb: 5,
        enableVirtualChannelsV0: true,
        virtualPeerPubkeys: const <String>['peer-pubkey'],
        vssUrl: 'http://127.0.0.1:8080',
        vssAllowHttp: true,
        vssAllowEmptyRestore: true,
        lspBaseUrl: 'http://127.0.0.1:3000',
        lspBearerToken: 'token',
        reuseAddresses: true,
      ),
      method: 'rlnCreateNode',
      args: const <Object?>[
        '/tmp/rln',
        3400,
        9735,
        'regtest',
        5,
        true,
        <String>['peer-pubkey'],
        'http://127.0.0.1:8080',
        true,
        true,
        'http://127.0.0.1:3000',
        'token',
        true,
      ],
    ),
    _ContractCase(
      name: 'initNode',
      invoke: (client) => client.initNode(
        nodeId: nodeId,
        password: 'password',
        mnemonic: 'mnemonic',
      ),
      method: 'rlnInitNode',
      args: const <Object?>[nodeId, 'password', 'mnemonic'],
    ),
    _ContractCase(
      name: 'createNativeExternalSigner',
      invoke: (client) => client.createNativeExternalSigner(
        seedHex: seedHex,
        network: 'regtest',
        permissivePolicy: true,
        storageDirPath: '/tmp/rln',
      ),
      method: 'rlnCreateNativeExternalSigner',
      args: const <Object?>[seedHex, 'regtest', true, '/tmp/rln'],
    ),
    _ContractCase(
      name: 'initNodeWithNativeExternalSigner',
      invoke: (client) async {
        await client.initNodeWithNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
        );
        return null;
      },
      method: 'rlnInitNodeWithNativeExternalSigner',
      args: const <Object?>[nodeId, signerId],
    ),
    _ContractCase(
      name: 'attachNativeExternalSigner',
      invoke: (client) async {
        await client.attachNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
        );
        return null;
      },
      method: 'rlnAttachNativeExternalSigner',
      args: const <Object?>[nodeId, signerId],
    ),
    _ContractCase(
      name: 'unlockNodeWithNativeExternalSigner',
      invoke: (client) async {
        await client.unlockNodeWithNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'pass',
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcPort: 18444,
          indexerUrl: '127.0.0.1:50002',
          proxyEndpoint: 'rpc://127.0.0.1:3003/json-rpc',
          announceAddresses: announceAddresses,
          announceAlias: 'node-alias',
          gossipRgsServerUrl: 'rgs://server',
          ethRpcUrl: 'https://eth.example',
        );
        return null;
      },
      method: 'rlnUnlockNodeWithNativeExternalSigner',
      args: const <Object?>[
        nodeId,
        signerId,
        'user',
        'pass',
        '127.0.0.1',
        18444,
        '127.0.0.1:50002',
        'rpc://127.0.0.1:3003/json-rpc',
        announceAddresses,
        'node-alias',
        'rgs://server',
        'https://eth.example',
      ],
    ),
    _ContractCase(
      name: 'destroyNativeExternalSigner',
      invoke: (client) async {
        await client.destroyNativeExternalSigner(signerId);
        return null;
      },
      method: 'rlnDestroyNativeExternalSigner',
      args: const <Object?>[signerId],
    ),
    _ContractCase(
      name: 'initNodeWithExternalSigner',
      invoke: (client) async {
        await client.initNodeWithExternalSigner(
          nodeId: nodeId,
          nodePublicKeyHex: 'node-pubkey',
          accountXpubVanilla: 'xpub-vanilla',
          accountXpubColored: 'xpub-colored',
          masterFingerprint: 'f23f9fd2',
          protocolVersion: '1',
          apiLevel: 1,
        );
        return null;
      },
      method: 'rlnInitNodeWithExternalSigner',
      args: const <Object?>[
        nodeId,
        'node-pubkey',
        'xpub-vanilla',
        'xpub-colored',
        'f23f9fd2',
        '1',
        1,
      ],
    ),
    _ContractCase(
      name: 'unlockNode',
      invoke: (client) async {
        await client.unlockNode(
          nodeId: nodeId,
          password: 'password',
          ethRpcUrl: 'https://ethereum.example/rpc',
          bitcoindRpcUsername: 'user',
          bitcoindRpcPassword: 'pass',
          bitcoindRpcHost: '127.0.0.1',
          bitcoindRpcPort: 18444,
          indexerUrl: '127.0.0.1:50002',
          proxyEndpoint: 'rpc://127.0.0.1:3003/json-rpc',
          announceAddresses: announceAddresses,
          announceAlias: 'node-alias',
          gossipRgsServerUrl: 'rgs://server',
        );
        return null;
      },
      method: 'rlnUnlockNode',
      args: const <Object?>[
        nodeId,
        'password',
        'user',
        'pass',
        '127.0.0.1',
        18444,
        '127.0.0.1:50002',
        'rpc://127.0.0.1:3003/json-rpc',
        announceAddresses,
        'node-alias',
        'rgs://server',
        'https://ethereum.example/rpc',
      ],
    ),
    _ContractCase(
      name: 'destroyNode',
      invoke: (client) async {
        await client.destroyNode(nodeId);
        return null;
      },
      method: 'rlnDestroyNode',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'nodeInfo',
      invoke: (client) => client.nodeInfo(nodeId),
      method: 'rlnNodeInfo',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'networkInfo',
      invoke: (client) => client.networkInfo(nodeId),
      method: 'rlnNetworkInfo',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'listPeers',
      invoke: (client) => client.listPeers(nodeId),
      method: 'rlnListPeers',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'connectPeer',
      invoke: (client) async {
        await client.connectPeer(
          nodeId: nodeId,
          peerPubkeyAndAddr: 'peer@127.0.0.1:9735',
        );
        return null;
      },
      method: 'rlnConnectPeer',
      args: const <Object?>[nodeId, 'peer@127.0.0.1:9735'],
    ),
    _ContractCase(
      name: 'disconnectPeer',
      invoke: (client) async {
        await client.disconnectPeer(nodeId: nodeId, peerPubkey: 'peer');
        return null;
      },
      method: 'rlnDisconnectPeer',
      args: const <Object?>[nodeId, 'peer'],
    ),
    _ContractCase(
      name: 'listChannels',
      invoke: (client) => client.listChannels(nodeId),
      method: 'rlnListChannels',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'openChannel',
      invoke: (client) => client.openChannel(
        nodeId: nodeId,
        peerPubkeyAndOptAddr: 'peer@127.0.0.1:9735',
        capacitySat: 100000,
        pushMsat: 1000,
        publicChannel: true,
        withAnchors: true,
        feeBaseMsat: 1000,
        feeProportionalMillionths: 10,
        temporaryChannelId: 'temporary-channel-id',
        assetId: 'asset',
        assetAmount: 50,
        pushAssetAmount: 5,
        virtualOpenMode: 'v0',
      ),
      method: 'rlnOpenChannel',
      args: const <Object?>[
        nodeId,
        'peer@127.0.0.1:9735',
        100000,
        1000,
        true,
        true,
        1000,
        10,
        'temporary-channel-id',
        'asset',
        50,
        5,
        'v0',
      ],
    ),
    _ContractCase(
      name: 'closeChannel',
      invoke: (client) async {
        await client.closeChannel(
          nodeId: nodeId,
          channelId: 'channel-id',
          peerPubkey: 'peer',
          force: true,
        );
        return null;
      },
      method: 'rlnCloseChannel',
      args: const <Object?>[nodeId, 'channel-id', 'peer', true],
    ),
    _ContractCase(
      name: 'listPayments',
      invoke: (client) => client.listPayments(nodeId),
      method: 'rlnListPayments',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'address',
      invoke: (client) => client.address(nodeId),
      method: 'rlnAddress',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'rotateAddress',
      invoke: (client) => client.rotateAddress(nodeId),
      method: 'rlnRotateAddress',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'signMessage',
      invoke: (client) =>
          client.signMessage(nodeId: nodeId, message: 'message'),
      method: 'rlnSignMessage',
      args: const <Object?>[nodeId, 'message'],
    ),
    _ContractCase(
      name: 'verifyMessage',
      invoke: (client) => client.verifyMessage(
        nodeId: nodeId,
        message: 'message',
        signature: 'signature',
      ),
      method: 'rlnVerifyMessage',
      args: const <Object?>[nodeId, 'message', 'signature'],
    ),
    _ContractCase(
      name: 'assetBalance',
      invoke: (client) => client.assetBalance(nodeId: nodeId, assetId: 'asset'),
      method: 'rlnAssetBalance',
      args: const <Object?>[nodeId, 'asset'],
    ),
    _ContractCase(
      name: 'backup',
      invoke: (client) async {
        await client.backup(
          nodeId: nodeId,
          backupPath: '/tmp/backup',
          password: 'password',
        );
        return null;
      },
      method: 'rlnBackup',
      args: const <Object?>[nodeId, '/tmp/backup', 'password'],
    ),
    _ContractCase(
      name: 'btcBalance',
      invoke: (client) => client.btcBalance(nodeId: nodeId, skipSync: true),
      method: 'rlnBtcBalance',
      args: const <Object?>[nodeId, true],
    ),
    _ContractCase(
      name: 'checkIndexerUrl',
      invoke: (client) =>
          client.checkIndexerUrl(nodeId: nodeId, indexerUrl: '127.0.0.1:50002'),
      method: 'rlnCheckIndexerUrl',
      args: const <Object?>[nodeId, '127.0.0.1:50002'],
    ),
    _ContractCase(
      name: 'checkProxyEndpoint',
      invoke: (client) async {
        await client.checkProxyEndpoint(
          nodeId: nodeId,
          proxyEndpoint: 'rpc://127.0.0.1:3003/json-rpc',
        );
        return null;
      },
      method: 'rlnCheckProxyEndpoint',
      args: const <Object?>[nodeId, 'rpc://127.0.0.1:3003/json-rpc'],
    ),
    _ContractCase(
      name: 'createUtxos',
      invoke: (client) async {
        await client.createUtxos(
          nodeId: nodeId,
          upTo: false,
          num: 3,
          size: 100000,
          feeRate: 1.5,
          skipSync: true,
        );
        return null;
      },
      method: 'rlnCreateUtxos',
      args: const <Object?>[nodeId, false, 3, 100000, 1.5, true],
    ),
    _ContractCase(
      name: 'decodeLnInvoice',
      invoke: (client) =>
          client.decodeLnInvoice(nodeId: nodeId, invoice: 'lnbc1invoice'),
      method: 'rlnDecodeLnInvoice',
      args: const <Object?>[nodeId, 'lnbc1invoice'],
    ),
    _ContractCase(
      name: 'decodeRgbInvoice',
      invoke: (client) =>
          client.decodeRgbInvoice(nodeId: nodeId, invoice: 'rgb:invoice'),
      method: 'rlnDecodeRgbInvoice',
      args: const <Object?>[nodeId, 'rgb:invoice'],
    ),
    _ContractCase(
      name: 'estimateFee',
      invoke: (client) => client.estimateFee(nodeId: nodeId, blocks: 6),
      method: 'rlnEstimateFee',
      args: const <Object?>[nodeId, 6],
    ),
    _ContractCase(
      name: 'failTransfers',
      invoke: (client) => client.failTransfers(
        nodeId: nodeId,
        batchTransferIdx: 11,
        noAssetOnly: true,
        skipSync: false,
      ),
      method: 'rlnFailTransfers',
      args: const <Object?>[nodeId, 11, true, false],
    ),
    _ContractCase(
      name: 'getChannelId',
      invoke: (client) => client.getChannelId(
        nodeId: nodeId,
        temporaryChannelId: 'temporary-channel-id',
      ),
      method: 'rlnGetChannelId',
      args: const <Object?>[nodeId, 'temporary-channel-id'],
    ),
    _ContractCase(
      name: 'getPayment',
      invoke: (client) =>
          client.getPayment(nodeId: nodeId, paymentHash: 'payment-hash'),
      method: 'rlnGetPayment',
      args: const <Object?>[nodeId, 'payment-hash'],
    ),
    _ContractCase(
      name: 'invoiceStatus',
      invoke: (client) =>
          client.invoiceStatus(nodeId: nodeId, invoice: 'lnbc1invoice'),
      method: 'rlnInvoiceStatus',
      args: const <Object?>[nodeId, 'lnbc1invoice'],
    ),
    _ContractCase(
      name: 'keysend',
      invoke: (client) => client.keysend(
        nodeId: nodeId,
        destPubkey: 'destination',
        amtMsat: 1000,
        assetId: 'asset',
        assetAmount: 50,
      ),
      method: 'rlnKeysend',
      args: const <Object?>[nodeId, 'destination', 1000, 'asset', 50],
    ),
    _ContractCase(
      name: 'listAssets',
      invoke: (client) =>
          client.listAssets(nodeId: nodeId, filterAssetSchemas: schemas),
      method: 'rlnListAssets',
      args: const <Object?>[nodeId, schemas],
    ),
    _ContractCase(
      name: 'listTransactions',
      invoke: (client) =>
          client.listTransactions(nodeId: nodeId, skipSync: true),
      method: 'rlnListTransactions',
      args: const <Object?>[nodeId, true],
    ),
    _ContractCase(
      name: 'listTransactionsByTxid',
      invoke: (client) => client.listTransactionsByTxid(
        nodeId: nodeId,
        txid: 'txid',
        skipSync: true,
      ),
      method: 'rlnListTransactionsByTxid',
      args: const <Object?>[nodeId, 'txid', true],
    ),
    _ContractCase(
      name: 'listTransfers',
      invoke: (client) =>
          client.listTransfers(nodeId: nodeId, assetId: 'asset'),
      method: 'rlnListTransfers',
      args: const <Object?>[nodeId, 'asset'],
    ),
    _ContractCase(
      name: 'listTransfersByTxid',
      invoke: (client) =>
          client.listTransfersByTxid(nodeId: nodeId, txid: 'txid'),
      method: 'rlnListTransfersByTxid',
      args: const <Object?>[nodeId, 'txid'],
    ),
    _ContractCase(
      name: 'listUnspents',
      invoke: (client) => client.listUnspents(nodeId: nodeId, skipSync: true),
      method: 'rlnListUnspents',
      args: const <Object?>[nodeId, true],
    ),
    _ContractCase(
      name: 'lnInvoice',
      invoke: (client) => client.lnInvoice(
        nodeId: nodeId,
        amtMsat: 1000,
        expirySec: 3600,
        assetId: 'asset',
        assetAmount: 50,
        paymentHash: 'payment-hash',
        minFinalCltvExpiryDelta: 144,
        description: 'invoice description',
      ),
      method: 'rlnLnInvoice',
      args: const <Object?>[
        nodeId,
        1000,
        3600,
        'asset',
        50,
        'payment-hash',
        144,
        null,
        'invoice description',
      ],
    ),
    _ContractCase(
      name: 'claimHodlInvoice',
      invoke: (client) => client.claimHodlInvoice(
        nodeId: nodeId,
        paymentHash: 'payment-hash',
        paymentPreimage: 'preimage',
      ),
      method: 'rlnClaimHodlInvoice',
      args: const <Object?>[nodeId, 'payment-hash', 'preimage'],
    ),
    _ContractCase(
      name: 'cancelHodlInvoice',
      invoke: (client) async {
        await client.cancelHodlInvoice(
          nodeId: nodeId,
          paymentHash: 'payment-hash',
        );
        return null;
      },
      method: 'rlnCancelHodlInvoice',
      args: const <Object?>[nodeId, 'payment-hash'],
    ),
    _ContractCase(
      name: 'apayNew',
      invoke: (client) =>
          client.apayNew(nodeId: nodeId, hostNodeId: 'host-node-id'),
      method: 'rlnApayNew',
      args: const <Object?>[nodeId, 'host-node-id'],
    ),
    _ContractCase(
      name: 'apayNewWithAddress',
      invoke: (client) => client.apayNewWithAddress(
        nodeId: nodeId,
        hostNodeId: 'host-node-id',
        username: 'alice',
        domain: 'lsp.example',
      ),
      method: 'rlnApayNewWithAddress',
      args: const <Object?>[nodeId, 'host-node-id', 'alice', 'lsp.example'],
    ),
    _ContractCase(
      name: 'refreshTransfers',
      invoke: (client) async {
        await client.refreshTransfers(nodeId: nodeId, skipSync: true);
        return null;
      },
      method: 'rlnRefreshTransfers',
      args: const <Object?>[nodeId, true],
    ),
    _ContractCase(
      name: 'rgbInvoice',
      invoke: (client) => client.rgbInvoice(
        nodeId: nodeId,
        assetId: 'asset',
        assignmentAmount: 100,
        durationSeconds: 3600,
        minConfirmations: 1,
        witness: true,
        assignmentKind: 'InflationRight',
      ),
      method: 'rlnRgbInvoice',
      args: const <Object?>[
        nodeId,
        'asset',
        100,
        3600,
        1,
        true,
        'InflationRight',
      ],
    ),
    _ContractCase(
      name: 'sendBtc',
      invoke: (client) => client.sendBtc(
        nodeId: nodeId,
        amount: 10000,
        address: 'bcrt1address',
        feeRate: 1.5,
        skipSync: true,
      ),
      method: 'rlnSendBtc',
      args: const <Object?>[nodeId, 10000, 'bcrt1address', 1.5, true],
    ),
    _ContractCase(
      name: 'sendPayment',
      invoke: (client) => client.sendPayment(
        nodeId: nodeId,
        invoice: 'lnbc1invoice',
        amtMsat: 1000,
        assetId: 'asset',
        assetAmount: 50,
      ),
      method: 'rlnSendPayment',
      args: const <Object?>[nodeId, 'lnbc1invoice', 1000, 'asset', 50],
    ),
    _ContractCase(
      name: 'sendRgb',
      invoke: (client) => client.sendRgb(
        nodeId: nodeId,
        donation: true,
        feeRate: 1.5,
        minConfirmations: 1,
        skipSync: false,
        assetId: 'asset',
        recipientId: 'recipient',
        amount: 100,
        transportEndpoints: transports,
        witnessAmountSat: 546,
        witnessBlinding: 42,
      ),
      method: 'rlnSendRgb',
      args: const <Object?>[
        nodeId,
        true,
        1.5,
        1,
        false,
        'asset',
        'recipient',
        100,
        transports,
        546,
        42,
      ],
    ),
    _ContractCase(
      name: 'shutdown',
      invoke: (client) async {
        await client.shutdown(nodeId);
        return null;
      },
      method: 'rlnShutdown',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'sync',
      invoke: (client) async {
        await client.sync(nodeId);
        return null;
      },
      method: 'rlnSync',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'assetMetadata',
      invoke: (client) =>
          client.assetMetadata(nodeId: nodeId, assetId: 'rgb:asset'),
      method: 'rlnAssetMetadata',
      args: const <Object?>[nodeId, 'rgb:asset'],
    ),
    _ContractCase(
      name: 'postAssetMedia',
      invoke: (client) => client.postAssetMedia(
        nodeId: nodeId,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      method: 'rlnPostAssetMedia',
      args: <Object?>[
        nodeId,
        Uint8List.fromList([1, 2, 3]),
      ],
    ),
    _ContractCase(
      name: 'issueAssetNia',
      invoke: (client) => client.issueAssetNia(
        nodeId: nodeId,
        ticker: 'TST',
        name: 'Test',
        precision: 0,
        amounts: amounts,
      ),
      method: 'rlnIssueAssetNia',
      args: const <Object?>[nodeId, 'TST', 'Test', 0, amounts],
    ),
    _ContractCase(
      name: 'issueAssetCfa',
      invoke: (client) => client.issueAssetCfa(
        nodeId: nodeId,
        name: 'Collectible',
        details: 'details',
        precision: 0,
        amounts: amounts,
        fileDigest: 'file-digest',
      ),
      method: 'rlnIssueAssetCfa',
      args: const <Object?>[
        nodeId,
        'Collectible',
        'details',
        0,
        amounts,
        'file-digest',
      ],
    ),
    _ContractCase(
      name: 'issueAssetIfa',
      invoke: (client) => client.issueAssetIfa(
        nodeId: nodeId,
        ticker: 'IFA',
        name: 'Inflatable',
        precision: 0,
        amounts: amounts,
        inflationAmounts: inflationAmounts,
        rejectListUrl: 'https://example.com/reject-list',
      ),
      method: 'rlnIssueAssetIfa',
      args: const <Object?>[
        nodeId,
        'IFA',
        'Inflatable',
        0,
        amounts,
        inflationAmounts,
        'https://example.com/reject-list',
      ],
    ),
    _ContractCase(
      name: 'inflate',
      invoke: (client) => client.inflate(
        nodeId: nodeId,
        assetId: 'asset',
        inflationAmounts: inflationAmounts,
        feeRate: 1.5,
        minConfirmations: 1,
      ),
      method: 'rlnInflate',
      args: const <Object?>[nodeId, 'asset', inflationAmounts, 1.5, 1],
    ),
    _ContractCase(
      name: 'issueAssetUda',
      invoke: (client) => client.issueAssetUda(
        nodeId: nodeId,
        ticker: 'UDA',
        name: 'Unique',
        details: 'details',
        precision: 0,
        mediaFileDigest: 'media-digest',
        attachmentsFileDigests: attachments,
      ),
      method: 'rlnIssueAssetUda',
      args: const <Object?>[
        nodeId,
        'UDA',
        'Unique',
        'details',
        0,
        'media-digest',
        attachments,
      ],
    ),
    _ContractCase(
      name: 'vssBackup',
      invoke: (client) => client.vssBackup(nodeId),
      method: 'rlnVssBackup',
      args: const <Object?>[nodeId],
    ),
    _ContractCase(
      name: 'vssClearFence',
      invoke: (client) async {
        await client.vssClearFence(nodeId: nodeId, password: 'password');
        return null;
      },
      method: 'rlnVssClearFence',
      args: const <Object?>[nodeId, 'password'],
    ),
  ];

  group('RlnClient bridge contract', () {
    test(
      'invoice description and hash are mutually exclusive before dispatch',
      () {
        final host = _RecordingRlnHostApi();
        expect(
          () => RlnClient(hostApi: host).lnInvoice(
            nodeId: nodeId,
            expirySec: 3600,
            description: 'description',
            descriptionHash: 'description-hash',
          ),
          throwsA(isA<WalletValidationException>()),
        );
      },
    );

    test(
      'listUnspents preserves native blinded reservations through JSON',
      () async {
        final host = _RecordingRlnHostApi();
        final result = await RlnClient(
          hostApi: host,
        ).listUnspents(nodeId: nodeId, skipSync: false);
        final unspent = RlnUnspent.fromMap(result.single).toCore();
        expect(unspent.pendingBlinded, 3);
        expect(unspent.utxo.outpoint.txid, 'ab' * 32);
        expect(unspent.utxo.outpoint.vout, 3);
        expect(unspent.utxo.btcAmount, 20000);
      },
    );

    test('matrix covers every low-level bridge method', () {
      final host =
          parseString(
            content: File('pigeons/rln_api.dart').readAsStringSync(),
          ).unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (type) => type.namePart.typeName.lexeme == 'RlnHostApi',
          );
      final methods =
          (host.body as BlockClassBody).members
              .whereType<MethodDeclaration>()
              .map((method) => method.name.lexeme)
              .toSet()
            // Artifact identity has its own dedicated native-artifact tests.
            ..remove('getNativeArtifactInfo');
      expect(cases.map((testCase) => testCase.method).toSet(), methods);
      expect(
        cases.map((testCase) => testCase.name).toSet(),
        hasLength(cases.length),
      );
    });

    test('sendRgb rejects skipSync true before native call', () {
      final hostApi = _RecordingRlnHostApi();
      final client = RlnClient(hostApi: hostApi);

      expect(
        () => client.sendRgb(
          nodeId: nodeId,
          donation: true,
          feeRate: 1.5,
          minConfirmations: 1,
          skipSync: true,
          assetId: 'asset',
          recipientId: 'recipient',
          amount: 100,
          transportEndpoints: transports,
        ),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );

      expect(hostApi.calls, isEmpty);
    });

    test('adapts typed refresh data without losing batch IDs', () async {
      final hostApi = _RecordingRlnHostApi()
        ..refreshTransfersData = RlnRefreshTransfersData(
          transfers: <RlnRefreshedTransferData>[
            RlnRefreshedTransferData(
              index: 9,
              updatedStatus: 'WaitingBroadcast',
              failure: RlnRefreshFailureData(
                name: 'ProxyError',
                message: 'proxy unavailable',
              ),
            ),
          ],
        );
      final client = RlnClient(hostApi: hostApi);

      final response = await client.refreshTransfers(
        nodeId: nodeId,
        skipSync: true,
      );

      expect(response, <Object?, Object?>{
        'transfers': <Object?, Object?>{
          9: <Object?, Object?>{
            'updatedStatus': 'WaitingBroadcast',
            'failure': <Object?, Object?>{
              'name': 'ProxyError',
              'message': 'proxy unavailable',
            },
          },
        },
      });
    });

    test('rejects duplicate batch IDs in typed refresh data', () async {
      final hostApi = _RecordingRlnHostApi()
        ..refreshTransfersData = RlnRefreshTransfersData(
          transfers: <RlnRefreshedTransferData>[
            RlnRefreshedTransferData(index: 9),
            RlnRefreshedTransferData(index: 9),
          ],
        );
      final client = RlnClient(hostApi: hostApi);

      await expectLater(
        client.refreshTransfers(nodeId: nodeId, skipSync: false),
        throwsA(isA<NativeProtocolException>()),
      );
    });

    test('maps PlatformException into typed SDK error with native cause', () {
      final client = RlnClient(hostApi: _ThrowingRlnHostApi());

      expect(
        () => client.nodeInfo(nodeId),
        throwsA(
          isA<BadRequestError>().having(
            (error) => error.cause,
            'cause',
            isA<NativeBridgeFailure>()
                .having((cause) => cause.operation, 'operation', 'rlnNodeInfo')
                .having((cause) => cause.nativeCode, 'nativeCode', 'RlnError'),
          ),
        ),
      );
    });

    test('maps structured native taxonomy without message heuristics', () {
      final mainnet = mapNativeBridgeException(
        PlatformException(code: 'LightningUnsupportedOnMainnet'),
        operation: 'rlnLnInvoice',
      );
      expect(mainnet, isA<UnsupportedWalletFeatureException>());
      final nativeCause = mainnet.cause! as NativeBridgeFailure;
      expect(nativeCause.nativeCode, 'LightningUnsupportedOnMainnet');
      expect(nativeCause.retryable, false);
      expect(nativeCause.category, NativeBridgeFailureCategory.unsupported);

      final unsupported = mapNativeBridgeException(
        PlatformException(
          code: 'RlnError',
          message: 'this text intentionally contains conflict and not found',
          details: <String, Object?>{
            'operation': 'rlnSendRgb',
            'category': 'unsupported',
            'retryable': false,
            'feature': 'sendRgb.skipSync',
          },
        ),
        operation: 'rlnSendRgb',
      );
      expect(
        unsupported,
        isA<UnsupportedWalletFeatureException>().having(
          (error) => error.feature,
          'feature',
          'sendRgb.skipSync',
        ),
      );
      expect((unsupported.cause! as NativeBridgeFailure).structured, true);

      final legacy = mapNativeBridgeException(
        PlatformException(
          code: 'RlnError',
          message: 'InvalidRequest: this legacy text must not classify',
        ),
        operation: 'rlnNodeInfo',
      );
      expect(legacy, isA<RgbNodeError>());
      expect((legacy.cause! as NativeBridgeFailure).structured, false);
    });

    test('rejects malformed native wire responses', () async {
      final client = RlnClient(hostApi: _MalformedWireRlnHostApi());

      await expectLater(
        client.signMessage(nodeId: nodeId, message: 'message'),
        throwsA(
          isA<NativeProtocolException>().having(
            (error) => error.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
      await expectLater(
        client.verifyMessage(
          nodeId: nodeId,
          message: 'message',
          signature: 'signature',
        ),
        throwsA(
          isA<NativeProtocolException>().having(
            (error) => error.field,
            'field',
            'RlnWireResponse.json',
          ),
        ),
      );
      await expectLater(
        client.listTransactionsByTxid(
          nodeId: nodeId,
          txid: 'txid',
          skipSync: false,
        ),
        throwsA(
          isA<NativeProtocolException>().having(
            (error) => error.field,
            'field',
            'RlnWireResponse.json',
          ),
        ),
      );
    });

    test(
      'every JSON-returning method rejects malformed or non-object data',
      () async {
        final schema = parseString(
          content: File('pigeons/rln_api.dart').readAsStringSync(),
        ).unit;
        final host = schema.declarations
            .whereType<ClassDeclaration>()
            .singleWhere(
              (declaration) =>
                  declaration.namePart.typeName.lexeme == 'RlnHostApi',
            );
        final body = host.body as BlockClassBody;
        final methods = body.members.whereType<MethodDeclaration>().where(
          (method) => method.returnType!.toSource().contains('RlnWireResponse'),
        );
        final expected = methods.map((method) => method.name.lexeme).toSet();
        final checked = <String>{};
        expect(expected, isNotEmpty);

        for (final contractCase in cases) {
          if (!expected.contains(contractCase.method)) continue;
          checked.add(contractCase.method);
          for (final invalid in <String>[
            '{not-json',
            'null',
            '42',
            'true',
            '"not-an-object"',
            '[{"valid":"but-wrong-root"}]',
          ]) {
            final hostApi = _InvalidJsonHostApi(invalid);
            await expectLater(
              contractCase.invoke(RlnClient(hostApi: hostApi)),
              throwsA(isA<NativeProtocolException>()),
              reason: '${contractCase.method} accepted invalid JSON shape',
            );
            expect(hostApi.calls.single.method, contractCase.method);
          }
        }
        // New Pigeon methods must have an executable contract, not only a label.
        expect(checked, expected);
      },
    );

    for (final contractCase in cases) {
      test(
        '${contractCase.name} maps a native failure without losing operation identity',
        () async {
          final client = RlnClient(hostApi: _EveryOperationFailsHost());
          await expectLater(
            contractCase.invoke(client),
            throwsA(
              isA<NetworkError>().having(
                (error) => error.cause,
                'cause',
                isA<NativeBridgeFailure>().having(
                  (failure) => failure.operation,
                  'operation',
                  contractCase.method,
                ),
              ),
            ),
          );
        },
      );
      test(
        '${contractCase.name} delegates to ${contractCase.method}',
        () async {
          final hostApi = _RecordingRlnHostApi();
          final client = RlnClient(hostApi: hostApi);

          await contractCase.invoke(client);

          expect(hostApi.calls, hasLength(1));
          expect(hostApi.calls.single.method, contractCase.method);
          expect(hostApi.calls.single.args, contractCase.args);
        },
      );
    }
  });
}
