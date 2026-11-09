import '../errors/rgb_sdk_exception.dart';

// Keep these in sync with the Kotlin and Swift wrapper policies. The reviewed
// deployment facts are recorded in tool/dev_signet_deployment_requirements.json.
const utexoDevSignetDeployment = 'utexo-dev-busdt-20261109-v1';
const utexoDevSignetIndexer = 'https://dev.esplora-01.mint.utexo.com';
const utexoDevSignetProxy = 'rpcs://dev.rgb-proxy.utexo.com/json-rpc';
const utexoDevSignetEvmChain = '42161';
const utexoDevSignetEvmRpc = 'https://arb1.arbitrum.io/rpc';
const utexoDevSignetMinMintLock = 2;
const utexoDevSignetMaxMintLock = 7200;
const utexoDevBridgeOrigin = 'https://dev.mint.utexo.com';
const utexoDevBridgeAssetId =
    'rgb:A6k89KtR-e3oXqRP-uH3jUrz-LU_sYL3-hMZ0k3O-6u8DXbE';

bool isUtexoDevSignetTransport(List<String> endpoints) =>
    endpoints.length == 1 && endpoints.single == utexoDevSignetProxy;

const utexoDevSignetServiceHosts = <String>{
  'dev.esplora-01.mint.utexo.com',
  'dev.rgb-proxy.utexo.com',
  'esplora-api.utexo.com',
  'rgb-proxy.dev.utexo.com',
};

/// Stops known Dev configuration outside the explicitly admitted RGB_L1 path.
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
    unqualifiedUtexoDevSignet();
  }
}

Never unqualifiedUtexoDevSignet() => throw const WalletException(
  'The dedicated UTEXO Dev Signet configuration is required.',
  code: 'DEPLOYMENT_UNQUALIFIED',
);
