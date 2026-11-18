import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

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
      final backup = '${scratch.path}/wallet.backup';
      final byteBackup = '${scratch.path}/byte-export.backup';
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
        final exportedBytes = await _channel.invokeMethod<Uint8List>(
          'exportBackup',
          {'handle': handle, 'password': password},
        );
        expect(exportedBytes, isNotEmpty);
        await File(byteBackup).writeAsBytes(exportedBytes!);
        await close();
        final archives = {'file': backup, 'bytes': byteBackup};
        for (final entry in archives.entries) {
          final restored = '${scratch.path}/restored-${entry.key}';
          await restoreBackupFromFile(
            filePath: entry.value,
            password: password,
            dataDir: restored,
          );
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
                    (await _channel.invokeMethod<String>(
                      'onchainRecoveryState',
                      {'handle': restoredHandle},
                    ))!,
                  )
                  as Map<String, dynamic>;
          expect(state['restoredSnapshot'], isTrue);
          expect(state['pending'], isEmpty);
          // A coherent backup may predate a payment approved by the original wallet.
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
        }
      } finally {
        await close();
        if (!nativeMayOwnStorage) await scratch.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('facade shares one offline native RGB_L1 session', (
    tester,
  ) async {
    final scratch = await Directory.systemTemp.createTemp('rgb-facade-smoke-');
    final engine = RgbLibWallet(
      params: RgbLibWalletParams(
        network: 'regtest',
        storageDirPath: '${scratch.path}/wallet',
        reuseAddresses: true,
      ),
      keys: RgbLibKeys.reader(() => _testMnemonic),
    );
    final wallet = UtexoWallet.rgbLib(engine: engine);
    try {
      expect(wallet.protocol, 'RGB_L1');
      expect(wallet.rgbLibEngine, same(engine));
      expect(wallet.isInitialized, isFalse);
      await wallet.init();
      expect(wallet.isInitialized, isTrue);
      final identity = await engine.getWalletIdentity();
      final address = await wallet.getAddress();
      expect(address, startsWith('bcrt1p'));
      expect(await engine.getAddress(), address);
      final balance = await wallet.getBtcBalance(skipSync: true);
      expect(balance.vanilla.spendable, 0);
      expect(wallet.isUnlocked, isFalse);
      await expectLater(
        wallet.listChannels(),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      await wallet.shutdown();
      expect(wallet.isShutdown, isTrue);
      await engine.openExisting();
      expect(wallet.isInitialized, isTrue);
      expect((await engine.getWalletIdentity()).id, identity.id);
      expect(
        (await engine.getWalletIdentity()).recoveryCohort,
        identity.recoveryCohort,
      );
    } finally {
      await wallet.destroy();
      await scratch.delete(recursive: true);
    }
  });
}
