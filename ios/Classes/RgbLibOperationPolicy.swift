/// Every unlisted native operation must prove that no payment remains pending.
enum RgbLibOperationPolicy {
  private static let observations: Set<String> = [
    "closeWallet", "getWalletIdentity", "getPublicKeys", "getReceivedMint", "goOnline", "getBtcBalance",
    "getAssetBalance", "listAssets", "getAssetMetadata", "listUnspents", "listTransactions",
    "listTransfers", "decodeInvoice", "checkIndexerUrl", "sync", "estimateFeeRate",
    "getNetworkInfo", "refresh", "backup", "getConsignmentPath", "getConsignment",
    "prepareOnchainSend", "commitOnchainSend", "onchainSendStatus", "cancelOnchainSend",
    "onchainRecoveryState", "listOnchainSendReceipts"
  ]

  static func perform<T>(_ operation: String, assertNoPending: () throws -> Void,
                         action: () throws -> T) rethrows -> T {
    if !observations.contains(operation) { try assertNoPending() }
    return try action()
  }
}
