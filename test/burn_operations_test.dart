import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/errors/native_bridge_error_mapper.dart';

const params = BurnParams(
  assetId: 'rgb:asset',
  amount: '18446744073709551615',
  burnRecipient:
      '0000000000000000000000001212121212121212121212121212121212121212',
  feeRate: 2,
  minConfirmations: 3,
);
const metadata = BurnOperationMetadata(
  origin: 'https://mint.example',
  network: 'regtest',
  payout: BurnPayout(
    chainId: 'eip155:42161',
    address: '0x1212121212121212121212121212121212121212',
  ),
);
final result = BurnResult(txid: 'ab' * 32, batchTransferIdx: 42);

// Explicit test-only storage; the production API requires host-owned durability.
class MemoryBurnStore implements BurnOperationStore {
  final Map<String, Object?> data = {};
  final List<BurnOperationState> writes = [];
  Future<void> Function(BurnOperationRecord)? beforeWrite;
  Future<void> Function(BurnOperationRecord)? afterWrite;
  @override
  Future<List<Object?>> readAll() async => data.values.toList();
  @override
  Future<void> write(BurnOperationRecord record) async {
    await beforeWrite?.call(record);
    data[record.id] = jsonDecode(jsonEncode(record.toJson()));
    writes.add(record.state);
    await afterWrite?.call(record);
  }
}

class BurnTestWallet implements BurnWallet {
  int calls = 0;
  Future<BurnResult> Function()? onBurn;
  String kind = 'Burn';
  @override
  Future<BurnResult> burn(BurnParams params) async {
    calls++;
    return onBurn == null ? result : await onBurn!();
  }

  @override
  Future<String> getConsignment(String assetId, String txid) async =>
      'cHJvb2Y=';
  @override
  Future<List<CoreTransfer>> listTransfers({String? assetId}) async => [
    CoreTransfer(
      idx: 9,
      status: 'Settled',
      kind: kind,
      txid: result.txid,
      assignments: const [],
      transportEndpoints: const [],
    ),
  ];
}

class CapabilityBurnTestWallet extends BurnTestWallet
    implements BurnCapabilityWallet {
  bool supportsBurn = false;

  @override
  Future<BfaCapabilities> getBfaCapabilities() async =>
      BfaCapabilities(burn: supportsBurn, consignment: true, bfa: true);
}

void main() {
  late BurnTestWallet wallet;
  late MemoryBurnStore store;
  late BurnOperations operations;
  setUp(() {
    wallet = BurnTestWallet();
    store = MemoryBurnStore();
    operations = BurnOperations(wallet, store);
  });

  test(
    'full u64 survives durable v2 roundtrip; pending precedes dispatch',
    () async {
      wallet.onBurn = () async {
        expect(store.writes, [
          BurnOperationState.prepared,
          BurnOperationState.pending,
        ]);
        return result;
      };
      final record = await operations.execute(params, metadata, () {});
      expect(record.id, matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(record.state, BurnOperationState.complete);
      final saved = (await operations.records()).single;
      expect(saved.params.amount, params.amount);
      expect(saved.result!.txid, result.txid);
      expect(wallet.calls, 1);
    },
  );

  test(
    'concurrent wrappers serialize and generate independent identities',
    () async {
      final other = BurnOperations(wallet, store);
      final gate = Completer<BurnResult>();
      wallet.onBurn = () => gate.future;
      final first = operations.execute(params, metadata, () {});
      final second = other.execute(params, metadata, () {});
      await Future<void>.delayed(Duration.zero);
      expect(wallet.calls, 1);
      gate.complete(result);
      final records = await Future.wait([first, second]);
      expect(records.map((record) => record.id).toSet(), hasLength(2));
      expect(wallet.calls, 2);
      expect(
        () => BurnOperations(wallet, MemoryBurnStore()),
        throwsA(isA<ConfigurationError>()),
      );
    },
  );

  test('uncertain native result blocks queued and restarted burns', () async {
    wallet.onBurn = () async => throw StateError('lost response');
    await expectLater(
      operations.execute(params, metadata, () {}),
      throwsStateError,
    );
    await expectLater(
      operations.execute(params, metadata, () {}),
      throwsA(
        isA<WalletException>().having(
          (e) => e.code,
          'code',
          'BURN_OUTCOME_UNRESOLVED',
        ),
      ),
    );
    final restarted = BurnTestWallet();
    await expectLater(
      BurnOperations(restarted, store).execute(params, metadata, () {}),
      throwsA(isA<WalletException>()),
    );
    expect(
      (await operations.records()).single.state,
      BurnOperationState.pending,
    );
    expect(wallet.calls, 1);
    expect(restarted.calls, 0);
  });

  test(
    'a capability refusal before journaling or in the backend is definitive',
    () async {
      final watchOnly = CapabilityBurnTestWallet();
      final journal = BurnOperations(watchOnly, store);
      await expectLater(
        journal.execute(params, metadata, () {}),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      expect(watchOnly.calls, 0);
      expect(store.writes, isEmpty);

      watchOnly.supportsBurn = true;
      watchOnly.onBurn = () async => throw const RgbLibWalletException(
        'Fixture capability refusal.',
        code: 'UNSUPPORTED_CAPABILITY',
      );
      await expectLater(
        journal.execute(params, metadata, () {}),
        throwsA(isA<RgbLibWalletException>()),
      );
      expect(
        (await journal.records()).single.state,
        BurnOperationState.cancelled,
      );
      watchOnly.onBurn = null;
      expect(
        (await journal.execute(params, metadata, () {})).state,
        BurnOperationState.complete,
      );
      expect(watchOnly.calls, 2);
    },
  );

  for (final code in ['InsufficientFunds', 'NoAvailableUtxos']) {
    test('$code survives actual native exception mapping', () async {
      wallet.onBurn = () async => throw mapNativeBridgeException(
        PlatformException(code: code, message: '/secret/native/path'),
        operation: 'rlnBurn',
      );
      await expectLater(
        operations.execute(params, metadata, () {}),
        throwsA(isA<RgbSdkException>()),
      );
      final saved = (await operations.records()).single;
      expect(saved.state, BurnOperationState.cancelled);
      expect(saved.error, code);
    });
    test('$code cancels only a proven pre-broadcast failure', () async {
      wallet.onBurn = () async =>
          throw WalletException('/secret/path', code: code);
      await expectLater(
        operations.execute(params, metadata, () {}),
        throwsA(isA<WalletException>()),
      );
      final record = (await operations.records()).single;
      expect(record.state, BurnOperationState.cancelled);
      expect(record.error, code);
      expect(jsonEncode(record.toJson()), isNot(contains('/secret/path')));
      final restarted = BurnTestWallet();
      await BurnOperations(restarted, store).execute(params, metadata, () {});
      expect(restarted.calls, 1);
    });

    test(
      '$code from persistence after native result must never cancel',
      () async {
        store.beforeWrite = (record) async {
          if (record.state == BurnOperationState.complete) {
            throw WalletException('storage failure', code: code);
          }
        };
        await expectLater(
          operations.execute(params, metadata, () {}),
          throwsA(isA<WalletException>()),
        );
        expect(
          (await operations.records()).single.state,
          BurnOperationState.pending,
        );
        store.beforeWrite = null;
        await operations.retryPersistence();
        expect((await operations.records()).single.result!.txid, result.txid);
        expect(wallet.calls, 1);
      },
    );
  }

  test('journal error roundtrips but malformed error fails closed', () async {
    final saved = await operations.execute(params, metadata, () {});
    expect(
      normalizeBurnRecord({...saved.toJson(), 'error': 'legacy'}).error,
      'legacy',
    );
    expect(
      () => normalizeBurnRecord({...saved.toJson(), 'error': 123}),
      throwsA(isA<WalletValidationException>()),
    );
  });

  for (final phase in [
    BurnOperationState.prepared,
    BurnOperationState.pending,
  ]) {
    for (final committed in [false, true]) {
      test(
        'failed $phase write (committed=$committed) never invokes native',
        () async {
          Future<void> fail(BurnOperationRecord record) async {
            if (record.state == phase) throw StateError('disk failure');
          }

          if (committed) {
            store.afterWrite = fail;
          } else {
            store.beforeWrite = fail;
          }
          await expectLater(
            operations.execute(params, metadata, () {}),
            throwsStateError,
          );
          expect(wallet.calls, 0);
          expect(
            (await operations.records()).single.state,
            BurnOperationState.cancelled,
          );
        },
      );
    }
    test('revocation during $phase write cancels before dispatch', () async {
      var allowed = true;
      store.afterWrite = (record) async {
        if (record.state == phase) allowed = false;
      };
      await expectLater(
        operations.execute(params, metadata, () {
          if (!allowed) throw StateError('revoked');
        }),
        throwsStateError,
      );
      expect(wallet.calls, 0);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.cancelled,
      );
    });
  }

  test(
    'complete persistence failure keeps result without retrying native',
    () async {
      store.beforeWrite = (record) async {
        if (record.state == BurnOperationState.complete) {
          throw StateError('disk failure');
        }
      };
      await expectLater(
        operations.execute(params, metadata, () {}),
        throwsStateError,
      );
      await expectLater(
        operations.execute(params, metadata, () {}),
        throwsStateError,
      );
      expect(wallet.calls, 1);
      store.beforeWrite = null;
      await operations.retryPersistence();
      expect(
        (await operations.records()).single.state,
        BurnOperationState.complete,
      );
      expect(wallet.calls, 1);
    },
  );

  test('prepared restart cancels safely, pending never auto-cancels', () async {
    await store.write(
      const BurnOperationRecord(
        id: 'prepared',
        params: params,
        metadata: metadata,
        state: BurnOperationState.prepared,
      ),
    );
    await store.write(
      const BurnOperationRecord(
        id: 'pending',
        params: params,
        metadata: metadata,
        state: BurnOperationState.pending,
      ),
    );
    await operations.retryPersistence();
    expect((await operations.records()).map((r) => r.state), [
      BurnOperationState.cancelled,
      BurnOperationState.pending,
    ]);
    expect(wallet.calls, 0);
  });

  test(
    'reconciliation needs burn history AND independently verified proof',
    () async {
      await store.write(
        const BurnOperationRecord(
          id: 'pending',
          params: params,
          metadata: metadata,
          state: BurnOperationState.pending,
        ),
      );
      wallet.kind = 'Send';
      var verified = false;
      Future<bool> verify(
        BurnOperationRecord r,
        BurnResult native,
        String proof,
      ) async {
        verified = true;
        expect(r.params.amount, params.amount);
        expect(native.txid, result.txid);
        expect(proof, 'cHJvb2Y=');
        return true;
      }

      await expectLater(
        operations.reconcile('pending', result, verify),
        throwsA(isA<WalletException>()),
      );
      expect(verified, false);
      wallet.kind = 'Burn';
      await expectLater(
        operations.reconcile('pending', result, (_, _, _) async => false),
        throwsA(isA<WalletException>()),
      );
      expect(
        (await operations.records()).single.state,
        BurnOperationState.pending,
      );
      await operations.reconcile('pending', result, verify);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.complete,
      );
      expect(wallet.calls, 0);
    },
  );

  test(
    'legacy journal preserves ID and encodes payout without precision loss',
    () {
      final legacy = normalizeBurnRecord({
        'origin': metadata.origin,
        'request': {
          'requestId': 'old',
          'network': metadata.network,
          'assetId': params.assetId,
          'amount': params.amount,
          'burnRecipient': {
            'chainId': metadata.payout.chainId,
            'address': metadata.payout.address,
          },
        },
        'state': 'pending',
      });
      expect(legacy.id, 'old');
      expect(legacy.params.burnRecipient, '${'0' * 24}${'12' * 20}');
      expect(legacy.toJson()['version'], 2);
    },
  );

  test(
    'corrupt or future journal formats fail closed with typed validation',
    () {
      final valid = const BurnOperationRecord(
        id: 'id',
        params: params,
        metadata: metadata,
        state: BurnOperationState.pending,
      ).toJson();
      for (final bad in [
        null,
        <String, Object?>{},
        {...valid, 'version': 3},
        {...valid, 'state': 'complete'},
        {
          ...valid,
          'params': {
            ...valid['params']! as Map<String, Object?>,
            'burnRecipient': 4,
          },
        },
      ]) {
        expect(() => normalizeBurnRecord(bad), throwsA(isA<RgbSdkException>()));
      }
    },
  );

  test(
    'missing payout commitment fails before journal writes or burning',
    () async {
      const missing = BurnParams(
        assetId: 'rgb:asset',
        amount: '1',
        feeRate: 2,
        minConfirmations: 3,
      );
      await expectLater(
        operations.execute(missing, metadata, () {}),
        throwsA(isA<WalletValidationException>()),
      );
      expect(wallet.calls, 0);
      expect(store.writes, isEmpty);

      final record = const BurnOperationRecord(
        id: 'uncertain',
        params: params,
        metadata: metadata,
        state: BurnOperationState.pending,
      ).toJson();
      for (final commitment in [null, '34' * 32]) {
        store.data['uncertain'] = {
          ...record,
          'params': {
            ...record['params']! as Map<String, Object?>,
            'burnRecipient': commitment,
          },
        };
        await expectLater(
          operations.execute(params, metadata, () {}),
          throwsA(isA<WalletValidationException>()),
        );
        expect(wallet.calls, 0);
        expect(store.data, hasLength(1));
        expect(store.writes, isEmpty);
      }
    },
  );

  test(
    'burn input boundaries reject overflow, rounding and malformed recipient',
    () {
      params.validate();
      for (final amount in [
        '0',
        '-1',
        '01',
        '1.5',
        '18446744073709551616',
        '1e3',
      ]) {
        expect(
          () => BurnParams(
            assetId: params.assetId,
            amount: amount,
            feeRate: 2,
            minConfirmations: 3,
          ).validate(),
          throwsA(isA<WalletValidationException>()),
        );
      }
      for (final fee in [0, 9007199254740992]) {
        expect(
          () => BurnParams(
            assetId: params.assetId,
            amount: '1',
            feeRate: fee,
            minConfirmations: 3,
          ).validate(),
          throwsA(isA<WalletValidationException>()),
        );
      }
      for (final confirmations in [0, 256]) {
        expect(
          () => BurnParams(
            assetId: params.assetId,
            amount: '1',
            feeRate: 2,
            minConfirmations: confirmations,
          ).validate(),
          throwsA(isA<WalletValidationException>()),
        );
      }
    },
  );
}
