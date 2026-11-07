import Foundation
import CoreFoundation

/// Wrapper-owned existing-only admission; native recovery authenticates storage.
enum RgbLibExistingOpenPolicy {
  static func parseFlag(_ value: Any?, present: Bool) -> Bool? {
    guard present else { return false }
    guard let number = value as? NSNumber,
      CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
    return number.boolValue
  }

  static func permitsProfile(existingOnly: Bool, profileExists: Bool) -> Bool {
    !existingOnly || profileExists
  }
}
