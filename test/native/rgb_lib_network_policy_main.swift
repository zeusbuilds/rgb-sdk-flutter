@main struct NetworkPolicyChecks {
 static func main() {
  precondition(RgbLibNetworkPolicy.nativeNetwork("utexo") == "signet")
  precondition(RgbLibNetworkPolicy.nativeNetwork("signet") == "signet")
  precondition(RgbLibNetworkPolicy.deploymentUnavailable("utexo"))
  precondition(!RgbLibNetworkPolicy.deploymentUnavailable("signet"))
  for kind in ["devSignetEsplora","devSignetElectrum"] {
   precondition(RgbLibNetworkPolicy.indexerKind("utexo",kind)==kind)
   precondition(RgbLibNetworkPolicy.indexerKind("signet",kind)==nil)
  }
  for kind in ["esplora","electrum","bitcoind"] {
   precondition(RgbLibNetworkPolicy.indexerKind("utexo",kind)==nil)
   precondition(RgbLibNetworkPolicy.indexerKind("signet",kind)==kind)
  }
  print("Swift Dev profile selection, public isolation and closed gate passed")
 }
}
