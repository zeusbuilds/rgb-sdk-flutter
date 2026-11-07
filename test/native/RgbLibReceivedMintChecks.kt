package com.utexo.rgb_sdk_flutter
import com.utexo.ReceivedMint
fun main() {
  val value = ReceivedMint("operation", "transaction-bound-lock", ULong.MAX_VALUE,
    ULong.MAX_VALUE - 1u, 42161u, "0x1111111111111111111111111111111111111111")
  val dto = rgbDto(value)
  check(dto.keys == setOf("opid", "lockId", "amount", "beforeBlock", "evmChainId", "bridgeContract"))
  check(dto["amount"] == "18446744073709551615")
  check(dto["beforeBlock"] == "18446744073709551614")
  check(dto["evmChainId"] == "42161")
  check(dto["opid"] == value.opid && dto["lockId"] == value.lockId)
  check(dto["bridgeContract"] == value.bridgeContract)
  println("Kotlin actual BFA.7 ReceivedMint DTO exact six-field UInt64 check passed")
}
