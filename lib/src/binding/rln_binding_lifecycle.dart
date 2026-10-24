part of 'rln_binding.dart';

mixin _RlnBindingLifecycle on _RlnBindingInternals {
  Future<int> rlnCreateNode(IRLNNodeCreateParams params) {
    return _withNodeQueue('rlnCreateNode', () async {
      final previousNodeId = _rlnNodeId;
      final previousState = _lifecycleState;
      final previousRetiredNodeCount = _retiredRlnNodeIds.length;
      if (_rlnNodeId != null) {
        if (_lifecycleState != _RlnLifecycleState.shuttingDown) {
          throw const WalletError('RLN node is already created');
        }
        _retiredRlnNodeIds.add(_rlnNodeId!);
        _rlnNodeId = null;
        _lifecycleState = _RlnLifecycleState.idle;
      }
      try {
        final nodeId = await _client.createNode(
          storageDirPath: params.storageDirPath,
          daemonListeningPort: params.daemonListeningPort,
          ldkPeerListeningPort: params.ldkPeerListeningPort,
          network: params.network,
          maxMediaUploadSizeMb: params.maxMediaUploadSizeMb,
          enableVirtualChannelsV0: params.enableVirtualChannelsV0,
          virtualPeerPubkeys: params.virtualPeerPubkeys,
          vssUrl: params.vssUrl,
          vssAllowHttp: params.vssAllowHttp,
          vssAllowEmptyRestore: params.vssAllowEmptyRestore,
          lspBaseUrl: params.lspBaseUrl,
          lspBearerToken: params.lspBearerToken,
          reuseAddresses: params.reuseAddresses,
        );
        _rlnNodeId = nodeId;
        _lifecycleState = _RlnLifecycleState.active;
        return nodeId;
      } catch (error, stackTrace) {
        _rlnNodeId = previousNodeId;
        _lifecycleState = previousState;
        _retiredRlnNodeIds.removeRange(
          previousRetiredNodeCount,
          _retiredRlnNodeIds.length,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<String> rlnInitNode(String password, [String? mnemonic]) {
    return _withNodeOperation(
      'rlnInitNode',
      (nodeId) => _client.initNode(
        nodeId: nodeId,
        password: password,
        mnemonic: mnemonic,
      ),
    );
  }

  Future<void> rlnUnlockNode({
    required String password,
    IRLNUnlockParams? params,
  }) {
    return _withNodeQueue('rlnUnlockNode', () async {
      final resolvedParams = params ?? IRLNUnlockParams();
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      _unlockConflictNormalized = false;
      if (await _probeNodeReady(nodeId)) return;
      try {
        await _client.unlockNode(
          nodeId: nodeId,
          password: password,
          bitcoindRpcUsername: resolvedParams.bitcoindRpcUsername,
          bitcoindRpcPassword: resolvedParams.bitcoindRpcPassword,
          bitcoindRpcHost: resolvedParams.bitcoindRpcHost,
          bitcoindRpcPort: resolvedParams.bitcoindRpcPort,
          indexerUrl: resolvedParams.indexerUrl,
          proxyEndpoint: resolvedParams.proxyEndpoint,
          announceAddresses: resolvedParams.announceAddresses,
          announceAlias: resolvedParams.announceAlias,
          gossipRgsServerUrl: resolvedParams.gossipRgsServerUrl,
          ethRpcUrl: resolvedParams.ethRpcUrl,
        );
      } catch (error) {
        if (!_isConflictError(error) || !await _probeNodeReady(nodeId)) {
          rethrow;
        }
        _unlockConflictNormalized = true;
      }
    });
  }

  Future<void> rlnShutdown() {
    return _withNodeQueue('rlnShutdown', () async {
      final nodeId = _requireNodeId();
      _lifecycleState = _RlnLifecycleState.shuttingDown;
      try {
        await _client.shutdown(nodeId);
      } catch (error, stackTrace) {
        _lifecycleState = _RlnLifecycleState.active;
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> rlnDestroyNode() {
    return _withNodeQueue('rlnDestroyNode', () async {
      final nodeId = _rlnNodeId;
      final nodeIds = <int>[?nodeId, ..._retiredRlnNodeIds];
      if (nodeIds.isEmpty) return;
      _lifecycleState = _RlnLifecycleState.destroying;
      try {
        for (final id in nodeIds.reversed) {
          await _client.destroyNode(id);
        }
        _rlnNodeId = null;
        _retiredRlnNodeIds.clear();
        _lifecycleState = _RlnLifecycleState.idle;
      } catch (error, stackTrace) {
        _lifecycleState = _RlnLifecycleState.active;
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  bool consumeRlnUnlockConflictNormalized() {
    final normalized = _unlockConflictNormalized;
    _unlockConflictNormalized = false;
    return normalized;
  }

  Future<int> rlnCreateNativeExternalSigner(
    String seedHex,
    String network, {
    bool permissivePolicy = true,
    String? storageDirPath,
  }) {
    return _withNodeQueue(
      'rlnCreateNativeExternalSigner',
      () => _client.createNativeExternalSigner(
        seedHex: seedHex,
        network: network,
        permissivePolicy: permissivePolicy,
        storageDirPath: storageDirPath,
      ),
    );
  }

  Future<void> rlnInitNodeWithNativeExternalSigner(int signerId) {
    return _withNodeOperation(
      'rlnInitNodeWithNativeExternalSigner',
      (nodeId) => _client.initNodeWithNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      ),
    );
  }

  Future<void> rlnAttachNativeExternalSigner(int signerId) {
    return _withNodeOperation(
      'rlnAttachNativeExternalSigner',
      (nodeId) => _client.attachNativeExternalSigner(
        nodeId: nodeId,
        signerId: signerId,
      ),
    );
  }

  Future<void> rlnUnlockNodeWithNativeExternalSigner(
    int signerId, [
    IRLNUnlockParams? params,
  ]) {
    return _withNodeQueue('rlnUnlockNodeWithNativeExternalSigner', () async {
      final resolvedParams = params ?? IRLNUnlockParams();
      final nodeId = _requireNodeId();
      _assertRegularOpsAllowed();
      _unlockConflictNormalized = false;
      if (await _probeNodeReady(nodeId)) return;
      try {
        await _client.unlockNodeWithNativeExternalSigner(
          nodeId: nodeId,
          signerId: signerId,
          bitcoindRpcUsername: resolvedParams.bitcoindRpcUsername,
          bitcoindRpcPassword: resolvedParams.bitcoindRpcPassword,
          bitcoindRpcHost: resolvedParams.bitcoindRpcHost,
          bitcoindRpcPort: resolvedParams.bitcoindRpcPort,
          indexerUrl: resolvedParams.indexerUrl,
          proxyEndpoint: resolvedParams.proxyEndpoint,
          announceAddresses: resolvedParams.announceAddresses,
          announceAlias: resolvedParams.announceAlias,
          gossipRgsServerUrl: resolvedParams.gossipRgsServerUrl,
          ethRpcUrl: resolvedParams.ethRpcUrl,
        );
      } catch (error) {
        if (!_isConflictError(error) || !await _probeNodeReady(nodeId)) {
          rethrow;
        }
        _unlockConflictNormalized = true;
      }
    });
  }

  Future<void> rlnDestroyNativeExternalSigner(int signerId) {
    return _withNodeQueue(
      'rlnDestroyNativeExternalSigner',
      () => _client.destroyNativeExternalSigner(signerId),
    );
  }

  Future<void> rlnInitNodeWithExternalSigner(
    IRLNExternalSignerBootstrap bootstrap,
  ) {
    return _withNodeOperation(
      'rlnInitNodeWithExternalSigner',
      (nodeId) => _client.initNodeWithExternalSigner(
        nodeId: nodeId,
        nodePublicKeyHex: bootstrap.nodePublicKeyHex,
        accountXpubVanilla: bootstrap.accountXpubVanilla,
        accountXpubColored: bootstrap.accountXpubColored,
        masterFingerprint: bootstrap.masterFingerprint,
        protocolVersion: bootstrap.protocolVersion,
        apiLevel: bootstrap.apiLevel,
      ),
    );
  }

  Future<RlnNodeInfo> rlnNodeInfo() async {
    return RlnNodeInfo.fromMap(
      await _withNodeInspection('rlnNodeInfo', _client.nodeInfo),
    );
  }

  Future<RlnNetworkInfo> rlnNetworkInfo() async {
    return RlnNetworkInfo.fromMap(
      await _withNodeOperation('rlnNetworkInfo', _client.networkInfo),
    );
  }
}
