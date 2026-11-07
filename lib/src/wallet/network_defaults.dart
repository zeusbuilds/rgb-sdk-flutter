import '../crypto/constants.dart';
import '../crypto/validation.dart';
import '../errors/rgb_sdk_exception.dart';

class NetworkEndpoints {
  const NetworkEndpoints({
    required this.indexerUrl,
    required this.proxyEndpoint,
  });

  final String indexerUrl;
  final String proxyEndpoint;
}

String normalizeNativeRlnNetwork(String network) {
  final normalized = normalizeNetwork(network.trim().toLowerCase());
  if (normalized == 'utexo') return 'signet';
  return normalized;
}

NetworkEndpoints? getNetworkDefaults(String network) {
  final normalized = normalizeNetwork(network.trim());
  final indexerUrl = DEFAULT_INDEXER_URLS[normalized];
  final proxyEndpoint = DEFAULT_TRANSPORT_ENDPOINTS[normalized];
  if (indexerUrl == null || proxyEndpoint == null) return null;

  final proxyOverride = switch (normalized) {
    // Legacy RLN consumes protocol 0.2; RGB_L1 owns its separate 1.0 defaults.
    'utexo' || 'signet' => 'rpcs://proxy.iriswallet.com/0.2/json-rpc',
    _ => proxyEndpoint,
  };

  return NetworkEndpoints(indexerUrl: indexerUrl, proxyEndpoint: proxyOverride);
}

String? getDefaultLspBaseUrl(String network) {
  return switch (normalizeNetwork(network.trim())) {
    'utexo' => 'https://lsp-signet.utexo.com',
    _ => null,
  };
}

String resolveLspBaseUrl(String network, String? lspBaseUrl) {
  final explicit = lspBaseUrl?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final resolved = getDefaultLspBaseUrl(network);
  if (resolved != null && resolved.isNotEmpty) return resolved;
  throw WalletValidationException(
    'No lspBaseUrl configured for network "$network" and no default is available. '
    'Set lspBaseUrl in the wallet config or pass an explicit LspPeer to createLsp().',
    field: 'lspBaseUrl',
  );
}
