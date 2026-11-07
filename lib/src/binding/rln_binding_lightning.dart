part of 'rln_binding.dart';

mixin _RlnBindingLightning on _RlnBindingInternals {
  Future<void> rlnConnectPeer(String peerPubkeyAndAddr) {
    return _withNodeOperation(
      'rlnConnectPeer',
      (nodeId) => _client.connectPeer(
        nodeId: nodeId,
        peerPubkeyAndAddr: peerPubkeyAndAddr,
      ),
    );
  }

  Future<List<RlnPeer>> rlnListPeers() async {
    final peers = await _withNodeOperation('rlnListPeers', _client.listPeers);
    return peers.map(RlnPeer.fromMap).toList(growable: false);
  }

  Future<void> rlnDisconnectPeer(String peerPubkey) {
    return _withNodeOperation(
      'rlnDisconnectPeer',
      (nodeId) =>
          _client.disconnectPeer(nodeId: nodeId, peerPubkey: peerPubkey),
    );
  }

  Future<List<RlnChannel>> rlnListChannels() async {
    final channels = await _withNodeOperation(
      'rlnListChannels',
      _client.listChannels,
    );
    return channels.map(RlnChannel.fromMap).toList(growable: false);
  }

  Future<RlnOpenChannelResult> rlnOpenChannel(RlnOpenChannelRequest request) {
    return _withNodeOperation(
      'rlnOpenChannel',
      (nodeId) async => RlnOpenChannelResult.fromMap(
        await _client.openChannel(
          nodeId: nodeId,
          peerPubkeyAndOptAddr: request.peerPubkeyAndOptAddr,
          capacitySat: request.capacitySat,
          pushMsat: request.pushMsat,
          publicChannel: request.public,
          withAnchors: request.withAnchors,
          feeBaseMsat: request.feeBaseMsat,
          feeProportionalMillionths: request.feeProportionalMillionths,
          temporaryChannelId: request.temporaryChannelId,
          assetId: request.assetId,
          assetAmount: request.assetAmount,
          pushAssetAmount: request.pushAssetAmount,
          virtualOpenMode: request.virtualOpenMode,
        ),
      ),
    );
  }

  Future<void> rlnCloseChannel(
    String channelId,
    String peerPubkey,
    bool force,
  ) {
    return _withNodeOperation(
      'rlnCloseChannel',
      (nodeId) => _client.closeChannel(
        nodeId: nodeId,
        channelId: channelId,
        peerPubkey: peerPubkey,
        force: force,
      ),
    );
  }

  Future<String> rlnGetChannelId(String temporaryChannelId) {
    return _withNodeOperation(
      'rlnGetChannelId',
      (nodeId) => _client.getChannelId(
        nodeId: nodeId,
        temporaryChannelId: temporaryChannelId,
      ),
    );
  }

  Future<List<RlnPayment>> rlnListPayments() async {
    final payments = await _withNodeOperation(
      'rlnListPayments',
      _client.listPayments,
    );
    return payments.map(RlnPayment.fromMap).toList(growable: false);
  }

  Future<RlnPayment> rlnGetPayment(String paymentHash) async {
    return RlnPayment.fromMap(
      await _withNodeOperation(
        'rlnGetPayment',
        (nodeId) =>
            _client.getPayment(nodeId: nodeId, paymentHash: paymentHash),
      ),
    );
  }

  Future<RlnInvoiceStatus> rlnInvoiceStatus(String invoice) async {
    return RlnInvoiceStatus.fromMap(
      await _withNodeOperation(
        'rlnInvoiceStatus',
        (nodeId) => _client.invoiceStatus(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnLnInvoice> rlnLnInvoice(
    int? amtMsat,
    int expirySec,
    String? assetId,
    int? assetAmount, {
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) async {
    return RlnLnInvoice.fromMap(
      await _withNodeOperation(
        'rlnLnInvoice',
        (nodeId) => _client.lnInvoice(
          nodeId: nodeId,
          amtMsat: amtMsat,
          expirySec: expirySec,
          assetId: assetId,
          assetAmount: assetAmount,
          paymentHash: paymentHash,
          minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
          descriptionHash: descriptionHash,
          description: description,
        ),
      ),
    );
  }

  Future<RlnMap> rlnClaimHodlInvoice(
    String paymentHash,
    String paymentPreimage,
  ) {
    return _withNodeOperation(
      'rlnClaimHodlInvoice',
      (nodeId) => _client.claimHodlInvoice(
        nodeId: nodeId,
        paymentHash: paymentHash,
        paymentPreimage: paymentPreimage,
      ),
    );
  }

  Future<void> rlnCancelHodlInvoice(String paymentHash) {
    return _withNodeOperation(
      'rlnCancelHodlInvoice',
      (nodeId) =>
          _client.cancelHodlInvoice(nodeId: nodeId, paymentHash: paymentHash),
    );
  }

  Future<RlnMap> rlnApayNew(String hostNodeId) {
    return _withNodeOperation(
      'rlnApayNew',
      (nodeId) => _client.apayNew(nodeId: nodeId, hostNodeId: hostNodeId),
    );
  }

  Future<RlnMap> rlnApayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) {
    return _withNodeOperation(
      'rlnApayNewWithAddress',
      (nodeId) => _client.apayNewWithAddress(
        nodeId: nodeId,
        hostNodeId: hostNodeId,
        username: username,
        domain: domain,
      ),
    );
  }

  Future<RlnDecodedLnInvoice> rlnDecodeLnInvoice(String invoice) async {
    return RlnDecodedLnInvoice.fromMap(
      await _withNodeOperation(
        'rlnDecodeLnInvoice',
        (nodeId) => _client.decodeLnInvoice(nodeId: nodeId, invoice: invoice),
      ),
    );
  }

  Future<RlnPaymentResult> rlnSendPayment(
    String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    return RlnPaymentResult.fromMap(
      await _withNodeOperation(
        'rlnSendPayment',
        (nodeId) => _client.sendPayment(
          nodeId: nodeId,
          invoice: invoice,
          amtMsat: amtMsat,
          assetId: assetId,
          assetAmount: assetAmount,
        ),
      ),
    );
  }

  Future<RlnPaymentResult> rlnKeysend(
    String destPubkey,
    int amtMsat,
    String? assetId,
    int? assetAmount,
  ) async {
    return RlnPaymentResult.fromMap(
      await _withNodeOperation(
        'rlnKeysend',
        (nodeId) => _client.keysend(
          nodeId: nodeId,
          destPubkey: destPubkey,
          amtMsat: amtMsat,
          assetId: assetId,
          assetAmount: assetAmount,
        ),
      ),
    );
  }
}
