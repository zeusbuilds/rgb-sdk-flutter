// Private mixin contracts are implemented across this library's part files.
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
import 'onchain_recovery.dart';
import 'recoverable_storage.dart';
import 'rgb_lib/config.dart' show rgbLibLocalFile;
import 'rgb_lib/wire.dart' show RgbLibAssetMetadata, RgbLibWire;
import 'rln_signers.dart';
import 'utexo_wallet_types.dart';
import 'wallet_engine.dart';
import 'wallet_policy.dart';

part 'rln_wallet_backend.dart';
part 'utexo_wallet_lifecycle.dart';
part 'utexo_wallet_lsp_apay.dart';
part 'utexo_wallet_onchain.dart';
part 'utexo_wallet_asset_media.dart';
part 'utexo_wallet_lightning.dart';
part 'utexo_wallet_raw.dart';
part 'utexo_wallet_guards.dart';
part 'utexo_wallet_bfa.dart';
part 'utexo_unlock_config_resolver.dart';

/// Independent RGB Lightning Node engine with its own session and lifecycle.
///
/// Creating an engine does not initialize native storage or connect to a
/// network. Its config and signer belong to this engine for its entire lifetime.
class RlnWallet extends _RlnWalletBackend implements WalletEngine {
  RlnWallet({required super.config, super.operationTimeouts, super.signer});

  RlnWallet._({
    required super.config,
    super.client,
    super.binding,
    super.operationTimeouts,
    super.signer,
  });

  @override
  RlnWallet get _walletSelf => this;

  @override
  String get protocol => 'RGB_LN';

  @override
  String get contractVersion => '1';
}

/// Creates an RLN engine with injectable native bridge dependencies.
///
/// This factory is exported only by the advanced entrypoint. Stable callers
/// construct [RlnWallet] and may pass it to the wallet facade explicitly.
RlnWallet createAdvancedRlnWallet({
  required RlnWalletConfig config,
  RlnClient? client,
  RLNBinding? binding,
  RlnOperationTimeoutPolicy? operationTimeouts,
  RlnSigner? signer,
}) => RlnWallet._(
  config: config,
  client: client,
  binding: binding,
  operationTimeouts: operationTimeouts,
  signer: signer,
);

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
