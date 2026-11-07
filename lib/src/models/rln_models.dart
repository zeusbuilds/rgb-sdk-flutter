import '../errors/rgb_sdk_exception.dart';

/// Raw platform map returned by the low-level RLN bridge.
typedef RlnMap = Map<Object?, Object?>;

/// Largest integer accepted as an input over the current Pigeon bridge.
///
/// RLN native APIs use unsigned integer types in many request structs, but
/// Pigeon transports Dart `int` values to Swift/Kotlin as signed 64-bit
/// integers. Inputs above this value cannot be represented by the generated
/// bridge and must be exposed through a future string/typed-integer transport
/// before the SDK claims larger request ranges.
const int rlnPigeonMaxSignedInt64 = 9223372036854775807;

/// Largest unsigned 64-bit value that native RLN may return on the wire.
///
/// Native outputs greater than [rlnPigeonMaxSignedInt64] are serialized as
/// decimal strings by the Swift/Kotlin bridge. RGB balances and supplies use
/// BigInt so a valid asset cannot make the entire asset list unreadable.
const String rlnMaxUnsigned64Decimal = '18446744073709551615';

/// Native RGB assignment type accepted by RLN invoices.
enum RlnAssignmentKind {
  fungible('Fungible'),
  nonFungible('NonFungible'),
  inflationRight('InflationRight'),
  replaceRight('ReplaceRight'),
  any('Any');

  const RlnAssignmentKind(this.wireValue);

  final String wireValue;
}

int? _intOrNull(Object? value, [String field = 'native integer']) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double &&
      value.isFinite &&
      value % 1 == 0 &&
      value.abs() <= 9007199254740991) {
    // BigInt conversion is exact for integral doubles and cannot saturate.
    return _intOrNull(BigInt.from(value).toString(), field);
  }
  if (value is String && RegExp(r'^-?[0-9]+$').hasMatch(value)) {
    final parsed = BigInt.tryParse(value);
    if (parsed == null) return null;
    if (parsed > BigInt.from(rlnPigeonMaxSignedInt64) ||
        parsed < BigInt.from(-rlnPigeonMaxSignedInt64 - 1)) {
      throw NativeProtocolException(
        '$field exceeds the supported signed 64-bit integer range.',
        field: field,
      );
    }
    return parsed.toInt();
  }
  return null;
}

BigInt? _uint64OrNull(Object? value, [String field = 'native UInt64']) {
  if (value == null) return null;
  final parsed = switch (value) {
    int() when value >= 0 => BigInt.from(value),
    double()
        when value.isFinite &&
            value % 1 == 0 &&
            value >= 0 &&
            value <= 9007199254740991 =>
      BigInt.from(value),
    String() when RegExp(r'^[0-9]+$').hasMatch(value) => BigInt.tryParse(value),
    _ => null,
  };
  if (parsed == null) return null;
  if (parsed < BigInt.zero || parsed > BigInt.parse(rlnMaxUnsigned64Decimal)) {
    throw NativeProtocolException(
      '$field exceeds the supported unsigned 64-bit integer range.',
      field: field,
    );
  }
  return parsed;
}

int _requiredInt(RlnMap map, String key, String typeName) {
  final value = _intOrNull(map[key]);
  if (value == null) {
    throw NativeProtocolException(
      '$typeName.$key must be an integer.',
      field: '$typeName.$key',
    );
  }
  return value;
}

int _requiredSats(RlnMap map, String key, String typeName) {
  final value = _requiredInt(map, key, typeName);
  if (value < 0) {
    throw NativeProtocolException(
      '$typeName.$key must be non-negative satoshis.',
      field: '$typeName.$key',
    );
  }
  return value;
}

BigInt _requiredUInt64(RlnMap map, String key, String typeName) {
  final field = '$typeName.$key';
  final value = _uint64OrNull(map[key], field);
  if (value == null) {
    throw NativeProtocolException(
      '$field must be an unsigned integer.',
      field: field,
    );
  }
  return value;
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double _requiredDouble(RlnMap map, String key, String typeName) {
  final value = _doubleOrNull(map[key]);
  if (value == null || value.isNaN || value.isInfinite) {
    throw NativeProtocolException(
      '$typeName.$key must be a finite number.',
      field: '$typeName.$key',
    );
  }
  return value;
}

bool _requiredBool(RlnMap map, String key, String typeName) {
  final value = map[key];
  if (value is bool) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a boolean.',
    field: '$typeName.$key',
  );
}

String? _stringOrNull(Object? value) => value is String ? value : null;

String _requiredString(RlnMap map, String key, String typeName) {
  final value = _stringOrNull(map[key]);
  if (value == null || value.isEmpty) {
    throw NativeProtocolException(
      '$typeName.$key must be a non-empty string.',
      field: '$typeName.$key',
    );
  }
  return value;
}

String? _optionalString(
  RlnMap map,
  String key,
  String typeName, {
  bool allowEmpty = true,
}) {
  if (!map.containsKey(key) || map[key] == null) return null;
  final value = map[key];
  if (value is String && (allowEmpty || value.isNotEmpty)) return value;
  throw NativeProtocolException(
    '$typeName.$key must be ${allowEmpty ? 'a string' : 'a non-empty string'} when present.',
    field: '$typeName.$key',
  );
}

String _canonicalEnum(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) {
    throw const NativeProtocolException(
      'Native enum must be a non-empty string.',
    );
  }
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(raw)) return raw;
  return raw
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toUpperCase();
}

String _uppercaseStatus(Object? value) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) {
    throw const NativeProtocolException(
      'Native status must be a non-empty string.',
    );
  }
  return raw.toUpperCase();
}

String _pascalEnum(Object? value, String field) {
  final raw = _stringOrNull(value);
  if (raw == null || raw.isEmpty) {
    throw NativeProtocolException(
      '$field must be a non-empty string.',
      field: field,
    );
  }
  if (raw.contains('_')) {
    return raw
        .toLowerCase()
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join();
  }
  if (raw == raw.toUpperCase()) {
    final lower = raw.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
  return raw[0].toUpperCase() + raw.substring(1);
}

String _pascalStatus(Object? value, String field) => _pascalEnum(value, field);

RlnMap _requiredMap(RlnMap map, String key, String typeName) {
  final value = map[key];
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  throw NativeProtocolException(
    '$typeName.$key must be a map.',
    field: '$typeName.$key',
  );
}

RlnMap _map(Object? value, String field) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  throw NativeProtocolException('$field must be a map.', field: field);
}

List<RlnMap> _mapList(Object? value, String field, {bool required = false}) {
  if (value == null && !required) return const <RlnMap>[];
  if (value is! List) {
    throw NativeProtocolException('$field must be a list.', field: field);
  }
  return value.map((entry) => _map(entry, '$field[]')).toList(growable: false);
}

List<String> _stringList(Object? value, String field, {bool required = false}) {
  if (value == null && !required) return const <String>[];
  if (value is! List) {
    throw NativeProtocolException('$field must be a list.', field: field);
  }
  return value
      .map((entry) {
        if (entry is String) return entry;
        throw NativeProtocolException(
          '$field entries must be strings.',
          field: field,
        );
      })
      .toList(growable: false);
}

/// Vanilla and colored xpubs for the wallet accounts.
class RlnXpubs {
  const RlnXpubs({this.vanilla, this.colored});

  final String? vanilla;
  final String? colored;
}

/// On-chain address returned by RLN.
class RlnAddress {
  const RlnAddress({required this.address});

  factory RlnAddress.fromMap(RlnMap map) {
    return RlnAddress(address: _requiredString(map, 'address', 'RlnAddress'));
  }

  final String address;
}

/// Node-key signature returned by RLN.
class RlnSignMessageResult {
  const RlnSignMessageResult({required this.signedMessage});

  factory RlnSignMessageResult.fromMap(RlnMap map) {
    return RlnSignMessageResult(
      signedMessage: _requiredString(
        map,
        'signedMessage',
        'RlnSignMessageResult',
      ),
    );
  }

  final String signedMessage;
}

/// Node-key signature verification result returned by RLN.
class RlnVerifyMessageResult {
  const RlnVerifyMessageResult({required this.valid});

  factory RlnVerifyMessageResult.fromMap(RlnMap map) {
    return RlnVerifyMessageResult(
      valid: _requiredBool(map, 'valid', 'RlnVerifyMessageResult'),
    );
  }

  final bool valid;
}

/// Atomic IFA inflation result returned by RLN.
class RlnInflateResult {
  const RlnInflateResult({required this.txid});

  factory RlnInflateResult.fromMap(RlnMap map) {
    return RlnInflateResult(
      txid: _requiredString(map, 'txid', 'RlnInflateResult'),
    );
  }

  final String txid;
}

/// Node metadata returned by RLN.
class RlnNodeInfo {
  const RlnNodeInfo({
    required this.pubkey,
    required this.numChannels,
    required this.numUsableChannels,
    required this.localBalanceSat,
    this.eventualCloseFeesSat,
    this.pendingOutboundPaymentsSat,
    required this.numPeers,
    this.accountXpubVanilla,
    this.accountXpubColored,
    this.maxMediaUploadSizeMb,
    this.rgbHtlcMinMsat,
    this.rgbChannelCapacityMinSat,
    this.channelCapacityMinSat,
    this.channelCapacityMaxSat,
    this.channelAssetMinAmount,
    this.channelAssetMaxAmount,
    this.networkNodes,
    this.networkChannels,
    this.latestRgsSnapshotTimestamp,
  });

  factory RlnNodeInfo.fromMap(RlnMap map) {
    return RlnNodeInfo(
      pubkey: _requiredString(map, 'pubkey', 'RlnNodeInfo'),
      numChannels: _requiredInt(map, 'numChannels', 'RlnNodeInfo'),
      numUsableChannels: _requiredInt(map, 'numUsableChannels', 'RlnNodeInfo'),
      localBalanceSat: _requiredInt(map, 'localBalanceSat', 'RlnNodeInfo'),
      eventualCloseFeesSat: _intOrNull(map['eventualCloseFeesSat']),
      pendingOutboundPaymentsSat: _intOrNull(map['pendingOutboundPaymentsSat']),
      numPeers: _requiredInt(map, 'numPeers', 'RlnNodeInfo'),
      accountXpubVanilla: _stringOrNull(map['accountXpubVanilla']),
      accountXpubColored: _stringOrNull(map['accountXpubColored']),
      maxMediaUploadSizeMb: _intOrNull(map['maxMediaUploadSizeMb']),
      rgbHtlcMinMsat: _intOrNull(map['rgbHtlcMinMsat']),
      rgbChannelCapacityMinSat: _intOrNull(map['rgbChannelCapacityMinSat']),
      channelCapacityMinSat: _intOrNull(map['channelCapacityMinSat']),
      channelCapacityMaxSat: _intOrNull(map['channelCapacityMaxSat']),
      channelAssetMinAmount: _intOrNull(map['channelAssetMinAmount']),
      channelAssetMaxAmount: _uint64OrNull(
        map['channelAssetMaxAmount'],
        'RlnNodeInfo.channelAssetMaxAmount',
      ),
      networkNodes: _intOrNull(map['networkNodes']),
      networkChannels: _intOrNull(map['networkChannels']),
      latestRgsSnapshotTimestamp: _intOrNull(map['latestRgsSnapshotTimestamp']),
    );
  }

  final String pubkey;
  final int numChannels;
  final int numUsableChannels;

  /// Local channel balance in sats.
  final int localBalanceSat;

  /// Eventual close fees in sats.
  final int? eventualCloseFeesSat;

  /// Pending outbound payment total in sats.
  final int? pendingOutboundPaymentsSat;
  final int numPeers;
  final String? accountXpubVanilla;
  final String? accountXpubColored;
  final int? maxMediaUploadSizeMb;

  /// Minimum RGB HTLC value in millisats.
  final int? rgbHtlcMinMsat;

  /// Minimum RGB channel capacity in sats.
  final int? rgbChannelCapacityMinSat;

  /// Minimum channel capacity in sats.
  final int? channelCapacityMinSat;

  /// Maximum channel capacity in sats.
  final int? channelCapacityMaxSat;

  /// Minimum channel RGB asset amount in the asset's smallest unit.
  final int? channelAssetMinAmount;

  /// Maximum channel RGB asset amount in the asset's smallest unit.
  final BigInt? channelAssetMaxAmount;
  final int? networkNodes;
  final int? networkChannels;

  /// Latest RGS snapshot Unix timestamp in seconds.
  final int? latestRgsSnapshotTimestamp;
}

/// Current chain/network state seen by the node.
class RlnNetworkInfo {
  const RlnNetworkInfo({required this.network, required this.height});

  factory RlnNetworkInfo.fromMap(RlnMap map) {
    return RlnNetworkInfo(
      network: _requiredString(map, 'network', 'RlnNetworkInfo'),
      height: _requiredInt(map, 'height', 'RlnNetworkInfo'),
    );
  }

  final String network;
  final int height;
}

/// Common settled/future/spendable balance tuple.
class RlnBalance {
  const RlnBalance({
    required this.settled,
    required this.future,
    required this.spendable,
  });

  factory RlnBalance.fromMap(RlnMap map) {
    return RlnBalance(
      settled: _requiredInt(map, 'settled', 'RlnBalance'),
      future: _requiredInt(map, 'future', 'RlnBalance'),
      spendable: _requiredInt(map, 'spendable', 'RlnBalance'),
    );
  }

  /// Settled balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int settled;

  /// Pending/future balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int future;

  /// Spendable balance. Bitcoin balances are sats; RGB balances are asset
  /// smallest units according to precision.
  final int spendable;
}

/// Bitcoin balance split by vanilla and colored wallet domains.
class RlnBtcBalance {
  const RlnBtcBalance({required this.vanilla, required this.colored});

  factory RlnBtcBalance.fromMap(RlnMap map) {
    return RlnBtcBalance(
      vanilla: RlnBalance.fromMap(
        _requiredMap(map, 'vanilla', 'RlnBtcBalance'),
      ),
      colored: RlnBalance.fromMap(
        _requiredMap(map, 'colored', 'RlnBtcBalance'),
      ),
    );
  }

  final RlnBalance vanilla;
  final RlnBalance colored;
}

/// RGB asset balance, including off-chain channel amounts.
class RlnAssetBalance {
  const RlnAssetBalance({
    required this.settled,
    required this.future,
    required this.spendable,
    required this.offchainOutbound,
    required this.offchainInbound,
  });

  factory RlnAssetBalance.fromMap(RlnMap map) {
    return RlnAssetBalance(
      settled: _requiredUInt64(map, 'settled', 'RlnAssetBalance'),
      future: _requiredUInt64(map, 'future', 'RlnAssetBalance'),
      spendable: _requiredUInt64(map, 'spendable', 'RlnAssetBalance'),
      offchainOutbound: _requiredUInt64(
        map,
        'offchainOutbound',
        'RlnAssetBalance',
      ),
      offchainInbound: _requiredUInt64(
        map,
        'offchainInbound',
        'RlnAssetBalance',
      ),
    );
  }

  /// Off-chain outbound RGB amount in the asset's smallest unit.
  final BigInt offchainOutbound;

  /// Off-chain inbound RGB amount in the asset's smallest unit.
  final BigInt offchainInbound;

  /// Settled RGB units, before applying the asset precision.
  final BigInt settled;

  /// Future RGB units, including pending transfers.
  final BigInt future;

  /// Spendable RGB units; not necessarily the same as the total balance.
  final BigInt spendable;
}

/// Media metadata attached to RGB assets or tokens.
class RlnMedia {
  const RlnMedia({
    required this.filePath,
    required this.digest,
    required this.mime,
  });

  factory RlnMedia.fromMap(RlnMap map) {
    return RlnMedia(
      filePath: _requiredString(map, 'filePath', 'RlnMedia'),
      digest: _requiredString(map, 'digest', 'RlnMedia'),
      mime: _requiredString(map, 'mime', 'RlnMedia'),
    );
  }

  final String filePath;
  final String digest;
  final String mime;
}

class RlnTokenLight {
  RlnTokenLight({
    required this.index,
    this.ticker,
    this.name,
    this.details,
    required this.embeddedMedia,
    this.media,
    required List<RlnMediaAttachment> attachments,
    required this.reserves,
  }) : attachments = List<RlnMediaAttachment>.unmodifiable(attachments);

  factory RlnTokenLight.fromMap(RlnMap map) {
    return RlnTokenLight(
      index: _requiredInt(map, 'index', 'RlnTokenLight'),
      ticker: _stringOrNull(map['ticker']),
      name: _stringOrNull(map['name']),
      details: _stringOrNull(map['details']),
      embeddedMedia: _requiredBool(map, 'embeddedMedia', 'RlnTokenLight'),
      media: map['media'] == null
          ? null
          : RlnMedia.fromMap(_map(map['media'], 'RlnTokenLight.media')),
      attachments: _mapList(
        map['attachments'],
        'RlnTokenLight.attachments',
      ).map(RlnMediaAttachment.fromMap).toList(growable: false),
      reserves: _requiredBool(map, 'reserves', 'RlnTokenLight'),
    );
  }

  final int index;
  final String? ticker;
  final String? name;
  final String? details;
  final bool embeddedMedia;
  final RlnMedia? media;
  final List<RlnMediaAttachment> attachments;
  final bool reserves;
}

class RlnMediaAttachment {
  const RlnMediaAttachment({required this.key, this.media});

  factory RlnMediaAttachment.fromMap(RlnMap map) {
    return RlnMediaAttachment(
      key: _requiredInt(map, 'key', 'RlnMediaAttachment'),
      media: map['media'] == null
          ? null
          : RlnMedia.fromMap(_map(map['media'], 'RlnMediaAttachment.media')),
    );
  }

  final int key;
  final RlnMedia? media;
}

/// Base type for typed RGB assets.
sealed class RlnAsset {
  const RlnAsset({
    required this.assetId,
    required this.name,
    this.details,
    required this.precision,
    required this.timestamp,
    required this.addedAt,
    required this.balance,
  });

  final String assetId;
  final String name;
  final String? details;
  final int precision;

  /// Asset issuance Unix timestamp in seconds.
  final int timestamp;

  /// Asset wallet-addition Unix timestamp in seconds.
  final int addedAt;
  final RlnAssetBalance balance;
}

/// Fungible NIA RGB asset.
class RlnAssetNia extends RlnAsset {
  const RlnAssetNia({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required this.issuedSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
  });

  factory RlnAssetNia.fromMap(RlnMap map) {
    return RlnAssetNia(
      assetId: _requiredString(map, 'assetId', 'RlnAssetNia'),
      ticker: _requiredString(map, 'ticker', 'RlnAssetNia'),
      name: _requiredString(map, 'name', 'RlnAssetNia'),
      details: _stringOrNull(map['details']),
      precision: _requiredInt(map, 'precision', 'RlnAssetNia'),
      issuedSupply: _requiredUInt64(map, 'issuedSupply', 'RlnAssetNia'),
      timestamp: _requiredInt(map, 'timestamp', 'RlnAssetNia'),
      addedAt: _requiredInt(map, 'addedAt', 'RlnAssetNia'),
      balance: RlnAssetBalance.fromMap(
        _requiredMap(map, 'balance', 'RlnAssetNia'),
      ),
      media: map['media'] == null
          ? null
          : RlnMedia.fromMap(_map(map['media'], 'RlnAssetNia.media')),
    );
  }

  final String ticker;
  final BigInt issuedSupply;
  final RlnMedia? media;
}

/// Bridged fungible RGB asset. Monetary fields preserve the full native u64.
class RlnAssetBfa extends RlnAsset {
  const RlnAssetBfa({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required this.initialSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
    this.rejectListUrl,
  });

  factory RlnAssetBfa.fromMap(RlnMap map) => RlnAssetBfa(
    assetId: _requiredString(map, 'assetId', 'RlnAssetBfa'),
    ticker: _requiredString(map, 'ticker', 'RlnAssetBfa'),
    name: _requiredString(map, 'name', 'RlnAssetBfa'),
    details: _optionalString(map, 'details', 'RlnAssetBfa'),
    precision: _requiredInt(map, 'precision', 'RlnAssetBfa'),
    initialSupply: _requiredUInt64(map, 'initialSupply', 'RlnAssetBfa'),
    timestamp: _requiredInt(map, 'timestamp', 'RlnAssetBfa'),
    addedAt: _requiredInt(map, 'addedAt', 'RlnAssetBfa'),
    balance: RlnAssetBalance.fromMap(
      _requiredMap(map, 'balance', 'RlnAssetBfa'),
    ),
    media: map['media'] == null
        ? null
        : RlnMedia.fromMap(_map(map['media'], 'RlnAssetBfa.media')),
    rejectListUrl: _optionalString(map, 'rejectListUrl', 'RlnAssetBfa'),
  );

  final String ticker;
  final BigInt initialSupply;
  final RlnMedia? media;
  final String? rejectListUrl;
}

/// Collectible CFA RGB asset.
class RlnAssetCfa extends RlnAsset {
  const RlnAssetCfa({
    required super.assetId,
    required super.name,
    super.details,
    required super.precision,
    required this.issuedSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
  });

  factory RlnAssetCfa.fromMap(RlnMap map) {
    return RlnAssetCfa(
      assetId: _requiredString(map, 'assetId', 'RlnAssetCfa'),
      name: _requiredString(map, 'name', 'RlnAssetCfa'),
      details: _stringOrNull(map['details']),
      precision: _requiredInt(map, 'precision', 'RlnAssetCfa'),
      issuedSupply: _requiredUInt64(map, 'issuedSupply', 'RlnAssetCfa'),
      timestamp: _requiredInt(map, 'timestamp', 'RlnAssetCfa'),
      addedAt: _requiredInt(map, 'addedAt', 'RlnAssetCfa'),
      balance: RlnAssetBalance.fromMap(
        _requiredMap(map, 'balance', 'RlnAssetCfa'),
      ),
      media: map['media'] == null
          ? null
          : RlnMedia.fromMap(_map(map['media'], 'RlnAssetCfa.media')),
    );
  }

  final BigInt issuedSupply;
  final RlnMedia? media;
}

/// RGB outpoint used by linked-asset issuance metadata.
class RlnRgbOutpoint {
  const RlnRgbOutpoint({required this.txid, required this.vout});

  factory RlnRgbOutpoint.fromMap(RlnMap map) {
    final vout = _requiredInt(map, 'vout', 'RlnRgbOutpoint');
    if (vout < 0 || vout > 0xFFFFFFFF) {
      throw const NativeProtocolException(
        'RlnRgbOutpoint.vout must fit in UInt32.',
        field: 'RlnRgbOutpoint.vout',
      );
    }
    return RlnRgbOutpoint(
      txid: _requiredString(map, 'txid', 'RlnRgbOutpoint'),
      vout: vout,
    );
  }

  final String txid;
  final int vout;
}

/// Inflation-capable IFA RGB asset.
class RlnAssetIfa extends RlnAsset {
  const RlnAssetIfa({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required this.initialSupply,
    required this.maxSupply,
    required this.knownCirculatingSupply,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.media,
    this.rejectListUrl,
    this.issuanceLinkRightOutpoint,
    this.linkedFromAssetId,
    this.linkedToAssetId,
  });

  factory RlnAssetIfa.fromMap(RlnMap map) {
    return RlnAssetIfa(
      assetId: _requiredString(map, 'assetId', 'RlnAssetIfa'),
      ticker: _requiredString(map, 'ticker', 'RlnAssetIfa'),
      name: _requiredString(map, 'name', 'RlnAssetIfa'),
      details: _stringOrNull(map['details']),
      precision: _requiredInt(map, 'precision', 'RlnAssetIfa'),
      initialSupply: _requiredUInt64(map, 'initialSupply', 'RlnAssetIfa'),
      maxSupply: _requiredUInt64(map, 'maxSupply', 'RlnAssetIfa'),
      knownCirculatingSupply: _requiredUInt64(
        map,
        'knownCirculatingSupply',
        'RlnAssetIfa',
      ),
      timestamp: _requiredInt(map, 'timestamp', 'RlnAssetIfa'),
      addedAt: _requiredInt(map, 'addedAt', 'RlnAssetIfa'),
      balance: RlnAssetBalance.fromMap(
        _requiredMap(map, 'balance', 'RlnAssetIfa'),
      ),
      media: map['media'] == null
          ? null
          : RlnMedia.fromMap(_map(map['media'], 'RlnAssetIfa.media')),
      rejectListUrl: _stringOrNull(map['rejectListUrl']),
      issuanceLinkRightOutpoint: map['issuanceLinkRightOutpoint'] == null
          ? null
          : RlnRgbOutpoint.fromMap(
              _map(
                map['issuanceLinkRightOutpoint'],
                'RlnAssetIfa.issuanceLinkRightOutpoint',
              ),
            ),
      linkedFromAssetId: _optionalString(
        map,
        'linkedFromAssetId',
        'RlnAssetIfa',
        allowEmpty: false,
      ),
      linkedToAssetId: _optionalString(
        map,
        'linkedToAssetId',
        'RlnAssetIfa',
        allowEmpty: false,
      ),
    );
  }

  final String ticker;
  final BigInt initialSupply;
  final BigInt maxSupply;
  final BigInt knownCirculatingSupply;
  final RlnMedia? media;
  final String? rejectListUrl;
  final RlnRgbOutpoint? issuanceLinkRightOutpoint;
  final String? linkedFromAssetId;
  final String? linkedToAssetId;
}

/// Unique digital asset.
class RlnAssetUda extends RlnAsset {
  const RlnAssetUda({
    required super.assetId,
    required this.ticker,
    required super.name,
    super.details,
    required super.precision,
    required super.timestamp,
    required super.addedAt,
    required super.balance,
    this.token,
  });

  factory RlnAssetUda.fromMap(RlnMap map) {
    return RlnAssetUda(
      assetId: _requiredString(map, 'assetId', 'RlnAssetUda'),
      ticker: _requiredString(map, 'ticker', 'RlnAssetUda'),
      name: _requiredString(map, 'name', 'RlnAssetUda'),
      details: _stringOrNull(map['details']),
      precision: _requiredInt(map, 'precision', 'RlnAssetUda'),
      timestamp: _requiredInt(map, 'timestamp', 'RlnAssetUda'),
      addedAt: _requiredInt(map, 'addedAt', 'RlnAssetUda'),
      balance: RlnAssetBalance.fromMap(
        _requiredMap(map, 'balance', 'RlnAssetUda'),
      ),
      token: map['token'] == null
          ? null
          : RlnTokenLight.fromMap(_map(map['token'], 'RlnAssetUda.token')),
    );
  }

  final String ticker;
  final RlnTokenLight? token;
}

/// Asset groups returned by `listAssets`.
class RlnAssets {
  RlnAssets({
    List<RlnAssetBfa> bfa = const [],
    required List<RlnAssetNia> nia,
    required List<RlnAssetUda> uda,
    required List<RlnAssetCfa> cfa,
    required List<RlnAssetIfa> ifa,
  }) : bfa = List<RlnAssetBfa>.unmodifiable(bfa),
       nia = List<RlnAssetNia>.unmodifiable(nia),
       uda = List<RlnAssetUda>.unmodifiable(uda),
       cfa = List<RlnAssetCfa>.unmodifiable(cfa),
       ifa = List<RlnAssetIfa>.unmodifiable(ifa);

  factory RlnAssets.fromMap(RlnMap map) {
    return RlnAssets(
      bfa: _mapList(
        map['bfa'],
        'RlnAssets.bfa',
      ).map(RlnAssetBfa.fromMap).toList(growable: false),
      nia: _mapList(
        map['nia'],
        'RlnAssets.nia',
      ).map(RlnAssetNia.fromMap).toList(growable: false),
      uda: _mapList(
        map['uda'],
        'RlnAssets.uda',
      ).map(RlnAssetUda.fromMap).toList(growable: false),
      cfa: _mapList(
        map['cfa'],
        'RlnAssets.cfa',
      ).map(RlnAssetCfa.fromMap).toList(growable: false),
      ifa: _mapList(
        map['ifa'],
        'RlnAssets.ifa',
      ).map(RlnAssetIfa.fromMap).toList(growable: false),
    );
  }

  final List<RlnAssetNia> nia;
  final List<RlnAssetBfa> bfa;
  final List<RlnAssetUda> uda;
  final List<RlnAssetCfa> cfa;
  final List<RlnAssetIfa> ifa;

  Iterable<String> get assetIds sync* {
    yield* bfa.map((asset) => asset.assetId);
    yield* nia.map((asset) => asset.assetId);
    yield* uda.map((asset) => asset.assetId);
    yield* cfa.map((asset) => asset.assetId);
    yield* ifa.map((asset) => asset.assetId);
  }
}

/// RGB invoice created by the wallet.
class RlnInvoice {
  const RlnInvoice({
    required this.invoice,
    required this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  factory RlnInvoice.fromMap(RlnMap map) {
    return RlnInvoice(
      invoice: _requiredString(map, 'invoice', 'RlnInvoice'),
      recipientId: _stringOrNull(map['recipientId']),
      expirationTimestamp: _intOrNull(map['expirationTimestamp']),
      batchTransferIdx: _requiredInt(map, 'batchTransferIdx', 'RlnInvoice'),
    );
  }

  final String invoice;
  final String? recipientId;
  final int? expirationTimestamp;
  final int batchTransferIdx;
}

/// Decoded RGB invoice data.
class RlnDecodedRgbInvoice {
  RlnDecodedRgbInvoice({
    required this.recipientId,
    required this.proxyRecipientId,
    required this.recipientType,
    this.assetSchema,
    this.assetId,
    required this.assignment,
    required this.network,
    this.expirationTimestamp,
    required List<String> transportEndpoints,
  }) : transportEndpoints = List<String>.unmodifiable(transportEndpoints);

  factory RlnDecodedRgbInvoice.fromMap(RlnMap map) {
    return RlnDecodedRgbInvoice(
      recipientId: _requiredString(map, 'recipientId', 'RlnDecodedRgbInvoice'),
      proxyRecipientId: _requiredString(
        map,
        'proxyRecipientId',
        'RlnDecodedRgbInvoice',
      ),
      recipientType: _requiredString(
        map,
        'recipientType',
        'RlnDecodedRgbInvoice',
      ),
      assetSchema: _stringOrNull(map['assetSchema']),
      assetId: _stringOrNull(map['assetId']),
      assignment: _requiredString(map, 'assignment', 'RlnDecodedRgbInvoice'),
      network: _requiredString(map, 'network', 'RlnDecodedRgbInvoice'),
      expirationTimestamp: _intOrNull(map['expirationTimestamp']),
      transportEndpoints: _stringList(
        map['transportEndpoints'],
        'RlnDecodedRgbInvoice.transportEndpoints',
        required: true,
      ),
    );
  }

  int? get assignmentAmount {
    final match = RegExp(r'\d+').firstMatch(assignment);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  final String recipientId;
  final String proxyRecipientId;
  final String recipientType;
  final String? assetSchema;
  final String? assetId;
  final String assignment;
  final String network;
  final int? expirationTimestamp;
  final List<String> transportEndpoints;
}

/// Result of an RGB send.
class RlnSendResult {
  const RlnSendResult({required this.txid, required this.batchTransferIdx});

  factory RlnSendResult.fromMap(RlnMap map) {
    return RlnSendResult(
      txid: _requiredString(map, 'txid', 'RlnSendResult'),
      batchTransferIdx: _requiredInt(map, 'batchTransferIdx', 'RlnSendResult'),
    );
  }

  final String txid;
  final int batchTransferIdx;
}

class RlnBlockTime {
  const RlnBlockTime({required this.height, required this.timestamp});

  factory RlnBlockTime.fromMap(RlnMap map) {
    return RlnBlockTime(
      height: _requiredInt(map, 'height', 'RlnBlockTime'),
      timestamp: _requiredInt(map, 'timestamp', 'RlnBlockTime'),
    );
  }

  /// Confirmation height.
  final int height;

  /// Block Unix timestamp in seconds.
  final int timestamp;
}

/// On-chain Bitcoin transaction.
class RlnTransaction {
  const RlnTransaction({
    required this.transactionType,
    required this.txid,
    required this.received,
    required this.sent,
    required this.fee,
    this.confirmationTime,
  });

  factory RlnTransaction.fromMap(RlnMap map) {
    return RlnTransaction(
      transactionType: _canonicalEnum(map['transactionType']),
      txid: _requiredString(map, 'txid', 'RlnTransaction'),
      received: _requiredSats(map, 'received', 'RlnTransaction'),
      sent: _requiredSats(map, 'sent', 'RlnTransaction'),
      fee: _requiredSats(map, 'fee', 'RlnTransaction'),
      confirmationTime: map['confirmationTime'] == null
          ? null
          : RlnBlockTime.fromMap(
              _map(map['confirmationTime'], 'RlnTransaction.confirmationTime'),
            ),
    );
  }

  final String transactionType;
  final String txid;

  /// Received Bitcoin amount in sats.
  final int received;

  /// Sent Bitcoin amount in sats.
  final int sent;

  /// Transaction fee in sats.
  final int fee;
  final RlnBlockTime? confirmationTime;
}

class RlnTransferTransportEndpoint {
  const RlnTransferTransportEndpoint({
    required this.endpoint,
    required this.transportType,
    required this.used,
  });

  factory RlnTransferTransportEndpoint.fromMap(RlnMap map) {
    return RlnTransferTransportEndpoint(
      endpoint: _requiredString(
        map,
        'endpoint',
        'RlnTransferTransportEndpoint',
      ),
      transportType: _requiredString(
        map,
        'transportType',
        'RlnTransferTransportEndpoint',
      ),
      used: _requiredBool(map, 'used', 'RlnTransferTransportEndpoint'),
    );
  }

  final String endpoint;
  final String transportType;
  final bool used;
}

/// RGB transfer state.
class RlnTransfer {
  RlnTransfer({
    required this.idx,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.requestedAssignment,
    required List<String> assignments,
    required this.kind,
    this.txid,
    this.recipientId,
    this.proxyRecipientId,
    this.receiveUtxo,
    this.changeUtxo,
    this.expiration,
    required List<RlnTransferTransportEndpoint> transportEndpoints,
    this.batchTransferIdx,
  }) : assignments = List<String>.unmodifiable(assignments),
       transportEndpoints = List<RlnTransferTransportEndpoint>.unmodifiable(
         transportEndpoints,
       );

  factory RlnTransfer.fromMap(RlnMap map) {
    return RlnTransfer(
      idx: _requiredInt(map, 'idx', 'RlnTransfer'),
      createdAt: _intOrNull(map['createdAt']),
      updatedAt: _intOrNull(map['updatedAt']),
      status: _requiredString(map, 'status', 'RlnTransfer'),
      requestedAssignment: _stringOrNull(map['requestedAssignment']),
      assignments: _stringList(map['assignments'], 'RlnTransfer.assignments'),
      kind: _stringOrNull(map['kind']),
      txid: _stringOrNull(map['txid']),
      recipientId: _stringOrNull(map['recipientId']),
      proxyRecipientId: _optionalString(
        map,
        'proxyRecipientId',
        'RlnTransfer',
        allowEmpty: false,
      ),
      receiveUtxo: _stringOrNull(map['receiveUtxo']),
      changeUtxo: _stringOrNull(map['changeUtxo']),
      expiration: _intOrNull(map['expiration']),
      transportEndpoints: _mapList(
        map['transportEndpoints'],
        'RlnTransfer.transportEndpoints',
      ).map(RlnTransferTransportEndpoint.fromMap).toList(growable: false),
      batchTransferIdx: _intOrNull(map['batchTransferIdx']),
    );
  }

  final int idx;

  /// Transfer creation Unix timestamp in seconds.
  final int? createdAt;

  /// Transfer update Unix timestamp in seconds.
  final int? updatedAt;
  final String status;
  final String? requestedAssignment;
  final List<String> assignments;
  final String? kind;
  final String? txid;
  final String? recipientId;
  final String? proxyRecipientId;
  final String? receiveUtxo;
  final String? changeUtxo;

  /// Transfer expiration Unix timestamp in seconds.
  final int? expiration;
  final List<RlnTransferTransportEndpoint> transportEndpoints;
  final int? batchTransferIdx;
}

/// Native transfer-refresh failure for one batch transfer.
class RlnRefreshFailure {
  const RlnRefreshFailure({required this.name, required this.message});

  factory RlnRefreshFailure.fromMap(RlnMap map) {
    return RlnRefreshFailure(
      name: _requiredString(map, 'name', 'RlnRefreshFailure'),
      message: _requiredString(map, 'message', 'RlnRefreshFailure'),
    );
  }

  final String name;
  final String message;
}

/// Native refresh outcome for one batch transfer.
class RlnRefreshedTransfer {
  const RlnRefreshedTransfer({this.updatedStatus, this.failure});

  factory RlnRefreshedTransfer.fromMap(RlnMap map) {
    return RlnRefreshedTransfer(
      updatedStatus: _optionalString(
        map,
        'updatedStatus',
        'RlnRefreshedTransfer',
        allowEmpty: false,
      ),
      failure: map['failure'] == null
          ? null
          : RlnRefreshFailure.fromMap(
              _map(map['failure'], 'RlnRefreshedTransfer.failure'),
            ),
    );
  }

  final String? updatedStatus;
  final RlnRefreshFailure? failure;
}

/// Native transfer-refresh result keyed by rgb-lib batch transfer ID.
class RlnRefreshTransfersResult {
  RlnRefreshTransfersResult({required Map<int, RlnRefreshedTransfer> transfers})
    : transfers = Map<int, RlnRefreshedTransfer>.unmodifiable(transfers);

  factory RlnRefreshTransfersResult.fromMap(RlnMap map) {
    final wireTransfers = _requiredMap(
      map,
      'transfers',
      'RlnRefreshTransfersResult',
    );
    final transfers = <int, RlnRefreshedTransfer>{};
    for (final entry in wireTransfers.entries) {
      final index = switch (entry.key) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      };
      if (index == null || index < -0x80000000 || index > 0x7FFFFFFF) {
        throw const NativeProtocolException(
          'RlnRefreshTransfersResult.transfers keys must be signed Int32 values.',
          field: 'RlnRefreshTransfersResult.transfers',
        );
      }
      if (transfers.containsKey(index)) {
        throw NativeProtocolException(
          'RlnRefreshTransfersResult.transfers contains duplicate key $index.',
          field: 'RlnRefreshTransfersResult.transfers',
        );
      }
      transfers[index] = RlnRefreshedTransfer.fromMap(
        _map(entry.value, 'RlnRefreshTransfersResult.transfers[$index]'),
      );
    }
    return RlnRefreshTransfersResult(transfers: transfers);
  }

  final Map<int, RlnRefreshedTransfer> transfers;
}

class RlnRgbAllocation {
  const RlnRgbAllocation({
    this.assetId,
    required this.assignment,
    required this.settled,
  });

  factory RlnRgbAllocation.fromMap(RlnMap map) {
    return RlnRgbAllocation(
      assetId: _stringOrNull(map['assetId']),
      assignment: _requiredString(map, 'assignment', 'RlnRgbAllocation'),
      settled: _requiredBool(map, 'settled', 'RlnRgbAllocation'),
    );
  }

  final String? assetId;
  final String assignment;
  final bool settled;
}

class RlnUtxo {
  const RlnUtxo({
    required this.outpoint,
    required this.btcAmount,
    required this.colorable,
    required this.exists,
  });

  factory RlnUtxo.fromMap(RlnMap map) {
    return RlnUtxo(
      outpoint: _requiredString(map, 'outpoint', 'RlnUtxo'),
      btcAmount: _requiredInt(map, 'btcAmount', 'RlnUtxo'),
      colorable: _requiredBool(map, 'colorable', 'RlnUtxo'),
      exists: _requiredBool(map, 'exists', 'RlnUtxo'),
    );
  }

  final String outpoint;
  final int btcAmount;
  final bool colorable;
  final bool exists;
}

/// Wallet UTXO and RGB allocations.
class RlnUnspent {
  RlnUnspent({
    required this.utxo,
    required List<RlnRgbAllocation> rgbAllocations,
    this.pendingBlinded = 0,
  }) : rgbAllocations = List<RlnRgbAllocation>.unmodifiable(rgbAllocations);

  factory RlnUnspent.fromMap(RlnMap map) {
    final pendingBlinded = _requiredInt(map, 'pendingBlinded', 'RlnUnspent');
    if (pendingBlinded < 0 || pendingBlinded > 0xffffffff) {
      throw const NativeProtocolException(
        'Pending blinded reservations must be a UInt32 count.',
        field: 'RlnUnspent.pendingBlinded',
      );
    }
    return RlnUnspent(
      utxo: RlnUtxo.fromMap(_requiredMap(map, 'utxo', 'RlnUnspent')),
      rgbAllocations: _mapList(
        map['rgbAllocations'],
        'RlnUnspent.rgbAllocations',
      ).map(RlnRgbAllocation.fromMap).toList(growable: false),
      pendingBlinded: pendingBlinded,
    );
  }

  final RlnUtxo utxo;
  final List<RlnRgbAllocation> rgbAllocations;
  final int pendingBlinded;
}

/// Decoded BOLT11 invoice.
class RlnDecodedLnInvoice {
  const RlnDecodedLnInvoice({
    this.amtMsat,
    required this.expirySec,
    required this.timestamp,
    this.assetId,
    this.assetAmount,
    this.description,
    this.descriptionHash,
    required this.paymentHash,
    required this.paymentSecret,
    this.payeePubkey,
    required this.network,
    this.minFinalCltvExpiryDelta,
  });

  factory RlnDecodedLnInvoice.fromMap(RlnMap map) {
    return RlnDecodedLnInvoice(
      amtMsat: _intOrNull(map['amtMsat']),
      expirySec: _requiredInt(map, 'expirySec', 'RlnDecodedLnInvoice'),
      timestamp: _requiredInt(map, 'timestamp', 'RlnDecodedLnInvoice'),
      assetId: _stringOrNull(map['assetId']),
      assetAmount: _uint64OrNull(map['assetAmount']),
      description: _optionalString(map, 'description', 'RlnDecodedLnInvoice'),
      descriptionHash: _optionalString(
        map,
        'descriptionHash',
        'RlnDecodedLnInvoice',
        allowEmpty: false,
      ),
      paymentHash: _requiredString(map, 'paymentHash', 'RlnDecodedLnInvoice'),
      paymentSecret: _requiredString(
        map,
        'paymentSecret',
        'RlnDecodedLnInvoice',
      ),
      payeePubkey: _stringOrNull(map['payeePubkey']),
      network: _requiredString(map, 'network', 'RlnDecodedLnInvoice'),
      minFinalCltvExpiryDelta: map['minFinalCltvExpiryDelta'] == null
          ? null
          : _requiredInt(map, 'minFinalCltvExpiryDelta', 'RlnDecodedLnInvoice'),
    );
  }

  /// Lightning invoice amount in millisats.
  final int? amtMsat;

  /// Lightning invoice expiry duration in seconds.
  final int expirySec;

  /// Lightning invoice creation Unix timestamp in seconds.
  final int timestamp;

  final String? assetId;

  /// RGB asset amount in the asset's smallest unit.
  final BigInt? assetAmount;
  final String? description;
  final String? descriptionHash;
  final String paymentHash;
  final String paymentSecret;
  final String? payeePubkey;
  final String network;
  final int? minFinalCltvExpiryDelta;
}

/// BOLT11 invoice created by RLN.
class RlnLnInvoice {
  const RlnLnInvoice({required this.invoice});

  factory RlnLnInvoice.fromMap(RlnMap map) {
    return RlnLnInvoice(
      invoice: _requiredString(map, 'invoice', 'RlnLnInvoice'),
    );
  }

  final String invoice;
}

/// Result returned by payment-send operations.
class RlnPaymentResult {
  const RlnPaymentResult({
    this.paymentId,
    this.paymentHash,
    this.paymentSecret,
    this.paymentPreimage,
    required this.status,
  });

  factory RlnPaymentResult.fromMap(RlnMap map) {
    return RlnPaymentResult(
      paymentId: _stringOrNull(map['paymentId']),
      paymentHash: _stringOrNull(map['paymentHash']),
      paymentSecret: _stringOrNull(map['paymentSecret']),
      paymentPreimage: _stringOrNull(map['paymentPreimage']),
      status: _pascalStatus(map['status'], 'RlnPaymentResult.status'),
    );
  }

  final String? paymentId;
  final String? paymentHash;
  final String? paymentSecret;
  final String? paymentPreimage;
  final String status;
}

/// Stored Lightning payment.
class RlnPayment {
  const RlnPayment({
    this.amtMsat,
    this.assetAmount,
    this.assetId,
    required this.paymentHash,
    this.paymentType,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.payeePubkey,
    this.preimage,
  });

  factory RlnPayment.fromMap(RlnMap map) {
    return RlnPayment(
      amtMsat: _intOrNull(map['amtMsat']),
      assetAmount: _uint64OrNull(map['assetAmount']),
      assetId: _stringOrNull(map['assetId']),
      paymentHash: _requiredString(map, 'paymentHash', 'RlnPayment'),
      paymentType: map['paymentType'] == null
          ? null
          : _pascalEnum(map['paymentType'], 'RlnPayment.paymentType'),
      status: map['status'] == null
          ? null
          : _pascalStatus(map['status'], 'RlnPayment.status'),
      createdAt: _requiredInt(map, 'createdAt', 'RlnPayment'),
      updatedAt: _requiredInt(map, 'updatedAt', 'RlnPayment'),
      payeePubkey: _stringOrNull(map['payeePubkey']),
      preimage:
          _stringOrNull(map['preimage']) ??
          _stringOrNull(map['paymentPreimage']) ??
          _stringOrNull(map['payment_preimage']),
    );
  }

  /// Lightning payment amount in millisats.
  final int? amtMsat;

  /// RGB asset amount in the asset's smallest unit.
  final BigInt? assetAmount;
  final String? assetId;
  final String paymentHash;
  final String? paymentType;
  final String? status;

  /// Payment creation Unix timestamp in seconds.
  final int createdAt;

  /// Payment update Unix timestamp in seconds.
  final int updatedAt;
  final String? payeePubkey;
  final String? preimage;
}

/// Lightning channel, optionally backed by an RGB asset.
class RlnChannel {
  const RlnChannel({
    required this.channelId,
    required this.peerPubkey,
    required this.status,
    required this.ready,
    required this.capacitySat,
    required this.localBalanceSat,
    required this.outboundBalanceMsat,
    required this.inboundBalanceMsat,
    this.nextOutboundHtlcLimitMsat,
    this.nextOutboundHtlcMinimumMsat,
    required this.isUsable,
    required this.public,
    this.fundingTxid,
    this.peerAlias,
    this.shortChannelId,
    this.assetId,
    this.assetLocalAmount,
    this.assetRemoteAmount,
    this.virtualOpenMode,
  });

  factory RlnChannel.fromMap(RlnMap map) {
    return RlnChannel(
      channelId: _requiredString(map, 'channelId', 'RlnChannel'),
      peerPubkey: _requiredString(map, 'peerPubkey', 'RlnChannel'),
      status: map['status'] == null ? null : _canonicalEnum(map['status']),
      ready: _requiredBool(map, 'ready', 'RlnChannel'),
      capacitySat: _requiredInt(map, 'capacitySat', 'RlnChannel'),
      localBalanceSat: _intOrNull(map['localBalanceSat']),
      outboundBalanceMsat: _intOrNull(map['outboundBalanceMsat']),
      inboundBalanceMsat: _intOrNull(map['inboundBalanceMsat']),
      nextOutboundHtlcLimitMsat: _intOrNull(map['nextOutboundHtlcLimitMsat']),
      nextOutboundHtlcMinimumMsat: _intOrNull(
        map['nextOutboundHtlcMinimumMsat'],
      ),
      isUsable: map['isUsable'] == null
          ? null
          : _requiredBool(map, 'isUsable', 'RlnChannel'),
      public: _requiredBool(map, 'public', 'RlnChannel'),
      fundingTxid: _stringOrNull(map['fundingTxid']),
      peerAlias: _stringOrNull(map['peerAlias']),
      shortChannelId: _intOrNull(map['shortChannelId']),
      assetId: _stringOrNull(map['assetId']),
      assetLocalAmount: _uint64OrNull(map['assetLocalAmount']),
      assetRemoteAmount: _uint64OrNull(map['assetRemoteAmount']),
      virtualOpenMode: _stringOrNull(map['virtualOpenMode']),
    );
  }

  final String channelId;
  final String peerPubkey;
  final String? status;
  final bool ready;

  /// Channel capacity in sats.
  final int capacitySat;

  /// Local channel balance in sats from the native RLN model.
  final int? localBalanceSat;

  /// Outbound Lightning balance in millisats.
  final int? outboundBalanceMsat;

  /// Inbound Lightning balance in millisats.
  final int? inboundBalanceMsat;

  /// Next outbound HTLC maximum in millisats.
  final int? nextOutboundHtlcLimitMsat;

  /// Next outbound HTLC minimum in millisats.
  final int? nextOutboundHtlcMinimumMsat;
  final bool? isUsable;
  final bool public;
  final String? fundingTxid;
  final String? peerAlias;
  final int? shortChannelId;
  final String? assetId;

  /// Local RGB asset amount in the asset's smallest unit.
  final BigInt? assetLocalAmount;

  /// Remote RGB asset amount in the asset's smallest unit.
  final BigInt? assetRemoteAmount;
  final String? virtualOpenMode;
}

/// Connected peer public key.
class RlnPeer {
  const RlnPeer({required this.pubkey});

  factory RlnPeer.fromMap(RlnMap map) {
    return RlnPeer(pubkey: _requiredString(map, 'pubkey', 'RlnPeer'));
  }

  final String pubkey;
}

/// Fee rate estimate returned by RLN.
class RlnFeeRate {
  const RlnFeeRate({required this.feeRate});

  factory RlnFeeRate.fromMap(RlnMap map) {
    return RlnFeeRate(feeRate: _requiredDouble(map, 'feeRate', 'RlnFeeRate'));
  }

  final double feeRate;
}

/// Indexer endpoint capability information returned by RLN.
class RlnIndexerCheck {
  const RlnIndexerCheck({required this.indexerProtocol});

  factory RlnIndexerCheck.fromMap(RlnMap map) {
    return RlnIndexerCheck(
      indexerProtocol: _requiredString(
        map,
        'indexerProtocol',
        'RlnIndexerCheck',
      ),
    );
  }

  final String indexerProtocol;
}

/// Invoice lifecycle status.
class RlnInvoiceStatus {
  const RlnInvoiceStatus({required this.status});

  factory RlnInvoiceStatus.fromMap(RlnMap map) {
    return RlnInvoiceStatus(status: _uppercaseStatus(map['status']));
  }

  final String status;
}

/// Result returned when opening a channel.
class RlnOpenChannelResult {
  const RlnOpenChannelResult({required this.temporaryChannelId});

  factory RlnOpenChannelResult.fromMap(RlnMap map) {
    return RlnOpenChannelResult(
      temporaryChannelId: _requiredString(
        map,
        'temporaryChannelId',
        'RlnOpenChannelResult',
      ),
    );
  }

  final String temporaryChannelId;
}
