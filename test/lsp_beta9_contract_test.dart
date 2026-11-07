import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/lsp/lsp_address_quote_verifier.dart';
import 'package:rgb_sdk_flutter/src/lsp/utexo_lsp_client.dart'
    show selectLspConnectionAddressForTesting;

const _targetHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _lnurlMetadata = '[["text/plain","Pay alice"]]';
const _lightningSignedMessagePrefix = 'Lightning Signed Message:';
const _zbase32Alphabet = 'ybndrfg8ejkmcpqxot1uwisza345h769';
final _testSecp256k1 = ECCurve_secp256k1();

LspSupportedAsset _asset(String id, String ticker) {
  return LspSupportedAsset(
    assetId: id,
    schema: 'Nia',
    ticker: ticker,
    name: '$ticker asset',
    precision: 2,
  );
}

LspGetInfoResponse _info({List<LspSupportedAsset>? assets}) {
  return LspGetInfoResponse(
    apiVersion: 1,
    pubkey: 'lsp-pubkey',
    network: 'regtest',
    host: '127.0.0.1',
    port: 9735,
    supportedAssets: assets ?? <LspSupportedAsset>[],
    minPaymentSizeMsat: BigInt.one,
    maxPaymentSizeMsat: BigInt.from(100000000),
    minChannelBalanceSat: BigInt.one,
    maxChannelBalanceSat: BigInt.from(1000000),
    minInitialClientBalanceMsat: BigInt.one,
    maxInitialClientBalanceMsat: BigInt.from(100000000),
    minChannelAssetAmount: BigInt.one,
    maxChannelAssetAmount: BigInt.from(1000000),
    lightningAddressMinSendableMsat: BigInt.one,
    lightningAddressMaxSendableMsat: BigInt.from(100000000),
  );
}

Map<String, Object?> _infoWire() {
  return <String, Object?>{
    'api_version': 1,
    'pubkey': 'lsp-pubkey',
    'network': 'regtest',
    'host': '127.0.0.1',
    'port': 9735,
    'supported_assets': <Object?>[
      <String, Object?>{
        'asset_id': 'rgb:source',
        'schema': 'Nia',
        'ticker': 'SOURCE',
        'name': 'Source asset',
        'precision': 2,
      },
    ],
    'min_payment_size_msat': '1',
    'max_payment_size_msat': '100000000',
    'min_channel_balance_sat': '1',
    'max_channel_balance_sat': '1000000',
    'min_initial_client_balance_msat': '1',
    'max_initial_client_balance_msat': '100000000',
    'min_channel_asset_amount': '1',
    'max_channel_asset_amount': '1000000',
    'virtual_channel_mode': 'trusted_no_broadcast',
    'lightning_address_min_sendable_msat': '1',
    'lightning_address_max_sendable_msat': '100000000',
  };
}

LightningChannel _channel({
  required String id,
  required String assetId,
  required int assetLocalAmount,
  String peer = 'lsp-pubkey',
  int outboundMsat = 1000000,
  int? inboundMsat = 500000,
  int? remoteMsat,
  bool usable = true,
}) {
  return LightningChannel(
    channelId: id,
    peerPubkey: peer,
    capacitySat: 100000,
    ready: true,
    isPublic: false,
    isUsable: usable,
    outboundBalanceMsat: outboundMsat,
    inboundBalanceMsat: inboundMsat,
    remoteBalanceMsat: remoteMsat,
    assetId: assetId,
    assetLocalAmount: BigInt.from(assetLocalAmount),
  );
}

DecodedLightningInvoice _decoded({
  required String hash,
  required int? amtMsat,
  required String? assetId,
  required int? assetAmount,
  String? payeePubkey,
  String? descriptionHash,
  int timestamp = 1700000000,
  int expirySec = 3600,
  String network = 'regtest',
}) {
  return DecodedLightningInvoice(
    amtMsat: amtMsat,
    expirySec: expirySec,
    timestamp: timestamp,
    assetId: assetId,
    assetAmount: assetAmount == null ? null : BigInt.from(assetAmount),
    descriptionHash: descriptionHash,
    paymentHash: hash,
    paymentSecret:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    payeePubkey: payeePubkey,
    network: network,
  );
}

CoreInvoiceData _decodedRgb({
  required String invoice,
  required String assetId,
  int? amount,
  int expiresAt = 1700003600,
  String network = 'regtest',
}) {
  return CoreInvoiceData(
    invoice: invoice,
    recipientId: 'recipient',
    assetSchema: 'Nia',
    assetId: assetId,
    network: network,
    assignment: amount == null
        ? const Assignment(type: 'Any')
        : Assignment(type: 'Fungible', amount: BigInt.from(amount)),
    expirationTimestamp: expiresAt,
    transportEndpoints: const <String>['rpc://proxy/json-rpc'],
  );
}

LspLightningSendResponse _relayQuote({
  String hash = _targetHash,
  String? inboundAsset = 'rgb:source',
  String? outboundAsset = 'rgb:target',
  int? inboundAssetAmount = 10,
  int? outboundAssetAmount = 10,
  int inboundMsat = 1010,
  int outboundMsat = 1000,
  int feeMsat = 10,
  bool converted = true,
  String? inboundPayee = 'lsp-pubkey',
  String? outboundPayee = 'recipient-pubkey',
  int expiresAt = 1700003600,
}) {
  return LspLightningSendResponse(
    lnInvoice: 'lnbc1hodl',
    paymentHash: hash,
    inbound: LspLightningSendLeg(
      assetId: inboundAsset,
      assetAmount: inboundAssetAmount,
      amtMsat: inboundMsat,
      payeePubkey: inboundPayee,
    ),
    outbound: LspLightningSendLeg(
      assetId: outboundAsset,
      assetAmount: outboundAssetAmount,
      amtMsat: outboundMsat,
      payeePubkey: outboundPayee,
    ),
    converted: converted,
    feeMsat: feeMsat,
    expiresAt: expiresAt,
  );
}

class _ApayFixture {
  const _ApayFixture({
    required this.discovery,
    required this.callback,
    required this.decoded,
    required this.hostPubkey,
  });

  final LspLnurlpDiscovery discovery;
  final LspLnurlpCallbackResponse callback;
  final DecodedLightningInvoice decoded;
  final String hostPubkey;
}

_ApayFixture _apayFixture({
  String invoice = 'lnbc1apay',
  int amtMsat = 3000,
  String? assetId = 'rgb:bridge',
  int? assetAmount = 10,
  String paymentHash = _targetHash,
  String username = 'alice',
  String domain = 'lsp.example',
  int createdAt = 1699999000,
  int expiresAt = 1700003600,
  LspSupportedAsset? payoutAsset,
  List<LspSupportedAsset>? acceptedAssets,
}) {
  final recipientSecret = BigInt.one;
  final recipient = _compressedTestPubkey(recipientSecret);
  final host = _compressedTestPubkey(BigInt.two);
  final batchId = Uint8List.fromList(List<int>.generate(16, (index) => index));
  final paymentHashBytes = _testHexDecode(paymentHash);
  final leaf = _testSha256(<int>[
    0,
    ...utf8.encode('UTEXO_APAY_HASH_V1'),
    ...recipient,
    ...batchId,
    ..._testUint64(100),
    ...paymentHashBytes,
  ]);
  final batchCommitment = <int>[
    ...utf8.encode('UTEXO_APAY_HASH_BATCH_V1'),
    ...recipient,
    ...host,
    ...batchId,
    ...leaf,
    ..._testUint64(1),
    ..._testUint64(createdAt),
    ..._testUint64(expiresAt),
  ];
  final addressCommitment = <int>[
    ...utf8.encode('UTEXO_APAY_LNADDR_V1'),
    ...recipient,
    ...utf8.encode(domain),
    ...utf8.encode(username),
    ..._testUint64(0),
  ];
  final recipientHex = _testHex(recipient);
  final hostHex = _testHex(host);
  final proof = ApayInvoiceProof(
    version: 1,
    recipientPubkey: recipientHex,
    hostPubkey: hostHex,
    batchId: _testHex(batchId),
    hashIndex: 100,
    paymentHash: paymentHash,
    batchRoot: _testHex(leaf),
    batchSize: 1,
    merkleProof: const <ApayMerkleProofElement>[],
    batchSig: _signTestLightningMessage(batchCommitment, recipientSecret),
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
  return _ApayFixture(
    discovery: LspLnurlpDiscovery(
      callback: 'https://$domain/pay/callback/$username',
      minSendable: 1000,
      maxSendable: 100000000,
      metadata: _lnurlMetadata,
      tag: 'payRequest',
      recipientPubkey: recipientHex,
      addressSig: _signTestLightningMessage(addressCommitment, recipientSecret),
      payoutAsset: payoutAsset,
      acceptedAssets: acceptedAssets,
    ),
    callback: LspLnurlpCallbackResponse(
      pr: invoice,
      routes: const <Object?>[],
      proof: proof,
    ),
    decoded: _decoded(
      hash: paymentHash,
      amtMsat: amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
      payeePubkey: hostHex,
      descriptionHash: sha256.convert(utf8.encode(_lnurlMetadata)).toString(),
    ),
    hostPubkey: hostHex,
  );
}

Uint8List _compressedTestPubkey(BigInt secret) {
  return (_testSecp256k1.G * secret)!.getEncoded(true);
}

String _signTestLightningMessage(List<int> message, BigInt secret) {
  final digest = _testSha256d(<int>[
    ...utf8.encode(_lightningSignedMessagePrefix),
    ...message,
  ]);
  final n = _testSecp256k1.n;
  final noncePoint = _testSecp256k1.G;
  final r = noncePoint.x!.toBigInteger()! % n;
  var s = (_testBytesToBigInt(digest) + r * secret) % n;
  var recoveryId = noncePoint.y!.toBigInteger()!.isOdd ? 1 : 0;
  if (s > n >> 1) {
    s = n - s;
    recoveryId ^= 1;
  }
  return _testZbase32(<int>[
    31 + recoveryId,
    ..._testIntBytes(r, 32),
    ..._testIntBytes(s, 32),
  ]);
}

String _testZbase32(List<int> bytes) {
  final output = StringBuffer();
  var buffer = 0;
  var pendingBits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    pendingBits += 8;
    while (pendingBits >= 5) {
      pendingBits -= 5;
      output.write(_zbase32Alphabet[(buffer >> pendingBits) & 0x1f]);
    }
    buffer &= (1 << pendingBits) - 1;
  }
  if (pendingBits > 0) {
    output.write(_zbase32Alphabet[(buffer << (5 - pendingBits)) & 0x1f]);
  }
  return output.toString();
}

Uint8List _testSha256(List<int> bytes) =>
    Uint8List.fromList(sha256.convert(bytes).bytes);

Uint8List _testSha256d(List<int> bytes) => _testSha256(_testSha256(bytes));

Uint8List _testUint64(int value) => _testIntBytes(BigInt.from(value), 8);

Uint8List _testIntBytes(BigInt value, int length) {
  final output = Uint8List(length);
  var current = value;
  for (var index = length - 1; index >= 0; index -= 1) {
    output[index] = (current & BigInt.from(0xff)).toInt();
    current >>= 8;
  }
  return output;
}

BigInt _testBytesToBigInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

String _testHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

String _mutateTestSignature(String value) {
  final replacement = value.endsWith('y') ? 'b' : 'y';
  return '${value.substring(0, value.length - 1)}$replacement';
}

Uint8List _testHexDecode(String value) {
  return Uint8List.fromList(<int>[
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

ApayInvoiceProof _copyProof(
  ApayInvoiceProof source, {
  int? version,
  String? recipientPubkey,
  String? hostPubkey,
  int? hashIndex,
  String? paymentHash,
  String? batchRoot,
  int? batchSize,
  List<ApayMerkleProofElement>? merkleProof,
  String? batchSig,
  int? createdAt,
  int? expiresAt,
}) {
  return ApayInvoiceProof(
    version: version ?? source.version,
    recipientPubkey: recipientPubkey ?? source.recipientPubkey,
    hostPubkey: hostPubkey ?? source.hostPubkey,
    batchId: source.batchId,
    hashIndex: hashIndex ?? source.hashIndex,
    paymentHash: paymentHash ?? source.paymentHash,
    batchRoot: batchRoot ?? source.batchRoot,
    batchSize: batchSize ?? source.batchSize,
    merkleProof: merkleProof ?? source.merkleProof,
    batchSig: batchSig ?? source.batchSig,
    createdAt: createdAt ?? source.createdAt,
    expiresAt: expiresAt ?? source.expiresAt,
  );
}

LspLnurlpDiscovery _copyDiscovery(
  LspLnurlpDiscovery source, {
  String? metadata,
  String? tag,
  String? recipientPubkey,
  String? addressSig,
  bool omitAddressSig = false,
}) {
  return LspLnurlpDiscovery(
    callback: source.callback,
    minSendable: source.minSendable,
    maxSendable: source.maxSendable,
    metadata: metadata ?? source.metadata,
    tag: tag ?? source.tag,
    recipientPubkey: recipientPubkey ?? source.recipientPubkey,
    addressSig: omitAddressSig ? null : addressSig ?? source.addressSig,
    payoutAsset: source.payoutAsset,
    acceptedAssets: source.acceptedAssets,
  );
}

DecodedLightningInvoice _copyDecoded(
  DecodedLightningInvoice source, {
  int? amtMsat,
  String? assetId,
  int? assetAmount,
  String? descriptionHash,
  String? paymentHash,
  String? payeePubkey,
  String? network,
  int? timestamp,
  int? expirySec,
}) {
  return DecodedLightningInvoice(
    amtMsat: amtMsat ?? source.amtMsat,
    expirySec: expirySec ?? source.expirySec,
    timestamp: timestamp ?? source.timestamp,
    assetId: assetId ?? source.assetId,
    assetAmount: assetAmount == null
        ? source.assetAmount
        : BigInt.from(assetAmount),
    description: source.description,
    descriptionHash: descriptionHash ?? source.descriptionHash,
    paymentHash: paymentHash ?? source.paymentHash,
    paymentSecret: source.paymentSecret,
    payeePubkey: payeePubkey ?? source.payeePubkey,
    network: network ?? source.network,
  );
}

void _verifyApayFixture(
  _ApayFixture fixture, {
  LspLnurlpDiscovery? discovery,
  ApayInvoiceProof? proof,
  DecodedLightningInvoice? decoded,
  String? expectedLspPubkey,
  bool requireApayProof = true,
  bool omitProof = false,
  String domain = 'lsp.example',
  String walletNetwork = 'regtest',
}) {
  LspAddressQuoteVerifier.verify(
    resolution: LspAddressResolution(
      discovery: discovery ?? fixture.discovery,
      callback: LspLnurlpCallbackResponse(
        pr: fixture.callback.pr,
        routes: const <Object?>[],
        proof: omitProof ? null : proof ?? fixture.callback.proof,
      ),
    ),
    invoice: decoded ?? fixture.decoded,
    username: 'alice',
    domain: domain,
    expectedAmtMsat: 3000,
    expectedAssetId: 'rgb:bridge',
    expectedAssetAmount: 10,
    walletNetwork: walletNetwork,
    nowEpochSeconds: 1700000100,
    expectedLspPubkey: expectedLspPubkey ?? fixture.hostPubkey,
    requireApayProof: requireApayProof,
  );
}

class _FakeWallet implements ILspWallet {
  List<LightningChannel> channels = <LightningChannel>[];
  List<LightningPayment> payments = <LightningPayment>[];
  Map<String, DecodedLightningInvoice> decoded =
      <String, DecodedLightningInvoice>{};
  Map<String, CoreInvoiceData> decodedRgb = <String, CoreInvoiceData>{};
  RlnInvoiceStatusValue receiveStatus = RlnInvoiceStatuses.pending;
  final List<String> events = <String>[];
  final List<String> paidInvoices = <String>[];
  int syncCalls = 0;
  String nodePubkey = 'wallet-pubkey';
  String? createdAssetId;
  int? createdAssetAmount;
  int? createdAmountSats;
  int? createdExpirySeconds;
  Duration createInvoiceDelay = Duration.zero;
  String networkName = 'regtest';

  @override
  String get network => networkName;

  @override
  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) async {
    return ApayNewResponse(
      requestId: 'request',
      hostNodeId: 'host',
      protocolVersion: 1,
      orderId: 'order',
      status: 'active',
      acceptedThroughIndex: 9,
      nextIndexExpected: 10,
      unusedHashes: 1,
      refillBatchSize: 10,
      firstHashIndex: 9,
      lastHashIndex: 9,
      hashes: const <ApayHashEntry>[
        ApayHashEntry(hashIndex: 9, paymentHash: _targetHash),
      ],
    );
  }

  @override
  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async {
    return const HodlInvoiceResult(changed: true);
  }

  @override
  Future<void> connectPeer(String peerPubkeyAndAddr) async {}

  @override
  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
  }) async {
    createdAmountSats = amountSats;
    createdAssetId = asset?.assetId;
    createdAssetAmount = asset?.amount;
    createdExpirySeconds = expirySeconds;
    if (createInvoiceDelay > Duration.zero) {
      await Future<void>.delayed(createInvoiceDelay);
    }
    return const LightningReceiveRequest(lnInvoice: 'lnbc1receive');
  }

  @override
  Future<DecodedLightningInvoice> decodeLnInvoice(String invoice) async {
    events.add('decode:$invoice');
    final value = decoded[invoice];
    if (value == null) {
      throw const NativeProtocolException(
        'Missing fake decoded invoice.',
        field: 'invoice',
      );
    }
    return value;
  }

  @override
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) async {
    events.add('decode-rgb:$invoice');
    final value = decodedRgb[invoice];
    if (value == null) {
      throw const NativeProtocolException(
        'Missing fake decoded RGB invoice.',
        field: 'invoice',
      );
    }
    return value;
  }

  @override
  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id) async {
    return receiveStatus;
  }

  @override
  Future<WalletNodeInfo> getNodeInfo() async {
    return WalletNodeInfo(
      pubkey: nodePubkey,
      numChannels: channels.length,
      numUsableChannels: channels.where((channel) => channel.ready).length,
      localBalanceSat: 0,
      numPeers: 1,
    );
  }

  @override
  Future<List<LightningChannel>> listChannels() async {
    return List<LightningChannel>.unmodifiable(channels);
  }

  @override
  Future<List<LightningPayment>> listPayments() async {
    return List<LightningPayment>.unmodifiable(payments);
  }

  @override
  Future<LightningSendRequest> payLightningInvoice({
    required String lnInvoice,
    int? amount,
    String? assetId,
    int? assetAmount,
  }) async {
    events.add('pay:$lnInvoice');
    paidInvoices.add(lnInvoice);
    return const LightningSendRequest(
      txid: _targetHash,
      status: RlnPaymentStatuses.pending,
    );
  }

  @override
  Future<void> syncWallet() async {
    syncCalls += 1;
  }
}

class _FakeLspClient implements IUtexoLspClient {
  LspLnurlpDiscovery localDiscovery = LspLnurlpDiscovery(
    callback: 'https://lsp.example/pay/callback/alice',
    minSendable: 1000,
    maxSendable: 100000000,
    metadata: _lnurlMetadata,
    tag: 'payRequest',
  );
  LspLnurlpDiscovery? externalDiscovery;
  LspLnurlpCallbackResponse callback = LspLnurlpCallbackResponse(
    pr: 'lnbc1address',
    routes: const <Object?>[],
  );
  LspLightningReceiveResponse receive = const LspLightningReceiveResponse(
    lnInvoice: 'lnbc1receive',
    rgbInvoice: 'rgb:invoice',
    mappingId: 'mapping',
  );
  LspOnchainSendResponse? onchainSendResponse;
  LspLightningSendResponse relay = _relayQuote();
  LspLightningSendStatusResponse relayStatus =
      const LspLightningSendStatusResponse(
        paymentHash: _targetHash,
        status: LspLightningSendStatuses.quoted,
      );
  LspGetInfoResponse info = _info();
  final List<Object> resolveErrors = <Object>[];
  final List<String> events = <String>[];
  bool closed = false;
  int resolveCalls = 0;
  int externalResolveCalls = 0;
  LspLightningReceiveRequest? lastReceive;
  LspOnchainSendRequest? lastOnchainSend;
  LspLightningSendRequest? lastRelayRequest;
  Object? relayFailure;
  String? lastRelayStatusHash;
  String? lastAssetId;
  int? lastAssetAmount;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<LspLnurlpDiscovery> discoverAddress(String username) async {
    return localDiscovery;
  }

  @override
  Future<LspLnurlpDiscovery> discoverExternalAddress(
    String domain,
    String username,
  ) async {
    return externalDiscovery ?? localDiscovery;
  }

  @override
  Future<LspGetInfoResponse> getInfo() async => info;

  @override
  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  ) async {
    return const LspLightningAddressByPubkeyResponse(
      username: 'alice',
      domain: 'lsp.example',
    );
  }

  @override
  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return callback;
  }

  @override
  Future<LspLightningReceiveResponse> lightningReceive(
    LspLightningReceiveRequest params,
  ) async {
    lastReceive = params;
    return receive;
  }

  @override
  Future<LspLightningSendResponse> lightningSend(
    LspLightningSendRequest params,
  ) async {
    events.add('quote:${params.invoice}');
    lastRelayRequest = params;
    if (relayFailure case final error?) throw error;
    return relay;
  }

  @override
  Future<LspLightningSendStatusResponse> lightningSendStatus(
    String paymentHash,
  ) async {
    lastRelayStatusHash = paymentHash;
    return relayStatus;
  }

  @override
  Future<LspOnchainSendResponse> onchainSend(
    LspOnchainSendRequest params,
  ) async {
    lastOnchainSend = params;
    return onchainSendResponse ??
        LspOnchainSendResponse(
          rgbInvoice: params.rgbInvoice,
          lnInvoice: 'lnbc1send',
          mappingId: 'mapping',
        );
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    resolveCalls += 1;
    lastAssetId = assetId;
    lastAssetAmount = assetAmount;
    if (resolveErrors.isNotEmpty) throw resolveErrors.removeAt(0);
    return callback;
  }

  @override
  Future<LspAddressResolution> resolveAddressWithDiscovery(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return LspAddressResolution(
      discovery: localDiscovery,
      callback: await resolveAddress(
        username,
        amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveExternalAddress(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    externalResolveCalls += 1;
    lastAssetId = assetId;
    lastAssetAmount = assetAmount;
    return callback;
  }

  @override
  Future<LspAddressResolution> resolveExternalAddressWithDiscovery(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return LspAddressResolution(
      discovery: externalDiscovery ?? localDiscovery,
      callback: await resolveExternalAddress(
        domain,
        username,
        amtMsat,
        assetId: assetId,
        assetAmount: assetAmount,
      ),
    );
  }
}

class _TestHttpClient extends http.BaseClient {
  _TestHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

class _AbortAwareHttpClient extends http.BaseClient {
  final abortObserved = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.AbortableRequest || request.abortTrigger == null) {
      throw StateError('Expected an abortable LSP request.');
    }
    await request.abortTrigger;
    abortObserved.complete();
    throw http.RequestAbortedException(request.url);
  }
}

UtexoLsp _lsp(
  _FakeWallet wallet,
  _FakeLspClient client, {
  String peerPubkey = 'lsp-pubkey',
}) {
  return UtexoLsp(
    wallet: wallet,
    peer: LspPeer(
      baseUrl: 'https://lsp.example/api',
      peerPubkey: peerPubkey,
      peerHost: 'lsp.example',
      peerPort: 9735,
      bearerToken: 'secret',
    ),
    httpClient: client,
    clock: () =>
        DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000, isUtc: true),
  );
}

void main() {
  group('beta.9 LSP HTTP contract', () {
    test(
      'maps discovery and never sends LSP credentials to foreign hosts',
      () async {
        final requests = <http.BaseRequest>[];
        final transport = _TestHttpClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(<String, Object?>{
              'callback': 'https://${request.url.host}/pay/callback/alice',
              'minSendable': 1000,
              'maxSendable': 5000,
              'metadata': '[]',
              'tag': 'payRequest',
              'recipient_pubkey': 'recipient',
              'address_sig': 'signature',
              'payout_asset': <String, Object?>{
                'asset_id': 'rgb:payout',
                'schema': 'Nia',
                'ticker': 'PAYOUT',
                'name': 'Payout',
                'precision': 2,
              },
              'accepted_assets': <Object?>[
                <String, Object?>{
                  'asset_id': 'rgb:payout',
                  'schema': 'Nia',
                  'ticker': 'PAYOUT',
                  'name': 'Payout',
                  'precision': 2,
                },
                <String, Object?>{
                  'asset_id': 'rgb:bridge',
                  'schema': 'Nia',
                  'ticker': 'BRIDGE',
                  'name': 'Bridge',
                  'precision': 2,
                },
              ],
            }),
            200,
          );
        });
        final client = UtexoLspClient(
          baseUrl: 'https://lsp.example/api',
          bearerToken: 'top-secret',
          httpClient: transport,
        );

        final local = await client.discoverAddress('alice');
        final external = await client.discoverExternalAddress(
          'wallet.example.com',
          'alice',
        );

        expect(local.payoutAsset?.assetId, 'rgb:payout');
        expect(local.acceptedAssets?.last.assetId, 'rgb:bridge');
        expect(local.recipientPubkey, 'recipient');
        expect(external.addressSig, 'signature');
        expect(requests.first.headers['Authorization'], 'Bearer top-secret');
        expect(requests.last.url.host, 'wallet.example.com');
        expect(requests.last.headers.containsKey('Authorization'), isFalse);
        client.close();
      },
    );

    test(
      'maps strict lightning_send request, response, and status shapes',
      () async {
        final requests = <http.BaseRequest>[];
        final client = UtexoLspClient(
          baseUrl: 'https://lsp.example/api',
          httpClient: _TestHttpClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/lightning_send')) {
              final body = jsonDecode((request as http.Request).body);
              expect(body, <String, Object?>{
                'invoice': 'lnbc1target',
                'pay_with_asset_id': 'rgb:source',
              });
              return http.Response(
                jsonEncode(<String, Object?>{
                  'ln_invoice': 'lnbc1hodl',
                  'payment_hash': _targetHash,
                  'inbound': <String, Object?>{
                    'asset_id': 'rgb:source',
                    'asset_amount': 10,
                    'amt_msat': 1010,
                    'payee_pubkey': 'lsp-pubkey',
                  },
                  'outbound': <String, Object?>{
                    'asset_id': 'rgb:target',
                    'asset_amount': 10,
                    'amt_msat': 1000,
                    'payee_pubkey': 'recipient-pubkey',
                  },
                  'converted': true,
                  'fee_msat': 10,
                  'expires_at': 1700003600,
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode(<String, Object?>{
                'payment_hash': _targetHash,
                'status': 'outbound_pending',
                'reason': 'routing',
              }),
              200,
            );
          }),
        );

        final quote = await client.lightningSend(
          const LspLightningSendRequest(
            invoice: 'lnbc1target',
            payWithAssetId: 'rgb:source',
          ),
        );
        final status = await client.lightningSendStatus(_targetHash);

        expect(quote.inbound.amtMsat, 1010);
        expect(quote.outbound.assetId, 'rgb:target');
        expect(quote.converted, isTrue);
        expect(status.status, LspLightningSendStatuses.outboundPending);
        expect(requests.last.url.path, '/api/lightning_send/$_targetHash');
      },
    );

    test('rejects incomplete relay responses and unknown statuses', () {
      expect(
        () => LspLightningSendResponse.fromWire(<String, Object?>{
          'ln_invoice': 'lnbc1hodl',
          'payment_hash': _targetHash,
          'inbound': <String, Object?>{'amt_msat': 1},
          'outbound': <String, Object?>{'amt_msat': 1},
        }),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => LspLightningSendStatusResponse.fromWire(<String, Object?>{
          'payment_hash': _targetHash,
          'status': 'invented',
        }),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => LspLightningSendResponse.fromWire(<String, Object?>{
          'ln_invoice': '   ',
          'payment_hash': _targetHash,
          'inbound': <String, Object?>{'amt_msat': 1},
          'outbound': <String, Object?>{'amt_msat': 1},
          'converted': false,
          'fee_msat': 0,
          'expires_at': 1,
        }),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => LspLnurlpDiscovery.fromWire(<String, Object?>{
          'callback': 'https://lsp.example/pay',
          'minSendable': 5000,
          'maxSendable': 1000,
        }),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => LspSupportedAsset.fromWire(<String, Object?>{
          'asset_id': 'rgb:asset',
          'schema': 'Nia',
          'name': 'Asset',
          'precision': 256,
        }),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => LspLnurlpCallbackResponse.fromWire(<String, Object?>{
          'pr': 'lnbc1invoice',
          'status': 200,
        }),
        throwsA(isA<NativeProtocolException>()),
      );
    });

    test('maps every remaining core beta.9 endpoint contract', () async {
      final requests = <http.Request>[];
      final transport = _TestHttpClient((baseRequest) async {
        final request = baseRequest as http.Request;
        requests.add(request);
        switch (request.url.path) {
          case '/api/get_info':
            return http.Response(jsonEncode(_infoWire()), 200);
          case '/api/lightning_address/by_pubkey/wallet-pubkey':
            return http.Response(
              jsonEncode(<String, Object?>{
                'username': 'alice',
                'domain': 'lsp.example',
                'recipient_pubkey': 'wallet-pubkey',
                'address_sig': 'address-signature',
              }),
              200,
            );
          case '/api/onchain_send':
            expect(jsonDecode(request.body), <String, Object?>{
              'rgb_invoice': 'rgb:recipient',
              'lninvoice': <String, Object?>{
                'amt_msat': 4000,
                'expiry_sec': 120,
                'asset_id': 'rgb:source',
                'asset_amount': 25,
              },
            });
            return http.Response(
              jsonEncode(<String, Object?>{
                'rgb_invoice': 'rgb:recipient',
                'ln_invoice': 'lnbc1funding',
                'mapping_id': 42,
              }),
              200,
            );
          case '/api/lightning_receive':
            expect(jsonDecode(request.body), <String, Object?>{
              'ln_invoice': 'lnbc1receive',
              'rgb_invoice': <String, Object?>{
                'asset_id': 'rgb:target',
                'min_confirmations': 2,
                'witness': true,
                'assignment': 'Fungible',
                'duration_seconds': 3600,
              },
            });
            return http.Response(
              jsonEncode(<String, Object?>{
                'ln_invoice': 'lnbc1receive',
                'rgb_invoice': 'rgb:lsp-issued',
                'mapping_id': 'mapping-2',
                'rgb_asset_id': 'rgb:canonical',
                'converted': true,
              }),
              200,
            );
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });
      final client = UtexoLspClient(
        baseUrl: 'https://lsp.example/api',
        bearerToken: 'top-secret',
        httpClient: transport,
      );

      final info = await client.getInfo();
      final address = await client.getLightningAddressByPubkey('wallet-pubkey');
      final onchain = await client.onchainSend(
        const LspOnchainSendRequest(
          rgbInvoice: 'rgb:recipient',
          ln: LspLnParams(
            amtMsat: 4000,
            expirySec: 120,
            assetId: 'rgb:source',
            assetAmount: 25,
          ),
        ),
      );
      final receive = await client.lightningReceive(
        const LspLightningReceiveRequest(
          lnInvoice: 'lnbc1receive',
          rgb: LspRgbParams(
            assetId: 'rgb:target',
            assignment: 'Fungible',
            durationSeconds: 3600,
            minConfirmations: 2,
            witness: 'invoice-recipient',
          ),
        ),
      );

      expect(info.virtualChannelMode, 'trusted_no_broadcast');
      expect(info.supportedAssets.single.assetId, 'rgb:source');
      expect(address.addressSig, 'address-signature');
      expect(onchain.mappingId, '42');
      expect(receive.rgbAssetId, 'rgb:canonical');
      expect(receive.converted, isTrue);
      expect(requests, hasLength(4));
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer top-secret',
        ),
        isTrue,
      );
      client.close();
      expect(transport.closed, isFalse);
    });

    test(
      'resolves local and external callbacks without credential leak',
      () async {
        final requests = <http.Request>[];
        final transport = _TestHttpClient((baseRequest) async {
          final request = baseRequest as http.Request;
          requests.add(request);
          if (request.url.path.contains('/.well-known/lnurlp/')) {
            final isExternal = request.url.host == 'wallet.example.com';
            return http.Response(
              jsonEncode(<String, Object?>{
                'callback': isExternal
                    ? 'https://callback.wallet.example.com/pay/alice'
                    : 'https://public-lsp.example/pay/callback/alice?tag=one',
                'minSendable': 1000,
                'maxSendable': 10000,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'pr': 'lnbc1quoted',
              'routes': <Object?>[],
            }),
            200,
          );
        });
        final client = UtexoLspClient(
          baseUrl: 'https://lsp.example/proxy',
          bearerToken: 'top-secret',
          httpClient: transport,
          closeHttpClient: true,
        );

        await client.resolveAddress(
          'alice',
          3000,
          assetId: 'rgb:source',
          assetAmount: 3,
        );
        await client.lnurlCallback('bob', 4000);
        await client.resolveExternalAddress(
          'wallet.example.com',
          'alice',
          5000,
          assetId: 'rgb:target',
          assetAmount: 5,
        );

        expect(requests[1].url.host, 'lsp.example');
        expect(requests[1].url.path, '/proxy/pay/callback/alice');
        expect(requests[1].url.queryParameters, <String, String>{
          'tag': 'one',
          'amount': '3000',
          'asset_id': 'rgb:source',
          'asset_amount': '3',
        });
        expect(requests[2].url.path, '/proxy/pay/callback/bob');
        expect(requests[3].url.host, 'wallet.example.com');
        expect(requests[4].url.host, 'callback.wallet.example.com');
        expect(requests[4].url.queryParameters, <String, String>{
          'amount': '5000',
          'asset_id': 'rgb:target',
          'asset_amount': '5',
        });
        expect(requests[3].headers.containsKey('Authorization'), isFalse);
        expect(requests[4].headers.containsKey('Authorization'), isFalse);
        client.close();
        expect(transport.closed, isTrue);
      },
    );

    test('fails closed on malformed and unsafe LSP URLs', () async {
      expect(
        () => UtexoLspClient(baseUrl: '%'),
        throwsA(isA<WalletValidationException>()),
      );

      final unsafeCallbackClient = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient((request) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'callback': 'https://127.0.0.1/private?k1=secret',
              'minSendable': 1,
              'maxSendable': 10,
            }),
            200,
          );
        }),
      );
      await expectLater(
        unsafeCallbackClient.resolveExternalAddress(
          'wallet.example.com',
          'alice',
          1,
        ),
        throwsA(isA<LspTransportPolicyException>()),
      );
      await expectLater(
        unsafeCallbackClient.discoverExternalAddress(
          'wallet.example.com/path',
          'alice',
        ),
        throwsA(isA<ValidationError>()),
      );
      for (final domain in <String>[
        '0.0.0.0',
        '10.0.2.2',
        '10.1.2.3',
        '100.64.0.1',
        '169.254.169.254',
        '172.16.0.1',
        '192.168.1.1',
        '[fc00::1]',
        '[fe80::1]',
        'service.internal',
        'service.local',
        'single-label',
      ]) {
        await expectLater(
          unsafeCallbackClient.discoverExternalAddress(domain, 'alice'),
          throwsA(isA<LspTransportPolicyException>()),
          reason: domain,
        );
      }

      final privateCallbackClient = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient((request) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'callback': 'https://192.168.1.2/pay/alice',
              'minSendable': 1,
              'maxSendable': 10,
            }),
            200,
          );
        }),
      );
      await expectLater(
        privateCallbackClient.resolveExternalAddress(
          'wallet.example.com',
          'alice',
          1,
        ),
        throwsA(isA<LspTransportPolicyException>()),
      );

      expect(
        () => UtexoLspClient(baseUrl: 'http://10.0.2.2:3000'),
        returnsNormally,
      );
      final publicUri = Uri.parse('https://wallet.example.com/pay');
      expect(
        selectLspConnectionAddressForTesting(publicUri, <InternetAddress>[
          InternetAddress('93.184.216.34'),
        ]).address,
        '93.184.216.34',
      );
      expect(
        () => selectLspConnectionAddressForTesting(publicUri, <InternetAddress>[
          InternetAddress('93.184.216.34'),
          InternetAddress('127.0.0.1'),
        ]),
        throwsA(isA<LspTransportPolicyException>()),
      );
      for (final privateAddress in <String>[
        '::1',
        'fc00::1',
        'fe80::1',
        '::ffff:127.0.0.1',
        '::10.0.0.1',
      ]) {
        expect(
          () => selectLspConnectionAddressForTesting(
            publicUri,
            <InternetAddress>[InternetAddress(privateAddress)],
          ),
          throwsA(isA<LspTransportPolicyException>()),
          reason: privateAddress,
        );
      }
      final malformedCallbackClient = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient((request) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'callback': 'not-an-absolute-path',
              'minSendable': 1,
              'maxSendable': 10,
            }),
            200,
          );
        }),
      );
      await expectLater(
        malformedCallbackClient.resolveExternalAddress(
          'wallet.example.com',
          'alice',
          1,
        ),
        throwsA(isA<NativeProtocolException>()),
      );

      final error = const LspError(
        endpoint: 'https://wallet.example/callback?k1=secret#fragment',
        status: 500,
        body: 'failed',
      );
      expect(error.toJson()['endpoint'], 'https://wallet.example/callback');
      expect(error.toString(), isNot(contains('secret')));

      final credentialError = const LspError(
        endpoint: 'https://alice:secret@wallet.example/callback',
        status: 500,
        body: 'failed',
      );
      expect(
        credentialError.toJson()['endpoint'],
        'https://wallet.example/callback',
      );
      expect(credentialError.toString(), isNot(contains('alice')));
      expect(credentialError.toString(), isNot(contains('secret')));
    });

    test(
      'redacts path secrets after removing endpoint credentials and query',
      () {
        final paymentHash = List.filled(64, 'a').join();
        for (final endpoint in [
          'https://alice:password@wallet.example/lightning_send/$paymentHash?token=secret#private',
          '/lightning_send/$paymentHash?token=secret',
        ]) {
          final error = LspError(
            endpoint: endpoint,
            status: 500,
            body: 'failed',
          );
          for (final diagnostic in [
            error.toString(),
            jsonEncode(error.toJson()),
          ]) {
            expect(diagnostic, isNot(contains(paymentHash)));
            expect(diagnostic, isNot(contains('secret')));
            expect(diagnostic, isNot(contains('password')));
            expect(diagnostic, contains('REDACTED_HEX'));
          }
        }
      },
    );

    test('transport policy diagnostics disclose only the endpoint origin', () {
      final paymentHash = List.filled(64, 'b').join();
      final error = LspTransportPolicyException(
        'Blocked callback.',
        uri: Uri.parse(
          'https://alice:password@wallet.example:8443/callback/$paymentHash?token=secret#private',
        ),
      );
      expect(error.toJson()['uri'], 'https://wallet.example:8443');
      for (final diagnostic in [error.toString(), jsonEncode(error.toJson())]) {
        expect(diagnostic, isNot(contains(paymentHash)));
        expect(diagnostic, isNot(contains('secret')));
        expect(diagnostic, isNot(contains('password')));
        expect(diagnostic, isNot(contains('alice')));
      }
    });

    test('rejects redirects and oversized LSP responses', () async {
      final requests = <http.BaseRequest>[];
      final redirecting = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient((request) async {
          requests.add(request);
          return http.Response(
            '',
            302,
            headers: const <String, String>{
              'location': 'http://127.0.0.1/private',
            },
          );
        }),
      );

      await expectLater(
        redirecting.getInfo(),
        throwsA(isA<LspError>().having((error) => error.status, 'status', 302)),
      );
      expect(requests, hasLength(1));
      expect(requests.single.followRedirects, isFalse);

      final oversized = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient(
          (_) async => http.Response('x' * (1024 * 1024 + 1), 200),
        ),
      );
      await expectLater(
        oversized.getInfo(),
        throwsA(
          isA<LspError>().having(
            (error) => error.body,
            'body',
            contains('1048576-byte limit'),
          ),
        ),
      );
    });

    test(
      'aborts the underlying HTTP request when its deadline expires',
      () async {
        final transport = _AbortAwareHttpClient();
        final client = UtexoLspClient(
          baseUrl: 'https://lsp.example',
          timeoutMs: 10,
          httpClient: transport,
        );

        await expectLater(
          client.getInfo(),
          throwsA(
            isA<LspError>()
                .having((error) => error.status, 'status', 0)
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<TimeoutException>(),
                ),
          ),
        );
        await expectLater(
          transport.abortObserved.future.timeout(const Duration(seconds: 1)),
          completes,
        );
      },
    );

    test('redacts invoice material from LSP diagnostics', () async {
      const invoice = 'lnbc1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';
      final client = UtexoLspClient(
        baseUrl: 'https://lsp.example',
        httpClient: _TestHttpClient(
          (_) async => http.Response(
            '{"invoice":"$invoice","message":"could not pay $invoice"}',
            500,
          ),
        ),
      );

      await expectLater(
        client.getInfo(),
        throwsA(
          isA<LspError>()
              .having((error) => error.body, 'body', isNot(contains(invoice)))
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains(invoice)),
              ),
        ),
      );
    });

    test('rejects structurally invalid APay proof fields', () {
      Map<String, Object?> proof({
        int version = 1,
        int hashIndex = 1,
        int batchSize = 1,
        int createdAt = 1,
        int expiresAt = 2,
        String side = 'left',
      }) {
        return <String, Object?>{
          'version': version,
          'recipient_pubkey': 'recipient',
          'host_pubkey': 'host',
          'batch_id': 'batch',
          'hash_index': hashIndex,
          'payment_hash': _targetHash,
          'batch_root': 'root',
          'batch_size': batchSize,
          'merkle_proof': <Object?>[
            <String, Object?>{'sibling': 'sibling', 'side': side},
          ],
          'batch_sig': 'signature',
          'created_at': createdAt,
          'expires_at': expiresAt,
        };
      }

      expect(ApayInvoiceProof.fromWire(proof(hashIndex: 100)).hashIndex, 100);
      expect(
        () => ApayInvoiceProof.fromWire(proof(version: 2)),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => ApayInvoiceProof.fromWire(proof(hashIndex: 0x80000000)),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => ApayInvoiceProof.fromWire(proof(batchSize: 0)),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => ApayInvoiceProof.fromWire(proof(batchSize: 201)),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => ApayInvoiceProof.fromWire(proof(createdAt: 2, expiresAt: 1)),
        throwsA(isA<NativeProtocolException>()),
      );
      expect(
        () => ApayInvoiceProof.fromWire(proof(side: 'above')),
        throwsA(isA<NativeProtocolException>()),
      );
    });

    test('UtexoLsp disposal delegates to the injected client', () {
      final client = _FakeLspClient();
      final lsp = _lsp(_FakeWallet(), client);

      lsp.dispose();

      expect(client.closed, isTrue);
    });
  });

  group('APay cryptographic quote verification', () {
    test('accepts the canonical LDK recoverable-signature vector', () {
      expect(
        LspAddressQuoteVerifier.verifyLightningSignatureForTesting(
          message: utf8.encode('test message'),
          pubkey:
              '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
          signature:
              'd9tibmnic9t5y41hg7hkakdcra94akas9ku3rmmj4ag9mritc8ok4p5qzefs78c9pqfhpuftqqzhydbdwfg7u6w6wdxcqpqn4sj4e73e',
        ),
        isTrue,
      );
    });

    test('invalid secp256k1 points return typed quote failures', () {
      final fixture = _apayFixture();
      for (final invalid in ['02${'ff' * 32}', '02${'00' * 32}']) {
        expect(
          () => _verifyApayFixture(
            fixture,
            decoded: _copyDecoded(fixture.decoded, payeePubkey: invalid),
          ),
          throwsA(isA<LspAddressQuoteVerificationException>()),
        );
      }
    });

    test('accepts a fully bound APay quote and a proofless legacy quote', () {
      final fixture = _apayFixture();

      expect(() => _verifyApayFixture(fixture), returnsNormally);
      expect(
        () => _verifyApayFixture(
          fixture,
          omitProof: true,
          requireApayProof: false,
        ),
        returnsNormally,
      );
      expect(
        () => _verifyApayFixture(
          fixture,
          expectedLspPubkey: _testHex(_compressedTestPubkey(BigInt.from(3))),
          omitProof: true,
          requireApayProof: false,
        ),
        throwsA(isA<LspAddressQuoteVerificationException>()),
      );
      expect(
        () => _verifyApayFixture(fixture, omitProof: true),
        throwsA(isA<LspAddressQuoteVerificationException>()),
      );
    });

    test('accepts canonical network aliases and DNS domain casing', () {
      final fixture = _apayFixture();

      expect(
        () => _verifyApayFixture(
          fixture,
          decoded: _copyDecoded(fixture.decoded, network: 'signet'),
          walletNetwork: 'utexo',
        ),
        returnsNormally,
      );
      expect(
        () => _verifyApayFixture(fixture, walletNetwork: '3'),
        returnsNormally,
      );
      expect(
        () => _verifyApayFixture(fixture, domain: 'LSP.EXAMPLE'),
        returnsNormally,
      );
    });

    test('rejects altered invoice semantics before payment', () {
      final fixture = _apayFixture();
      final failures = <String, DecodedLightningInvoice>{
        'amount': _copyDecoded(fixture.decoded, amtMsat: 3001),
        'asset': _copyDecoded(fixture.decoded, assetId: 'rgb:other'),
        'asset amount': _copyDecoded(fixture.decoded, assetAmount: 11),
        'network': _copyDecoded(fixture.decoded, network: 'mainnet'),
        'metadata': _copyDecoded(
          fixture.decoded,
          descriptionHash:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        'payment hash': _copyDecoded(
          fixture.decoded,
          paymentHash:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        'payee': _copyDecoded(
          fixture.decoded,
          payeePubkey: _testHex(_compressedTestPubkey(BigInt.from(3))),
        ),
        'expired': _copyDecoded(
          fixture.decoded,
          timestamp: 1699990000,
          expirySec: 10,
        ),
        'future dated': _copyDecoded(fixture.decoded, timestamp: 1700001000),
      };

      for (final entry in failures.entries) {
        expect(
          () => _verifyApayFixture(fixture, decoded: entry.value),
          throwsA(isA<LspAddressQuoteVerificationException>()),
          reason: entry.key,
        );
      }
    });

    test('rejects altered APay membership, signatures, and validity', () {
      final fixture = _apayFixture();
      final proof = fixture.callback.proof!;
      final failures = <String, ApayInvoiceProof>{
        'version': _copyProof(proof, version: 2),
        'root': _copyProof(
          proof,
          batchRoot:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        'depth': _copyProof(proof, batchSize: 2),
        'batch signature': _copyProof(
          proof,
          batchSig: _mutateTestSignature(proof.batchSig),
        ),
        'expired': _copyProof(proof, expiresAt: 1700000000),
        'future dated': _copyProof(proof, createdAt: 1700001000),
        'derivation overflow': _copyProof(proof, hashIndex: 0x80000000),
        'wrong host': _copyProof(
          proof,
          hostPubkey: _testHex(_compressedTestPubkey(BigInt.from(3))),
        ),
      };

      for (final entry in failures.entries) {
        expect(
          () => _verifyApayFixture(fixture, proof: entry.value),
          throwsA(isA<LspAddressQuoteVerificationException>()),
          reason: entry.key,
        );
      }
      expect(
        () => _verifyApayFixture(
          fixture,
          expectedLspPubkey: _testHex(_compressedTestPubkey(BigInt.from(3))),
        ),
        throwsA(isA<LspAddressQuoteVerificationException>()),
      );
    });

    test('rejects altered LNURL metadata and address ownership', () {
      final fixture = _apayFixture();
      final discovery = fixture.discovery;
      final failures = <String, LspLnurlpDiscovery>{
        'tag': _copyDiscovery(discovery, tag: 'withdrawRequest'),
        'metadata': _copyDiscovery(
          discovery,
          metadata: '[["text/plain","Mallory"]]',
        ),
        'recipient': _copyDiscovery(
          discovery,
          recipientPubkey: _testHex(_compressedTestPubkey(BigInt.from(3))),
        ),
        'address signature': _copyDiscovery(
          discovery,
          addressSig: _mutateTestSignature(discovery.addressSig!),
        ),
        'missing address signature': _copyDiscovery(
          discovery,
          omitAddressSig: true,
        ),
      };

      for (final entry in failures.entries) {
        expect(
          () => _verifyApayFixture(fixture, discovery: entry.value),
          throwsA(isA<LspAddressQuoteVerificationException>()),
          reason: entry.key,
        );
      }
    });
  });

  group('linked and canonical receive', () {
    test(
      'omits asset_id by default and preserves resolved bridge metadata',
      () async {
        final wallet = _FakeWallet()
          ..decoded['lnbc1receive'] = _decoded(
            hash: _targetHash,
            amtMsat: 3000000,
            assetId: 'rgb:payout',
            assetAmount: 10,
          )
          ..decodedRgb['rgb:canonical-invoice'] = _decodedRgb(
            invoice: 'rgb:canonical-invoice',
            assetId: 'rgb:canonical',
            amount: 10,
          );
        final client = _FakeLspClient()
          ..receive = const LspLightningReceiveResponse(
            lnInvoice: 'lnbc1receive',
            rgbInvoice: 'rgb:canonical-invoice',
            mappingId: '42',
            rgbAssetId: 'rgb:canonical',
            converted: true,
          );

        final result = await _lsp(wallet, client).receiveAsset(
          const ReceiveAssetOptions(
            assetId: 'rgb:payout',
            amountSats: 3000,
            amountRgb: 10,
          ),
        );

        expect(
          client.lastReceive?.rgb.toWire().containsKey('asset_id'),
          isFalse,
        );
        expect(wallet.createdAssetId, 'rgb:payout');
        expect(wallet.createdAssetAmount, 10);
        expect(result.onchainAssetId, 'rgb:canonical');
        expect(result.converted, isTrue);
      },
    );

    test('payout mode explicitly sends the Lightning asset ID', () async {
      final wallet = _FakeWallet()
        ..decoded['lnbc1receive'] = _decoded(
          hash: _targetHash,
          amtMsat: 3000000,
          assetId: 'rgb:payout',
          assetAmount: 10,
        )
        ..decodedRgb['rgb:invoice'] = _decodedRgb(
          invoice: 'rgb:invoice',
          assetId: 'rgb:payout',
          amount: 10,
        );
      final client = _FakeLspClient();

      await _lsp(wallet, client).receiveAsset(
        const ReceiveAssetOptions(
          assetId: 'rgb:payout',
          amountSats: 3000,
          amountRgb: 10,
          onchainAsset: ReceiveOnchainAsset.payout,
        ),
      );

      expect(client.lastReceive?.rgb.assetId, 'rgb:payout');
      expect(client.lastReceive?.rgb.toWire()['asset_id'], 'rgb:payout');
    });

    test(
      'same-asset Any receive is valid but converted Any receive is rejected',
      () async {
        final wallet = _FakeWallet()
          ..decoded['lnbc1receive'] = _decoded(
            hash: _targetHash,
            amtMsat: 3000000,
            assetId: 'rgb:payout',
            assetAmount: 10,
          )
          ..decodedRgb['rgb:invoice'] = _decodedRgb(
            invoice: 'rgb:invoice',
            assetId: 'rgb:payout',
          );
        final client = _FakeLspClient();
        final lsp = _lsp(wallet, client);
        final result = await lsp.receiveAsset(
          const ReceiveAssetOptions(
            assetId: 'rgb:payout',
            amountSats: 3000,
            amountRgb: 10,
            onchainAsset: ReceiveOnchainAsset.payout,
          ),
        );
        expect(result.onchainAssetId, 'rgb:payout');
        expect(result.converted, isFalse);
        wallet.decodedRgb['rgb:invoice'] = _decodedRgb(
          invoice: 'rgb:invoice',
          assetId: 'rgb:canonical',
        );
        await expectLater(
          lsp.receiveAsset(
            const ReceiveAssetOptions(
              assetId: 'rgb:payout',
              amountSats: 3000,
              amountRgb: 10,
            ),
          ),
          throwsA(isA<LspBridgeQuoteVerificationException>()),
        );
        expect(wallet.paidInvoices, isEmpty);
      },
    );

    test('sendAsset pays only the invoice returned by the LSP', () async {
      final wallet = _FakeWallet()
        ..decodedRgb['rgb:recipient'] = _decodedRgb(
          invoice: 'rgb:recipient',
          assetId: 'rgb:target',
          amount: 10,
          expiresAt: 1700000220,
        )
        ..decoded['lnbc1send'] = _decoded(
          hash: _targetHash,
          amtMsat: 3000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 120,
        );
      final client = _FakeLspClient();

      final result = await _lsp(wallet, client).sendAsset(
        const SendAssetOptions(
          rgbInvoice: 'rgb:recipient',
          ln: LspLnParams(amtMsat: 3000, expirySec: 120),
        ),
      );

      expect(client.lastOnchainSend?.rgbInvoice, 'rgb:recipient');
      expect(client.lastOnchainSend?.ln?.amtMsat, 3000);
      expect(wallet.paidInvoices, <String>['lnbc1send']);
      expect(result.mappingId, 'mapping');
      expect(result.sendResult.txid, _targetHash);
    });

    test('receiveAsset rejects unbound bridge metadata', () async {
      Future<void> expectRejected({
        LspLightningReceiveResponse? response,
        CoreInvoiceData? decodedRgb,
      }) async {
        final wallet = _FakeWallet()
          ..decoded['lnbc1receive'] = _decoded(
            hash: _targetHash,
            amtMsat: 3000000,
            assetId: 'rgb:payout',
            assetAmount: 10,
          )
          ..decodedRgb['rgb:canonical-invoice'] =
              decodedRgb ??
              _decodedRgb(
                invoice: 'rgb:canonical-invoice',
                assetId: 'rgb:canonical',
                amount: 10,
              );
        final client = _FakeLspClient()
          ..receive =
              response ??
              const LspLightningReceiveResponse(
                lnInvoice: 'lnbc1receive',
                rgbInvoice: 'rgb:canonical-invoice',
                mappingId: 'mapping',
                rgbAssetId: 'rgb:canonical',
                converted: true,
              );

        await expectLater(
          _lsp(wallet, client).receiveAsset(
            const ReceiveAssetOptions(
              assetId: 'rgb:payout',
              amountSats: 3000,
              amountRgb: 10,
            ),
          ),
          throwsA(isA<LspBridgeQuoteVerificationException>()),
        );
      }

      await expectRejected(
        response: const LspLightningReceiveResponse(
          lnInvoice: 'lnbc1other',
          rgbInvoice: 'rgb:canonical-invoice',
          mappingId: 'mapping',
        ),
      );
      await expectRejected(
        decodedRgb: _decodedRgb(
          invoice: 'rgb:canonical-invoice',
          assetId: 'rgb:canonical',
          amount: 11,
        ),
      );
      await expectRejected(
        decodedRgb: _decodedRgb(
          invoice: 'rgb:canonical-invoice',
          assetId: 'rgb:canonical',
          amount: 10,
          network: 'mainnet',
        ),
      );
      await expectRejected(
        decodedRgb: _decodedRgb(
          invoice: 'rgb:canonical-invoice',
          assetId: 'rgb:canonical',
          amount: 10,
          expiresAt: 1700003500,
        ),
      );
      await expectRejected(
        response: const LspLightningReceiveResponse(
          lnInvoice: 'lnbc1receive',
          rgbInvoice: 'rgb:canonical-invoice',
          mappingId: 'mapping',
          rgbAssetId: 'rgb:other',
          converted: true,
        ),
      );
      await expectRejected(
        response: const LspLightningReceiveResponse(
          lnInvoice: 'lnbc1receive',
          rgbInvoice: 'rgb:canonical-invoice',
          mappingId: 'mapping',
          rgbAssetId: 'rgb:canonical',
          converted: false,
        ),
      );
    });

    test('sendAsset never pays an unbound LSP invoice', () async {
      Future<void> expectRejected({
        LspOnchainSendResponse? response,
        DecodedLightningInvoice? decodedLightning,
      }) async {
        final wallet = _FakeWallet()
          ..decodedRgb['rgb:recipient'] = _decodedRgb(
            invoice: 'rgb:recipient',
            assetId: 'rgb:target',
            amount: 10,
            expiresAt: 1700000220,
          )
          ..decoded['lnbc1send'] =
              decodedLightning ??
              _decoded(
                hash: _targetHash,
                amtMsat: 3000,
                assetId: 'rgb:target',
                assetAmount: 10,
                payeePubkey: 'lsp-pubkey',
                timestamp: 1700000100,
                expirySec: 120,
              );
        final client = _FakeLspClient()..onchainSendResponse = response;

        await expectLater(
          _lsp(wallet, client).sendAsset(
            const SendAssetOptions(
              rgbInvoice: 'rgb:recipient',
              ln: LspLnParams(amtMsat: 3000, expirySec: 120),
            ),
          ),
          throwsA(isA<LspBridgeQuoteVerificationException>()),
        );
        expect(wallet.paidInvoices, isEmpty);
      }

      await expectRejected(
        response: const LspOnchainSendResponse(
          rgbInvoice: 'rgb:other',
          lnInvoice: 'lnbc1send',
          mappingId: 'mapping',
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: _targetHash,
          amtMsat: 3000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 120,
          network: 'mainnet',
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: _targetHash,
          amtMsat: 3000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'another-peer',
          timestamp: 1700000100,
          expirySec: 120,
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: _targetHash,
          amtMsat: 3000,
          assetId: 'rgb:other',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 120,
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: _targetHash,
          amtMsat: 4000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 120,
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: _targetHash,
          amtMsat: 3000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 60,
        ),
      );
      await expectRejected(
        decodedLightning: _decoded(
          hash: 'not-a-payment-hash',
          amtMsat: 3000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
          timestamp: 1700000100,
          expirySec: 120,
        ),
      );
    });

    test(
      'bridge verification accepts canonical wallet network aliases',
      () async {
        final wallet = _FakeWallet()
          ..networkName = 'utexo'
          ..decoded['lnbc1receive'] = _decoded(
            hash: _targetHash,
            amtMsat: 3000000,
            assetId: 'rgb:payout',
            assetAmount: 10,
            network: 'signet',
          )
          ..decodedRgb['rgb:invoice'] = _decodedRgb(
            invoice: 'rgb:invoice',
            assetId: 'rgb:payout',
            amount: 10,
            network: 'signet',
          );

        final result = await _lsp(wallet, _FakeLspClient()).receiveAsset(
          const ReceiveAssetOptions(
            assetId: 'rgb:payout',
            amountSats: 3000,
            amountRgb: 10,
            onchainAsset: ReceiveOnchainAsset.payout,
          ),
        );

        expect(result.onchainAssetId, 'rgb:payout');
      },
    );

    test('bridge mutations reject invalid inputs before LSP contact', () async {
      final receiveWallet = _FakeWallet();
      final receiveClient = _FakeLspClient();
      await expectLater(
        _lsp(receiveWallet, receiveClient).receiveAsset(
          const ReceiveAssetOptions(
            assetId: 'rgb:payout',
            amountSats: 0,
            amountRgb: 10,
          ),
        ),
        throwsA(isA<ValidationError>()),
      );
      expect(receiveWallet.createdAmountSats, isNull);
      expect(receiveClient.lastReceive, isNull);

      for (final ln in <LspLnParams>[
        const LspLnParams(descriptionHash: 'not-a-hash'),
        const LspLnParams(paymentHash: 'not-a-hash'),
        const LspLnParams(minFinalCltvExpiryDelta: 0x10000),
      ]) {
        final sendWallet = _FakeWallet()
          ..decodedRgb['rgb:recipient'] = _decodedRgb(
            invoice: 'rgb:recipient',
            assetId: 'rgb:target',
            amount: 10,
          );
        final sendClient = _FakeLspClient();
        await expectLater(
          _lsp(
            sendWallet,
            sendClient,
          ).sendAsset(SendAssetOptions(rgbInvoice: 'rgb:recipient', ln: ln)),
          throwsA(isA<ValidationError>()),
        );
        expect(sendClient.lastOnchainSend, isNull);
        expect(sendWallet.paidInvoices, isEmpty);
      }
    });

    test('receiveAsset never maps an invoice whose lifetime elapsed', () async {
      final wallet = _FakeWallet()
        ..createInvoiceDelay = const Duration(milliseconds: 1100)
        ..decoded['lnbc1receive'] = _decoded(
          hash: _targetHash,
          amtMsat: 1000,
          assetId: 'rgb:payout',
          assetAmount: 1,
          timestamp: 1700000100,
          expirySec: 1,
        );
      final client = _FakeLspClient();

      await expectLater(
        _lsp(wallet, client).receiveAsset(
          const ReceiveAssetOptions(
            assetId: 'rgb:payout',
            amountSats: 1,
            amountRgb: 1,
            expirySeconds: 1,
          ),
        ),
        throwsA(isA<NetworkError>()),
      );
      expect(client.lastReceive, isNull);
    });

    test(
      'receiveAsset verifies its signed invoice before LSP contact',
      () async {
        final wallet = _FakeWallet()
          ..decoded['lnbc1receive'] = _decoded(
            hash: _targetHash,
            amtMsat: 2000,
            assetId: 'rgb:payout',
            assetAmount: 1,
          );
        final client = _FakeLspClient();

        await expectLater(
          _lsp(wallet, client).receiveAsset(
            const ReceiveAssetOptions(
              assetId: 'rgb:payout',
              amountSats: 1,
              amountRgb: 1,
            ),
          ),
          throwsA(isA<LspBridgeQuoteVerificationException>()),
        );
        expect(client.lastReceive, isNull);
      },
    );

    test(
      'sendAsset rejects invalid RGB targets before contacting the LSP',
      () async {
        final wallet = _FakeWallet()
          ..decodedRgb['rgb:recipient'] = _decodedRgb(
            invoice: 'rgb:recipient',
            assetId: 'rgb:target',
            amount: 10,
            expiresAt: 1700000000,
          );
        final client = _FakeLspClient();

        await expectLater(
          _lsp(
            wallet,
            client,
          ).sendAsset(const SendAssetOptions(rgbInvoice: 'rgb:recipient')),
          throwsA(isA<LspBridgeQuoteVerificationException>()),
        );
        expect(client.lastOnchainSend, isNull);
        expect(wallet.paidInvoices, isEmpty);
      },
    );
  });

  group('Lightning Address asset policy', () {
    late LspSupportedAsset payout;
    late LspSupportedAsset bridge;
    late LspLnurlpDiscovery discovery;

    setUp(() {
      payout = _asset('rgb:payout', 'PAYOUT');
      bridge = _asset('rgb:bridge', 'BRIDGE');
      discovery = LspLnurlpDiscovery(
        callback: 'https://lsp.example/pay/callback/alice',
        minSendable: 1000,
        maxSendable: 100000000,
        metadata: _lnurlMetadata,
        tag: 'payRequest',
        payoutAsset: payout,
        acceptedAssets: <LspSupportedAsset>[payout, bridge],
      );
    });

    test(
      'preserves the discovery menu and derives convertible assets',
      () async {
        final wallet = _FakeWallet();
        final advertised = LspLnurlpDiscovery(
          callback: discovery.callback,
          minSendable: discovery.minSendable,
          maxSendable: discovery.maxSendable,
          payoutAsset: payout,
          acceptedAssets: <LspSupportedAsset>[bridge, payout, bridge],
        );
        final client = _FakeLspClient()..localDiscovery = advertised;

        final payable = await _lsp(
          wallet,
          client,
        ).listPayableAssets('alice@lsp.example');

        expect(payable.accepted.map((asset) => asset.assetId), <String>[
          'rgb:bridge',
          'rgb:payout',
          'rgb:bridge',
        ]);
        expect(payable.convertible.map((asset) => asset.assetId), <String>[
          'rgb:bridge',
          'rgb:bridge',
        ]);
      },
    );

    test(
      'uses the largest single channel and prefers payout when sufficient',
      () async {
        final wallet = _FakeWallet()
          ..channels = <LightningChannel>[
            _channel(
              id: 'payout-small-a',
              assetId: 'rgb:payout',
              assetLocalAmount: 4,
            ),
            _channel(
              id: 'payout-small-b',
              assetId: 'rgb:payout',
              assetLocalAmount: 4,
            ),
            _channel(
              id: 'bridge-large',
              assetId: 'rgb:bridge',
              assetLocalAmount: 8,
            ),
            _channel(
              id: 'bridge-small',
              assetId: 'rgb:bridge',
              assetLocalAmount: 2,
            ),
          ];
        final client = _FakeLspClient()..localDiscovery = discovery;
        final lsp = _lsp(wallet, client);

        final fallback = await lsp.selectPaymentAsset(
          SelectPaymentAssetOptions(
            address: 'alice@lsp.example',
            assetAmount: 7,
            discovery: discovery,
          ),
        );
        wallet.channels.add(
          _channel(
            id: 'payout-large',
            assetId: 'rgb:payout',
            assetLocalAmount: 9,
          ),
        );
        final preferred = await lsp.selectPaymentAsset(
          SelectPaymentAssetOptions(
            address: 'alice@lsp.example',
            assetAmount: 7,
            discovery: discovery,
          ),
        );

        expect(fallback.assetId, 'rgb:bridge');
        expect(fallback.localAssetAmount, BigInt.from(8));
        expect(fallback.converted, isTrue);
        expect(preferred.assetId, 'rgb:payout');
        expect(preferred.converted, isFalse);
      },
    );

    test('reports per-asset liquidity and refuses an empty menu', () async {
      final wallet = _FakeWallet()
        ..channels = <LightningChannel>[
          _channel(id: 'payout', assetId: 'rgb:payout', assetLocalAmount: 4),
          _channel(id: 'bridge', assetId: 'rgb:bridge', assetLocalAmount: 6),
        ];
      final client = _FakeLspClient()..localDiscovery = discovery;
      final lsp = _lsp(wallet, client);

      await expectLater(
        lsp.selectPaymentAsset(
          SelectPaymentAssetOptions(
            address: 'alice@lsp.example',
            assetAmount: 7,
            discovery: discovery,
          ),
        ),
        throwsA(
          isA<LspInsufficientAssetLiquidityException>()
              .having((error) => error.requiredAmount, 'required', 7)
              .having(
                (error) => error.candidates.map((item) => item.localAmount),
                'candidate amounts',
                <BigInt>[BigInt.from(4), BigInt.from(6)],
              ),
        ),
      );
      await expectLater(
        lsp.selectPaymentAsset(
          SelectPaymentAssetOptions(
            address: 'alice@lsp.example',
            assetAmount: 1,
            discovery: LspLnurlpDiscovery(
              callback: 'https://lsp.example/pay/callback/alice',
              minSendable: 1,
              maxSendable: 2,
            ),
          ),
        ),
        throwsA(isA<LspNoPayableAssetException>()),
      );
    });

    test('quoteAddress selects an asset and returns the selection', () async {
      final fixture = _apayFixture(
        invoice: 'lnbc1quoted',
        payoutAsset: payout,
        acceptedAssets: <LspSupportedAsset>[payout, bridge],
      );
      final wallet = _FakeWallet()
        ..channels = <LightningChannel>[
          _channel(id: 'bridge', assetId: 'rgb:bridge', assetLocalAmount: 20),
        ]
        ..decoded[fixture.callback.pr] = fixture.decoded;
      final client = _FakeLspClient()
        ..localDiscovery = fixture.discovery
        ..callback = fixture.callback;

      final quote = await _lsp(wallet, client, peerPubkey: fixture.hostPubkey)
          .quoteAddress(
            const PayAddressOptions(
              address: 'alice@lsp.example',
              amtMsat: 3000,
              asset: PayAddressAssetParam(assetAmount: 10),
            ),
          );

      expect(client.lastAssetId, 'rgb:bridge');
      expect(client.lastAssetAmount, 10);
      expect(quote.assetSelection?.converted, isTrue);
      expect(quote.proof?.paymentHash, _targetHash);
    });

    test('does not retry a consuming Lightning Address callback', () async {
      final client = _FakeLspClient()
        ..resolveErrors.add(
          const LspError(
            endpoint: '/lnurlp',
            status: 503,
            body: 'ambiguous response',
          ),
        );

      await expectLater(
        _lsp(_FakeWallet(), client).quoteAddress(
          const PayAddressOptions(address: 'alice@lsp.example', amtMsat: 3000),
        ),
        throwsA(isA<LspError>()),
      );
      expect(client.resolveCalls, 1);
    });

    test(
      'requestExternalInvoice resolves ticker and default preference',
      () async {
        final preferredFixture = _apayFixture(
          invoice: 'lnbc1external-bridge',
          payoutAsset: payout,
          acceptedAssets: <LspSupportedAsset>[payout, bridge],
        );
        final wallet = _FakeWallet()
          ..nodePubkey = preferredFixture.discovery.recipientPubkey!
          ..decoded[preferredFixture.callback.pr] = preferredFixture.decoded;
        final client = _FakeLspClient()
          ..localDiscovery = preferredFixture.discovery
          ..callback = preferredFixture.callback;
        final lsp = _lsp(
          wallet,
          client,
          peerPubkey: preferredFixture.hostPubkey,
        );

        final preferred = await lsp.requestExternalInvoice(
          const RequestExternalInvoiceOptions(amtMsat: 3000, assetAmount: 10),
        );
        final explicitFixture = _apayFixture(
          invoice: 'lnbc1external-payout',
          assetId: 'rgb:payout',
          payoutAsset: payout,
          acceptedAssets: <LspSupportedAsset>[payout, bridge],
        );
        wallet.decoded[explicitFixture.callback.pr] = explicitFixture.decoded;
        client
          ..localDiscovery = explicitFixture.discovery
          ..callback = explicitFixture.callback;
        final explicit = await lsp.requestExternalInvoice(
          const RequestExternalInvoiceOptions(
            amtMsat: 3000,
            assetAmount: 10,
            asset: 'PAYOUT',
            address: 'alice@lsp.example',
          ),
        );

        expect(preferred.asset?.assetId, 'rgb:bridge');
        expect(preferred.converted, isTrue);
        expect(preferred.paymentHash, _targetHash);
        expect(explicit.asset?.assetId, 'rgb:payout');
        expect(explicit.converted, isFalse);
      },
    );

    test(
      'own receive rejects another valid recipient while explicit recipient remains allowed',
      () async {
        final fixture = _apayFixture(
          invoice: 'lnbc1other-recipient',
          payoutAsset: payout,
          acceptedAssets: <LspSupportedAsset>[payout, bridge],
        );
        final wallet = _FakeWallet()
          ..nodePubkey = '02${'12' * 32}'
          ..decoded[fixture.callback.pr] = fixture.decoded;
        final client = _FakeLspClient()
          ..localDiscovery = fixture.discovery
          ..callback = fixture.callback;
        final lsp = _lsp(wallet, client, peerPubkey: fixture.hostPubkey);
        await expectLater(
          lsp.requestExternalInvoice(
            const RequestExternalInvoiceOptions(amtMsat: 3000, assetAmount: 10),
          ),
          throwsA(isA<LspAddressQuoteVerificationException>()),
        );
        final explicit = await lsp.requestExternalInvoice(
          const RequestExternalInvoiceOptions(
            amtMsat: 3000,
            assetAmount: 10,
            address: 'alice@lsp.example',
          ),
        );
        expect(explicit.paymentHash, _targetHash);
        expect(wallet.paidInvoices, isEmpty);
      },
    );

    test('APay host mismatch prevents hash registration', () async {
      final wallet = _FakeWallet();
      final client = _FakeLspClient();
      final lsp = _lsp(wallet, client, peerPubkey: 'unexpected-peer');
      await expectLater(
        lsp.enableLightningAddress(),
        throwsA(isA<LspQuoteMismatchException>()),
      );
      await expectLater(
        lsp.refillHashPool(),
        throwsA(isA<LspQuoteMismatchException>()),
      );
    });

    test(
      'requestExternalInvoice refuses ambiguous convertible assets',
      () async {
        final wallet = _FakeWallet();
        final client = _FakeLspClient()
          ..localDiscovery = LspLnurlpDiscovery(
            callback: discovery.callback,
            minSendable: discovery.minSendable,
            maxSendable: discovery.maxSendable,
            payoutAsset: payout,
            acceptedAssets: <LspSupportedAsset>[
              payout,
              bridge,
              _asset('rgb:other', 'OTHER'),
            ],
          );

        await expectLater(
          _lsp(wallet, client).requestExternalInvoice(
            const RequestExternalInvoiceOptions(amtMsat: 3000, assetAmount: 10),
          ),
          throwsA(isA<LspAmbiguousPayableAssetException>()),
        );
        expect(client.resolveCalls, 0);
      },
    );

    test(
      'rejects conflicting amount aliases before reserving a quote',
      () async {
        final client = _FakeLspClient();
        await expectLater(
          _lsp(_FakeWallet(), client).quoteAddress(
            const PayAddressOptions(
              address: 'alice@lsp.example',
              amtMsat: 3000,
              asset: PayAddressAssetParam(amount: 1, assetAmount: 2),
            ),
          ),
          throwsA(isA<ValidationError>()),
        );
        expect(client.resolveCalls, 0);
      },
    );
  });

  group('external relay funds safety', () {
    test(
      'rejects a self-consistent substituted funding asset before payment',
      () async {
        final wallet = _FakeWallet()
          ..decoded = <String, DecodedLightningInvoice>{
            'lnbc1target': _decoded(
              hash: _targetHash,
              amtMsat: 1000,
              assetId: 'rgb:target',
              assetAmount: 10,
              payeePubkey: 'recipient-pubkey',
            ),
            'lnbc1hodl': _decoded(
              hash: _targetHash,
              amtMsat: 1010,
              assetId: 'rgb:substituted',
              assetAmount: 10,
              payeePubkey: 'lsp-pubkey',
            ),
          };
        final client = _FakeLspClient()
          ..relay = _relayQuote(inboundAsset: 'rgb:substituted');
        await expectLater(
          _lsp(wallet, client).payExternalInvoice(
            const PayExternalInvoiceOptions(
              invoice: 'lnbc1target',
              payWith: 'rgb:selected',
              maxFeeMsat: 10,
            ),
          ),
          throwsA(isA<LspQuoteMismatchException>()),
        );
        expect(wallet.paidInvoices, isEmpty);
      },
    );
    test(
      'decodes both invoices before paying and returns a verified quote',
      () async {
        final wallet = _FakeWallet()
          ..decoded = <String, DecodedLightningInvoice>{
            'lnbc1target': _decoded(
              hash: _targetHash,
              amtMsat: 1000,
              assetId: 'rgb:target',
              assetAmount: 10,
              payeePubkey: 'recipient-pubkey',
            ),
            'lnbc1hodl': _decoded(
              hash: _targetHash.toUpperCase(),
              amtMsat: 1010,
              assetId: 'rgb:source',
              assetAmount: 10,
              payeePubkey: 'lsp-pubkey',
            ),
          };
        final client = _FakeLspClient()
          ..info = _info(
            assets: <LspSupportedAsset>[_asset('rgb:source', 'SOURCE')],
          )
          ..relay = _relayQuote();
        final result = await _lsp(wallet, client).payExternalInvoice(
          const PayExternalInvoiceOptions(
            invoice: 'lnbc1target',
            payWith: 'source',
            maxFeeMsat: 10,
          ),
        );

        expect(client.lastRelayRequest?.payWithAssetId, 'rgb:source');
        expect(result.quote.verified, isTrue);
        expect(result.quote.paymentHash, _targetHash.toUpperCase());
        expect(wallet.events, <String>[
          'decode:lnbc1target',
          'decode:lnbc1hodl',
          'pay:lnbc1hodl',
        ]);
        expect(wallet.paidInvoices, <String>['lnbc1hodl']);
      },
    );

    test('relay verification accepts the utexo/signet network alias', () async {
      final wallet = _FakeWallet()
        ..networkName = 'utexo'
        ..decoded = <String, DecodedLightningInvoice>{
          'lnbc1target': _decoded(
            hash: _targetHash,
            amtMsat: 1000,
            assetId: 'rgb:target',
            assetAmount: 10,
            payeePubkey: 'recipient-pubkey',
            network: 'signet',
          ),
          'lnbc1hodl': _decoded(
            hash: _targetHash,
            amtMsat: 1010,
            assetId: 'rgb:source',
            assetAmount: 10,
            payeePubkey: 'lsp-pubkey',
            network: 'signet',
          ),
        };
      final client = _FakeLspClient()
        ..info = _info(
          assets: <LspSupportedAsset>[_asset('rgb:source', 'SOURCE')],
        )
        ..relay = _relayQuote();

      final quote = await _lsp(wallet, client).quoteExternalPayment(
        const PayExternalInvoiceOptions(
          invoice: 'lnbc1target',
          payWith: 'SOURCE',
          maxFeeMsat: 10,
        ),
      );

      expect(quote.verified, isTrue);
      expect(wallet.paidInvoices, isEmpty);
    });

    test(
      'a rejected automatic conversion quote never triggers payment',
      () async {
        final wallet = _FakeWallet()
          ..channels = <LightningChannel>[
            _channel(id: 'b', assetId: 'rgb:alternative', assetLocalAmount: 20),
          ]
          ..decoded = <String, DecodedLightningInvoice>{
            'lnbc1target': _decoded(
              hash: _targetHash,
              amtMsat: 1000,
              assetId: 'rgb:target',
              assetAmount: 10,
              payeePubkey: 'recipient-pubkey',
            ),
          };
        final client = _FakeLspClient()
          ..relayFailure = const LspError(
            endpoint: '/lightning_send',
            status: 400,
            body: 'pair not convertible',
          );
        await expectLater(
          _lsp(wallet, client).payExternalInvoice(
            const PayExternalInvoiceOptions(
              invoice: 'lnbc1target',
              maxFeeMsat: 10,
            ),
          ),
          throwsA(isA<LspError>()),
        );
        expect(client.lastRelayRequest?.payWithAssetId, 'rgb:alternative');
        expect(client.events, <String>['quote:lnbc1target']);
        expect(wallet.paidInvoices, isEmpty);
      },
    );

    test('selects the first locally funded alternative like core', () async {
      final wallet = _FakeWallet()
        ..channels = <LightningChannel>[
          _channel(id: 'b', assetId: 'rgb:b', assetLocalAmount: 20),
          _channel(id: 'a', assetId: 'rgb:a', assetLocalAmount: 20),
        ]
        ..decoded = <String, DecodedLightningInvoice>{
          'lnbc1target': _decoded(
            hash: _targetHash,
            amtMsat: 1000,
            assetId: 'rgb:target',
            assetAmount: 10,
            payeePubkey: 'recipient-pubkey',
          ),
          'lnbc1hodl': _decoded(
            hash: _targetHash,
            amtMsat: 1010,
            assetId: 'rgb:b',
            assetAmount: 10,
            payeePubkey: 'lsp-pubkey',
          ),
        };
      final client = _FakeLspClient()
        ..relay = _relayQuote(
          inboundAsset: 'rgb:b',
          inboundPayee: null,
          outboundPayee: 'recipient-pubkey',
        );

      final quote = await _lsp(wallet, client).quoteExternalPayment(
        const PayExternalInvoiceOptions(invoice: 'lnbc1target', maxFeeMsat: 10),
      );

      expect(client.lastRelayRequest?.payWithAssetId, 'rgb:b');
      expect(quote.verified, isTrue);
      expect(wallet.paidInvoices, isEmpty);
    });

    test(
      'passes an explicit RGB contract through without get_info lookup',
      () async {
        final wallet = _FakeWallet()
          ..decoded = <String, DecodedLightningInvoice>{
            'lnbc1target': _decoded(
              hash: _targetHash,
              amtMsat: 1000,
              assetId: 'rgb:target',
              assetAmount: 10,
              payeePubkey: 'recipient-pubkey',
            ),
            'lnbc1hodl': _decoded(
              hash: _targetHash,
              amtMsat: 1010,
              assetId: 'rgb:source',
              assetAmount: 10,
              payeePubkey: 'lsp-pubkey',
            ),
          };
        final client = _FakeLspClient()
          ..info = _info()
          ..relay = _relayQuote(
            inboundPayee: null,
            outboundPayee: 'recipient-pubkey',
          );

        await _lsp(wallet, client).quoteExternalPayment(
          const PayExternalInvoiceOptions(
            invoice: 'lnbc1target',
            payWith: 'rgb:source',
            maxFeeMsat: 10,
          ),
        );

        expect(client.lastRelayRequest?.payWithAssetId, 'rgb:source');
      },
    );

    test('resolves non-prefixed payWith values by ticker only', () async {
      final wallet = _FakeWallet()
        ..decoded = <String, DecodedLightningInvoice>{
          'lnbc1target': _decoded(
            hash: _targetHash,
            amtMsat: 1000,
            assetId: 'rgb:target',
            assetAmount: 10,
          ),
        };
      final client = _FakeLspClient()
        ..info = _info(
          assets: <LspSupportedAsset>[_asset('legacy-contract-id', 'SOURCE')],
        );

      await expectLater(
        _lsp(wallet, client).quoteExternalPayment(
          const PayExternalInvoiceOptions(
            invoice: 'lnbc1target',
            payWith: 'legacy-contract-id',
          ),
        ),
        throwsA(isA<LspUnknownPayableAssetException>()),
      );
      expect(client.lastRelayRequest, isNull);
    });

    test(
      'refuses every hash, asset, amount, fee, and conversion mismatch',
      () async {
        final validTarget = _decoded(
          hash: _targetHash,
          amtMsat: 1000,
          assetId: 'rgb:target',
          assetAmount: 10,
          payeePubkey: 'recipient-pubkey',
        );
        final validHodl = _decoded(
          hash: _targetHash,
          amtMsat: 1010,
          assetId: 'rgb:source',
          assetAmount: 10,
          payeePubkey: 'lsp-pubkey',
        );
        final cases = <_RelayMismatchCase>[
          _RelayMismatchCase(
            'invoice hash',
            hodl: _decoded(
              hash:
                  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
              amtMsat: 1010,
              assetId: 'rgb:source',
              assetAmount: 10,
            ),
          ),
          _RelayMismatchCase(
            'reported hash',
            quote: _relayQuote(
              hash:
                  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            ),
          ),
          _RelayMismatchCase(
            'invoice asset amount',
            hodl: _decoded(
              hash: _targetHash,
              amtMsat: 1010,
              assetId: 'rgb:source',
              assetAmount: 11,
            ),
          ),
          _RelayMismatchCase(
            'inbound asset',
            quote: _relayQuote(inboundAsset: 'rgb:wrong'),
          ),
          _RelayMismatchCase(
            'outbound asset',
            quote: _relayQuote(outboundAsset: 'rgb:wrong'),
          ),
          _RelayMismatchCase(
            'inbound asset amount',
            quote: _relayQuote(inboundAssetAmount: 11),
          ),
          _RelayMismatchCase(
            'outbound asset amount',
            quote: _relayQuote(outboundAssetAmount: 11),
          ),
          _RelayMismatchCase(
            'inbound millisatoshis',
            quote: _relayQuote(inboundMsat: 1009, feeMsat: 9),
          ),
          _RelayMismatchCase(
            'outbound millisatoshis',
            quote: _relayQuote(outboundMsat: 999, feeMsat: 11),
            maxFeeMsat: 11,
          ),
          _RelayMismatchCase(
            'fee ceiling',
            quote: _relayQuote(inboundMsat: 1011, feeMsat: 11),
          ),
          _RelayMismatchCase(
            'fee reconciliation',
            quote: _relayQuote(feeMsat: 9),
          ),
          _RelayMismatchCase(
            'conversion flag',
            quote: _relayQuote(converted: false),
          ),
          _RelayMismatchCase(
            'outbound payee',
            quote: _relayQuote(outboundPayee: 'attacker'),
          ),
          _RelayMismatchCase(
            'inbound payee',
            quote: _relayQuote(inboundPayee: 'attacker'),
          ),
          _RelayMismatchCase(
            'missing outbound payee',
            quote: _relayQuote(outboundPayee: null),
          ),
          _RelayMismatchCase(
            'wrong HODL payee',
            hodl: _copyDecoded(validHodl, payeePubkey: 'attacker'),
          ),
          _RelayMismatchCase(
            'target network',
            target: _copyDecoded(validTarget, network: 'mainnet'),
          ),
          _RelayMismatchCase(
            'HODL network',
            hodl: _copyDecoded(validHodl, network: 'mainnet'),
          ),
          _RelayMismatchCase(
            'expired target',
            target: _copyDecoded(
              validTarget,
              timestamp: 1699990000,
              expirySec: 10,
            ),
          ),
          _RelayMismatchCase(
            'future HODL',
            hodl: _copyDecoded(validHodl, timestamp: 1700001000),
          ),
          _RelayMismatchCase(
            'HODL outlives target',
            hodl: _copyDecoded(validHodl, expirySec: 3601),
          ),
          _RelayMismatchCase(
            'expired reported quote',
            quote: _relayQuote(expiresAt: 1700000000),
          ),
          _RelayMismatchCase(
            'misreported quote expiry',
            quote: _relayQuote(expiresAt: 1700003500),
          ),
        ];

        for (final mismatch in cases) {
          final wallet = _FakeWallet()
            ..decoded = <String, DecodedLightningInvoice>{
              'lnbc1target': mismatch.target ?? validTarget,
              'lnbc1hodl': mismatch.hodl ?? validHodl,
            };
          final client = _FakeLspClient()
            ..info = _info(
              assets: <LspSupportedAsset>[_asset('rgb:source', 'SOURCE')],
            )
            ..relay = mismatch.quote ?? _relayQuote();

          await expectLater(
            _lsp(wallet, client).payExternalInvoice(
              PayExternalInvoiceOptions(
                invoice: 'lnbc1target',
                payWith: 'SOURCE',
                maxFeeMsat: mismatch.maxFeeMsat,
              ),
            ),
            throwsA(isA<LspQuoteMismatchException>()),
            reason: mismatch.name,
          );
          expect(wallet.paidInvoices, isEmpty, reason: mismatch.name);
        }
      },
    );

    test('rejects an amountless target before paying', () async {
      final wallet = _FakeWallet()
        ..decoded = <String, DecodedLightningInvoice>{
          'lnbc1target': _decoded(
            hash: _targetHash,
            amtMsat: null,
            assetId: 'rgb:target',
            assetAmount: 10,
          ),
          'lnbc1hodl': _decoded(
            hash: _targetHash,
            amtMsat: 10,
            assetId: 'rgb:source',
            assetAmount: 10,
          ),
        };

      await expectLater(
        _lsp(wallet, _FakeLspClient()).payExternalInvoice(
          const PayExternalInvoiceOptions(invoice: 'lnbc1target'),
        ),
        throwsA(isA<LspQuoteMismatchException>()),
      );
      expect(wallet.paidInvoices, isEmpty);
    });

    test(
      'externalPaymentStatus validates and delegates the payment hash',
      () async {
        final client = _FakeLspClient();
        final lsp = _lsp(_FakeWallet(), client);

        final status = await lsp.externalPaymentStatus('  $_targetHash  ');

        expect(client.lastRelayStatusHash, _targetHash);
        expect(status.status, LspLightningSendStatuses.quoted);
        await expectLater(
          lsp.externalPaymentStatus('  '),
          throwsA(isA<ValidationError>()),
        );
      },
    );
  });

  group('polling semantics', () {
    test('liquidity uses the largest usable channel, not the first', () async {
      final wallet = _FakeWallet()
        ..channels = <LightningChannel>[
          _channel(
            id: 'small',
            assetId: 'rgb:asset',
            assetLocalAmount: 1,
            outboundMsat: 1,
          ),
          _channel(
            id: 'large',
            assetId: 'rgb:asset',
            assetLocalAmount: 1,
            outboundMsat: 1000000,
          ),
        ];
      await _lsp(wallet, _FakeLspClient()).waitForOutboundLiquidity(
        500000,
        options: const WaitOptions(timeoutMs: 200, pollIntervalMs: 50),
      );
      expect(wallet.syncCalls, 1);
    });

    test('poll deadline prevents follow-up dispatch after slow hook', () async {
      final hook = Completer<void>();
      final wallet = _FakeWallet();
      await expectLater(
        _lsp(wallet, _FakeLspClient()).waitForOutboundLiquidity(
          1,
          options: WaitOptions(
            timeoutMs: 20,
            pollIntervalMs: 50,
            onEachPoll: () => hook.future,
          ),
        ),
        throwsA(isA<LspLiquidityTimeoutException>()),
      );
      expect(wallet.syncCalls, 0);
      hook.complete();
      await Future<void>.value();
      expect(wallet.syncCalls, 0);
    });
    test(
      'waitForChannel selects the configured peer and preserves remote fallback',
      () async {
        final wallet = _FakeWallet()
          ..channels = <LightningChannel>[
            _channel(
              id: 'wrong-peer',
              peer: 'another-peer',
              assetId: 'rgb:asset',
              assetLocalAmount: 1,
            ),
            _channel(
              id: 'lsp-channel',
              assetId: 'rgb:asset',
              assetLocalAmount: 1,
              inboundMsat: null,
              remoteMsat: 321,
            ),
          ];

        final result = await _lsp(
          wallet,
          _FakeLspClient(),
        ).waitForChannel('rgb:asset');

        expect(result.channelId, 'lsp-channel');
        expect(result.peerPubkey, 'lsp-pubkey');
        expect(result.inboundBalanceMsat, 321);
      },
    );

    test(
      'treats Cancelled receive status as a terminal settlement failure',
      () async {
        final wallet = _FakeWallet()
          ..receiveStatus = RlnInvoiceStatuses.cancelled;

        await expectLater(
          _lsp(wallet, _FakeLspClient()).awaitReceiveSettlement(
            'lnbc1receive',
            options: const WaitOptions(timeoutMs: 100, pollIntervalMs: 50),
          ),
          throwsA(
            isA<LspSettlementException>().having(
              (error) => error.status,
              'status',
              RlnInvoiceStatuses.cancelled,
            ),
          ),
        );
      },
    );

    test('liquidity timeout reports the last amount observed', () async {
      final wallet = _FakeWallet()
        ..channels = <LightningChannel>[
          _channel(
            id: 'channel',
            assetId: 'rgb:asset',
            assetLocalAmount: 1,
            outboundMsat: 75,
          ),
        ];

      await expectLater(
        _lsp(wallet, _FakeLspClient()).waitForOutboundLiquidity(
          100,
          // Leave enough time for the observation even when other tests or a
          // native build contend for the host. The poll still expires.
          options: const WaitOptions(timeoutMs: 500, pollIntervalMs: 50),
        ),
        throwsA(
          isA<LspLiquidityTimeoutException>().having(
            (error) => error.lastOutboundMsat,
            'last outbound',
            75,
          ),
        ),
      );
    });
  });
}

class _RelayMismatchCase {
  const _RelayMismatchCase(
    this.name, {
    this.target,
    this.hodl,
    this.quote,
    this.maxFeeMsat = 10,
  });

  final String name;
  final DecodedLightningInvoice? target;
  final DecodedLightningInvoice? hodl;
  final LspLightningSendResponse? quote;
  final int maxFeeMsat;
}
