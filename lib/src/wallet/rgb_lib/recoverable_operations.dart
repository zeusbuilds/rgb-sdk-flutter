part of 'rgb_lib_wallet.dart';

/// Canonical contract registration and crash-safe native payment operations.
extension RgbLibDurableOperations on RgbLibWallet {
  /// Imports only an approved public contract definition. No funds are credited.
  Future<ImportedRgbContract> importContract({
    required String contractBase64,
    required String expectedAssetId,
  }) {
    validateRgbContractImport(contractBase64, expectedAssetId);
    return _call(
      'importContract',
      (value) {
        final Object? decoded = _recoveryJson(value);
        if (decoded is! Map<Object?, Object?>) {
          invalidRgbLibWire('importContract');
        }
        return ImportedRgbContract.fromMap(
          decoded,
          expectedAssetId: expectedAssetId,
        );
      },
      arguments: {
        'contractBase64': contractBase64,
        'expectedAssetId': expectedAssetId,
      },
      registration: true,
    );
  }

  /// Reads native-validated mint lock requirements, or null when none exist.
  /// Does not create or authorize an EVM lock or assert mint completion.
  Future<RgbLibReceivedMint?> getReceivedMint(String recipientId) {
    _required(recipientId, 'recipientId');
    return _call(
      'getReceivedMint',
      (value) =>
          value == null ? null : RgbLibWire(value, 'receivedMint').receivedMint,
      arguments: {'recipientId': recipientId},
    );
  }

  /// Reads the actual native account derivation; it never derives substitute keys.
  Future<RgbLibPublicKeys> getPublicKeys() => _call('getPublicKeys', (value) {
    final row = RgbLibWire(value, 'publicKeys');
    final keys = RgbLibPublicKeys(
      accountXpubVanilla: row.requiredText('accountXpubVanilla'),
      accountXpubColored: row.requiredText('accountXpubColored'),
      masterFingerprint: row.requiredText('masterFingerprint'),
    );
    try {
      keys.validate(network);
    } on RgbLibWalletException {
      invalidRgbLibWire('publicKeys');
    }
    final bound = crypto.sha256
        .convert(
          utf8.encode(
            '$network:${params.witnessVersion.wireValue}:${keys.accountXpubVanilla}:${keys.accountXpubColored}',
          ),
        )
        .toString();
    if (keys.masterFingerprint.toLowerCase() !=
            _requireIdentity().masterFingerprint ||
        bound != _requireIdentity().id) {
      invalidRgbLibWire('publicKeys.masterFingerprint');
    }
    return keys;
  });

  /// Audits authoritative native commands even when the application's marker is lost.
  /// Only read-only inspection is performed. No returned entry grants permission
  /// to commit; preserve the original command and reconcile or cancel explicitly.
  Future<List<RgbLibPendingOnchainOperation>> listPendingOnchainSends() =>
      _call('onchainRecoveryState', (value) {
        final row = RgbLibWire(_recoveryJson(value), 'recoveryState');
        final identity = _recoveryIdentity();
        if (row.integer('version') != 1 ||
            row.text('walletBinding') != identity.id ||
            row.text('cohort') != identity.recoveryCohort) {
          invalidRgbLibWire('recoveryState.identity');
        }
        final restored = row.map['restoredSnapshot'];
        if (restored is! bool) {
          invalidRgbLibWire('recoveryState.restoredSnapshot');
        }
        if (restored) {
          throw const RgbLibWalletException(
            'A restored snapshot cannot establish payment freshness.',
            code: 'RECOVERY_RESTORE_UNCERTAIN',
          );
        }
        final pending = row.rows('pending');
        if (pending.length > 256) invalidRgbLibWire('recoveryState.pending');
        final ids = <String>{};
        final result = <RgbLibPendingOnchainOperation>[];
        for (final entry in pending) {
          final RecoverableOnchainSendCommand command;
          try {
            command = RecoverableOnchainSendCommand.fromJson(
              entry.text('commandJson'),
            );
            RgbLibRecoverableCodec.requireWallet(
              command,
              network: network,
              walletBinding: identity.id,
              recoveryCohort: identity.recoveryCohort!,
            );
          } on WalletValidationException {
            invalidRgbLibWire('recoveryState.commandJson');
          }
          final fields = Map<String, Object?>.from(entry.map)
            ..remove('commandJson');
          final status = RgbLibRecoverableCodec.decodeStatus(
            jsonEncode(fields),
            command,
          );
          if (!ids.add(command.operationId) ||
              !const {
                RecoverableOnchainSendPhase.preparing,
                RecoverableOnchainSendPhase.prepared,
                RecoverableOnchainSendPhase.committing,
              }.contains(status.phase)) {
            invalidRgbLibWire('recoveryState.pending');
          }
          result.add(
            RgbLibPendingOnchainOperation._(command: command, status: status),
          );
        }
        return List.unmodifiable(result);
      });

  /// Reads immutable accepted submission receipts in one native revision.
  /// Historical submission does not establish current confirmation or permission
  /// to send. Compare [RgbLibOnchainSendReceiptPage.revision] across all pages.
  Future<RgbLibOnchainSendReceiptPage> listOnchainSendReceipts({
    int offset = 0,
    int limit = 100,
  }) => _call(
    'listOnchainSendReceipts',
    (value) {
      final row = RgbLibWire(_recoveryJson(value), 'sendReceipts');
      final identity = _recoveryIdentity();
      if (row.integer('version') != 1 ||
          row.text('walletBinding') != identity.id ||
          row.text('cohort') != identity.recoveryCohort ||
          row.map['restoredSnapshot'] is! bool) {
        invalidRgbLibWire('sendReceipts.identity');
      }
      final revisionText = row.text('revision');
      if (!RegExp(r'^(0|[1-9][0-9]{0,19})$').hasMatch(revisionText) ||
          BigInt.parse(revisionText) > BigInt.parse('18446744073709551615')) {
        invalidRgbLibWire('sendReceipts.revision');
      }
      final total = row.integer('total', max: 10000);
      final entries = row.rows('receipts');
      final expected = offset >= total
          ? 0
          : (total - offset < limit ? total - offset : limit);
      if (entries.length != expected) {
        invalidRgbLibWire('sendReceipts.pagination');
      }
      final seen = <String>{};
      final receipts = <RgbLibOnchainSendReceipt>[];
      for (final entry in entries) {
        final operationId = entry.requiredText('operationId');
        final fingerprint = entry.requiredText('fingerprint');
        final kindText = entry.text('kind');
        if (entry.integer('version') != 1 ||
            !RegExp(r'^[0-9a-f]{32}$').hasMatch(operationId) ||
            !seen.add(operationId) ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
            !const {'bitcoin', 'rgb'}.contains(kindText) ||
            entry.text('phase') != 'accepted' ||
            entry.map['endAuthorized'] != true ||
            entry.map['failureCode'] != null) {
          invalidRgbLibWire('sendReceipts.receipt');
        }
        final kind = RecoverableOnchainSendKind.values.byName(kindText);
        BigInt decimal(String key) {
          final text = entry.text(key);
          if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(text) ||
              BigInt.parse(text) > BigInt.parse('18446744073709551615')) {
            invalidRgbLibWire('sendReceipts.$key');
          }
          return BigInt.parse(text);
        }

        final amount = decimal('amount'), fee = decimal('feeRate');
        final assetId = entry.optionalText('assetId');
        final address = entry.optionalText('address');
        final recipient = entry.optionalText('recipientId');
        final batch = entry.map['batchTransferIndex'] == null
            ? null
            : entry.integer('batchTransferIndex', max: 0x7fffffff);
        if (kind == RecoverableOnchainSendKind.bitcoin
            ? (assetId != null ||
                  recipient != null ||
                  address == null ||
                  address.isEmpty ||
                  batch != null ||
                  amount > BigInt.from(2100000000000000))
            : (assetId == null ||
                  recipient == null ||
                  recipient.isEmpty ||
                  address != null ||
                  batch == null ||
                  batch <= 0)) {
          invalidRgbLibWire('sendReceipts.summary');
        }
        if (assetId != null) {
          try {
            validateBurnAssetId(assetId);
          } on WalletValidationException {
            invalidRgbLibWire('sendReceipts.assetId');
          }
        }
        receipts.add(
          RgbLibOnchainSendReceipt._(
            operationId: operationId,
            fingerprint: fingerprint,
            kind: kind,
            txid: entry.txid('txid'),
            batchTransferIndex: batch,
            amount: amount,
            feeRate: fee,
            assetId: assetId,
            address: address,
            recipientId: recipient,
          ),
        );
      }
      return RgbLibOnchainSendReceiptPage._(
        revision: BigInt.parse(revisionText),
        total: total,
        offset: offset,
        walletBinding: identity.id,
        recoveryCohort: identity.recoveryCohort!,
        restoredSnapshot: row.map['restoredSnapshot']! as bool,
        receipts: List.unmodifiable(receipts),
      );
    },
    arguments: {
      'offset': _range(offset, 'offset', 0, 0xffffffff),
      'limit': _range(limit, 'limit', 1, 500),
    },
  );

  /// Checks the complete native outbox; malformed or missing state never means false.
  Future<bool> hasPendingOnchainSends() async =>
      (await listPendingOnchainSends()).isNotEmpty;

  RgbLibWalletIdentity _recoveryIdentity({bool signing = false}) {
    final identity = _requireIdentity();
    if (_runtime?.durableOnchainRecovery != true ||
        (signing && watchOnly) ||
        !burnHex32.hasMatch(identity.id) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(identity.recoveryCohort ?? '')) {
      throw const RgbLibWalletException(
        'The native durable recovery protocol is unavailable.',
        code: 'UNSUPPORTED_CAPABILITY',
      );
    }
    return identity;
  }

  /// Creates exact private inputs without preparing or broadcasting a payment.
  Future<RecoverableOnchainSendCommand> createRecoverableBtcSendCommand({
    required String operationId,
    required int amount,
    required String address,
    double feeRate = 1,
  }) => _accept(() async {
    final identity = _recoveryIdentity(signing: true);
    return RgbLibRecoverableCodec.create(
      network: network,
      walletBinding: identity.id,
      recoveryCohort: identity.recoveryCohort!,
      request: {
        'version': 2,
        'operationId': operationId,
        'kind': 'bitcoin',
        'amount': _range(amount, 'amount', 1, 2100000000000000).toString(),
        'feeRate': _recoverableFee(feeRate),
        'address': _required(address, 'address'),
        'transportEndpoints': <String>[],
        'minConfirmations': 1,
        'donation': false,
      },
    );
  });

  /// Binds the decoded invoice, amount and configured sender proxy to one command.
  /// Exact overrides permit full UInt64 RGB values without narrowing to Dart int.
  /// Set [requireFreshInvoice] to false only to reconstruct saved read-only
  /// recovery inputs; native preparation independently checks expiration.
  Future<RecoverableOnchainSendCommand> createRecoverableRgbSendCommand({
    required String operationId,
    required RgbSendRequest request,
    BigInt? exactAmount,
    BigInt? exactWitnessBlinding,
    bool requireFreshInvoice = true,
  }) => _accept(() async {
    final identity = _recoveryIdentity(signing: true);
    if (request.donation || request.skipSync) {
      throw const WalletValidationException(
        'Unsupported durable send mode.',
        field: 'donation',
      );
    }
    if (exactAmount != null &&
        request.amount != null &&
        exactAmount != BigInt.from(request.amount!)) {
      throw const WalletValidationException(
        'Conflicting asset amount.',
        field: 'amount',
      );
    }
    if (exactWitnessBlinding != null &&
        request.witnessBlinding != null &&
        exactWitnessBlinding != BigInt.from(request.witnessBlinding!)) {
      throw const WalletValidationException(
        'Conflicting witness blinding.',
        field: 'witnessBlinding',
      );
    }
    final invoice = RgbLibWire(
      await _invoke('decodeInvoice', {
        'handle': _handle!,
        'invoice': _required(request.invoice, 'invoice'),
      }),
      'invoice',
    ).invoice(request.invoice);
    if (invoice.network != rgbLibNativeNetwork(network) ||
        (invoice.assetId != null &&
            request.assetId != null &&
            invoice.assetId != request.assetId)) {
      throw const WalletValidationException(
        'Invoice does not match this payment.',
        field: 'invoice',
      );
    }
    final assetId = _optionalAssetId(request.assetId ?? invoice.assetId);
    final supplied =
        exactAmount ??
        (request.amount == null ? null : BigInt.from(request.amount!));
    final assignment = invoice.assignment;
    final embedded = assignment.type == 'Fungible' ? assignment.amount : null;
    if (!const {'Fungible', 'Any'}.contains(assignment.type) ||
        (embedded != null && supplied != null && embedded != supplied)) {
      throw const WalletValidationException(
        'Invoice amount does not match this payment.',
        field: 'amount',
      );
    }
    final units = supplied ?? embedded;
    if (assetId == null || units == null) {
      throw const WalletValidationException(
        'Asset and amount are required.',
        field: 'amount',
      );
    }
    if (invoice.recipientType == 'Witness' &&
            request.witnessAmountSat == null ||
        invoice.recipientType == 'Blind' &&
            (request.witnessAmountSat != null ||
                request.witnessBlinding != null ||
                exactWitnessBlinding != null)) {
      throw const WalletValidationException(
        'The Bitcoin output does not match the recipient kind.',
        field: 'witnessAmountSat',
      );
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final expiry = invoice.expirationTimestamp ?? now + 86400;
    if (requireFreshInvoice && expiry <= now + 900) {
      throw const WalletValidationException(
        'Invoice expires too soon.',
        field: 'invoice',
      );
    }
    await _ensureOnline();
    String? registeredAsset;
    if (network == 'utexo') {
      // The closed deployment gate must be deliberately reviewed before this
      // branch can execute. Neither invoice text nor an alias proves a chain.
      RgbLibWire(
        await _invoke('getAssetMetadata', {
          'handle': _handle!,
          'assetId': assetId,
        }),
        'assetMetadata',
      ).metadata;
      registeredAsset = assetId;
    }
    if (!rgbLibInvoiceMatchesProfile(
      logicalNetwork: network,
      invoiceNetwork: invoice.network,
      verifiedIndexerKind: _online!.nativeArguments['indexerKind'] as String?,
      expectedAssetId: assetId,
      registeredAssetId: registeredAsset,
      invoiceAssetId: invoice.assetId,
    )) {
      throw const WalletValidationException(
        'Invoice does not match the verified wallet profile.',
        field: 'invoice',
      );
    }
    return RgbLibRecoverableCodec.create(
      network: network,
      walletBinding: identity.id,
      recoveryCohort: identity.recoveryCohort!,
      request: {
        'version': 2,
        'operationId': operationId,
        'kind': 'rgb',
        'amount': rgbLibAmount(units, 'amount', positive: true),
        'feeRate': _recoverableFee(request.feeRate),
        'assetId': assetId,
        'recipientId': invoice.recipientId,
        'transportEndpoints': invoice.transportEndpoints,
        'senderTransportEndpoint': _online!.proxyEndpoint,
        'witnessAmountSat': request.witnessAmountSat?.toString(),
        'witnessBlinding':
            (exactWitnessBlinding ??
                    (request.witnessBlinding == null
                        ? null
                        : BigInt.from(request.witnessBlinding!)))
                ?.toString(),
        'minConfirmations': request.minConfirmations,
        'donation': false,
        'expirationTimestamp': expiry.toString(),
        'invoicePublicKey': invoice.publicKey?.toLowerCase(),
        'invoiceEncryption': invoice.encryption,
      },
    );
  });

  /// Persists and signs a fixed plan without granting broadcast authority.
  Future<RecoverableOnchainSendStatus> prepareOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _durableCall('prepareOnchainSend', command, online: true);

  /// Authorizes only the existing prepared plan after the app saved commit intent.
  Future<RecoverableOnchainSendStatus> commitOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _durableCall('commitOnchainSend', command, online: true);

  /// Reconciles exact native evidence; this never sends or retries a payment.
  Future<RecoverableOnchainSendStatus> onchainSendStatus(
    RecoverableOnchainSendCommand command,
  ) => _durableCall('onchainSendStatus', command);

  /// Cancels only preparation that never received durable commit authorization.
  Future<RecoverableOnchainSendStatus> cancelOnchainSend(
    RecoverableOnchainSendCommand command,
  ) => _durableCall('cancelOnchainSend', command);

  Future<RecoverableOnchainSendStatus> _durableCall(
    String operation,
    RecoverableOnchainSendCommand command, {
    bool online = false,
  }) => _accept(() async {
    final identity = _recoveryIdentity(signing: online);
    RgbLibRecoverableCodec.requireWallet(
      command,
      network: network,
      walletBinding: identity.id,
      recoveryCohort: identity.recoveryCohort!,
    );
    if (online) await _ensureOnline();
    final result = await _invoke(operation, {
      'handle': _handle!,
      'requestJson': command.requestJson,
    });
    if (result is! String) invalidRgbLibWire('durableStatus');
    return RgbLibRecoverableCodec.decodeStatus(result, command);
  });
}

String _recoverableFee(double value) {
  if (!value.isFinite ||
      value <= 0 ||
      value > _maxSafeInteger ||
      value != value.truncateToDouble()) {
    throw const WalletValidationException(
      'Expected a positive integer fee rate.',
      field: 'feeRate',
    );
  }
  return value.toInt().toString();
}

Object? _recoveryJson(Object? value) {
  if (value is! String) return value;
  if (utf8.encode(value).length > 32 * 1024 * 1024) {
    invalidRgbLibWire('recoveryResponse');
  }
  try {
    return jsonDecode(value);
  } on FormatException {
    invalidRgbLibWire('recoveryResponse');
  }
}

/// A native-owned pending command recovered without authorizing a payment.
///
/// The private command can rebuild an application recovery fence after its
/// marker is lost. It must never be logged or silently committed.
final class RgbLibPendingOnchainOperation {
  const RgbLibPendingOnchainOperation._({
    required this.command,
    required this.status,
  });

  final RecoverableOnchainSendCommand command;
  final RecoverableOnchainSendStatus status;

  String get commandJson => command.requestJson;
  String get operationId => command.operationId;
  RecoverableOnchainSendKind get kind => command.kind;
  RecoverableOnchainSendPhase get phase => status.phase;
  String? get txid => status.txid;
  int? get batchTransferIndex => status.batchTransferIndex;
  bool get endAuthorized => status.endAuthorized;
}

/// One native revision of accepted payment receipts; never a spending authority.
final class RgbLibOnchainSendReceiptPage {
  const RgbLibOnchainSendReceiptPage._({
    required this.revision,
    required this.total,
    required this.offset,
    required this.walletBinding,
    required this.recoveryCohort,
    required this.restoredSnapshot,
    required this.receipts,
  });
  final BigInt revision;
  final int total;
  final int offset;
  final String walletBinding;
  final String recoveryCohort;
  final bool restoredSnapshot;
  final List<RgbLibOnchainSendReceipt> receipts;
}

/// Exact approved gross amount from a native accepted submission certificate.
/// Chain history independently determines whether the transaction is confirmed.
final class RgbLibOnchainSendReceipt {
  const RgbLibOnchainSendReceipt._({
    required this.operationId,
    required this.fingerprint,
    required this.kind,
    required this.txid,
    required this.batchTransferIndex,
    required this.amount,
    required this.feeRate,
    required this.assetId,
    required this.address,
    required this.recipientId,
  });
  final String operationId;
  final String fingerprint;
  final RecoverableOnchainSendKind kind;
  final String txid;
  final int? batchTransferIndex;
  final BigInt amount;
  final BigInt feeRate;
  final String? assetId;
  final String? address;
  final String? recipientId;
  RecoverableOnchainSendPhase get phase => RecoverableOnchainSendPhase.accepted;
  bool get endAuthorized => true;
  String? get failureCode => null;
}
