import 'dart:io';

const _barrelPath = 'lib/rgb_sdk_flutter.dart';
const _docPath = 'doc/PUBLIC_API_REFERENCE.md';
const _forbiddenStableRootSymbols = <String>{
  'IRLNExternalSignerBootstrap',
  'IRLNNodeCreateParams',
  'IRLNUnlockParams',
  'Logger',
  'NativeBridgeFailure',
  'RLNBinding',
  'RLNManager',
  'RlnAddress',
  'RlnAsset',
  'RlnAssetBalance',
  'RlnAssetCfa',
  'RlnAssetIfa',
  'RlnAssetNia',
  'RlnAssetUda',
  'RlnAssets',
  'RlnBtcBalance',
  'RlnChannel',
  'RlnClient',
  'RlnDecodedLnInvoice',
  'RlnDecodedRgbInvoice',
  'RlnFeeRate',
  'RlnInvoice',
  'RlnLnInvoice',
  'RlnMap',
  'RlnNetworkInfo',
  'RlnNodeInfo',
  'RlnOpenChannelRequest',
  'RlnOpenChannelResult',
  'RlnPayment',
  'RlnPaymentResult',
  'RlnPeer',
  'RlnSendResult',
  'RlnSignMessageResult',
  'RlnTransaction',
  'RlnTransfer',
  'RlnUnspent',
  'RlnUtxo',
  'RlnVerifyMessageResult',
  'configureLogging',
  'createRLNManager',
  'logger',
  'mapNativeBridgeException',
};

void main() {
  final errors = <String>[];
  final docFile = File(_docPath);
  if (!docFile.existsSync()) {
    errors.add('Missing $_docPath.');
  }
  final doc = docFile.existsSync() ? docFile.readAsStringSync() : '';

  for (final section in <String>[
    '## Stability Tiers',
    '## Lifecycle Prerequisites',
    '## Units',
    '## Error Taxonomy',
    '## Side Effects',
    '## Secret Handling',
    '## Platform Support',
    '## Unsupported or Native-Blocked Behavior',
    '## Symbol Coverage Checklist',
  ]) {
    if (!doc.contains(section)) {
      errors.add('$_docPath is missing required section $section.');
    }
  }

  final exportedSymbols = _exportedPublicSymbols();
  final forbidden = exportedSymbols.intersection(_forbiddenStableRootSymbols);
  if (forbidden.isNotEmpty) {
    errors.add(
      'Stable root barrel exports advanced/internal symbols: '
      '${(forbidden.toList()..sort()).join(', ')}.',
    );
  }

  for (final symbol in exportedSymbols) {
    if (!RegExp('`${RegExp.escape(symbol)}`').hasMatch(doc)) {
      errors.add('$_docPath does not document exported symbol `$symbol`.');
    }
  }

  if (doc.contains('## Symbol Coverage Checklist')) {
    final documented = checklistSymbols(doc);
    final stale = documented.difference(exportedSymbols).toList()..sort();
    if (stale.isNotEmpty) {
      errors.add(
        '$_docPath checklist contains stale non-exported symbols: '
        '${stale.join(', ')}.',
      );
    }
  }

  _validateStableWalletBoundary(errors);

  if (errors.isNotEmpty) {
    stderr.writeln('Public API documentation validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  stdout.writeln(
    'Public API documentation valid: ${exportedSymbols.length} symbols.',
  );
}

/// Only list entries in the checklist section name exported top-level symbols.
/// Following prose may discuss public members (such as `reinit`), which must
/// not be mistaken for stale top-level exports by this documentation gate.
Set<String> checklistSymbols(String document) {
  const header = '## Symbol Coverage Checklist';
  final start = document.indexOf(header);
  if (start < 0) return {};
  final tail = document.substring(start + header.length);
  final nextSection = RegExp(r'^#{1,2}\s', multiLine: true).firstMatch(tail);
  final section = nextSection == null
      ? tail
      : tail.substring(0, nextSection.start);
  return {
    for (final line in section.split('\n'))
      if (line.trimLeft().startsWith('- '))
        for (final match in RegExp(r'`([^`]+)`').allMatches(line))
          if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(match.group(1)!))
            match.group(1)!,
  };
}

void _validateStableWalletBoundary(List<String> errors) {
  final root = File(_barrelPath).readAsStringSync();
  if (!RegExp(
    r"export 'src/wallet/utexo_wallet\.dart'\s+show\s+"
    r'UtexoWallet\s*,\s*resolveUnlockParams\s*,\s*'
    r'RecoverableOnchainSendCommand\s*,\s*RecoverableOnchainSendKind\s*,\s*'
    r'RecoverableOnchainSendPhase\s*,\s*RecoverableOnchainSendStatus\s*;',
  ).hasMatch(root)) {
    errors.add(
      'The stable root must export only the reviewed wallet, helper and '
      'ROOT-01 durable-send DTOs from utexo_wallet.dart.',
    );
  }

  final advanced = File('lib/rgb_sdk_flutter_advanced.dart').readAsStringSync();
  if (!advanced.contains("export 'src/wallet/utexo_wallet.dart';")) {
    errors.add(
      'The advanced entrypoint must export the complete wallet library.',
    );
  }

  const stableWalletFiles = <String>[
    'lib/src/wallet/utexo_wallet.dart',
    'lib/src/wallet/utexo_wallet_bfa.dart',
    'lib/src/wallet/utexo_wallet_lifecycle.dart',
    'lib/src/wallet/utexo_wallet_lsp_apay.dart',
    'lib/src/wallet/utexo_wallet_onchain.dart',
    'lib/src/wallet/utexo_wallet_lightning.dart',
  ];
  final stableSource = stableWalletFiles
      .map((path) => File(path).readAsStringSync())
      .join('\n');
  final methodPattern = RegExp(
    r'^\s{2}([A-Za-z][A-Za-z0-9_<>, ?]*)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*\(',
    multiLine: true,
  );
  final methods = <String, String>{};
  for (final match in methodPattern.allMatches(stableSource)) {
    final name = match.group(2)!;
    if (name.startsWith('_')) continue;
    methods[name] = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  for (final entry in methods.entries) {
    final name = entry.key;
    final returnType = entry.value;
    if (name.endsWith('Raw') ||
        name.startsWith('rln') ||
        name.startsWith('createRln') ||
        name.startsWith('payRln')) {
      errors.add('Stable UtexoWallet exposes advanced method `$name`.');
    }
    final exposesRawReturn = RegExp(
      r'^Future<(?:List<)?Rln(?!InvoiceStatusValue|PaymentStatusValue)',
    ).hasMatch(returnType);
    if (exposesRawReturn) {
      errors.add(
        'Stable UtexoWallet.$name returns raw/native type `$returnType`.',
      );
    }
  }

  const requiredReturns = <String, String>{
    'issueAssetNia': 'Future<CoreAssetNia>',
    'issueAssetIfa': 'Future<CoreAssetIfa>',
    'inflate': 'Future<InflateAssetIfaResponse>',
    'estimateFeeRate': 'Future<FeeEstimationResponse>',
    'checkIndexerUrl': 'Future<IndexerCheckResponse>',
    'getBtcBalance': 'Future<CoreBtcBalance>',
    'listAssets': 'Future<CoreListAssets>',
    'listPayments': 'Future<List<LightningPayment>>',
    'listChannels': 'Future<List<LightningChannel>>',
  };
  for (final entry in requiredReturns.entries) {
    if (methods[entry.key] != entry.value) {
      errors.add(
        'Stable UtexoWallet.${entry.key} must return ${entry.value}; found '
        '${methods[entry.key] ?? 'no declaration'}.',
      );
    }
  }

  final walletSource = File(
    'lib/src/wallet/utexo_wallet.dart',
  ).readAsStringSync();
  final constructor = RegExp(
    r'\n  UtexoWallet\(\{([\s\S]*?)\n  \}\)\s*:\s*this\._\(',
  ).firstMatch(walletSource);
  if (constructor == null) {
    errors.add('Stable UtexoWallet constructor shape could not be verified.');
  } else {
    final parameters = constructor.group(1)!;
    for (final forbidden in <String>['RlnClient', 'RLNBinding']) {
      if (parameters.contains(forbidden)) {
        errors.add(
          'Stable UtexoWallet constructor exposes advanced type `$forbidden`.',
        );
      }
    }
  }

  final rawSource = File(
    'lib/src/wallet/utexo_wallet_raw.dart',
  ).readAsStringSync();
  if (!rawSource.contains('extension UtexoWalletRawApi on UtexoWallet')) {
    errors.add('Missing advanced-only UtexoWalletRawApi extension.');
  }
  for (final required in <String>[
    'issueAssetNiaRaw',
    'issueAssetIfaRaw',
    'inflateRaw',
    'estimateFeeRateRaw',
    'checkIndexerUrlRaw',
    'createRlnLightningInvoice',
    'payRlnLightningInvoice',
  ]) {
    if (!RegExp('\\b${RegExp.escape(required)}\\s*\\(').hasMatch(rawSource)) {
      errors.add('Advanced wallet API is missing `$required`.');
    }
  }

  final coreModels = File(
    'lib/src/models/utexo_core_models.dart',
  ).readAsStringSync();
  final mapperBoundary = coreModels.indexOf('extension Rln');
  final stableModelDeclarations = mapperBoundary < 0
      ? coreModels
      : coreModels.substring(0, mapperBoundary);
  final rawModelReference = RegExp(
    r'\bRln[A-Z][A-Za-z0-9_]*\b',
  ).firstMatch(stableModelDeclarations);
  if (rawModelReference != null) {
    errors.add(
      'Stable core DTO declarations expose raw type '
      '`${rawModelReference.group(0)}`.',
    );
  }

  final walletTypes = File(
    'lib/src/wallet/utexo_wallet_types.dart',
  ).readAsStringSync();
  if (walletTypes.contains('.fromRln(') ||
      walletTypes.contains("import '../models/rln_models.dart';")) {
    errors.add(
      'Stable wallet DTOs must not expose native Rln conversion factories or '
      'import raw model declarations.',
    );
  }

  final signerSource = File(
    'lib/src/wallet/rln_signers.dart',
  ).readAsStringSync();
  final signerAdapterBoundary = signerSource.indexOf(
    'Future<void> initializeRlnSigner',
  );
  final stableSignerDeclarations = signerAdapterBoundary < 0
      ? signerSource
      : signerSource.substring(0, signerAdapterBoundary);
  if (!stableSignerDeclarations.contains(
        'abstract interface class RlnSignerHost',
      ) ||
      stableSignerDeclarations.contains('RlnClient')) {
    errors.add(
      'Stable signer declarations must use RlnSignerHost and must not expose '
      'the advanced RlnClient type.',
    );
  }

  final nativeArtifactInfo = File(
    'lib/src/native_artifact_info.dart',
  ).readAsStringSync();
  if (nativeArtifactInfo.contains('RlnNativeArtifactInfo') ||
      nativeArtifactInfo.contains("import 'pigeon/")) {
    errors.add(
      'Stable NativeArtifactInfo must not expose generated Pigeon types.',
    );
  }
}

Set<String> _exportedPublicSymbols() {
  final barrel = File(_barrelPath).readAsStringSync();
  final symbols = <String>{'RgbSdkFlutter'};

  for (final match in _exportDirectives(barrel)) {
    final file = File('lib/${match.path}');
    if (!file.existsSync()) {
      throw StateError('Exported file does not exist: ${file.path}');
    }
    final librarySymbols = <String>{};
    for (final libraryFile in _dartLibraryFiles(file)) {
      librarySymbols.addAll(_publicSymbolsIn(libraryFile.readAsStringSync()));
    }
    symbols.addAll(_filterSymbols(librarySymbols, match));
  }
  return symbols;
}

List<File> _dartLibraryFiles(File file) {
  final source = file.readAsStringSync();
  final directory = file.parent.path;
  final partPattern = RegExp(r"part '([^']+)';");
  return <File>[
    file,
    for (final match in partPattern.allMatches(source))
      File('$directory/${match.group(1)!}'),
  ];
}

Set<String> _publicSymbolsIn(String source) {
  final declarations = <String>{};
  final declarationPattern = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|class|enum|extension|typedef)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)',
    multiLine: true,
  );
  for (final match in declarationPattern.allMatches(source)) {
    final name = match.group(1)!;
    if (!name.startsWith('_')) declarations.add(name);
  }

  final functionPattern = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9_<>,?]*\s+)+([a-z][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  for (final match in functionPattern.allMatches(source)) {
    final name = match.group(1)!;
    if (!name.startsWith('_')) declarations.add(name);
  }
  return declarations;
}

List<_ExportDirective> _exportDirectives(String barrel) {
  final exportPattern = RegExp(r"export '([^']+)'([^;]*);");
  return exportPattern
      .allMatches(barrel)
      .map(
        (match) => _ExportDirective(
          match.group(1)!,
          show: _symbolsFromCombinator(match.group(2)!, 'show'),
          hide: _symbolsFromCombinator(match.group(2)!, 'hide'),
        ),
      )
      .toList(growable: false);
}

Set<String>? _symbolsFromCombinator(String source, String keyword) {
  final match = RegExp('(?:^|\\s)$keyword\\s+([^;]+)').firstMatch(source);
  if (match == null) return null;
  final raw = match.group(1)!;
  final stop = RegExp(r'\s(?:show|hide)\s').firstMatch(raw);
  final values = stop == null ? raw : raw.substring(0, stop.start);
  return values
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> _filterSymbols(Set<String> symbols, _ExportDirective directive) {
  final show = directive.show;
  final hide = directive.hide ?? const <String>{};
  return symbols
      .where((symbol) => show == null || show.contains(symbol))
      .where((symbol) => !hide.contains(symbol))
      .toSet();
}

class _ExportDirective {
  const _ExportDirective(this.path, {this.show, this.hide});

  final String path;
  final Set<String>? show;
  final Set<String>? hide;
}
