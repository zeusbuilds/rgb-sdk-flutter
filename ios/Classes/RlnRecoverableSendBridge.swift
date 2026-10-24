import Flutter

// ROOT-01: this extension remains unsupported against official older artifacts.
// A separately verified native rebuild is required before enabling its flag.
extension RgbSdkFlutterPlugin {
  func rlnPrepareOnchainSend(nodeId: Int64, requestJson: String) throws -> String {
    try runRln("rlnPrepareOnchainSend") {
      #if RGB_RECOVERABLE_ONCHAIN_SEND
      return try nodeStore.get(id: nodeId).prepareOnchainSend(requestJson: requestJson)
      #else
      throw recoverableSendUnavailable("rlnPrepareOnchainSend")
      #endif
    }
  }

  func rlnCommitOnchainSend(nodeId: Int64, requestJson: String) throws -> String {
    try runRln("rlnCommitOnchainSend") {
      #if RGB_RECOVERABLE_ONCHAIN_SEND
      return try nodeStore.get(id: nodeId).commitOnchainSend(requestJson: requestJson)
      #else
      throw recoverableSendUnavailable("rlnCommitOnchainSend")
      #endif
    }
  }

  func rlnOnchainSendStatus(nodeId: Int64, requestJson: String) throws -> String {
    try runRln("rlnOnchainSendStatus") {
      #if RGB_RECOVERABLE_ONCHAIN_SEND
      return try nodeStore.get(id: nodeId).onchainSendStatus(requestJson: requestJson)
      #else
      throw recoverableSendUnavailable("rlnOnchainSendStatus")
      #endif
    }
  }

  private func recoverableSendUnavailable(_ operation: String) -> PigeonError {
    PigeonError(
      code: "UnsupportedOperationException",
      message: "This native artifact does not support durable on-chain sends.",
      details: bridgeErrorDetails(operation, category: "unsupported", retryable: false,
                                  extra: ["feature": "recoverableOnchainSend"])
    )
  }

  func rlnCancelOnchainSend(nodeId: Int64, requestJson: String) throws -> String {
    try runRln("rlnCancelOnchainSend") {
      #if RGB_RECOVERABLE_ONCHAIN_SEND
      return try nodeStore.get(id: nodeId).cancelOnchainSend(requestJson: requestJson)
      #else
      throw recoverableSendUnavailable("rlnCancelOnchainSend")
      #endif
    }
  }

}
