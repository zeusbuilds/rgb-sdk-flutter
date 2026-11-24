part of 'rln_wallet.dart';

mixin _UtexoWalletLifecycle on _UtexoWalletInternals {
  Future<void> init({String? password, String? mnemonic}) {
    final inFlight = _initInFlight;
    if (inFlight != null) return inFlight;
    final future =
        _withLifecycle(() async {
          _ensureNotDisposed();
          if (isInitialized) return;
          if (_lifecycleState == _WalletLifecycleState.shutDown) {
            throw const WalletException(
              'Wallet is shut down. Call reinit() before regular use.',
            );
          }
          _validateConfig();
          _validateSignerCanUnlock(password: password);
          final hadNode = _nodeId != null;
          _lifecycleState = _WalletLifecycleState.initializing;
          try {
            _nodeId ??= await _createNode();
            _nodeCreated = true;
          } catch (error, stackTrace) {
            if (!hadNode) {
              _nodeId = null;
              _nodeCreated = false;
            }
            _lifecycleState = hadNode
                ? _WalletLifecycleState.initialized
                : _WalletLifecycleState.uninitialized;
            Error.throwWithStackTrace(error, stackTrace);
          }
          final signer = _ensureSigner(password: password, mnemonic: mnemonic);
          try {
            await _binding.runSignerOperation(
              'rlnInitSigner',
              () => initializeRlnSigner(
                signer: signer,
                client: _client,
                nodeId: _nodeId!,
                storageDirPath: _config.storageDirPath,
              ),
            );
          } catch (error, stackTrace) {
            // Failed password initialization consumes its secrets as well.
            // A retry must supply credentials before allocating another node.
            _markPasswordSignerConsumed(signer);
            if (error is RlnOperationTimeoutException) {
              _lifecycleState = _WalletLifecycleState.uninitialized;
              Error.throwWithStackTrace(error, stackTrace);
            }
            if (!hadNode &&
                _nodeId != null &&
                _signer is! NativeExternalRlnSigner) {
              try {
                await _binding.rlnDestroyNode();
                _nodeId = null;
                _nodeCreated = false;
              } catch (cleanupError) {
                _cleanupRequired = true;
                _lifecycleState = _WalletLifecycleState.uninitialized;
                Error.throwWithStackTrace(
                  WalletException(
                    'Wallet initialization and temporary node cleanup both '
                    'failed. Call destroy() before retrying.',
                    cause: <Object>[error, cleanupError],
                  ),
                  stackTrace,
                );
              }
            }
            _lifecycleState = _WalletLifecycleState.uninitialized;
            rethrow;
          }
          _lifecycleState = _WalletLifecycleState.initialized;
        }).whenComplete(() {
          _initInFlight = null;
        });
    _initInFlight = future;
    return future;
  }

  Future<void> initialize({String? password, String? mnemonic}) {
    return init(password: password, mnemonic: mnemonic);
  }

  Future<void> unlock({String? password, required UtexoUnlockConfig config}) {
    final inFlight = _unlockInFlight;
    if (inFlight != null) return inFlight;
    final future =
        _withLifecycle(() async {
          _ensureInitialized();
          if (isUnlocked) return;
          final resolvedConfig = _resolveUnlockConfig(config);
          final signer = _ensureSigner(password: password);
          _lifecycleState = _WalletLifecycleState.unlocking;
          try {
            await _binding.runSignerOperation(
              'rlnUnlockSigner',
              () => unlockRlnSigner(
                signer: signer,
                client: _client,
                nodeId: _nodeId!,
                config: resolvedConfig,
                storageDirPath: _config.storageDirPath,
              ),
            );
          } catch (error, stackTrace) {
            _lifecycleState = _WalletLifecycleState.initialized;
            Error.throwWithStackTrace(error, stackTrace);
          } finally {
            _markPasswordSignerConsumed(signer);
          }
          _lifecycleState = _WalletLifecycleState.unlocked;
        }).whenComplete(() {
          _unlockInFlight = null;
        });
    _unlockInFlight = future;
    return future;
  }

  Future<void> reinit({
    String? password,
    String? mnemonic,
    UtexoUnlockConfig? unlockConfig,
  }) {
    return _withLifecycle(() async {
      _ensureNotDisposed();
      _validateConfig();
      if (unlockConfig != null) {
        _validateSignerCanUnlock(password: password);
      }
      // Resolve all local preconditions before shutting down the active node.
      final resolvedConfig = unlockConfig == null
          ? null
          : _resolveUnlockConfig(unlockConfig);
      final previousNodeId = _nodeId;
      final hadPreviousNode = previousNodeId != null;
      final wasShutdown = _lifecycleState == _WalletLifecycleState.shutDown;
      if (hadPreviousNode && !wasShutdown) {
        try {
          await _binding.rlnShutdown();
        } catch (error, stackTrace) {
          _cleanupRequired = true;
          _lifecycleState = _WalletLifecycleState.initialized;
          Error.throwWithStackTrace(error, stackTrace);
        }
        _lifecycleState = _WalletLifecycleState.shutDown;
      }
      _lifecycleState = _WalletLifecycleState.initializing;
      late final int restartedNodeId;
      try {
        restartedNodeId = await _createNode();
      } catch (error, stackTrace) {
        _nodeId = previousNodeId;
        _nodeCreated = hadPreviousNode;
        _lifecycleState = hadPreviousNode
            ? _WalletLifecycleState.shutDown
            : _WalletLifecycleState.uninitialized;
        Error.throwWithStackTrace(error, stackTrace);
      }
      _nodeId = restartedNodeId;
      _nodeCreated = true;
      _lifecycleState = _WalletLifecycleState.initialized;
      if (resolvedConfig != null) {
        final signer = _ensureSigner(password: password, mnemonic: mnemonic);
        _lifecycleState = _WalletLifecycleState.unlocking;
        try {
          await _binding.runSignerOperation(
            'rlnUnlockSigner',
            () => unlockRlnSigner(
              signer: signer,
              client: _client,
              nodeId: _nodeId!,
              config: resolvedConfig,
              storageDirPath: _config.storageDirPath,
            ),
          );
        } catch (error, stackTrace) {
          if (error is RlnOperationTimeoutException) {
            _lifecycleState = _WalletLifecycleState.initialized;
            Error.throwWithStackTrace(error, stackTrace);
          }
          try {
            await _binding.rlnDestroyNode();
          } catch (cleanupError) {
            // Preserve the replacement owner when destruction is unresolved.
            _cleanupRequired = true;
            _lifecycleState = _WalletLifecycleState.initialized;
            Error.throwWithStackTrace(
              WalletException(
                'Wallet reinit unlock and replacement node cleanup both '
                'failed. Call destroy() before retrying.',
                cause: <Object>[error, cleanupError],
              ),
              stackTrace,
            );
          }
          _nodeId = null;
          _nodeCreated = false;
          _lifecycleState = _WalletLifecycleState.uninitialized;
          Error.throwWithStackTrace(error, stackTrace);
        } finally {
          _markPasswordSignerConsumed(signer);
        }
        _lifecycleState = _WalletLifecycleState.unlocked;
      }
    });
  }

  Future<void> shutdown() {
    return _withLifecycle(() async {
      if (_lifecycleState == _WalletLifecycleState.disposed) return;
      _ensureNotDisposed();
      final id = _nodeId;
      if (id == null ||
          _lifecycleState == _WalletLifecycleState.disposed ||
          _lifecycleState == _WalletLifecycleState.shutDown) {
        return;
      }
      _lifecycleState = _WalletLifecycleState.shutDown;
      try {
        await _binding.rlnShutdown();
      } catch (error, stackTrace) {
        _cleanupRequired = true;
        _lifecycleState = _WalletLifecycleState.initialized;
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<void> destroy() {
    return _withLifecycle(() async {
      final id = _nodeId;
      final wasShutdown = _lifecycleState == _WalletLifecycleState.shutDown;
      if (_lifecycleState == _WalletLifecycleState.disposed) return;
      _lifecycleState = _WalletLifecycleState.destroying;
      final errors = <Object>[];
      if (id != null && !wasShutdown) {
        try {
          await _binding.rlnShutdown();
        } catch (error) {
          // Native shutdown includes final persistence and worker teardown.
          // Retain both handles when its outcome is uncertain: dropping the
          // signer first can strand the writer or let another node reopen a
          // directory whose native owner is still alive. The same instance can
          // retry destroy after the underlying shutdown fault is reconciled.
          _cleanupRequired = true;
          _lifecycleState = _WalletLifecycleState.initialized;
          throw WalletException(
            'Wallet shutdown did not complete; node and signer were retained.',
            cause: List<Object>.unmodifiable(<Object>[error]),
          );
        }
      }
      var signerDisposed = true;
      if (_signer != null) {
        try {
          final signer = _signer;
          if (signer != null) {
            await _binding.runSignerOperation(
              'rlnDestroySigner',
              () =>
                  disposeRlnSigner(signer: signer, client: _client, nodeId: id),
            );
            _signer = null;
          }
        } catch (error) {
          signerDisposed = false;
          errors.add(error);
        }
      }
      var nodeDestroyed = false;
      try {
        await _binding.rlnDestroyNode();
        nodeDestroyed = true;
      } catch (error) {
        errors.add(error);
      }
      if (nodeDestroyed) {
        _nodeId = null;
        _nodeCreated = false;
      }
      if (nodeDestroyed && signerDisposed) {
        _lifecycleState = _WalletLifecycleState.disposed;
      }
      if (errors.isNotEmpty) {
        _cleanupRequired = true;
        if (!nodeDestroyed || !signerDisposed) {
          // Native shutdown succeeded above; preserve that fact for a cleanup
          // retry, even if signer revocation or handle destruction failed.
          _lifecycleState = _WalletLifecycleState.shutDown;
        }
        throw WalletException(
          'Wallet destroy did not complete cleanly.',
          cause: List<Object>.unmodifiable(errors),
        );
      }
      _nodeId = null;
      _nodeCreated = false;
      _lifecycleState = _WalletLifecycleState.disposed;
      _cleanupRequired = false;
    });
  }

  Future<void> dispose() => destroy();

  @override
  RlnSigner _ensureSigner({String? password, String? mnemonic}) {
    final signer = _signer;
    if (signer != null) {
      if (signer is PasswordRlnSigner &&
          password != null &&
          password.isNotEmpty) {
        signer.provideSecrets(password: password, mnemonic: mnemonic);
        _passwordSignerPasswordConsumed = false;
      }
      return signer;
    }
    if (password == null || password.isEmpty) {
      throw const WalletValidationException(
        'password is required when no RlnSigner is configured.',
        field: 'password',
      );
    }
    _passwordSignerPasswordConsumed = false;
    return _signer = PasswordRlnSigner(password: password, mnemonic: mnemonic);
  }

  @override
  void _validateSignerCanUnlock({String? password}) {
    if (_signer == null) {
      if (password == null || password.isEmpty) {
        throw const WalletValidationException(
          'password is required when no RlnSigner is configured.',
          field: 'password',
        );
      }
      return;
    }
    if (_signer is PasswordRlnSigner &&
        (password == null || password.isEmpty) &&
        _passwordSignerPasswordConsumed) {
      throw const WalletValidationException(
        'password is required because the previous password was consumed.',
        field: 'password',
      );
    }
  }

  @override
  void _markPasswordSignerConsumed(RlnSigner signer) {
    if (signer is PasswordRlnSigner) {
      _passwordSignerPasswordConsumed = true;
    }
  }

  @override
  Future<int> _createNode() {
    return _binding.rlnCreateNode(
      IRLNNodeCreateParams(
        storageDirPath: _config.storageDirPath,
        daemonListeningPort: _config.daemonListeningPort,
        ldkPeerListeningPort: _config.ldkPeerListeningPort,
        network: normalizeNativeRlnNetwork(_config.network),
        maxMediaUploadSizeMb: _config.maxMediaUploadSizeMb,
        enableVirtualChannelsV0:
            _resolvedEnableVirtualChannelsV0 ?? _config.enableVirtualChannelsV0,
        virtualPeerPubkeys:
            _resolvedVirtualPeerPubkeys ?? _config.virtualPeerPubkeys,
        vssUrl: _config.vssUrl,
        vssAllowHttp: _config.vssAllowHttp,
        vssAllowEmptyRestore: _config.vssAllowEmptyRestore,
        lspBaseUrl: _resolvedNodeLspBaseUrl(),
        lspBearerToken: _config.lspBearerToken,
        reuseAddresses: _config.reuseAddresses,
      ),
    );
  }

  @override
  String? _resolvedNodeLspBaseUrl() {
    final resolved = _resolvedLspBaseUrl;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final explicit = _config.lspBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return getDefaultLspBaseUrl(_config.network);
  }
}
