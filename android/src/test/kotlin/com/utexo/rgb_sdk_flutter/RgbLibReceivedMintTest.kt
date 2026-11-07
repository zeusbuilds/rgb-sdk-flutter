package com.utexo.rgb_sdk_flutter

import com.utexo.ReceivedMint
import kotlin.test.Test
import kotlin.test.assertEquals

internal class RgbLibReceivedMintTest {
  @Test fun preservesActualNativeShapeAndUnsignedPrecision() {
    val mint = ReceivedMint("operation", "transaction-bound-lock", ULong.MAX_VALUE,
      ULong.MAX_VALUE - 1u, 42161u, "0x1111111111111111111111111111111111111111")
    val dto = rgbDto(mint)
    assertEquals(setOf("opid", "lockId", "amount", "beforeBlock", "evmChainId", "bridgeContract"), dto.keys)
    assertEquals("18446744073709551615", dto["amount"])
    assertEquals("18446744073709551614", dto["beforeBlock"])
    assertEquals("42161", dto["evmChainId"])
    assertEquals(mint.opid, dto["opid"])
    assertEquals(mint.lockId, dto["lockId"])
    assertEquals(mint.bridgeContract, dto["bridgeContract"])
  }
}
