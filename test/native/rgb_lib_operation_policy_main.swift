import Foundation
enum PendingPayment: Error { case pending }

@main struct OperationPolicyChecks {
  static func main() throws {
    precondition(RgbLibExistingOpenPolicy.parseFlag(nil, present: false) == false)
    precondition(RgbLibExistingOpenPolicy.parseFlag(false, present: true) == false)
    precondition(RgbLibExistingOpenPolicy.parseFlag(true, present: true) == true)
    for value: Any? in [nil, NSNull(), "true", 0, 1, 1.0, NSNumber(value: 1)] {
      precondition(RgbLibExistingOpenPolicy.parseFlag(value, present: true) == nil)
    }
    precondition(RgbLibExistingOpenPolicy.permitsProfile(existingOnly: false, profileExists: false))
    precondition(RgbLibExistingOpenPolicy.permitsProfile(existingOnly: true, profileExists: true))
    precondition(!RgbLibExistingOpenPolicy.permitsProfile(existingOnly: true, profileExists: false))
    precondition(RgbLibRevocationPolicy.isAvailable(true))
    for value: Any? in [nil, false, "true", 1, 1.0, NSNumber(value: 1)] {
      precondition(!RgbLibRevocationPolicy.isAvailable(value))
    }
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
    let allowedOperations = ["getBtcBalance", "getAssetMetadata", "getPublicKeys", "getReceivedMint", "listTransfers",
      "onchainRecoveryState", "listOnchainSendReceipts", "onchainSendStatus", "cancelOnchainSend", "revokeOnchainSend", "backup", "sync", "refresh"]
    for operation in allowedOperations {
      var calls = 0
      RgbLibOperationPolicy.perform(operation, assertNoPending: {
        preconditionFailure("Explicit recovery operation was blocked: \(operation)")
      }, action: { calls += 1 })
      precondition(calls == 1)
    }
    print("Swift operation policy: \(mutations.count) fenced mutations and \(allowedOperations.count) explicitly allowed recovery operations passed")
  }
}
