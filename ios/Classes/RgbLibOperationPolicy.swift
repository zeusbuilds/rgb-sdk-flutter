/// Every unlisted native operation must prove that no payment remains pending.
/// Allowed actions include native-authorized recovery/progression, not only reads.
/// In particular, native refresh rejects restored snapshots before protocol work.
enum RgbLibOperationPolicy {
  private static let allowedWhilePending: Set<String> = [
    "closeWallet", "getWalletIdentity", "getPublicKeys", "getReceivedMint", "goOnline", "getBtcBalance",
    "getAssetBalance", "listAssets", "getAssetMetadata", "listUnspents", "listTransactions",
    "listTransfers", "decodeInvoice", "checkIndexerUrl", "sync", "estimateFeeRate",
    "getNetworkInfo", "refresh", "backup", "getConsignmentPath", "getConsignment",
    "prepareOnchainSend", "commitOnchainSend", "onchainSendStatus", "cancelOnchainSend", "revokeOnchainSend",
    "onchainRecoveryState", "listOnchainSendReceipts",
    "bridgeBlindReceive", "prepareBridgeBurn", "commitBridgeBurn", "observeBridgeBurn", "cancelBridgeBurn", "bridgeBurnProof"
  ]

  static func perform<T>(_ operation: String, assertNoPending: () throws -> Void,
                         action: () throws -> T) rethrows -> T {
    if !allowedWhilePending.contains(operation) { try assertNoPending() }
    return try action()
  }
}
