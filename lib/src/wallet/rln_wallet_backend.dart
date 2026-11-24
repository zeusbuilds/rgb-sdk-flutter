// Private mixin contracts are consumed across this library's part files.
// ignore_for_file: unused_element, unused_element_parameter

part of 'rln_wallet.dart';

enum _WalletLifecycleState {
  uninitialized,
  initializing,
  initialized,
  unlocking,
  unlocked,
  shutDown,
  destroying,
  disposed,
}

abstract class _UtexoWalletInternals {
  ILspWallet get _walletSelf;
  UtexoWalletConfig get _config;
  RlnClient get _client;
  RLNBinding get _binding;
  RlnSigner? get _signer;
  set _signer(RlnSigner? value);
  int? get _nodeId;
  set _nodeId(int? value);
  bool get _nodeCreated;
  set _nodeCreated(bool value);
  _WalletLifecycleState get _lifecycleState;
  set _lifecycleState(_WalletLifecycleState value);
  bool get _cleanupRequired;
  set _cleanupRequired(bool value);
  Future<void>? get _initInFlight;
  set _initInFlight(Future<void>? value);
  Future<void>? get _unlockInFlight;
  set _unlockInFlight(Future<void>? value);
  Future<void> get _lifecycleQueue;
  set _lifecycleQueue(Future<void> value);
  bool? get _resolvedEnableVirtualChannelsV0;
  set _resolvedEnableVirtualChannelsV0(bool? value);
  List<String>? get _resolvedVirtualPeerPubkeys;
  set _resolvedVirtualPeerPubkeys(List<String>? value);
  String? get _resolvedLspBaseUrl;
  set _resolvedLspBaseUrl(String? value);
  bool get _passwordSignerPasswordConsumed;
  set _passwordSignerPasswordConsumed(bool value);

  bool get isInitialized;
  bool get isUnlocked;
  WalletCapabilities get capabilities;
  PsbtWalletCarrier? get psbt;
  BeginEndWalletCarrier? get beginEnd;

  RlnSigner _ensureSigner({String? password, String? mnemonic});
  void _validateSignerCanUnlock({String? password});
  void _markPasswordSignerConsumed(RlnSigner signer);
  Future<int> _createNode();
  String? _resolvedNodeLspBaseUrl();
  UtexoUnlockConfig _resolveUnlockConfig(UtexoUnlockConfig config);
  Future<RlnInvoice> _rgbInvoice(
    RgbInvoiceRequest request, {
    required bool witness,
  });
  RlnMap _asRlnMap(Object? value);
  int _requireNode();
  int _requireUnlockedNode();
  void _ensureInitialized();
  void _ensureActive();
  void _assertLightningEnabled();
  void _ensureNotDisposed();
  Future<T> _withLifecycle<T>(Future<T> Function() operation);
  void _requireNonEmpty(String value, String field);
  void _validateConfig();
  void _requirePositive(int value, String field);
  void _requireNonNegative(int value, String field);
  void _requireNonNegativeOptional(int? value, String field);
  void _requireUInt8(int value, String field);
  void _requireUInt8Optional(int? value, String field);
  void _requireUInt16(int value, String field);
  void _requireUInt16Optional(int? value, String field);
  void _requireUInt32(int value, String field);
  void _requireUInt32Optional(int? value, String field);
  void _requireFeeRate(double value, String field);
  void _ensureRgbUtxoCreationSupported();
  void _ensureRgbAssetIssuanceSupported(String operation);
  void _requireSupportedRgbSendSkipSync(bool skipSync);
  Future<RlnSendResult> _sendRgb(RgbSendRequest request);
  void _ensureVirtualChannelsMutable();
  void _enableVirtualChannelsForPeer(String peerPubkey);
}

abstract class _RlnWalletBackend extends _UtexoWalletInternals
    with
        _UtexoWalletLifecycle,
        _UtexoWalletLspApay,
        _UtexoWalletOnchain,
        _UtexoWalletAssetMedia,
        _UtexoWalletBfa,
        _UtexoWalletLightning,
        _UtexoWalletGuards
    implements ILspWallet, BurnCapabilityWallet {
  static const _defaultOperationTimeouts = RlnOperationTimeoutPolicy();

  _RlnWalletBackend({
    required RlnWalletConfig config,
    RlnClient? client,
    RLNBinding? binding,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) : _signer = signer {
    final resolvedClient = client ?? binding?.client ?? RlnClient();
    if (binding != null &&
        client != null &&
        !identical(binding.client, client)) {
      WalletInputPolicy.requireCompatibleNativeOwner(
        binding: binding.client,
        client: client,
      );
    }
    _rln = (
      config: config,
      client: resolvedClient,
      binding:
          binding ??
          RLNBinding(
            client: resolvedClient,
            operationTimeouts: operationTimeouts ?? _defaultOperationTimeouts,
          ),
    );
  }

  late final ({UtexoWalletConfig config, RlnClient client, RLNBinding binding})
  _rln;

  @override
  UtexoWalletConfig get _config => _rln.config;

  /// Canonical native network used by decoded RGB and Lightning invoices.
  @override
  String get network => normalizeNativeRlnNetwork(_config.network);
  @override
  RlnClient get _client => _rln.client;
  @override
  RLNBinding get _binding => _rln.binding;
  @override
  RlnSigner? _signer;

  @override
  int? _nodeId;
  @override
  bool _nodeCreated = false;
  @override
  _WalletLifecycleState _lifecycleState = _WalletLifecycleState.uninitialized;
  @override
  bool _cleanupRequired = false;
  @override
  Future<void>? _initInFlight;
  @override
  Future<void>? _unlockInFlight;
  @override
  Future<void> _lifecycleQueue = Future<void>.value();
  @override
  bool? _resolvedEnableVirtualChannelsV0;
  @override
  List<String>? _resolvedVirtualPeerPubkeys;
  @override
  String? _resolvedLspBaseUrl;
  @override
  bool _passwordSignerPasswordConsumed = false;
  @override
  PsbtWalletCarrier? get psbt => null;
  @override
  BeginEndWalletCarrier? get beginEnd => null;

  int get nodeId => _requireNode();

  @override
  bool get isInitialized =>
      !_cleanupRequired &&
      (_lifecycleState == _WalletLifecycleState.initialized ||
          _lifecycleState == _WalletLifecycleState.unlocking ||
          _lifecycleState == _WalletLifecycleState.unlocked);
  @override
  bool get isUnlocked => _lifecycleState == _WalletLifecycleState.unlocked;
  bool get isShutdown => _lifecycleState == _WalletLifecycleState.shutDown;
  bool isDisposed() => _lifecycleState == _WalletLifecycleState.disposed;
  @override
  WalletCapabilities get capabilities {
    final supportsExternalSignerRgbAssetFlows =
        _signer is! NativeExternalRlnSigner;
    return WalletCapabilities(
      psbtSigning: psbt != null,
      beginEndFlows: beginEnd != null,
      rgbUtxoCreation: supportsExternalSignerRgbAssetFlows,
      rgbAssetIssuance: supportsExternalSignerRgbAssetFlows,
    );
  }

  String getNetwork() {
    _ensureActive();
    return _config.network;
  }
}
