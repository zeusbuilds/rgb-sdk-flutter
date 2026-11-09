package com.utexo.rgb_sdk_flutter

import com.utexo.Online
import com.utexo.Wallet
import java.lang.reflect.InvocationTargetException

/** Binds only the exact new signatures when the verified artifact advertises them. */
internal object RgbLibHostedBridge {
  val operations = setOf(
    "bridgeBlindReceive", "prepareBridgeBurn", "commitBridgeBurn",
    "observeBridgeBurn", "cancelBridgeBurn", "bridgeBurnProof"
  )

  private val methods by lazy {
    operations.mapNotNull { name ->
      val parameters = when (name) {
        "bridgeBlindReceive" -> arrayOf(Online::class.java, String::class.java, Boolean::class.javaPrimitiveType!!)
        "bridgeBurnProof" -> arrayOf(String::class.java)
        else -> arrayOf(Online::class.java, String::class.java)
      }
      val method = runCatching { Wallet::class.java.getMethod(name, *parameters) }.getOrNull()
      method?.takeIf { it.returnType == String::class.java }?.let { name to it }
    }.toMap()
  }

  fun supports(manifestValue: Any?): Boolean = manifestValue == true && methods.size == operations.size

  fun invoke(name: String, wallet: Wallet, online: Online?, request: String, recoveryOnly: Boolean?): String {
    val method = methods[name] ?: unavailable()
    val args = when (name) {
      "bridgeBlindReceive" -> arrayOf(online, request, recoveryOnly ?: unavailable())
      "bridgeBurnProof" -> arrayOf(request)
      else -> arrayOf(online, request)
    }
    return try {
      method.invoke(wallet, *args) as? String ?: unavailable()
    } catch (error: InvocationTargetException) {
      throw error.targetException
    }
  }

  fun unavailable(): Nothing = throw RgbLibBridgeError("UNSUPPORTED_CAPABILITY", "Durable hosted Dev bridge is unavailable")
}
