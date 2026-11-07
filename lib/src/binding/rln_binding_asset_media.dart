part of 'rln_binding.dart';

mixin _RlnBindingAssetMedia on _RlnBindingInternals {
  Future<RlnMap> rlnAssetMetadata(String assetId) => _withNodeOperation(
    'rlnAssetMetadata',
    (nodeId) => _client.assetMetadata(nodeId: nodeId, assetId: assetId),
  );

  Future<RlnAssetCfa> rlnIssueAssetCfaWithMedia({
    required String name,
    required int precision,
    required List<int> amounts,
    required int mediaLimit,
    String? details,
    String? filePath,
  }) {
    final ownedAmounts = List<int>.unmodifiable(amounts);
    return _withNodeOperation('rlnIssueAssetCfa', (nodeId) async {
      final digest = filePath == null
          ? null
          : await _uploadAssetMedia(nodeId, filePath, mediaLimit);
      _assertRegularOpsAllowed();
      final result = await _client.issueAssetCfa(
        nodeId: nodeId,
        name: name,
        details: details,
        precision: precision,
        amounts: ownedAmounts,
        fileDigest: digest,
      );
      if (result is! RlnMap) {
        throw const NativeProtocolException('Invalid CFA issuance response.');
      }
      return RlnAssetCfa.fromMap(result);
    });
  }

  Future<RlnAssetUda> rlnIssueAssetUdaWithMedia({
    required String ticker,
    required String name,
    required int precision,
    required int mediaLimit,
    String? details,
    String? mediaFilePath,
    List<String> attachmentsFilePaths = const [],
  }) {
    final ownedPaths = List<String>.unmodifiable(attachmentsFilePaths);
    return _withNodeOperation('rlnIssueAssetUda', (nodeId) async {
      final mediaDigest = mediaFilePath == null
          ? null
          : await _uploadAssetMedia(nodeId, mediaFilePath, mediaLimit);
      final attachments = [
        for (final path in ownedPaths)
          await _uploadAssetMedia(nodeId, path, mediaLimit),
      ];
      _assertRegularOpsAllowed();
      final result = await _client.issueAssetUda(
        nodeId: nodeId,
        ticker: ticker,
        name: name,
        details: details,
        precision: precision,
        mediaFileDigest: mediaDigest,
        attachmentsFileDigests: attachments,
      );
      if (result is! RlnMap) {
        throw const NativeProtocolException('Invalid UDA issuance response.');
      }
      return RlnAssetUda.fromMap(result);
    });
  }

  Future<String> _uploadAssetMedia(int nodeId, String path, int limit) async {
    _assertRegularOpsAllowed();
    final file = File(path);
    Uint8List bytes;
    try {
      final info = await file.stat();
      if (info.type != FileSystemEntityType.file ||
          info.size < 1 ||
          info.size > limit) {
        throw const WalletValidationException(
          'Asset media must be a nonempty file within the size limit.',
          field: 'media',
        );
      }
      final handle = await file.open();
      try {
        bytes = await handle.read(limit + 1);
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      throw const WalletValidationException(
        'Could not read the asset media file.',
        field: 'media',
      );
    }
    if (bytes.isEmpty || bytes.length > limit) {
      throw const WalletValidationException(
        'Asset media must be a nonempty file within the size limit.',
        field: 'media',
      );
    }
    _assertRegularOpsAllowed();
    final response = await _client.postAssetMedia(nodeId: nodeId, bytes: bytes);
    final digest = response['digest'];
    if (digest is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw const NativeProtocolException('Invalid asset media digest.');
    }
    return digest;
  }
}
