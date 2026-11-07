package com.utexo.rgb_sdk_flutter

/** Pure selection only: no endpoint, key, file, or deployment authorization. */
internal object RgbLibNetworkPolicy {
  fun nativeNetwork(logical: String): String = if (logical == "utexo") "signet" else logical
  fun deploymentUnavailable(logical: String): Boolean = logical == "utexo"
  fun indexerKind(logical: String, requested: String): String? =
    if (logical == "utexo") requested.takeIf { it in setOf("devSignetElectrum", "devSignetEsplora") }
    else requested.takeIf { it in setOf("electrum", "esplora", "bitcoind") }
}
