part of 'rln_wallet.dart';

mixin _UtexoWalletLspApay on _UtexoWalletInternals {
  Future<ApayNewResponse> apayNew(String hostNodeId) async {
    _assertLightningEnabled();
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    _requireUnlockedNode();
    return decodeNativeApayNewResponse(
      await _binding.rlnApayNew(hostNodeId),
      expectedHostNodeId: hostNodeId,
    );
  }

  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) async {
    _assertLightningEnabled();
    _requireNonEmpty(hostNodeId, 'hostNodeId');
    _requireNonEmpty(username, 'username');
    _requireNonEmpty(domain, 'domain');
    _requireUnlockedNode();
    return decodeNativeApayNewResponse(
      await _binding.rlnApayNewWithAddress(hostNodeId, username, domain),
      expectedHostNodeId: hostNodeId,
    );
  }

  Future<UtexoLsp> createLsp([LspPeer? peer, int peerPort = 9735]) async {
    _assertLightningEnabled();
    _ensureNotDisposed();
    if (peer != null) return UtexoLsp(wallet: _walletSelf, peer: peer);
    _ensureVirtualChannelsMutable();
    final baseUrl = resolveLspBaseUrl(_config.network, _config.lspBaseUrl);
    final client = UtexoLspClient(
      baseUrl: baseUrl,
      bearerToken: _config.lspBearerToken,
    );
    try {
      final info = await client.getInfo();
      _enableVirtualChannelsForPeer(info.pubkey);
      final peerHost = info.host ?? Uri.parse(baseUrl).host;
      return UtexoLsp(
        wallet: _walletSelf,
        peer: LspPeer(
          baseUrl: baseUrl,
          peerPubkey: info.pubkey,
          peerHost: peerHost,
          peerPort: info.port ?? peerPort,
          bearerToken: _config.lspBearerToken,
        ),
        httpClient: client,
      );
    } catch (error) {
      client.close();
      rethrow;
    }
  }

  UtexoLspConfig getLspConfig() {
    return UtexoLspConfig(
      baseUrl: _config.lspBaseUrl,
      bearerToken: _config.lspBearerToken,
    );
  }

  @override
  void _ensureVirtualChannelsMutable() {
    if (_nodeCreated || _nodeId != null) {
      throw const WalletException(
        'createLsp() must be called before init()/reinit(): virtual-channel '
        'params are baked into the node at init time and cannot be changed '
        'afterwards.',
      );
    }
  }

  @override
  void _enableVirtualChannelsForPeer(String peerPubkey) {
    _ensureVirtualChannelsMutable();
    _requireNonEmpty(peerPubkey, 'peerPubkey');
    _resolvedEnableVirtualChannelsV0 = true;
    _resolvedLspBaseUrl = resolveLspBaseUrl(
      _config.network,
      _config.lspBaseUrl,
    );
    final existing =
        _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys ?? const [];
    if (existing.contains(peerPubkey)) {
      _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(existing);
      return;
    }
    _resolvedVirtualPeerPubkeys = List<String>.unmodifiable(<String>[
      ...existing,
      peerPubkey,
    ]);
  }
}
