part of 'rln_wallet.dart';

mixin _UtexoWalletBfa on _UtexoWalletInternals {
  /// Imports a public RGB contract, verifying its exact expected identity.
  ///
  /// Import records metadata only; it never credits a spendable balance. Obtain
  /// bytes from a trusted network-specific asset definition, and independently
  /// check its published hash and returned schema/name/ticker/precision.
  Future<ImportedRgbContract> importRgbContract({
    required String contractBase64,
    required String expectedAssetId,
  }) {
    validateRgbContractImport(contractBase64, expectedAssetId);
    _requireUnlockedNode();
    return _binding.rlnImportRgbContract(
      contractBase64: contractBase64,
      expectedAssetId: expectedAssetId,
    );
  }

  /// Native-build support intersected with the configured signer capability.
  Future<BfaCapabilities> getBfaCapabilities() async {
    _ensureActive();
    final native = await _binding.rlnBfaCapabilities();
    _ensureActive();
    return BfaCapabilities(
      burn: native.burn && (_signer?.supportsBurn ?? false),
      consignment: native.consignment,
      bfa: native.bfa,
    );
  }

  /// Irreversible one-attempt burn. Use BurnOperations for durable journaling.
  ///
  /// A timeout or transport error may occur after native dispatch. Never retry
  /// automatically: reconcile the saved operation against an independent proof.
  Future<BurnResult> burn(BurnParams params) async {
    params.validate();
    _requireUnlockedNode();
    if (!(await getBfaCapabilities()).burn) {
      throw const UnsupportedWalletFeatureException(
        'Burn is unsupported by this native build or signer.',
        feature: 'burn',
      );
    }
    // Lifecycle may have changed while the capability query was in flight.
    _requireUnlockedNode();
    return _binding.rlnBurn(params);
  }

  /// Standard Base64 of already-saved consignment bytes, never regeneration.
  Future<String> getConsignment(String assetId, String txid) {
    validateConsignmentLookup(assetId, txid);
    _requireUnlockedNode();
    return _binding.rlnGetConsignment(assetId, txid);
  }

  /// Local sandbox path for wallet-owned use. Never expose this to a dApp.
  Future<String> getConsignmentPath(String assetId, String txid) {
    validateConsignmentLookup(assetId, txid);
    _requireUnlockedNode();
    return _binding.rlnGetConsignmentPath(assetId, txid);
  }
}
