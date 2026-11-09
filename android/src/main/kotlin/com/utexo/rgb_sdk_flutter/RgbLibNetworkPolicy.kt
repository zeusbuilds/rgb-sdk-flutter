package com.utexo.rgb_sdk_flutter

/** Selection and exact hosted Dev admission, independent of wallet storage. */
internal object RgbLibNetworkPolicy {
  private const val DEV_DEPLOYMENT = "utexo-dev-busdt-20261109-v1"
  private const val DEV_INDEXER = "https://dev.esplora-01.mint.utexo.com"
  private const val DEV_PROXY = "rpcs://dev.rgb-proxy.utexo.com/json-rpc"

  fun nativeNetwork(logical: String): String = if (logical == "utexo") "signet" else logical
  fun permitsOpen(logical: String, deployment: String? = null): Boolean =
    if (logical == "utexo") deployment == DEV_DEPLOYMENT else deployment == null

  fun indexerKind(logical: String, requested: String): String? =
    if (logical == "utexo") requested.takeIf { it in setOf("devSignetElectrum", "devSignetEsplora") }
    else requested.takeIf { it in setOf("electrum", "esplora", "bitcoind") }

  fun permitsIndexer(logical: String, kind: String?, url: String): Boolean =
    logical != "utexo" || (kind == "devSignetEsplora" && url == DEV_INDEXER)

  fun permitsReceive(logical: String, endpoints: List<String>): Boolean =
    logical != "utexo" || endpoints == listOf(DEV_PROXY)

  fun permitsSend(logical: String, endpoints: List<String>, sender: String?): Boolean =
    logical != "utexo" || (permitsReceive(logical, endpoints) && sender == DEV_PROXY)

  fun permitsBurn(logical: String): Boolean = logical != "utexo"

  fun permitsOnline(
    logical: String, proxy: String?, proxyAuthEndpoints: List<String>,
    chainIds: List<String>, rpcUrls: List<String>, minimums: List<String>, maximums: List<String>
  ): Boolean = logical != "utexo" || (
    proxy == DEV_PROXY && proxyAuthEndpoints.isEmpty() && chainIds == listOf("42161") &&
      rpcUrls == listOf("https://arb1.arbitrum.io/rpc") &&
      minimums == listOf("2") && maximums == listOf("7200")
  )
}
