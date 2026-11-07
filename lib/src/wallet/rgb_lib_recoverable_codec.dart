part of 'utexo_wallet.dart';

/// Internal codec shared by the two native facade libraries.
///
/// This class is intentionally absent from the package's stable export list.
/// Native remains authoritative for reservations, storage continuity and sends.
abstract final class RgbLibRecoverableCodec {
  static const sourceRevision = '9ec49c08be2e68f08521281e3efbd760ec989cb9';
  static const overlay = 'flutter-bfa7-durable-v1';

  static RecoverableOnchainSendCommand create({
    required String network,
    required String walletBinding,
    required String recoveryCohort,
    required Map<String, Object?> request,
  }) => _validate(
    network: network,
    walletBinding: walletBinding,
    recoveryCohort: recoveryCohort,
    request: request,
    restoring: false,
  );

  static RecoverableOnchainSendCommand restore(Map<String, Object?> envelope) {
    const fields = {
      'version',
      'backend',
      'network',
      'walletBinding',
      'recoveryCohort',
      'nativeSourceRevision',
      'nativeOverlay',
      'request',
    };
    _recoverableKeys(envelope, fields);
    if (envelope.length != fields.length ||
        envelope['version'] != 3 ||
        envelope['backend'] != 'RGB_L1' ||
        envelope['nativeSourceRevision'] != sourceRevision ||
        envelope['nativeOverlay'] != overlay) {
      _recoverableInvalid('command.backend');
    }
    final request = envelope['request'];
    if (request is! Map<String, Object?>) {
      _recoverableInvalid('command.request');
    }
    return _validate(
      network: _recoverableString(envelope['network'], 'command.network'),
      walletBinding: _recoverableString(
        envelope['walletBinding'],
        'command.walletBinding',
      ),
      recoveryCohort: _recoverableString(
        envelope['recoveryCohort'],
        'command.recoveryCohort',
      ),
      request: request,
      restoring: true,
    );
  }

  static RecoverableOnchainSendStatus decodeStatus(
    String value,
    RecoverableOnchainSendCommand command,
  ) => _decodeRecoverableStatus(value, command);

  static void requireWallet(
    RecoverableOnchainSendCommand command, {
    required String network,
    required String walletBinding,
    required String recoveryCohort,
  }) {
    if (command.version != 3 ||
        command.backend != 'RGB_L1' ||
        command.network != network ||
        command.walletBinding != walletBinding ||
        command.recoveryCohort != recoveryCohort ||
        command.nativeSourceRevision != sourceRevision ||
        command.nativeOverlay != overlay) {
      _recoverableInvalid('command.wallet');
    }
  }

  static RecoverableOnchainSendCommand _validate({
    required String network,
    required String walletBinding,
    required String recoveryCohort,
    required Map<String, Object?> request,
    required bool restoring,
  }) {
    if (!const {
          'mainnet',
          'testnet',
          'testnet4',
          'signet',
          'regtest',
          'utexo',
        }.contains(network) ||
        !_recoverableHash.hasMatch(walletBinding) ||
        !_recoverableOperationId.hasMatch(recoveryCohort)) {
      _recoverableInvalid('command.wallet');
    }
    const fields = {
      'version',
      'operationId',
      'kind',
      'amount',
      'feeRate',
      'address',
      'assetId',
      'recipientId',
      'transportEndpoints',
      'senderTransportEndpoint',
      'witnessAmountSat',
      'witnessBlinding',
      'minConfirmations',
      'donation',
      'expirationTimestamp',
      'invoicePublicKey',
      'invoiceEncryption',
      'fingerprint',
    };
    _recoverableKeys(request, fields);
    if (request['version'] != 2 ||
        request['version'] is! int ||
        !_recoverableOperationId.hasMatch(
          _recoverableString(request['operationId'], 'operationId'),
        )) {
      _recoverableInvalid('operationId');
    }
    String decimal(String field, {bool positive = false}) {
      final value = request[field];
      if (value is! String ||
          !RegExp(r'^(0|[1-9][0-9]{0,19})$').hasMatch(value)) {
        _recoverableInvalid(field);
      }
      final parsed = BigInt.parse(value);
      if (parsed > BigInt.parse('18446744073709551615') ||
          (positive && parsed == BigInt.zero)) {
        _recoverableInvalid(field);
      }
      return value;
    }

    final amount = decimal('amount', positive: true);
    final fee = decimal('feeRate', positive: true);
    if (BigInt.parse(fee) > BigInt.from(9007199254740991)) {
      _recoverableInvalid('feeRate');
    }
    for (final field in [
      'witnessAmountSat',
      'witnessBlinding',
      'expirationTimestamp',
    ]) {
      if (request[field] != null) {
        decimal(field, positive: field != 'witnessBlinding');
      }
    }
    if (request['witnessBlinding'] != null &&
        request['witnessAmountSat'] == null) {
      _recoverableInvalid('witnessBlinding');
    }
    if (request['witnessAmountSat'] case final String value) {
      if (BigInt.parse(value) > BigInt.from(2100000000000000)) {
        _recoverableInvalid('witnessAmountSat');
      }
    }
    final confirmations = request['minConfirmations'];
    if (confirmations is! int ||
        confirmations < 1 ||
        confirmations > 255 ||
        request['donation'] != false) {
      _recoverableInvalid('minConfirmations');
    }
    final rawEndpoints = request['transportEndpoints'];
    if (rawEndpoints is! List ||
        rawEndpoints.length > 16 ||
        rawEndpoints.any((e) => e is! String)) {
      _recoverableInvalid('transportEndpoints');
    }
    final endpoints = List<String>.unmodifiable(rawEndpoints.cast<String>());
    for (final endpoint in endpoints) {
      _recoverableString(endpoint, 'transportEndpoints');
      if (utf8.encode(endpoint).length > 8000) {
        _recoverableInvalid('transportEndpoints');
      }
    }
    final kind = request['kind'];
    if (kind == 'bitcoin') {
      _recoverableString(request['address'], 'address');
      if (BigInt.parse(amount) > BigInt.from(2100000000000000) ||
          confirmations != 1 ||
          endpoints.isNotEmpty ||
          [
            'assetId',
            'recipientId',
            'senderTransportEndpoint',
            'witnessAmountSat',
            'witnessBlinding',
            'expirationTimestamp',
            'invoicePublicKey',
            'invoiceEncryption',
          ].any((field) => request[field] != null)) {
        _recoverableInvalid('bitcoinFields');
      }
    } else if (kind == 'rgb') {
      validateBurnAssetId(_recoverableString(request['assetId'], 'assetId'));
      _recoverableString(request['recipientId'], 'recipientId');
      _recoverableString(
        request['senderTransportEndpoint'],
        'senderTransportEndpoint',
      );
      if (request['address'] != null ||
          endpoints.isEmpty ||
          request['expirationTimestamp'] == null ||
          !const {
            'Required',
            'Optional',
            'Unsupported',
          }.contains(request['invoiceEncryption'])) {
        _recoverableInvalid('rgbFields');
      }
      final publicKey = request['invoicePublicKey'];
      if (publicKey != null &&
          (publicKey is! String ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(publicKey))) {
        _recoverableInvalid('invoicePublicKey');
      }
      if (publicKey == null) {
        _recoverableInvalid('invoicePublicKey');
      }
    } else {
      _recoverableInvalid('kind');
    }
    final canonical = <String, Object?>{
      'version': 2,
      'operationId': request['operationId'],
      'kind': kind,
      'amount': amount,
      'feeRate': fee,
      'address': request['address'],
      'assetId': request['assetId'],
      'recipientId': request['recipientId'],
      'transportEndpoints': endpoints,
      'senderTransportEndpoint': request['senderTransportEndpoint'],
      'witnessAmountSat': request['witnessAmountSat'],
      'witnessBlinding': request['witnessBlinding'],
      'minConfirmations': confirmations,
      'donation': false,
      'expirationTimestamp': request['expirationTimestamp'],
      'invoicePublicKey': request['invoicePublicKey'],
      'invoiceEncryption': request['invoiceEncryption'],
    };
    final command = RecoverableOnchainSendCommand._(
      network: network,
      version: 3,
      storageDirPath: null,
      walletBinding: walletBinding,
      backend: 'RGB_L1',
      recoveryCohort: recoveryCohort,
      nativeSourceRevision: sourceRevision,
      nativeOverlay: overlay,
      request: canonical,
      restored: restoring,
    );
    final fingerprint = crypto.sha256
        .convert(utf8.encode(command.requestJson))
        .toString();
    if (restoring && request['fingerprint'] != fingerprint) {
      _recoverableInvalid('fingerprint');
    }
    canonical['fingerprint'] = fingerprint;
    final result = RecoverableOnchainSendCommand._(
      network: network,
      version: 3,
      storageDirPath: null,
      walletBinding: walletBinding,
      backend: 'RGB_L1',
      recoveryCohort: recoveryCohort,
      nativeSourceRevision: sourceRevision,
      nativeOverlay: overlay,
      request: canonical,
      restored: restoring,
    );
    if (utf8.encode(result.requestJson).length > _recoverableMaxJsonBytes) {
      _recoverableInvalid('command');
    }
    return result;
  }
}
