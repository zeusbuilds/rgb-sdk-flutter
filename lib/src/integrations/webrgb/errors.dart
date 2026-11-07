import '../../errors/native_bridge_error_mapper.dart';
import '../../errors/rgb_sdk_exception.dart';
import '../../wallet/burn_recipient.dart' as recipient;

/// Sanitized WebRGB transport failure; never contains the native cause.
class WebRgbError implements Exception {
  const WebRgbError(this.code, this.message);
  final String code;
  final String message;
  Map<String, String> toJson() => {'code': code, 'message': message};
  @override
  String toString() => 'WebRgbError($code): $message';
}

Future<T> webRgbWalletCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on WebRgbError {
    rethrow;
  } catch (error) {
    var code = error is RgbSdkException ? error.code : null;
    if (error is RgbSdkException && error.cause is NativeBridgeFailure) {
      code = (error.cause! as NativeBridgeFailure).nativeCode;
    }
    if (code == 'AssetNotFound' ||
        code == 'UnknownAsset' ||
        code == 'ASSET_NOT_FOUND') {
      throw const WebRgbError('ASSET_NOT_FOUND', 'Asset was not found.');
    }
    if (error is WalletValidationException ||
        error is BadRequestError ||
        code == 'InvalidAssetId' ||
        code == 'InvalidInvoice' ||
        code == 'InvalidAmount' ||
        code == 'INVALID_PARAMS' ||
        code == 'INVALID_AMOUNT' ||
        code == 'AMOUNT_OVERFLOW') {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Invalid wallet operation parameters.',
      );
    }
    if (error is UnsupportedWalletFeatureException ||
        code == 'UnsupportedInExternalSignerMode' ||
        code == 'UNSUPPORTED_CAPABILITY' ||
        code == 'METHOD_NOT_SUPPORTED') {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Wallet operation is unsupported.',
      );
    }
    throw const WebRgbError('INTERNAL_ERROR', 'Wallet operation failed.');
  }
}

int webRgbInteger(
  int value,
  String name, {
  int min = 1,
  int max = 9007199254740991,
}) {
  if (value < min || value > max) {
    throw WebRgbError(
      'INVALID_PARAMS',
      '$name is outside the supported integer range.',
    );
  }
  return value;
}

int webRgbAmount(BigInt value) {
  if (value.isNegative || value > BigInt.from(9007199254740991)) {
    throw const WebRgbError(
      'INTERNAL_ERROR',
      'Amount exceeds the supported exact integer range.',
    );
  }
  return value.toInt();
}

void webRgbAsset(String? assetId) {
  if (assetId != null &&
      (!assetId.startsWith('rgb:') || assetId.length > 256)) {
    throw const WebRgbError('INVALID_PARAMS', 'Invalid asset ID.');
  }
}

/// Encodes a nonzero EVM address as 12 zero bytes and 20 address bytes.
String encodeEvmBurnRecipient(String address) {
  try {
    return recipient.encodeEvmBurnRecipient(address);
  } on WalletValidationException {
    throw const WebRgbError(
      'INVALID_PARAMS',
      'A nonzero 20-byte EVM address is required.',
    );
  }
}

/// Validates Tron Base58Check and encodes its nonzero account into 32 bytes.
String encodeTronBurnRecipient(String address) {
  try {
    return recipient.encodeTronBurnRecipient(address);
  } on WalletValidationException {
    throw const WebRgbError(
      'INVALID_PARAMS',
      'A nonzero Tron Base58Check address is required.',
    );
  }
}
