import Foundation
import Darwin

@main struct ProfileReaderChecks {
  static func main() throws {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("rgb-profile-reader-" + UUID().uuidString)
    try fm.createDirectory(at: dir, withIntermediateDirectories: false)
    defer { try? fm.removeItem(at: dir) }
    let file = dir.appendingPathComponent("profile.json")
    func reject(_ target: URL) throws {
      do {
        _ = try RgbLibProfileReader.read(target)
        preconditionFailure("Invalid profile was accepted")
      } catch RgbLibProfileReadError.invalid {}
    }
    var rejectedInputs = 0
    func rejectData(_ data: Data) throws {
      try data.write(to: file)
      try reject(file)
      let retained = try Data(contentsOf: file)
      precondition(retained == data, "Rejected profile was changed")
      rejectedInputs += 1
    }
    let exact = "{}" + String(repeating: " ", count: RgbLibProfileReader.maxBytes - 2)
    try Data(exact.utf8).write(to: file)
    let atLimit = try RgbLibProfileReader.read(file)
    precondition(atLimit.isEmpty)
    try rejectData(Data((exact + " ").utf8))
    for content in ["{broken", "[]", "null", "\"string\"",
      "{\"v\":" + String(repeating: "[", count: 32000) + "0" + String(repeating: "]", count: 32000) + "}",
      #"{"v":{"nested":1}}"#,
      #"{/*"*/"x":[[[[[[[[[[[[[[[[[0]]]]]]]]]]]]]]]]]/*"*/}"#,
      #"{"x":a", "extra":[[[0]]], "tail":b"}"#,
      #"{'v':'single quoted'}"#,
      #"{v:1}"#,
      #"{"v":NaN}"#,
      #"{"v":01}"#,
      #"{"v":1,}"#,
      #"{"v":truefalse}"#,
      #"{"v":1.}"#,
      #"{"v":1e}"#,
      #"{"v":1e309}"#,
      #"{"v":1234567890123456789012345}"#,
      #"{"v":"\q"}"#,
      #"{"v":"\uD800"}"#,
      #"{"v":"\uDC00"}"#,
      #"{"v":"\uD800\u0000"}"#,
      "{\u{000b}}",
      "{\"v\":\"raw\nnewline\"}",
      "{\"v\":\"raw\0nul\"}",
      "{} {}"] {
      try rejectData(Data(content.utf8))
    }
    // The old byte quote counter could be desynchronized by U+0122's 0x22
    // byte in UTF-16/32. Foundation would then decode the deep value correctly.
    let deep = String(repeating: "[", count: 32) + "0" + String(repeating: "]", count: 32)
    let wideBypass = "{\"a\":\"\u{0122}\",\"b\":" + deep + ",\"c\":\"\u{0122}\"}"
    for encoding in [String.Encoding.utf16LittleEndian, .utf16BigEndian,
                     .utf32LittleEndian, .utf32BigEndian] {
      try rejectData(wideBypass.data(using: encoding)!)
    }
    try rejectData(Data([123, 34, 118, 34, 58, 34, 0xC0, 0xAF, 34, 125]))
    try rejectData(Data([123, 34, 118, 34, 58, 34, 0xED, 0xA0, 0x80, 34, 125]))
    let text = String(repeating: "[\"\\", count: 100)
    try JSONSerialization.data(withJSONObject: ["text": text]).write(to: file)
    let quoted = try RgbLibProfileReader.read(file)
    precondition(quoted["text"] as? String == text)
    let validProfile: [String: Any] = [
      "formatVersion": 2, "backend": "rgb-lib", "id": String(repeating: "a", count: 64),
      "network": "regtest", "nativeSourceRevision": String(repeating: "b", count: 40),
      "nativeOverlay": "flutter-bfa7-durable-v1", "witnessVersion": "taproot",
      "maxAllocations": UInt32.max, "masterFingerprint": "0123abcd",
      "accountXpubVanilla": "public-vanilla", "accountXpubColored": "public-colored",
      "recoveryCohort": String(repeating: "c", count: 32)
    ]
    try JSONSerialization.data(withJSONObject: validProfile).write(to: file)
    let decodedProfile = try RgbLibProfileReader.read(file)
    precondition(NSDictionary(dictionary: decodedProfile).isEqual(to: validProfile))
    try Data(#"{"s":"\"\\\/\b\f\n\r\t\u0000\uD83D\uDE03","t":true,"f":false,"n":null,"number":-12.5e+2}"#.utf8).write(to: file)
    let scalars = try RgbLibProfileReader.read(file)
    precondition(scalars["t"] as? Bool == true && scalars["f"] as? Bool == false)
    precondition(scalars["n"] is NSNull && (scalars["number"] as? NSNumber)?.doubleValue == -1250)
    try Data(#"{"number":123456789012345678901234}"#.utf8).write(to: file)
    _ = try RgbLibProfileReader.read(file)
    let link = dir.appendingPathComponent("alias.json")
    try fm.createSymbolicLink(at: link, withDestinationURL: file)
    try reject(link)
    try reject(dir)
    try reject(dir.appendingPathComponent("absent"))
    let fifo = dir.appendingPathComponent("pipe")
    precondition(Darwin.mkfifo(fifo.path, 0o600) == 0)
    try reject(fifo)
    try reject(URL(string: "https://example.invalid/profile.json")!)
    print("Swift bounded profile reader: \(rejectedInputs) malformed/encoding/size inputs rejected; valid flat profile, scalars, escapes, exact64KiB and nonblocking regular-file admission passed")
  }
}
