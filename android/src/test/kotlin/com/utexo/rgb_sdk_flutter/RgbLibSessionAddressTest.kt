package com.utexo.rgb_sdk_flutter
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
internal class RgbLibSessionAddressTest {
 @Test fun sessionCannotBeSeededFromAnUnauthenticatedPersistedAddress() {
  for(mode in listOf("signing","watch-only")) {
   val foreign="foreign-profile-address";var calls=0
   val derive={ calls++;"native-$mode-$calls" }
   val original=RgbLibSessionAddress()
   val first=original.get(true,false,derive)
   assertNotEquals(foreign,first);assertEquals(1,calls)
   assertEquals(first,original.get(true,false,derive));assertEquals(1,calls)
   val reopened=RgbLibSessionAddress()
   assertNotEquals(foreign,reopened.get(true,false,derive));assertEquals(2,calls)
  }
 }
}
