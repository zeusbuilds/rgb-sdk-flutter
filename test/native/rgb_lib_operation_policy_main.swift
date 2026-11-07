enum PendingPayment: Error { case pending }

@main struct OperationPolicyChecks {
  static func main() throws {
    let mutations = [
      "sendBtc", "send", "createUtxos", "issueAssetNia", "issueAssetCfa", "issueAssetUda",
      "issueAssetIfa", "inflate", "burn", "drainTo", "deleteTransfers", "failTransfers",
      "receive", "getAddress", "importContract", "signPsbt", "sendBtcBegin", "sendBtcEnd",
      "sendRgbBegin", "sendRgbEnd", "futureUnknownMutation"
    ]
    for operation in mutations {
      var calls = 0, checks = 0
      do {
        try RgbLibOperationPolicy.perform(operation, assertNoPending: {
          checks += 1; throw PendingPayment.pending
        }, action: { calls += 1 })
        preconditionFailure("Pending operation was not blocked: \(operation)")
      } catch PendingPayment.pending {}
      precondition(checks == 1 && calls == 0, "Mutation escaped pending fence: \(operation)")
      RgbLibOperationPolicy.perform(operation, assertNoPending: { checks += 1 }, action: { calls += 1 })
      precondition(checks == 2 && calls == 1, "Idle mutation was blocked: \(operation)")
    }
    let reads = ["getBtcBalance", "getAssetMetadata", "getPublicKeys", "getReceivedMint", "listTransfers",
      "onchainRecoveryState", "listOnchainSendReceipts", "onchainSendStatus", "cancelOnchainSend", "backup", "sync", "refresh"]
    for operation in reads {
      var calls = 0
      RgbLibOperationPolicy.perform(operation, assertNoPending: {
        preconditionFailure("Recovery observation was blocked: \(operation)")
      }, action: { calls += 1 })
      precondition(calls == 1)
    }
    print("Swift operation policy: \(mutations.count) fenced mutations and \(reads.count) recovery observations passed")
  }
}
