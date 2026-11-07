package com.utexo.rgb_sdk_flutter

/** Only a native-derived address from this open session may enter the cache. */
internal class RgbLibSessionAddress {
  private var cached: String? = null
  fun get(reuse: Boolean, rotate: Boolean, derive: () -> String): String {
    if (rotate || !reuse || cached == null) cached = derive()
    return cached!!
  }
}
