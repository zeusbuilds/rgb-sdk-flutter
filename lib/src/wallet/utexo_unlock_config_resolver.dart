part of 'utexo_wallet.dart';

UtexoUnlockConfig resolveUnlockConfig(
  String network,
  UtexoUnlockConfig config,
) {
  final defaults = getNetworkDefaults(network);
  final indexerUrl = _blankToNull(config.indexerUrl) ?? defaults?.indexerUrl;
  final proxyEndpoint =
      _blankToNull(config.proxyEndpoint) ?? defaults?.proxyEndpoint;
  final bitcoindRpcHost = _blankToNull(config.bitcoindRpcHost);
  final bitcoindRpcUsername = _blankToNull(config.bitcoindRpcUsername);
  requireQualifiedUtexoDevSignet(
    endpoints: [indexerUrl, proxyEndpoint, bitcoindRpcHost, config.ethRpcUrl],
  );
  final resolved = UtexoUnlockConfig(
    bitcoindRpcUsername: bitcoindRpcUsername,
    bitcoindRpcPassword: config.bitcoindRpcPassword,
    bitcoindRpcHost: bitcoindRpcHost,
    bitcoindRpcPort: config.bitcoindRpcPort,
    indexerUrl: indexerUrl,
    proxyEndpoint: proxyEndpoint,
    announceAddresses: config.announceAddresses,
    announceAlias: config.announceAlias,
    gossipRgsServerUrl: _blankToNull(config.gossipRgsServerUrl),
    ethRpcUrl: _blankToNull(config.ethRpcUrl),
  );

  final hasIndexer = resolved.indexerUrl != null;
  final bitcoindValues = <Object?>[
    resolved.bitcoindRpcUsername,
    resolved.bitcoindRpcPassword,
    resolved.bitcoindRpcHost,
    resolved.bitcoindRpcPort,
  ];
  final bitcoindValueCount = bitcoindValues
      .where((value) => value != null)
      .length;
  if (bitcoindValueCount > 0 && bitcoindValueCount < bitcoindValues.length) {
    throw const WalletValidationException(
      'Provide all bitcoind RPC parameters or none of them.',
      field: 'bitcoindRpc',
    );
  }
  if (resolved.bitcoindRpcPort case final port?) {
    if (port < 1 || port > 65535) {
      throw const WalletValidationException(
        'bitcoindRpcPort must be between 1 and 65535.',
        field: 'bitcoindRpcPort',
      );
    }
  }
  final hasBitcoind = bitcoindValueCount == bitcoindValues.length;
  if (!hasIndexer && !hasBitcoind) {
    throw WalletValidationException(
      'No chain backend configured for network "$network". '
      'Provide indexerUrl or complete bitcoind RPC parameters in unlock config.',
      field: 'indexerUrl',
    );
  }
  return resolved;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

UtexoUnlockConfig resolveUnlockParams(
  String network,
  UtexoUnlockConfig params,
) {
  return resolveUnlockConfig(network, params);
}
