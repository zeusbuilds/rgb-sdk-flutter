package com.utexo.rgb_sdk_flutter

private class PendingPayment : Exception()

fun main() {
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
  val reads = listOf("getBtcBalance", "getAssetMetadata", "getPublicKeys", "getReceivedMint", "listTransfers",
    "onchainRecoveryState", "listOnchainSendReceipts", "onchainSendStatus", "cancelOnchainSend", "backup", "sync", "refresh")
  for (operation in reads) {
    var calls = 0
    RgbLibOperationPolicy.perform(operation, { error("Recovery observation was blocked: $operation") }) { calls++ }
    check(calls == 1)
  }
  println("Kotlin operation policy: ${mutations.size} fenced mutations and ${reads.size} recovery observations passed")
}
