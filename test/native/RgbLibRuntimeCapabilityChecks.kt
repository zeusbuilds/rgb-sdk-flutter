package com.utexo.rgb_sdk_flutter

import com.utexo.RgbLibException

fun main(args: Array<String>) {
  val cases = listOf(
    "{}" to false,
    "{\"dispatched_rgb_revocation\":false}" to false,
    "{\"dispatched_rgb_revocation\":true}" to true,
    "{\"dispatched_rgb_revocation\":\"true\"}" to "true",
    "{\"dispatched_rgb_revocation\":1}" to 1,
    "{\"dispatched_rgb_revocation\":null}" to null
  )
  for ((metadata, expected) in cases) {
    val store = RgbLibSessionStore { metadata }
    val info = store.execute("getRuntimeInfo", emptyMap()) as Map<*, *>
    check(info["supportsDispatchedRgbRevocation"] == expected)
    check(info["supportsExistingOnlyOpen"] == true)
  }
  for (encoded in listOf("false", "\"true\"", "1", "null")) {
    val info = RgbLibSessionStore { "{\"durable_hosted_bridge\":$encoded}" }
      .execute("getRuntimeInfo", emptyMap()) as Map<*, *>
    check(info["supportsDurableHostedDevBridge"] == false)
  }
  val reviewed = RgbLibSessionStore { "{\"durable_hosted_bridge\":true}" }
    .execute("getRuntimeInfo", emptyMap()) as Map<*, *>
  check(reviewed["supportsDurableHostedDevBridge"] == args.contains("--hosted-dev-bridge"))
  check(RgbLibExistingOpenPolicy.parseFlag(null, false) == false)
  check(RgbLibExistingOpenPolicy.parseFlag(false, true) == false)
  check(RgbLibExistingOpenPolicy.parseFlag(true, true) == true)
  for (value in listOf(null, "true", 0, 1, 1L, 1.0))
    check(RgbLibExistingOpenPolicy.parseFlag(value, true) == null)
  check(RgbLibExistingOpenPolicy.permitsProfile(false, false))
  check(RgbLibExistingOpenPolicy.permitsProfile(true, true))
  check(!RgbLibExistingOpenPolicy.permitsProfile(true, false))
  check(rgbLibErrorCode(RgbLibException.Recovery("RECOVERY_BACKUP_INVALID")) == "RECOVERY_BACKUP_INVALID")
  check(rgbLibErrorCode(RgbLibException.Recovery("BRIDGE_INVOICE_EXPIRED")) == "BRIDGE_INVOICE_EXPIRED")
  check(rgbLibErrorCode(RgbLibException.Recovery("private_unexpected_payload")) == "NATIVE_ERROR")
  println("Kotlin runtime capability forwards exact archive boolean/type; typed backup error allowlist passed")
}
