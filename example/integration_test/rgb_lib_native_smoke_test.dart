import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'dart:convert';

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'pinned RGB Lib bridge opens, locks and quarantines restored authority',
    (WidgetTester tester) async {
      final runtime = await _channel.invokeMapMethod<String, Object?>(
        'getRuntimeInfo',
      );
      expect(
        runtime,
        containsPair('version', RgbLibRuntimeInfo.expectedVersion),
      );
      expect(
        runtime,
        containsPair('bridgeVersion', RgbLibRuntimeInfo.expectedBridgeVersion),
      );
      final verifiedRuntime = await RgbLibWallet.getRuntimeInfo();
      expect(verifiedRuntime.contractRegistration, isTrue);
      expect(verifiedRuntime.durableOnchainRecovery, isTrue);
      expect(
        verifiedRuntime.integrationTree,
        RgbLibRuntimeInfo.expectedIntegrationTree,
      );

      final scratch = await Directory.systemTemp.createTemp('rgb-lib-smoke-');
      final wallet = '${scratch.path}/wallet';
      final restored = '${scratch.path}/restored';
      final backup = '${scratch.path}/wallet.backup';
      const password = 'disposable-smoke-password';
      String? activeHandle;
      var nativeMayOwnStorage = false;

      Map<String, Object?> openFields(String path) => <String, Object?>{
        'dataDir': path,
        'network': 'regtest',
        'mnemonic': _testMnemonic,
        'witnessVersion': 'taproot',
        'maxAllocationsPerUtxo': 5,
        'reuseAddresses': true,
      };

      Future<String> open(String path) async {
        nativeMayOwnStorage = true;
        final handle = await _channel.invokeMethod<String>(
          'openWallet',
          openFields(path),
        );
        expect(handle, isNotEmpty);
        activeHandle = handle;
        return handle!;
      }

      Future<void> close() async {
        final handle = activeHandle;
        if (handle == null) return;
        await _channel.invokeMethod<void>('closeWallet', {'handle': handle});
        activeHandle = null;
        nativeMayOwnStorage = false;
      }

      Future<String?> address(String handle) => _channel.invokeMethod<String>(
        'getAddress',
        {'handle': handle, 'rotate': false},
      );

      try {
        final handle = await open(wallet);
        final identity = await _channel.invokeMapMethod<String, Object?>(
          'getWalletIdentity',
          {'handle': handle},
        );
        expect(identity, containsPair('network', 'regtest'));
        await expectLater(
          _channel.invokeMethod<String>('openWallet', openFields(wallet)),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'WALLET_STORAGE_IN_USE',
            ),
          ),
        );
        final initial = await address(handle);
        expect(initial, startsWith('bcrt1p'));
        expect(await address(handle), initial);
        final balances = await _channel.invokeMapMethod<String, Object?>(
          'getBtcBalance',
          {'handle': handle, 'skipSync': true},
        );
        expect(balances?['vanilla'], containsPair('spendable', '0'));
        expect(balances?['colored'], containsPair('spendable', '0'));
        await _channel.invokeMethod<void>('backup', {
          'handle': handle,
          'backupPath': backup,
          'password': password,
        });
        await close();
        await _channel.invokeMethod<void>('restoreBackup', {
          'dataDir': restored,
          'backupPath': backup,
          'password': password,
        });
        final restoredHandle = await open(restored);
        final restoredIdentity = await _channel
            .invokeMapMethod<String, Object?>('getWalletIdentity', {
              'handle': restoredHandle,
            });
        expect(restoredIdentity?['id'], identity?['id']);
        expect(
          restoredIdentity?['recoveryCohort'],
          identity?['recoveryCohort'],
        );
        final state =
            jsonDecode(
                  (await _channel.invokeMethod<String>('onchainRecoveryState', {
                    'handle': restoredHandle,
                  }))!,
                )
                as Map<String, dynamic>;
        expect(state['restoredSnapshot'], isTrue);
        expect(state['pending'], isEmpty);
        // An old coherent backup cannot prove that the original wallet did not
        // authorize a transaction after that snapshot. Native must fail closed.
        await expectLater(
          address(restoredHandle),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'RECOVERY_RESTORE_UNCERTAIN',
            ),
          ),
        );
        await close();
      } finally {
        await close();
        if (!nativeMayOwnStorage) await scratch.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
