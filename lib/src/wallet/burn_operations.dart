import 'dart:math';

import '../errors/native_bridge_error_mapper.dart';
import '../errors/rgb_sdk_exception.dart';
import '../models/burn_models.dart';
import '../models/utexo_core_models.dart';
import 'burn_destination.dart';
import 'burn_recipient.dart';
import 'rgb_lib/config.dart' show RgbLibWalletException;

/// Narrow wallet boundary for irreversible burn execution and proof recovery.
abstract interface class BurnWallet {
  Future<BurnResult> burn(BurnParams params);
  Future<List<CoreTransfer>> listTransfers({String? assetId});
  Future<String> getConsignment(String assetId, String txid);
}

/// A wallet that can reject unsupported burns before creating a journal entry.
abstract interface class BurnCapabilityWallet implements BurnWallet {
  Future<BfaCapabilities> getBfaCapabilities();
}

/// Durable journal states, not RGB transfer or external payout statuses.
enum BurnOperationState { prepared, pending, complete, cancelled }

/// Host-approved payout destination. The chain ID is policy, not native data.
class BurnPayout {
  const BurnPayout({required this.chainId, required this.address});
  final String chainId;
  final String address;
}

/// Wallet-owned context retained across dApp sessions and process restarts.
class BurnOperationMetadata {
  const BurnOperationMetadata({
    required this.origin,
    required this.network,
    required this.payout,
    this.burnDestination,
  });
  final String origin;
  final String network;
  final BurnPayout payout;
  final BurnDestination? burnDestination;
}

/// Immutable v2 journal record. IDs are private wallet identities, not dApp IDs.
class BurnOperationRecord {
  const BurnOperationRecord({
    required this.id,
    required this.params,
    required this.metadata,
    required this.state,
    this.result,
    this.error,
  });
  final String id;
  final BurnParams params;
  final BurnOperationMetadata metadata;
  final BurnOperationState state;
  final BurnResult? result;

  /// Sanitized failure code for newly written records; never a native payload.
  /// Legacy RN records may contain messages. Do not log or expose this to dApps.
  final String? error;

  BurnOperationRecord withState(
    BurnOperationState state, {
    BurnResult? result,
    String? error,
  }) => BurnOperationRecord(
    id: id,
    params: params,
    metadata: metadata,
    state: state,
    result: result ?? this.result,
    error: error ?? this.error,
  );

  /// Storage shape compatible with the RN v2 journal. Never send it to a dApp.
  Map<String, Object?> toJson() => {
    'version': 2,
    'id': id,
    'params': {
      'assetId': params.assetId,
      'amount': params.amount,
      if (params.burnRecipient != null) 'burnRecipient': params.burnRecipient,
      'feeRate': params.feeRate,
      'minConfirmations': params.minConfirmations,
    },
    'metadata': {
      'origin': metadata.origin,
      'network': metadata.network,
      'payout': {
        'chainId': metadata.payout.chainId,
        'address': metadata.payout.address,
      },
      if (metadata.burnDestination case final destination?)
        'burnDestination': destination.toJson(),
    },
    'state': state.name,
    if (error != null) 'error': error,
    if (result != null)
      'result': {
        'txid': result!.txid,
        'batchTransferIdx': result!.batchTransferIdx,
      },
  };
}

/// App-owned, wallet-scoped durable storage. No in-memory production default.
///
/// [write] must resolve only after an atomic durable upsert by record ID.
/// A rejected write may already have reached disk. Use the same store object
/// for every service/session around a wallet; never discard pending records.
/// Only one process/isolate may own the wallet and its store at a time.
abstract interface class BurnOperationStore {
  Future<List<Object?>> readAll();
  Future<void> write(BurnOperationRecord record);
}

Map<Object?, Object?> _object(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  throw const WalletValidationException(
    'Invalid burn journal record.',
    field: 'journal',
  );
}

String _string(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  throw const WalletValidationException(
    'Invalid burn journal string.',
    field: 'journal',
  );
}

int _integer(Object? value) {
  if (value is int) return value;
  throw const WalletValidationException(
    'Invalid burn journal integer.',
    field: 'journal',
  );
}

/// Strictly reads v2 records and upgrades RN's legacy v1 shape in memory.
///
/// Unknown versions and corrupt records fail closed; a corrupt pending record
/// must not silently vanish and permit a second burn.
BurnOperationRecord normalizeBurnRecord(Object? value) {
  final raw = _object(value);
  if (raw['error'] != null && raw['error'] is! String) {
    throw const WalletValidationException(
      'Invalid burn journal error.',
      field: 'error',
    );
  }
  final version = raw['version'];
  if (version != null && version != 1 && version != 2) {
    throw const WalletValidationException(
      'Unsupported burn journal version.',
      field: 'version',
    );
  }
  final legacy = version != 2;
  final params = _object(raw[legacy ? 'request' : 'params']);
  final metadata = legacy ? raw : _object(raw['metadata']);
  final payout = _object(legacy ? params['burnRecipient'] : metadata['payout']);
  final chainId = _string(payout['chainId']);
  final address = _string(payout['address']);
  final destination = !legacy && metadata.containsKey('burnDestination')
      ? BurnDestination.fromJson(metadata['burnDestination'])
      : null;
  destination?.validatePayout(chainId, address);
  final encoded =
      destination?.commitment ?? encodeBurnRecipient(chainId, address);
  final request = BurnParams(
    assetId: _string(params['assetId']),
    amount: _string(params['amount']),
    burnRecipient: legacy ? encoded : _string(params['burnRecipient']),
    feeRate: _integer(params['feeRate'] ?? (legacy ? 2 : null)),
    minConfirmations: _integer(
      params['minConfirmations'] ?? (legacy ? 3 : null),
    ),
  );
  request.validate();
  if (request.burnRecipient!.toLowerCase() != encoded) {
    throw const WalletValidationException(
      'Burn recipient and payout differ.',
      field: 'payout',
    );
  }
  final states = BurnOperationState.values.where(
    (state) => state.name == raw['state'],
  );
  if (states.isEmpty) {
    throw const WalletValidationException(
      'Invalid burn journal state.',
      field: 'state',
    );
  }
  final result = raw['result'] == null
      ? null
      : BurnResult.fromMap(_object(raw['result']));
  if (states.single == BurnOperationState.complete && result == null) {
    throw const WalletValidationException(
      'Completed burn is missing its result.',
      field: 'result',
    );
  }
  return BurnOperationRecord(
    id: _string(legacy ? params['requestId'] : raw['id']),
    params: request,
    metadata: BurnOperationMetadata(
      origin: _string(metadata['origin']),
      network: _string(legacy ? params['network'] : metadata['network']),
      payout: BurnPayout(chainId: chainId, address: address),
      burnDestination: destination,
    ),
    state: states.single,
    result: result,
    error: raw['error'] as String?,
  );
}

class _BurnRuntime {
  _BurnRuntime(this.store);
  final BurnOperationStore store;
  Future<void> queue = Future<void>.value();
  final Map<String, BurnOperationRecord> unsaved = {};
}

/// Durable, non-retrying execution of irreversible burns.
///
/// One queue and journal owner exist per wallet object. Pending outcomes block
/// every subsequent burn until independently reconciled, including after a
/// restart. A known native result survives write failure in memory so retrying
/// persistence never repeats the native mutation.
class BurnOperations {
  BurnOperations(this._wallet, BurnOperationStore store) {
    final existing = _runtimes[_wallet];
    if (existing != null && !identical(existing.store, store)) {
      throw const ConfigurationError('Use one durable burn store per wallet.');
    }
    _runtime = existing ?? _BurnRuntime(store);
    _runtimes[_wallet] = _runtime;
  }
  static final Expando<_BurnRuntime> _runtimes = Expando<_BurnRuntime>();
  final BurnWallet _wallet;
  late final _BurnRuntime _runtime;

  /// Prevents a session from binding another wallet's irreversible journal.
  bool belongsTo(BurnWallet wallet) => identical(wallet, _wallet);

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final next = _runtime.queue.then((_) => action());
    _runtime.queue = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<List<BurnOperationRecord>> _read() async {
    final records = (await _runtime.store.readAll())
        .map(normalizeBurnRecord)
        .toList();
    if (records.map((record) => record.id).toSet().length != records.length) {
      throw const WalletException(
        'Burn journal contains duplicate identities.',
      );
    }
    return List.unmodifiable(records);
  }

  /// Returns validated records without racing a journal write.
  Future<List<BurnOperationRecord>> records() => _exclusive(_read);

  Future<void> _save(BurnOperationRecord record) async {
    _runtime.unsaved[record.id] = record;
    await _runtime.store.write(record);
    _runtime.unsaved.remove(record.id);
  }

  Future<void> _flush() async {
    for (final record in List<BurnOperationRecord>.of(
      _runtime.unsaved.values,
    )) {
      await _save(record);
    }
    for (final record in await _read()) {
      // A durable pending write is required before native invocation; a record
      // still prepared after restart therefore cannot represent a dispatched burn.
      if (record.state == BurnOperationState.prepared) {
        await _save(record.withState(BurnOperationState.cancelled));
      }
    }
  }

  /// Flushes known results and cancels undispatched preparations; never burns.
  Future<void> retryPersistence() => _exclusive(_flush);

  /// Checks authorization immediately before each durable/native transition.
  Future<BurnOperationRecord> execute(
    BurnParams params,
    BurnOperationMetadata metadata,
    void Function() assertAuthorized,
  ) => _exclusive(() async {
    params.validate();
    await _flush();
    if ((await _read()).any(
      (record) => record.state == BurnOperationState.pending,
    )) {
      throw const WalletError(
        'A previous burn has an unresolved outcome.',
        code: 'BURN_OUTCOME_UNRESOLVED',
      );
    }
    assertAuthorized();
    final wallet = _wallet;
    if (wallet is BurnCapabilityWallet &&
        !(await wallet.getBfaCapabilities()).burn) {
      throw const UnsupportedWalletFeatureException(
        'Burn is unsupported by this native build or signer.',
        feature: 'burn',
      );
    }
    assertAuthorized();
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    var record = normalizeBurnRecord(
      BurnOperationRecord(
        id: id,
        params: params,
        metadata: metadata,
        state: BurnOperationState.prepared,
      ).toJson(),
    );
    var invoked = false;
    var nativeReturned = false;
    try {
      await _save(record);
      assertAuthorized();
      record = record.withState(BurnOperationState.pending);
      await _save(record);
      assertAuthorized();
      invoked = true;
      final result = await _wallet.burn(params);
      nativeReturned = true;
      result.validate();
      record = record.withState(BurnOperationState.complete, result: result);
      await _save(record);
      return record;
    } catch (error, stack) {
      // Only recognized funding or capability refusals prove non-submission.
      // An invalid returned result or timeout is still an uncertain mutation.
      final cause = error is RgbSdkException ? error.cause : null;
      final nativeCode = cause is NativeBridgeFailure
          ? cause.operation == 'rlnBurn'
                ? cause.nativeCode
                : null
          : error is RgbSdkException
          ? error.code
          : null;
      final refusedBeforeBroadcast =
          !nativeReturned &&
          (const {
                'InsufficientFunds',
                'NoAvailableUtxos',
              }.contains(nativeCode) ||
              (error is RgbLibWalletException &&
                  nativeCode == 'UNSUPPORTED_CAPABILITY') ||
              (error is UnsupportedWalletFeatureException &&
                  error.feature == 'burn'));
      if (record.state != BurnOperationState.complete) {
        final cancelled = !invoked || refusedBeforeBroadcast;
        try {
          await _save(
            record.withState(
              cancelled
                  ? BurnOperationState.cancelled
                  : BurnOperationState.pending,
              error: invoked
                  ? refusedBeforeBroadcast
                        ? nativeCode
                        : 'BURN_OUTCOME_UNRESOLVED'
                  : null,
            ),
          );
        } catch (persistenceError) {
          Error.throwWithStackTrace(
            WalletException(
              'Burn journal recovery still needs persistence.',
              cause: [error, persistenceError],
            ),
            stack,
          );
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  });

  /// Wallet-only recovery; never authorizes a repeat burn.
  ///
  /// [verify] must independently decode/check the saved proof's asset, amount,
  /// recipient and native result. A matching txid is not sufficient. The pinned
  /// native API has no such decoder; the host must provide a real verifier.
  Future<void> reconcile(
    String id,
    BurnResult result,
    Future<bool> Function(BurnOperationRecord, BurnResult, String) verify,
  ) => _exclusive(() async {
    await _flush();
    final matches = (await _read()).where((item) => item.id == id);
    if (matches.isEmpty || matches.single.state != BurnOperationState.pending) {
      throw const WalletException('No unresolved burn with this ID.');
    }
    final record = matches.single;
    result.validate();
    final transfers = await _wallet.listTransfers(
      assetId: record.params.assetId,
    );
    if (!transfers.any(
      (item) => item.kind == 'Burn' && item.txid == result.txid,
    )) {
      throw const WalletException(
        'The transaction is not a burn of this asset.',
      );
    }
    final proof = await _wallet.getConsignment(
      record.params.assetId,
      result.txid,
    );
    if (proof.isEmpty || !await verify(record, result, proof)) {
      throw const WalletException(
        'Burn proof does not match the saved operation.',
      );
    }
    await _save(record.withState(BurnOperationState.complete, result: result));
  });
}
