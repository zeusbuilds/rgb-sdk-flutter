package com.utexo.rgb_sdk_flutter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

internal class RgbLibOperationPolicyTest {
  private class Pending : Exception()

  @Test fun pendingPaymentsFenceOrdinaryAndFutureNativeMutations() {
    for (operation in listOf("sendBtc", "send", "createUtxos", "issueAssetNia", "burn",
        "drainTo", "deleteTransfers", "signPsbt", "sendBtcBegin", "sendBtcEnd", "futureMutation")) {
      var calls = 0
      assertFailsWith<Pending> {
        RgbLibOperationPolicy.perform(operation, { throw Pending() }) { calls++ }
      }
      assertEquals(0, calls, operation)
    }
  }

  @Test fun pendingPaymentsRetainObservationRecoveryAndBackup() {
    for (operation in listOf("getBtcBalance", "getAssetMetadata", "getReceivedMint", "listOnchainSendReceipts", "onchainRecoveryState",
        "onchainSendStatus", "cancelOnchainSend", "revokeOnchainSend", "sync", "refresh", "backup")) {
      var calls = 0
      RgbLibOperationPolicy.perform(operation, { throw Pending() }) { calls++ }
      assertEquals(1, calls, operation)
    }
  }
}
