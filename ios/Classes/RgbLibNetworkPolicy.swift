/// Selection and exact hosted Dev admission, independent of wallet storage.
enum RgbLibNetworkPolicy {
  private static let devDeployment = "utexo-dev-busdt-20261109-v1"
  private static let devIndexer = "https://dev.esplora-01.mint.utexo.com"
  private static let devProxy = "rpcs://dev.rgb-proxy.utexo.com/json-rpc"

  static func nativeNetwork(_ logical: String) -> String { logical == "utexo" ? "signet" : logical }
  static func permitsOpen(_ logical: String, deployment: String? = nil) -> Bool {
    logical == "utexo" ? deployment == devDeployment : deployment == nil
  }

  static func indexerKind(_ logical: String, _ requested: String) -> String? {
    let allowed: Set<String> = logical == "utexo"
      ? ["devSignetElectrum", "devSignetEsplora"] : ["electrum", "esplora", "bitcoind"]
    return allowed.contains(requested) ? requested : nil
  }

  static func permitsIndexer(_ logical: String, kind: String?, url: String) -> Bool {
    logical != "utexo" || (kind == "devSignetEsplora" && url == devIndexer)
  }

  static func permitsReceive(_ logical: String, endpoints: [String]) -> Bool {
    logical != "utexo" || endpoints == [devProxy]
  }

  static func permitsSend(_ logical: String, endpoints: [String], sender: String?) -> Bool {
    logical != "utexo" || (permitsReceive(logical, endpoints: endpoints) && sender == devProxy)
  }

  static func permitsBurn(_ logical: String) -> Bool { logical != "utexo" }

  static func permitsOnline(_ logical: String, proxy: String?, proxyAuthEndpoints: [String],
                            chainIds: [String], rpcUrls: [String], minimums: [String], maximums: [String]) -> Bool {
    logical != "utexo" || (
      proxy == devProxy && proxyAuthEndpoints.isEmpty && chainIds == ["42161"] &&
      rpcUrls == ["https://arb1.arbitrum.io/rpc"] && minimums == ["2"] && maximums == ["7200"]
    )
  }
}
