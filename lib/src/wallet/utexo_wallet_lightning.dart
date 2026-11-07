part of 'utexo_wallet.dart';

mixin _UtexoWalletLightning on _UtexoWalletInternals {
  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) async {
    _assertLightningEnabled();
    _requireNonNegativeOptional(amountSats, 'amountSats');
    final invoice = await _createRlnLightningInvoice(
      amtMsat: WalletInputPolicy.satsToMsats(amountSats, 'amountSats'),
      expirySec: expirySeconds,
      assetId: asset?.assetId,
      assetAmount: asset?.amount,
      paymentHash: null,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
      description: description,
    );
    return LightningReceiveRequest(lnInvoice: invoice.invoice);
  }

  Future<RlnLnInvoice> _createRlnLightningInvoice({
    int? amtMsat,
    int expirySec = 3600,
    String? assetId,
    int? assetAmount,
    String? paymentHash,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) async {
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireUInt32(expirySec, 'expirySec');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUInt16Optional(minFinalCltvExpiryDelta, 'minFinalCltvExpiryDelta');
    _requireUnlockedNode();
    return _binding.rlnLnInvoice(
      amtMsat,
      expirySec,
      assetId,
      assetAmount,
      paymentHash: paymentHash,
      minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
      descriptionHash: descriptionHash,
      description: description,
    );
  }

  Future<HodlInvoice> createHodlInvoice(CreateHodlInvoiceParams params) async {
    _assertLightningEnabled();
    _requireNonEmpty(params.paymentHash, 'paymentHash');
    _requireNonNegativeOptional(params.amtMsat, 'amtMsat');
    _requireUInt32(params.expirySec, 'expirySec');
    _requireNonNegativeOptional(params.assetAmount, 'assetAmount');
    _requireUInt16Optional(
      params.minFinalCltvExpiryDelta,
      'minFinalCltvExpiryDelta',
    );
    final invoice = await _createRlnLightningInvoice(
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      paymentHash: params.paymentHash,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
      description: params.description,
    );
    return HodlInvoice(
      bolt11: invoice.invoice,
      paymentHash: params.paymentHash,
      amtMsat: params.amtMsat,
      expirySec: params.expirySec,
      assetId: params.assetId,
      assetAmount: params.assetAmount,
      minFinalCltvExpiryDelta: params.minFinalCltvExpiryDelta,
      descriptionHash: params.descriptionHash,
      description: params.description,
    );
  }

  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async {
    _assertLightningEnabled();
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireNonEmpty(preimage, 'preimage');
    _requireUnlockedNode();
    final response = await _binding.rlnClaimHodlInvoice(paymentHash, preimage);
    return HodlInvoiceResult(
      changed: _requiredNativeBool(
        response,
        'changed',
        'RlnClaimHodlInvoiceResponse',
      ),
    );
  }

  Future<HodlInvoiceResult> cancelHodlInvoice(String paymentHash) async {
    _assertLightningEnabled();
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireUnlockedNode();
    await _binding.rlnCancelHodlInvoice(paymentHash);
    return const HodlInvoiceResult(changed: true);
  }

  Future<RlnDecodedLnInvoice> _decodeLnInvoiceRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnDecodeLnInvoice(invoice);
  }

  Future<DecodedLightningInvoice> decodeLnInvoice(String invoice) async {
    _assertLightningEnabled();
    return (await _decodeLnInvoiceRaw(invoice)).toDecodedLightningInvoice();
  }

  Future<LightningSendRequest> payLightningInvoice({
    required String lnInvoice,
    int? amount,
    String? assetId,
    int? assetAmount,
  }) async {
    _assertLightningEnabled();
    _requireNonEmpty(lnInvoice, 'lnInvoice');
    _requireNonNegativeOptional(amount, 'amount');
    final payment = await _payRlnLightningInvoice(
      invoice: lnInvoice,
      amtMsat: WalletInputPolicy.satsToMsats(amount, 'amount'),
      assetId: assetId,
      assetAmount: assetAmount,
    );
    final txid = payment.paymentHash ?? payment.paymentId;
    if (txid == null || txid.isEmpty) {
      throw const NativeProtocolException(
        'RlnSendPaymentResponse must contain a non-empty paymentHash or '
        'paymentId.',
        field: 'RlnSendPaymentResponse.paymentHash',
      );
    }
    return LightningSendRequest(
      txid: txid,
      status: tryNormalizePaymentStatus(payment.status),
    );
  }

  Future<RlnPaymentResult> _payRlnLightningInvoice({
    required String invoice,
    int? amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireNonNegativeOptional(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUnlockedNode();
    return _binding.rlnSendPayment(invoice, amtMsat, assetId, assetAmount);
  }

  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id) async {
    _assertLightningEnabled();
    _requireNonEmpty(id, 'id');
    return normalizeInvoiceStatus((await _invoiceStatusRaw(id)).status);
  }

  Future<RlnPaymentStatusValue?> getLightningSendStatus(String id) async {
    _assertLightningEnabled();
    _requireNonEmpty(id, 'id');
    final payment = await _getPaymentRaw(id);
    return tryNormalizePaymentStatus(payment.status);
  }

  Future<RlnInvoiceStatus> _invoiceStatusRaw(String invoice) async {
    _requireNonEmpty(invoice, 'invoice');
    _requireUnlockedNode();
    return _binding.rlnInvoiceStatus(invoice);
  }

  Future<RlnInvoiceStatusValue> invoiceStatus(String invoice) async {
    _assertLightningEnabled();
    return normalizeInvoiceStatus((await _invoiceStatusRaw(invoice)).status);
  }

  Future<List<RlnPayment>> _listPaymentsRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListPayments();
  }

  Future<List<LightningPayment>> listPayments() async {
    _assertLightningEnabled();
    return (await _listPaymentsRaw())
        .map((payment) => payment.toLightningPayment())
        .toList(growable: false);
  }

  Future<ListLightningPaymentsResponse> listLightningPayments() async {
    _assertLightningEnabled();
    final payments = await _listPaymentsRaw();
    return ListLightningPaymentsResponse(
      payments: payments
          .map(
            (payment) => LightningSendRequest(
              txid: payment.paymentHash,
              status: tryNormalizePaymentStatus(payment.status),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> connectPeer(String peerPubkeyAndAddr) async {
    _assertLightningEnabled();
    _requireNonEmpty(peerPubkeyAndAddr, 'peerPubkeyAndAddr');
    _requireUnlockedNode();
    return _binding.rlnConnectPeer(peerPubkeyAndAddr);
  }

  Future<void> disconnectPeer(String peerPubkey) async {
    _assertLightningEnabled();
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _requireUnlockedNode();
    return _binding.rlnDisconnectPeer(peerPubkey);
  }

  Future<List<RlnPeer>> _listPeersRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListPeers();
  }

  Future<List<LightningPeer>> listPeers() async {
    _assertLightningEnabled();
    return (await _listPeersRaw())
        .map((peer) => peer.toLightningPeer())
        .toList(growable: false);
  }

  Future<List<RlnChannel>> _listChannelsRaw() async {
    _requireUnlockedNode();
    return _binding.rlnListChannels();
  }

  Future<List<LightningChannel>> listChannels() async {
    _assertLightningEnabled();
    return (await _listChannelsRaw())
        .map((channel) => channel.toLightningChannel())
        .toList(growable: false);
  }

  Future<RlnOpenChannelResult> _openChannelRaw({
    required String peerPubkeyAndOptAddr,
    required int capacitySat,
    int pushMsat = 0,
    bool publicChannel = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async {
    _requireNonEmpty(peerPubkeyAndOptAddr, 'peerPubkeyAndOptAddr');
    _requirePositive(capacitySat, 'capacitySat');
    _requireNonNegative(pushMsat, 'pushMsat');
    _requireUInt32Optional(feeBaseMsat, 'feeBaseMsat');
    _requireUInt32Optional(
      feeProportionalMillionths,
      'feeProportionalMillionths',
    );
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireNonNegativeOptional(pushAssetAmount, 'pushAssetAmount');
    _requireUnlockedNode();
    return _binding.rlnOpenChannel(
      RlnOpenChannelRequest(
        peerPubkeyAndOptAddr: peerPubkeyAndOptAddr,
        capacitySat: capacitySat,
        pushMsat: pushMsat,
        public: publicChannel,
        withAnchors: withAnchors,
        feeBaseMsat: feeBaseMsat,
        feeProportionalMillionths: feeProportionalMillionths,
        temporaryChannelId: temporaryChannelId,
        assetId: assetId,
        assetAmount: assetAmount,
        pushAssetAmount: pushAssetAmount,
        virtualOpenMode: virtualOpenMode,
      ),
    );
  }

  Future<LightningChannelOpenResult> openChannel({
    required String peerPubkey,
    required int capacitySat,
    int pushMsat = 0,
    bool isPublic = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetLocalAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async {
    _assertLightningEnabled();
    return (await _openChannelRaw(
      peerPubkeyAndOptAddr: peerPubkey,
      capacitySat: capacitySat,
      pushMsat: pushMsat,
      publicChannel: isPublic,
      withAnchors: withAnchors,
      feeBaseMsat: feeBaseMsat,
      feeProportionalMillionths: feeProportionalMillionths,
      temporaryChannelId: temporaryChannelId,
      assetId: assetId,
      assetAmount: assetLocalAmount,
      pushAssetAmount: pushAssetAmount,
      virtualOpenMode: virtualOpenMode,
    )).toLightningChannelOpenResult();
  }

  Future<void> closeChannel({
    required String channelId,
    required String peerPubkey,
    bool force = false,
  }) async {
    _assertLightningEnabled();
    _requireNonEmpty(channelId, 'channelId');
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _requireUnlockedNode();
    return _binding.rlnCloseChannel(channelId, peerPubkey, force);
  }

  Future<String> getChannelId(String temporaryChannelId) async {
    _assertLightningEnabled();
    _requireNonEmpty(temporaryChannelId, 'temporaryChannelId');
    _requireUnlockedNode();
    return _binding.rlnGetChannelId(temporaryChannelId);
  }

  Future<RlnPaymentResult> _keysendRaw({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _requireNonEmpty(destPubkey, 'destPubkey');
    _requirePositive(amtMsat, 'amtMsat');
    _requireNonNegativeOptional(assetAmount, 'assetAmount');
    _requireUnlockedNode();
    return _binding.rlnKeysend(destPubkey, amtMsat, assetId, assetAmount);
  }

  Future<SendPaymentResult> keysend({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async {
    _assertLightningEnabled();
    return (await _keysendRaw(
      destPubkey: destPubkey,
      amtMsat: amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    )).toSendPaymentResult();
  }

  Future<RlnPayment> _getPaymentRaw(String paymentHash) async {
    _requireNonEmpty(paymentHash, 'paymentHash');
    _requireUnlockedNode();
    return _binding.rlnGetPayment(paymentHash);
  }

  Future<String> signNodeMessage(String message) async {
    _requireNonEmpty(message, 'message');
    _requireUnlockedNode();
    return (await _binding.rlnSignMessage(message)).signedMessage;
  }

  Future<bool> verifyNodeMessage(String message, String signature) async {
    _requireNonEmpty(message, 'message');
    _requireNonEmpty(signature, 'signature');
    _requireUnlockedNode();
    return (await _binding.rlnVerifyMessage(message, signature)).valid;
  }

  Future<String> signMessage(String message) => signNodeMessage(message);

  Future<bool> verifyMessage(String message, String signature) =>
      verifyNodeMessage(message, signature);

  Future<void> vssClearFence(String password) {
    _requireNonEmpty(password, 'password');
    _ensureInitialized();
    return _binding.rlnVssClearFence(password);
  }

  Future<int> backupNow() {
    _requireUnlockedNode();
    return _binding.rlnVssBackup();
  }
}
