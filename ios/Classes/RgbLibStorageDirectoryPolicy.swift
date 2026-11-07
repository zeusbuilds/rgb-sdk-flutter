import Darwin
import Foundation

/// RGB_L1's iOS SQLite build supports private app-container storage only.
/// Check ancestry before creating any directory; resolving the final path alone
/// would admit a parent symlink pointing at a file-provider or external volume.
enum RgbLibStorageDirectoryPolicy {
  enum AdmissionError: Error {
    case malformedPath
    case outsidePrivateContainer
  }

  static func requireContainedPath(_ path: String, containerRoot: String) throws {
    for value in [path, containerRoot] {
      guard !value.isEmpty, value.utf8.count < 4096,
        !value.utf8.contains(0), (value as NSString).isAbsolutePath,
        !(value as NSString).pathComponents.contains(where: { $0 == "." || $0 == ".." })
      else { throw AdmissionError.malformedPath }
    }
    let rawRoot = URL(fileURLWithPath: containerRoot, isDirectory: true)
      .standardizedFileURL.path
    let root = URL(fileURLWithPath: rawRoot, isDirectory: true)
      .resolvingSymlinksInPath().standardizedFileURL.path
    let candidate = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    guard root != "/", FileManager.default.fileExists(atPath: root) else {
      throw AdmissionError.outsidePrivateContainer
    }
    let relative: String
    if candidate.hasPrefix(rawRoot + "/") {
      relative = String(candidate.dropFirst(rawRoot.count + 1))
    } else if candidate.hasPrefix(root + "/") {
      relative = String(candidate.dropFirst(root.count + 1))
    } else { throw AdmissionError.outsidePrivateContainer }

    // Foundation does not reliably resolve a parent symlink when the final
    // child does not exist. Walk existing components without following links.
    var current = URL(fileURLWithPath: root, isDirectory: true)
    for component in relative.split(separator: "/") {
      current.appendPathComponent(String(component), isDirectory: true)
      var metadata = stat()
      if lstat(current.path, &metadata) != 0 {
        guard errno == ENOENT else { throw AdmissionError.malformedPath }
        break
      }
      guard (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
        throw AdmissionError.outsidePrivateContainer
      }
    }
  }

  static func prepare(_ path: String) throws {
    #if os(iOS)
      try requireContainedPath(path, containerRoot: NSHomeDirectory())
    #endif
    try RlnStorageDirectoryPolicy.prepare(path)
  }
}
