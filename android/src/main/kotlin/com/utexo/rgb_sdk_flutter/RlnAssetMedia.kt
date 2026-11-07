package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.SdkNode
import org.utexo.rgblightningnode.SdkPostAssetMediaRequest

internal object RlnAssetMedia {
    fun metadata(node: SdkNode, assetId: String): Map<Any?, Any?> {
        val metadata = node.assetMetadata(assetId)
        return mapOf(
            "assetSchema" to metadata.assetSchema,
            "initialSupply" to metadata.initialSupply.toString(),
            "maxSupply" to metadata.maxSupply.toString(),
            "knownCirculatingSupply" to metadata.knownCirculatingSupply.toString(),
            "timestamp" to metadata.timestamp.toString(),
            "name" to metadata.name,
            "precision" to metadata.precision.toLong(),
            "ticker" to metadata.ticker,
            "details" to metadata.details,
            "linkedFromContract" to metadata.linkedFromAssetId,
            "linkedToContract" to metadata.linkedToAssetId
        )
    }

    fun upload(node: SdkNode, bytes: ByteArray): Map<Any?, Any?> {
        val maximum = minOf(20, node.nodeInfo().maxMediaUploadSizeMb.toInt()) * 1_048_576
        if (bytes.isEmpty() || bytes.size > maximum) {
            throw FlutterError("InvalidArgumentException", "Invalid asset media size.")
        }
        val request = SdkPostAssetMediaRequest(bytes.map { it.toUByte() })
        return mapOf("digest" to node.postassetmedia(request).digest)
    }
}
