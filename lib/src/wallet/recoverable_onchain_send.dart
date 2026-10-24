part of 'utexo_wallet.dart';

/// The on-chain operation recorded by the durable native send journal.
enum RecoverableOnchainSendKind { bitcoin, rgb }

/// Durable native operation state. Status reads never authorize a broadcast.
enum RecoverableOnchainSendPhase {
  absent,
  preparing,
  prepared,
  committing,
  accepted,
  rejected,
}

/// Immutable, wallet-bound input for the native prepare/commit protocol.
///
/// Create through the wallet's command factories before saving the application's
/// pending-send marker. Persist [requestJson] exactly, in private wallet storage.
/// It contains the destination and wallet identity; never put it in diagnostics.
/// Restoring the command does not dispatch any native operation.
class RecoverableOnchainSendCommand {
  RecoverableOnchainSendCommand._({
    required this.network,
    required this.version,
    required this.storageDirPath,
    required this.walletBinding,
    required Map<String, Object?> request,
    required bool restored,
  }) : _request = Map<String, Object?>.unmodifiable(request),
       _restored = restored;

  /// Restores a canonical SDK envelope and recomputes its command fingerprint.
  ///
  /// Altered, oversized, ambiguous, unknown-field or noncanonical input fails
  /// closed before native dispatch. This is integrity validation, not a MAC;
  /// callers must keep their journal in trusted private storage.
  /// Recovery calls require the existing real native outbox. This cannot
  /// establish continuity after selective record deletion or a mixed restore.
  factory RecoverableOnchainSendCommand.fromJson(String requestJson) {
    final envelope = _recoverableJsonObject(requestJson, 'command');
    final version = envelope['version'];
    if (version is! int || (version != 1 && version != 2)) {
      _recoverableInvalid('command.version');
    }
    _recoverableKeys(envelope, {
      'version',
      'network',
      if (version == 1) 'storageDirPath' else 'walletBinding',
      'request',
    });
    final network = _recoverableString(envelope['network'], 'command.network');
    if (normalizeNativeRlnNetwork(network) != network) {
      _recoverableInvalid('command.network');
    }
    final storageDirPath = version == 1
        ? _recoverableString(
            envelope['storageDirPath'],
            'command.storageDirPath',
          )
        : null;
    final walletBinding = version == 2
        ? _recoverableString(envelope['walletBinding'], 'command.walletBinding')
        : null;
    if (walletBinding != null && !_recoverableHash.hasMatch(walletBinding)) {
      _recoverableInvalid('command.walletBinding');
    }
    final request = envelope['request'];
    if (request is! Map<String, Object?>) {
      _recoverableInvalid('command.request');
    }
    final command = _validatedRecoverableCommand(
      network: network,
      envelopeVersion: version,
      storageDirPath: storageDirPath,
      walletBinding: walletBinding,
      request: request,
      restoring: true,
    );
    if (command.requestJson != requestJson) {
      _recoverableInvalid('command.canonicalEncoding');
    }
    return command;
  }

  /// Canonical native network, bound into the fingerprint.
  final String network;

  /// SDK envelope version. New commands use stable wallet identity in version 2.
  final int version;

  /// Legacy version-1 wallet path; null for stable-identity commands.
  /// Version 1 cannot be relocated and is never silently migrated.
  final String? storageDirPath;

  /// Version-2 domain-separated digest of network and both account xpubs.
  /// Null only for legacy version-1 commands.
  final String? walletBinding;
  final Map<String, Object?> _request;
  final bool _restored;

  /// Random 128-bit lowercase hexadecimal identity supplied by the caller.
  String get operationId => _request['operationId']! as String;

  /// SHA-256 of all normalized command inputs and wallet binding.
  String get fingerprint => _request['fingerprint']! as String;

  /// Bitcoin or RGB on-chain operation.
  RecoverableOnchainSendKind get kind =>
      RecoverableOnchainSendKind.values.byName(_request['kind']! as String);

  /// Exact private SDK envelope to persist before calling prepare.
  String get requestJson => jsonEncode(<String, Object?>{
    'version': version,
    'network': network,
    if (version == 1)
      'storageDirPath': storageDirPath
    else
      'walletBinding': walletBinding,
    'request': _request,
  });

  String get _nativeRequestJson => jsonEncode(_request);
}

/// Validated, command-bound result from native durable send recovery.
///
/// The accepted phase means the native end operation returned successfully, not that
/// the transaction has chain confirmations. Missing, malformed, contradictory
/// or mismatched native status throws instead of authorizing a new send.
class RecoverableOnchainSendStatus {
  const RecoverableOnchainSendStatus._({
    required this.operationId,
    required this.fingerprint,
    required this.kind,
    required this.phase,
    required this.txid,
    required this.batchTransferIndex,
    required this.failureCode,
    required this.endAuthorized,
  });

  /// Native operation identity, equal to the expected command.
  final String operationId;

  /// Expected command fingerprint; null only when [phase] is absent.
  final String? fingerprint;

  /// Expected operation kind; null only when [phase] is absent.
  final RecoverableOnchainSendKind? kind;

  /// Durable native journal phase.
  final RecoverableOnchainSendPhase phase;

  /// Bitcoin transaction ID, when native has established one.
  final String? txid;

  /// RGB batch transfer identity, when native has established one.
  final int? batchTransferIndex;

  /// Machine-readable terminal rejection reason, if supported by native.
  final String? failureCode;

  /// Whether native durably authorized the end/broadcast operation.
  final bool endAuthorized;
}

const _recoverableRequestKeys = <String>{
  'version',
  'operationId',
  'fingerprint',
  'kind',
  'amount',
  'feeRate',
  'address',
  'assetId',
  'recipientId',
  'transportEndpoints',
  'witnessAmountSat',
  'witnessBlinding',
  'minConfirmations',
  'donation',
  'expirationTimestamp',
};
const _recoverableMaxJsonBytes = 131072;
final _recoverableOperationId = RegExp(r'^[0-9a-f]{32}$');
final _recoverableHash = RegExp(r'^[0-9a-f]{64}$');

Never _recoverableInvalid(String field) => throw WalletValidationException(
  'Invalid recoverable on-chain command.',
  field: field,
);

String _recoverableString(Object? value, String field) {
  if (value is! String ||
      value.isEmpty ||
      value != value.trim() ||
      value.length > 16384 ||
      value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
    _recoverableInvalid(field);
  }
  return value;
}

Map<String, Object?> _recoverableJsonObject(String json, String field) {
  if (utf8.encode(json).length > _recoverableMaxJsonBytes) {
    _recoverableInvalid(field);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    _recoverableInvalid(field);
  }
  if (decoded is! Map<String, Object?>) _recoverableInvalid(field);
  // SDK/native producers emit compact JSON. Requiring canonical compact input
  // also rejects duplicate JSON object keys, which jsonDecode would overwrite.
  if (jsonEncode(decoded) != json) {
    _recoverableInvalid('$field.canonicalEncoding');
  }
  return decoded;
}

void _recoverableKeys(Map<String, Object?> map, Set<String> keys) {
  if (map.keys.any((key) => !keys.contains(key))) {
    _recoverableInvalid('unknownField');
  }
}

RecoverableOnchainSendCommand _validatedRecoverableCommand({
  required String network,
  int envelopeVersion = 2,
  String? storageDirPath,
  String? walletBinding,
  required Map<String, Object?> request,
  bool restoring = false,
}) {
  if (envelopeVersion == 1) {
    _recoverableString(storageDirPath, 'command.storageDirPath');
    if (walletBinding != null) _recoverableInvalid('command.walletBinding');
  } else if (envelopeVersion == 2) {
    if (storageDirPath != null ||
        walletBinding == null ||
        !_recoverableHash.hasMatch(walletBinding)) {
      _recoverableInvalid('command.walletBinding');
    }
  } else {
    _recoverableInvalid('command.version');
  }
  _recoverableKeys(request, _recoverableRequestKeys);
  if (request['version'] != 1 || request['version'] is! int) {
    _recoverableInvalid('version');
  }
  final operationId = _recoverableString(request['operationId'], 'operationId');
  if (!_recoverableOperationId.hasMatch(operationId)) {
    _recoverableInvalid('operationId');
  }
  final kind = request['kind'];
  if (kind != 'bitcoin' && kind != 'rgb') _recoverableInvalid('kind');
  final amount = request['amount'];
  final feeRate = request['feeRate'];
  if (amount is! int) _recoverableInvalid('amount');
  if (feeRate is! int) _recoverableInvalid('feeRate');
  WalletInputPolicy.requirePositive(amount, 'amount');
  WalletInputPolicy.requirePositive(feeRate, 'feeRate');
  if (request['donation'] != false) _recoverableInvalid('donation');
  final minConfirmations = request['minConfirmations'];
  if (minConfirmations is! int) _recoverableInvalid('minConfirmations');
  WalletInputPolicy.requireUInt8(minConfirmations, 'minConfirmations');
  final endpoints = request['transportEndpoints'];
  if (endpoints is! List ||
      endpoints.length > 16 ||
      endpoints.any((endpoint) => endpoint is! String)) {
    _recoverableInvalid('transportEndpoints');
  }
  final safeEndpoints = List<String>.unmodifiable(endpoints.cast<String>());
  for (final endpoint in safeEndpoints) {
    _recoverableString(endpoint, 'transportEndpoints');
    if (utf8.encode(endpoint).length > 8000) {
      _recoverableInvalid('transportEndpoints');
    }
  }
  for (final field in [
    'witnessAmountSat',
    'witnessBlinding',
    'expirationTimestamp',
  ]) {
    final value = request[field];
    if (value != null) {
      if (value is! int) _recoverableInvalid(field);
      WalletInputPolicy.requireNonNegative(value, field);
    }
  }
  if (request['witnessBlinding'] != null &&
      request['witnessAmountSat'] == null) {
    _recoverableInvalid('witnessBlinding');
  }
  if (request['witnessAmountSat'] == 0) _recoverableInvalid('witnessAmountSat');
  if (kind == 'bitcoin') {
    final address = _recoverableString(request['address'], 'address');
    if (utf8.encode(address).length > 1000) _recoverableInvalid('address');
    if (request['assetId'] != null ||
        request['recipientId'] != null ||
        safeEndpoints.isNotEmpty ||
        request['witnessAmountSat'] != null ||
        request['witnessBlinding'] != null ||
        request['expirationTimestamp'] != null ||
        minConfirmations != 1) {
      _recoverableInvalid('bitcoinFields');
    }
  } else {
    final assetId = _recoverableString(request['assetId'], 'assetId');
    final recipientId = _recoverableString(
      request['recipientId'],
      'recipientId',
    );
    if (utf8.encode(assetId).length > 1000) _recoverableInvalid('assetId');
    if (utf8.encode(recipientId).length > 4000) {
      _recoverableInvalid('recipientId');
    }
    if (safeEndpoints.isEmpty) _recoverableInvalid('transportEndpoints');
    final expiry = request['expirationTimestamp'];
    if (expiry is! int || expiry <= 0) {
      _recoverableInvalid('expirationTimestamp');
    }
    if (request['address'] != null) _recoverableInvalid('address');
  }
  final canonical = <String, Object?>{
    'version': 1,
    'operationId': operationId,
    'kind': kind,
    'amount': amount,
    'feeRate': feeRate,
    'address': request['address'],
    'assetId': request['assetId'],
    'recipientId': request['recipientId'],
    'transportEndpoints': safeEndpoints,
    'witnessAmountSat': request['witnessAmountSat'],
    'witnessBlinding': request['witnessBlinding'],
    'minConfirmations': minConfirmations,
    'donation': false,
    'expirationTimestamp': request['expirationTimestamp'],
  };
  final fingerprint = crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'version': envelopeVersion,
            'network': network,
            if (envelopeVersion == 1)
              'storageDirPath': storageDirPath
            else
              'walletBinding': walletBinding,
            'request': canonical,
          }),
        ),
      )
      .toString();
  if (restoring && request['fingerprint'] != fingerprint) {
    _recoverableInvalid('fingerprint');
  }
  canonical['fingerprint'] = fingerprint;
  final command = RecoverableOnchainSendCommand._(
    network: network,
    version: envelopeVersion,
    storageDirPath: storageDirPath,
    walletBinding: walletBinding,
    request: canonical,
    restored: restoring,
  );
  if (utf8.encode(command.requestJson).length > _recoverableMaxJsonBytes) {
    _recoverableInvalid('command');
  }
  return command;
}

RecoverableOnchainSendStatus _decodeRecoverableStatus(
  String json,
  RecoverableOnchainSendCommand command,
) {
  try {
    final map = _recoverableJsonObject(json, 'status');
    const fields = {
      'version',
      'operationId',
      'fingerprint',
      'kind',
      'phase',
      'txid',
      'batchTransferIndex',
      'failureCode',
      'endAuthorized',
    };
    _recoverableKeys(map, fields);
    if (map.keys.toSet().length != fields.length ||
        map['version'] != 1 ||
        map['version'] is! int ||
        map['operationId'] != command.operationId ||
        map['endAuthorized'] is! bool) {
      _recoverableInvalid('status');
    }
    final phase = RecoverableOnchainSendPhase.values
        .where((value) => value.name == map['phase'])
        .firstOrNull;
    if (phase == null) _recoverableInvalid('status.phase');
    final absent = phase == RecoverableOnchainSendPhase.absent;
    if (absent
        ? (map['fingerprint'] != null || map['kind'] != null)
        : (map['fingerprint'] != command.fingerprint ||
              map['kind'] != command.kind.name)) {
      _recoverableInvalid('status.binding');
    }
    final txid = map['txid'];
    if (txid != null && (txid is! String || !_recoverableHash.hasMatch(txid))) {
      _recoverableInvalid('status.txid');
    }
    final batch = map['batchTransferIndex'];
    if (batch != null &&
        (batch is! int ||
            batch < 0 ||
            batch > 2147483647 ||
            command.kind != RecoverableOnchainSendKind.rgb)) {
      _recoverableInvalid('status.batchTransferIndex');
    }
    if (command.kind == RecoverableOnchainSendKind.rgb &&
        ((txid == null) != (batch == null))) {
      _recoverableInvalid('status.rgbIdentity');
    }
    final failure = map['failureCode'];
    if (failure != null &&
        (failure is! String ||
            !RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,79}$').hasMatch(failure))) {
      _recoverableInvalid('status.failureCode');
    }
    final authorized = map['endAuthorized']! as bool;
    if ((phase == RecoverableOnchainSendPhase.committing ||
            phase == RecoverableOnchainSendPhase.accepted) !=
        authorized) {
      _recoverableInvalid('status.endAuthorized');
    }
    if (absent && (txid != null || batch != null || failure != null)) {
      _recoverableInvalid('status.absent');
    }
    if (phase == RecoverableOnchainSendPhase.accepted &&
        (txid == null ||
            (command.kind == RecoverableOnchainSendKind.rgb &&
                batch == null))) {
      _recoverableInvalid('status.accepted');
    }
    if ((phase == RecoverableOnchainSendPhase.rejected) &&
        (txid != null || batch != null)) {
      _recoverableInvalid('status.unpreparedIdentity');
    }
    if ((phase == RecoverableOnchainSendPhase.prepared ||
            phase == RecoverableOnchainSendPhase.committing) &&
        (txid == null ||
            (command.kind == RecoverableOnchainSendKind.rgb &&
                batch == null))) {
      _recoverableInvalid('status.preparedIdentity');
    }
    if (phase == RecoverableOnchainSendPhase.accepted && failure != null) {
      _recoverableInvalid('status.failureCode');
    }
    if (phase == RecoverableOnchainSendPhase.rejected && failure == null) {
      _recoverableInvalid('status.failureCode');
    }
    return RecoverableOnchainSendStatus._(
      operationId: command.operationId,
      fingerprint: map['fingerprint'] as String?,
      kind: absent ? null : command.kind,
      phase: phase,
      txid: txid as String?,
      batchTransferIndex: batch as int?,
      failureCode: failure as String?,
      endAuthorized: authorized,
    );
  } on WalletValidationException {
    throw const NativeProtocolException(
      'Native durable send status is invalid or does not match the command.',
      field: 'onchainSendStatus',
    );
  }
}
