package com.utexo.rgb_sdk_flutter

/** Every unlisted native operation must prove that no payment remains pending. */
internal object RgbLibOperationPolicy {
  private val observations = setOf(
    "closeWallet", "getWalletIdentity", "getPublicKeys", "getReceivedMint", "goOnline", "getBtcBalance",
    "getAssetBalance", "listAssets", "getAssetMetadata", "listUnspents", "listTransactions",
    "listTransfers", "decodeInvoice", "checkIndexerUrl", "sync", "estimateFeeRate",
    "getNetworkInfo", "refresh", "backup", "getConsignmentPath", "getConsignment",
    "prepareOnchainSend", "commitOnchainSend", "onchainSendStatus", "cancelOnchainSend",
    "onchainRecoveryState", "listOnchainSendReceipts"
  )

  fun <T> perform(operation: String, assertNoPending: () -> Unit, action: () -> T): T {
    if (operation !in observations) assertNoPending()
    return action()
  }
}
