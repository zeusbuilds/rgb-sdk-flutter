import Foundation

struct RlnStorageClaimError: Error {}

enum RlnStorageClaim {
  static let marker = ".rln-sdk-profile"

  static func claim(_ path: String) throws {
    let root = URL(fileURLWithPath: path, isDirectory: true)
    let files = FileManager.default
    let lock = root.appendingPathComponent(".rgb-sdk.lock").path
    let profile = root.appendingPathComponent("rgb-sdk-profile.json").path
    if files.fileExists(atPath: lock) || files.fileExists(atPath: profile) {
      throw RlnStorageClaimError()
    }
    let marker = root.appendingPathComponent(marker)
    if !files.fileExists(atPath: marker.path) {
      try Data("rln".utf8).write(to: marker, options: .atomic)
    }
    // RGB Lib checks the marker after taking its own storage lock.
    if files.fileExists(atPath: lock) {
      throw RlnStorageClaimError()
    }
  }
}
