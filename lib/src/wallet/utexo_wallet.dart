// Private mixin contracts are implemented across this library's part files;
// the analyzer does not count those cross-part references as direct uses.
// ignore_for_file: unused_element, unused_element_parameter

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../binding/rln_binding.dart';
import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import '../lsp/lsp_native_decoders.dart';
import '../lsp/lsp_types.dart';
import '../lsp/lsp_wallet.dart';
import '../lsp/utexo_lsp.dart';
import '../lsp/utexo_lsp_client.dart';
import '../models/burn_models.dart';
import '../models/imported_rgb_contract.dart';
import '../models/rln_models.dart';
import '../models/utexo_core_models.dart';
import '../models/utexo_domain_policy.dart';
import 'burn_operations.dart';
import 'lightning_policy.dart';
import 'network_defaults.dart';
import 'recoverable_storage.dart';
import 'rln_signers.dart';
import 'utexo_wallet_types.dart';
import 'wallet_policy.dart';

part 'utexo_wallet_lifecycle.dart';
part 'utexo_wallet_lsp_apay.dart';
part 'utexo_wallet_onchain.dart';
part 'recoverable_onchain_send.dart';
part 'utexo_wallet_lightning.dart';
part 'utexo_wallet_raw.dart';
part 'utexo_wallet_guards.dart';
part 'utexo_wallet_bfa.dart';
part 'utexo_unlock_config_resolver.dart';

String _requiredNativeString(RlnMap response, String field, String typeName) {
  final value = response[field];
  if (value is String && value.isNotEmpty) return value;
  throw NativeProtocolException(
    '$typeName.$field must be a non-empty string.',
    field: '$typeName.$field',
  );
}

bool _requiredNativeBool(RlnMap response, String field, String typeName) {
  final value = response[field];
  if (value is bool) return value;
  throw NativeProtocolException(
    '$typeName.$field must be a boolean.',
    field: '$typeName.$field',
  );
}

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
  UtexoWallet get _walletSelf;
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
  void _requireNonNegativeList(List<int> values, String field);
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

class UtexoWallet extends _UtexoWalletInternals
    with
        _UtexoWalletLifecycle,
        _UtexoWalletLspApay,
        _UtexoWalletOnchain,
        _UtexoWalletBfa,
        _UtexoWalletLightning,
        _UtexoWalletGuards
    implements ILspWallet, BurnWallet {
  static const _defaultOperationTimeouts = RlnOperationTimeoutPolicy();

  UtexoWallet({
    required UtexoWalletConfig config,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) : this._(
         config: config,
         operationTimeouts: operationTimeouts,
         signer: signer,
       );

  UtexoWallet._({
    required UtexoWalletConfig config,
    RlnClient? client,
    RLNBinding? binding,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) : _config = config,
       _signer = signer {
    final resolvedClient = client ?? binding?.client ?? RlnClient();
    if (binding != null &&
        client != null &&
        !identical(binding.client, client)) {
      WalletInputPolicy.requireCompatibleNativeOwner(
        binding: binding.client,
        client: client,
      );
    }
    _client = resolvedClient;
    _binding =
        binding ??
        RLNBinding(
          client: resolvedClient,
          operationTimeouts: operationTimeouts ?? _defaultOperationTimeouts,
        );
  }

  @override
  UtexoWallet get _walletSelf => this;

  @override
  final UtexoWalletConfig _config;

  /// Canonical native network used by decoded RGB and Lightning invoices.
  @override
  String get network => normalizeNativeRlnNetwork(_config.network);
  @override
  late final RlnClient _client;
  @override
  late final RLNBinding _binding;
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

/// Creates a wallet with injectable bridge dependencies for advanced
/// integrations and tests.
///
/// This factory is exported only by `rgb_sdk_flutter_advanced.dart`. Stable
/// app code should use [UtexoWallet.new] or the stable package factory.
UtexoWallet createAdvancedUtexoWallet({
  required UtexoWalletConfig config,
  RlnClient? client,
  RLNBinding? binding,
  RlnOperationTimeoutPolicy? operationTimeouts,
  RlnSigner? signer,
}) {
  return UtexoWallet._(
    config: config,
    client: client,
    binding: binding,
    operationTimeouts: operationTimeouts,
    signer: signer,
  );
}
