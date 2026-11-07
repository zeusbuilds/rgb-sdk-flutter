import Foundation

enum RlnAssetMedia {
  static func metadata(_ node: SdkNode, assetId: String) throws -> [String: Any?] {
    let metadata = try node.assetMetadata(assetId: assetId)
    return [
      "assetSchema": metadata.assetSchema,
      "initialSupply": String(metadata.initialSupply),
      "maxSupply": String(metadata.maxSupply),
      "knownCirculatingSupply": String(metadata.knownCirculatingSupply),
      "timestamp": String(metadata.timestamp),
      "name": metadata.name,
      "precision": Int64(metadata.precision),
      "ticker": metadata.ticker,
      "details": metadata.details,
      "linkedFromContract": metadata.linkedFromAssetId,
      "linkedToContract": metadata.linkedToAssetId,
    ]
  }

  static func upload(_ node: SdkNode, data: Data) throws -> [String: Any?] {
    let maximum = min(20, Int(try node.nodeInfo().maxMediaUploadSizeMb)) * 1_048_576
    guard !data.isEmpty, data.count <= maximum else {
      throw PigeonError(
        code: "InvalidArgumentException",
        message: "Invalid asset media size.",
        details: nil
      )
    }
    let request = SdkPostAssetMediaRequest(fileBytes: Array(data))
    return ["digest": try node.postassetmedia(request: request).digest]
  }
}
