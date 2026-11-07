package com.utexo.rgb_sdk_flutter
fun main() {
  check(RgbLibNetworkPolicy.nativeNetwork("utexo") == "signet")
  check(RgbLibNetworkPolicy.nativeNetwork("signet") == "signet")
  check(RgbLibNetworkPolicy.deploymentUnavailable("utexo"))
  check(!RgbLibNetworkPolicy.deploymentUnavailable("signet"))
  for (kind in listOf("devSignetEsplora","devSignetElectrum")) {
    check(RgbLibNetworkPolicy.indexerKind("utexo",kind)==kind)
    check(RgbLibNetworkPolicy.indexerKind("signet",kind)==null)
  }
  for (kind in listOf("esplora","electrum","bitcoind")) {
    check(RgbLibNetworkPolicy.indexerKind("utexo",kind)==null)
    check(RgbLibNetworkPolicy.indexerKind("signet",kind)==kind)
  }
  println("Kotlin Dev profile selection, public isolation and closed gate passed")
}
