package com.utexo.rgb_sdk_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.Log
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicBoolean
import org.utexo.rgblightningnode.AsyncOrderNewHashWire
import org.utexo.rgblightningnode.CancelHodlInvoiceRequest
import org.utexo.rgblightningnode.ClaimHodlInvoiceRequest
import org.utexo.rgblightningnode.LnInvoiceRequest
import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkExternalSignerBootstrap
import org.utexo.rgblightningnode.SdkExternalUnlockRequest
import org.utexo.rgblightningnode.SdkInitRequest
import org.utexo.rgblightningnode.SdkLdkChainSync
import org.utexo.rgblightningnode.SdkNode
import org.utexo.rgblightningnode.SdkUnlockRequest
import org.utexo.rgblightningnode.SdkVssClearFenceRequest
import org.json.JSONArray
import org.json.JSONObject

/** RgbSdkFlutterPlugin */
class RgbSdkFlutterPlugin :
    FlutterPlugin,
    RlnHostApi {
    private val storageDirectoryPolicy = RlnStorageDirectoryPolicy()
    internal val nodeStore = RlnNodeStore()
    private val operationLock = Any()
    private val closeLock = Any()
    private val closing = AtomicBoolean(false)
    private var closeFuture: CompletableFuture<Void>? = null

    internal fun closeEngine(): CompletableFuture<Void> = synchronized(closeLock) {
        closeFuture ?: run {
            closing.set(true)
            CompletableFuture.runAsync {
                synchronized(operationLock) { nodeStore.clearAll() }
            }.also { closeFuture = it }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        RlnHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun getNativeArtifactInfo(): RlnNativeArtifactInfo {
        return RlnNativeArtifactInfo(
            platform = "android",
            rlnVersion = ReleaseBaseline.RLN_VERSION,
            reactNativeParityVersion = ReleaseBaseline.REACT_NATIVE_VERSION,
            bridge = "pigeon-bootstrap",
            nativeArtifact = ReleaseBaseline.ANDROID_MAVEN_COORDINATE
        )
    }

    private fun <T> runRln(operation: String, block: () -> T): T {
        synchronized(operationLock) {
            if (closing.get()) {
                throw FlutterError("Conflict", "Flutter engine is detached.", null)
            }
            try {
                @Suppress("UNCHECKED_CAST")
                return pigeonSafeValue(block()) as T
            } catch (e: FlutterError) {
                throw e
            } catch (e: Exception) {
                throw bridgeError(e, operation)
            }
        }
    }

    private fun <T> runRlnWire(operation: String, block: () -> T): RlnWireResponse {
        return wireResponse(runRln(operation, block))
    }

    private fun <T> runRlnWireList(operation: String, block: () -> List<T>): List<RlnWireResponse> {
        return runRln(operation, block).map(::wireResponse)
    }

    private fun wireResponse(value: Any?): RlnWireResponse {
        return RlnWireResponse(json = toJsonValue(value).toString())
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> JSONObject(
                value.entries.associate { (key, entryValue) ->
                    key.toString() to toJsonValue(entryValue)
                }
            )
            is Iterable<*> -> JSONArray(value.map(::toJsonValue))
            is Array<*> -> JSONArray(value.map(::toJsonValue))
            is Boolean, is Number, is String -> value
            else -> value.toString()
        }
    }

    private fun invalidArgument(operation: String, field: String, message: String): Nothing {
        throw FlutterError(
            code = "invalidArgument",
            message = message,
            details = bridgeErrorDetails(
                operation = operation,
                category = "invalidRequest",
                retryable = false,
                extra = mapOf("field" to field)
            )
        )
    }

    private fun requireExternalSignerNetwork(network: String, operation: String) {
        // Unknown aliases also fail closed. This boundary covers raw clients.
        val allowed = setOf("regtest", "testnet", "testnet4", "signet", "utexo", "signetcustom")
        if (network.trim().lowercase(java.util.Locale.ROOT) !in allowed) {
            throw FlutterError("UnsupportedOperationException",
                "Mainnet supports only the built-in password signer.",
                bridgeErrorDetails(operation, "unsupported", false,
                    mapOf("feature" to "mainnet.externalSigner")))
        }
    }

    private fun requireExternalSignerNode(nodeId: Long, operation: String) {
        requireExternalSignerNetwork(nodeStore.getNetwork(nodeId), operation)
    }

    private fun prepareStorageDirectory(path: String, operation: String) {
        try {
            storageDirectoryPolicy.prepare(path)
        } catch (error: RlnStorageDirectoryPolicyException) {
            invalidArgument(
                operation = operation,
                field = "storageDirPath",
                message = error.message ?: "storageDirPath does not satisfy the storage policy."
            )
        }
    }

    private fun requireULong(value: Long, field: String, operation: String): ULong {
        if (value < 0) {
            invalidArgument(operation, field, "$field must be non-negative.")
        }
        return value.toULong()
    }

    private fun requireUInt(value: Long, field: String, operation: String): UInt {
        if (value < 0 || value > UInt.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt32.")
        }
        return value.toUInt()
    }

    private fun requireUShort(value: Long, field: String, operation: String): UShort {
        if (value < 0 || value > UShort.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt16.")
        }
        return value.toUShort()
    }

    private fun requireUByte(value: Long, field: String, operation: String): UByte {
        if (value < 0 || value > UByte.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt8.")
        }
        return value.toUByte()
    }

    private fun requireInt(value: Long, field: String, operation: String): Int {
        if (value < Int.MIN_VALUE || value > Int.MAX_VALUE) {
            invalidArgument(operation, field, "$field must fit in Int32.")
        }
        return value.toInt()
    }

    private fun requireFeeRate(value: Double, field: String, operation: String): ULong {
        if (!value.isFinite() || value < 0 || value >= 9223372036854775808.0 || value % 1.0 != 0.0) {
            invalidArgument(operation, field, "$field must be a finite non-negative integer fee rate.")
        }
        return value.toLong().toULong()
    }

    private fun requireLdkChainSync(
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?,
        operation: String
    ): SdkLdkChainSync {
        return try {
            RlnChainSyncFactory.create(
                bitcoindRpcUsername = bitcoindRpcUsername,
                bitcoindRpcPassword = bitcoindRpcPassword,
                bitcoindRpcHost = bitcoindRpcHost,
                bitcoindRpcPort = bitcoindRpcPort,
                indexerUrl = indexerUrl
            )
        } catch (error: RlnChainSyncConfigurationException) {
            invalidArgument(operation, error.field, error.message)
        }
    }

    private fun requireULongList(values: List<Long>, field: String, operation: String): List<ULong> {
        return values.mapIndexed { index, value ->
            requireULong(value, "$field[$index]", operation)
        }
    }

    private fun pigeonSafeValue(value: Any?): Any? {
        return when (value) {
            null -> null
            is UByte -> value.toInt()
            is UShort -> value.toInt()
            is UInt -> value.toLong()
            is ULong -> if (value <= Long.MAX_VALUE.toULong()) value.toLong() else value.toString()
            is Enum<*> -> value.name
            is Map<*, *> -> value.entries.associate { entry ->
                pigeonSafeMapKey(entry.key) to pigeonSafeValue(entry.value)
            }
            is Iterable<*> -> value.map(::pigeonSafeValue)
            is Array<*> -> value.map(::pigeonSafeValue)
            else -> value
        }
    }

    private fun pigeonSafeMapKey(key: Any?): Any? {
        return when (key) {
            null -> null
            is String, is Int, is Long, is Boolean, is Double, is Float -> key
            is UByte -> key.toInt()
            is UShort -> key.toInt()
            is UInt -> key.toLong()
            is ULong -> if (key <= Long.MAX_VALUE.toULong()) key.toLong() else key.toString()
            is Enum<*> -> key.name
            else -> key.toString()
        }
    }

    private fun bridgeError(exception: Exception, operation: String): FlutterError {
        // Unlock rollback also receives already-classified bridge validation errors.
        if (exception is FlutterError) return exception
        val code = errorClassName(exception)
        val category = nativeErrorCategory(code)
        return FlutterError(
            code = code,
            message = "Native wallet operation failed ($code).",
            details = bridgeErrorDetails(
                operation = operation,
                category = category,
                retryable = nativeErrorRetryable(category)
            )
        )
    }

    private fun bridgeErrorDetails(
        operation: String,
        category: String,
        retryable: Boolean,
        extra: Map<String, Any?> = emptyMap()
    ): Map<String, Any?> {
        return mapOf(
            "operation" to operation,
            "category" to category,
            "retryable" to retryable
        ) + extra
    }

    private fun errorClassName(exception: Exception): String {
        if (exception is RlnStateConflict) return "Conflict"
        val className = exception.javaClass.name
        return className.split('$').last().split('.').last()
    }

    private fun nativeErrorCategory(code: String): String {
        return when (code) {
            "NodeNotFound", "SignerNotFound", "NotFound" -> "notFound"
            "Conflict", "AlreadyExists", "ResourceBusy" -> "conflict"
            "Network", "Transport", "Timeout", "FailedBitcoindConnection",
            "FailedBdkSync", "FailedBroadcast", "FailedPeerConnection", "NoRoute" -> "network"
            "Configuration", "RlnStorageDirectoryPolicyException", "NotInitialized",
            "ExternalSignerRequired", "ExternalSignerMismatch", "ExternalSignerUnavailable" -> "configuration"
            "InvalidArgument", "InvalidRequest", "BadRequest" -> "invalidRequest"
            "Unsupported", "UnsupportedOperation", "UnsupportedInExternalSignerMode",
            "LightningUnsupportedOnMainnet" -> "unsupported"
            else -> "native"
        }
    }

    private fun nativeErrorRetryable(category: String): Boolean {
        return category == "network" || category == "conflict"
    }


    private fun isNodeReady(node: SdkNode): Boolean {
        return try {
            node.nodeInfo().pubkey.isNotBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun btcBalanceMap(balance: org.utexo.rgblightningnode.BtcBalance): Map<Any?, Any?> {
        return mapOf(
            "settled" to balance.settled,
            "future" to balance.future,
            "spendable" to balance.spendable
        )
    }

    private fun channelMap(channel: org.utexo.rgblightningnode.Channel): Map<Any?, Any?> {
        return mapOf(
            "channelId" to channel.channelId,
            "peerPubkey" to channel.peerPubkey,
            "status" to channel.status.name,
            "ready" to channel.ready,
            "capacitySat" to channel.capacitySat,
            "localBalanceSat" to channel.localBalanceSat,
            "outboundBalanceMsat" to channel.outboundBalanceMsat,
            "inboundBalanceMsat" to channel.inboundBalanceMsat,
            "nextOutboundHtlcLimitMsat" to channel.nextOutboundHtlcLimitMsat,
            "nextOutboundHtlcMinimumMsat" to channel.nextOutboundHtlcMinimumMsat,
            "isUsable" to channel.isUsable,
            "public" to channel.public,
            "fundingTxid" to channel.fundingTxid,
            "peerAlias" to channel.peerAlias,
            "shortChannelId" to channel.shortChannelId?.toString(),
            "assetId" to channel.assetId,
            "assetLocalAmount" to channel.assetLocalAmount?.toString(),
            "assetRemoteAmount" to channel.assetRemoteAmount?.toString(),
            "virtualOpenMode" to channel.virtualOpenMode
        )
    }

    private fun paymentMap(payment: org.utexo.rgblightningnode.Payment): Map<Any?, Any?> {
        return mapOf(
            "amtMsat" to payment.amtMsat?.toString(),
            "assetAmount" to payment.assetAmount?.toString(),
            "assetId" to payment.assetId,
            "paymentHash" to payment.paymentHash,
            "paymentType" to payment.paymentType.name,
            "status" to payment.status.name,
            "createdAt" to payment.createdAt,
            "updatedAt" to payment.updatedAt,
            "payeePubkey" to payment.payeePubkey,
            "preimage" to payment.preimage
        )
    }

    private fun apayHashMap(hash: AsyncOrderNewHashWire): Map<Any?, Any?> {
        return mapOf(
            "hashIndex" to hash.hashIndex,
            "paymentHash" to hash.paymentHash
        )
    }

    private fun rgbAllocationMap(allocation: org.utexo.rgblightningnode.RgbAllocation): Map<Any?, Any?> {
        return mapOf(
            "assetId" to allocation.assetId,
            "assignment" to allocation.assignment,
            "settled" to allocation.settled
        )
    }

    private fun blockTimeMap(blockTime: org.utexo.rgblightningnode.BlockTime?): Map<Any?, Any?>? {
        if (blockTime == null) return null
        return mapOf(
            "height" to blockTime.height,
            "timestamp" to blockTime.timestamp
        )
    }

    private fun transactionMap(transaction: org.utexo.rgblightningnode.Transaction): Map<Any?, Any?> {
        return mapOf(
            "transactionType" to transaction.transactionType.name,
            "txid" to transaction.txid,
            "received" to transaction.received,
            "sent" to transaction.sent,
            "fee" to transaction.fee,
            "confirmationTime" to blockTimeMap(transaction.confirmationTime)
        )
    }

    internal fun unspentMap(unspent: org.utexo.rgblightningnode.Unspent): Map<Any?, Any?> {
        return mapOf(
            "utxo" to mapOf(
                "outpoint" to unspent.utxo.outpoint,
                "btcAmount" to unspent.utxo.btcAmount,
                "colorable" to unspent.utxo.colorable,
                "exists" to unspent.utxo.exists
            ),
            "rgbAllocations" to unspent.rgbAllocations.map(::rgbAllocationMap),
            "pendingBlinded" to unspent.pendingBlinded.toLong()
        )
    }

    private fun decodeRgbInvoiceMap(invoice: org.utexo.rgblightningnode.DecodeRgbInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "recipientId" to invoice.recipientId,
            "proxyRecipientId" to invoice.proxyRecipientId,
            "recipientType" to invoice.recipientType,
            "assetSchema" to invoice.assetSchema,
            "assetId" to invoice.assetId,
            "assignment" to invoice.assignment,
            "network" to invoice.network,
            "expirationTimestamp" to invoice.expirationTimestamp,
            "transportEndpoints" to invoice.transportEndpoints
        )
    }

    private fun transferTransportEndpointMap(endpoint: org.utexo.rgblightningnode.TransferTransportEndpoint): Map<Any?, Any?> {
        return mapOf(
            "endpoint" to endpoint.endpoint,
            "transportType" to endpoint.transportType,
            "used" to endpoint.used
        )
    }

    private fun transferMap(transfer: org.utexo.rgblightningnode.Transfer): Map<Any?, Any?> {
        return mapOf(
            "idx" to transfer.idx,
            "createdAt" to transfer.createdAt,
            "updatedAt" to transfer.updatedAt,
            "status" to transfer.status,
            "requestedAssignment" to transfer.requestedAssignment,
            "assignments" to transfer.assignments,
            "kind" to transfer.kind,
            "txid" to transfer.txid,
            "recipientId" to transfer.recipientId,
            "proxyRecipientId" to transfer.proxyRecipientId,
            "receiveUtxo" to transfer.receiveUtxo,
            "changeUtxo" to transfer.changeUtxo,
            "expiration" to transfer.expiration,
            "transportEndpoints" to transfer.transportEndpoints.map(::transferTransportEndpointMap)
        )
    }

    private fun rgbInvoiceMap(invoice: org.utexo.rgblightningnode.SdkRgbInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "recipientId" to invoice.recipientId,
            "invoice" to invoice.invoice,
            "expirationTimestamp" to invoice.expirationTimestamp,
            "batchTransferIdx" to invoice.batchTransferIdx
        )
    }

    private fun decodeLnInvoiceMap(invoice: org.utexo.rgblightningnode.DecodeLnInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "amtMsat" to invoice.amtMsat?.toString(),
            "expirySec" to invoice.expirySec.toString(),
            "timestamp" to invoice.timestamp.toString(),
            "assetId" to invoice.assetId,
            "assetAmount" to invoice.assetAmount?.toString(),
            "description" to invoice.description,
            "descriptionHash" to invoice.descriptionHash,
            "paymentHash" to invoice.paymentHash,
            "paymentSecret" to invoice.paymentSecret,
            "payeePubkey" to invoice.payeePubkey,
            "network" to invoice.network
        )
    }

    private fun keysendMap(response: org.utexo.rgblightningnode.SdkKeysendResponse): Map<Any?, Any?> {
        return mapOf(
            "paymentHash" to response.paymentHash,
            "paymentPreimage" to response.paymentPreimage,
            "status" to response.status.name
        )
    }

    private fun sendPaymentMap(response: org.utexo.rgblightningnode.SdkSendPaymentResponse): Map<Any?, Any?> {
        return mapOf(
            "paymentId" to response.paymentId,
            "paymentHash" to response.paymentHash,
            "paymentSecret" to response.paymentSecret,
            "status" to response.status.name
        )
    }

    override fun rlnCreateNode(
        storageDirPath: String,
        daemonListeningPort: Long,
        ldkPeerListeningPort: Long,
        network: String,
        maxMediaUploadSizeMb: Long,
        enableVirtualChannelsV0: Boolean?,
        virtualPeerPubkeys: List<String>?,
        vssUrl: String?,
        vssAllowHttp: Boolean,
        vssAllowEmptyRestore: Boolean,
        lspBaseUrl: String?,
        lspBearerToken: String?,
        reuseAddresses: Boolean
    ): Long {
        return runRln("rlnCreateNode") {
            val initRequest = SdkInitRequest(
                storageDirPath = storageDirPath,
                daemonListeningPort = requireUShort(daemonListeningPort, "daemonListeningPort", "rlnCreateNode"),
                ldkPeerListeningPort = requireUShort(ldkPeerListeningPort, "ldkPeerListeningPort", "rlnCreateNode"),
                network = network,
                maxMediaUploadSizeMb = requireUShort(maxMediaUploadSizeMb, "maxMediaUploadSizeMb", "rlnCreateNode"),
                enableVirtualChannelsV0 = enableVirtualChannelsV0,
                virtualPeerPubkeys = virtualPeerPubkeys?.filter { it.isNotBlank() },
                lspBaseUrl = lspBaseUrl,
                lspBearerToken = lspBearerToken,
                vssUrl = vssUrl,
                vssAllowHttp = vssAllowHttp,
                vssAllowEmptyRestore = vssAllowEmptyRestore,
                reuseAddresses = reuseAddresses
            )
            nodeStore.ensureStorageAvailable(storageDirPath)
            prepareStorageDirectory(storageDirPath, "rlnCreateNode")
            val node = SdkNode.create(initRequest)
            nodeStore.create(node, storageDirPath, network)
        }
    }

    override fun rlnInitNode(nodeId: Long, password: String, mnemonic: String?): String {
        return runRln("rlnInitNode") {
            val node = nodeStore.get(nodeId)
            val state = nodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw RlnStateConflict("RLN init is not allowed while node is in state: $state")
            }
            val pubkey = node.init(password, mnemonic)
            nodeStore.markInitialized(nodeId)
            pubkey
        }
    }

    override fun rlnCreateNativeExternalSigner(
        seedHex: String,
        network: String,
        permissivePolicy: Boolean,
        storageDirPath: String?
    ): Long {
        return runRln("rlnCreateNativeExternalSigner") {
            requireExternalSignerNetwork(network, "rlnCreateNativeExternalSigner")
            val signer = if (storageDirPath == null) {
                NativeExternalSigner(seedHex, network, permissivePolicy)
            } else {
                prepareStorageDirectory(storageDirPath, "rlnCreateNativeExternalSigner")
                NativeExternalSigner.newWithStorage(
                    seedHex,
                    network,
                    permissivePolicy,
                    storageDirPath
                )
            }
            nodeStore.createSigner(signer)
        }
    }

    override fun rlnInitNodeWithNativeExternalSigner(nodeId: Long, signerId: Long) {
        runRln("rlnInitNodeWithNativeExternalSigner") {
            requireExternalSignerNode(nodeId, "rlnInitNodeWithNativeExternalSigner")
            val node = nodeStore.get(nodeId)
            val state = nodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw RlnStateConflict("RLN init is not allowed while node is in state: $state")
            }
            val signer = nodeStore.getSigner(signerId)
            node.initWithNativeExternalSigner(signer)
            node.detachExternalSigner()
            nodeStore.markInitialized(nodeId)
        }
    }

    override fun rlnAttachNativeExternalSigner(nodeId: Long, signerId: Long) {
        runRln("rlnAttachNativeExternalSigner") {
            requireExternalSignerNode(nodeId, "rlnAttachNativeExternalSigner")
            val node = nodeStore.get(nodeId)
            val signer = nodeStore.getSigner(signerId)
            node.attachNativeExternalSigner(signer)
        }
    }

    override fun rlnUnlockNodeWithNativeExternalSigner(
        nodeId: Long,
        signerId: Long,
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?,
        proxyEndpoint: String?,
        announceAddresses: List<String>,
        announceAlias: String?,
        gossipRgsServerUrl: String?,
        ethRpcUrl: String?
    ) {
        runRln("rlnUnlockNodeWithNativeExternalSigner") {
            if (gossipRgsServerUrl != null) {
                throw FlutterError("UnsupportedOperationException",
                    "External-signer unlock does not support RGS configuration.",
                    bridgeErrorDetails("rlnUnlockNodeWithNativeExternalSigner",
                        "unsupported", false, mapOf("feature" to "externalSigner.gossipRgsServerUrl")))
            }
            requireExternalSignerNode(nodeId, "rlnUnlockNodeWithNativeExternalSigner")
            try {
                val node = nodeStore.get(nodeId)
                val signer = nodeStore.getSigner(signerId)
                when (nodeStore.beginUnlock(nodeId)) {
                    RlnNodeStore.NodeLifecycleState.UNLOCKED -> {
                        if (isNodeReady(node)) {
                            return@runRln
                        }
                        throw RlnStateConflict("RLN node is marked unlocked but nodeInfo is not available")
                    }
                    RlnNodeStore.NodeLifecycleState.UNLOCKING -> Unit
                    else -> throw RlnStateConflict("Unexpected RLN node state before unlock")
                }
                node.unlockWithNativeExternalSignerRequest(
                    signer = signer,
                    request = SdkExternalUnlockRequest(
                        ldkChainSync = requireLdkChainSync(
                            bitcoindRpcUsername = bitcoindRpcUsername,
                            bitcoindRpcPassword = bitcoindRpcPassword,
                            bitcoindRpcHost = bitcoindRpcHost,
                            bitcoindRpcPort = bitcoindRpcPort,
                            indexerUrl = indexerUrl,
                            operation = "rlnUnlockNodeWithNativeExternalSigner"
                        ),
                        indexerUrl = indexerUrl,
                        proxyEndpoint = proxyEndpoint,
                        announceAddresses = announceAddresses,
                        announceAlias = announceAlias,
                        ethRpcUrl = ethRpcUrl
                    )
                )
                nodeStore.markUnlocked(nodeId)
            } catch (e: Exception) {
                nodeStore.rollbackUnlock(nodeId)
                throw bridgeError(e, "rlnUnlockNodeWithNativeExternalSigner")
            }
        }
    }

    override fun rlnDestroyNativeExternalSigner(signerId: Long) {
        runRln("rlnDestroyNativeExternalSigner") { nodeStore.removeSigner(signerId) }
    }

    override fun rlnInitNodeWithExternalSigner(nodeId: Long, nodePublicKeyHex: String, accountXpubVanilla: String, accountXpubColored: String, masterFingerprint: String, protocolVersion: String, apiLevel: Long) {
        runRln("rlnInitNodeWithExternalSigner") {
            requireExternalSignerNode(nodeId, "rlnInitNodeWithExternalSigner")
            val node = nodeStore.get(nodeId)
            val state = nodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw RlnStateConflict("RLN init is not allowed while node is in state: $state")
            }
            node.initWithExternalSigner(
                SdkExternalSignerBootstrap(
                    nodeId = nodePublicKeyHex,
                    accountXpubVanilla = accountXpubVanilla,
                    accountXpubColored = accountXpubColored,
                    masterFingerprint = masterFingerprint,
                    protocolVersion = protocolVersion,
                    apiLevel = requireUInt(apiLevel, "apiLevel", "rlnInitNodeWithExternalSigner")
                )
            )
            nodeStore.markInitialized(nodeId)
        }
    }

    override fun rlnUnlockNode(
        nodeId: Long,
        password: String,
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?,
        proxyEndpoint: String?,
        announceAddresses: List<String>,
        announceAlias: String?,
        gossipRgsServerUrl: String?,
        ethRpcUrl: String?
    ) {
        runRln("rlnUnlockNode") {
            try {
                val node = nodeStore.get(nodeId)
                when (nodeStore.beginUnlock(nodeId)) {
                    RlnNodeStore.NodeLifecycleState.UNLOCKED -> {
                        if (isNodeReady(node)) {
                            return@runRln
                        }
                        throw RlnStateConflict("RLN node is marked unlocked but nodeInfo is not available")
                    }
                    RlnNodeStore.NodeLifecycleState.UNLOCKING -> Unit
                    else -> throw RlnStateConflict("Unexpected RLN node state before unlock")
                }
                node.unlock(
                    SdkUnlockRequest(
                        password = password,
                        ldkChainSync = requireLdkChainSync(
                            bitcoindRpcUsername = bitcoindRpcUsername,
                            bitcoindRpcPassword = bitcoindRpcPassword,
                            bitcoindRpcHost = bitcoindRpcHost,
                            bitcoindRpcPort = bitcoindRpcPort,
                            indexerUrl = indexerUrl,
                            operation = "rlnUnlockNode"
                        ),
                        indexerUrl = indexerUrl,
                        proxyEndpoint = proxyEndpoint,
                        announceAddresses = announceAddresses,
                        announceAlias = announceAlias,
                        gossipRgsServerUrl = gossipRgsServerUrl,
                        ethRpcUrl = ethRpcUrl
                    )
                )
                nodeStore.markUnlocked(nodeId)
            } catch (e: Exception) {
                nodeStore.rollbackUnlock(nodeId)
                throw bridgeError(e, "rlnUnlockNode")
            }
        }
    }

    override fun rlnDestroyNode(nodeId: Long) {
        runRln("rlnDestroyNode") { nodeStore.remove(nodeId) }
    }

    override fun rlnBfaCapabilities(): RlnWireResponse = runRlnWire("rlnBfaCapabilities") {
        mapOf("burn" to true, "consignment" to true, "bfa" to true)
    }

    private fun requireBurnAssetId(assetId: String, operation: String) {
        if (!assetId.startsWith("rgb:") || assetId.length > 256)
            throw invalidArgument(operation, "assetId", "Invalid asset ID.")
    }

    private fun requireConsignmentLookup(assetId: String, txid: String, operation: String) {
        requireBurnAssetId(assetId, operation)
        if (!Regex("^[a-fA-F0-9]{64}$").matches(txid))
            throw invalidArgument(operation, "txid", "Expected a 32-byte hex transaction ID.")
    }

    override fun rlnBurn(nodeId: Long, assetId: String, amount: String, burnRecipient: String?,
                         feeRate: Long, minConfirmations: Long): RlnWireResponse = runRlnWire("rlnBurn") {
        requireBurnAssetId(assetId, "rlnBurn")
        val units = amount.toULongOrNull()
        if (!Regex("^[1-9][0-9]{0,19}$").matches(amount) || units == null)
            throw invalidArgument("rlnBurn", "amount", "Expected a positive u64 decimal string.")
        if (feeRate < 1 || feeRate > 9007199254740991L)
            throw invalidArgument("rlnBurn", "feeRate", "Expected a positive safe integer sat/vB.")
        if (minConfirmations < 1 || minConfirmations > 255)
            throw invalidArgument("rlnBurn", "minConfirmations", "Expected 1 through 255 confirmations.")
        val recipient = burnRecipient?.let { hex ->
            if (!Regex("^[a-fA-F0-9]{64}$").matches(hex))
                throw invalidArgument("rlnBurn", "burnRecipient", "Expected 32-byte hex without 0x.")
            ByteArray(32) { index -> hex.substring(index * 2, index * 2 + 2).toInt(16).toByte() }
        }
        val result = nodeStore.get(nodeId).burn(org.utexo.rgblightningnode.BurnRequest(
            assetId = assetId, amount = units, burnRecipient = recipient,
            feeRate = feeRate.toULong(), minConfirmations = minConfirmations.toUByte()
        ))
        mapOf("txid" to result.txid, "batchTransferIdx" to result.batchTransferIdx.toLong())
    }

    override fun rlnImportRgbContract(nodeId: Long, contractBase64: String, expectedAssetId: String): RlnWireResponse =
        runRlnWire("rlnImportRgbContract") {
            requireBurnAssetId(expectedAssetId, "rlnImportRgbContract")
            if (contractBase64.isEmpty() || contractBase64.length > 16 * 1024 * 1024 || contractBase64.length % 4 != 0 ||
                !Regex("^[A-Za-z0-9+/]*={0,2}$").matches(contractBase64))
                throw invalidArgument("rlnImportRgbContract", "contractBase64", "Expected standard Base64 public contract bytes.")
            val bytes = android.util.Base64.decode(contractBase64, android.util.Base64.NO_WRAP)
            if (bytes.isEmpty() || android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP) != contractBase64)
                throw invalidArgument("rlnImportRgbContract", "contractBase64", "Expected canonical standard Base64 public contract bytes.")
            val result = nodeStore.get(nodeId).importrgbcontract(
                org.utexo.rgblightningnode.ImportRgbContractRequest(contractBase64, expectedAssetId)
            )
            val meta = result.metadata
            mapOf("assetId" to result.assetId, "alreadyImported" to result.alreadyImported,
                "metadata" to mapOf("assetSchema" to meta.assetSchema, "name" to meta.name,
                    "ticker" to meta.ticker, "details" to meta.details, "precision" to meta.precision,
                    "initialSupply" to meta.initialSupply.toString(), "maxSupply" to meta.maxSupply.toString(),
                    "knownCirculatingSupply" to meta.knownCirculatingSupply.toString()))
        }

    override fun rlnGetConsignment(nodeId: Long, assetId: String, txid: String): String =
        runRln("rlnGetConsignment") {
            requireConsignmentLookup(assetId, txid, "rlnGetConsignment")
            android.util.Base64.encodeToString(nodeStore.get(nodeId).getConsignment(assetId, txid), android.util.Base64.NO_WRAP)
        }

    override fun rlnGetConsignmentPath(nodeId: Long, assetId: String, txid: String): String =
        runRln("rlnGetConsignmentPath") {
            requireConsignmentLookup(assetId, txid, "rlnGetConsignmentPath")
            nodeStore.get(nodeId).getConsignmentPath(assetId, txid)
        }

    override fun rlnNodeInfo(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnNodeInfo") {
            val info = nodeStore.get(nodeId).nodeInfo()
            mapOf(
                "pubkey" to info.pubkey,
                "numChannels" to info.numChannels,
                "numUsableChannels" to info.numUsableChannels,
                "localBalanceSat" to info.localBalanceSat,
                "eventualCloseFeesSat" to info.eventualCloseFeesSat,
                "pendingOutboundPaymentsSat" to info.pendingOutboundPaymentsSat,
                "numPeers" to info.numPeers,
                "accountXpubVanilla" to info.accountXpubVanilla,
                "accountXpubColored" to info.accountXpubColored,
                "maxMediaUploadSizeMb" to info.maxMediaUploadSizeMb,
                "rgbHtlcMinMsat" to info.rgbHtlcMinMsat,
                "rgbChannelCapacityMinSat" to info.rgbChannelCapacityMinSat,
                "channelCapacityMinSat" to info.channelCapacityMinSat,
                "channelCapacityMaxSat" to info.channelCapacityMaxSat,
                "channelAssetMinAmount" to info.channelAssetMinAmount,
                "channelAssetMaxAmount" to info.channelAssetMaxAmount.toString(),
                "networkNodes" to info.networkNodes,
                "networkChannels" to info.networkChannels,
                "latestRgsSnapshotTimestamp" to info.latestRgsSnapshotTimestamp
            )
        }
    }

    override fun rlnNetworkInfo(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnNetworkInfo") {
            val info = nodeStore.get(nodeId).networkInfo()
            mapOf(
                "network" to info.network,
                "height" to info.height
            )
        }
    }

    override fun rlnListPeers(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListPeers") {
            nodeStore.get(nodeId).listPeers().map { mapOf("pubkey" to it.pubkey) }
        }
    }

    override fun rlnConnectPeer(nodeId: Long, peerPubkeyAndAddr: String) {
        runRln("rlnConnectPeer") {
            nodeStore.get(nodeId).connectpeer(peerPubkeyAndAddr)
        }
    }

    override fun rlnDisconnectPeer(nodeId: Long, peerPubkey: String) {
        runRln("rlnDisconnectPeer") {
            nodeStore.get(nodeId).disconnectpeer(
                org.utexo.rgblightningnode.SdkDisconnectPeerRequest(peerPubkey)
            )
        }
    }

    override fun rlnListChannels(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListChannels") {
            nodeStore.get(nodeId).listChannels().map(::channelMap)
        }
    }

    override fun rlnOpenChannel(nodeId: Long, peerPubkeyAndOptAddr: String, capacitySat: Long, pushMsat: Long, publicChannel: Boolean, withAnchors: Boolean, feeBaseMsat: Long?, feeProportionalMillionths: Long?, temporaryChannelId: String?, assetId: String?, assetAmount: Long?, pushAssetAmount: Long?, virtualOpenMode: String?): RlnWireResponse {
        return runRlnWire("rlnOpenChannel") {
            val request = org.utexo.rgblightningnode.SdkOpenChannelRequest(
                peerPubkeyAndOptAddr = peerPubkeyAndOptAddr,
                capacitySat = requireULong(capacitySat, "capacitySat", "rlnOpenChannel"),
                pushMsat = requireULong(pushMsat, "pushMsat", "rlnOpenChannel"),
                public = publicChannel,
                withAnchors = withAnchors,
                feeBaseMsat = feeBaseMsat?.let { requireUInt(it, "feeBaseMsat", "rlnOpenChannel") },
                feeProportionalMillionths = feeProportionalMillionths?.let { requireUInt(it, "feeProportionalMillionths", "rlnOpenChannel") },
                temporaryChannelId = temporaryChannelId,
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnOpenChannel") },
                pushAssetAmount = pushAssetAmount?.let { requireULong(it, "pushAssetAmount", "rlnOpenChannel") },
                virtualOpenMode = virtualOpenMode
            )
            val response = nodeStore.get(nodeId).openchannel(request)
            mapOf("temporaryChannelId" to response.temporaryChannelId)
        }
    }

    override fun rlnCloseChannel(nodeId: Long, channelId: String, peerPubkey: String, force: Boolean) {
        runRln("rlnCloseChannel") {
            nodeStore.get(nodeId).closechannel(
                org.utexo.rgblightningnode.SdkCloseChannelRequest(
                    channelId = channelId,
                    peerPubkey = peerPubkey,
                    force = force
                )
            )
        }
    }

    override fun rlnListPayments(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListPayments") {
            nodeStore.get(nodeId).listPayments().map(::paymentMap)
        }
    }

    override fun rlnAddress(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnAddress") {
            mapOf("address" to nodeStore.get(nodeId).address().address)
        }
    }

    override fun rlnRotateAddress(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnRotateAddress") {
            mapOf("address" to nodeStore.get(nodeId).rotateAddress().address)
        }
    }

    override fun rlnSignMessage(nodeId: Long, message: String): RlnWireResponse {
        return runRlnWire("rlnSignMessage") {
            mapOf("signedMessage" to nodeStore.get(nodeId).signMessage(message).signedMessage)
        }
    }

    override fun rlnVerifyMessage(nodeId: Long, message: String, signature: String): RlnWireResponse {
        return runRlnWire("rlnVerifyMessage") {
            mapOf("valid" to nodeStore.get(nodeId).verifyMessage(message, signature).valid)
        }
    }

    override fun rlnAssetBalance(nodeId: Long, assetId: String): RlnWireResponse {
        return runRlnWire("rlnAssetBalance") {
            RlnAssetMapper.assetBalanceMap(nodeStore.get(nodeId).assetBalance(assetId))
        }
    }

    override fun rlnBackup(nodeId: Long, backupPath: String, password: String) {
        throw FlutterError(
            code = "UnsupportedOperationException",
            message = "rlnBackup is not available in current Android RLN bindings",
            details = bridgeErrorDetails(
                operation = "rlnBackup",
                category = "unsupported",
                retryable = false,
                extra = mapOf("phase" to "rln-parity", "feature" to "rlnBackup")
            )
        )
    }

    override fun rlnBtcBalance(nodeId: Long, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnBtcBalance") {
            val balance = nodeStore.get(nodeId).btcBalance(skipSync)
            mapOf(
                "vanilla" to btcBalanceMap(balance.vanilla),
                "colored" to btcBalanceMap(balance.colored)
            )
        }
    }

    override fun rlnCheckIndexerUrl(nodeId: Long, indexerUrl: String): RlnWireResponse {
        return runRlnWire("rlnCheckIndexerUrl") {
            val response = nodeStore.get(nodeId).checkIndexerUrl(indexerUrl)
            mapOf("indexerProtocol" to response.indexerProtocol)
        }
    }

    override fun rlnCheckProxyEndpoint(nodeId: Long, proxyEndpoint: String) {
        runRln("rlnCheckProxyEndpoint") {
            nodeStore.get(nodeId).checkProxyEndpoint(proxyEndpoint)
        }
    }

    override fun rlnCreateUtxos(nodeId: Long, upTo: Boolean, num: Long?, size: Long?, feeRate: Double, skipSync: Boolean) {
        runRln("rlnCreateUtxos") {
            val request = org.utexo.rgblightningnode.SdkCreateUtxosRequest(
                upTo = upTo,
                num = num?.let { requireUByte(it, "num", "rlnCreateUtxos") },
                size = size?.let { requireUInt(it, "size", "rlnCreateUtxos") },
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnCreateUtxos"),
                skipSync = skipSync
            )
            nodeStore.get(nodeId).createutxos(request)
        }
    }

    override fun rlnDecodeLnInvoice(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnDecodeLnInvoice") {
            decodeLnInvoiceMap(nodeStore.get(nodeId).decodeLnInvoice(invoice))
        }
    }

    override fun rlnDecodeRgbInvoice(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnDecodeRgbInvoice") {
            decodeRgbInvoiceMap(nodeStore.get(nodeId).decodeRgbInvoice(invoice))
        }
    }

    override fun rlnEstimateFee(nodeId: Long, blocks: Long): RlnWireResponse {
        return runRlnWire("rlnEstimateFee") {
            val response = nodeStore.get(nodeId).estimateFee(
                requireUShort(blocks, "blocks", "rlnEstimateFee")
            )
            mapOf("feeRate" to response.feeRate)
        }
    }

    override fun rlnFailTransfers(nodeId: Long, batchTransferIdx: Long?, noAssetOnly: Boolean, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnFailTransfers") {
            val response = nodeStore.get(nodeId).failtransfers(
                org.utexo.rgblightningnode.SdkFailTransfersRequest(
                    batchTransferIdx = batchTransferIdx?.let { requireInt(it, "batchTransferIdx", "rlnFailTransfers") },
                    noAssetOnly = noAssetOnly,
                    skipSync = skipSync
                )
            )
            mapOf("transfersChanged" to response.transfersChanged)
        }
    }

    override fun rlnGetChannelId(nodeId: Long, temporaryChannelId: String): String {
        return runRln("rlnGetChannelId") {
            nodeStore.get(nodeId).getChannelId(temporaryChannelId)
        }
    }

    override fun rlnGetPayment(nodeId: Long, paymentHash: String): RlnWireResponse {
        return runRlnWire("rlnGetPayment") {
            val node = nodeStore.get(nodeId)
            var lastError: Exception? = null
            for (paymentType in listOf(
                org.utexo.rgblightningnode.PaymentType.OUTBOUND,
                org.utexo.rgblightningnode.PaymentType.INBOUND_AUTO_CLAIM,
                org.utexo.rgblightningnode.PaymentType.INBOUND_HODL
            )) {
                try {
                    return@runRlnWire paymentMap(node.getPayment(paymentHash, paymentType))
                } catch (e: Exception) {
                    lastError = e
                }
            }
            throw lastError ?: IllegalStateException("Payment not found")
        }
    }

    override fun rlnInvoiceStatus(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnInvoiceStatus") {
            mapOf("status" to nodeStore.get(nodeId).invoiceStatus(invoice).name)
        }
    }

    override fun rlnKeysend(nodeId: Long, destPubkey: String, amtMsat: Long, assetId: String?, assetAmount: Long?): RlnWireResponse {
        return runRlnWire("rlnKeysend") {
            val request = org.utexo.rgblightningnode.SdkKeysendRequest(
                destPubkey = destPubkey,
                amtMsat = requireULong(amtMsat, "amtMsat", "rlnKeysend"),
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnKeysend") }
            )
            val response = nodeStore.get(nodeId).keysend(request)
            keysendMap(response)
        }
    }

    override fun rlnListAssets(nodeId: Long, filterAssetSchemas: List<String>): RlnWireResponse {
        return runRlnWire("rlnListAssets") {
            RlnAssetMapper.listAssetsMap(nodeStore.get(nodeId).listAssets(filterAssetSchemas))
        }
    }

    override fun rlnListTransactions(nodeId: Long, skipSync: Boolean): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransactions") {
            nodeStore.get(nodeId).listTransactions(skipSync, null).map(::transactionMap)
        }
    }

    override fun rlnListTransactionsByTxid(
        nodeId: Long,
        txid: String,
        skipSync: Boolean
    ): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransactionsByTxid") {
            nodeStore.get(nodeId).listTransactions(skipSync, txid).map(::transactionMap)
        }
    }

    override fun rlnListTransfers(nodeId: Long, assetId: String): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransfers") {
            nodeStore.get(nodeId).listTransfers(assetId.ifEmpty { null }, null).map(::transferMap)
        }
    }

    override fun rlnListTransfersByTxid(nodeId: Long, txid: String): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransfersByTxid") {
            nodeStore.get(nodeId).listTransfers(null, txid).map(::transferMap)
        }
    }

    override fun rlnListUnspents(nodeId: Long, skipSync: Boolean): List<RlnWireResponse> {
        return runRlnWireList("rlnListUnspents") {
            nodeStore.get(nodeId).listUnspents(skipSync).map(::unspentMap)
        }
    }

    override fun rlnLnInvoice(
        nodeId: Long,
        amtMsat: Long?,
        expirySec: Long,
        assetId: String?,
        assetAmount: Long?,
        paymentHash: String?,
        minFinalCltvExpiryDelta: Long?,
        descriptionHash: String?
    ): RlnWireResponse {
        return runRlnWire("rlnLnInvoice") {
            val request = LnInvoiceRequest(
                amtMsat = amtMsat?.let { requireULong(it, "amtMsat", "rlnLnInvoice") },
                expirySec = requireUInt(expirySec, "expirySec", "rlnLnInvoice"),
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnLnInvoice") },
                paymentHash = paymentHash,
                descriptionHash = descriptionHash,
                minFinalCltvExpiryDelta = minFinalCltvExpiryDelta?.let { requireUShort(it, "minFinalCltvExpiryDelta", "rlnLnInvoice") }
            )
            val response = nodeStore.get(nodeId).lnInvoice(request)
            mapOf("invoice" to response.invoice)
        }
    }

    override fun rlnClaimHodlInvoice(nodeId: Long, paymentHash: String, paymentPreimage: String): RlnWireResponse {
        return runRlnWire("rlnClaimHodlInvoice") {
            val response = nodeStore.get(nodeId).claimhodlinvoice(
                ClaimHodlInvoiceRequest(
                    paymentHash = paymentHash,
                    paymentPreimage = paymentPreimage
                )
            )
            mapOf("changed" to response.changed)
        }
    }

    override fun rlnCancelHodlInvoice(nodeId: Long, paymentHash: String) {
        runRln("rlnCancelHodlInvoice") {
            nodeStore.get(nodeId).cancelhodlinvoice(
                CancelHodlInvoiceRequest(paymentHash = paymentHash)
            )
        }
    }

    override fun rlnApayNew(nodeId: Long, hostNodeId: String): RlnWireResponse {
        return runRlnWire("rlnApayNew") {
            val response = nodeStore.get(nodeId).apayNew(hostNodeId)
            mapOf(
                "requestId" to response.requestId,
                "hostNodeId" to response.hostNodeId,
                "protocolVersion" to response.protocolVersion,
                "orderId" to response.orderId,
                "status" to response.status,
                "acceptedThroughIndex" to response.acceptedThroughIndex,
                "nextIndexExpected" to response.nextIndexExpected,
                "unusedHashes" to response.unusedHashes,
                "refillBatchSize" to response.refillBatchSize,
                "firstHashIndex" to response.firstHashIndex,
                "lastHashIndex" to response.lastHashIndex,
                "hashes" to response.hashes.map(::apayHashMap)
            )
        }
    }

    override fun rlnApayNewWithAddress(nodeId: Long, hostNodeId: String, username: String, domain: String): RlnWireResponse {
        return runRlnWire("rlnApayNewWithAddress") {
            val response = nodeStore.get(nodeId).apayNewWithAddress(hostNodeId, username, domain)
            mapOf(
                "requestId" to response.requestId,
                "hostNodeId" to response.hostNodeId,
                "protocolVersion" to response.protocolVersion,
                "orderId" to response.orderId,
                "status" to response.status,
                "acceptedThroughIndex" to response.acceptedThroughIndex,
                "nextIndexExpected" to response.nextIndexExpected,
                "unusedHashes" to response.unusedHashes,
                "refillBatchSize" to response.refillBatchSize,
                "firstHashIndex" to response.firstHashIndex,
                "lastHashIndex" to response.lastHashIndex,
                "hashes" to response.hashes.map(::apayHashMap)
            )
        }
    }

    override fun rlnRefreshTransfers(nodeId: Long, skipSync: Boolean): RlnRefreshTransfersData {
        return runRln("rlnRefreshTransfers") {
            val response = nodeStore.get(nodeId).refreshtransfers(
                org.utexo.rgblightningnode.SdkRefreshTransfersRequest(skipSync)
            )
            RlnRefreshTransfersData(
                transfers = response.transfers.entries
                    .sortedBy { it.key }
                    .map { (index, transfer) ->
                        RlnRefreshedTransferData(
                            index = index.toLong(),
                            updatedStatus = transfer.updatedStatus,
                            failure = transfer.failure?.let {
                                RlnRefreshFailureData(name = it.name, message = it.message)
                            }
                        )
                    }
            )
        }
    }

    private fun parseAssignmentKind(rawValue: String?): org.utexo.rgblightningnode.AssignmentKind? {
        return when (rawValue) {
            null -> null
            "Fungible" -> org.utexo.rgblightningnode.AssignmentKind.FUNGIBLE
            "NonFungible" -> org.utexo.rgblightningnode.AssignmentKind.NON_FUNGIBLE
            "InflationRight" -> org.utexo.rgblightningnode.AssignmentKind.INFLATION_RIGHT
            "ReplaceRight" -> org.utexo.rgblightningnode.AssignmentKind.REPLACE_RIGHT
            "Any" -> org.utexo.rgblightningnode.AssignmentKind.ANY
            else -> invalidArgument(
                "rlnRgbInvoice",
                "assignmentKind",
                "Unknown assignmentKind: $rawValue"
            )
        }
    }

    override fun rlnRgbInvoice(
        nodeId: Long,
        assetId: String?,
        assignmentAmount: Long?,
        durationSeconds: Long?,
        minConfirmations: Long,
        witness: Boolean,
        assignmentKind: String?
    ): RlnWireResponse {
        return runRlnWire("rlnRgbInvoice") {
            val request = org.utexo.rgblightningnode.SdkRgbInvoiceRequest(
                assetId = assetId,
                assignmentKind = parseAssignmentKind(assignmentKind),
                assignmentAmount = assignmentAmount?.let { requireULong(it, "assignmentAmount", "rlnRgbInvoice") },
                durationSeconds = durationSeconds?.let { requireUInt(it, "durationSeconds", "rlnRgbInvoice") },
                minConfirmations = requireUByte(minConfirmations, "minConfirmations", "rlnRgbInvoice"),
                witness = witness
            )
            rgbInvoiceMap(nodeStore.get(nodeId).rgbinvoice(request))
        }
    }

    override fun rlnSendBtc(nodeId: Long, amount: Long, address: String, feeRate: Double, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnSendBtc") {
            val request = org.utexo.rgblightningnode.SdkSendBtcRequest(
                amount = requireULong(amount, "amount", "rlnSendBtc"),
                address = address,
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnSendBtc"),
                skipSync = skipSync
            )
            val response = nodeStore.get(nodeId).sendbtc(request)
            mapOf("txid" to response.txid)
        }
    }

    override fun rlnPrepareOnchainSend(nodeId: Long, requestJson: String): String =
        runRln("rlnPrepareOnchainSend") {
            recoverableOnchainCall(nodeId, "prepareOnchainSend", requestJson, "rlnPrepareOnchainSend")
        }

    override fun rlnCommitOnchainSend(nodeId: Long, requestJson: String): String =
        runRln("rlnCommitOnchainSend") {
            recoverableOnchainCall(nodeId, "commitOnchainSend", requestJson, "rlnCommitOnchainSend")
        }

    override fun rlnOnchainSendStatus(nodeId: Long, requestJson: String): String =
        runRln("rlnOnchainSendStatus") {
            recoverableOnchainCall(nodeId, "onchainSendStatus", requestJson, "rlnOnchainSendStatus")
        }

    override fun rlnCancelOnchainSend(nodeId: Long, requestJson: String): String =
        runRln("rlnCancelOnchainSend") {
            recoverableOnchainCall(nodeId, "cancelOnchainSend", requestJson, "rlnCancelOnchainSend")
        }

    // Reflection keeps the published, older AAR source-compatible. Absence is
    // unsupported, never an absent operation or permission to send again.
    private fun recoverableOnchainCall(nodeId: Long, methodName: String, input: String, operation: String): String {
        val node = nodeStore.get(nodeId)
        val method = try {
            node.javaClass.getMethod(methodName, String::class.java)
        } catch (_: NoSuchMethodException) {
            throw FlutterError(
                code = "UnsupportedOperationException",
                message = "This native artifact does not support durable on-chain sends.",
                details = bridgeErrorDetails(operation = operation, category = "unsupported", retryable = false,
                    extra = mapOf("feature" to "recoverableOnchainSend"))
            )
        }
        val result = try {
            method.invoke(node, input)
        } catch (error: java.lang.reflect.InvocationTargetException) {
            throw error.targetException
        }
        return result as? String ?: throw FlutterError(
            code = "InvalidRequest", message = "Invalid native durable-send response.", details = null
        )
    }

    override fun rlnSendPayment(nodeId: Long, invoice: String, amtMsat: Long?, assetId: String?, assetAmount: Long?): RlnWireResponse {
        return runRlnWire("rlnSendPayment") {
            val request = org.utexo.rgblightningnode.SdkSendPaymentRequest(
                invoice = invoice,
                amtMsat = amtMsat?.let { requireULong(it, "amtMsat", "rlnSendPayment") },
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnSendPayment") }
            )
            val response = nodeStore.get(nodeId).sendpayment(request)
            sendPaymentMap(response)
        }
    }

    override fun rlnSendRgb(nodeId: Long, donation: Boolean, feeRate: Double, minConfirmations: Long, skipSync: Boolean, assetId: String, recipientId: String, amount: Long, transportEndpoints: List<String>, witnessAmountSat: Long?, witnessBlinding: Long?): RlnWireResponse {
        return runRlnWire("rlnSendRgb") {
            if (skipSync) {
                throw FlutterError(
                    code = "UnsupportedOperationException",
                    message = "rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.",
                    details = bridgeErrorDetails(
                        operation = "rlnSendRgb",
                        category = "unsupported",
                        retryable = false,
                        extra = mapOf("field" to "skipSync", "feature" to "sendRgb.skipSync")
                    )
                )
            }
            val witnessData = witnessAmountSat?.let {
                org.utexo.rgblightningnode.WitnessData(
                    amountSat = requireULong(it, "witnessAmountSat", "rlnSendRgb"),
                    blinding = witnessBlinding?.let { value ->
                        requireULong(value, "witnessBlinding", "rlnSendRgb")
                    }
                )
            }
            val recipient = org.utexo.rgblightningnode.RgbRecipient(
                recipientId = recipientId,
                witnessData = witnessData,
                assignmentKind = org.utexo.rgblightningnode.AssignmentKind.FUNGIBLE,
                assignmentAmount = requireULong(amount, "amount", "rlnSendRgb"),
                transportEndpoints = transportEndpoints
            )
            val request = org.utexo.rgblightningnode.SendRgbRequest(
                donation = donation,
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnSendRgb"),
                minConfirmations = requireUByte(minConfirmations, "minConfirmations", "rlnSendRgb"),
                recipientGroups = listOf(
                    org.utexo.rgblightningnode.AssetRecipients(
                        assetId = assetId,
                        recipients = listOf(recipient)
                    )
                )
            )
            val response = nodeStore.get(nodeId).sendRgb(request)
            mapOf(
                "txid" to response.txid,
                "batchTransferIdx" to response.batchTransferIdx
            )
        }
    }

    override fun rlnShutdown(nodeId: Long) {
        runRln("rlnShutdown") {
            val node = nodeStore.get(nodeId)
            node.shutdown()
            nodeStore.markShutdown(nodeId)
        }
    }

    override fun rlnSync(nodeId: Long) {
        runRln("rlnSync") {
            nodeStore.get(nodeId).sync()
        }
    }

    override fun rlnIssueAssetNia(nodeId: Long, ticker: String, name: String, precision: Long, amounts: List<Long>): RlnWireResponse {
        return runRlnWire("rlnIssueAssetNia") {
            val asset = nodeStore.get(nodeId).issueassetnia(
                org.utexo.rgblightningnode.SdkIssueAssetNiaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetNia"),
                    ticker = ticker,
                    name = name,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetNia")
                )
            )
            RlnAssetMapper.assetNiaMap(asset)
        }
    }

    override fun rlnIssueAssetCfa(nodeId: Long, name: String, details: String?, precision: Long, amounts: List<Long>, fileDigest: String?): RlnWireResponse {
        return runRlnWire("rlnIssueAssetCfa") {
            val asset = nodeStore.get(nodeId).issueassetcfa(
                org.utexo.rgblightningnode.SdkIssueAssetCfaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetCfa"),
                    name = name,
                    details = details,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetCfa"),
                    fileDigest = fileDigest
                )
            )
            RlnAssetMapper.assetCfaMap(asset)
        }
    }

    override fun rlnIssueAssetIfa(nodeId: Long, ticker: String, name: String, precision: Long, amounts: List<Long>, inflationAmounts: List<Long>, rejectListUrl: String?): RlnWireResponse {
        return runRlnWire("rlnIssueAssetIfa") {
            val asset = nodeStore.get(nodeId).issueassetifa(
                org.utexo.rgblightningnode.SdkIssueAssetIfaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetIfa"),
                    inflationAmounts = requireULongList(inflationAmounts, "inflationAmounts", "rlnIssueAssetIfa"),
                    ticker = ticker,
                    name = name,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetIfa"),
                    rejectListUrl = rejectListUrl
                )
            )
            RlnAssetMapper.assetIfaMap(asset)
        }
    }

    override fun rlnInflate(
        nodeId: Long,
        assetId: String,
        inflationAmounts: List<Long>,
        feeRate: Double,
        minConfirmations: Long
    ): RlnWireResponse {
        return runRlnWire("rlnInflate") {
            val request = org.utexo.rgblightningnode.InflateRequest(
                assetId = assetId,
                inflationAmounts = requireULongList(
                    inflationAmounts,
                    "inflationAmounts",
                    "rlnInflate"
                ),
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnInflate"),
                minConfirmations = requireUByte(
                    minConfirmations,
                    "minConfirmations",
                    "rlnInflate"
                )
            )
            val response = nodeStore.get(nodeId).inflate(request)
            mapOf("txid" to response.txid)
        }
    }

    override fun rlnIssueAssetUda(nodeId: Long, ticker: String, name: String, details: String?, precision: Long, mediaFileDigest: String?, attachmentsFileDigests: List<String>): RlnWireResponse {
        return runRlnWire("rlnIssueAssetUda") {
            val asset = nodeStore.get(nodeId).issueassetuda(
                org.utexo.rgblightningnode.SdkIssueAssetUdaRequest(
                    ticker = ticker,
                    name = name,
                    details = details,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetUda"),
                    mediaFileDigest = mediaFileDigest,
                    attachmentsFileDigests = attachmentsFileDigests
                )
            )
            RlnAssetMapper.assetUdaMap(asset)
        }
    }

    override fun rlnVssBackup(nodeId: Long): Long {
        return runRln("rlnVssBackup") {
            nodeStore.get(nodeId).vssBackup()
        }
    }

    override fun rlnVssClearFence(nodeId: Long, password: String) {
        runRln("rlnVssClearFence") {
            nodeStore.get(nodeId).vssClearFence(
                SdkVssClearFenceRequest(password = password)
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RlnHostApi.setUp(binding.binaryMessenger, null)
        closeEngine().whenComplete { _, error ->
            if (error != null) Log.e("RgbSdkFlutter", "Native engine cleanup failed.")
        }
    }
}
