part of 'utexo_wallet.dart';

// A fresh command can initialize its outbox only on its first status attempt.
// This session latch is deliberately absent from the persisted JSON envelope.
final _recoverableStatusAttempted = Expando<bool>('recoverableStatusAttempted');

mixin _UtexoWalletOnchain on _UtexoWalletInternals {
  /// Constructs wallet-bound Bitcoin inputs without preparing or broadcasting.
  /// Check [onchainSendStatus] once before saving an app marker; then persist
  /// the returned command before invoking [prepareOnchainSend].
  Future<RecoverableOnchainSendCommand> createRecoverableBtcSendCommand({
    required String operationId,
    required int amount,
    required String address,
    double feeRate = 1,
  }) => _withLifecycle(() async {
    _requireRecoverableMode();
    _requireUnlockedNode();
    _requireFeeRate(feeRate, 'feeRate');
    return _validatedRecoverableCommand(
      network: normalizeNativeRlnNetwork(_config.network),
      walletBinding: await _recoverableWalletBinding(),
      request: <String, Object?>{
        'version': 1,
        'operationId': operationId,
        'kind': 'bitcoin',
        'amount': amount,
        'feeRate': feeRate.toInt(),
        'address': address,
        'transportEndpoints': const <String>[],
        'minConfirmations': 1,
        'donation': false,
      },
    );
  });

  /// Decodes and validates RGB inputs before any durable prepare dispatch.
  /// Donation and skip-sync modes are deliberately unsupported by this protocol.
  Future<RecoverableOnchainSendCommand> createRecoverableRgbSendCommand({
    required String operationId,
    required RgbSendRequest request,
  }) => _withLifecycle(() async {
    _requireRecoverableMode();
    _requireUnlockedNode();
    _requireFeeRate(request.feeRate, 'feeRate');
    _requireSupportedRgbSendSkipSync(request.skipSync);
    if (request.donation) _recoverableInvalid('donation');
    if (request.amount == null) _recoverableInvalid('amount');
    final decoded = await _decodeRgbInvoiceRaw(request.invoice);
    if (normalizeNativeRlnNetwork(decoded.network) !=
        normalizeNativeRlnNetwork(_config.network)) {
      _recoverableInvalid('invoice.network');
    }
    if (decoded.assetId != null &&
        request.assetId != null &&
        decoded.assetId != request.assetId) {
      _recoverableInvalid('invoice.assetId');
    }
    return _validatedRecoverableCommand(
      network: normalizeNativeRlnNetwork(_config.network),
      walletBinding: await _recoverableWalletBinding(),
      request: <String, Object?>{
        'version': 1,
        'operationId': operationId,
        'kind': 'rgb',
        'amount': request.amount,
        'feeRate': request.feeRate.toInt(),
        'assetId': request.assetId ?? decoded.assetId,
        'recipientId': decoded.recipientId,
        'transportEndpoints': decoded.transportEndpoints,
        'witnessAmountSat': request.witnessAmountSat,
        'witnessBlinding': request.witnessBlinding,
        'minConfirmations': request.minConfirmations,
        'donation': false,
        // Bind the pinned native default once, before durable app dispatch.
        'expirationTimestamp':
            decoded.expirationTimestamp ??
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 86400,
      },
    );
  });

  Future<String> _recoverableWalletBinding() async {
    final nodeId = _requireUnlockedNode();
    final info = await _binding.rlnNodeInfo();
    if (_requireUnlockedNode() != nodeId) {
      _recoverableInvalid('command.wallet');
    }
    final vanilla = info.accountXpubVanilla;
    final colored = info.accountXpubColored;
    if (vanilla == null ||
        colored == null ||
        vanilla.isEmpty ||
        colored.isEmpty ||
        vanilla != vanilla.trim() ||
        colored != colored.trim() ||
        vanilla.length > 16384 ||
        colored.length > 16384 ||
        vanilla.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        colored.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const NativeProtocolException(
        'Native wallet account identity is unavailable.',
        field: 'RlnNodeInfo.accountXpubs',
      );
    }
    return crypto.sha256
        .convert(
          utf8.encode(
            jsonEncode(<Object?>[
              'rgb_sdk_flutter/recoverable-wallet/v2',
              normalizeNativeRlnNetwork(_config.network),
              vanilla,
              colored,
            ]),
          ),
        )
        .toString();
  }

  Future<void> _requireRecoverableCommandWallet(
    RecoverableOnchainSendCommand command, {
    bool allowMissingOutbox = false,
  }) async {
    _requireRecoverableMode();
    _requireUnlockedNode();
    if (command.network != normalizeNativeRlnNetwork(_config.network) ||
        (command.version == 1 &&
            command.storageDirPath != _config.storageDirPath)) {
      _recoverableInvalid('command.wallet');
    }
    // Check the current physical cohort before any native identity/outbox call.
    await requireRecoverableStorage(
      _config.storageDirPath,
      allowMissingOutbox: allowMissingOutbox,
    );
    if (command.version == 2 &&
        command.walletBinding != await _recoverableWalletBinding()) {
      _recoverableInvalid('command.wallet');
    }
  }

  void _requireRecoverableMode() {
    if (_config.vssUrl != null ||
        _config.vssAllowHttp ||
        _config.vssAllowEmptyRestore) {
      throw const UnsupportedWalletFeatureException(
        'Recoverable on-chain sends are unavailable with VSS configuration.',
        feature: 'recoverableOnchainSendVss',
      );
    }
  }

  /// Prepares/signs exactly one durable operation without authorizing broadcast.
  /// Native and transport failures never fall back to a one-shot send or retry.
  Future<RecoverableOnchainSendStatus> prepareOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _withLifecycle(() async {
    await _requireRecoverableCommandWallet(command);
    return _decodeRecoverableStatus(
      await _binding.rlnPrepareOnchainSend(command._nativeRequestJson),
      command,
    );
  });

  /// Explicitly authorizes the prepared operation, using its existing identity.
  /// Call only after persisting the application's reviewed commit intent.
  Future<RecoverableOnchainSendStatus> commitOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _withLifecycle(() async {
    await _requireRecoverableCommandWallet(command);
    return _decodeRecoverableStatus(
      await _binding.rlnCommitOnchainSend(command._nativeRequestJson),
      command,
    );
  });

  /// Checks durable status without releasing payment. Native may durably record
  /// an observed receipt. It never calls prepare, commit, or one-shot send.
  /// After an in-flight native deadline, identity/status inspection and pure
  /// RGB invoice decoding for restored-intent validation wait for
  /// that original native call to finish. It preserves the timeout quarantine;
  /// ordinary operations still require explicit lifecycle recovery. If native
  /// never finishes, inspection reaches its own deadline without dispatching.
  /// Only the first fresh-command preflight may initialize a missing outbox.
  /// Restored commands and later calls require the intact private directory.
  Future<RecoverableOnchainSendStatus> onchainSendStatus(
    RecoverableOnchainSendCommand command,
  ) => _withLifecycle(() async {
    final canInitialize =
        !command._restored && _recoverableStatusAttempted[command] != true;
    _recoverableStatusAttempted[command] = true;
    await _requireRecoverableCommandWallet(
      command,
      allowMissingOutbox: canInitialize,
    );
    final status = _decodeRecoverableStatus(
      await _binding.rlnOnchainSendStatus(command._nativeRequestJson),
      command,
    );
    await requireRecoverableStorage(_config.storageDirPath);
    return status;
  });

  /// Cancels only a native operation whose end/broadcast was never authorized.
  /// Commit-authorized operations remain fenced and return their actual status.
  /// Cancellation may require an explicit subsequent cancellation attempt after
  /// interrupted reservation cleanup; it never dispatches a replacement send.
  Future<RecoverableOnchainSendStatus> cancelOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _withLifecycle(() async {
    await _requireRecoverableCommandWallet(command);
    return _decodeRecoverableStatus(
      await _binding.rlnCancelOnchainSend(command._nativeRequestJson),
      command,
    );
  });

  Future<RlnNodeInfo> _nodeInfoRaw() async {
    _requireNode();
    return _binding.rlnNodeInfo();
  }

  Future<WalletNodeInfo> getNodeInfo() async {
    return (await _nodeInfoRaw()).toWalletNodeInfo();
  }

  Future<RlnNetworkInfo> _networkInfoRaw() async {
    _requireUnlockedNode();
    return _binding.rlnNetworkInfo();
  }

  Future<WalletNetworkInfo> getNetworkInfo() async {
    return (await _networkInfoRaw()).toWalletNetworkInfo();
  }

  Future<RlnBtcBalance> _getBtcBalanceRaw({bool skipSync = false}) async {
    _requireUnlockedNode();
    return _binding.rlnBtcBalance(skipSync);
  }

  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false}) async {
    return (await _getBtcBalanceRaw(skipSync: skipSync)).toCore();
  }

  Future<String> getAddress() async {
    _requireUnlockedNode();
    return (await _binding.rlnAddress()).address;
  }

  Future<List<RlnUnspent>> _listUnspentsRaw({bool skipSync = false}) async {
    _requireUnlockedNode();
    return _binding.rlnListUnspents(skipSync);
  }

  Future<List<CoreUnspent>> listUnspents({bool skipSync = false}) async {
    return (await _listUnspentsRaw(
      skipSync: skipSync,
    )).map((unspent) => unspent.toCore()).toList(growable: false);
  }

  /// Creates UTXOs and returns the observed number of new colorable outputs.
  /// An unavailable post-create count means creation was acknowledged. Check
  /// history and output inventory before considering another creation.
  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requireUInt8Optional(num, 'num');
    _requireUInt32Optional(size, 'size');
    if (num != null) _requirePositive(num, 'num');
    if (size != null) _requirePositive(size, 'size');
    _requireFeeRate(feeRate, 'feeRate');
    _ensureRgbUtxoCreationSupported();
    _requireUnlockedNode();
    return _binding.rlnCreateUtxosCounted(upTo, num, size, feeRate, skipSync);
  }

  Future<RlnAssets> _listAssetsRaw({
    List<String> filterAssetSchemas = const [],
  }) async {
    _requireUnlockedNode();
    return _binding.rlnListAssets(filterAssetSchemas);
  }

  Future<CoreListAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async {
    final schemas = List<String>.unmodifiable(filterAssetSchemas);
    if (schemas.any(
      (schema) => !const {'Nia', 'Cfa', 'Uda', 'Ifa', 'Bfa'}.contains(schema),
    )) {
      throw const WalletValidationException(
        'Asset schema filter contains an unsupported schema.',
        field: 'filterAssetSchemas',
      );
    }
    return (await _listAssetsRaw(filterAssetSchemas: schemas)).toCore();
  }

  Future<RlnAssetBalance> _getAssetBalanceRaw(String assetId) async {
    _requireNonEmpty(assetId, 'assetId');
    _requireUnlockedNode();
    return _binding.rlnAssetBalance(assetId);
  }

  Future<CoreAssetBalance> getAssetBalance(String assetId) async {
    return (await _getAssetBalanceRaw(assetId)).toCore();
  }

  Future<String> rotateVanillaAddress() async {
    _requireUnlockedNode();
    return (await _binding.rlnRotateAddress()).address;
  }

  Future<RlnAssetNia> _issueAssetNiaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    WalletInputPolicy.requireAssetPrecision(precision);
    final issued = List<int>.unmodifiable(amounts);
    WalletInputPolicy.requireAssetSupply(issued);
    _ensureRgbAssetIssuanceSupported('issueAssetNia');
    _requireUnlockedNode();
    return RlnAssetNia.fromMap(
      _asRlnMap(
        await _binding.rlnIssueAssetNia(ticker, name, precision, issued),
      ),
    );
  }

  Future<CoreAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async {
    return (await _issueAssetNiaRaw(
      ticker: ticker,
      name: name,
      precision: precision,
      amounts: amounts,
    )).toCore();
  }

  Future<RlnAssetIfa> _issueAssetIfaRaw({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    WalletInputPolicy.requireAssetPrecision(precision);
    final issued = List<int>.unmodifiable(amounts);
    final inflatable = List<int>.unmodifiable(inflationAmounts);
    WalletInputPolicy.requireAssetSupply(issued, inflationAmounts: inflatable);
    _ensureRgbAssetIssuanceSupported('issueAssetIfa');
    _requireUnlockedNode();
    return RlnAssetIfa.fromMap(
      _asRlnMap(
        await _binding.rlnIssueAssetIfa(
          ticker,
          name,
          precision,
          issued,
          inflatable,
          rejectListUrl,
        ),
      ),
    );
  }

  Future<CoreAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async {
    return (await _issueAssetIfaRaw(
      ticker: ticker,
      name: name,
      precision: precision,
      amounts: amounts,
      inflationAmounts: inflationAmounts,
      rejectListUrl: rejectListUrl,
    )).toCore();
  }

  Future<RlnInvoice> _blindReceiveRaw(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: false);
  }

  Future<CoreInvoiceReceiveData> blindReceive(RgbInvoiceRequest request) async {
    return (await _blindReceiveRaw(request)).toCore();
  }

  Future<RlnInvoice> _witnessReceiveRaw(RgbInvoiceRequest request) {
    return _rgbInvoice(request, witness: true);
  }

  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async {
    return (await _witnessReceiveRaw(request)).toCore();
  }

  Future<RlnDecodedRgbInvoice> _decodeRgbInvoiceRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnDecodeRgbInvoice(invoice);
  }

  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) async {
    return (await _decodeRgbInvoiceRaw(invoice)).toCore(invoice);
  }

  @override
  Future<RlnSendResult> _sendRgb(RgbSendRequest request) {
    final invoice = request.invoice;
    final requestedAssetId = request.assetId;
    final requestedAmount = request.amount;
    final donation = request.donation;
    final feeRate = request.feeRate;
    final minConfirmations = request.minConfirmations;
    final skipSync = request.skipSync;
    final witnessAmountSat = request.witnessAmountSat;
    final witnessBlinding = request.witnessBlinding;

    return _withLifecycle(() async {
      _requireNonEmpty(invoice, 'invoice');
      if (requestedAssetId != null) {
        _requireNonEmpty(requestedAssetId, 'assetId');
      }
      if (requestedAmount != null) _requirePositive(requestedAmount, 'amount');
      if (witnessAmountSat != null) {
        _requirePositive(witnessAmountSat, 'witnessAmountSat');
      }
      _requireFeeRate(feeRate, 'feeRate');
      _requireUInt8(minConfirmations, 'minConfirmations');
      _requireNonNegativeOptional(witnessBlinding, 'witnessBlinding');
      if (witnessBlinding != null && witnessAmountSat == null) {
        throw const WalletValidationException(
          'Witness blinding requires a Bitcoin output amount.',
          field: 'witnessAmountSat',
        );
      }
      _requireSupportedRgbSendSkipSync(skipSync);

      final decoded = await _decodeRgbInvoiceRaw(invoice);
      if (normalizeNativeRlnNetwork(decoded.network) !=
          normalizeNativeRlnNetwork(_config.network)) {
        throw const WalletValidationException(
          'RGB invoice network does not match the wallet.',
          field: 'invoice.network',
        );
      }
      if (decoded.expirationTimestamp case final expiry?
          when expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        throw const WalletValidationException(
          'RGB invoice has expired.',
          field: 'invoice.expirationTimestamp',
        );
      }
      final assetId = requestedAssetId ?? decoded.assetId;
      if (assetId == null ||
          assetId.isEmpty ||
          (decoded.assetId != null && decoded.assetId != assetId)) {
        throw const WalletValidationException(
          'The RGB asset must match the invoice.',
          field: 'assetId',
        );
      }
      _requireNonEmpty(decoded.recipientId, 'recipientId');
      final assignment = parseCoreAssignment(decoded.assignment);
      if (assignment.type != 'Fungible' && assignment.type != 'Any') {
        throw const WalletValidationException(
          'RGB send requires a fungible invoice assignment.',
          field: 'invoice.assignment',
        );
      }
      final invoiceAmount = assignment.amount;
      if (invoiceAmount != null &&
          (invoiceAmount <= BigInt.zero ||
              invoiceAmount > BigInt.from(rlnPigeonMaxSignedInt64) ||
              (requestedAmount != null &&
                  BigInt.from(requestedAmount) != invoiceAmount))) {
        throw const WalletValidationException(
          'The send amount must match the supported invoice amount.',
          field: 'amount',
        );
      }
      final amount = requestedAmount ?? invoiceAmount?.toInt();
      if (amount == null) {
        throw const WalletValidationException(
          'Amount is required for RGB send.',
          field: 'amount',
        );
      }

      return _binding.rlnSendRgb(
        donation,
        feeRate,
        minConfirmations,
        skipSync,
        assetId,
        decoded.recipientId,
        amount,
        decoded.transportEndpoints,
        witnessAmountSat == null
            ? null
            : RlnWitnessData(
                amountSat: witnessAmountSat,
                blinding: witnessBlinding,
              ),
      );
    });
  }

  Future<RlnInflateResult> _inflateRaw(InflateAssetIfaRequest request) async {
    final assetId = request.assetId;
    final inflationAmounts = List<int>.unmodifiable(request.inflationAmounts);
    final feeRate = request.feeRate;
    final minConfirmations = request.minConfirmations;
    _requireNonEmpty(assetId, 'assetId');
    if (inflationAmounts.isEmpty) {
      throw const WalletValidationException(
        'inflationAmounts must not be empty.',
        field: 'inflationAmounts',
      );
    }
    WalletInputPolicy.requireAssetSupply(
      const [],
      inflationAmounts: inflationAmounts,
    );
    _requireFeeRate(feeRate, 'feeRate');
    _requireUInt8(minConfirmations, 'minConfirmations');
    _ensureRgbAssetIssuanceSupported('inflate');
    _requireUnlockedNode();
    return _binding.rlnInflate(
      assetId,
      inflationAmounts,
      feeRate,
      minConfirmations,
    );
  }

  Future<InflateAssetIfaResponse> inflate(
    InflateAssetIfaRequest request,
  ) async {
    final result = await _inflateRaw(request);
    return InflateAssetIfaResponse(txid: result.txid);
  }

  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1,
    bool skipSync = false,
  }) async {
    _requirePositive(amount, 'amount');
    _requireNonEmpty(address, 'address');
    _requireFeeRate(feeRate, 'feeRate');
    _requireUnlockedNode();
    final response = await _binding.rlnSendBtc(
      amount,
      address,
      feeRate,
      skipSync,
    );
    return _requiredNativeString(response, 'txid', 'RlnSendBtcResponse');
  }

  Future<List<RlnTransaction>> _listTransactionsRaw({
    bool skipSync = false,
  }) async {
    _requireUnlockedNode();
    return _binding.rlnListTransactions(skipSync);
  }

  Future<List<CoreTransaction>> listTransactions({
    bool skipSync = false,
  }) async {
    return (await _listTransactionsRaw(
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<RlnTransaction>> _listTransactionsByTxidRaw(
    String txid, {
    bool skipSync = false,
  }) async {
    _requireNonEmpty(txid, 'txid');
    _requireUnlockedNode();
    return _binding.rlnListTransactionsByTxid(txid, skipSync);
  }

  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async {
    return (await _listTransactionsByTxidRaw(
      txid,
      skipSync: skipSync,
    )).map((transaction) => transaction.toCore()).toList(growable: false);
  }

  Future<List<RlnTransfer>> _listTransfersRaw({String? assetId}) async {
    _requireUnlockedNode();
    return _binding.rlnListTransfers(assetId ?? '');
  }

  Future<List<CoreTransfer>> listTransfers({String? assetId}) async {
    return (await _listTransfersRaw(
      assetId: assetId,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<List<RlnTransfer>> _listTransfersByTxidRaw(String txid) async {
    _requireNonEmpty(txid, 'txid');
    _requireUnlockedNode();
    return _binding.rlnListTransfersByTxid(txid);
  }

  Future<List<CoreTransfer>> listTransfersByTxid(String txid) async {
    return (await _listTransfersByTxidRaw(
      txid,
    )).map((transfer) => transfer.toCore()).toList(growable: false);
  }

  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) async {
    _requireNonNegativeOptional(batchTransferIdx, 'batchTransferIdx');
    if (batchTransferIdx != null && batchTransferIdx > 0x7fffffff) {
      throw const WalletValidationException(
        'batchTransferIdx must fit in Int32.',
        field: 'batchTransferIdx',
      );
    }
    _requireUnlockedNode();
    final response = await _binding.rlnFailTransfers(
      batchTransferIdx,
      noAssetOnly,
      skipSync,
    );
    return _requiredNativeBool(
      response,
      'transfersChanged',
      'RlnFailTransfersResponse',
    );
  }

  Future<RlnRefreshTransfersResult> _refreshTransfersRaw({
    bool skipSync = false,
  }) {
    _requireUnlockedNode();
    return _binding.rlnRefreshTransfers(skipSync);
  }

  Future<RefreshTransfersResult> refreshTransfers({
    bool skipSync = false,
  }) async {
    final result = await _refreshTransfersRaw(skipSync: skipSync);
    return RefreshTransfersResult(
      transfers: result.transfers.map(
        (index, transfer) => MapEntry(
          index,
          RefreshedTransfer(
            updatedStatus: transfer.updatedStatus == null
                ? null
                : UtexoDomainPolicy.requireTransferStatus(
                    transfer.updatedStatus!,
                  ),
            failure: transfer.failure == null
                ? null
                : RefreshFailure(
                    name: transfer.failure!.name,
                    message: transfer.failure!.message,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> refreshWallet() async {
    await refreshTransfers();
  }

  Future<void> syncWallet() {
    _requireUnlockedNode();
    return _binding.rlnSync();
  }

  Future<RlnFeeRate> _estimateFeeRateRaw(int blocks) async {
    _requirePositive(blocks, 'blocks');
    _requireUInt16(blocks, 'blocks');
    _requireUnlockedNode();
    return _binding.rlnEstimateFee(blocks);
  }

  Future<FeeEstimationResponse> estimateFeeRate(int blocks) async {
    final result = await _estimateFeeRateRaw(blocks);
    final rate = result.feeRate;
    if (!rate.isFinite ||
        rate <= 0 ||
        rate >= rlnPigeonMaxSignedInt64.toDouble()) {
      throw const NativeProtocolException(
        'Native fee estimate is outside the supported range.',
        field: 'RlnFeeRate.feeRate',
      );
    }
    return FeeEstimationResponse(feeRate: rate.ceilToDouble());
  }

  Future<RlnIndexerCheck> _checkIndexerUrlRaw(String url) async {
    _requireNonEmpty(url, 'url');
    _requireUnlockedNode();
    return _binding.rlnCheckIndexerUrl(url);
  }

  Future<IndexerCheckResponse> checkIndexerUrl(String url) async {
    final result = await _checkIndexerUrlRaw(url);
    return IndexerCheckResponse(
      indexerProtocol: result.indexerProtocol.toLowerCase(),
    );
  }

  Future<void> checkProxyEndpoint(String endpoint) {
    _requireNonEmpty(endpoint, 'endpoint');
    _requireUnlockedNode();
    return _binding.rlnCheckProxyEndpoint(endpoint);
  }

  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) {
    _requireNonEmpty(backupPath, 'backupPath');
    _requireNonEmpty(password, 'password');
    throw const UnsupportedWalletFeatureException(
      'createBackup is native-blocked by the current RLN/RN contract and is '
      'not a recovery-ready API.',
      feature: 'createBackup',
    );
  }

  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async {
    final invoice = await _rgbInvoice(request, witness: request.witness);
    return OnchainReceiveResponse(
      invoice: invoice.invoice,
      recipientId: invoice.recipientId,
      expirationTimestamp: invoice.expirationTimestamp,
      batchTransferIdx: invoice.batchTransferIdx,
    );
  }

  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async {
    final result = await _sendRgb(request);
    return OnchainSendResponse(
      txid: result.txid,
      batchTransferIdx: result.batchTransferIdx,
    );
  }

  Future<List<CoreTransfer>> listOnchainTransfers({String? assetId}) {
    return listTransfers(assetId: assetId);
  }

  @override
  Future<RlnInvoice> _rgbInvoice(
    RgbInvoiceRequest request, {
    required bool witness,
  }) async {
    final amount = request.amount;
    final kind = switch (request.assignmentKind) {
      RgbReceiveAssignmentKind.fungible => RlnAssignmentKind.fungible,
      RgbReceiveAssignmentKind.nonFungible => RlnAssignmentKind.nonFungible,
      RgbReceiveAssignmentKind.inflationRight =>
        RlnAssignmentKind.inflationRight,
      RgbReceiveAssignmentKind.any => RlnAssignmentKind.any,
      null => amount == null ? null : RlnAssignmentKind.fungible,
    };
    final requiresAmount =
        kind == RlnAssignmentKind.fungible ||
        kind == RlnAssignmentKind.inflationRight;
    if (requiresAmount != (amount != null)) {
      throw const WalletValidationException(
        'Amount does not match the selected assignment kind.',
        field: 'amount',
      );
    }
    if (amount != null) _requirePositive(amount, 'amount');
    final duration = request.durationSeconds;
    if (duration != null && (duration < 1 || duration > 2592000)) {
      throw const WalletValidationException(
        'Duration must be between 1 second and 30 days.',
        field: 'durationSeconds',
      );
    }
    _requireUInt8(request.minConfirmations, 'minConfirmations');
    _requireUnlockedNode();
    return _binding.rlnRgbInvoice(
      request.assetId,
      amount,
      duration,
      request.minConfirmations,
      witness,
      assignmentKind: kind,
    );
  }

  @override
  RlnMap _asRlnMap(Object? value) {
    if (value is RlnMap) return value;
    if (value is Map) return Map<Object?, Object?>.from(value);
    throw const NativeProtocolException(
      'Native asset response must be a map.',
      field: 'assetResponse',
    );
  }
}
