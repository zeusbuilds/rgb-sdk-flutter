part of 'rln_binding.dart';

mixin _RlnBindingOnchain on _RlnBindingInternals {
  Future<String> rlnPrepareOnchainSend(String requestJson) =>
      _withNodeOperation(
        'rlnPrepareOnchainSend',
        (nodeId) => _client.prepareOnchainSend(
          nodeId: nodeId,
          requestJson: requestJson,
        ),
      );

  Future<String> rlnCommitOnchainSend(String requestJson) => _withNodeOperation(
    'rlnCommitOnchainSend',
    (nodeId) =>
        _client.commitOnchainSend(nodeId: nodeId, requestJson: requestJson),
  );

  Future<String> rlnOnchainSendStatus(String requestJson) =>
      _withNodeInspection(
        'rlnOnchainSendStatus',
        (nodeId) =>
            _client.onchainSendStatus(nodeId: nodeId, requestJson: requestJson),
      );

  Future<String> rlnCancelOnchainSend(String requestJson) => _withNodeOperation(
    'rlnCancelOnchainSend',
    (nodeId) =>
        _client.cancelOnchainSend(nodeId: nodeId, requestJson: requestJson),
  );

  Future<RlnDecodedRgbInvoice> rlnDecodeRgbInvoice(String invoice) async {
    return RlnDecodedRgbInvoice.fromMap(
      await _withNodeInspection(
        'rlnDecodeRgbInvoice',
        (nodeId) => _client.decodeRgbInvoice(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnAddress> rlnAddress() async {
    return RlnAddress.fromMap(
      await _withNodeOperation('rlnAddress', _client.address),
    );
  }

  Future<RlnAddress> rlnRotateAddress() async {
    return RlnAddress.fromMap(
      await _withNodeOperation('rlnRotateAddress', _client.rotateAddress),
    );
  }

  Future<RlnSignMessageResult> rlnSignMessage(String message) async {
    return RlnSignMessageResult.fromMap(
      await _withNodeOperation(
        'rlnSignMessage',
        (nodeId) => _client.signMessage(nodeId: nodeId, message: message),
      ),
    );
  }

  Future<RlnVerifyMessageResult> rlnVerifyMessage(
    String message,
    String signature,
  ) async {
    return RlnVerifyMessageResult.fromMap(
      await _withNodeOperation(
        'rlnVerifyMessage',
        (nodeId) => _client.verifyMessage(
          nodeId: nodeId,
          message: message,
          signature: signature,
        ),
      ),
    );
  }

  Future<RlnBtcBalance> rlnBtcBalance([bool skipSync = false]) async {
    return RlnBtcBalance.fromMap(
      await _withNodeOperation(
        'rlnBtcBalance',
        (nodeId) => _client.btcBalance(nodeId: nodeId, skipSync: skipSync),
      ),
    );
  }

  Future<RlnMap> rlnSendBtc(
    int amount,
    String address,
    double feeRate,
    bool skipSync,
  ) {
    return _withNodeOperation(
      'rlnSendBtc',
      (nodeId) => _client.sendBtc(
        nodeId: nodeId,
        amount: amount,
        address: address,
        feeRate: feeRate,
        skipSync: skipSync,
      ),
    );
  }

  Future<Object?> rlnIssueAssetNia(
    String ticker,
    String name,
    int precision,
    List<int> amounts,
  ) {
    return _withNodeOperation(
      'rlnIssueAssetNia',
      (nodeId) => _client.issueAssetNia(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        precision: precision,
        amounts: amounts,
      ),
    );
  }

  Future<Object?> rlnIssueAssetCfa(
    String name,
    String? details,
    int precision,
    List<int> amounts,
    String? fileDigest,
  ) {
    return _withNodeOperation(
      'rlnIssueAssetCfa',
      (nodeId) => _client.issueAssetCfa(
        nodeId: nodeId,
        name: name,
        details: details,
        precision: precision,
        amounts: amounts,
        fileDigest: fileDigest,
      ),
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
    return _withNodeOperation(
      'rlnIssueAssetIfa',
      (nodeId) => _client.issueAssetIfa(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        precision: precision,
        amounts: amounts,
        inflationAmounts: inflationAmounts,
        rejectListUrl: rejectListUrl,
      ),
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
    return _withNodeOperation(
      'rlnIssueAssetUda',
      (nodeId) => _client.issueAssetUda(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        details: details,
        precision: precision,
        mediaFileDigest: mediaFileDigest,
        attachmentsFileDigests: attachmentsFileDigests,
      ),
    );
  }

  Future<RlnAssets> rlnListAssets(List<String> filterAssetSchemas) async {
    return RlnAssets.fromMap(
      await _withNodeOperation(
        'rlnListAssets',
        (nodeId) => _client.listAssets(
          nodeId: nodeId,
          filterAssetSchemas: filterAssetSchemas,
        ),
      ),
    );
  }

  Future<RlnAssetBalance> rlnAssetBalance(String assetId) async {
    return RlnAssetBalance.fromMap(
      await _withNodeOperation(
        'rlnAssetBalance',
        (nodeId) => _client.assetBalance(nodeId: nodeId, assetId: assetId),
      ),
    );
  }

  Future<RlnInvoice> rlnRgbInvoice(
    String? assetId,
    int? assignmentAmount,
    int? durationSeconds,
    int minConfirmations,
    bool witness, {
    RlnAssignmentKind? assignmentKind,
  }) async {
    final resolvedAssignmentKind =
        assignmentKind ??
        (assignmentAmount == null ? null : RlnAssignmentKind.fungible);
    return RlnInvoice.fromMap(
      await _withNodeOperation(
        'rlnRgbInvoice',
        (nodeId) => _client.rgbInvoice(
          nodeId: nodeId,
          assetId: assetId,
          assignmentAmount: assignmentAmount,
          durationSeconds: durationSeconds,
          minConfirmations: minConfirmations,
          witness: witness,
          assignmentKind: resolvedAssignmentKind?.wireValue,
        ),
      ),
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
  ]) async {
    return RlnSendResult.fromMap(
      await _withNodeOperation(
        'rlnSendRgb',
        (nodeId) => _client.sendRgb(
          nodeId: nodeId,
          donation: donation,
          feeRate: feeRate,
          minConfirmations: minConfirmations,
          skipSync: skipSync,
          assetId: assetId,
          recipientId: recipientId,
          amount: amount,
          transportEndpoints: transportEndpoints,
          witnessAmountSat: witnessData?.amountSat,
          witnessBlinding: witnessData?.blinding,
        ),
      ),
    );
  }

  Future<RlnInflateResult> rlnInflate(
    String assetId,
    List<int> inflationAmounts,
    double feeRate,
    int minConfirmations,
  ) async {
    return RlnInflateResult.fromMap(
      await _withNodeOperation(
        'rlnInflate',
        (nodeId) => _client.inflate(
          nodeId: nodeId,
          assetId: assetId,
          inflationAmounts: inflationAmounts,
          feeRate: feeRate,
          minConfirmations: minConfirmations,
        ),
      ),
    );
  }

  Future<List<RlnTransaction>> rlnListTransactions(bool skipSync) async {
    final transactions = await _withNodeOperation(
      'rlnListTransactions',
      (nodeId) => _client.listTransactions(nodeId: nodeId, skipSync: skipSync),
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<RlnTransaction>> rlnListTransactionsByTxid(
    String txid,
    bool skipSync,
  ) async {
    final transactions = await _withNodeOperation(
      'rlnListTransactionsByTxid',
      (nodeId) => _client.listTransactionsByTxid(
        nodeId: nodeId,
        txid: txid,
        skipSync: skipSync,
      ),
    );
    return transactions.map(RlnTransaction.fromMap).toList(growable: false);
  }

  Future<List<RlnTransfer>> rlnListTransfers(String assetId) async {
    final transfers = await _withNodeOperation(
      'rlnListTransfers',
      (nodeId) => _client.listTransfers(nodeId: nodeId, assetId: assetId),
    );
    return transfers.map(RlnTransfer.fromMap).toList(growable: false);
  }

  Future<List<RlnTransfer>> rlnListTransfersByTxid(String txid) async {
    final transfers = await _withNodeOperation(
      'rlnListTransfersByTxid',
      (nodeId) => _client.listTransfersByTxid(nodeId: nodeId, txid: txid),
    );
    return transfers.map(RlnTransfer.fromMap).toList(growable: false);
  }

  Future<List<RlnUnspent>> rlnListUnspents(bool skipSync) async {
    final unspents = await _withNodeOperation(
      'rlnListUnspents',
      (nodeId) => _client.listUnspents(nodeId: nodeId, skipSync: skipSync),
    );
    return unspents.map(RlnUnspent.fromMap).toList(growable: false);
  }

  Future<RlnRefreshTransfersResult> rlnRefreshTransfers(bool skipSync) async {
    return RlnRefreshTransfersResult.fromMap(
      await _withNodeOperation(
        'rlnRefreshTransfers',
        (nodeId) =>
            _client.refreshTransfers(nodeId: nodeId, skipSync: skipSync),
      ),
    );
  }

  Future<RlnMap> rlnFailTransfers(
    int? batchTransferIdx,
    bool noAssetOnly,
    bool skipSync,
  ) {
    return _withNodeOperation(
      'rlnFailTransfers',
      (nodeId) => _client.failTransfers(
        nodeId: nodeId,
        batchTransferIdx: batchTransferIdx,
        noAssetOnly: noAssetOnly,
        skipSync: skipSync,
      ),
    );
  }

  Future<RlnFeeRate> rlnEstimateFee(int blocks) async {
    return RlnFeeRate.fromMap(
      await _withNodeOperation(
        'rlnEstimateFee',
        (nodeId) => _client.estimateFee(nodeId: nodeId, blocks: blocks),
      ),
    );
  }

  Future<RlnIndexerCheck> rlnCheckIndexerUrl(String indexerUrl) async {
    return RlnIndexerCheck.fromMap(
      await _withNodeOperation(
        'rlnCheckIndexerUrl',
        (nodeId) =>
            _client.checkIndexerUrl(nodeId: nodeId, indexerUrl: indexerUrl),
      ),
    );
  }

  Future<void> rlnCheckProxyEndpoint(String proxyEndpoint) {
    return _withNodeOperation(
      'rlnCheckProxyEndpoint',
      (nodeId) => _client.checkProxyEndpoint(
        nodeId: nodeId,
        proxyEndpoint: proxyEndpoint,
      ),
    );
  }

  Future<void> rlnSync() {
    return _withNodeOperation('rlnSync', _client.sync);
  }

  Future<void> rlnCreateUtxos(
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) {
    return _withNodeOperation(
      'rlnCreateUtxos',
      (nodeId) => _client.createUtxos(
        nodeId: nodeId,
        upTo: upTo,
        num: num,
        size: size,
        feeRate: feeRate,
        skipSync: skipSync,
      ),
    );
  }

  /// Observes newly recorded colorable outpoints within the same node queue.
  /// RLN 0.17 acknowledges creation without returning a count.
  Future<int> rlnCreateUtxosCounted(
    bool upTo,
    int? num,
    int? size,
    double feeRate,
    bool skipSync,
  ) => _withNodeOperation('rlnCreateUtxos', (nodeId) async {
    final before = {
      for (final row in await _client.listUnspents(
        nodeId: nodeId,
        skipSync: skipSync,
      ))
        RlnUnspent.fromMap(row).utxo.outpoint,
    };
    // The baseline read can outlive the facade's deadline. Do not start a
    // financial mutation after the node has been quarantined or closed.
    _assertRegularOpsAllowed();
    await _client.createUtxos(
      nodeId: nodeId,
      upTo: upTo,
      num: num,
      size: size,
      feeRate: feeRate,
      skipSync: true,
    );
    try {
      final after = await _client.listUnspents(nodeId: nodeId, skipSync: true);
      final created = {
        for (final row in after)
          if (RlnUnspent.fromMap(row).utxo case final utxo
              when utxo.exists &&
                  utxo.colorable &&
                  !before.contains(utxo.outpoint))
            utxo.outpoint,
      };
      final outpointPattern = RegExp(r'^[a-f0-9]{64}:[0-9]+$');
      if (created.isEmpty ||
          created.length > (num ?? 255) ||
          created.any((outpoint) => !outpointPattern.hasMatch(outpoint)) ||
          created.map((outpoint) => outpoint.substring(0, 64)).toSet().length !=
              1) {
        throw const NativeProtocolException(
          'Native output inventory did not establish the created count.',
          field: 'rlnCreateUtxos.count',
        );
      }
      return created.length;
    } catch (error, stack) {
      // The create call already succeeded. A failed observation must never
      // imply that it is safe to repeat creation.
      Error.throwWithStackTrace(
        WalletError(
          'UTXO creation completed but its output count is unavailable.',
          code: 'UTXO_CREATION_COUNT_UNAVAILABLE',
          cause: error,
        ),
        stack,
      );
    }
  });

  Future<void> rlnBackup(String backupPath, String password) {
    return _withNodeOperation(
      'rlnBackup',
      (nodeId) => _client.backup(
        nodeId: nodeId,
        backupPath: backupPath,
        password: password,
      ),
    );
  }

  Future<void> rlnVssClearFence(String password) {
    return _withNodeOperation(
      'rlnVssClearFence',
      (nodeId) => _client.vssClearFence(nodeId: nodeId, password: password),
    );
  }

  Future<int> rlnVssBackup() {
    return _withNodeOperation('rlnVssBackup', _client.vssBackup);
  }
}
