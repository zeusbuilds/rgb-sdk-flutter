import '../errors/rgb_sdk_exception.dart';

// The reviewed deployment facts and unresolved prerequisites are recorded in
// tool/dev_signet_deployment_requirements.json. This is a compatibility gate,
// not a generic restriction on applications' independently qualified endpoints.
const utexoDevSignetServiceHosts = <String>{
  'dev.esplora-01.mint.utexo.com',
  'dev.rgb-proxy.utexo.com',
  'esplora-api.utexo.com',
  'rgb-proxy.dev.utexo.com',
};

/// Stops known Dev configuration before native connection or key access.
///
/// The `utexo` RGB_L1 profile means the distinct UTEXO Dev Signet chain. The
/// legacy RLN facade also uses that spelling for an older service profile, so
/// its caller checks actual endpoints without treating the alias as Dev.
void requireQualifiedUtexoDevSignet({
  bool customSignetProfile = false,
  Iterable<String?> endpoints = const [],
}) {
  final knownDevEndpoint = endpoints.any((endpoint) {
    if (endpoint == null) return false;
    final value = endpoint.trim();
    final uri = Uri.tryParse(
      value.contains('://')
          ? value
          : value.startsWith('//')
          ? 'tcp:$value'
          : 'tcp://$value',
    );
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    return utexoDevSignetServiceHosts.contains(host);
  });
  if (customSignetProfile || knownDevEndpoint) {
    throw const WalletException(
      'UTEXO Dev Signet is not qualified for this native runtime.',
      code: 'DEPLOYMENT_UNQUALIFIED',
    );
  }
}
