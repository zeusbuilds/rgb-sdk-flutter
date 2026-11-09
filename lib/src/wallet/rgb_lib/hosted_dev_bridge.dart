part of 'rgb_lib_wallet.dart';

/// Internal method-channel operations for the exact hosted Dev WebRGB router.
enum RgbLibHostedBridgeOperation {
  blindReceive('bridgeBlindReceive'),
  prepareBurn('prepareBridgeBurn'),
  commitBurn('commitBridgeBurn'),
  observeBurn('observeBridgeBurn'),
  cancelBurn('cancelBridgeBurn'),
  burnProof('bridgeBurnProof');

  const RgbLibHostedBridgeOperation(this.wireName);
  final String wireName;
}

/// Internal glue kept out of the public SDK barrel.
extension RgbLibHostedBridgeOperations on RgbLibWallet {
  Future<Map<String, Object?>?> hostedDevBridgeNative(
    RgbLibHostedBridgeOperation operation,
    Map<String, Object?> request, {
    required void Function() assertAuthorized,
    bool recoveryOnly = false,
  }) {
    final encoded = jsonEncode(request);
    if (encoded.length > 8192) invalidRgbLibConfig('Invalid bridge request.');
    return _accept(() async {
      _requireIdentity();
      _requireHostedDevBridge(this);
      assertAuthorized();
      final response = await _invoke(operation.wireName, {
        'handle': _handle!,
        'requestJson': encoded,
        if (operation == RgbLibHostedBridgeOperation.blindReceive ||
            operation == RgbLibHostedBridgeOperation.observeBurn)
          'recoveryOnly': recoveryOnly,
      });
      assertAuthorized();
      final limit = operation == RgbLibHostedBridgeOperation.burnProof
          ? 4 * ((16 * 1024 * 1024 + 2) ~/ 3) + 8192
          : 16384;
      if (response is! String || response.length > limit) {
        invalidRgbLibWire('hostedDevBridge');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response);
      } on FormatException {
        invalidRgbLibWire('hostedDevBridge');
      }
      if (decoded == null || decoded is Map<String, Object?>) {
        return decoded as Map<String, Object?>?;
      }
      invalidRgbLibWire('hostedDevBridge');
    });
  }
}

Future<bool> _hostedDevBridgeBlindReceiveReady(RgbLibWallet wallet) async {
  if (!wallet.supportsHostedDevBridge) return false;
  final outputs = await wallet.listUnspents();
  final candidateTxids = outputs
      .where(
        (output) =>
            output.utxo.exists &&
            output.utxo.colorable &&
            output.rgbAllocations.isEmpty &&
            output.pendingBlinded == 0,
      )
      .map((output) => output.utxo.outpoint.txid)
      .toSet();
  if (candidateTxids.isEmpty || !wallet.supportsHostedDevBridge) return false;
  final transactions = await wallet.listTransactions(skipSync: true);
  return wallet.supportsHostedDevBridge &&
      transactions.any(
        (tx) => candidateTxids.contains(tx.txid) && tx.confirmationTime != null,
      );
}

void _requireHostedDevBridge(RgbLibWallet wallet) {
  if (!wallet.supportsHostedDevBridge) {
    throw const RgbLibWalletException(
      'Durable hosted Dev bridge operations are unavailable.',
      code: 'UNSUPPORTED_CAPABILITY',
    );
  }
}
