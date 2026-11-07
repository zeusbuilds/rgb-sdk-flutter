import 'dart:async';

import 'package:bip32/bip32.dart';

import '../../crypto/constants.dart';
import '../../errors/rgb_sdk_exception.dart';
import '../network_defaults.dart';

/// Stable failure categories for the native on-chain wallet.
final class RgbLibWalletException extends WalletException {
  const RgbLibWalletException(super.message, {required super.code});
}

/// Parameters bound to the native on-chain wallet's storage profile.
final class RgbLibWalletParams {
  const RgbLibWalletParams({
    required this.network,
    required this.storageDirPath,
    this.witnessVersion = RgbLibWitnessVersion.taproot,
    this.maxAllocationsPerUtxo = 5,
    this.reuseAddresses = false,
  });

  final String network;

  /// An absolute, private directory dedicated to this RGB_L1 wallet.
  final String storageDirPath;
  final RgbLibWitnessVersion witnessVersion;
  final int maxAllocationsPerUtxo;
  final bool reuseAddresses;
}

enum RgbLibWitnessVersion {
  taproot('taproot'),
  segwitV0('segwit-v0');

  const RgbLibWitnessVersion(this.wireValue);

  final String wireValue;
}

/// Account extended public keys and master fingerprint for one witness version.
final class RgbLibPublicKeys {
  const RgbLibPublicKeys({
    required this.accountXpubVanilla,
    required this.accountXpubColored,
    required this.masterFingerprint,
  });

  final String accountXpubVanilla;
  final String accountXpubColored;
  final String masterFingerprint;

  void validate(String network) {
    final versions = getNetworkVersions(network).toBip32Network();
    try {
      for (final value in [accountXpubVanilla, accountXpubColored]) {
        final key = BIP32.fromBase58(value, versions);
        if (!key.isNeutered()) {
          invalidRgbLibConfig('Account keys must be public extended keys.');
        }
      }
    } catch (_) {
      invalidRgbLibConfig('Invalid extended public keys for this network.');
    }
    if (!RegExp(r'^[a-fA-F0-9]{8}$').hasMatch(masterFingerprint)) {
      invalidRgbLibConfig('Invalid master fingerprint.');
    }
  }
}

/// Reads a mnemonic from the host each time a native session opens.
typedef RgbLibMnemonicReader = FutureOr<String?> Function();

/// Signing or watch-only key material. Prefer a secure reader for persisted keys.
final class RgbLibKeys {
  RgbLibKeys.mnemonic(String mnemonic, {this.publicKeys})
    : readMnemonic = (() => mnemonic) {
    if (mnemonic.trim().isEmpty) {
      invalidRgbLibConfig('The mnemonic must not be empty.');
    }
  }

  const RgbLibKeys.reader(RgbLibMnemonicReader reader, {this.publicKeys})
    : readMnemonic = reader;

  const RgbLibKeys.watchOnly(RgbLibPublicKeys keys)
    : publicKeys = keys,
      readMnemonic = null;

  final RgbLibMnemonicReader? readMnemonic;
  final RgbLibPublicKeys? publicKeys;
}

enum RgbLibIndexerKind { electrum, esplora, bitcoind }

/// Bitcoin indexer and, for bitcoind, exactly one authentication mechanism.
final class RgbLibIndexer {
  const RgbLibIndexer.electrum(this.url)
    : kind = RgbLibIndexerKind.electrum,
      username = null,
      password = null,
      cookieFile = null;

  const RgbLibIndexer.esplora(this.url)
    : kind = RgbLibIndexerKind.esplora,
      username = null,
      password = null,
      cookieFile = null;

  const RgbLibIndexer.bitcoind(
    this.url, {
    required String this.username,
    required String this.password,
  }) : kind = RgbLibIndexerKind.bitcoind,
       cookieFile = null;

  const RgbLibIndexer.bitcoindCookie(this.url, String this.cookieFile)
    : kind = RgbLibIndexerKind.bitcoind,
      username = null,
      password = null;

  final RgbLibIndexerKind kind;
  final String url;
  final String? username;
  final String? password;
  final String? cookieFile;
}

/// Configuration for an RGB_L1 online session, with protocol 1.0 RGB transport.
final class RgbLibUnlockParams {
  RgbLibUnlockParams({
    this.indexer,
    this.indexerUrl,
    this.proxyEndpoint,
    Map<String, String> evmRpcUrls = const {},
    Map<String, String> proxyAuthKeys = const {},
  }) : evmRpcUrls = Map.unmodifiable(evmRpcUrls),
       proxyAuthKeys = Map.unmodifiable(proxyAuthKeys);

  final RgbLibIndexer? indexer;
  final String? indexerUrl;
  final String? proxyEndpoint;
  final Map<String, String> evmRpcUrls;
  final Map<String, String> proxyAuthKeys;
}

/// SDK beta.40 RGB_L1 defaults, kept separate from legacy RLN proxy defaults.
NetworkEndpoints? getRgbLibNetworkDefaults(String network) {
  final indexer = switch (network) {
    'mainnet' => 'ssl://electrs-01.utexo.com:50002',
    'utexo' => 'https://dev.esplora-01.mint.utexo.com',
    'testnet' || 'testnet4' || 'signet' => DEFAULT_INDEXER_URLS[network],
    _ => null,
  };
  final proxy = switch (network) {
    'mainnet' => 'rpcs://rgb-proxy.utexo.com/json-rpc',
    'utexo' => 'rpcs://dev.rgb-proxy.utexo.com/json-rpc',
    'signet' => 'rpcs://staging.rgb-proxy.utexo.com/json-rpc',
    'testnet' || 'testnet4' => DEFAULT_TRANSPORT_ENDPOINTS[network],
    _ => null,
  };
  if (indexer == null || proxy == null) return null;
  return NetworkEndpoints(indexerUrl: indexer, proxyEndpoint: proxy);
}

Never invalidRgbLibConfig(String message) =>
    throw RgbLibWalletException(message, code: 'INVALID_CONFIG');

void validateRgbLibWalletParams(RgbLibWalletParams params) {
  if (!BIP32_VERSIONS.containsKey(params.network)) {
    invalidRgbLibConfig('Unsupported wallet network.');
  }
  if (!isAbsoluteRgbLibPath(params.storageDirPath)) {
    invalidRgbLibConfig('Wallet storage requires an absolute native path.');
  }
  if (params.maxAllocationsPerUtxo < 1 ||
      params.maxAllocationsPerUtxo > 0xffffffff) {
    invalidRgbLibConfig('Invalid maximum allocations per UTXO.');
  }
}

bool isAbsoluteRgbLibPath(String value) =>
    value.startsWith('/') && !value.contains('\u0000');

String rgbLibLocalFile(String value) {
  if (isAbsoluteRgbLibPath(value)) return value;
  try {
    final uri = Uri.parse(value);
    if (uri.scheme == 'file' &&
        (uri.host.isEmpty || uri.host == 'localhost') &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        isAbsoluteRgbLibPath(uri.path)) {
      final path = Uri.decodeComponent(uri.path);
      if (isAbsoluteRgbLibPath(path)) return path;
    }
  } on FormatException {
    // Use the same stable error for an invalid URI and a non-local path.
  }
  invalidRgbLibConfig('A local absolute path or file URI is required.');
}

Uri _url(String value, Set<String> schemes, String field) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !schemes.contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.hasPort && (uri.port < 1 || uri.port > 65535)) ||
      uri.hasFragment ||
      RegExp(r'[\s\\]').hasMatch(value)) {
    invalidRgbLibConfig('Invalid $field URL.');
  }
  return uri;
}

String _proxy(String value) {
  final uri = _url(value, {'rpc', 'rpcs', 'http', 'https'}, 'RGB proxy');
  return switch (uri.scheme) {
    'https' => value.replaceFirst(
      RegExp(r'^https:', caseSensitive: false),
      'rpcs:',
    ),
    'http' => value.replaceFirst(
      RegExp(r'^http:', caseSensitive: false),
      'rpc:',
    ),
    _ => value,
  };
}

typedef RgbLibOnlineConfig = ({
  Map<String, Object?> nativeArguments,
  String proxyEndpoint,
});

RgbLibOnlineConfig resolveRgbLibOnline(
  String network,
  RgbLibUnlockParams params,
) {
  if (params.indexer != null && params.indexerUrl != null) {
    invalidRgbLibConfig('Provide either indexer or indexerUrl.');
  }
  final defaults = getRgbLibNetworkDefaults(network);
  final endpoint = params.indexerUrl ?? defaults?.indexerUrl;
  final indexer =
      params.indexer ??
      (endpoint == null
          ? invalidRgbLibConfig('An explicit indexer is required.')
          : endpoint.startsWith('ssl://') || endpoint.startsWith('tcp://')
          ? RgbLibIndexer.electrum(endpoint)
          : RgbLibIndexer.esplora(endpoint));
  _url(
    indexer.url,
    indexer.kind == RgbLibIndexerKind.electrum
        ? {'ssl', 'tcp'}
        : {'http', 'https'},
    'indexer',
  );
  final cookieFile = indexer.cookieFile;
  if (cookieFile != null && !isAbsoluteRgbLibPath(cookieFile)) {
    invalidRgbLibConfig('An absolute bitcoind cookie path is required.');
  }
  final proxy = _proxy(
    params.proxyEndpoint ??
        defaults?.proxyEndpoint ??
        invalidRgbLibConfig('An explicit RGB proxy is required.'),
  );
  final chains = params.evmRpcUrls.keys.toList()..sort();
  for (final chain in chains) {
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(chain) ||
        BigInt.parse(chain) > BigInt.parse('18446744073709551615')) {
      invalidRgbLibConfig('EVM chain IDs must be positive UInt64 decimals.');
    }
    _url(params.evmRpcUrls[chain]!, {'https', 'http'}, 'EVM RPC');
  }
  final auth = <String, String>{};
  for (final entry in params.proxyAuthKeys.entries) {
    final endpoint = _proxy(entry.key);
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(entry.value)) {
      invalidRgbLibConfig('Proxy authentication keys must be 32-byte hex.');
    }
    if (auth.containsKey(endpoint) && auth[endpoint] != entry.value) {
      invalidRgbLibConfig('Conflicting RGB proxy authentication keys.');
    }
    auth[endpoint] = entry.value;
  }
  final proxies = auth.keys.toList()..sort();
  return (
    proxyEndpoint: proxy,
    nativeArguments: {
      'indexerKind': indexer.kind.name,
      'indexerUrl': indexer.url,
      'username': indexer.username,
      'password': indexer.password,
      'cookieFile': indexer.cookieFile,
      'evmChainIds': chains,
      'evmRpcUrls': [for (final chain in chains) params.evmRpcUrls[chain]!],
      'proxyEndpoints': proxies,
      'proxyAuthKeys': [for (final proxy in proxies) auth[proxy]!],
    },
  );
}
