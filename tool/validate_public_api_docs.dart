import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'api_export_graph.dart';

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
  'createAdvancedRlnWallet',
  'createAdvancedUtexoWallet',
  'RlnWalletRawApi',
  'UtexoWalletRawApi',
  'RlnRecoverableCodec',
  'RgbLibRecoverableCodec',
  'RgbLibFacadeAdapter',
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
    r'RecoverableOnchainSendPhase\s*,\s*RecoverableOnchainSendStatus\s*,\s*'
    r'UtexoWalletEngineAccess\s*;',
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
    'lib/src/wallet/rln_wallet.dart',
    'lib/src/wallet/rln_wallet_backend.dart',
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
  errors.addAll(walletFacadeArchitectureErrors(walletSource));
  for (final required in [
    "export 'src/wallet/rln_wallet.dart' show RlnWallet;",
    "export 'src/wallet/wallet_engine.dart' show WalletEngine;",
  ]) {
    if (!root.contains(required)) {
      errors.add(
        'Stable entrypoint must expose reviewed engine contract: $required',
      );
    }
  }
  for (final path in ['rln_wallet.dart', 'rgb_lib/rgb_lib_wallet.dart']) {
    final source = File('lib/src/wallet/$path').readAsStringSync();
    final unit = parseString(content: source).unit;
    if (unit.directives.whereType<UriBasedDirective>().any(
      (directive) =>
          directive.uri.stringValue?.endsWith('/utexo_wallet.dart') == true ||
          directive.uri.stringValue == 'utexo_wallet.dart',
    )) {
      errors.add('Engine $path must not depend on the wallet facade library.');
    }
  }

  for (final (path, extensionName, onType) in [
    ('utexo_wallet_raw.dart', 'RlnWalletRawApi', 'RlnWallet'),
    ('utexo_wallet_raw_compatibility.dart', 'UtexoWalletRawApi', 'UtexoWallet'),
  ]) {
    final rawSource = File('lib/src/wallet/$path').readAsStringSync();
    if (!rawSource.contains('extension $extensionName on $onType')) {
      errors.add('Missing advanced-only $extensionName extension.');
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
        errors.add('Advanced $extensionName is missing `$required`.');
      }
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

/// Guards the composition boundary without relying on a constructor regex.
List<String> walletFacadeArchitectureErrors(String source) {
  final errors = <String>[];
  final unit = parseString(content: source).unit;
  final classes = unit.declarations.whereType<ClassDeclaration>();
  final facade = classes
      .where((node) => node.namePart.typeName.lexeme == 'UtexoWallet')
      .singleOrNull;
  if (facade == null || facade.body is! BlockClassBody) {
    return ['Missing concrete UtexoWallet facade.'];
  }
  if (facade.extendsClause != null || facade.withClause != null) {
    errors.add(
      'UtexoWallet must use composition without engine inheritance or mixins.',
    );
  }
  final members = (facade.body as BlockClassBody).members;
  final fields = members.whereType<FieldDeclaration>().toList();
  final names = fields
      .expand((field) => field.fields.variables.map((v) => v.name.lexeme))
      .toSet();
  if (names.length != 2 ||
      !names.containsAll({'engine', '_rgbApi'}) ||
      fields.any((field) => !field.fields.isFinal)) {
    errors.add(
      'UtexoWallet may own only the immutable engine and stateless typed adapter.',
    );
  }
  final constructor = members
      .whereType<ConstructorDeclaration>()
      .where((node) => node.name == null)
      .singleOrNull;
  if (constructor == null || constructor.factoryKeyword == null) {
    errors.add('UtexoWallet must use the reviewed engine-selecting factory.');
  } else {
    final actual = <String, String>{};
    for (final raw in constructor.parameters.parameters) {
      final parameter = raw is DefaultFormalParameter ? raw.parameter : raw;
      if (parameter is SimpleFormalParameter) {
        actual[parameter.name!.lexeme] =
            parameter.type?.toSource() ?? 'dynamic';
      }
    }
    const expected = {
      'engine': 'WalletEngine?',
      'params': 'RgbLibWalletParams?',
      'keys': 'RgbLibKeys?',
      'online': 'RgbLibUnlockParams?',
    };
    if (actual.length != expected.length ||
        expected.entries.any((e) => actual[e.key] != e.value)) {
      errors.add(
        'Default UtexoWallet parameters must select an engine or typed RGB_L1 configuration.',
      );
    }
  }
  final selection = unit.declarations
      .whereType<FunctionDeclaration>()
      .where((node) => node.name.lexeme == '_selectEngine')
      .singleOrNull;
  final selectionBody = selection?.functionExpression.body.toSource() ?? '';
  if (!selectionBody.contains('return RgbLibWallet(') ||
      selectionBody.contains('RlnWallet(')) {
    errors.add(
      'Default wallet selection must create RGB_L1 and never implicitly create RLN.',
    );
  }
  return errors;
}

Set<String> _exportedPublicSymbols() {
  final graph = collectDartExportGraph(
    entrypoints: [_barrelPath],
    readSource: (path) => File(path).readAsStringSync(),
  );
  return {
    for (final entry in graph.entries)
      ...publicSymbolsIn(
        File(entry.key).readAsStringSync(),
      ).where(entry.value.allows),
  };
}

/// Enumerates declarations that require public API documentation.
Set<String> publicSymbolsIn(String source) {
  final declarations = <String>{};
  final declarationPattern = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|final\s+class|class|enum|extension|typedef)\s+'
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
