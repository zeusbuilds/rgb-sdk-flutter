import Foundation
import Darwin

enum RgbLibProfileReadError: Error { case invalid }

/// Bounded metadata admission shared by normal open and encrypted restore.
enum RgbLibProfileReader {
  static let maxBytes = 65536

  static func read(_ file: URL) throws -> [String: Any] {
    guard file.isFileURL else { throw RgbLibProfileReadError.invalid }
    // Nonblocking open lets fstat reject a FIFO or device without waiting for
    // an external writer. It does not change regular-file reads.
    let descriptor = Darwin.open(file.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
    guard descriptor >= 0 else { throw RgbLibProfileReadError.invalid }
    defer { Darwin.close(descriptor) }
    var metadata = stat()
    guard Darwin.fstat(descriptor, &metadata) == 0,
      metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
      metadata.st_size >= 0, metadata.st_size <= off_t(maxBytes) else {
      throw RgbLibProfileReadError.invalid
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
      if count < 0 {
        if errno == EINTR { continue }
        throw RgbLibProfileReadError.invalid
      }
      if count == 0 { break }
      guard count <= maxBytes - data.count else { throw RgbLibProfileReadError.invalid }
      data.append(contentsOf: buffer.prefix(count))
    }
    // SDK profiles are UTF-8 flat metadata. Foundation also autodetects UTF-16
    // and UTF-32, so validate the encoding before scanning the same bytes that
    // it will parse. Raw NUL is never valid JSON and would permit autodetection.
    guard !data.contains(0), String(data: data, encoding: .utf8) != nil else {
      throw RgbLibProfileReadError.invalid
    }
    var grammar = FlatProfileGrammar(bytes: Array(data))
    try grammar.validate()
    do {
      guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw RgbLibProfileReadError.invalid
      }
      return value
    } catch { throw RgbLibProfileReadError.invalid }
  }

  /// Nonrecursive admission before the system parser. Every format-2 profile
  /// value is scalar; nested containers and lenient JSON extensions are invalid.
  private struct FlatProfileGrammar {
    let bytes: [UInt8]
    var position = 0
    var current: UInt8? { position < bytes.count ? bytes[position] : nil }

    mutating func validate() throws {
      whitespace()
      try consume(123) // {
      whitespace()
      if current == 125 {
        position += 1
      } else {
        while true {
          try string()
          whitespace()
          try consume(58) // :
          whitespace()
          try scalar()
          whitespace()
          if current == 125 {
            position += 1
            break
          }
          try consume(44) // ,
          whitespace()
        }
      }
      whitespace()
      guard position == bytes.count else { throw RgbLibProfileReadError.invalid }
    }

    mutating func whitespace() {
      while let value = current, value == 32 || value == 9 || value == 10 || value == 13 {
        position += 1
      }
    }

    mutating func consume(_ expected: UInt8) throws {
      guard current == expected else { throw RgbLibProfileReadError.invalid }
      position += 1
    }

    mutating func scalar() throws {
      guard let value = current else { throw RgbLibProfileReadError.invalid }
      switch value {
      case 34: try string()
      case 116: try literal([116, 114, 117, 101]) // true
      case 102: try literal([102, 97, 108, 115, 101]) // false
      case 110: try literal([110, 117, 108, 108]) // null
      case 45, 48...57: try number()
      default: throw RgbLibProfileReadError.invalid
      }
    }

    mutating func literal(_ expected: [UInt8]) throws {
      for value in expected { try consume(value) }
    }

    mutating func string() throws {
      try consume(34)
      while let value = current {
        position += 1
        if value == 34 { return }
        guard value >= 32 else { throw RgbLibProfileReadError.invalid }
        if value == 92 {
          guard let escaped = current else { throw RgbLibProfileReadError.invalid }
          position += 1
          switch escaped {
          case 34, 92, 47, 98, 102, 110, 114, 116: break
          case 117:
            let scalar = try hexQuad()
            if (0xD800...0xDBFF).contains(scalar) {
              try consume(92)
              try consume(117)
              guard (0xDC00...0xDFFF).contains(try hexQuad()) else {
                throw RgbLibProfileReadError.invalid
              }
            } else if (0xDC00...0xDFFF).contains(scalar) {
              throw RgbLibProfileReadError.invalid
            }
          default: throw RgbLibProfileReadError.invalid
          }
        }
      }
      throw RgbLibProfileReadError.invalid
    }

    mutating func hexQuad() throws -> UInt16 {
      var value: UInt16 = 0
      for _ in 0..<4 {
        guard let byte = current else { throw RgbLibProfileReadError.invalid }
        let digit: UInt16
        switch byte {
        case 48...57: digit = UInt16(byte - 48)
        case 65...70: digit = UInt16(byte - 55)
        case 97...102: digit = UInt16(byte - 87)
        default: throw RgbLibProfileReadError.invalid
        }
        value = value * 16 + digit
        position += 1
      }
      return value
    }

    mutating func number() throws {
      let start = position
      if current == 45 { position += 1 }
      if current == 48 {
        position += 1
      } else {
        guard let value = current, (49...57).contains(value) else {
          throw RgbLibProfileReadError.invalid
        }
        digits()
      }
      if current == 46 {
        position += 1
        try requiredDigits()
      }
      if current == 101 || current == 69 {
        position += 1
        if current == 43 || current == 45 { position += 1 }
        try requiredDigits()
      }
      guard position - start <= 24,
        let value = Double(String(decoding: bytes[start..<position], as: UTF8.self)),
        value.isFinite else { throw RgbLibProfileReadError.invalid }
    }

    mutating func requiredDigits() throws {
      guard let value = current, (48...57).contains(value) else {
        throw RgbLibProfileReadError.invalid
      }
      digits()
    }

    mutating func digits() {
      while let value = current, (48...57).contains(value) { position += 1 }
    }
  }
}
