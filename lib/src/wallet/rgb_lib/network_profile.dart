/// Pure logical-to-native profile selection. It grants no deployment approval.
String rgbLibNativeNetwork(String logicalNetwork) =>
    logicalNetwork == 'utexo' ? 'signet' : logicalNetwork;

/// Explicit resolver selection keeps the Dev checkpoint out of public Signet.
String? rgbLibNativeIndexerKind(String logicalNetwork, String kind) =>
    logicalNetwork == 'utexo'
    ? switch (kind) {
        'electrum' => 'devSignetElectrum',
        'esplora' => 'devSignetEsplora',
        _ => null,
      }
    : const {'electrum', 'esplora', 'bitcoind'}.contains(kind)
    ? kind
    : null;

/// An invoice alone cannot establish the Dev chain or its selected contract.
/// The caller obtains resolver evidence only after native goOnline succeeds,
/// and registration evidence only through an actual native metadata lookup.
bool rgbLibInvoiceMatchesProfile({
  required String logicalNetwork,
  required String invoiceNetwork,
  required String? verifiedIndexerKind,
  required String? expectedAssetId,
  required String? registeredAssetId,
  required String? invoiceAssetId,
  bool invoiceAllowsAssetSelection = false,
}) {
  if (logicalNetwork != 'utexo') {
    return invoiceNetwork == logicalNetwork &&
        !const {
          'devSignetElectrum',
          'devSignetEsplora',
        }.contains(verifiedIndexerKind);
  }
  return invoiceNetwork == 'signet' &&
      const {
        'devSignetElectrum',
        'devSignetEsplora',
      }.contains(verifiedIndexerKind) &&
      expectedAssetId != null &&
      expectedAssetId.isNotEmpty &&
      registeredAssetId == expectedAssetId &&
      (invoiceAssetId == expectedAssetId ||
          (invoiceAssetId == null && invoiceAllowsAssetSelection));
}
