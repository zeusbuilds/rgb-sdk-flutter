import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:pointycastle/digests/keccak.dart';

import '../../models/burn_models.dart';
import '../../wallet/burn_destination.dart';
import '../../wallet/burn_operations.dart';
import '../../wallet/burn_recipient.dart' as recipient;
import 'errors.dart';
import 'session.dart';
import 'types.dart';
import 'wallet.dart';

const _maxProofBytes = 16 * 1024 * 1024;

/// Private controller: durable mutation ownership stays in BurnOperations.
class WebRgbBurnController {
  WebRgbBurnController(this._wallet, this._session, this._options) {
    if (!_options.operations.belongsTo(_wallet.burnWallet)) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Burn journal belongs to another wallet.',
      );
    }
    if (_options.allowedPayoutChainIds.any(
      (id) => !recipient.isSupportedBurnPayoutChain(id),
    )) {
      throw const WebRgbError('INVALID_PARAMS', 'Invalid payout chain policy.');
    }
    final routes = _options.destinationRoutes;
    if (routes.isNotEmpty &&
        (_wallet.protocol != 'RGB_L1' ||
            routes.map((route) => route.chainId).toSet().length !=
                routes.length ||
            routes.length != _options.allowedPayoutChainIds.length ||
            routes.any(
              (route) =>
                  !_options.allowedPayoutChainIds.contains(route.chainId),
            ))) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Invalid V1 payout route policy.',
      );
    }
  }
  final WebRgbWallet _wallet;
  final WebRgbSession _session;
  final WebRgbBurnOptions _options;
  final Set<String> _exports = {};
  WebRgbGetConsignmentResult? _proof;

  List<BurnDestinationRoute> get destinationRoutes =>
      _options.destinationRoutes;

  /// Address namespaces enabled by the host's explicit payout-chain policy.
  List<String> get recipientNamespaces => [
    for (final namespace in ['eip155', 'tron'])
      if (_options.allowedPayoutChainIds.any(
        (chainId) => chainId.startsWith('$namespace:'),
      ))
        namespace,
  ];

  void revoke() {
    _exports.clear();
    _proof = null;
  }

  Future<List<String>> methods(int revision) async {
    final caps = await _session.call(revision, _wallet.getBfaCapabilities);
    return [
      if (caps.bfa &&
          caps.burn &&
          caps.consignment &&
          _options.allowedPayoutChainIds.isNotEmpty)
        'burnAsset',
      if (caps.consignment) 'getConsignment',
    ];
  }

  Future<WebRgbBurnAssetResult> burnAsset(
    int revision,
    WebRgbBurnAssetArgs args,
  ) async {
    _session.check(revision);
    if (!(await methods(revision)).contains('burnAsset')) {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Native burn is unavailable.',
      );
    }
    if (args.network != _wallet.getNetwork() ||
        !_options.allowedPayoutChainIds.contains(args.burnRecipient.chainId)) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Invalid RGB network or payout chain.',
      );
    }
    webRgbInteger(args.minConfirmations, 'minConfirmations', max: 255);
    final payout = await webRgbWalletCall(
      () async => BurnPayout(
        chainId: args.burnRecipient.chainId,
        address: recipient.normalizeBurnRecipientAddress(
          args.burnRecipient.chainId,
          args.burnRecipient.address,
        ),
      ),
    );
    final destination = await webRgbWalletCall(() async {
      final supplied = args.burnDestination;
      if (destinationRoutes.isEmpty) {
        if (supplied == null) return null;
        throw const WebRgbError(
          'INVALID_PARAMS',
          'V1 payout routes are unavailable.',
        );
      }
      final route = destinationRoutes.singleWhere(
        (route) => route.chainId == payout.chainId,
      );
      final expected = BurnDestination.forPayout(route, payout.address);
      if (supplied != null) {
        supplied.validatePayout(payout.chainId, payout.address);
        if (supplied.dstEid != expected.dstEid) {
          throw const WebRgbError(
            'INVALID_PARAMS',
            'Payout route does not match wallet configuration.',
          );
        }
      }
      return expected;
    });
    final request = BurnParams(
      assetId: args.assetId,
      amount: args.amount,
      burnRecipient:
          destination?.commitment ??
          recipient.encodeBurnRecipient(payout.chainId, payout.address),
      feeRate: args.feeRate,
      minConfirmations: max(3, args.minConfirmations),
    );
    await webRgbWalletCall(() async => request.validate());
    await _session.call(revision, _options.operations.retryPersistence);
    final records = await _session.call(revision, _options.operations.records);
    if (records.any((record) => record.state == BurnOperationState.pending)) {
      throw const WebRgbError(
        'INTERNAL_ERROR',
        'A previous burn has an unresolved outcome.',
      );
    }
    final assets = await _session.call(revision, _wallet.listAssets);
    if (!assets.bfa.any((asset) => asset.assetId == request.assetId)) {
      throw const WebRgbError(
        'ASSET_NOT_FOUND',
        'Select a BFA asset held by this wallet.',
      );
    }
    await _session.confirm(revision, 'burnAsset', {
      'network': args.network,
      'assetId': request.assetId,
      'amount': request.amount,
      'burnRecipient': payoutJson(payout),
      if (destination != null) 'burnDestination': destination.toJson(),
      'feeRate': request.feeRate,
      'minConfirmations': request.minConfirmations,
      'getConsignment': true,
    });
    // Persist a known result even if permission is revoked during native work.
    // The outer session check then withholds the result from the revoked dApp.
    final record = await webRgbWalletCall(
      () => _options.operations.execute(
        request,
        BurnOperationMetadata(
          origin: _session.options.origin,
          network: args.network,
          payout: payout,
          burnDestination: destination,
        ),
        () => _session.check(revision),
      ),
    );
    _session.check(revision);
    final result = record.result!;
    _exports.add('${request.assetId}:${result.txid}');
    return WebRgbBurnAssetResult(
      txid: result.txid,
      assetId: request.assetId,
      amount: request.amount,
      burnRecipient: payout,
      burnDestination: destination,
      minConfirmations: request.minConfirmations,
    );
  }

  Future<WebRgbTransferStatusResult?> getTransferStatus(
    int revision,
    String id,
    String? assetId,
  ) async {
    await _session.call(revision, _options.operations.retryPersistence);
    final records = await _session.call(revision, _options.operations.records);
    final matches = records.where(
      (record) =>
          (record.metadata.origin == _session.options.origin ||
              (record.metadata.burnDestination != null &&
                  _exports.contains(
                    '${record.params.assetId}:${record.result?.txid}',
                  ))) &&
          record.result?.txid == id &&
          (assetId == null || record.params.assetId == assetId),
    );
    if (matches.isEmpty) return null;
    final record = matches.first;
    final result = record.result!;
    await _session.call(revision, _wallet.refreshWallet);
    final transfers = await _session.call(
      revision,
      () => _wallet.burnWallet.listTransfers(assetId: record.params.assetId),
    );
    final transactions = await _session.call(
      revision,
      () => _wallet.listTransactionsByTxid(result.txid),
    );
    final blockHeight = await _session.call(revision, _wallet.getBlockHeight);
    final matchedTransfers = transfers.where(
      (item) => item.txid == result.txid && item.kind == 'Burn',
    );
    final transfer = matchedTransfers.isEmpty ? null : matchedTransfers.first;
    final matchedTransactions = transactions.where(
      (item) => item.txid == result.txid,
    );
    final height = matchedTransactions.isEmpty
        ? null
        : matchedTransactions.first.confirmationTime?.height;
    final amount = BigInt.parse(record.params.amount);
    final status = transfer?.status ?? 'WaitingConfirmations';
    return WebRgbTransferStatusResult(
      found: true,
      status: status,
      transfer: WebRgbTransfer(
        network: record.metadata.network,
        assetId: record.params.assetId,
        amount: amount <= BigInt.from(9007199254740991) ? amount.toInt() : null,
        burnRecipient: record.metadata.payout,
        burnDestination: record.metadata.burnDestination,
        txid: result.txid,
        batchTransferIdx: result.batchTransferIdx,
        status: status,
        feeRate: record.params.feeRate,
        minConfirmations: record.params.minConfirmations,
        transferId: transfer?.idx,
        amountBaseUnits: record.params.amount,
        blockHeight: height,
        confirmations: height == null
            ? 0
            : blockHeight == null
            ? null
            : max(0, blockHeight - height + 1),
      ),
    );
  }

  Future<WebRgbGetConsignmentResult> getConsignment(
    int revision,
    WebRgbGetConsignmentArgs args,
  ) async {
    _session.check(revision);
    if (!(await methods(revision)).contains('getConsignment')) {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Native consignment access is unavailable.',
      );
    }
    await webRgbWalletCall(
      () async => validateConsignmentLookup(args.assetId, args.txid),
    );
    final key = '${args.assetId}:${args.txid}';
    // Journal ownership is not lasting export consent. A new or revoked session
    // requires fresh approval even for a burn previously made by the same origin.
    if (!_exports.contains(key)) {
      await _session.confirm(revision, 'getConsignment', {
        'assetId': args.assetId,
        'txid': args.txid,
      });
    }
    final transfers = await _session.call(
      revision,
      () => _wallet.burnWallet.listTransfers(assetId: args.assetId),
    );
    if (!transfers.any(
      (item) => item.kind == 'Burn' && item.txid == args.txid,
    )) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Only a saved burn consignment can be exported.',
      );
    }
    final cached = _proof;
    if (cached != null &&
        cached.assetId == args.assetId &&
        cached.txid == args.txid) {
      _session.check(revision);
      return cached;
    }
    final encoded = await _session.call(
      revision,
      () => _wallet.burnWallet.getConsignment(args.assetId, args.txid),
    );
    if (encoded.length > ((_maxProofBytes + 2) ~/ 3) * 4) {
      throw const WebRgbError(
        'INTERNAL_ERROR',
        'Consignment exceeds the 16 MiB wallet limit.',
      );
    }
    // Hashing a maximum-size proof must not block the Flutter UI isolate.
    final result = await _session.call(
      revision,
      () => _hashProofInBackground(args, encoded),
    );
    _proof = result;
    _exports.add(key);
    return result;
  }
}

// Keep this closure outside the controller's scope: isolate messages must not
// capture the wallet, host callbacks, durable store or native handles.
Future<WebRgbGetConsignmentResult> _hashProofInBackground(
  WebRgbGetConsignmentArgs args,
  String encoded,
) => Isolate.run(() => _decodeProof(args, encoded));

WebRgbGetConsignmentResult _decodeProof(
  WebRgbGetConsignmentArgs args,
  String encoded,
) {
  try {
    final bytes = base64Decode(encoded);
    if (bytes.isEmpty ||
        bytes.length > _maxProofBytes ||
        base64Encode(bytes) != encoded) {
      throw const FormatException('Invalid canonical proof encoding.');
    }
    final digest = KeccakDigest(256)
        .process(bytes)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return WebRgbGetConsignmentResult(
      assetId: args.assetId,
      txid: args.txid,
      data: encoded,
      byteLength: bytes.length,
      digest: '0x$digest',
    );
  } on FormatException {
    throw const WebRgbError('INTERNAL_ERROR', 'Saved consignment is invalid.');
  }
}
