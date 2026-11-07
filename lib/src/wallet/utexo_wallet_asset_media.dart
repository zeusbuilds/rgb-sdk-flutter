part of 'utexo_wallet.dart';

mixin _UtexoWalletAssetMedia on _UtexoWalletInternals {
  /// Returns on-chain asset metadata with exact supply values.
  Future<RgbLibAssetMetadata> getAssetMetadata(String assetId) async {
    validateBurnAssetId(assetId);
    _requireUnlockedNode();
    final result = await _binding.rlnAssetMetadata(assetId);
    return RgbLibWire(result, 'assetMetadata').metadata;
  }

  /// Issues a collectible fungible asset, optionally attaching local media.
  Future<CoreAssetCfa> issueAssetCfa({
    required String name,
    required int precision,
    required List<int> amounts,
    String? details,
    String? filePath,
  }) async {
    _requireNonEmpty(name, 'name');
    WalletInputPolicy.requireAssetPrecision(precision);
    if (amounts.isEmpty) {
      throw const WalletValidationException(
        'Issuance requires allocations.',
        field: 'amounts',
      );
    }
    WalletInputPolicy.requireAssetSupply(amounts);
    _ensureRgbAssetIssuanceSupported('issueAssetCfa');
    _requireUnlockedNode();
    return (await _binding.rlnIssueAssetCfaWithMedia(
      name: name,
      details: details,
      precision: precision,
      amounts: amounts,
      filePath: filePath == null ? null : rgbLibLocalFile(filePath),
      mediaLimit: _mediaLimit,
    )).toCore();
  }

  /// Issues a unique digital asset, with optional local media and attachments.
  Future<CoreAssetUda> issueAssetUda({
    required String ticker,
    required String name,
    required int precision,
    String? details,
    String? mediaFilePath,
    List<String> attachmentsFilePaths = const [],
  }) async {
    _requireNonEmpty(ticker, 'ticker');
    _requireNonEmpty(name, 'name');
    WalletInputPolicy.requireAssetPrecision(precision);
    if (attachmentsFilePaths.length > 255) {
      throw const WalletValidationException(
        'Too many media attachments.',
        field: 'attachmentsFilePaths',
      );
    }
    _ensureRgbAssetIssuanceSupported('issueAssetUda');
    _requireUnlockedNode();
    return (await _binding.rlnIssueAssetUdaWithMedia(
      ticker: ticker,
      name: name,
      details: details,
      precision: precision,
      mediaFilePath: mediaFilePath == null
          ? null
          : rgbLibLocalFile(mediaFilePath),
      attachmentsFilePaths: attachmentsFilePaths.map(rgbLibLocalFile).toList(),
      mediaLimit: _mediaLimit,
    )).toCore();
  }

  int get _mediaLimit => _config.maxMediaUploadSizeMb.clamp(0, 20) * 1048576;
}
