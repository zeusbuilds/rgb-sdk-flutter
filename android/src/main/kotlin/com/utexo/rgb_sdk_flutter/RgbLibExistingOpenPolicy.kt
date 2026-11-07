package com.utexo.rgb_sdk_flutter

/** Wrapper-owned existing-only admission; native recovery still authenticates storage. */
internal object RgbLibExistingOpenPolicy {
  fun parseFlag(value: Any?, present: Boolean): Boolean? =
    if (!present) false else value as? Boolean

  fun permitsProfile(existingOnly: Boolean, profileExists: Boolean): Boolean =
    !existingOnly || profileExists
}
