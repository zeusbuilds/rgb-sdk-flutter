import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../errors/rgb_sdk_exception.dart';
import '../models/burn_models.dart';
import 'dev_signet_policy.dart';
import 'network_defaults.dart' show normalizeNativeRlnNetwork;
import 'wallet_policy.dart';

part 'recoverable_onchain_send.dart';
part 'rgb_lib_recoverable_codec.dart';

/// Internal RLN wire access shared by the engine and durable command library.
///
/// This class is intentionally absent from the package's public exports. It
/// preserves the existing envelope, fingerprint and native status semantics.
abstract final class RlnRecoverableCodec {
  static RecoverableOnchainSendCommand create({
    required String network,
    required String walletBinding,
    required Map<String, Object?> request,
  }) => _validatedRecoverableCommand(
    network: network,
    walletBinding: walletBinding,
    request: request,
  );

  static RecoverableOnchainSendStatus decodeStatus(
    String json,
    RecoverableOnchainSendCommand command,
  ) => _decodeRecoverableStatus(json, command);

  static String nativeRequestJson(RecoverableOnchainSendCommand command) =>
      command._nativeRequestJson;

  static bool isRestored(RecoverableOnchainSendCommand command) =>
      command._restored;

  static Never invalid(String field) => _recoverableInvalid(field);
}
