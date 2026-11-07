import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('published RGB Lib bridge opens, locks and restores a wallet', (
    WidgetTester tester,
  ) async {
    final runtime = await _channel.invokeMapMethod<String, Object?>(
      'getRuntimeInfo',
    );
    expect(
      runtime,
      containsPair('version', '0.3.0-beta.7-upstream-dev-bfa.5-bfa'),
    );
    expect(runtime, containsPair('bridgeVersion', 4));

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
      expect(await address(restoredHandle), initial);
      await close();
    } finally {
      await close();
      if (!nativeMayOwnStorage) await scratch.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
