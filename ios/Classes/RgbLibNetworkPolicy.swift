/// Pure selection only: no endpoint, key, file, or deployment authorization.
enum RgbLibNetworkPolicy {
  static func nativeNetwork(_ logical: String) -> String { logical == "utexo" ? "signet" : logical }
  static func deploymentUnavailable(_ logical: String) -> Bool { logical == "utexo" }
  static func indexerKind(_ logical: String, _ requested: String) -> String? {
    let allowed: Set<String> = logical == "utexo"
      ? ["devSignetElectrum", "devSignetEsplora"] : ["electrum", "esplora", "bitcoind"]
    return allowed.contains(requested) ? requested : nil
  }
}
