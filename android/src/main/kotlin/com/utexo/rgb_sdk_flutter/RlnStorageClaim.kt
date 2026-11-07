package com.utexo.rgb_sdk_flutter

import java.io.File

internal class RlnStorageClaimException : Exception()

internal object RlnStorageClaim {
    const val MARKER = ".rln-sdk-profile"
    private const val RGB_PROFILE = "rgb-sdk-profile.json"
    private const val RGB_LOCK = ".rgb-sdk.lock"

    fun claim(path: String) {
        val root = File(path)
        val lock = File(root, RGB_LOCK)
        if (lock.exists() || File(root, RGB_PROFILE).exists()) {
            throw RlnStorageClaimException()
        }
        File(root, MARKER).createNewFile()
        // If RGB Lib raced the claim, both sides reject instead of sharing storage.
        if (lock.exists()) {
            throw RlnStorageClaimException()
        }
    }
}
