@main struct NetworkPolicyChecks {
 static func main() {
  precondition(RgbLibNetworkPolicy.nativeNetwork("utexo") == "signet")
  precondition(RgbLibNetworkPolicy.nativeNetwork("signet") == "signet")
  let revision = "utexo-dev-busdt-20261109-v1"
  let indexer = "https://dev.esplora-01.mint.utexo.com"
  let proxy = "rpcs://dev.rgb-proxy.utexo.com/json-rpc"
  precondition(!RgbLibNetworkPolicy.permitsOpen("utexo"))
  precondition(RgbLibNetworkPolicy.permitsOpen("utexo", deployment: revision))
  precondition(!RgbLibNetworkPolicy.permitsOpen("signet", deployment: revision))
  precondition(RgbLibNetworkPolicy.permitsOpen("signet"))
  for kind in ["devSignetEsplora","devSignetElectrum"] {
   precondition(RgbLibNetworkPolicy.indexerKind("utexo",kind)==kind)
   precondition(RgbLibNetworkPolicy.indexerKind("signet",kind)==nil)
  }
  for kind in ["esplora","electrum","bitcoind"] {
   precondition(RgbLibNetworkPolicy.indexerKind("utexo",kind)==nil)
   precondition(RgbLibNetworkPolicy.indexerKind("signet",kind)==kind)
  }
  precondition(RgbLibNetworkPolicy.permitsIndexer("utexo", kind: "devSignetEsplora", url: indexer))
  precondition(!RgbLibNetworkPolicy.permitsIndexer("utexo", kind: "esplora", url: indexer))
  precondition(!RgbLibNetworkPolicy.permitsIndexer("utexo", kind: "devSignetEsplora", url: indexer + "/"))
  precondition(!RgbLibNetworkPolicy.permitsIndexer("utexo", kind: nil, url: indexer))
  precondition(RgbLibNetworkPolicy.permitsReceive("utexo", endpoints: [proxy]))
  precondition(!RgbLibNetworkPolicy.permitsReceive("utexo", endpoints: []))
  precondition(!RgbLibNetworkPolicy.permitsSend("utexo", endpoints: [proxy, "rpcs://other.test"], sender: proxy))
  precondition(!RgbLibNetworkPolicy.permitsSend("utexo", endpoints: [proxy], sender: "rpcs://other.test"))
  precondition(!RgbLibNetworkPolicy.permitsBurn("utexo"))
  precondition(RgbLibNetworkPolicy.permitsBurn("regtest"))
  func permitsOnline(_ endpoint: String?, max: String) -> Bool {
    RgbLibNetworkPolicy.permitsOnline("utexo", proxy: endpoint, proxyAuthEndpoints: [],
      chainIds: ["42161"], rpcUrls: ["https://arb1.arbitrum.io/rpc"], minimums: ["2"], maximums: [max])
  }
  precondition(permitsOnline(proxy, max: "7200"))
  precondition(!permitsOnline(proxy, max: "512"))
  precondition(!permitsOnline(nil, max: "7200"))
  print("Swift hosted Dev admission and public Signet isolation passed")
 }
}
