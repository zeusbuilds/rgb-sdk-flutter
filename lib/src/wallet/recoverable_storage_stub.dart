import '../errors/rgb_sdk_exception.dart';

Future<void> requireRecoverableStorage(
  String storageDirPath, {
  bool allowMissingOutbox = false,
}) async {
  throw const UnsupportedWalletFeatureException(
    'Native private recovery storage is required.',
    feature: 'recoverableOnchainSendStorage',
  );
}
