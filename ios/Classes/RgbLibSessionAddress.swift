/// Only a native-derived address from this open session may enter the cache.
final class RgbLibSessionAddress {
  private var cached: String?
  func get(reuse: Bool, rotate: Bool, derive: () throws -> String) rethrows -> String {
    if rotate || !reuse || cached == nil { cached = try derive() }
    return cached!
  }
}
