import Foundation
import CoreFoundation

/// NSNumber(1) and strings must not become authority through Foundation coercion.
enum RgbLibRevocationPolicy {
  static func isAvailable(_ archiveValue: Any?) -> Bool {
    guard let value = archiveValue as? NSNumber,
          CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
    return value.boolValue
  }
}
