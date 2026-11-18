part of '../utexo_wallet.dart';

/// Adapts the common facade surface while the selected engine retains its own
/// credentials, connection policy, native session, and durable operation queue.
final class _RgbLibWalletFacade extends UtexoWallet {
  _RgbLibWalletFacade(this._rgbLibEngine) : super._withoutRln();

  final RgbLibWallet _rgbLibEngine;

  @override
  String get network => _rgbLibEngine.network;

  @override
  String getNetwork() => _rgbLibEngine.getNetwork();

  @override
  bool get isInitialized => _rgbLibEngine.isInitialized;

  @override
  bool get isUnlocked => _rgbLibEngine.isUnlocked;

  @override
  bool get isShutdown => _rgbLibEngine.isShutdown;

  @override
  bool isDisposed() => _rgbLibEngine.isDisposed();

  @override
  WalletCapabilities get capabilities => WalletCapabilities(
    psbtSigning: _rgbLibEngine.capabilities.psbtSigning,
    beginEndFlows: _rgbLibEngine.capabilities.beginEndFlows,
    rgbUtxoCreation: !_rgbLibEngine.watchOnly,
    rgbAssetIssuance: !_rgbLibEngine.watchOnly,
  );

  @override
  Future<void> init({String? password, String? mnemonic}) async {
    _checkCredentials(password, mnemonic);
    return _rgbLibEngine.init();
  }

  @override
  Future<void> unlock({
    String? password,
    required UtexoUnlockConfig config,
  }) async {
    throw _requiresTypedEngine('unlock');
  }

  @override
  Future<void> reinit({
    String? password,
    String? mnemonic,
    UtexoUnlockConfig? unlockConfig,
  }) async {
    _checkCredentials(password, mnemonic);
    if (unlockConfig != null) throw _requiresTypedEngine('reinit');
    return _rgbLibEngine.reinit();
  }

  void _checkCredentials(String? password, String? mnemonic) {
    if (password != null || mnemonic != null) {
      throw const WalletValidationException(
        'Configure RGB_L1 credentials on the selected RgbLibWallet.',
        field: 'engine',
      );
    }
  }

  UnsupportedWalletFeatureException _requiresTypedEngine(String operation) =>
      UnsupportedWalletFeatureException(
        'Use rgbLibEngine.$operation with RGB_L1 configuration.',
        feature: operation,
      );

  @override
  Future<void> shutdown() => _rgbLibEngine.shutdown();

  @override
  Future<void> destroy() => _rgbLibEngine.destroy();

  @override
  Future<String> getAddress() => _rgbLibEngine.getAddress();

  @override
  Future<String> rotateVanillaAddress() => _rgbLibEngine.rotateVanillaAddress();

  @override
  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false}) =>
      _rgbLibEngine.getBtcBalance(skipSync: skipSync);

  @override
  Future<CoreAssetBalance> getAssetBalance(String assetId) =>
      _rgbLibEngine.getAssetBalance(assetId);

  @override
  Future<RgbLibAssetMetadata> getAssetMetadata(String assetId) =>
      _rgbLibEngine.getAssetMetadata(assetId);

  @override
  Future<CoreListAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async => _rgbLibEngine.listAssets(
    filterAssetSchemas: filterAssetSchemas.map(_rgbLibAssetSchema).toList(),
  );

  RgbLibAssetSchema _rgbLibAssetSchema(String schema) {
    for (final value in RgbLibAssetSchema.values) {
      if (value.wireValue == schema) return value;
    }
    throw const WalletValidationException(
      'Asset schema filter contains an unsupported schema.',
      field: 'filterAssetSchemas',
    );
  }

  @override
  Future<List<CoreUnspent>> listUnspents({bool skipSync = false}) =>
      _rgbLibEngine.listUnspents(skipSync: skipSync);

  @override
  Future<List<CoreTransaction>> listTransactions({bool skipSync = false}) =>
      _rgbLibEngine.listTransactions(skipSync: skipSync);

  @override
  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) => _rgbLibEngine.listTransactionsByTxid(txid, skipSync: skipSync);

  @override
  Future<List<CoreTransfer>> listTransfers({String? assetId}) =>
      _rgbLibEngine.listTransfers(assetId: assetId);

  @override
  Future<List<CoreTransfer>> listTransfersByTxid(String txid) =>
      _rgbLibEngine.listTransfersByTxid(txid);

  @override
  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) => _rgbLibEngine.failTransfers(
    batchTransferIdx: batchTransferIdx,
    noAssetOnly: noAssetOnly,
    skipSync: skipSync,
  );

  @override
  Future<RefreshTransfersResult> refreshTransfers({bool skipSync = false}) =>
      _rgbLibEngine.refreshTransfers(skipSync: skipSync);

  @override
  Future<void> refreshWallet() => _rgbLibEngine.refreshWallet();

  @override
  Future<void> syncWallet() => _rgbLibEngine.syncWallet();

  @override
  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requireFeeRate(feeRate, 'feeRate');
    return _rgbLibEngine.createUtxos(
      upTo: upTo,
      num: num,
      size: size,
      feeRate: feeRate.toInt(),
      skipSync: skipSync,
    );
  }

  @override
  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requireFeeRate(feeRate, 'feeRate');
    return _rgbLibEngine.sendBtc(
      amount: amount,
      address: address,
      feeRate: feeRate.toInt(),
      skipSync: skipSync,
    );
  }

  @override
  Future<CoreAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async => _rgbLibEngine.issueAssetNia(
    ticker: ticker,
    name: name,
    precision: precision,
    amounts: amounts.map(BigInt.from).toList(),
  );

  @override
  Future<CoreAssetCfa> issueAssetCfa({
    required String name,
    required int precision,
    required List<int> amounts,
    String? details,
    String? filePath,
  }) async => _rgbLibEngine.issueAssetCfa(
    name: name,
    precision: precision,
    amounts: amounts.map(BigInt.from).toList(),
    details: details,
    filePath: filePath,
  );

  @override
  Future<CoreAssetUda> issueAssetUda({
    required String ticker,
    required String name,
    required int precision,
    String? details,
    String? mediaFilePath,
    List<String> attachmentsFilePaths = const [],
  }) async => _rgbLibEngine.issueAssetUda(
    ticker: ticker,
    name: name,
    precision: precision,
    details: details,
    mediaFilePath: mediaFilePath,
    attachmentsFilePaths: attachmentsFilePaths,
  );

  @override
  Future<CoreAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async {
    if (rejectListUrl == null) {
      throw const WalletValidationException(
        'RGB_L1 inflation requires a reject list URL.',
        field: 'rejectListUrl',
      );
    }
    return _rgbLibEngine.issueAssetIfa(
      ticker: ticker,
      name: name,
      precision: precision,
      amounts: amounts.map(BigInt.from).toList(),
      inflationAmounts: inflationAmounts.map(BigInt.from).toList(),
      rejectListUrl: rejectListUrl,
    );
  }

  @override
  Future<InflateAssetIfaResponse> inflate(
    InflateAssetIfaRequest request,
  ) async {
    _requireFeeRate(request.feeRate, 'feeRate');
    final result = await _rgbLibEngine.inflate(
      assetId: request.assetId,
      inflationAmounts: request.inflationAmounts.map(BigInt.from).toList(),
      feeRate: request.feeRate.toInt(),
      minConfirmations: request.minConfirmations,
    );
    return InflateAssetIfaResponse(txid: result.txid);
  }

  @override
  Future<FeeEstimationResponse> estimateFeeRate(int blocks) async =>
      FeeEstimationResponse(
        feeRate: (await _rgbLibEngine.estimateFeeRate(blocks)).toDouble(),
      );

  @override
  Future<IndexerCheckResponse> checkIndexerUrl(String url) async =>
      IndexerCheckResponse(
        indexerProtocol: (await _rgbLibEngine.checkIndexerUrl(
          url,
        )).indexerProtocol,
      );

  @override
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) =>
      _rgbLibEngine.decodeRgbInvoice(invoice);

  Future<RgbLibReceiveData> _receive(
    RgbInvoiceRequest request, {
    required bool witness,
  }) {
    return _rgbLibEngine.onchainReceive(
      witness: witness,
      assetId: request.assetId,
      amount: request.amount == null ? null : BigInt.from(request.amount!),
      durationSeconds: request.durationSeconds ?? 86400,
      minConfirmations: request.minConfirmations,
      assignmentKind: switch (request.assignmentKind) {
        RgbReceiveAssignmentKind.fungible => RgbLibReceiveAssignment.fungible,
        RgbReceiveAssignmentKind.nonFungible =>
          RgbLibReceiveAssignment.nonFungible,
        RgbReceiveAssignmentKind.inflationRight =>
          RgbLibReceiveAssignment.inflationRight,
        RgbReceiveAssignmentKind.any => RgbLibReceiveAssignment.any,
        null => null,
      },
    );
  }

  @override
  Future<CoreInvoiceReceiveData> blindReceive(
    RgbInvoiceRequest request,
  ) async => _receive(request, witness: false);

  @override
  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async => _receive(request, witness: true);

  @override
  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async {
    final result = await _receive(request, witness: request.witness);
    return OnchainReceiveResponse(
      invoice: result.invoice,
      recipientId: result.recipientId,
      expirationTimestamp: result.expirationTimestamp,
      batchTransferIdx: result.batchTransferIdx,
    );
  }

  @override
  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async {
    _requireFeeRate(request.feeRate, 'feeRate');
    final result = await _rgbLibEngine.onchainSend(
      invoice: request.invoice,
      assetId: request.assetId,
      amount: request.amount == null ? null : BigInt.from(request.amount!),
      witnessAmountSat: request.witnessAmountSat,
      witnessBlinding: request.witnessBlinding == null
          ? null
          : BigInt.from(request.witnessBlinding!),
      donation: request.donation,
      feeRate: request.feeRate.toInt(),
      minConfirmations: request.minConfirmations,
      skipSync: request.skipSync,
    );
    return OnchainSendResponse(
      txid: result.txid,
      batchTransferIdx: result.batchTransferIdx,
    );
  }

  @override
  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) async {
    final result = await _rgbLibEngine.exportBackupToFile(
      filePath: backupPath,
      password: password,
    );
    return WalletBackupResponse(
      message: result.message,
      backupPath: result.backupPath,
    );
  }

  @override
  Future<ImportedRgbContract> importRgbContract({
    required String contractBase64,
    required String expectedAssetId,
  }) => _rgbLibEngine.importContract(
    contractBase64: contractBase64,
    expectedAssetId: expectedAssetId,
  );

  @override
  Future<BfaCapabilities> getBfaCapabilities() =>
      _rgbLibEngine.getBfaCapabilities();

  @override
  Future<BurnResult> burn(BurnParams params) => _rgbLibEngine.burn(params);

  @override
  Future<String> getConsignment(String assetId, String txid) =>
      _rgbLibEngine.getConsignment(assetId, txid);

  @override
  Future<String> getConsignmentPath(String assetId, String txid) =>
      _rgbLibEngine.getConsignmentPath(assetId, txid);

  @override
  Future<RecoverableOnchainSendCommand> createRecoverableBtcSendCommand({
    required String operationId,
    required int amount,
    required String address,
    double feeRate = 1,
  }) => _rgbLibEngine.createRecoverableBtcSendCommand(
    operationId: operationId,
    amount: amount,
    address: address,
    feeRate: feeRate,
  );

  @override
  Future<RecoverableOnchainSendCommand> createRecoverableRgbSendCommand({
    required String operationId,
    required RgbSendRequest request,
  }) => _rgbLibEngine.createRecoverableRgbSendCommand(
    operationId: operationId,
    request: request,
  );

  @override
  Future<RecoverableOnchainSendStatus> prepareOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.prepareOnchainSend(command);

  @override
  Future<RecoverableOnchainSendStatus> commitOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.commitOnchainSend(command);

  @override
  Future<RecoverableOnchainSendStatus> onchainSendStatus(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.onchainSendStatus(command);

  @override
  Future<RecoverableOnchainSendStatus> cancelOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.cancelOnchainSend(command);
}
