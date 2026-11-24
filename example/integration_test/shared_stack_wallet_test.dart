// Uses only the already-running shared Utexo stack. Never starts containers,
// resets chains, touches an existing wallet, or retries an irreversible send.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

const _runId = String.fromEnvironment('RGB_SHARED_RUN_ID');
const _contract = String.fromEnvironment('RGB_SHARED_CONTRACT_BASE64');
const _asset = String.fromEnvironment('RGB_SHARED_ASSET_ID');
const _contractHash = String.fromEnvironment('RGB_SHARED_CONTRACT_SHA256');
const _lifecycleOnly = bool.fromEnvironment('RGB_SHARED_LIFECYCLE_ONLY');
const _resume = bool.fromEnvironment('RGB_SHARED_RESUME_AFTER_BLIND');
const _verifyClosedFixture = bool.fromEnvironment(
  'RGB_SHARED_VERIFY_CLOSED_FIXTURE',
);
const _password = 'Disposable-shared-regtest-fixture-only';
String get _host => Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
String get _role => Platform.isAndroid ? 'sdk-android17' : 'sdk-ios27';
final _http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
final _unlock = UtexoUnlockConfig(
  indexerUrl: 'http://$_host:18094',
  proxyEndpoint: 'rpc://$_host:28090/json-rpc',
  ethRpcUrl: 'http://$_host:18555',
);
int _sequence = 0;
late File _journal;

Future<void> _event(String event, Map<String, Object?> fields) async {
  final payload = <String, Object?>{
    'event': event,
    'run_id': _runId,
    'role': _role,
    ...fields,
  };
  await _journal.writeAsString(
    '${jsonEncode(payload)}\n',
    mode: FileMode.append,
    flush: true,
  );
  // Invoices, proof bytes and sandbox paths stay in private transaction
  // journals. The runner resolves its own fixture control records privately.
  final diagnostic = Map<String, Object?>.of(payload)
    ..remove('invoice')
    ..remove('consignment_base64')
    ..remove('storage');
  debugPrintSynchronously('RGB_SDK_SHARED ${jsonEncode(diagnostic)}');
  final request = await _http.postUrl(
    Uri.parse('http://127.0.0.1:29671/event'),
  );
  request.headers.contentType = ContentType.json;
  final body = utf8.encode(jsonEncode(payload));
  request.contentLength = body.length;
  request.add(body);
  final response = await request.close();
  await response.drain<void>();
  if (response.statusCode != 200 &&
      response.statusCode != 201 &&
      response.statusCode != 202) {
    throw StateError('Control relay rejected event: ${response.statusCode}');
  }
}

Future<Map<String, Object?>> _command(
  String event,
  Map<String, Object?> fields,
) async {
  final id = '$_runId-$_role-${_sequence++}';
  // Acknowledgement polling never repeats the request. An uncertain mint/burn
  // is retained in the durable device and host journals for reconciliation.
  await _event(event, {'id': id, ...fields});
  final deadline = DateTime.now().add(const Duration(minutes: 12));
  while (DateTime.now().isBefore(deadline)) {
    final request = await _http.getUrl(
      Uri.parse('http://127.0.0.1:29671/commands/$id'),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode == 200) {
      final result = Map<String, Object?>.from(jsonDecode(body) as Map);
      if (result['error'] != null ||
          result['ok'] == false ||
          result['status'] == 'failed') {
        throw StateError(
          'Host command $event failed; inspect retained host journal for $id.',
        );
      }
      await _event('host_command_acknowledged', {'id': id, 'command': event});
      return result;
    }
    if (response.statusCode != 404) {
      throw StateError('Control relay HTTP ${response.statusCode}');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw TimeoutException(
    'Host command has no acknowledgement; do not replay: $id',
  );
}

UtexoWallet _wallet(Directory directory, int offset) => UtexoWallet.rln(
  config: UtexoWalletConfig(
    storageDirPath: directory.path,
    network: 'regtest',
    daemonListeningPort: 35431 + offset,
    ldkPeerListeningPort: 35432 + offset,
  ),
);

Future<void> _wait(String label, Future<bool> Function() assertion) async {
  final deadline = DateTime.now().add(const Duration(minutes: 4));
  while (DateTime.now().isBefore(deadline)) {
    if (await assertion()) return;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw StateError(
    'Timed out waiting for $label; inspect retained wallet journals.',
  );
}

Future<void> _assetBalance(
  UtexoWallet wallet,
  int units, {
  UtexoWallet? peer,
}) => _wait('exact settled/spendable asset balance $units', () async {
  await peer?.refreshWallet();
  await wallet.refreshWallet();
  final balance = await wallet.getAssetBalance(_asset);
  return balance.settled == BigInt.from(units) &&
      balance.spendable == BigInt.from(units);
});

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Accessibility inspection can otherwise create the platform's semantics
  // handle midway through this long native test, which the widget-test leak
  // check mistakes for a test-owned handle. Establish its lifetime before the
  // widget-test baseline and restore the platform value after verification.
  binding.platformDispatcher.semanticsEnabledTestValue = true;
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
  testWidgets(
    'existing shared stack: lifecycle, BTC, canonical BFA and payout',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Local wallet qualification')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_runId, matches(RegExp(r'^[A-Za-z0-9_.-]{6,100}$')));
      final root = await Directory.systemTemp.createTemp('rgb-shared-$_runId-');
      _journal = File('${root.path}/events.jsonl');
      // Native creates each missing wallet directory with owner-only mode.
      // Dart Directory.create uses the process umask, which can yield 0755.
      final dirA = Directory('${root.path}/wallet-a');
      final dirB = Directory('${root.path}/wallet-b');
      var walletA = _wallet(dirA, 0);
      var walletB = _wallet(dirB, 2);
      await _event('fixture_created', {
        'storage': root.path,
        'network': 'regtest',
      });
      try {
        if (Platform.isAndroid) {
          await _event('stage', {'stage': 'request_local_network_consent'});
          final granted = await const MethodChannel(
            'com.utexo.rgb_sdk_flutter_example/permissions',
          ).invokeMethod<bool>('requestLocalNetworkPermission');
          expect(
            granted,
            true,
            reason:
                'Local-network consent is required for the regtest fixture.',
          );
          await _event('local_network_consent_granted', {});
        }
        final genesisRequest = await _http.getUrl(
          Uri.parse('http://$_host:18094/block-height/0'),
        );
        final genesisResponse = await genesisRequest.close();
        expect(genesisResponse.statusCode, 200);
        expect(
          (await utf8.decoder.bind(genesisResponse).join()).trim(),
          '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
        );
        await _event('shared_chain_preflight_passed', {'network': 'regtest'});
        if (_verifyClosedFixture) {
          final restored = await _command('fixture_restore_requested', {
            'storage': root.path,
          });
          await walletA.reinit(password: _password, unlockConfig: _unlock);
          await walletB.reinit(password: _password, unlockConfig: _unlock);
          expect(
            (await walletA.getNodeInfo()).pubkey,
            restored['wallet_a_pubkey'],
          );
          await _assetBalance(walletA, 1580000, peer: walletB);
          await _assetBalance(walletB, 400000, peer: walletA);
          final beforeA = (await walletA.getBtcBalance()).vanilla.settled;
          final beforeB = (await walletB.getBtcBalance()).vanilla.settled;
          expect(beforeA, greaterThan(0));
          expect(beforeB, greaterThan(0));
          for (final wallet in [walletA, walletB]) {
            await wallet.shutdown();
            await wallet.reinit(password: _password, unlockConfig: _unlock);
          }
          expect(
            (await walletA.getNodeInfo()).pubkey,
            restored['wallet_a_pubkey'],
          );
          await _assetBalance(walletA, 1580000, peer: walletB);
          await _assetBalance(walletB, 400000, peer: walletA);
          expect((await walletA.getBtcBalance()).vanilla.settled, beforeA);
          expect((await walletB.getBtcBalance()).vanilla.settled, beforeB);
          await _event('closed_funded_fixture_verified', {
            'restored_from_run': restored['restored_from_run'],
            'wallet_a_units': 1580000,
            'wallet_b_units': 400000,
            'bitcoin_settled_persisted': true,
          });
          await _event('suite_passed', {
            'scope': 'read-only-closed-funded-fixture-persistence',
          });
          return;
        }
        if (_resume) {
          final restored = await _command('fixture_restore_requested', {
            'storage': root.path,
          });
          await walletA.reinit(password: _password, unlockConfig: _unlock);
          await walletB.reinit(password: _password, unlockConfig: _unlock);
          final identityA = (await walletA.getNodeInfo()).pubkey;
          expect(identityA, restored['wallet_a_pubkey']);
          await _assetBalance(walletA, 1500000, peer: walletB);
          await _assetBalance(walletB, 500000, peer: walletA);
          final imported = await walletA.importRgbContract(
            contractBase64: _contract,
            expectedAssetId: _asset,
          );
          expect(imported.alreadyImported, true);
          final identity = await _command('identity_requested', {});
          expect(identity['asset_id'], _asset);
          await _event('closed_fixture_resume_verified', {
            'pubkey': identityA,
            'wallet_a_units': 1500000,
            'wallet_b_units': 500000,
          });
          await _completeBfaFlow(walletA, walletB, root, identityA, identity);
          return;
        }
        await _event('stage', {'stage': 'wallet_a_init'});
        await walletA.init(password: _password);
        await _event('stage', {'stage': 'wallet_a_unlock'});
        await walletA.unlock(password: _password, config: _unlock);
        final identityA = (await walletA.getNodeInfo()).pubkey;
        for (var cycle = 0; cycle < 3; cycle++) {
          await _event('stage', {'stage': 'wallet_a_shutdown', 'cycle': cycle});
          await walletA.shutdown();
          await _event('stage', {'stage': 'wallet_a_reinit', 'cycle': cycle});
          await walletA.reinit(password: _password, unlockConfig: _unlock);
          expect((await walletA.getNodeInfo()).pubkey, identityA);
          await _event('lifecycle_reinit_passed', {
            'cycle': cycle,
            'pubkey': identityA,
          });
        }
        await walletA.destroy();
        walletA = _wallet(dirA, 0);
        await walletA.reinit(password: _password, unlockConfig: _unlock);
        expect((await walletA.getNodeInfo()).pubkey, identityA);
        await _event('lifecycle_destroy_reopen_passed', {'pubkey': identityA});
        if (_lifecycleOnly) {
          await _event('suite_passed', {'scope': 'unfunded-lifecycle-only'});
          return;
        }

        expect(
          sha256.convert(base64Decode(_contract)).toString(),
          _contractHash,
        );
        await walletB.init(password: _password);
        await walletB.unlock(password: _password, config: _unlock);
        for (final wallet in [walletA, walletB]) {
          final imported = await wallet.importRgbContract(
            contractBase64: _contract,
            expectedAssetId: _asset,
          );
          expect(imported.assetId, _asset);
          expect(imported.assetSchema, 'Bfa');
          expect(imported.name, 'Usdt');
          expect(imported.ticker, 'USDT');
          expect(imported.precision, 6);
          final balance = await wallet.getAssetBalance(_asset);
          expect(balance.spendable, BigInt.zero);
          expect(balance.settled, BigInt.zero);
          final repeat = await wallet.importRgbContract(
            contractBase64: _contract,
            expectedAssetId: _asset,
          );
          expect(repeat.alreadyImported, true);
        }
        await _event('canonical_import_passed', {
          'asset_id': _asset,
          'sha256': _contractHash,
        });
        for (final entry in {'a': walletA, 'b': walletB}.entries) {
          await _command('fund_requested', {
            'address': await entry.value.getAddress(),
            'amount_sats': 2000000,
            'wallet': entry.key,
          });
          await _wait('BTC spendable for ${entry.key}', () async {
            await entry.value.syncWallet();
            return (await entry.value.getBtcBalance()).vanilla.spendable >=
                1900000;
          });
        }
        final bitcoin = await walletA.sendBtc(
          amount: 20000,
          address: await walletB.getAddress(),
        );
        await _wait('two-sided confirmed Bitcoin transfer', () async {
          await walletA.syncWallet();
          await walletB.syncWallet();
          final outgoing = await walletA.listTransactions();
          final incoming = await walletB.listTransactions();
          return outgoing.any(
                (tx) => tx.txid == bitcoin && tx.confirmationTime != null,
              ) &&
              incoming.any(
                (tx) =>
                    tx.txid == bitcoin &&
                    tx.received == 20000 &&
                    tx.confirmationTime != null,
              );
        });
        await _event('bitcoin_transfer_passed', {
          'txid': bitcoin,
          'amount_sats': 20000,
        });
        for (final wallet in [walletA, walletB]) {
          await wallet.createUtxos(num: 8, size: 10000, feeRate: 1);
        }
        await _wait('confirmed allocation UTXOs', () async {
          await walletA.syncWallet();
          await walletB.syncWallet();
          final a = await walletA.listUnspents();
          final b = await walletB.listUnspents();
          return a
                      .where((item) => item.utxo.colorable && item.utxo.exists)
                      .length >=
                  8 &&
              b
                      .where((item) => item.utxo.colorable && item.utxo.exists)
                      .length >=
                  8;
        });
        final invoice = await walletA.blindReceive(
          RgbInvoiceRequest(
            assetId: _asset,
            amount: 2000000,
            minConfirmations: 1,
          ),
        );
        final mint = await _command('bfa_mint_requested', {
          'invoice': invoice.invoice,
          'asset_id': _asset,
          'amount_units': 2000000,
        });
        await _assetBalance(walletA, 2000000);
        await _event('canonical_bfa_mint_received', {
          'asset_id': _asset,
          'amount_units': 2000000,
        });
        final blind = await walletB.blindReceive(
          RgbInvoiceRequest(
            assetId: _asset,
            amount: 500000,
            minConfirmations: 1,
          ),
        );
        final sent = await walletA.onchainSend(
          RgbSendRequest(
            invoice: blind.invoice,
            assetId: _asset,
            amount: 500000,
          ),
        );
        await _assetBalance(walletB, 500000, peer: walletA);
        await _assetBalance(walletA, 1500000, peer: walletB);
        expect(
          (await walletA.listTransfers(assetId: _asset))
              .singleWhere((row) => row.txid == sent.txid && row.kind == 'Send')
              .amountBaseUnits,
          '500000',
        );
        expect(
          (await walletB.listTransfers(assetId: _asset))
              .singleWhere(
                (row) => row.txid == sent.txid && row.kind == 'ReceiveBlind',
              )
              .amountBaseUnits,
          '500000',
        );
        await _event('bfa_blind_transfer_passed', {
          'txid': sent.txid,
          'amount_units': 500000,
        });
        await _completeBfaFlow(walletA, walletB, root, identityA, mint);
      } catch (error) {
        await _event('suite_failed', {
          'error_type': error.runtimeType.toString(),
          if (error is RgbSdkException) 'operation': error.operation,
        });
        rethrow;
      } finally {
        // Flutter integration_test uninstalls its test application on exit.
        // Explicitly close native writers, then let the host runner privately
        // preserve only this run's fixture before allowing the process to end.
        final cleanupErrors = <Object>[];
        for (final wallet in [walletA, walletB]) {
          try {
            await wallet.destroy();
          } catch (error) {
            cleanupErrors.add(error);
          }
        }
        await _command('fixture_backup_requested', {
          'storage': root.path,
          'native_closed': cleanupErrors.isEmpty,
        });
        _http.close();
        if (cleanupErrors.isNotEmpty) {
          throw StateError(
            'Native fixture teardown failed; forensic backup retained.',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 35)),
  );
}

Future<void> _completeBfaFlow(
  UtexoWallet walletA,
  UtexoWallet walletB,
  Directory root,
  String identityA,
  Map<String, Object?> mint,
) async {
  final witness = await walletA.witnessReceive(
    RgbInvoiceRequest(assetId: _asset, amount: 100000, minConfirmations: 1),
  );
  final returned = await walletB.onchainSend(
    RgbSendRequest(
      invoice: witness.invoice,
      assetId: _asset,
      amount: 100000,
      witnessAmountSat: 1000,
    ),
  );
  await walletA.refreshWallet();
  final statusRequest = await _http.getUrl(
    Uri.parse('http://$_host:18094/tx/${returned.txid}/status'),
  );
  final statusResponse = await statusRequest.close();
  final status =
      jsonDecode(await utf8.decoder.bind(statusResponse).join()) as Map;
  final observedWitnessBalance = await walletA.getAssetBalance(_asset);
  await _event('witness_balance_observed', {
    'txid': returned.txid,
    'bitcoin_confirmed': status['confirmed'],
    'settled': observedWitnessBalance.settled.toString(),
    'future': observedWitnessBalance.future.toString(),
    'spendable': observedWitnessBalance.spendable.toString(),
    'expected_final_units': 1600000,
    'qualification':
        'observation only; auto-miner is never paused on shared chain',
  });
  await _assetBalance(walletA, 1600000, peer: walletB);
  await _assetBalance(walletB, 400000, peer: walletA);
  await _event('bfa_witness_transfer_passed', {
    'txid': returned.txid,
    'amount_units': 100000,
  });

  final recipient = mint['recipient'];
  expect(recipient, isA<String>());
  await _event('bfa_burn_prepared', {
    'asset_id': _asset,
    'amount_units': 20000,
    'recipient': recipient,
  });
  final burn = await walletA.burn(
    BurnParams(
      assetId: _asset,
      amount: '20000',
      burnRecipient: (recipient! as String)
          .replaceFirst('0x', '')
          .toLowerCase()
          .padLeft(64, '0'),
      feeRate: 1,
      minConfirmations: 1,
    ),
  );
  // Persist native result before proof lookup or external payout dispatch.
  await _event('bfa_burn_native_result', {
    'txid': burn.txid,
    'batch_transfer_idx': burn.batchTransferIdx,
    'amount_units': 20000,
  });
  final proof = await walletA.getConsignment(_asset, burn.txid);
  final saved = File('${root.path}/burn-${burn.txid}.base64');
  await saved.writeAsString(proof, flush: true);
  await _command('bfa_burn_requested', {
    'asset_id': _asset,
    'txid': burn.txid,
    'consignment_base64': proof,
    'amount_units': 20000,
    'recipient': recipient,
  });
  await _assetBalance(walletA, 1580000, peer: walletB);
  final fundedBefore = await walletA.getBtcBalance();
  await walletA.shutdown();
  await walletA.reinit(password: _password, unlockConfig: _unlock);
  expect((await walletA.getNodeInfo()).pubkey, identityA);
  await _assetBalance(walletA, 1580000);
  expect(
    (await walletA.getBtcBalance()).vanilla.settled,
    fundedBefore.vanilla.settled,
  );
  await _event('funded_lifecycle_passed', {'asset_units': 1580000});
  await _event('suite_passed', {
    'scope': _resume
        ? 'resumed-BFA-witness-burn-payout-funded-persistence'
        : 'BTC-canonical-BFA-mint-blind-witness-burn-payout-persistence',
  });
}
