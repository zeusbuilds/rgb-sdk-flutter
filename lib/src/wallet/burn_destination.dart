import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

import '../errors/rgb_sdk_exception.dart';
import 'burn_recipient.dart';

const _maxExactChainId = 9007199254740991;
const _maxDstEid = 0xffffffff;
const _invalidDestination = WalletValidationException(
  'Invalid V1 burn destination.',
  field: 'burnDestination',
);

/// A payout route selected by the host's approved bridge deployment.
final class BurnDestinationRoute {
  BurnDestinationRoute({required this.chainId, required this.dstEid}) {
    _chainNumber(chainId);
    if (dstEid < 0 ||
        dstEid > _maxDstEid ||
        (dstEid == 0 && chainId.startsWith('tron:'))) {
      throw _invalidDestination;
    }
  }

  final String chainId;
  final int dstEid;

  Map<String, Object> toJson() =>
      Map.unmodifiable({'chainId': chainId, 'dstEid': dstEid});
}

/// Typed payout metadata committed into a native RGB_L1 BFA burn reason.
final class BurnDestination {
  BurnDestination._(this.destinationChainId, this.dstEid, this.recipient);

  factory BurnDestination.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) throw _invalidDestination;
    final version = value['version'];
    final chain = value['destinationChainId'];
    final eid = value['dstEid'];
    final address = value['recipient'];
    if (version is! int ||
        version != 1 ||
        chain is! int ||
        chain <= 0 ||
        chain > _maxExactChainId ||
        eid is! int ||
        eid < 0 ||
        eid > _maxDstEid ||
        address is! String ||
        address.length > 66 ||
        RegExp(
              r'^0x(?:[\da-f]{2}){1,32}$',
              caseSensitive: false,
            ).firstMatch(address)?.end !=
            address.length ||
        (eid == 0 && address.length != 42)) {
      throw _invalidDestination;
    }
    return BurnDestination._(chain, eid, address.toLowerCase());
  }

  factory BurnDestination.forPayout(
    BurnDestinationRoute route,
    String address,
  ) => BurnDestination._(
    _chainNumber(route.chainId),
    route.dstEid,
    _recipientBytes(route.chainId, address),
  );

  final int destinationChainId;
  final int dstEid;
  final String recipient;

  /// Checks that journal metadata still names the exact approved account.
  void validatePayout(String chainId, String address) {
    if (destinationChainId != _chainNumber(chainId) ||
        recipient != _recipientBytes(chainId, address)) {
      throw _invalidDestination;
    }
  }

  Map<String, Object> toJson() => Map.unmodifiable({
    'version': 1,
    'destinationChainId': destinationChainId,
    'dstEid': dstEid,
    'recipient': recipient,
  });

  /// Keccak-256 of the EVM ABI tuple as an unprefixed native 32-byte hex value.
  String get commitment {
    final encoded = Uint8List(128);
    final words = ByteData.sublistView(encoded);
    final recipientBytes = Uint8List((recipient.length - 2) ~/ 2);
    for (var i = 0; i < recipientBytes.length; i++) {
      final start = 2 + 2 * i;
      recipientBytes[i] = int.parse(
        recipient.substring(start, start + 2),
        radix: 16,
      );
    }
    encoded.setRange(0, 32, _destinationTypeHash);
    words.setUint64(56, destinationChainId);
    words.setUint32(92, dstEid);
    encoded.setRange(96, 128, KeccakDigest(256).process(recipientBytes));
    return KeccakDigest(256)
        .process(encoded)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

final _destinationTypeHash = KeccakDigest(256).process(
  Uint8List.fromList(
    utf8.encode(
      'UtexoBurnDestinationV1(uint64 destinationChainId,uint32 dstEid,bytes recipient)',
    ),
  ),
);

int _chainNumber(String chainId) {
  if (chainId.length > 23 || !isSupportedBurnPayoutChain(chainId)) {
    throw _invalidDestination;
  }
  final suffix = chainId.substring(chainId.indexOf(':') + 1);
  final chain = int.tryParse(suffix);
  if (chain == null ||
      chain <= 0 ||
      chain > _maxExactChainId ||
      suffix != chain.toString()) {
    throw _invalidDestination;
  }
  return chain;
}

String _recipientBytes(String chainId, String address) {
  final account = encodeBurnRecipient(chainId, address).substring(24);
  return chainId.startsWith('tron:') ? '0x41$account' : '0x$account';
}
