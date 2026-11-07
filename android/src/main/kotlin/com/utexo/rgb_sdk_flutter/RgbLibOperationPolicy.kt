package com.utexo.rgb_sdk_flutter

/**
 * Every unlisted operation must prove that no payment remains pending.
 * Allowed actions include native-authorized progression, not only reads:
 * native refresh rejects restored snapshots before any protocol work.
 */
internal object RgbLibOperationPolicy {
  private val allowedWhilePending = setOf(
    "closeWallet", "getWalletIdentity", "getPublicKeys", "getReceivedMint", "goOnline", "getBtcBalance",
    "getAssetBalance", "listAssets", "getAssetMetadata", "listUnspents", "listTransactions",
    "listTransfers", "decodeInvoice", "checkIndexerUrl", "sync", "estimateFeeRate",
    "getNetworkInfo", "refresh", "backup", "getConsignmentPath", "getConsignment",
    "prepareOnchainSend", "commitOnchainSend", "onchainSendStatus", "cancelOnchainSend", "revokeOnchainSend",
    "onchainRecoveryState", "listOnchainSendReceipts"
  )

  fun <T> perform(operation: String, assertNoPending: () -> Unit, action: () -> T): T {
    if (operation !in allowedWhilePending) assertNoPending()
    return action()
  }
}
