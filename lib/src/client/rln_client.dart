import 'dart:convert';

import 'package:flutter/services.dart';

import '../errors/native_bridge_error_mapper.dart';
import '../errors/rgb_sdk_exception.dart';
import '../pigeon/rln_api.g.dart';

/// Low-level bridge over the native RGB Lightning Node `rln*` API.
///
/// This class intentionally stays close to the React Native bridge surface.
/// Prefer `UtexoWallet` for product code because it returns typed models and
/// handles wallet lifecycle checks.
class RlnClient {
  RlnClient({RlnHostApi? hostApi}) : _hostApi = hostApi ?? RlnHostApi();

  final RlnHostApi _hostApi;

  Future<T> _native<T>(String operation, Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        mapNativeBridgeException(error, operation: operation),
        stackTrace,
      );
    }
  }

  Future<Map<Object?, Object?>> _nativeMap(
    String operation,
    Future<RlnWireResponse> Function() call,
  ) async {
    return _decodeWireMap(await _native(operation, call));
  }

  Future<List<Map<Object?, Object?>>> _nativeMapList(
    String operation,
    Future<List<RlnWireResponse>> Function() call,
  ) async {
    return (await _native(
      operation,
      call,
    )).map(_decodeWireMap).toList(growable: false);
  }

  Map<Object?, Object?> _decodeWireMap(RlnWireResponse response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.json);
    } on FormatException catch (error) {
      throw NativeProtocolException(
        'Native response is not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw NativeProtocolException(
        'Native response JSON root must be an object.',
        field: 'RlnWireResponse.json',
      );
    }
    return Map<Object?, Object?>.from(decoded);
  }

  Future<int> createNode({
    required String storageDirPath,
    required int daemonListeningPort,
    required int ldkPeerListeningPort,
    required String network,
    required int maxMediaUploadSizeMb,
    bool? enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    String? vssUrl,
    bool vssAllowHttp = false,
    bool vssAllowEmptyRestore = false,
    String? lspBaseUrl,
    String? lspBearerToken,
    bool reuseAddresses = false,
  }) {
    return _native(
      'rlnCreateNode',
      () => _hostApi.rlnCreateNode(
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
      ),
    );
  }

  Future<String> initNode({
    required int nodeId,
    required String password,
    String? mnemonic,
  }) {
    return _native(
      'rlnInitNode',
      () => _hostApi.rlnInitNode(nodeId, password, mnemonic),
    );
  }

  Future<int> createNativeExternalSigner({
    required String seedHex,
    required String network,
    required bool permissivePolicy,
    String? storageDirPath,
  }) {
    return _native(
      'rlnCreateNativeExternalSigner',
      () => _hostApi.rlnCreateNativeExternalSigner(
        seedHex,
        network,
        permissivePolicy,
        storageDirPath,
      ),
    );
  }

  Future<void> initNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _native(
      'rlnInitNodeWithNativeExternalSigner',
      () => _hostApi.rlnInitNodeWithNativeExternalSigner(nodeId, signerId),
    );
  }

  Future<void> attachNativeExternalSigner({
    required int nodeId,
    required int signerId,
  }) {
    return _native(
      'rlnAttachNativeExternalSigner',
      () => _hostApi.rlnAttachNativeExternalSigner(nodeId, signerId),
    );
  }

  Future<void> unlockNodeWithNativeExternalSigner({
    required int nodeId,
    required int signerId,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    String? announceAlias,
    String? gossipRgsServerUrl,
    String? ethRpcUrl,
  }) {
    return _native(
      'rlnUnlockNodeWithNativeExternalSigner',
      () => _hostApi.rlnUnlockNodeWithNativeExternalSigner(
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
      ),
    );
  }

  Future<void> destroyNativeExternalSigner(int signerId) {
    return _native(
      'rlnDestroyNativeExternalSigner',
      () => _hostApi.rlnDestroyNativeExternalSigner(signerId),
    );
  }

  Future<void> initNodeWithExternalSigner({
    required int nodeId,
    required String nodePublicKeyHex,
    required String accountXpubVanilla,
    required String accountXpubColored,
    required String masterFingerprint,
    required String protocolVersion,
    required int apiLevel,
  }) {
    return _native(
      'rlnInitNodeWithExternalSigner',
      () => _hostApi.rlnInitNodeWithExternalSigner(
        nodeId,
        nodePublicKeyHex,
        accountXpubVanilla,
        accountXpubColored,
        masterFingerprint,
        protocolVersion,
        apiLevel,
      ),
    );
  }

  Future<void> unlockNode({
    required int nodeId,
    required String password,
    String? bitcoindRpcUsername,
    String? bitcoindRpcPassword,
    String? bitcoindRpcHost,
    int? bitcoindRpcPort,
    String? indexerUrl,
    String? proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    String? announceAlias,
    String? gossipRgsServerUrl,
    String? ethRpcUrl,
  }) {
    return _native(
      'rlnUnlockNode',
      () => _hostApi.rlnUnlockNode(
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
      ),
    );
  }

  Future<void> destroyNode(int nodeId) {
    return _native('rlnDestroyNode', () => _hostApi.rlnDestroyNode(nodeId));
  }

  /// Imports public contract metadata while native verifies the expected ID.
  Future<Map<Object?, Object?>> importRgbContract({
    required int nodeId,
    required String contractBase64,
    required String expectedAssetId,
  }) => _nativeMap(
    'rlnImportRgbContract',
    () =>
        _hostApi.rlnImportRgbContract(nodeId, contractBase64, expectedAssetId),
  );

  /// Native-build capabilities; signer support is applied by UtexoWallet.
  Future<Map<Object?, Object?>> bfaCapabilities() =>
      _nativeMap('rlnBfaCapabilities', _hostApi.rlnBfaCapabilities);

  /// Irreversible one-attempt native burn. Amount is an exact u64 decimal.
  Future<Map<Object?, Object?>> burn({
    required int nodeId,
    required String assetId,
    required String amount,
    String? burnRecipient,
    required int feeRate,
    required int minConfirmations,
  }) => _nativeMap(
    'rlnBurn',
    () => _hostApi.rlnBurn(
      nodeId,
      assetId,
      amount,
      burnRecipient,
      feeRate,
      minConfirmations,
    ),
  );

  /// Reads saved proof bytes as standard Base64; does not regenerate proofs.
  Future<String> getConsignment(int nodeId, String assetId, String txid) =>
      _native(
        'rlnGetConsignment',
        () => _hostApi.rlnGetConsignment(nodeId, assetId, txid),
      );

  /// Local sandbox path for wallet-owned use, never for dApp transport.
  Future<String> getConsignmentPath(int nodeId, String assetId, String txid) =>
      _native(
        'rlnGetConsignmentPath',
        () => _hostApi.rlnGetConsignmentPath(nodeId, assetId, txid),
      );

  Future<Map<Object?, Object?>> nodeInfo(int nodeId) {
    return _nativeMap('rlnNodeInfo', () => _hostApi.rlnNodeInfo(nodeId));
  }

  Future<Map<Object?, Object?>> networkInfo(int nodeId) {
    return _nativeMap('rlnNetworkInfo', () => _hostApi.rlnNetworkInfo(nodeId));
  }

  Future<List<Map<Object?, Object?>>> listPeers(int nodeId) {
    return _nativeMapList('rlnListPeers', () => _hostApi.rlnListPeers(nodeId));
  }

  Future<void> connectPeer({
    required int nodeId,
    required String peerPubkeyAndAddr,
  }) {
    return _native(
      'rlnConnectPeer',
      () => _hostApi.rlnConnectPeer(nodeId, peerPubkeyAndAddr),
    );
  }

  Future<void> disconnectPeer({
    required int nodeId,
    required String peerPubkey,
  }) {
    return _native(
      'rlnDisconnectPeer',
      () => _hostApi.rlnDisconnectPeer(nodeId, peerPubkey),
    );
  }

  Future<List<Map<Object?, Object?>>> listChannels(int nodeId) {
    return _nativeMapList(
      'rlnListChannels',
      () => _hostApi.rlnListChannels(nodeId),
    );
  }

  Future<Map<Object?, Object?>> openChannel({
    required int nodeId,
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    required int pushMsat,
    required bool publicChannel,
    required bool withAnchors,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) {
    return _nativeMap(
      'rlnOpenChannel',
      () => _hostApi.rlnOpenChannel(
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
      ),
    );
  }

  Future<void> closeChannel({
    required int nodeId,
    required String channelId,
    required String peerPubkey,
    required bool force,
  }) {
    return _native(
      'rlnCloseChannel',
      () => _hostApi.rlnCloseChannel(nodeId, channelId, peerPubkey, force),
    );
  }

  Future<List<Map<Object?, Object?>>> listPayments(int nodeId) {
    return _nativeMapList(
      'rlnListPayments',
      () => _hostApi.rlnListPayments(nodeId),
    );
  }

  Future<Map<Object?, Object?>> address(int nodeId) {
    return _nativeMap('rlnAddress', () => _hostApi.rlnAddress(nodeId));
  }

  Future<Map<Object?, Object?>> rotateAddress(int nodeId) {
    return _nativeMap(
      'rlnRotateAddress',
      () => _hostApi.rlnRotateAddress(nodeId),
    );
  }

  Future<Map<Object?, Object?>> signMessage({
    required int nodeId,
    required String message,
  }) {
    return _nativeMap(
      'rlnSignMessage',
      () => _hostApi.rlnSignMessage(nodeId, message),
    );
  }

  Future<Map<Object?, Object?>> verifyMessage({
    required int nodeId,
    required String message,
    required String signature,
  }) {
    return _nativeMap(
      'rlnVerifyMessage',
      () => _hostApi.rlnVerifyMessage(nodeId, message, signature),
    );
  }

  Future<Map<Object?, Object?>> assetBalance({
    required int nodeId,
    required String assetId,
  }) {
    return _nativeMap(
      'rlnAssetBalance',
      () => _hostApi.rlnAssetBalance(nodeId, assetId),
    );
  }

  Future<void> backup({
    required int nodeId,
    required String backupPath,
    required String password,
  }) {
    return _native(
      'rlnBackup',
      () => _hostApi.rlnBackup(nodeId, backupPath, password),
    );
  }

  Future<Map<Object?, Object?>> btcBalance({
    required int nodeId,
    required bool skipSync,
  }) {
    return _nativeMap(
      'rlnBtcBalance',
      () => _hostApi.rlnBtcBalance(nodeId, skipSync),
    );
  }

  Future<Map<Object?, Object?>> checkIndexerUrl({
    required int nodeId,
    required String indexerUrl,
  }) {
    return _nativeMap(
      'rlnCheckIndexerUrl',
      () => _hostApi.rlnCheckIndexerUrl(nodeId, indexerUrl),
    );
  }

  Future<void> checkProxyEndpoint({
    required int nodeId,
    required String proxyEndpoint,
  }) {
    return _native(
      'rlnCheckProxyEndpoint',
      () => _hostApi.rlnCheckProxyEndpoint(nodeId, proxyEndpoint),
    );
  }

  Future<void> createUtxos({
    required int nodeId,
    required bool upTo,
    int? num,
    int? size,
    required double feeRate,
    required bool skipSync,
  }) {
    return _native(
      'rlnCreateUtxos',
      () => _hostApi.rlnCreateUtxos(nodeId, upTo, num, size, feeRate, skipSync),
    );
  }

  Future<Map<Object?, Object?>> decodeLnInvoice({
    required int nodeId,
    required String invoice,
  }) {
    return _nativeMap(
      'rlnDecodeLnInvoice',
      () => _hostApi.rlnDecodeLnInvoice(nodeId, invoice),
    );
  }

  Future<Map<Object?, Object?>> decodeRgbInvoice({
    required int nodeId,
    required String invoice,
  }) {
    return _nativeMap(
      'rlnDecodeRgbInvoice',
      () => _hostApi.rlnDecodeRgbInvoice(nodeId, invoice),
    );
  }

  Future<Map<Object?, Object?>> estimateFee({
    required int nodeId,
    required int blocks,
  }) {
    return _nativeMap(
      'rlnEstimateFee',
      () => _hostApi.rlnEstimateFee(nodeId, blocks),
    );
  }

  Future<Map<Object?, Object?>> failTransfers({
    required int nodeId,
    int? batchTransferIdx,
    required bool noAssetOnly,
    required bool skipSync,
  }) {
    return _nativeMap(
      'rlnFailTransfers',
      () => _hostApi.rlnFailTransfers(
        nodeId,
        batchTransferIdx,
        noAssetOnly,
        skipSync,
      ),
    );
  }

  Future<String> getChannelId({
    required int nodeId,
    required String temporaryChannelId,
  }) {
    return _native(
      'rlnGetChannelId',
      () => _hostApi.rlnGetChannelId(nodeId, temporaryChannelId),
    );
  }

  Future<Map<Object?, Object?>> getPayment({
    required int nodeId,
    required String paymentHash,
  }) {
    return _nativeMap(
      'rlnGetPayment',
      () => _hostApi.rlnGetPayment(nodeId, paymentHash),
    );
  }

  Future<Map<Object?, Object?>> invoiceStatus({
    required int nodeId,
    required String invoice,
  }) {
    return _nativeMap(
      'rlnInvoiceStatus',
      () => _hostApi.rlnInvoiceStatus(nodeId, invoice),
    );
  }

  Future<Map<Object?, Object?>> keysend({
    required int nodeId,
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _nativeMap(
      'rlnKeysend',
      () => _hostApi.rlnKeysend(
        nodeId,
        destPubkey,
        amtMsat,
        assetId,
        assetAmount,
      ),
    );
  }

  Future<Map<Object?, Object?>> listAssets({
    required int nodeId,
    List<String> filterAssetSchemas = const <String>[],
  }) {
    return _nativeMap(
      'rlnListAssets',
      () => _hostApi.rlnListAssets(nodeId, filterAssetSchemas),
    );
  }

  Future<List<Map<Object?, Object?>>> listTransactions({
    required int nodeId,
    required bool skipSync,
  }) {
    return _nativeMapList(
      'rlnListTransactions',
      () => _hostApi.rlnListTransactions(nodeId, skipSync),
    );
  }

  Future<List<Map<Object?, Object?>>> listTransactionsByTxid({
    required int nodeId,
    required String txid,
    required bool skipSync,
  }) {
    return _nativeMapList(
      'rlnListTransactionsByTxid',
      () => _hostApi.rlnListTransactionsByTxid(nodeId, txid, skipSync),
    );
  }

  Future<List<Map<Object?, Object?>>> listTransfers({
    required int nodeId,
    required String assetId,
  }) {
    return _nativeMapList(
      'rlnListTransfers',
      () => _hostApi.rlnListTransfers(nodeId, assetId),
    );
  }

  Future<List<Map<Object?, Object?>>> listTransfersByTxid({
    required int nodeId,
    required String txid,
  }) {
    return _nativeMapList(
      'rlnListTransfersByTxid',
      () => _hostApi.rlnListTransfersByTxid(nodeId, txid),
    );
  }

  Future<List<Map<Object?, Object?>>> listUnspents({
    required int nodeId,
    required bool skipSync,
  }) {
    return _nativeMapList(
      'rlnListUnspents',
      () => _hostApi.rlnListUnspents(nodeId, skipSync),
    );
  }

  Future<Map<Object?, Object?>> lnInvoice({
    required int nodeId,
    int? amtMsat,
    required int expirySec,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) {
    if (description != null && descriptionHash != null) {
      throw const WalletValidationException(
        'Provide either description or descriptionHash.',
        field: 'description',
      );
    }
    return _nativeMap(
      'rlnLnInvoice',
      () => _hostApi.rlnLnInvoice(
        nodeId,
        amtMsat,
        expirySec,
        assetId,
        assetAmount,
        paymentHash,
        minFinalCltvExpiryDelta,
        descriptionHash,
        description,
      ),
    );
  }

  Future<Map<Object?, Object?>> claimHodlInvoice({
    required int nodeId,
    required String paymentHash,
    required String paymentPreimage,
  }) {
    return _nativeMap(
      'rlnClaimHodlInvoice',
      () => _hostApi.rlnClaimHodlInvoice(nodeId, paymentHash, paymentPreimage),
    );
  }

  Future<void> cancelHodlInvoice({
    required int nodeId,
    required String paymentHash,
  }) {
    return _native(
      'rlnCancelHodlInvoice',
      () => _hostApi.rlnCancelHodlInvoice(nodeId, paymentHash),
    );
  }

  Future<Map<Object?, Object?>> apayNew({
    required int nodeId,
    required String hostNodeId,
  }) {
    return _nativeMap(
      'rlnApayNew',
      () => _hostApi.rlnApayNew(nodeId, hostNodeId),
    );
  }

  Future<Map<Object?, Object?>> apayNewWithAddress({
    required int nodeId,
    required String hostNodeId,
    required String username,
    required String domain,
  }) {
    return _nativeMap(
      'rlnApayNewWithAddress',
      () =>
          _hostApi.rlnApayNewWithAddress(nodeId, hostNodeId, username, domain),
    );
  }

  Future<Map<Object?, Object?>> refreshTransfers({
    required int nodeId,
    required bool skipSync,
  }) async {
    final response = await _native(
      'rlnRefreshTransfers',
      () => _hostApi.rlnRefreshTransfers(nodeId, skipSync),
    );
    final transfers = <Object?, Object?>{};
    for (final transfer in response.transfers) {
      if (transfers.containsKey(transfer.index)) {
        throw NativeProtocolException(
          'Native refresh response contains duplicate batch transfer ID ${transfer.index}.',
          field: 'RlnRefreshTransfersData.transfers',
        );
      }
      final transferMap = <Object?, Object?>{};
      final updatedStatus = transfer.updatedStatus;
      if (updatedStatus != null) {
        transferMap['updatedStatus'] = updatedStatus;
      }
      final failure = transfer.failure;
      if (failure != null) {
        transferMap['failure'] = <Object?, Object?>{
          'name': failure.name,
          'message': failure.message,
        };
      }
      transfers[transfer.index] = transferMap;
    }
    return <Object?, Object?>{'transfers': transfers};
  }

  Future<Map<Object?, Object?>> rgbInvoice({
    required int nodeId,
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    required int minConfirmations,
    required bool witness,
    String? assignmentKind,
  }) {
    return _nativeMap(
      'rlnRgbInvoice',
      () => _hostApi.rlnRgbInvoice(
        nodeId,
        assetId,
        assignmentAmount,
        durationSeconds,
        minConfirmations,
        witness,
        assignmentKind,
      ),
    );
  }

  Future<Map<Object?, Object?>> sendBtc({
    required int nodeId,
    required int amount,
    required String address,
    required double feeRate,
    required bool skipSync,
  }) {
    return _nativeMap(
      'rlnSendBtc',
      () => _hostApi.rlnSendBtc(nodeId, amount, address, feeRate, skipSync),
    );
  }

  /// Prepares a durable native operation without authorizing its broadcast.
  Future<String> prepareOnchainSend({
    required int nodeId,
    required String requestJson,
  }) => _native(
    'rlnPrepareOnchainSend',
    () => _hostApi.rlnPrepareOnchainSend(nodeId, requestJson),
  );

  /// Authorizes only the previously prepared native operation.
  Future<String> commitOnchainSend({
    required int nodeId,
    required String requestJson,
  }) => _native(
    'rlnCommitOnchainSend',
    () => _hostApi.rlnCommitOnchainSend(nodeId, requestJson),
  );

  /// Reads durable native status without preparing or broadcasting a payment.
  Future<String> onchainSendStatus({
    required int nodeId,
    required String requestJson,
  }) => _native(
    'rlnOnchainSendStatus',
    () => _hostApi.rlnOnchainSendStatus(nodeId, requestJson),
  );

  /// Revokes only an operation whose end/broadcast has not been authorized.
  Future<String> cancelOnchainSend({
    required int nodeId,
    required String requestJson,
  }) => _native(
    'rlnCancelOnchainSend',
    () => _hostApi.rlnCancelOnchainSend(nodeId, requestJson),
  );

  Future<Map<Object?, Object?>> sendPayment({
    required int nodeId,
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) {
    return _nativeMap(
      'rlnSendPayment',
      () => _hostApi.rlnSendPayment(
        nodeId,
        invoice,
        amtMsat,
        assetId,
        assetAmount,
      ),
    );
  }

  Future<Map<Object?, Object?>> sendRgb({
    required int nodeId,
    required bool donation,
    required double feeRate,
    required int minConfirmations,
    required bool skipSync,
    required String assetId,
    required String recipientId,
    required int amount,
    required List<String> transportEndpoints,
    int? witnessAmountSat,
    int? witnessBlinding,
  }) {
    if (skipSync) {
      throw const UnsupportedWalletFeatureException(
        'rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.',
        feature: 'rlnSendRgb.skipSync',
      );
    }
    return _nativeMap(
      'rlnSendRgb',
      () => _hostApi.rlnSendRgb(
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
      ),
    );
  }

  Future<void> shutdown(int nodeId) {
    return _native('rlnShutdown', () => _hostApi.rlnShutdown(nodeId));
  }

  Future<void> sync(int nodeId) {
    return _native('rlnSync', () => _hostApi.rlnSync(nodeId));
  }

  Future<Map<Object?, Object?>> assetMetadata({
    required int nodeId,
    required String assetId,
  }) => _nativeMap(
    'rlnAssetMetadata',
    () => _hostApi.rlnAssetMetadata(nodeId, assetId),
  );

  Future<Map<Object?, Object?>> postAssetMedia({
    required int nodeId,
    required Uint8List bytes,
  }) => _nativeMap(
    'rlnPostAssetMedia',
    () => _hostApi.rlnPostAssetMedia(nodeId, bytes),
  );

  Future<Object?> issueAssetNia({
    required int nodeId,
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) {
    return _nativeMap(
      'rlnIssueAssetNia',
      () => _hostApi.rlnIssueAssetNia(nodeId, ticker, name, precision, amounts),
    );
  }

  Future<Object?> issueAssetCfa({
    required int nodeId,
    required String name,
    String? details,
    required int precision,
    required List<int> amounts,
    String? fileDigest,
  }) {
    return _nativeMap(
      'rlnIssueAssetCfa',
      () => _hostApi.rlnIssueAssetCfa(
        nodeId,
        name,
        details,
        precision,
        amounts,
        fileDigest,
      ),
    );
  }

  Future<Object?> issueAssetIfa({
    required int nodeId,
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) {
    return _nativeMap(
      'rlnIssueAssetIfa',
      () => _hostApi.rlnIssueAssetIfa(
        nodeId,
        ticker,
        name,
        precision,
        amounts,
        inflationAmounts,
        rejectListUrl,
      ),
    );
  }

  Future<Map<Object?, Object?>> inflate({
    required int nodeId,
    required String assetId,
    required List<int> inflationAmounts,
    required double feeRate,
    required int minConfirmations,
  }) {
    return _nativeMap(
      'rlnInflate',
      () => _hostApi.rlnInflate(
        nodeId,
        assetId,
        inflationAmounts,
        feeRate,
        minConfirmations,
      ),
    );
  }

  Future<Object?> issueAssetUda({
    required int nodeId,
    required String ticker,
    required String name,
    String? details,
    required int precision,
    String? mediaFileDigest,
    List<String> attachmentsFileDigests = const <String>[],
  }) {
    return _nativeMap(
      'rlnIssueAssetUda',
      () => _hostApi.rlnIssueAssetUda(
        nodeId,
        ticker,
        name,
        details,
        precision,
        mediaFileDigest,
        attachmentsFileDigests,
      ),
    );
  }

  Future<void> vssClearFence({required int nodeId, required String password}) {
    return _native(
      'rlnVssClearFence',
      () => _hostApi.rlnVssClearFence(nodeId, password),
    );
  }

  Future<int> vssBackup(int nodeId) {
    return _native('rlnVssBackup', () => _hostApi.rlnVssBackup(nodeId));
  }
}
