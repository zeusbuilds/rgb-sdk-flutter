package com.utexo.rgb_sdk_flutter

private class PendingPayment : Exception()

fun main() {
  check(RgbLibRevocationPolicy.isAvailable(true))
  for (value in listOf(null, false, "true", 1, 1.0)) check(!RgbLibRevocationPolicy.isAvailable(value))
  val mutations = listOf(
    "sendBtc", "send", "createUtxos", "issueAssetNia", "issueAssetCfa", "issueAssetUda",
    "issueAssetIfa", "inflate", "burn", "drainTo", "deleteTransfers", "failTransfers",
    "receive", "getAddress", "importContract", "signPsbt", "sendBtcBegin", "sendBtcEnd",
    "sendRgbBegin", "sendRgbEnd", "futureUnknownMutation"
  )
  for (operation in mutations) {
    var calls = 0
    var checks = 0
    try {
      RgbLibOperationPolicy.perform(operation, { checks++; throw PendingPayment() }) { calls++ }
      error("Pending operation was not blocked: $operation")
    } catch (_: PendingPayment) {}
    check(checks == 1 && calls == 0) { "Mutation escaped pending fence: $operation" }
    RgbLibOperationPolicy.perform(operation, { checks++ }) { calls++ }
    check(checks == 2 && calls == 1) { "Idle mutation was blocked: $operation" }
  }
  val allowedOperations = listOf("getBtcBalance", "getAssetMetadata", "getPublicKeys", "getReceivedMint", "listTransfers",
    "onchainRecoveryState", "listOnchainSendReceipts", "onchainSendStatus", "cancelOnchainSend", "revokeOnchainSend", "backup", "sync", "refresh")
  for (operation in allowedOperations) {
    var calls = 0
    RgbLibOperationPolicy.perform(operation, { error("Explicit recovery operation was blocked: $operation") }) { calls++ }
    check(calls == 1)
  }
  println("Kotlin operation policy: ${mutations.size} fenced mutations and ${allowedOperations.size} explicitly allowed recovery operations passed")
}
