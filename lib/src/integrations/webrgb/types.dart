import '../../wallet/burn_destination.dart';
import '../../wallet/burn_operations.dart';

/// dApp-session approval. Values are SDK-owned immutable snapshots.
class WebRgbApproval {
  WebRgbApproval({
    required this.origin,
    required this.method,
    required Map<String, Object?> params,
  }) : params = Map.unmodifiable(params);
  final String origin;
  final String method;
  final Map<String, Object?> params;
}

/// Host-only configuration. Chain policy must never come from the dApp.
class WebRgbBurnOptions {
  WebRgbBurnOptions({
    required this.operations,
    required Iterable<String> allowedPayoutChainIds,
    Iterable<BurnDestinationRoute> destinationRoutes = const [],
  }) : allowedPayoutChainIds = Set.unmodifiable(allowedPayoutChainIds),
       destinationRoutes = List.unmodifiable(destinationRoutes);
  final BurnOperations operations;
  final Set<String> allowedPayoutChainIds;

  /// Deployment-owned V1 routes. A configured V1 route never falls back to
  /// legacy address padding if the request names a different chain or route.
  final List<BurnDestinationRoute> destinationRoutes;
}

/// One approved transport session, not a global wallet permission.
class WebRgbOptions {
  const WebRgbOptions({
    required this.origin,
    required this.confirm,
    this.sessionApproved = false,
    this.assertAuthorized,
    this.minConfirmations = 3,
    this.burn,
  });

  /// Verified by the transport host; never take from request parameters.
  final String origin;
  final Future<bool> Function(WebRgbApproval) confirm;

  /// Set only after the host independently approves/restores a session.
  final bool sessionApproved;

  /// Rechecked after async boundaries. Throw if transport permission ended.
  final void Function()? assertAuthorized;
  final int minConfirmations;
  final WebRgbBurnOptions? burn;
}

class WebRgbInfo {
  WebRgbInfo({
    required this.network,
    required Iterable<String> methods,
    Iterable<String>? burnRecipientNamespaces,
    this.protocol = 'RGB_LN',
    Iterable<BurnDestinationRoute> burnDestinationRoutes = const [],
  }) : methods = List.unmodifiable(methods),
       burnDestinationRoutes = List.unmodifiable(burnDestinationRoutes),
       burnRecipientNamespaces = burnRecipientNamespaces == null
           ? null
           : List.unmodifiable(burnRecipientNamespaces);
  final String network;
  final List<String> methods;

  /// Host-authorized address namespaces; absent when burning is unavailable.
  final List<String>? burnRecipientNamespaces;
  final List<BurnDestinationRoute> burnDestinationRoutes;
  bool get ready => true;
  final String protocol;
  Map<String, Object?> toJson() => {
    'ready': ready,
    'network': network,
    'protocol': protocol,
    'methods': methods,
    if (burnRecipientNamespaces != null)
      'burnRecipientNamespaces': burnRecipientNamespaces,
    if (burnDestinationRoutes.isNotEmpty) ...{
      'burnDestinationVersion': 1,
      'burnDestinationRoutes': burnDestinationRoutes
          .map((route) => route.toJson())
          .toList(),
    },
  };
}

/// Wallet address response in the WebRGB transport shape.
class WebRgbAddressResult {
  const WebRgbAddressResult({required this.address});
  final String address;
  Map<String, Object?> toJson() => {'address': address};
}

/// Parameters for a blinded receive; amounts use base units.
class WebRgbBlindReceiveArgs {
  const WebRgbBlindReceiveArgs({
    this.assetId,
    this.amount,
    this.durationSeconds = 3600,
    this.minConfirmations,
  });
  final String? assetId;
  final int? amount;
  final int durationSeconds;
  final int? minConfirmations;
}

class WebRgbBlindReceiveResult {
  const WebRgbBlindReceiveResult({
    required this.invoice,
    this.recipientId,
    this.expirationTimestamp,
    required this.minConfirmations,
  });
  final String invoice;
  final String? recipientId;

  /// Unix timestamp in seconds.
  final int? expirationTimestamp;
  final int minConfirmations;
  Map<String, Object?> toJson() => {
    'invoice': invoice,
    if (recipientId != null) 'recipientId': recipientId,
    if (expirationTimestamp != null) 'expirationTimestamp': expirationTimestamp,
    'minConfirmations': minConfirmations,
  };
}

/// Witness receiving uses the same units, expiry and confirmation policy.
typedef WebRgbWitnessReceiveArgs = WebRgbBlindReceiveArgs;

/// Witness invoice response, matching the WebRGB 0.1.2 wire shape.
typedef WebRgbWitnessReceiveResult = WebRgbBlindReceiveResult;

/// Native wallet signature over the exact, user-approved Unicode message.
class WebRgbSignMessageResult {
  const WebRgbSignMessageResult({required this.signature});
  final String signature;
  Map<String, Object?> toJson() => {'signature': signature};
}

class WebRgbAsset {
  const WebRgbAsset({
    required this.id,
    required this.schema,
    this.ticker,
    required this.name,
    required this.precision,
  });
  final String id;
  final String schema;
  final String? ticker;
  final String name;
  final int precision;
  Map<String, Object?> toJson() => {
    'id': id,
    'schema': schema,
    if (ticker != null) 'ticker': ticker,
    'name': name,
    'precision': precision,
  };
}

/// JavaScript-safe base-unit balances. Larger amounts fail, never round.
class WebRgbAssetBalance {
  WebRgbAssetBalance({
    required this.assetId,
    required this.balance,
    required Map<String, int> raw,
  }) : raw = Map.unmodifiable(raw);
  final String assetId;
  final int balance;
  final Map<String, int> raw;
  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'balance': balance,
    'raw': raw,
  };
}

/// Public transfer fields only, without journal IDs or local paths.
class WebRgbTransfer {
  const WebRgbTransfer({
    this.assetId,
    this.transferId,
    this.status,
    this.kind,
    this.amount,
    this.recipientId,
    this.txid,
    this.network,
    this.burnRecipient,
    this.burnDestination,
    this.batchTransferIdx,
    this.feeRate,
    this.minConfirmations,
    this.amountBaseUnits,
    this.blockHeight,
    this.confirmations,
  });
  final String? assetId;
  final int? transferId;
  final String? status;
  final String? kind;
  final int? amount;
  final String? recipientId;
  final String? txid;
  final String? network;
  final BurnPayout? burnRecipient;
  final BurnDestination? burnDestination;
  final int? batchTransferIdx;
  final int? feeRate;
  final int? minConfirmations;

  /// Exact decimal smallest units for history and burns, including full UInt64.
  final String? amountBaseUnits;
  final int? blockHeight;
  final int? confirmations;
  Map<String, Object?> toJson() => {
    if (assetId != null) 'assetId': assetId,
    if (transferId != null) 'transferId': transferId,
    if (status != null) 'status': status,
    if (kind != null) 'kind': kind,
    if (amount != null) 'amount': amount,
    if (recipientId != null) 'recipientId': recipientId,
    if (txid != null) 'txid': txid,
    if (network != null) 'network': network,
    if (burnRecipient != null) 'burnRecipient': payoutJson(burnRecipient!),
    if (burnDestination case final destination?)
      'burnDestination': destination.toJson(),
    if (batchTransferIdx != null) 'batchTransferIdx': batchTransferIdx,
    if (feeRate != null) 'feeRate': feeRate,
    if (minConfirmations != null) 'minConfirmations': minConfirmations,
    if (amountBaseUnits != null) 'amountBaseUnits': amountBaseUnits,
    if (blockHeight != null || burnRecipient != null)
      'blockHeight': blockHeight,
    if (confirmations != null) 'confirmations': confirmations,
  };
}

class WebRgbTransferStatusResult {
  const WebRgbTransferStatusResult({
    required this.found,
    this.status,
    this.transfer,
  });
  final bool found;
  final String? status;
  final WebRgbTransfer? transfer;
  Map<String, Object?> toJson() => {
    'found': found,
    'status': status,
    'transfer': transfer?.toJson(),
  };
}

class WebRgbDecodedInvoice {
  WebRgbDecodedInvoice({
    this.assetId,
    this.amount,
    required this.recipientId,
    this.expirationTimestamp,
    required this.network,
    required Iterable<String> transportEndpoints,
  }) : transportEndpoints = List.unmodifiable(transportEndpoints);
  final String? assetId;

  /// Null for Any and Fungible(0), not a request to send zero.
  final int? amount;
  final String recipientId;
  final int? expirationTimestamp;
  final String network;
  final List<String> transportEndpoints;
  Map<String, Object?> toJson() => {
    if (assetId != null) 'assetId': assetId,
    'amount': amount,
    'recipientId': recipientId,
    if (expirationTimestamp != null) 'expirationTimestamp': expirationTimestamp,
    'network': network,
    'transportEndpoints': transportEndpoints,
  };
}

class WebRgbBurnAssetArgs {
  const WebRgbBurnAssetArgs({
    required this.network,
    required this.assetId,
    required this.amount,
    required this.burnRecipient,
    this.burnDestination,
    this.feeRate = 2,
    this.minConfirmations = 3,
  });
  final String network;
  final String assetId;

  /// Positive u64 decimal base units.
  final String amount;
  final BurnPayout burnRecipient;
  final BurnDestination? burnDestination;
  final int feeRate;
  final int minConfirmations;
}

/// Broadcast result only; never evidence of a successful external payout.
class WebRgbBurnAssetResult {
  const WebRgbBurnAssetResult({
    required this.txid,
    required this.assetId,
    required this.amount,
    required this.burnRecipient,
    required this.minConfirmations,
    this.burnDestination,
  });
  final String txid;
  String get transferId => txid;
  final String assetId;
  final String amount;
  final BurnPayout burnRecipient;
  final BurnDestination? burnDestination;
  final int minConfirmations;
  String get status => 'WaitingConfirmations';
  Map<String, Object?> toJson() => {
    'transferId': transferId,
    'txid': txid,
    'assetId': assetId,
    'amount': amount,
    'burnRecipient': payoutJson(burnRecipient),
    if (burnDestination case final destination?)
      'burnDestination': destination.toJson(),
    'status': status,
    'minConfirmations': minConfirmations,
  };
}

class WebRgbGetConsignmentArgs {
  const WebRgbGetConsignmentArgs({required this.assetId, required this.txid});
  final String assetId;
  final String txid;
}

/// Bounded saved-proof export; digest is Keccak-256, not NIST SHA3-256.
class WebRgbGetConsignmentResult {
  const WebRgbGetConsignmentResult({
    required this.assetId,
    required this.txid,
    required this.data,
    required this.byteLength,
    required this.digest,
  });
  final String assetId;
  final String txid;
  final String data;
  final int byteLength;

  /// 0x-prefixed 32-byte Keccak-256 digest.
  final String digest;
  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'txid': txid,
    'encoding': 'base64',
    'data': data,
    'byteLength': byteLength,
    'digest': {'algorithm': 'keccak256', 'value': digest},
  };
}

Map<String, String> payoutJson(BurnPayout payout) =>
    Map.unmodifiable({'chainId': payout.chainId, 'address': payout.address});
