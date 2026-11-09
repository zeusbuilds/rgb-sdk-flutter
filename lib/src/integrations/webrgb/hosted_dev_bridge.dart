part of 'walletconnect.dart';

const _bridgeAssetId = utexoDevBridgeAssetId;
const _directArbitrum = 'eip155:42161';
const _maxDevBurnFeeSats = 5000;
const _maxBurnHistoryChecks = 256;
const _maxPortableBurnProofBytes = 10 * 1024 * 1024;
const _bridgeInvalid = WebRgbError(
  'INVALID_PARAMS',
  'Invalid Dev bridge request.',
);
const _bridgeResponseInvalid = WebRgbError(
  'INTERNAL_ERROR',
  'Invalid native Dev bridge response.',
);
const _bridgeRecoveryRequired = WebRgbError(
  'INTERNAL_ERROR',
  'The original operation needs recovery.',
);

final class _HostedDevWebRgb {
  _HostedDevWebRgb(this.wallet, this.session, this.confirm);

  final RgbLibWallet wallet;
  final WebRgbWalletConnectSession session;
  final Future<bool> Function(WebRgbApproval) confirm;

  late final String _scopeKey = _bridgeScopeKey(
    session._grant.topic,
    session._grant.account,
  );

  Future<Object?> dispatch(
    String name,
    List<Object?> args,
    int id,
    String fingerprint,
    bool recoveryOnly,
  ) async {
    await _checkWallet();
    final provider = session._provider;
    switch (name) {
      case 'enable':
        await provider.enable();
        return null;
      case 'getInfo':
        final blind = await _blindReady();
        final methods = session
            ._currentGrant()!
            .methods
            .where(WebRgbWalletConnectSession.hostedDevMethods.contains)
            .where(session._grant.methods.contains)
            .map((method) => method.substring(4))
            .where((method) => method != 'blindReceive' || blind)
            .toList();
        return WebRgbInfo(
          network: 'utexo',
          protocol: 'RGB_L1',
          methods: methods,
          burnRecipientNamespaces: methods.contains('burnAsset')
              ? const ['eip155']
              : null,
          burnDestinationRoutes: methods.contains('burnAsset')
              ? [BurnDestinationRoute(chainId: _directArbitrum, dstEid: 0)]
              : const [],
        ).toJson();
      case 'getAddress':
        return (await provider.getAddress()).toJson();
      case 'blindReceive':
        return _receive(args, _binding(id, fingerprint), recoveryOnly);
      case 'listAssets':
        return (await provider.listAssets())
            .where(
              (asset) => asset.id == _bridgeAssetId && asset.schema == 'bfa',
            )
            .map((asset) => asset.toJson())
            .toList();
      case 'getAssetBalance':
        if (args.first != _bridgeAssetId) {
          throw const WebRgbError('ASSET_NOT_FOUND', 'Asset was not found.');
        }
        final balance = await provider.getAssetBalance(_bridgeAssetId);
        return {
          'assetId': balance.assetId,
          'balance': balance.balance,
          'raw': {'spendable': balance.balance},
        };
      case 'listTransfers':
        if (args.isNotEmpty) _requireBridgeAsset(args.first);
        return _listTransfers();
      case 'getTransferStatus':
        if (args.length == 2) _requireBridgeAsset(args[1]);
        return _transferStatus(args.first);
      case 'decodeRgbInvoice':
        final arg = args.first;
        final value = arg is String
            ? arg
            : _only(_object(arg), {'invoice'})['invoice'];
        final decoded = await provider.decodeRgbInvoice(_string(value));
        if (decoded.network != 'signet' ||
            !isUtexoDevSignetTransport(decoded.transportEndpoints) ||
            (decoded.assetId != null && decoded.assetId != _bridgeAssetId)) {
          throw _bridgeInvalid;
        }
        return decoded.toJson();
      case 'burnAsset':
        return _burn(
          _object(args.first),
          _binding(id, fingerprint),
          recoveryOnly,
        );
      case 'getConsignment':
        final input = _only(_object(args.first), {
          'assetId',
          'txid',
          'offset',
          'length',
        });
        _requireBridgeAsset(input['assetId']);
        final txid = _string(input['txid']).toLowerCase();
        if (!_bridgeHex64.hasMatch(txid)) throw _bridgeInvalid;
        return session._chunk({...input, 'txid': txid});
      default:
        throw const WebRgbError(
          'METHOD_NOT_SUPPORTED',
          'Unsupported Dev bridge method.',
        );
    }
  }

  Future<void> _checkWallet() async {
    session._check();
    if (!wallet.supportsHostedDevBridge) {
      throw const WebRgbError('NOT_ENABLED', 'The Dev wallet is unavailable.');
    }
    final identity = await webRgbWalletCall(wallet.getWalletIdentity);
    session._check();
    if (identity.network != 'utexo' ||
        session._grant.account != 'rgb:utexo:${identity.id}') {
      throw const WebRgbError(
        'NOT_ENABLED',
        'The session belongs to another wallet.',
      );
    }
  }

  Map<String, Object?> _binding(int id, String fingerprint) =>
      _bridgeBinding(_scopeKey, id, fingerprint);

  Future<bool> _blindReady() async {
    try {
      final ready = await wallet.hostedDevBridgeBlindReceiveReady();
      session._check();
      return ready;
    } on RgbLibWalletException {
      session._check();
      return false;
    }
  }

  Future<Map<String, Object?>?> _native(
    RgbLibHostedBridgeOperation operation,
    Map<String, Object?> request, {
    bool recoveryOnly = false,
  }) => webRgbWalletCall(
    () => wallet.hostedDevBridgeNative(
      operation,
      request,
      assertAuthorized: session._check,
      recoveryOnly: recoveryOnly,
    ),
  );

  Future<void> _confirm(String method, Map<String, Object?> params) async {
    session._check();
    final allowed = await confirm(
      WebRgbApproval(
        origin: session._grant.origin,
        method: method,
        params: params,
      ),
    );
    session._check();
    if (!allowed) throw const WebRgbError('USER_REJECTED', 'Request declined.');
  }

  Future<Map<String, Object?>> _receive(
    List<Object?> args,
    Map<String, Object?> binding,
    bool recoveryOnly,
  ) async {
    final input = args.isEmpty
        ? const <String, Object?>{}
        : _only(_object(args.first), {
            'assetId',
            'amount',
            'durationSeconds',
            'minConfirmations',
          });
    if (input.containsKey('assetId')) _requireBridgeAsset(input['assetId']);
    final amount = input.containsKey('amount')
        ? webRgbInteger(_optionalInteger(input['amount']) ?? 0, 'amount')
        : null;
    final duration = _bridgeInt(input, 'durationSeconds', 86400, 3600, 604800);
    final requested = _bridgeInt(input, 'minConfirmations', 3, 0, 255);
    final minimum = requested < 3 ? 3 : requested;
    final request = <String, Object?>{
      ...binding,
      'amount': amount?.toString(),
      'durationSeconds': duration,
      'minConfirmations': minimum,
      'transportEndpoint': utexoDevSignetProxy,
    };
    var value = await _native(
      RgbLibHostedBridgeOperation.blindReceive,
      request,
      recoveryOnly: true,
    );
    if (value == null) {
      if (recoveryOnly) throw _bridgeRecoveryRequired;
      if (!await _blindReady()) {
        throw const WebRgbError(
          'METHOD_NOT_SUPPORTED',
          'A confirmed RGB output is required.',
        );
      }
      await _confirm('blindReceive', {
        'assetId': _bridgeAssetId,
        'amount': ?amount,
        'durationSeconds': duration,
        'minConfirmations': minimum,
      });
      value = await _native(RgbLibHostedBridgeOperation.blindReceive, request);
    }
    final receipt = _checkBinding(value, binding);
    final invoice = receipt['invoice'];
    final recipientId = receipt['recipientId'];
    final expires = receipt['expirationTimestamp'];
    final timestamp =
        expires is String && RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(expires)
        ? int.tryParse(expires)
        : null;
    if (invoice is! String ||
        receipt['minConfirmations'] != minimum ||
        !invoice.startsWith('rgb:') ||
        invoice.length > 8192 ||
        recipientId is! String ||
        recipientId.isEmpty ||
        recipientId.length > 1024 ||
        timestamp == null ||
        timestamp <= session._now ||
        timestamp > 9007199254740991) {
      throw _bridgeResponseInvalid;
    }
    final decoded = await webRgbWalletCall(
      () => wallet.decodeRgbInvoice(invoice),
    );
    session._check();
    if (decoded.network != 'signet' ||
        decoded.recipientType != 'Blind' ||
        decoded.recipientId != recipientId ||
        decoded.assetId != _bridgeAssetId ||
        decoded.expirationTimestamp != timestamp ||
        !isUtexoDevSignetTransport(decoded.transportEndpoints) ||
        (amount == null
            ? decoded.assignment.type != 'Any' ||
                  decoded.assignment.amount != null
            : decoded.assignment.type != 'Fungible' ||
                  decoded.assignment.amount != BigInt.from(amount))) {
      throw _bridgeResponseInvalid;
    }
    return WebRgbBlindReceiveResult(
      invoice: invoice,
      recipientId: recipientId,
      expirationTimestamp: timestamp,
      minConfirmations: minimum,
    ).toJson();
  }

  Future<Map<String, Object?>> _burn(
    Map<String, Object?> input,
    Map<String, Object?> binding,
    bool recoveryOnly,
  ) async {
    final burn = await _parseHostedBurn(input);
    final (:amount, :payout, :destination, :rate, :minimum) = burn;
    final request = _bridgeBurnWire(binding, burn);
    final previous = await _native(
      RgbLibHostedBridgeOperation.observeBurn,
      request,
    );
    if (previous != null) {
      _checkBinding(previous, binding);
      if (previous['phase'] == 'accepted') {
        return _burnReply(previous, amount, payout, destination, minimum, rate);
      }
      if (recoveryOnly &&
          (previous['phase'] == 'prepared' ||
              previous['phase'] == 'preparing')) {
        final cancelled = _checkBinding(
          await _native(RgbLibHostedBridgeOperation.cancelBurn, request),
          binding,
        );
        if (cancelled['phase'] == 'rejected') {
          throw const WebRgbError(
            'BURN_NOT_SUBMITTED',
            'Burn was interrupted before submission.',
          );
        }
        if (cancelled['phase'] == 'accepted') {
          return _burnReply(
            cancelled,
            amount,
            payout,
            destination,
            minimum,
            rate,
          );
        }
      }
      if (previous['phase'] != 'prepared') throw _bridgeRecoveryRequired;
    }
    if (recoveryOnly) throw _bridgeRecoveryRequired;
    final prepared = _checkBinding(
      previous ??
          await _native(RgbLibHostedBridgeOperation.prepareBurn, request),
      binding,
    );
    if (prepared['phase'] != 'prepared') throw _bridgeResponseInvalid;
    var commitAttempted = false;
    try {
      final fee = _bridgeFee(prepared);
      await _confirm('burnAsset', {
        'network': 'utexo',
        'assetId': _bridgeAssetId,
        'amount': amount,
        'burnRecipient': payoutJson(payout),
        'burnDestination': destination.toJson(),
        'feeRate': rate,
        'feeSats': fee,
        'minConfirmations': minimum,
      });
      commitAttempted = true;
      final result = _checkBinding(
        await _native(RgbLibHostedBridgeOperation.commitBurn, request),
        binding,
      );
      if (_bridgeFee(result) != fee) throw _bridgeResponseInvalid;
      return _burnReply(result, amount, payout, destination, minimum, rate);
    } finally {
      if (!commitAttempted) {
        // Cancelling this exact native prepare does not sign or broadcast.
        // If the wallet is closing, retain the native fence for inspection.
        try {
          await wallet.hostedDevBridgeNative(
            RgbLibHostedBridgeOperation.cancelBurn,
            request,
            assertAuthorized: () {},
          );
        } on RgbLibWalletException {
          // The retained operation remains authoritative across restart.
        }
      }
    }
  }

  Map<String, Object?> _burnReply(
    Map<String, Object?> result,
    String amount,
    BurnPayout payout,
    BurnDestination destination,
    int minimum,
    int rate,
  ) {
    final txid = result['txid'];
    final details = _acceptedBurn(result);
    if (txid is! String ||
        !_bridgeHex64.hasMatch(txid) ||
        details.amount.toString() != amount ||
        details.payout.address != payout.address ||
        details.destination.commitment != destination.commitment ||
        details.minimum != minimum ||
        details.rate != rate) {
      throw _bridgeResponseInvalid;
    }
    return {
      ...WebRgbBurnAssetResult(
        txid: txid,
        assetId: _bridgeAssetId,
        amount: amount,
        burnRecipient: payout,
        burnDestination: destination,
        minConfirmations: minimum,
      ).toJson(),
      'network': 'utexo',
    };
  }

  Map<String, Object?> _proofLookup(String txid) =>
      _bridgeLookup(_scopeKey, txid);

  Future<List<Map<String, Object?>>> _listTransfers() async {
    final rows = await webRgbWalletCall(
      () => wallet.listTransfers(assetId: _bridgeAssetId),
    );
    session._check();
    final burns = await _listScopedBurns(rows, _scopeKey, _native);
    return [
      for (final row in rows)
        if (row.kind != 'Burn')
          _publicBridgeTransfer(row).toJson()
        else if (burns[row.idx] case final burn?)
          burn.toJson(),
    ];
  }

  Future<Map<String, Object?>> _transferStatus(Object? id) async {
    if ((id is! String && id is! int) ||
        id.toString().isEmpty ||
        id.toString().length > 1024) {
      throw _bridgeInvalid;
    }
    final key = id.toString().toLowerCase();
    final observed = _bridgeHex64.hasMatch(key)
        ? await _native(
            RgbLibHostedBridgeOperation.observeBurn,
            _proofLookup(key),
          )
        : null;
    if (observed == null) {
      final status = await session._provider.getTransferStatus(
        id!,
        _bridgeAssetId,
      );
      if (status.transfer?.kind == 'Burn') {
        return const WebRgbTransferStatusResult(found: false).toJson();
      }
      return status.toJson();
    }
    final record = _checkBinding(observed, _proofLookup(key));
    final details = _acceptedBurn(record);
    final confirmations = record['confirmations'];
    if (confirmations != null &&
        (confirmations is! int ||
            confirmations < 0 ||
            confirmations > 0xffffffff)) {
      throw _bridgeResponseInvalid;
    }
    await webRgbWalletCall(wallet.refreshWallet);
    session._check();
    final transfers = await webRgbWalletCall(
      () => wallet.listTransfersByTxid(key),
    );
    session._check();
    final matches = transfers
        .where(
          (t) =>
              t.kind == 'Burn' &&
              t.txid == key &&
              t.batchTransferIdx == details.batch,
        )
        .toList();
    if (matches.length != 1 || matches.single.amount != details.amount) {
      throw _bridgeResponseInvalid;
    }
    final txs = await webRgbWalletCall(
      () => wallet.listTransactionsByTxid(key),
    );
    session._check();
    if (txs.length > 1) throw _bridgeResponseInvalid;
    final status = matches.single.status;
    final transfer = _scopedBurnTransfer(
      key,
      status,
      details,
      blockHeight: txs.isEmpty ? null : txs.single.confirmationTime?.height,
      confirmations: confirmations as int?,
    );
    return WebRgbTransferStatusResult(
      found: true,
      status: status,
      transfer: transfer,
    ).toJson();
  }

  Future<WebRgbGetConsignmentResult> proof(String assetId, String txid) async {
    _requireBridgeAsset(assetId);
    final result = await _readScopedProof(
      _scopeKey,
      txid,
      _native,
      beforeDisclosure: () =>
          _confirm('getConsignment', {'assetId': assetId, 'txid': txid}),
    );
    session._check();
    return result.proof;
  }
}

typedef _BridgeNativeCall =
    Future<Map<String, Object?>?> Function(
      RgbLibHostedBridgeOperation operation,
      Map<String, Object?> request, {
      bool recoveryOnly,
    });

Map<String, Object?> _bridgeLookup(String scope, String txid) => {
  'scopeKey': scope,
  'assetId': _bridgeAssetId,
  'txid': txid,
};

WebRgbTransfer _publicBridgeTransfer(RgbLibTransfer row) {
  final amount = row.amount;
  return WebRgbTransfer(
    assetId: _bridgeAssetId,
    transferId: row.idx,
    status: row.status,
    kind: row.kind,
    amount: amount == null || amount > BigInt.from(9007199254740991)
        ? null
        : webRgbAmount(amount),
    amountBaseUnits: row.amountBaseUnits,
    recipientId: row.recipientId,
    txid: row.txid,
  );
}

Future<Map<int, WebRgbTransfer>> _listScopedBurns(
  List<RgbLibTransfer> rows,
  String scope,
  _BridgeNativeCall native,
) async {
  final receipts = <String, _AcceptedBurn?>{};
  final transfers = <int, WebRgbTransfer>{};
  // Inspect recent candidates using only the native outbox, without indexer
  // calls or exposing burns created under another WalletConnect topic.
  final candidates =
      rows.where((row) => row.kind == 'Burn' && row.txid != null).toList()
        ..sort((a, b) => b.idx.compareTo(a.idx));
  for (final row in candidates.take(_maxBurnHistoryChecks)) {
    final txid = row.txid!;
    if (!receipts.containsKey(txid)) {
      final lookup = _bridgeLookup(scope, txid);
      final receipt = await native(
        RgbLibHostedBridgeOperation.observeBurn,
        lookup,
        recoveryOnly: true,
      );
      receipts[txid] = receipt == null
          ? null
          : _acceptedBurn(_checkBinding(receipt, lookup));
    }
    final details = receipts[txid];
    if (details != null &&
        row.batchTransferIdx == details.batch &&
        row.amount == details.amount) {
      transfers[row.idx] = _scopedBurnTransfer(txid, row.status, details);
    }
  }
  return transfers;
}

Future<({WebRgbGetConsignmentResult proof, BurnDestination destination})>
_readScopedProof(
  String scope,
  String txid,
  _BridgeNativeCall native, {
  required Future<void> Function() beforeDisclosure,
  int maxBytes = 16 * 1024 * 1024,
}) async {
  final request = _bridgeLookup(scope, txid);
  final observed = await native(
    RgbLibHostedBridgeOperation.observeBurn,
    request,
    recoveryOnly: true,
  );
  if (observed == null) throw _bridgeInvalid;
  final record = _checkBinding(observed, request);
  final details = _acceptedBurn(record);
  await beforeDisclosure();
  final result = _checkBinding(
    await native(RgbLibHostedBridgeOperation.burnProof, request),
    {
      ...request,
      for (final field in [
        'operationId',
        'requestKey',
        'recipientAddress',
        'destinationCommitment',
        'amount',
        'feeRate',
        'minConfirmations',
        'batchTransferIdx',
        'feeSats',
      ])
        field: record[field],
    },
  );
  final data = result['data'];
  final sha = result['sha256'];
  if (data is! String || sha is! String || !_bridgeHex64.hasMatch(sha)) {
    throw _bridgeResponseInvalid;
  }
  final proof = await _verifiedNativeProof(
    _bridgeAssetId,
    txid,
    data,
    sha,
    maxBytes,
  );
  return (proof: proof, destination: details.destination);
}

Future<String> _localBridgeScope(
  RgbLibWallet wallet,
  String topic,
  void Function() assertAuthorized,
) async {
  if (!_bridgeHex64.hasMatch(topic)) throw _bridgeInvalid;
  assertAuthorized();
  if (!wallet.supportsHostedDevBridge) {
    throw const WebRgbError('NOT_ENABLED', 'The Dev wallet is unavailable.');
  }
  final identity = await webRgbWalletCall(wallet.getWalletIdentity);
  assertAuthorized();
  if (identity.network != 'utexo') throw _bridgeInvalid;
  return _bridgeScopeKey(topic, 'rgb:utexo:${identity.id}');
}

_BridgeNativeCall _localBridgeNative(
  RgbLibWallet wallet,
  void Function() assertAuthorized,
) =>
    (operation, request, {bool recoveryOnly = false}) => webRgbWalletCall(
      () => wallet.hostedDevBridgeNative(
        operation,
        request,
        assertAuthorized: assertAuthorized,
        recoveryOnly: recoveryOnly,
      ),
    );

Future<List<WebRgbTransfer>> _listLocalHostedBurns(
  RgbLibWallet wallet,
  String topic,
  void Function() assertAuthorized,
) async {
  final scope = await _localBridgeScope(wallet, topic, assertAuthorized);
  final rows = await webRgbWalletCall(
    () => wallet.listTransfers(assetId: _bridgeAssetId),
  );
  assertAuthorized();
  final burns = await _listScopedBurns(
    rows,
    scope,
    _localBridgeNative(wallet, assertAuthorized),
  );
  assertAuthorized();
  return List.unmodifiable(burns.values);
}

Future<Map<String, Object?>> _exportLocalHostedBurn(
  RgbLibWallet wallet,
  String topic,
  String txid,
  void Function() assertAuthorized,
) async {
  if (!_bridgeHex64.hasMatch(txid)) throw _bridgeInvalid;
  final scope = await _localBridgeScope(wallet, topic, assertAuthorized);
  final result = await _readScopedProof(
    scope,
    txid,
    _localBridgeNative(wallet, assertAuthorized),
    beforeDisclosure: () async => assertAuthorized(),
    maxBytes: _maxPortableBurnProofBytes,
  );
  assertAuthorized();
  return {
    'format': 'utexo-burn',
    'version': 1,
    'consignment': {
      'encoding': 'base64',
      'byteLength': result.proof.byteLength,
      'data': result.proof.data,
    },
    'burnDestination': result.destination.toJson(),
  };
}

typedef _HostedBurn = ({
  String amount,
  BurnPayout payout,
  BurnDestination destination,
  int rate,
  int minimum,
});

Future<_HostedBurn> _parseHostedBurn(Map<String, Object?> input) async {
  _only(input, {
    'network',
    'assetId',
    'amount',
    'feeRate',
    'minConfirmations',
    'burnRecipient',
    'burnDestination',
  });
  if (input['network'] != 'utexo') throw _bridgeInvalid;
  _requireBridgeAsset(input['assetId']);
  final amount = _string(input['amount']);
  if (!_isBridgeAmount(amount)) throw _bridgeInvalid;
  final recipient = _only(_object(input['burnRecipient']), {
    'chainId',
    'address',
  });
  if (recipient['chainId'] != _directArbitrum) throw _bridgeInvalid;
  final payout = BurnPayout(
    chainId: _directArbitrum,
    address: _bridgePayoutAddress(recipient['address']),
  );
  final destination = await webRgbWalletCall(
    () async => BurnDestination.forPayout(
      BurnDestinationRoute(chainId: _directArbitrum, dstEid: 0),
      payout.address,
    ),
  );
  final supplied = _only(_object(input['burnDestination']), {
    'version',
    'destinationChainId',
    'dstEid',
    'recipient',
  });
  final candidate = await webRgbWalletCall(
    () async => BurnDestination.fromJson({
      ...supplied,
      'recipient': _bridgePayoutAddress(supplied['recipient']),
    }),
  );
  if (candidate.commitment != destination.commitment) throw _bridgeInvalid;
  final rate = _bridgeInt(input, 'feeRate', 2, 1, 1000);
  final requested = _bridgeInt(input, 'minConfirmations', 6, 1, 255);
  final minimum = requested < 6 ? 6 : requested;
  return (
    amount: amount,
    payout: payout,
    destination: destination,
    rate: rate,
    minimum: minimum,
  );
}

String _bridgePayoutAddress(Object? value) {
  final address = _string(value);
  if (!RegExp(r'^0x[0-9a-f]{40}$', caseSensitive: false).hasMatch(address) ||
      RegExp(r'^0x0{40}$', caseSensitive: false).hasMatch(address)) {
    throw _bridgeInvalid;
  }
  final body = address.substring(2);
  final lower = body.toLowerCase();
  if (body != lower && body != body.toUpperCase()) {
    final checksum = KeccakDigest(
      256,
    ).process(Uint8List.fromList(ascii.encode(lower)));
    for (var i = 0; i < body.length; i++) {
      final nibble = i.isEven ? checksum[i ~/ 2] >> 4 : checksum[i ~/ 2] & 15;
      final expected = nibble >= 8 ? lower[i].toUpperCase() : lower[i];
      if (body[i] != expected) throw _bridgeInvalid;
    }
  }
  return '0x$lower';
}

String _bridgeScopeKey(String topic, String account) => _bridgeHash([
  'aster-hosted-dev-webrgb-v1',
  utexoDevBridgeOrigin,
  topic,
  account,
]);

String _bridgeFingerprint(
  String chain,
  String method,
  int expiry,
  List<Object?> params,
) => _bridgeHash([chain, method, expiry, _canonicalBridgeJson(params)]);

Map<String, Object?> _bridgeBinding(String scope, int id, String fingerprint) =>
    {
      'operationId': _bridgeHash([scope, id]).substring(0, 32),
      'scopeKey': scope,
      'requestKey': fingerprint,
      'assetId': _bridgeAssetId,
    };

Map<String, Object?> _bridgeBurnWire(
  Map<String, Object?> binding,
  _HostedBurn burn,
) => {
  ...binding,
  'amount': burn.amount,
  'feeRate': burn.rate.toString(),
  'minConfirmations': burn.minimum,
  'recipientAddress': burn.payout.address,
  'destinationCommitment': burn.destination.commitment,
};

Future<bool> _cancelLocalHostedBurn(
  RgbLibWallet wallet,
  String topic,
  int id,
  int expiry,
  List<Object?> params,
  void Function() assertAuthorized,
) async {
  if (params.length != 1) throw _bridgeInvalid;
  webRgbInteger(id, 'id', min: 0);
  webRgbInteger(expiry, 'expiry');
  final encoded = jsonEncode(params);
  if (utf8.encode(encoded).length > 65536) throw _bridgeInvalid;
  final frozen = jsonDecode(encoded) as List<Object?>;
  final burn = await _parseHostedBurn(_object(frozen.single));
  final scope = await _localBridgeScope(wallet, topic, assertAuthorized);
  final fingerprint = _bridgeFingerprint(
    'rgb:utexo',
    'rgb_burnAsset',
    expiry,
    frozen,
  );
  final binding = _bridgeBinding(scope, id, fingerprint);
  final request = _bridgeBurnWire(binding, burn);
  final native = _localBridgeNative(wallet, assertAuthorized);
  final observed = await native(
    RgbLibHostedBridgeOperation.observeBurn,
    request,
    recoveryOnly: true,
  );
  if (observed == null) return true;
  final phase = _checkBinding(observed, binding)['phase'];
  if (phase == 'rejected') return true;
  if (phase == 'accepted' || phase == 'committing') return false;
  if (phase != 'preparing' && phase != 'prepared') throw _bridgeResponseInvalid;
  final cancelled = _checkBinding(
    await native(RgbLibHostedBridgeOperation.cancelBurn, request),
    binding,
  );
  return cancelled['phase'] == 'rejected';
}

typedef _AcceptedBurn = ({
  BigInt amount,
  BurnPayout payout,
  BurnDestination destination,
  int rate,
  int minimum,
  int batch,
});

WebRgbTransfer _scopedBurnTransfer(
  String txid,
  String status,
  _AcceptedBurn details, {
  int? blockHeight,
  int? confirmations,
}) => WebRgbTransfer(
  network: 'utexo',
  kind: 'Burn',
  status: status,
  assetId: _bridgeAssetId,
  amount: details.amount <= BigInt.from(9007199254740991)
      ? details.amount.toInt()
      : null,
  amountBaseUnits: details.amount.toString(),
  burnRecipient: details.payout,
  burnDestination: details.destination,
  txid: txid,
  batchTransferIdx: details.batch,
  feeRate: details.rate,
  minConfirmations: details.minimum,
  blockHeight: blockHeight,
  confirmations: confirmations,
);

_AcceptedBurn _acceptedBurn(Map<String, Object?> record) {
  final address = record['recipientAddress'];
  final amount = record['amount'];
  final rateText = record['feeRate'];
  final minimum = record['minConfirmations'];
  final rate =
      rateText is String && RegExp(r'^[1-9][0-9]{0,3}$').hasMatch(rateText)
      ? int.tryParse(rateText)
      : null;
  if (record['phase'] != 'accepted' ||
      address is! String ||
      amount is! String ||
      !_isBridgeAmount(amount) ||
      rate == null ||
      rate > 1000 ||
      minimum is! int ||
      minimum < 6 ||
      minimum > 255) {
    throw _bridgeResponseInvalid;
  }
  final payout = BurnPayout(chainId: _directArbitrum, address: address);
  final destination = BurnDestination.forPayout(
    BurnDestinationRoute(chainId: _directArbitrum, dstEid: 0),
    address,
  );
  if (destination.commitment != record['destinationCommitment']) {
    throw _bridgeResponseInvalid;
  }
  _bridgeFee(record);
  return (
    amount: BigInt.parse(amount),
    payout: payout,
    destination: destination,
    rate: rate,
    minimum: minimum,
    batch: _bridgeBatch(record),
  );
}

int _bridgeBatch(Map<String, Object?> record) {
  final batch = record['batchTransferIdx'];
  if (batch is! int || batch < 0 || batch > 0x7fffffff) {
    throw _bridgeResponseInvalid;
  }
  return batch;
}

int _bridgeFee(Map<String, Object?> record) {
  final value = record['feeSats'];
  final fee = value is String && RegExp(r'^[1-9][0-9]{0,3}$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (fee == null || fee > _maxDevBurnFeeSats) throw _bridgeResponseInvalid;
  return fee;
}

int _bridgeInt(
  Map<String, Object?> input,
  String key,
  int fallback,
  int min,
  int max,
) => webRgbInteger(
  input.containsKey(key) ? _optionalInteger(input[key]) ?? -1 : fallback,
  key,
  min: min,
  max: max,
);

void _requireBridgeAsset(Object? assetId) {
  if (assetId != _bridgeAssetId) throw _bridgeInvalid;
}

Map<String, Object?> _only(Map<String, Object?> input, Set<String> keys) {
  if (input.keys.any((key) => !keys.contains(key))) throw _bridgeInvalid;
  return input;
}

Map<String, Object?> _checkBinding(
  Map<String, Object?>? row,
  Map<String, Object?> expected,
) {
  if (row == null ||
      expected.entries.any((entry) => row[entry.key] != entry.value)) {
    throw _bridgeResponseInvalid;
  }
  return row;
}

bool _isBridgeAmount(String value) =>
    RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value) &&
    BigInt.parse(value) <= ((BigInt.one << 64) - BigInt.one);

final _bridgeHex64 = RegExp(r'^[a-f0-9]{64}$');

String _bridgeHash(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

Object? _canonicalBridgeJson(Object? value) => switch (value) {
  final Map<String, Object?> object => {
    for (final key in object.keys.toList()..sort())
      key: _canonicalBridgeJson(object[key]),
  },
  final List<Object?> array => array.map(_canonicalBridgeJson).toList(),
  _ => value,
};

Future<WebRgbGetConsignmentResult> _verifiedNativeProof(
  String assetId,
  String txid,
  String data,
  String expectedSha,
  int maxBytes,
) => Isolate.run(() {
  const magic = [82, 71, 66, 0, 84, 70, 82];
  if (data.length > ((maxBytes + 2) ~/ 3) * 4) throw _bridgeResponseInvalid;
  final bytes = base64Decode(data);
  if (bytes.length <= magic.length ||
      bytes.length > maxBytes ||
      base64Encode(bytes) != data ||
      !List.generate(
        magic.length,
        (i) => bytes[i] == magic[i],
      ).every((matches) => matches) ||
      sha256.convert(bytes).toString() != expectedSha) {
    throw _bridgeResponseInvalid;
  }
  final digest = KeccakDigest(
    256,
  ).process(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return WebRgbGetConsignmentResult(
    assetId: assetId,
    txid: txid,
    data: data,
    byteLength: bytes.length,
    digest: '0x$digest',
  );
});
