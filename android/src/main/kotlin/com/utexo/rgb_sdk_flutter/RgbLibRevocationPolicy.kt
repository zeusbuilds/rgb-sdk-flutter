package com.utexo.rgb_sdk_flutter

/** Only an actual boolean from the pinned native archive can grant revocation. */
internal object RgbLibRevocationPolicy {
  fun isAvailable(archiveValue: Any?): Boolean = archiveValue is Boolean && archiveValue
}
