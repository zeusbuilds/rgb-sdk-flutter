import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../errors/rgb_sdk_exception.dart';
import '../../models/burn_models.dart';
import '../../models/utexo_core_models.dart';
import '../burn_operations.dart';
import '../dev_signet_policy.dart';
import '../utexo_wallet_types.dart';
import 'config.dart';
import 'wire.dart';

part 'operation_inputs.dart';

/// Native RGB_L1 Bitcoin and RGB wallet, independent of the legacy RLN wallet.
///
/// All calls on one wallet execute in order. Native owns the exclusive storage
/// claim. Use [destroy] when the object will no longer be used. A mnemonic
/// reader should only read keys and must not call this wallet from inside init.
final class RgbLibWallet implements BurnCapabilityWallet {
  RgbLibWallet({required this.params, required RgbLibKeys keys})
    : _keys = keys {
    validateRgbLibWalletParams(params);
    keys.publicKeys?.validate(params.network);
  }

  final RgbLibWalletParams params;
  final RgbLibKeys _keys;

  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _disposeRequested = false;
  bool _disposed = false;
  bool _closeRequired = false;
  String? _handle;
  RgbLibWalletIdentity? _identity;
  RgbLibOnlineConfig? _online;
  RgbLibRuntimeInfo? _runtime;

  String get protocol => 'RGB_L1';
  String get network => params.network;
  String getNetwork() => network;
  bool get watchOnly => _keys.readMnemonic == null;
  bool isDisposed() => _disposed;

  /// One-shot native sends do not supply a durable payment recovery protocol.
  bool get supportsRecoverableOnchainSend => false;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _accept<T>(Future<T> Function() action) {
    if (_disposeRequested) {
      return Future.error(
        const RgbLibWalletException(
          'This wallet session has been disposed.',
          code: 'WALLET_DISPOSED',
        ),
      );
    }
    if (_closing != null || _closeRequired) {
      return Future.error(
        const RgbLibWalletException(
          'Wallet cleanup is in progress or must be retried.',
          code: 'WALLET_STOPPING',
        ),
      );
    }
    return _enqueue(() {
      if (_closeRequired) {
        throw const RgbLibWalletException(
          'Wallet cleanup must be retried.',
          code: 'WALLET_STOPPING',
        );
      }
      return action();
    });
  }

  /// Reads and verifies native artifact provenance without opening a wallet.
  static Future<RgbLibRuntimeInfo> getRuntimeInfo() async {
    final row = RgbLibWire(await _invoke('getRuntimeInfo'), 'runtime');
    final info = RgbLibRuntimeInfo(
      version: row.text('version'),
      sourceRevision: row.text('sourceRevision'),
      bridgeVersion: row.integer('bridgeVersion'),
      capabilities: BfaCapabilities.fromMap(row.map),
    );
    if (info.version != RgbLibRuntimeInfo.expectedVersion ||
        info.sourceRevision != RgbLibRuntimeInfo.expectedSourceRevision ||
        info.bridgeVersion != RgbLibRuntimeInfo.expectedBridgeVersion) {
      throw const RgbLibWalletException(
        'The RGB_L1 native artifacts do not match this SDK.',
        code: 'NATIVE_VERSION_MISMATCH',
      );
    }
    return info;
  }

  /// Opens a native session. No network connection is required.
  Future<void> init() => _accept(_open);
  Future<void> initialize() => init();

  Future<void> _open() async {
    if (_identity != null) return;
    requireQualifiedUtexoDevSignet(customSignetProfile: network == 'utexo');
    final runtime = await getRuntimeInfo();
    final readMnemonic = _keys.readMnemonic;
    String? mnemonic;
    if (readMnemonic != null) {
      try {
        mnemonic = (await readMnemonic())?.trim();
      } catch (_) {
        throw const RgbLibWalletException(
          'Could not read wallet keys.',
          code: 'KEYS_UNAVAILABLE',
        );
      }
      if (mnemonic == null || mnemonic.isEmpty) {
        throw const RgbLibWalletException(
          'Wallet keys are unavailable.',
          code: 'KEYS_UNAVAILABLE',
        );
      }
    }
    final keys = _keys.publicKeys;
    final handle = _nonempty(
      await _invoke('openWallet', {
        'dataDir': params.storageDirPath,
        'network': network,
        'mnemonic': mnemonic,
        'accountXpubVanilla': keys?.accountXpubVanilla,
        'accountXpubColored': keys?.accountXpubColored,
        'masterFingerprint': keys?.masterFingerprint.toLowerCase(),
        'witnessVersion': params.witnessVersion.wireValue,
        'maxAllocationsPerUtxo': params.maxAllocationsPerUtxo,
        'reuseAddresses': params.reuseAddresses,
      }),
      'handle',
    );
    _handle = handle;
    try {
      final row = RgbLibWire(
        await _invoke('getWalletIdentity', {'handle': handle}),
        'identity',
      );
      final fingerprint = row.text('masterFingerprint').toLowerCase();
      if (row.text('network') != network ||
          !RegExp(r'^[a-f0-9]{8}$').hasMatch(fingerprint) ||
          (keys != null &&
              fingerprint != keys.masterFingerprint.toLowerCase())) {
        throw const RgbLibWalletException(
          'Native wallet identity does not match the profile.',
          code: 'WALLET_CONFIG_MISMATCH',
        );
      }
      _identity = RgbLibWalletIdentity(
        id: row.requiredText('id'),
        network: network,
        masterFingerprint: fingerprint,
      );
      _runtime = runtime;
    } catch (_) {
      _closeRequired = true;
      await _closeNative();
      rethrow;
    }
  }

  Future<RgbLibWalletIdentity> getWalletIdentity() =>
      _accept(() async => _requireIdentity());

  RgbLibWalletIdentity _requireIdentity() =>
      _identity ??
      (throw const RgbLibWalletException(
        'Call init before this wallet operation.',
        code: 'WALLET_NOT_INITIALIZED',
      ));

  /// Explicit configuration takes precedence over a later lazy connection.
  Future<void> goOnline([RgbLibUnlockParams? params]) =>
      unlock(params ?? RgbLibUnlockParams());

  Future<void> unlock(RgbLibUnlockParams params) => _accept(() async {
    _requireIdentity();
    await _connect(resolveRgbLibOnline(network, params));
  });

  Future<void> _connect(RgbLibOnlineConfig config) async {
    final previous = _online;
    if (previous != null) {
      if (previous.proxyEndpoint != config.proxyEndpoint ||
          jsonEncode(previous.nativeArguments) !=
              jsonEncode(config.nativeArguments)) {
        throw const RgbLibWalletException(
          'Restart the wallet to change its network configuration.',
          code: 'WALLET_CONFIG_MISMATCH',
        );
      }
      return;
    }
    await _invoke('goOnline', {'handle': _handle!, ...config.nativeArguments});
    _online = config;
  }

  Future<void> _ensureOnline() async {
    if (_online != null) return;
    if (getRgbLibNetworkDefaults(network) == null) {
      throw const RgbLibWalletException(
        'This network requires explicit online configuration.',
        code: 'WALLET_OFFLINE',
      );
    }
    await _connect(resolveRgbLibOnline(network, RgbLibUnlockParams()));
  }

  /// Opens a new session after shutdown and optionally connects it.
  Future<void> reinit([RgbLibUnlockParams? params]) => _accept(() async {
    if (_handle != null) {
      throw const RgbLibWalletException(
        'Shut down the current session before reopening.',
        code: 'WALLET_CONFIG_MISMATCH',
      );
    }
    final config = params == null ? null : resolveRgbLibOnline(network, params);
    await _open();
    if (config != null) await _connect(config);
  });

  /// Closes the native session without removing wallet data.
  Future<void> shutdown() => _close(terminal: false);

  /// Closes this session permanently. Wallet files remain on disk.
  Future<void> destroy() => _close(terminal: true);
  Future<void> dispose() => destroy();

  Future<void> _close({required bool terminal}) {
    if (terminal) _disposeRequested = true;
    if (_disposed) return Future.value();
    if (_closing case final closing?) return closing;
    final closing = _enqueue(() async {
      _closeRequired = true;
      await _closeNative();
      _disposed = _disposeRequested;
    }).whenComplete(() => _closing = null);
    return _closing = closing;
  }

  Future<void> _closeNative() async {
    final handle = _handle;
    if (handle != null) {
      try {
        await _invoke('closeWallet', {'handle': handle});
      } on RgbLibWalletException catch (error) {
        if (error.code != 'WALLET_NOT_INITIALIZED') rethrow;
      }
    }
    _handle = null;
    _identity = null;
    _online = null;
    _runtime = null;
    _closeRequired = false;
  }

  Future<T> _call<T>(
    String operation,
    T Function(Object? result) decode, {
    Map<String, Object?> arguments = const {},
    bool online = false,
    bool signing = false,
    bool burn = false,
    Map<String, Object?> Function(String proxy)? proxyArguments,
  }) => _accept(() async {
    _requireIdentity();
    if ((signing && watchOnly) ||
        (burn && _runtime?.capabilities.burn != true)) {
      throw const RgbLibWalletException(
        'This wallet cannot sign the requested operation.',
        code: 'UNSUPPORTED_CAPABILITY',
      );
    }
    if (online || proxyArguments != null) await _ensureOnline();
    return decode(
      await _invoke(operation, {
        'handle': _handle!,
        ...arguments,
        if (proxyArguments != null) ...proxyArguments(_online!.proxyEndpoint),
      }),
    );
  });

  /// Restore a native encrypted backup into an empty dedicated directory.
  ///
  /// Open the restored wallet with its matching keys and profile configuration.
  static Future<void> restoreFromBackup({
    required String backupFilePath,
    required String password,
    required String dataDir,
  }) async {
    _validateBackup(backupFilePath, password);
    if (!isAbsoluteRgbLibPath(dataDir)) {
      invalidRgbLibConfig('Restore requires an absolute destination path.');
    }
    await getRuntimeInfo();
    await _invoke('restoreBackup', {
      'backupPath': backupFilePath,
      'password': password,
      'dataDir': dataDir,
    });
  }

  Future<String> getAddress() => _address(rotate: false);
  Future<String> rotateVanillaAddress() => _address(rotate: true);

  Future<String> _address({required bool rotate}) => _call(
    'getAddress',
    (value) => _nonempty(value, 'address'),
    arguments: {'rotate': rotate},
  );

  Future<RgbLibNetworkInfo> getNetworkInfo() =>
      _call('getNetworkInfo', (value) {
        final row = RgbLibWire(value, 'networkInfo');
        if (row.text('network') != network) {
          invalidRgbLibWire('networkInfo.network');
        }
        return (
          network: network,
          blockHeight: row.map['blockHeight'] == null
              ? null
              : row.integer('blockHeight'),
        );
      }, online: true);

  Future<RgbLibIndexerCheck> checkIndexerUrl(String indexerUrl) async {
    requireQualifiedUtexoDevSignet(endpoints: [indexerUrl]);
    return _call('checkIndexerUrl', (value) {
      if (value is! String ||
          !{'esplora', 'electrum', 'bitcoind'}.contains(value)) {
        invalidRgbLibWire('indexerProtocol');
      }
      return (indexerProtocol: value);
    }, arguments: {'indexerUrl': indexerUrl});
  }

  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false}) => _call(
    'getBtcBalance',
    (value) {
      final row = RgbLibWire(value, 'btcBalance');
      return CoreBtcBalance(
        vanilla: row.child('vanilla').btcBalance,
        colored: row.child('colored').btcBalance,
      );
    },
    arguments: {'skipSync': skipSync},
    online: true,
  );

  Future<CoreAssetBalance> getAssetBalance(String assetId) => _call(
    'getAssetBalance',
    (value) => RgbLibWire(value, 'assetBalance').assetBalance,
    arguments: {'assetId': _assetId(assetId)},
  );

  Future<CoreListAssets> listAssets({
    List<RgbLibAssetSchema> filterAssetSchemas = const [],
  }) => _call(
    'listAssets',
    (value) {
      final assets = rgbLibRows(
        value,
        'assets',
      ).map((row) => row.asset).toList();
      return CoreListAssets(
        nia: assets.whereType<CoreAssetNia>().toList(),
        cfa: assets.whereType<CoreAssetCfa>().toList(),
        uda: assets.whereType<CoreAssetUda>().toList(),
        ifa: assets.whereType<CoreAssetIfa>().toList(),
        bfa: assets.whereType<CoreAssetBfa>().toList(),
      );
    },
    arguments: {
      'filterAssetSchemas': [
        for (final schema in filterAssetSchemas) schema.wireValue,
      ],
    },
  );

  Future<RgbLibAssetMetadata> getAssetMetadata(String assetId) => _call(
    'getAssetMetadata',
    (value) => RgbLibWire(value, 'assetMetadata').metadata,
    arguments: {'assetId': _assetId(assetId)},
  );

  Future<List<CoreUnspent>> listUnspents({bool skipSync = false}) => _call(
    'listUnspents',
    (value) => List.unmodifiable(
      rgbLibRows(value, 'unspents').map((row) => row.unspent),
    ),
    arguments: {'skipSync': skipSync},
    online: true,
  );

  Future<List<CoreTransaction>> listTransactions({bool skipSync = false}) =>
      _call(
        'listTransactions',
        (value) => List.unmodifiable(
          rgbLibRows(value, 'transactions').map((row) => row.transaction),
        ),
        arguments: {'skipSync': skipSync},
        online: true,
      );

  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async {
    final canonical = _validateTxid(txid);
    final transactions = await listTransactions(skipSync: skipSync);
    return List.unmodifiable(transactions.where((tx) => tx.txid == canonical));
  }

  @override
  Future<List<RgbLibTransfer>> listTransfers({String? assetId}) =>
      _listTransfers(assetId: assetId);

  Future<List<RgbLibTransfer>> listTransfersByTxid(String txid) =>
      _listTransfers(txid: _validateTxid(txid));

  Future<List<RgbLibTransfer>> listOnchainTransfers({String? assetId}) =>
      listTransfers(assetId: assetId);

  Future<List<RgbLibTransfer>> _listTransfers({
    String? assetId,
    String? txid,
  }) => _call(
    'listTransfers',
    (value) => List.unmodifiable(
      rgbLibRows(value, 'transfers').map((row) => row.transfer),
    ),
    arguments: {'assetId': _optionalAssetId(assetId), 'txid': txid},
  );

  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    int feeRate = 1,
    bool skipSync = false,
  }) => _call(
    'createUtxos',
    (value) => RgbLibWire({'num': value}, 'num').integer('num', max: 255),
    arguments: {
      'upTo': upTo,
      'num': num == null ? null : _range(num, 'num', 1, 255),
      'size': size == null ? null : _range(size, 'size', 1, 0xffffffff),
      'feeRate': _feeRate(feeRate),
      'skipSync': skipSync,
    },
    online: true,
    signing: true,
  );

  /// Submits a Bitcoin payment once. A transport failure may leave the outcome
  /// unknown. Do not automatically repeat the call.
  Future<String> sendBtc({
    required String address,
    required int amount,
    required int feeRate,
    bool skipSync = false,
  }) => _call(
    'sendBtc',
    _txid,
    arguments: {
      'address': _required(address, 'address'),
      'amount': _range(amount, 'amount', 1, 2100000000000000).toString(),
      'feeRate': _feeRate(feeRate),
      'skipSync': skipSync,
    },
    online: true,
    signing: true,
  );

  Future<int> estimateFeeRate(int blocks) => _call(
    'estimateFeeRate',
    (value) {
      if (value is! num ||
          !value.isFinite ||
          value <= 0 ||
          value > _maxSafeInteger) {
        invalidRgbLibWire('feeRate');
      }
      return value.ceil();
    },
    arguments: {'blocks': _range(blocks, 'blocks', 1, 0xffff)},
    online: true,
  );

  Future<RgbLibReceiveData> blindReceive({
    String? assetId,
    BigInt? amount,
    int durationSeconds = 86400,
    int minConfirmations = 0,
    RgbLibReceiveAssignment? assignmentKind,
  }) => onchainReceive(
    witness: false,
    assetId: assetId,
    amount: amount,
    durationSeconds: durationSeconds,
    minConfirmations: minConfirmations,
    assignmentKind: assignmentKind,
  );

  Future<RgbLibReceiveData> witnessReceive({
    String? assetId,
    BigInt? amount,
    int durationSeconds = 86400,
    int minConfirmations = 0,
    RgbLibReceiveAssignment? assignmentKind,
  }) => onchainReceive(
    assetId: assetId,
    amount: amount,
    durationSeconds: durationSeconds,
    minConfirmations: minConfirmations,
    assignmentKind: assignmentKind,
  );

  Future<RgbLibReceiveData> onchainReceive({
    bool witness = true,
    String? assetId,
    BigInt? amount,
    int durationSeconds = 86400,
    int minConfirmations = 0,
    RgbLibReceiveAssignment? assignmentKind,
  }) {
    final kind =
        assignmentKind ??
        (amount == null
            ? RgbLibReceiveAssignment.any
            : RgbLibReceiveAssignment.fungible);
    if (kind.requiresAmount != (amount != null)) {
      throw const WalletValidationException(
        'The receive amount must match the assignment kind.',
        field: 'amount',
      );
    }
    final duration = _range(durationSeconds, 'durationSeconds', 1, 0xffffffff);
    return _call(
      'receive',
      (value) => RgbLibWire(value, 'receive').receive,
      arguments: {
        'witness': witness,
        'assetId': _optionalAssetId(assetId),
        'amount': amount == null
            ? null
            : rgbLibAmount(amount, 'amount', positive: true),
        'minConfirmations': _range(
          minConfirmations,
          'minConfirmations',
          0,
          255,
        ),
        'assignmentKind': kind.wireValue,
      },
      proxyArguments: (proxy) => {
        'transportEndpoints': [proxy],
        'expirationTimestamp':
            (DateTime.now().millisecondsSinceEpoch ~/ 1000 + duration)
                .toString(),
      },
    );
  }

  Future<RgbLibInvoiceData> decodeRgbInvoice(String invoice) => _call(
    'decodeInvoice',
    (value) => RgbLibWire(value, 'invoice').invoice(invoice),
    arguments: {'invoice': _required(invoice, 'invoice')},
  );

  /// Submits an RGB payment once, using the invoice's exact assignment.
  ///
  /// A transport failure may leave the outcome unknown. Do not automatically
  /// repeat the call. Durable recovery is a separate backend capability.
  Future<BurnResult> onchainSend({
    required String invoice,
    String? assetId,
    BigInt? amount,
    int? witnessAmountSat,
    BigInt? witnessBlinding,
    bool donation = false,
    required int feeRate,
    int minConfirmations = 1,
  }) {
    if (witnessBlinding != null && witnessAmountSat == null) {
      throw const WalletValidationException(
        'Witness blinding requires a Bitcoin output amount.',
        field: 'witnessAmountSat',
      );
    }
    return _call(
      'send',
      _operationResult,
      arguments: {
        'invoice': _required(invoice, 'invoice'),
        'assetId': _optionalAssetId(assetId),
        'amount': amount == null
            ? null
            : rgbLibAmount(amount, 'amount', positive: true),
        'witnessAmountSat': witnessAmountSat == null
            ? null
            : _range(
                witnessAmountSat,
                'witnessAmountSat',
                1,
                2100000000000000,
              ).toString(),
        'witnessBlinding': witnessBlinding == null
            ? null
            : rgbLibAmount(witnessBlinding, 'witnessBlinding'),
        'donation': donation,
        'feeRate': _feeRate(feeRate),
        'minConfirmations': _range(
          minConfirmations,
          'minConfirmations',
          1,
          255,
        ),
        'skipSync': false,
      },
      signing: true,
      proxyArguments: (proxy) => {'senderTransportEndpoint': proxy},
    );
  }

  Future<CoreAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<BigInt> amounts,
  }) => _issue('issueAssetNia', RgbLibAssetSchema.nia, {
    ..._assetName(name, precision),
    'ticker': _required(ticker, 'ticker'),
    'amounts': _issuanceAmounts(amounts, const []).issued,
  });

  Future<CoreAssetCfa> issueAssetCfa({
    required String name,
    String? details,
    required int precision,
    required List<BigInt> amounts,
    String? filePath,
  }) => _issue('issueAssetCfa', RgbLibAssetSchema.cfa, {
    ..._assetName(name, precision),
    'details': details,
    'amounts': _issuanceAmounts(amounts, const []).issued,
    'filePath': filePath == null ? null : rgbLibLocalFile(filePath),
  });

  Future<CoreAssetUda> issueAssetUda({
    required String ticker,
    required String name,
    String? details,
    required int precision,
    String? mediaFilePath,
    List<String> attachmentsFilePaths = const [],
  }) => _issue('issueAssetUda', RgbLibAssetSchema.uda, {
    ..._assetName(name, precision),
    'ticker': _required(ticker, 'ticker'),
    'details': details,
    'mediaFilePath': mediaFilePath == null
        ? null
        : rgbLibLocalFile(mediaFilePath),
    'attachmentsFilePaths': attachmentsFilePaths.map(rgbLibLocalFile).toList(),
  });

  Future<CoreAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<BigInt> amounts,
    required List<BigInt> inflationAmounts,
    required String rejectListUrl,
  }) {
    final supply = _issuanceAmounts(amounts, inflationAmounts);
    return _issue('issueAssetIfa', RgbLibAssetSchema.ifa, {
      ..._assetName(name, precision),
      'ticker': _required(ticker, 'ticker'),
      'amounts': supply.issued,
      'inflationAmounts': supply.inflation,
      'rejectListUrl': _required(rejectListUrl, 'rejectListUrl'),
    });
  }

  Future<T> _issue<T extends CoreAsset>(
    String operation,
    RgbLibAssetSchema schema,
    Map<String, Object?> arguments,
  ) => _call(operation, (value) {
    final row = RgbLibWire(value, 'asset');
    if (row.schema('schema') != schema) invalidRgbLibWire('asset.schema');
    return row.asset as T;
  }, arguments: arguments);

  Future<BurnResult> inflate({
    required String assetId,
    required List<BigInt> inflationAmounts,
    int feeRate = 1,
    int minConfirmations = 1,
  }) => _call(
    'inflate',
    _operationResult,
    arguments: {
      'assetId': _assetId(assetId),
      'amounts': _amountList(inflationAmounts, 'inflationAmounts'),
      'feeRate': _feeRate(feeRate),
      'minConfirmations': _range(minConfirmations, 'minConfirmations', 1, 255),
    },
    online: true,
    signing: true,
  );

  @override
  Future<BfaCapabilities> getBfaCapabilities() async {
    final capabilities = _runtime?.capabilities;
    final ready =
        capabilities != null &&
        !_disposeRequested &&
        _closing == null &&
        !_closeRequired;
    return BfaCapabilities(
      burn: ready && !watchOnly && capabilities.burn,
      consignment: ready && capabilities.consignment,
      bfa: ready && capabilities.bfa,
    );
  }

  @override
  Future<BurnResult> burn(BurnParams params) {
    params.validate();
    return _call(
      'burn',
      _operationResult,
      arguments: {
        'assetId': params.assetId,
        'amount': params.amount,
        'burnReason': params.burnRecipient,
        'feeRate': _feeRate(params.feeRate),
        'minConfirmations': params.minConfirmations,
      },
      online: true,
      signing: true,
      burn: true,
    );
  }

  @override
  Future<String> getConsignment(String assetId, String txid) =>
      _consignment('getConsignment', assetId, txid);

  Future<String> getConsignmentPath(String assetId, String txid) =>
      _consignment('getConsignmentPath', assetId, txid);

  Future<String> _consignment(String method, String assetId, String txid) {
    validateConsignmentLookup(assetId, txid);
    return _call(
      method,
      (value) => _nonempty(value, method),
      arguments: {'assetId': assetId, 'txid': txid.toLowerCase()},
    );
  }

  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) => _call(
    'failTransfers',
    _boolean,
    arguments: {
      ..._transferSelection(batchTransferIdx, noAssetOnly),
      'skipSync': skipSync,
    },
    online: true,
  );

  Future<bool> deleteTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
  }) => _call(
    'deleteTransfers',
    _boolean,
    arguments: _transferSelection(batchTransferIdx, noAssetOnly),
  );

  Future<String> drainTo({required String address, required int feeRate}) =>
      _call(
        'drainTo',
        _txid,
        arguments: {
          'address': _required(address, 'address'),
          'feeRate': _feeRate(feeRate),
        },
        online: true,
        signing: true,
      );

  Future<RefreshTransfersResult> refreshTransfers({bool skipSync = false}) =>
      _call(
        'refresh',
        (value) {
          final transfers = <int, RefreshedTransfer>{};
          for (final row in rgbLibRows(value, 'refresh')) {
            final index = row.integer('batchTransferIdx');
            if (transfers.containsKey(index)) {
              invalidRgbLibWire('batchTransferIdx');
            }
            transfers[index] = row.refreshedTransfer;
          }
          return RefreshTransfersResult(transfers: transfers);
        },
        arguments: {'skipSync': skipSync},
        online: true,
      );

  Future<void> refreshWallet() async {
    await refreshTransfers();
  }

  Future<void> syncWallet() => _call('sync', _void, online: true);

  Future<({String message, String backupPath})> createBackup({
    required String backupPath,
    required String password,
  }) {
    _validateBackup(backupPath, password);
    return _call('backup', (value) {
      _void(value);
      return (message: 'Backup created successfully', backupPath: backupPath);
    }, arguments: {'backupPath': backupPath, 'password': password});
  }
}

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');

Future<Object?> _invoke(
  String method, [
  Map<String, Object?> args = const {},
]) async {
  try {
    return await _channel.invokeMethod<Object?>(method, args);
  } on MissingPluginException {
    throw const RgbLibWalletException(
      'The RGB_L1 native backend is unavailable on this build.',
      code: 'NATIVE_BACKEND_UNAVAILABLE',
    );
  } on PlatformException catch (error) {
    // Native text can contain paths or RPC credentials. Preserve only known
    // symbolic codes and report a stable message to applications.
    final raw = error.code;
    final code = switch (raw) {
      'RGB_LIB_WatchOnly' => 'UNSUPPORTED_CAPABILITY',
      'RGB_LIB_AssetNotFound' => 'ASSET_NOT_FOUND',
      _ when raw.startsWith('RGB_LIB_Invalid') => 'INVALID_PARAMS',
      _ when raw.startsWith('RGB_LIB_Insufficient') => 'INSUFFICIENT_FUNDS',
      _ when _nativeCodes.contains(raw) => raw,
      _ => 'NATIVE_ERROR',
    };
    throw RgbLibWalletException('RGB_L1 operation failed.', code: code);
  }
}

const _nativeCodes = {
  'NATIVE_BACKEND_UNAVAILABLE',
  'WALLET_NOT_INITIALIZED',
  'WALLET_DISPOSED',
  'INVALID_CONFIG',
  'INVALID_PARAMS',
  'INVALID_NATIVE_RESPONSE',
  'WALLET_PROFILE_MISMATCH',
  'WALLET_STORAGE_IN_USE',
  'WALLET_STORAGE_NOT_EMPTY',
  'BACKUP_PROFILE_MISMATCH',
  'CONSIGNMENT_NOT_FOUND',
  'INVALID_CONSIGNMENT_PATH',
  'WALLET_OFFLINE',
};

String _nonempty(Object? value, String field) =>
    value is String && value.isNotEmpty ? value : invalidRgbLibWire(field);

String _txid(Object? value) => value is String && burnHex32.hasMatch(value)
    ? value.toLowerCase()
    : invalidRgbLibWire('txid');

void _validateBackup(String path, String password) {
  if (!isAbsoluteRgbLibPath(path) || password.isEmpty) {
    invalidRgbLibConfig(
      'Backup requires an absolute path and nonempty password.',
    );
  }
}
