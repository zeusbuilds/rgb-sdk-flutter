package com.utexo.rgb_sdk_flutter

import com.utexo.RgbLibException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

internal class RgbLibRuntimeCapabilityTest {
  @Test fun revocationAdvertisementRetainsActualArchiveType() {
    val cases = listOf(
      "{}" to false,
      "{\"dispatched_rgb_revocation\":false}" to false,
      "{\"dispatched_rgb_revocation\":true}" to true,
      "{\"dispatched_rgb_revocation\":\"true\"}" to "true",
      "{\"dispatched_rgb_revocation\":1}" to 1,
      "{\"dispatched_rgb_revocation\":null}" to null
    )
    for ((metadata, expected) in cases) {
      val info = RgbLibSessionStore { metadata }
        .execute("getRuntimeInfo", emptyMap()) as Map<*, *>
      assertEquals(expected, info["supportsDispatchedRgbRevocation"], metadata)
      assertEquals(true, info["supportsExistingOnlyOpen"], metadata)
    }
  }

  @Test fun existingOnlyRawFlagIsStrictAndMissingProfileCannotPermitCreation() {
    assertEquals(false, RgbLibExistingOpenPolicy.parseFlag(null, false))
    assertEquals(false, RgbLibExistingOpenPolicy.parseFlag(false, true))
    assertEquals(true, RgbLibExistingOpenPolicy.parseFlag(true, true))
    for (value in listOf(null, "true", 0, 1, 1L, 1.0)) {
      assertEquals(null, RgbLibExistingOpenPolicy.parseFlag(value, true))
      val failure = assertFailsWith<RgbLibBridgeError> {
        RgbLibSessionStore().execute("openWallet", mapOf(
          "network" to "regtest", "requireExisting" to value,
          "mnemonic" to "must-never-reach-native-key-parser"
        ))
      }
      assertEquals("INVALID_CONFIG", failure.code)
    }
    assertTrue(RgbLibExistingOpenPolicy.permitsProfile(false, false))
    assertTrue(RgbLibExistingOpenPolicy.permitsProfile(true, true))
    assertFalse(RgbLibExistingOpenPolicy.permitsProfile(true, false))
  }

  @Test fun rawRevocationAuthorityRequiresAnActualBoolean() {
    assertTrue(RgbLibRevocationPolicy.isAvailable(true))
    for (value in listOf(null, false, "true", "TRUE", 1, 1L, 1.0)) {
      assertFalse(RgbLibRevocationPolicy.isAvailable(value), value.toString())
    }
  }

  @Test fun explicitRevocationDoesNotGrantAuthorityToUnlistedOperations() {
    class Pending : Exception()
    var calls = 0
    RgbLibOperationPolicy.perform("revokeOnchainSend", { throw Pending() }) { calls++ }
    assertEquals(1, calls)
    for (operation in listOf("revoke", "revoke_onchain_send", "revokeOnchainSendV2", "futureMutation")) {
      assertFailsWith<Pending>(operation) {
        RgbLibOperationPolicy.perform(operation, { throw Pending() }) { calls++ }
      }
      assertEquals(1, calls, operation)
    }
  }

  @Test fun nativeBackupErrorsStayTypedWithoutEchoingUnknownPayloads() {
    assertEquals("RECOVERY_BACKUP_INVALID",
      rgbLibErrorCode(RgbLibException.Recovery("RECOVERY_BACKUP_INVALID")))
    assertEquals("NATIVE_ERROR",
      rgbLibErrorCode(RgbLibException.Recovery("private_unexpected_payload")))
  }
}
