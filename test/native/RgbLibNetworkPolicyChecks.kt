package com.utexo.rgb_sdk_flutter
fun main() {
  check(RgbLibNetworkPolicy.nativeNetwork("utexo") == "signet")
  check(RgbLibNetworkPolicy.nativeNetwork("signet") == "signet")
  val revision = "utexo-dev-busdt-20261109-v1"
  val indexer = "https://dev.esplora-01.mint.utexo.com"
  val proxy = "rpcs://dev.rgb-proxy.utexo.com/json-rpc"
  check(!RgbLibNetworkPolicy.permitsOpen("utexo"))
  check(RgbLibNetworkPolicy.permitsOpen("utexo", revision))
  check(!RgbLibNetworkPolicy.permitsOpen("signet", revision))
  check(RgbLibNetworkPolicy.permitsOpen("signet"))
  for (kind in listOf("devSignetEsplora","devSignetElectrum")) {
    check(RgbLibNetworkPolicy.indexerKind("utexo",kind)==kind)
    check(RgbLibNetworkPolicy.indexerKind("signet",kind)==null)
  }
  for (kind in listOf("esplora","electrum","bitcoind")) {
    check(RgbLibNetworkPolicy.indexerKind("utexo",kind)==null)
    check(RgbLibNetworkPolicy.indexerKind("signet",kind)==kind)
  }
  check(RgbLibNetworkPolicy.permitsIndexer("utexo", "devSignetEsplora", indexer))
  check(!RgbLibNetworkPolicy.permitsIndexer("utexo", "esplora", indexer))
  check(!RgbLibNetworkPolicy.permitsIndexer("utexo", "devSignetEsplora", "$indexer/"))
  check(!RgbLibNetworkPolicy.permitsIndexer("utexo", null, indexer))
  check(RgbLibNetworkPolicy.permitsReceive("utexo", listOf(proxy)))
  check(!RgbLibNetworkPolicy.permitsReceive("utexo", emptyList()))
  check(!RgbLibNetworkPolicy.permitsSend("utexo", listOf(proxy,"rpcs://other.test"), proxy))
  check(!RgbLibNetworkPolicy.permitsSend("utexo", listOf(proxy), "rpcs://other.test"))
  check(!RgbLibNetworkPolicy.permitsBurn("utexo"))
  check(RgbLibNetworkPolicy.permitsBurn("regtest"))
  fun permitsOnline(endpoint: String?, max: String) = RgbLibNetworkPolicy.permitsOnline(
    "utexo", endpoint, emptyList(), listOf("42161"), listOf("https://arb1.arbitrum.io/rpc"), listOf("2"), listOf(max)
  )
  check(permitsOnline(proxy, "7200"))
  check(!permitsOnline(proxy, "512"))
  check(!permitsOnline(null, "7200"))
  println("Kotlin hosted Dev admission and public Signet isolation passed")
}
