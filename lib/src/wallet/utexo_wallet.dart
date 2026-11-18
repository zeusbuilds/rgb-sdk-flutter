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
import 'dev_signet_policy.dart';
import 'lightning_policy.dart';
import 'network_defaults.dart';
import 'recoverable_storage.dart';
import 'rgb_lib/config.dart' show rgbLibLocalFile;
import 'rgb_lib/rgb_lib_wallet.dart';
import 'rgb_lib/wire.dart'
    show
        RgbLibAssetMetadata,
        RgbLibAssetSchema,
        RgbLibReceivedMint,
        RgbLibReceiveAssignment,
        RgbLibReceiveData,
        RgbLibWire;
import 'rln_signers.dart';
import 'utexo_wallet_types.dart';
import 'wallet_policy.dart';

part 'rln_wallet_backend.dart';
part 'rgb_lib/utexo_wallet_adapter.dart';
part 'utexo_wallet_lifecycle.dart';
part 'utexo_wallet_lsp_apay.dart';
part 'utexo_wallet_onchain.dart';
part 'utexo_wallet_asset_media.dart';
part 'recoverable_onchain_send.dart';
part 'rgb_lib_recoverable_codec.dart';
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

/// A wallet bound to a single native engine for its entire lifetime.
///
/// The original constructor selects the RLN engine. Use [UtexoWallet.rgbLib]
/// to select a configured rgb-lib engine, including its own storage and keys.
class UtexoWallet extends _RlnWalletBackend
    implements ILspWallet, BurnCapabilityWallet {
  UtexoWallet({
    required UtexoWalletConfig config,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) : this._(
         config: config,
         operationTimeouts: operationTimeouts,
         signer: signer,
       );

  /// Explicitly selects the legacy RGB Lightning Node engine.
  UtexoWallet.rln({
    required UtexoWalletConfig config,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) : this._(
         config: config,
         operationTimeouts: operationTimeouts,
         signer: signer,
       );

  /// Wraps one configured on-chain RGB_L1 engine without opening it.
  ///
  /// The facade and [engine] share a session and lifecycle. Use the engine's
  /// typed API for RGB_L1 network configuration and capabilities.
  factory UtexoWallet.rgbLib({required RgbLibWallet engine}) =>
      _RgbLibWalletFacade(engine);

  UtexoWallet._({
    required super.config,
    super.client,
    super.binding,
    super.operationTimeouts,
    super.signer,
  });

  UtexoWallet._withoutRln() : super.withoutRln();

  @override
  UtexoWallet get _walletSelf => this;
}

/// Engine selection and RGB_L1 capabilities on a [UtexoWallet].
///
/// An extension keeps existing implementations of the wallet interface source
/// compatible. Each accessor refers to the selected session only.
extension UtexoWalletEngineAccess on UtexoWallet {
  /// The selected native protocol (`RGB_L1` or `RGB_LN`).
  String get protocol => rgbLibEngine?.protocol ?? 'RGB_LN';

  /// The selected on-chain engine, or null for an RLN wallet.
  RgbLibWallet? get rgbLibEngine => switch (this) {
    _RgbLibWalletFacade(:final _rgbLibEngine) => _rgbLibEngine,
    _ => null,
  };

  /// Inspects native mint lock requirements for a receive recipient.
  /// A null result means no observation exists. Use only with RGB_L1.
  Future<RgbLibReceivedMint?> getReceivedMint(String recipientId) async {
    final engine = rgbLibEngine;
    if (engine == null) {
      throw const UnsupportedWalletFeatureException(
        'getReceivedMint requires an RGB_L1 wallet.',
        feature: 'getReceivedMint',
      );
    }
    return engine.getReceivedMint(recipientId);
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
