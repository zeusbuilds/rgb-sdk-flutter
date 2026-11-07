import '../errors/rgb_sdk_exception.dart';
import '../models/exact_integer.dart';
import 'lsp_protocol_policy.dart';

const _maxUnsigned64Decimal = '18446744073709551615';

class LspClientConfig {
  const LspClientConfig({
    required this.baseUrl,
    this.bearerToken,
    this.timeoutMs,
  });

  final String baseUrl;
  final String? bearerToken;
  final int? timeoutMs;
}

class LspGetInfoResponse {
  LspGetInfoResponse({
    required this.apiVersion,
    required this.pubkey,
    required this.network,
    this.host,
    this.port,
    required List<LspSupportedAsset> supportedAssets,
    required this.minPaymentSizeMsat,
    required this.maxPaymentSizeMsat,
    required this.minChannelBalanceSat,
    required this.maxChannelBalanceSat,
    required this.minInitialClientBalanceMsat,
    required this.maxInitialClientBalanceMsat,
    required this.minChannelAssetAmount,
    required this.maxChannelAssetAmount,
    this.virtualChannelMode,
    required this.lightningAddressMinSendableMsat,
    required this.lightningAddressMaxSendableMsat,
  }) : supportedAssets = List<LspSupportedAsset>.unmodifiable(supportedAssets);

  factory LspGetInfoResponse.fromWire(Map<String, Object?> map) {
    return LspGetInfoResponse(
      apiVersion: _requiredInt(map, 'api_version', 'LspGetInfoResponse'),
      pubkey: _requiredString(map, 'pubkey', 'LspGetInfoResponse'),
      network: _requiredString(map, 'network', 'LspGetInfoResponse'),
      host: _optionalString(map, 'host', 'LspGetInfoResponse'),
      port: _optionalPort(map, 'port', 'LspGetInfoResponse'),
      supportedAssets: _requiredMapList(
        map,
        'supported_assets',
        'LspGetInfoResponse',
      ).map(LspSupportedAsset.fromWire).toList(growable: false),
      minPaymentSizeMsat: _requiredUInt64(
        map,
        'min_payment_size_msat',
        'LspGetInfoResponse',
      ),
      maxPaymentSizeMsat: _requiredUInt64(
        map,
        'max_payment_size_msat',
        'LspGetInfoResponse',
      ),
      minChannelBalanceSat: _requiredUInt64(
        map,
        'min_channel_balance_sat',
        'LspGetInfoResponse',
      ),
      maxChannelBalanceSat: _requiredUInt64(
        map,
        'max_channel_balance_sat',
        'LspGetInfoResponse',
      ),
      minInitialClientBalanceMsat: _requiredUInt64(
        map,
        'min_initial_client_balance_msat',
        'LspGetInfoResponse',
      ),
      maxInitialClientBalanceMsat: _requiredUInt64(
        map,
        'max_initial_client_balance_msat',
        'LspGetInfoResponse',
      ),
      minChannelAssetAmount: _requiredUInt64(
        map,
        'min_channel_asset_amount',
        'LspGetInfoResponse',
      ),
      maxChannelAssetAmount: _requiredUInt64(
        map,
        'max_channel_asset_amount',
        'LspGetInfoResponse',
      ),
      virtualChannelMode: _optionalString(
        map,
        'virtual_channel_mode',
        'LspGetInfoResponse',
      ),
      lightningAddressMinSendableMsat: _requiredUInt64(
        map,
        'lightning_address_min_sendable_msat',
        'LspGetInfoResponse',
      ),
      lightningAddressMaxSendableMsat: _requiredUInt64(
        map,
        'lightning_address_max_sendable_msat',
        'LspGetInfoResponse',
      ),
    );
  }

  final int apiVersion;
  final String pubkey;
  final String network;
  final String? host;
  final int? port;
  final List<LspSupportedAsset> supportedAssets;
  final BigInt minPaymentSizeMsat;
  final BigInt maxPaymentSizeMsat;
  final BigInt minChannelBalanceSat;
  final BigInt maxChannelBalanceSat;
  final BigInt minInitialClientBalanceMsat;
  final BigInt maxInitialClientBalanceMsat;
  final BigInt minChannelAssetAmount;
  final BigInt maxChannelAssetAmount;
  final String? virtualChannelMode;
  final BigInt lightningAddressMinSendableMsat;
  final BigInt lightningAddressMaxSendableMsat;
}

class LspSupportedAsset {
  const LspSupportedAsset({
    required this.assetId,
    required this.schema,
    this.ticker,
    required this.name,
    required this.precision,
  });

  factory LspSupportedAsset.fromWire(Map<String, Object?> map) {
    return LspSupportedAsset(
      assetId: _requiredString(map, 'asset_id', 'LspSupportedAsset'),
      schema: _requiredString(map, 'schema', 'LspSupportedAsset'),
      ticker: _optionalString(map, 'ticker', 'LspSupportedAsset'),
      name: _requiredString(map, 'name', 'LspSupportedAsset'),
      precision: _requiredUInt8(map, 'precision', 'LspSupportedAsset'),
    );
  }

  final String assetId;
  final String schema;
  final String? ticker;
  final String name;
  final int precision;
}

class LspLnParams {
  const LspLnParams({
    this.amtMsat,
    this.expirySec,
    this.assetId,
    this.assetAmount,
    this.descriptionHash,
    this.paymentHash,
    this.minFinalCltvExpiryDelta,
  });

  final int? amtMsat;
  final int? expirySec;
  final String? assetId;
  final int? assetAmount;
  final String? descriptionHash;
  final String? paymentHash;
  final int? minFinalCltvExpiryDelta;

  Map<String, Object?> toWire() {
    return <String, Object?>{
      if (amtMsat != null) 'amt_msat': amtMsat,
      if (expirySec != null) 'expiry_sec': expirySec,
      if (assetId != null) 'asset_id': assetId,
      if (assetAmount != null) 'asset_amount': assetAmount,
      if (descriptionHash != null) 'description_hash': descriptionHash,
      if (paymentHash != null) 'payment_hash': paymentHash,
      if (minFinalCltvExpiryDelta != null)
        'min_final_cltv_expiry_delta': minFinalCltvExpiryDelta,
    };
  }
}

class LspOnchainSendRequest {
  const LspOnchainSendRequest({required this.rgbInvoice, this.ln});

  final String rgbInvoice;
  final LspLnParams? ln;
}

class LspOnchainSendResponse {
  const LspOnchainSendResponse({
    required this.rgbInvoice,
    required this.lnInvoice,
    required this.mappingId,
  });

  factory LspOnchainSendResponse.fromWire(Map<String, Object?> map) {
    return LspOnchainSendResponse(
      rgbInvoice: _requiredString(map, 'rgb_invoice', 'LspOnchainSendResponse'),
      lnInvoice: _requiredString(map, 'ln_invoice', 'LspOnchainSendResponse'),
      mappingId: _requiredStringOrInt(
        map,
        'mapping_id',
        'LspOnchainSendResponse',
      ),
    );
  }

  final String rgbInvoice;
  final String lnInvoice;
  final String mappingId;
}

class LspRgbParams {
  const LspRgbParams({
    this.assetId,
    this.assignment,
    this.durationSeconds,
    this.minConfirmations,
    this.witness,
  });

  /// Asset requested for the on-chain leg. Omit for LSP pair resolution.
  final String? assetId;
  final String? assignment;
  final int? durationSeconds;
  final int? minConfirmations;
  final String? witness;

  Map<String, Object?> toWire() {
    return <String, Object?>{
      if (assetId != null) 'asset_id': assetId,
      'min_confirmations': minConfirmations ?? 1,
      'witness': witness != null && witness!.isNotEmpty,
      if (assignment != null) 'assignment': assignment,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }
}

class LspLightningReceiveRequest {
  const LspLightningReceiveRequest({
    required this.lnInvoice,
    required this.rgb,
  });

  final String lnInvoice;
  final LspRgbParams rgb;
}

class LspLightningReceiveResponse {
  const LspLightningReceiveResponse({
    required this.lnInvoice,
    required this.rgbInvoice,
    required this.mappingId,
    this.rgbAssetId,
    this.converted,
  });

  factory LspLightningReceiveResponse.fromWire(Map<String, Object?> map) {
    return LspLightningReceiveResponse(
      lnInvoice: _requiredString(
        map,
        'ln_invoice',
        'LspLightningReceiveResponse',
      ),
      rgbInvoice: _requiredString(
        map,
        'rgb_invoice',
        'LspLightningReceiveResponse',
      ),
      mappingId: _requiredStringOrInt(
        map,
        'mapping_id',
        'LspLightningReceiveResponse',
      ),
      rgbAssetId: _optionalString(
        map,
        'rgb_asset_id',
        'LspLightningReceiveResponse',
      ),
      converted: _optionalBool(map, 'converted', 'LspLightningReceiveResponse'),
    );
  }

  final String lnInvoice;
  final String rgbInvoice;
  final String mappingId;

  /// Asset resolved by the LSP for the on-chain leg, when reported.
  final String? rgbAssetId;

  /// Whether the LSP converts between different linked assets.
  final bool? converted;
}

/// LUD-06 discovery metadata for one Lightning Address.
class LspLnurlpDiscovery {
  LspLnurlpDiscovery({
    required this.callback,
    required this.minSendable,
    required this.maxSendable,
    this.metadata,
    this.tag,
    this.recipientPubkey,
    this.addressSig,
    this.payoutAsset,
    List<LspSupportedAsset>? acceptedAssets,
  }) : acceptedAssets = acceptedAssets == null
           ? null
           : List<LspSupportedAsset>.unmodifiable(acceptedAssets);

  factory LspLnurlpDiscovery.fromWire(Map<String, Object?> map) {
    final payout = map['payout_asset'];
    final accepted = map['accepted_assets'];
    final minSendable = _requiredNonNegativeInt(
      map,
      'minSendable',
      'LspLnurlpDiscovery',
    );
    final maxSendable = _requiredNonNegativeInt(
      map,
      'maxSendable',
      'LspLnurlpDiscovery',
    );
    if (minSendable <= 0 || maxSendable < minSendable) {
      throw _malformed(
        'LspLnurlpDiscovery sendable range must satisfy '
        '0 < minSendable <= maxSendable.',
      );
    }
    return LspLnurlpDiscovery(
      callback: _requiredString(map, 'callback', 'LspLnurlpDiscovery'),
      minSendable: minSendable,
      maxSendable: maxSendable,
      metadata: _optionalString(map, 'metadata', 'LspLnurlpDiscovery'),
      tag: _optionalString(map, 'tag', 'LspLnurlpDiscovery'),
      recipientPubkey: _optionalString(
        map,
        'recipient_pubkey',
        'LspLnurlpDiscovery',
      ),
      addressSig: _optionalString(map, 'address_sig', 'LspLnurlpDiscovery'),
      payoutAsset: payout == null
          ? null
          : payout is Map
          ? LspSupportedAsset.fromWire(Map<String, Object?>.from(payout))
          : throw _malformed(
              'LspLnurlpDiscovery.payout_asset must be a map when present.',
            ),
      acceptedAssets: accepted == null
          ? null
          : _mapListValue(
              accepted,
              'LspLnurlpDiscovery.accepted_assets',
            ).map(LspSupportedAsset.fromWire).toList(growable: false),
    );
  }

  final String callback;

  /// Minimum callback amount in millisatoshis.
  final int minSendable;

  /// Maximum callback amount in millisatoshis.
  final int maxSendable;

  final String? metadata;
  final String? tag;
  final String? recipientPubkey;
  final String? addressSig;

  /// Asset delivered to the receiver, when advertised.
  final LspSupportedAsset? payoutAsset;

  /// Assets the callback accepts, when advertised by this LSP version.
  final List<LspSupportedAsset>? acceptedAssets;
}

class LspLnurlpCallbackResponse {
  LspLnurlpCallbackResponse({
    required this.pr,
    required List<Object?> routes,
    this.status,
    this.reason,
    this.proof,
  }) : routes = List<Object?>.unmodifiable(routes);

  factory LspLnurlpCallbackResponse.fromWire(Map<String, Object?> map) {
    final status = _optionalString(map, 'status', 'LspLnurlpCallbackResponse');
    if (status == 'ERROR') {
      throw LnurlCallbackException(
        reason: _requiredString(map, 'reason', 'LspLnurlpCallbackResponse'),
      );
    }
    final proof = map['proof'];
    return LspLnurlpCallbackResponse(
      pr: _requiredString(map, 'pr', 'LspLnurlpCallbackResponse'),
      routes: _optionalList(map, 'routes', 'LspLnurlpCallbackResponse'),
      status: _optionalString(map, 'status', 'LspLnurlpCallbackResponse'),
      reason: _optionalString(map, 'reason', 'LspLnurlpCallbackResponse'),
      proof: proof == null
          ? null
          : proof is Map
          ? ApayInvoiceProof.fromWire(Map<String, Object?>.from(proof))
          : throw _malformed('LspLnurlpCallbackResponse.proof must be a map.'),
    );
  }

  final String pr;
  final List<Object?> routes;
  final String? status;
  final String? reason;
  final ApayInvoiceProof? proof;
}

/// One coherent LNURL discovery and callback exchange.
///
/// The callback URL, sendable range, address attestation, and returned invoice
/// must all originate from the same discovery response. Keeping both values
/// together prevents orchestration code from re-running discovery between
/// validation and a callback that consumes an APay hash.
class LspAddressResolution {
  const LspAddressResolution({required this.discovery, required this.callback});

  final LspLnurlpDiscovery discovery;
  final LspLnurlpCallbackResponse callback;
}

class ApayMerkleProofElement {
  const ApayMerkleProofElement({required this.sibling, required this.side});

  factory ApayMerkleProofElement.fromWire(Map<String, Object?> map) {
    final side = _requiredString(map, 'side', 'ApayMerkleProofElement');
    if (side != 'left' && side != 'right') {
      throw _malformed(
        'ApayMerkleProofElement.side must be "left" or "right".',
      );
    }
    return ApayMerkleProofElement(
      sibling: _requiredString(map, 'sibling', 'ApayMerkleProofElement'),
      side: side,
    );
  }

  final String sibling;
  final String side;
}

class ApayInvoiceProof {
  ApayInvoiceProof({
    required this.version,
    required this.recipientPubkey,
    required this.hostPubkey,
    required this.batchId,
    required this.hashIndex,
    required this.paymentHash,
    required this.batchRoot,
    required this.batchSize,
    required List<ApayMerkleProofElement> merkleProof,
    required this.batchSig,
    required this.createdAt,
    required this.expiresAt,
  }) : merkleProof = List<ApayMerkleProofElement>.unmodifiable(merkleProof);

  factory ApayInvoiceProof.fromWire(Map<String, Object?> map) {
    final merkleProof = map['merkle_proof'];
    final version = _requiredNonNegativeInt(map, 'version', 'ApayInvoiceProof');
    if (version != ApayProtocolPolicy.protocolVersion) {
      throw _malformed('ApayInvoiceProof.version is unsupported.');
    }
    final hashIndex = _requiredPositiveInt(
      map,
      'hash_index',
      'ApayInvoiceProof',
    );
    if (hashIndex > ApayProtocolPolicy.maxHashIndex) {
      throw _malformed(
        'ApayInvoiceProof.hash_index exceeds the APay BIP32 derivation range.',
      );
    }
    final batchSize = _requiredPositiveInt(
      map,
      'batch_size',
      'ApayInvoiceProof',
    );
    if (batchSize > ApayProtocolPolicy.maxBatchSize) {
      throw _malformed(
        'ApayInvoiceProof.batch_size exceeds the APay protocol maximum.',
      );
    }
    final createdAt = _requiredNonNegativeInt(
      map,
      'created_at',
      'ApayInvoiceProof',
    );
    final expiresAt = _requiredNonNegativeInt(
      map,
      'expires_at',
      'ApayInvoiceProof',
    );
    if (expiresAt < createdAt) {
      throw _malformed(
        'ApayInvoiceProof.expires_at must not precede created_at.',
      );
    }
    return ApayInvoiceProof(
      version: version,
      recipientPubkey: _requiredString(
        map,
        'recipient_pubkey',
        'ApayInvoiceProof',
      ),
      hostPubkey: _requiredString(map, 'host_pubkey', 'ApayInvoiceProof'),
      batchId: _requiredString(map, 'batch_id', 'ApayInvoiceProof'),
      hashIndex: hashIndex,
      paymentHash: _requiredString(map, 'payment_hash', 'ApayInvoiceProof'),
      batchRoot: _requiredString(map, 'batch_root', 'ApayInvoiceProof'),
      batchSize: batchSize,
      merkleProof: _mapListValue(
        merkleProof,
        'ApayInvoiceProof.merkle_proof',
      ).map(ApayMerkleProofElement.fromWire).toList(growable: false),
      batchSig: _requiredString(map, 'batch_sig', 'ApayInvoiceProof'),
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  final int version;
  final String recipientPubkey;
  final String hostPubkey;
  final String batchId;
  final int hashIndex;
  final String paymentHash;
  final String batchRoot;
  final int batchSize;
  final List<ApayMerkleProofElement> merkleProof;
  final String batchSig;
  final int createdAt;
  final int expiresAt;
}

class LspLightningAddressByPubkeyResponse {
  const LspLightningAddressByPubkeyResponse({
    required this.username,
    required this.domain,
    this.recipientPubkey,
    this.addressSig,
  });

  factory LspLightningAddressByPubkeyResponse.fromWire(
    Map<String, Object?> map,
  ) {
    return LspLightningAddressByPubkeyResponse(
      username: _requiredString(
        map,
        'username',
        'LspLightningAddressByPubkeyResponse',
      ),
      domain: _requiredString(
        map,
        'domain',
        'LspLightningAddressByPubkeyResponse',
      ),
      recipientPubkey: _optionalString(
        map,
        'recipient_pubkey',
        'LspLightningAddressByPubkeyResponse',
      ),
      addressSig: _optionalString(
        map,
        'address_sig',
        'LspLightningAddressByPubkeyResponse',
      ),
    );
  }

  final String username;
  final String domain;
  final String? recipientPubkey;
  final String? addressSig;
}

class LspPeer {
  const LspPeer({
    required this.baseUrl,
    required this.peerPubkey,
    required this.peerHost,
    required this.peerPort,
    this.bearerToken,
    this.timeoutMs,
  });

  final String baseUrl;
  final String peerPubkey;
  final String peerHost;
  final int peerPort;
  final String? bearerToken;
  final int? timeoutMs;
}

String peerUri(LspPeer peer) {
  return '${peer.peerPubkey}@${peer.peerHost}:${peer.peerPort}';
}

typedef ReceiveStatus = String;
typedef ReceiveSettlementOutcome = String;

abstract final class ReceiveStatuses {
  static const pending = 'Pending';
  static const succeeded = 'Succeeded';
  static const failed = 'Failed';
  static const expired = 'Expired';
}

abstract final class ReceiveSettlementOutcomes {
  static const settled = 'settled';
  static const timedOut = 'timed_out';
}

ReceiveStatus normalizeReceiveStatus(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'SUCCEEDED':
    case 'SETTLED':
      return ReceiveStatuses.succeeded;
    case 'FAILED':
      return ReceiveStatuses.failed;
    case 'EXPIRED':
      return ReceiveStatuses.expired;
    default:
      return ReceiveStatuses.pending;
  }
}

class ChannelReadyInfo {
  const ChannelReadyInfo({
    required this.channelId,
    required this.peerPubkey,
    required this.capacitySat,
    required this.outboundBalanceMsat,
    required this.inboundBalanceMsat,
  });

  final String channelId;
  final String peerPubkey;
  final int capacitySat;
  final int outboundBalanceMsat;
  final int inboundBalanceMsat;
}

class CreateHodlInvoiceParams {
  const CreateHodlInvoiceParams({
    required this.paymentHash,
    this.amtMsat,
    required this.expirySec,
    this.assetId,
    this.assetAmount,
    this.minFinalCltvExpiryDelta,
    this.descriptionHash,
    this.description,
  });

  final String paymentHash;
  final int? amtMsat;
  final int expirySec;
  final String? assetId;
  final int? assetAmount;
  final int? minFinalCltvExpiryDelta;
  final String? descriptionHash;
  final String? description;
}

class HodlInvoice {
  const HodlInvoice({
    required this.bolt11,
    required this.paymentHash,
    this.amtMsat,
    required this.expirySec,
    this.assetId,
    this.assetAmount,
    this.minFinalCltvExpiryDelta,
    this.descriptionHash,
    this.description,
  });

  final String bolt11;

  /// Core-compatible spelling of [bolt11].
  String get invoice => bolt11;
  final String paymentHash;
  final int? amtMsat;
  final int expirySec;
  final String? assetId;
  final int? assetAmount;
  final int? minFinalCltvExpiryDelta;
  final String? descriptionHash;
  final String? description;
}

class HodlInvoiceResult {
  const HodlInvoiceResult({required this.changed});

  /// Native claim result, or acknowledgement for cancellation.
  /// Cancellation's void native API does not prove a state transition. Query
  /// invoice/payment state before treating this as an observed cancellation.
  final bool changed;
}

class ApayHashEntry {
  const ApayHashEntry({required this.hashIndex, required this.paymentHash});

  final int hashIndex;
  final String paymentHash;
}

class ApayNewResponse {
  ApayNewResponse({
    required this.requestId,
    required this.hostNodeId,
    required this.protocolVersion,
    required this.orderId,
    required this.status,
    required this.acceptedThroughIndex,
    required this.nextIndexExpected,
    required this.unusedHashes,
    required this.refillBatchSize,
    required this.firstHashIndex,
    required this.lastHashIndex,
    required List<ApayHashEntry> hashes,
  }) : hashes = List<ApayHashEntry>.unmodifiable(hashes);

  final String requestId;
  final String hostNodeId;
  final int protocolVersion;
  final String orderId;
  final String status;
  final int acceptedThroughIndex;
  final int nextIndexExpected;
  final int unusedHashes;
  final int refillBatchSize;
  final int firstHashIndex;
  final int lastHashIndex;

  /// Registered hashes. The indices are global and continue across refills.
  final List<ApayHashEntry> hashes;
}

int _requiredInt(Map<String, Object?> map, String key, String typeName) {
  final value = _intValue(map[key]);
  if (value == null) {
    throw _malformed('$typeName.$key must be an integer.');
  }
  return value;
}

int _requiredUInt8(Map<String, Object?> map, String key, String typeName) {
  final value = _intValue(map[key]);
  if (value == null || value < 0 || value > 0xFF) {
    throw _malformed('$typeName.$key must be an unsigned 8-bit integer.');
  }
  return value;
}

int? _intValue(Object? value) => exactWireInt(value);

String _requiredString(Map<String, Object?> map, String key, String typeName) {
  final value = _stringValue(map[key]);
  if (value == null || value.trim().isEmpty) {
    throw _malformed('$typeName.$key must be a non-empty string.');
  }
  return value;
}

String _requiredStringOrInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value;
  if (value is int) return value.toString();
  throw _malformed('$typeName.$key must be a non-empty string or integer.');
}

String? _optionalString(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value == null) return null;
  final string = _stringValue(value);
  if (string == null) {
    throw _malformed('$typeName.$key must be a string when present.');
  }
  return string;
}

String? _stringValue(Object? value) {
  if (value is String) return value;
  return null;
}

int? _optionalPort(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value == null) return null;
  final port = _intValue(value);
  if (port == null || port < 1 || port > 65535) {
    throw _malformed('$typeName.$key must be a TCP port in range 1..65535.');
  }
  return port;
}

bool? _optionalBool(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw _malformed('$typeName.$key must be a boolean when present.');
}

int _requiredNonNegativeInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = _intValue(map[key]);
  if (value == null || value < 0) {
    throw _malformed('$typeName.$key must be a non-negative integer.');
  }
  return value;
}

int _requiredPositiveInt(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = _intValue(map[key]);
  if (value == null || value <= 0) {
    throw _malformed('$typeName.$key must be a positive integer.');
  }
  return value;
}

BigInt _requiredUInt64(Map<String, Object?> map, String key, String typeName) {
  final value = map[key];
  final parsed = switch (value) {
    int() when value >= 0 => BigInt.from(value),
    String() => BigInt.tryParse(value),
    _ => null,
  };
  final max = BigInt.parse(_maxUnsigned64Decimal);
  if (parsed == null || parsed < BigInt.zero || parsed > max) {
    throw _malformed('$typeName.$key must be a u64 decimal string.');
  }
  return parsed;
}

List<Map<String, Object?>> _requiredMapList(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = map[key];
  if (value == null) {
    throw _malformed('$typeName.$key must be a list.');
  }
  return _mapListValue(value, '$typeName.$key');
}

List<Object?> _optionalList(
  Map<String, Object?> map,
  String key,
  String typeName,
) {
  final value = map[key];
  if (value == null) return const <Object?>[];
  if (value is! List<Object?>) {
    throw _malformed('$typeName.$key must be a list when present.');
  }
  return List<Object?>.unmodifiable(value);
}

List<Map<String, Object?>> _mapListValue(Object? value, String field) {
  if (value is! List) {
    throw _malformed('$field must be a list.');
  }
  return List<Map<String, Object?>>.unmodifiable(
    value.map((item) {
      if (item is! Map) {
        throw _malformed('$field entries must be maps.');
      }
      return Map<String, Object?>.from(item);
    }),
  );
}

Never _malformed(String message) {
  throw NativeProtocolException(message, field: 'lsp');
}
