package com.utexo.rgb_sdk_flutter

import android.os.Handler
import android.os.Looper
import android.os.Process
import com.utexo.RgbLibException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import org.json.JSONException

internal class RgbLibChannel(binding: FlutterPlugin.FlutterPluginBinding) {
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(binding.binaryMessenger, NAME)
    private val assets = binding.applicationContext.assets
    private val store = RgbLibSessionStore {
        runCatching {
            assets.open("rgb-lib-bfa-version.json").bufferedReader().use { it.readText() }
        }.getOrNull()
    }
    private val dispatcher = RgbLibDispatcher(store::execute, ::rejectError)

    init {
        channel.setMethodCallHandler { call, result ->
            if (!Process.is64Bit()) {
                result.error("NATIVE_BACKEND_UNAVAILABLE", "RGB Lib requires a supported 64-bit process.", null)
                return@setMethodCallHandler
            }
            val arguments = call.arguments ?: emptyMap<String, Any?>()
            if (arguments !is Map<*, *> || arguments.keys.any { it !is String }) {
                result.error("INVALID_CONFIG", "Expected a native request map.", null)
            } else {
                @Suppress("UNCHECKED_CAST")
                dispatcher.invoke(call.method, arguments as Map<String, Any?>,
                    object : RgbLibDispatcher.Reply {
                        override fun resolve(value: Any?) {
                            main.post { result.success(value) }
                        }

                        override fun reject(code: String, message: String?) {
                            main.post { result.error(code, message, null) }
                        }
                    })
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        dispatcher.invalidate()
    }

    private fun rejectError(error: Throwable): Pair<String, String> = when (error) {
        is RgbLibBridgeError -> error.code to error.message.orEmpty()
        is RgbLibException -> rgbLibErrorCode(error) to "RGB Lib native operation failed."
        is JSONException, is NumberFormatException ->
            "INVALID_CONFIG" to "Invalid native request fields."
        is LinkageError -> "NATIVE_BACKEND_UNAVAILABLE" to "RGB Lib native library could not load."
        else -> "NATIVE_BRIDGE_ERROR" to "RGB Lib native bridge operation failed."
    }

    companion object {
        private const val NAME = "com.utexo.rgb_sdk_flutter/rgb_lib"
    }
}
