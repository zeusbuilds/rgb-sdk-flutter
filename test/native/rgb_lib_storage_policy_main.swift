import Foundation

@main struct StoragePolicyChecks {
  static func main() throws {
    let fm = FileManager.default
    let base = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let home = base.appendingPathComponent("home")
    let outside = base.appendingPathComponent("external")
    try fm.createDirectory(at: home, withIntermediateDirectories: true)
    try fm.createDirectory(at: outside, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: base) }
    let inside = home.appendingPathComponent("Library/wallet")
    try RgbLibStorageDirectoryPolicy.requireContainedPath(inside.path, containerRoot: home.path)
    let escape = home.appendingPathComponent("escape")
    try fm.createSymbolicLink(at: escape, withDestinationURL: outside)
    let rejected = [home.path, outside.path, home.path + "-sibling/wallet",
      escape.appendingPathComponent("wallet").path, home.path + "/../external/wallet",
      "relative/wallet", home.path + "/nul\0tail"]
    for (index, path) in rejected.enumerated() {
      do {
        try RgbLibStorageDirectoryPolicy.requireContainedPath(path, containerRoot: home.path)
        preconditionFailure("Outside or malformed storage was admitted: case \(index)")
      } catch {}
    }
    precondition(!fm.fileExists(atPath: inside.path))
    precondition(!fm.fileExists(atPath: outside.appendingPathComponent("wallet").path))
    print("Swift private-container admission and symlink-escape rejection passed")
  }
}
