import Flutter
import Foundation

final class RgbLibChannel {
  private let channel: FlutterMethodChannel
  private let lock = NSLock()
  private let shared = DispatchQueue(label: "com.utexo.rgb_sdk_flutter.rgb-lib", attributes: .concurrent)
  private var sessions: [String: DispatchQueue] = [:]
  private var accepting = true

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.utexo.rgb_sdk_flutter/rgb_lib", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "WALLET_DISPOSED", message: "Native module is closed.", details: nil))
        return
      }
      self.invoke(call, result: result)
    }
  }

  func close() {
    channel.setMethodCallHandler(nil)
    lock.lock()
    defer { lock.unlock() }
    accepting = false
    #if canImport(RGBLib)
    for (handle, queue) in sessions {
      queue.async {
        _ = RgbLibSwiftHelper.execute("closeWallet", params: ["handle": handle])
      }
    }
    #endif
    sessions.removeAll()
  }

  private func invoke(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(RGBLib)
    guard let params = (call.arguments ?? [:]) as? [String: Any] else {
      result(FlutterError(code: "INVALID_CONFIG", message: "Expected a native request map.", details: nil))
      return
    }
    let operation = call.method
    let handle = params["handle"] as? String
    lock.lock()
    defer { lock.unlock() }
    guard accepting else {
      result(FlutterError(code: "WALLET_DISPOSED", message: "Native module is closed.", details: nil))
      return
    }
    let queue = handle.flatMap { sessions[$0] } ?? shared
    queue.async {
      let response = RgbLibSwiftHelper.execute(operation, params: params as NSDictionary)
      if operation == "closeWallet", let handle {
        self.lock.lock()
        self.sessions.removeValue(forKey: handle)
        self.lock.unlock()
      }
      if let failure = response["error"] as? [String: String] {
        DispatchQueue.main.async {
          result(FlutterError(code: failure["code"] ?? "NATIVE_BRIDGE_ERROR",
                              message: failure["message"], details: nil))
        }
        return
      }
      let value = response["result"]
      if operation == "openWallet", let newHandle = value as? String, !self.adopt(newHandle) {
        _ = RgbLibSwiftHelper.execute("closeWallet", params: ["handle": newHandle])
        DispatchQueue.main.async {
          result(FlutterError(code: "WALLET_DISPOSED", message: "Native module is closed.", details: nil))
        }
        return
      }
      DispatchQueue.main.async { result(value is NSNull ? nil : value) }
    }
    #else
    result(FlutterError(code: "NATIVE_BACKEND_UNAVAILABLE", message: "RGB Lib native library is unavailable.", details: nil))
    #endif
  }

  private func adopt(_ handle: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard accepting else { return false }
    sessions[handle] = DispatchQueue(label: "com.utexo.rgb_sdk_flutter.rgb-lib.wallet")
    return true
  }
}
