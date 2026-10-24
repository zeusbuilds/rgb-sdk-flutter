/// Narrow support diagnostic carried by a native failure cause.
///
/// [operation] names an SDK operation, never native exception text or payloads.
abstract interface class NativeOperationCause {
  String get operation;
}

/// Narrow machine-readable error identity from a native failure cause.
abstract interface class NativeErrorCodeCause {
  String get nativeCode;
}

const _supportSafeNativeCodes = <String>{
  'RlnError',
  'NotInitialized',
  'InvalidRequest',
  'NotFound',
  'Conflict',
  'FailedBitcoindConnection',
  'FailedBdkSync',
  'FailedBroadcast',
  'FailedPeerConnection',
  'InsufficientCapacity',
  'InsufficientFunds',
  'NoAvailableUtxos',
  'InsufficientAllocationSlots',
  'NoRoute',
  'ExternalSignerRequired',
  'ExternalSignerMismatch',
  'ExternalSignerUnavailable',
  'ExternalSignerProtocolError',
  'UnsupportedInExternalSignerMode',
  'FailedVssInit',
  'Internal',
  'LightningUnsupportedOnMainnet',
  'NativeError',
};

/// Base exception type thrown by the Dart wallet facade.
class RgbSdkException implements Exception {
  const RgbSdkException(
    this.message, {
    required this.code,
    this.statusCode,
    this.cause,
  });

  final String message;
  final String code;
  final int? statusCode;
  final Object? cause;

  /// Support-safe native operation token, when supplied by a structured cause.
  ///
  /// Arbitrary native messages, endpoints, request bodies and paths remain
  /// private. Apps can preserve this diagnostic without importing advanced APIs.
  String? get operation {
    final diagnostic = cause;
    if (diagnostic is! NativeOperationCause) return null;
    final token = diagnostic.operation;
    return RegExp(r'^[A-Za-z][A-Za-z0-9_.]{0,79}$').hasMatch(token)
        ? token
        : null;
  }

  /// Exact allowlisted native error code, without native message inspection.
  ///
  /// Apps may use this to offer an explicit action such as allocation-UTXO
  /// setup after `NoAvailableUtxos`. Unknown and payload-like values are null.
  String? get nativeCode {
    final diagnostic = cause;
    if (diagnostic is! NativeErrorCodeCause) return null;
    final code = diagnostic.nativeCode;
    return _supportSafeNativeCodes.contains(code) ? code : null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': runtimeType.toString(),
      'message': message,
      'code': code,
      'statusCode': statusCode,
      // Causes may contain native payloads, HTTP bodies or key material. They
      // remain available for controlled debugging, never public serialization.
      if (cause != null) 'hasCause': true,
    };
  }

  @override
  String toString() {
    final statusCode = this.statusCode;
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    return '${runtimeType.toString()}($code$status): $message';
  }
}

/// RN-core compatible base error name.
class SDKError extends RgbSdkException {
  const SDKError(
    super.message, {
    super.code = 'SDK_ERROR',
    super.statusCode,
    super.cause,
  });
}

/// General wallet lifecycle or native-response error.
class WalletException extends SDKError {
  const WalletException(
    super.message, {
    super.code = 'WALLET_ERROR',
    super.statusCode,
    super.cause,
  });
}

/// Native response violated the SDK's wire contract.
class NativeProtocolException extends SDKError {
  const NativeProtocolException(
    super.message, {
    this.field,
    super.statusCode,
    super.cause,
  }) : super(code: 'NATIVE_PROTOCOL_ERROR');

  final String? field;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    if (field != null) 'field': field,
  };

  @override
  String toString() {
    final field = this.field;
    if (field == null) return 'NativeProtocolException: $message';
    return 'NativeProtocolException($field): $message';
  }
}

/// RN-core compatible wallet error name.
class WalletError extends WalletException {
  const WalletError(super.message, {super.code, super.statusCode, super.cause});
}

/// The native recovery outbox is missing or is no longer a real directory.
///
/// This is retained-state loss, never proof that a payment was not sent. Restore
/// the complete matching private storage cohort; do not recreate an empty outbox.
class RecoverableSendStorageException extends WalletException {
  const RecoverableSendStorageException()
    : super(
        'On-chain recovery storage is unavailable. Wallet recovery is required.',
        code: 'RECOVERABLE_SEND_STORAGE_LOST',
      );
}

/// A Dart-side deadline elapsed before a native RLN operation returned.
///
/// Pigeon and the pinned native RLN artifacts do not expose true cancellation
/// once a call has entered native code. The binding therefore quarantines the
/// node after this error and keeps its internal queue blocked until native
/// completion, so follow-up cleanup can run in order.
class RlnOperationTimeoutException extends WalletException {
  const RlnOperationTimeoutException({
    required this.operation,
    required this.timeout,
  }) : super('Native RLN operation timed out.', cause: operation);

  @override
  final String operation;
  final Duration timeout;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'operation': operation,
    'timeoutMs': timeout.inMilliseconds,
  };

  @override
  String toString() =>
      'RlnOperationTimeoutException($operation, ${timeout.inMilliseconds}ms)';
}

/// Input validation failure before a native call is made.
class WalletValidationException extends SDKError {
  const WalletValidationException(super.message, {required this.field})
    : super(code: 'VALIDATION_ERROR');

  final String field;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'field': field,
  };

  @override
  String toString() => 'WalletValidationException($field): $message';
}

/// RN-core compatible validation error name.
class ValidationError extends WalletValidationException {
  const ValidationError(super.message, String field) : super(field: field);
}

/// RN-core compatible crypto error name.
class CryptoError extends SDKError {
  const CryptoError(super.message, {super.statusCode, super.cause})
    : super(code: 'CRYPTO_ERROR');
}

/// Private-key signing path that is intentionally not production enabled.
class ExperimentalCryptoException extends CryptoError {
  const ExperimentalCryptoException(super.message, {required this.primitive})
    : super(cause: primitive);

  final String primitive;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'primitive': primitive,
  };
}

/// RN-core compatible network error name.
class NetworkError extends SDKError {
  const NetworkError(super.message, {super.statusCode, super.cause})
    : super(code: 'NETWORK_ERROR');
}

/// LNURL callback business failure, distinct from malformed success JSON.
///
/// [reason] is the server's business code. Do not log it automatically: an
/// untrusted server may return arbitrary text. Safe diagnostics omit it.
class LnurlCallbackException extends NetworkError {
  const LnurlCallbackException({required this.reason})
    : super('The LNURL provider could not issue an invoice.');

  final String reason;
}

/// Caller-requested cancellation before an SDK operation completed.
class OperationCancelledError extends SDKError {
  const OperationCancelledError(super.message, {super.cause})
    : super(code: 'CANCELLED');
}

/// RN-core compatible configuration error name.
class ConfigurationError extends SDKError {
  const ConfigurationError(super.message, {super.statusCode, super.cause})
    : super(code: 'CONFIGURATION_ERROR');
}

/// RN-core compatible bad request error name.
class BadRequestError extends SDKError {
  const BadRequestError(super.message, {super.statusCode = 400, super.cause})
    : super(code: 'BAD_REQUEST');
}

/// RN-core compatible not found error name.
class NotFoundError extends SDKError {
  const NotFoundError(super.message, {super.statusCode = 404, super.cause})
    : super(code: 'NOT_FOUND');
}

/// RN-core compatible conflict error name.
class ConflictError extends SDKError {
  const ConflictError(super.message, {super.statusCode = 409, super.cause})
    : super(code: 'CONFLICT');
}

/// RN-core compatible RGB node error name.
class RgbNodeError extends SDKError {
  const RgbNodeError(super.message, {super.statusCode, super.cause})
    : super(code: 'RGB_NODE_ERROR');
}

/// Feature that exists for parity but is intentionally unavailable.
class UnsupportedWalletFeatureException extends SDKError {
  const UnsupportedWalletFeatureException(
    super.message, {
    required this.feature,
    super.cause,
  }) : super(code: 'UNSUPPORTED');

  final String feature;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'feature': feature,
  };

  @override
  String toString() => 'UnsupportedWalletFeatureException($feature): $message';
}
