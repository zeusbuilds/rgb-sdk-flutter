import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'snapshot support cannot imply portable or phrase-only RGB recovery',
    () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'getRuntimeInfo');
        return {
          'version': RgbLibRuntimeInfo.expectedVersion,
          'sourceRevision': RgbLibRuntimeInfo.expectedSourceRevision,
          'bridgeVersion': RgbLibRuntimeInfo.expectedBridgeVersion,
          'integrationTree': RgbLibRuntimeInfo.expectedIntegrationTree,
          'overlayPatchSha256': RgbLibRuntimeInfo.expectedOverlayPatchSha256,
          'sourceLockSha256': RgbLibRuntimeInfo.expectedSourceLockSha256,
          'sourceManifestSha256':
              RgbLibRuntimeInfo.expectedSourceManifestSha256,
          'burn': true,
          'consignment': true,
          'bfa': true,
          // Unqualified fields cannot override the reviewed recovery contract.
          'restoredWalletSpending': true,
          'mnemonicOnlyRgbRecovery': true,
        };
      });
      final RgbLibBackupRecoveryCapabilities capabilities =
          (await RgbLibWallet.getRuntimeInfo()).backupRecovery;
      expect(capabilities.encryptedSnapshotCreation, isTrue);
      expect(capabilities.readOnlySnapshotRestoration, isTrue);
      expect(capabilities.restoredWalletSpending, isFalse);
      expect(capabilities.mnemonicOnlyRgbRecovery, isFalse);
    },
  );
}
