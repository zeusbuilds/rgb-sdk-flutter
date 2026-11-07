package com.utexo.rgb_sdk_flutter
fun main() {
  for (mode in listOf("signing", "watch-only")) {
    val foreignProfileAddress = "foreign-profile-address"
    var calls = 0
    val native = { calls++; "native-$mode-$calls" }
    val firstSession = RgbLibSessionAddress()
    val first = firstSession.get(true,false,native)
    check(first != foreignProfileAddress && calls == 1)
    check(firstSession.get(true,false,native)==first && calls==1)
    check(firstSession.get(true,true,native)!=first && calls==2)
    val reopened = RgbLibSessionAddress()
    check(reopened.get(true,false,native) != foreignProfileAddress && calls==3)
    reopened.get(false,false,native); check(calls==4)
  }
  println("Kotlin session-owned address cache derives initially/reopens for signing and watch-only")
}
