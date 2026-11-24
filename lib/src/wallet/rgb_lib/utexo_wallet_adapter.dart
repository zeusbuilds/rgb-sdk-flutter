import '../../errors/rgb_sdk_exception.dart';
import '../../models/imported_rgb_contract.dart';
import '../../models/utexo_core_models.dart';
import '../onchain_recovery.dart';
import '../utexo_wallet_types.dart';
import '../wallet_policy.dart';
import 'rgb_lib_wallet.dart';
import 'wire.dart';

/// Adapts the common facade surface while the selected engine retains its own
/// credentials, connection policy, native session, and durable operation queue.
final class RgbLibFacadeAdapter {
  RgbLibFacadeAdapter(this._rgbLibEngine);

  void _requireFeeRate(double value, String field) =>
      WalletInputPolicy.requireIntegerFeeRate(value, field);

  final RgbLibWallet _rgbLibEngine;

  WalletCapabilities get capabilities => WalletCapabilities(
    psbtSigning: _rgbLibEngine.capabilities.psbtSigning,
    beginEndFlows: _rgbLibEngine.capabilities.beginEndFlows,
    rgbUtxoCreation: !_rgbLibEngine.watchOnly,
    rgbAssetIssuance: !_rgbLibEngine.watchOnly,
  );

  Future<void> init({String? password, String? mnemonic}) async {
    _checkCredentials(password, mnemonic);
    return _rgbLibEngine.init();
  }

  Future<void> unlock({
    String? password,
    required UtexoUnlockConfig config,
  }) async {
    throw _requiresTypedEngine('unlock');
  }

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

  Future<FeeEstimationResponse> estimateFeeRate(int blocks) async =>
      FeeEstimationResponse(
        feeRate: (await _rgbLibEngine.estimateFeeRate(blocks)).toDouble(),
      );

  Future<IndexerCheckResponse> checkIndexerUrl(String url) async =>
      IndexerCheckResponse(
        indexerProtocol: (await _rgbLibEngine.checkIndexerUrl(
          url,
        )).indexerProtocol,
      );

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

  Future<CoreInvoiceReceiveData> blindReceive(
    RgbInvoiceRequest request,
  ) async => _receive(request, witness: false);

  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async => _receive(request, witness: true);

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

  Future<ImportedRgbContract> importRgbContract({
    required String contractBase64,
    required String expectedAssetId,
  }) => _rgbLibEngine.importContract(
    contractBase64: contractBase64,
    expectedAssetId: expectedAssetId,
  );

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

  Future<RecoverableOnchainSendCommand> createRecoverableRgbSendCommand({
    required String operationId,
    required RgbSendRequest request,
  }) => _rgbLibEngine.createRecoverableRgbSendCommand(
    operationId: operationId,
    request: request,
  );

  Future<RecoverableOnchainSendStatus> prepareOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.prepareOnchainSend(command);

  Future<RecoverableOnchainSendStatus> commitOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.commitOnchainSend(command);

  Future<RecoverableOnchainSendStatus> onchainSendStatus(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.onchainSendStatus(command);

  Future<RecoverableOnchainSendStatus> cancelOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _rgbLibEngine.cancelOnchainSend(command);
}
