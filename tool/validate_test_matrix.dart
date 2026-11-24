import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import 'api_export_graph.dart';
import 'evidence_target.dart';

const _validSupport = <String>{
  'supported',
  'native-blocked',
  'unsupported-parity',
};

const _validContract = <String>{'covered', 'implemented'};

const _validPlatformStatus = <String>{
  'required',
  'expected_failure',
  'not_required',
};

const _validLspParity = <String>{'core', 'flutter-adaptation'};

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final rlnMatrix = _readMatrix(
    root,
    'tool/test_matrix/rln_methods.json',
    errors,
  );
  final walletMatrix = _readMatrix(
    root,
    'tool/test_matrix/wallet_methods.json',
    errors,
  );
  final coreMatrix = _readMatrix(
    root,
    'tool/test_matrix/core_exports.json',
    errors,
  );
  final lspMatrix = _readMatrix(
    root,
    'tool/test_matrix/lsp_methods.json',
    errors,
  );
  final lspClientMatrix = _readMatrix(
    root,
    'tool/test_matrix/lsp_client_methods.json',
    errors,
  );
  final lspContract = _readMatrix(
    root,
    'tool/core_lsp_parity_manifest.json',
    errors,
  );
  final releaseBaseline = _readMatrix(
    root,
    'tool/release_baseline.json',
    errors,
  );
  final evidenceCatalog = _readEvidenceCatalog(
    root,
    'tool/test_matrix/evidence_catalog.json',
    errors,
  );
  _validateEvidenceTargets(evidenceCatalog, errors);

  _validateMatrixShape('rln_methods.json', rlnMatrix, evidenceCatalog, errors);
  _validateMatrixShape(
    'wallet_methods.json',
    walletMatrix,
    evidenceCatalog,
    errors,
  );
  _validateMatrixShape(
    'core_exports.json',
    coreMatrix,
    evidenceCatalog,
    errors,
  );
  _validateMatrixShape('lsp_methods.json', lspMatrix, evidenceCatalog, errors);
  _validateMatrixShape(
    'lsp_client_methods.json',
    lspClientMatrix,
    evidenceCatalog,
    errors,
  );

  _validateSourceCoverage(
    name: 'RlnClient',
    className: 'RlnClient',
    sourcePath: 'lib/src/client/rln_client.dart',
    matrix: rlnMatrix,
    errors: errors,
  );
  _validateCoreExportCoverage(coreMatrix, errors);
  _validateSourceCoverage(
    name: 'UtexoWallet',
    className: 'UtexoWallet',
    sourcePath: 'lib/src/wallet/utexo_wallet.dart',
    matrix: walletMatrix,
    errors: errors,
  );
  _validateSourceCoverage(
    name: 'UtexoLsp',
    className: 'UtexoLsp',
    sourcePath: 'lib/src/lsp/utexo_lsp.dart',
    matrix: lspMatrix,
    errors: errors,
  );
  _validateSourceCoverage(
    name: 'IUtexoLspClient',
    className: 'IUtexoLspClient',
    sourcePath: 'lib/src/lsp/utexo_lsp_client.dart',
    matrix: lspClientMatrix,
    errors: errors,
  );
  _validateLspParityContract(
    lspContract: lspContract,
    releaseBaseline: releaseBaseline,
    lspMatrix: lspMatrix,
    lspClientMatrix: lspClientMatrix,
    errors: errors,
  );
  _validateCallableImplementations('wallet_methods.json', walletMatrix, errors);
  for (final (name, path) in const [
    ('RlnWallet', 'lib/src/wallet/rln_wallet.dart'),
    ('WalletEngine', 'lib/src/wallet/wallet_engine.dart'),
  ]) {
    final methods = _extractPublicClassMethods(path, name);
    for (final method in methods.difference(_methodIds(walletMatrix))) {
      errors.add(
        '$name.$method is public but has no reviewed wallet matrix row.',
      );
    }
  }
  _validateCallableImplementations('lsp_methods.json', lspMatrix, errors);
  _validateCallableImplementations(
    'lsp_client_methods.json',
    lspClientMatrix,
    errors,
  );

  if (errors.isNotEmpty) {
    stderr.writeln('Test matrix validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  final rlnCount = _methodIds(rlnMatrix).length;
  final walletCount = _methodIds(walletMatrix).length;
  final coreCount = _methodIds(coreMatrix).length;
  final lspCount = _methodIds(lspMatrix).length;
  final lspClientCount = _methodIds(lspClientMatrix).length;
  stdout.writeln(
    'Test matrix valid: '
    '$rlnCount RlnClient, $walletCount UtexoWallet, $coreCount core exports, '
    '$lspCount UtexoLsp, $lspClientCount IUtexoLspClient.',
  );
}

void _validateEvidenceTargets(
  Map<String, Object?> evidenceCatalog,
  List<String> errors,
) {
  for (final entry in evidenceCatalog.entries) {
    final bucket = entry.value;
    if (bucket is! Map<String, Object?>) continue;
    final testIds = bucket['testIds'];
    if (testIds is! List<Object?>) continue;
    for (final testId in testIds.whereType<String>()) {
      final error = evidenceTargetError(testId);
      if (error != null) errors.add('${entry.key}: $error');
    }
  }
}

void _validateLspParityContract({
  required Map<String, Object?> lspContract,
  required Map<String, Object?> releaseBaseline,
  required Map<String, Object?> lspMatrix,
  required Map<String, Object?> lspClientMatrix,
  required List<String> errors,
}) {
  if (lspContract['schemaVersion'] != 1) {
    errors.add('core_lsp_parity_manifest.json must have schemaVersion 1.');
  }
  final baselineCore = releaseBaseline['core'];
  final baselineCoreVersion = baselineCore is Map<String, Object?>
      ? baselineCore['version']
      : null;
  if (lspContract['corePackage'] != '@utexo/rgb-sdk-core' ||
      lspContract['coreVersion'] != baselineCoreVersion) {
    errors.add(
      'core_lsp_parity_manifest.json must target the exact core package and '
      'version in release_baseline.json.',
    );
  }

  _validateLspMethodSet(
    matrixName: 'lsp_methods.json',
    matrix: lspMatrix,
    coreMethods: _stringSet(lspContract, 'utexoLspMethods', errors),
    adaptations: _stringSet(lspContract, 'utexoLspFlutterAdaptations', errors),
    errors: errors,
  );
  _validateLspMethodSet(
    matrixName: 'lsp_client_methods.json',
    matrix: lspClientMatrix,
    coreMethods: _stringSet(lspContract, 'lspClientMethods', errors),
    adaptations: _stringSet(lspContract, 'lspClientFlutterAdaptations', errors),
    errors: errors,
  );

  final stableSymbols = _collectEntrypointSymbols(
    'lib/rgb_sdk_flutter.dart',
    errors,
  );
  final rnLspTypes = lspContract['rnLspTypeExports'];
  if (rnLspTypes is! Map<String, Object?> || rnLspTypes.isEmpty) {
    errors.add('core_lsp_parity_manifest.json must map rnLspTypeExports.');
  }
  for (final symbol
      in (rnLspTypes is Map<String, Object?>
          ? rnLspTypes.values.whereType<String>()
          : const Iterable<String>.empty())) {
    if (!stableSymbols.contains(symbol)) {
      errors.add('Core beta.9 LSP contract requires stable export $symbol.');
    }
  }
  final runtimeErrors = lspContract['runtimeErrors'];
  if (runtimeErrors is! Map<String, Object?> || runtimeErrors.isEmpty) {
    errors.add('core_lsp_parity_manifest.json must map runtimeErrors.');
  } else {
    for (final entry in runtimeErrors.entries) {
      final dartName = entry.value;
      if (dartName is! String || !stableSymbols.contains(dartName)) {
        errors.add(
          'Core LSP error ${entry.key} maps to missing stable Dart export '
          '$dartName.',
        );
      }
    }
  }
}

void _validateLspMethodSet({
  required String matrixName,
  required Map<String, Object?> matrix,
  required Set<String> coreMethods,
  required Set<String> adaptations,
  required List<String> errors,
}) {
  final rows = matrix['methods'];
  if (rows is! List<Object?>) return;
  final byParity = <String, Set<String>>{
    'core': <String>{},
    'flutter-adaptation': <String>{},
  };
  for (final row in rows.whereType<Map<String, Object?>>()) {
    final id = row['id'];
    final parity = row['parity'];
    if (id is! String) continue;
    if (parity is! String || !_validLspParity.contains(parity)) {
      errors.add(
        '$matrixName/$id has invalid or missing parity classification.',
      );
      continue;
    }
    byParity[parity]!.add(id);
  }
  _compareExactSet(
    '$matrixName core methods',
    actual: byParity['core']!,
    expected: coreMethods,
    errors: errors,
  );
  _compareExactSet(
    '$matrixName Flutter adaptations',
    actual: byParity['flutter-adaptation']!,
    expected: adaptations,
    errors: errors,
  );
}

void _compareExactSet(
  String label, {
  required Set<String> actual,
  required Set<String> expected,
  required List<String> errors,
}) {
  for (final value in expected.difference(actual).toList()..sort()) {
    errors.add('$label is missing $value.');
  }
  for (final value in actual.difference(expected).toList()..sort()) {
    errors.add('$label contains unreviewed value $value.');
  }
}

Set<String> _stringSet(
  Map<String, Object?> source,
  String key,
  List<String> errors,
) {
  final values = source[key];
  if (values is! List<Object?> || values.any((value) => value is! String)) {
    errors.add('core_lsp_parity_manifest.json/$key must be a string array.');
    return <String>{};
  }
  final result = values.whereType<String>().toSet();
  if (result.length != values.length) {
    errors.add('core_lsp_parity_manifest.json/$key contains duplicates.');
  }
  return result;
}

void _validateCallableImplementations(
  String matrixName,
  Map<String, Object?> matrix,
  List<String> errors,
) {
  final rows = matrix['methods'];
  if (rows is! List<Object?>) return;
  for (final row in rows.whereType<Map<String, Object?>>()) {
    final id = row['id'];
    final implementation = row['implementation'];
    if (id is! String || implementation is! String) continue;
    final separator = implementation.indexOf('::');
    if (separator < 0) continue;
    final path = implementation.substring(0, separator);
    final symbol = implementation.substring(separator + 2);
    final member = symbol.split('.').last;
    if (member != id) {
      errors.add('$matrixName/$id points to mismatched member $symbol.');
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      errors.add('$matrixName/$id points to missing file $path.');
      continue;
    }
    if (!RegExp(
      '\\b${RegExp.escape(id)}\\s*\\(',
    ).hasMatch(file.readAsStringSync())) {
      errors.add('$matrixName/$id points to missing callable $symbol.');
    }
  }
}

void _validateCoreExportCoverage(
  Map<String, Object?> matrix,
  List<String> errors,
) {
  final stable = _collectEntrypointSymbols('lib/rgb_sdk_flutter.dart', errors);
  final advanced = _collectEntrypointSymbols(
    'lib/rgb_sdk_flutter_advanced.dart',
    errors,
  );
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return;

  for (final row in methods.whereType<Map<String, Object?>>()) {
    final id = row['id'];
    final implementation = row['implementation'];
    if (id is! String || implementation is! String) continue;
    final separator = implementation.indexOf('::');
    if (separator < 0) continue;
    final entrypoint = implementation.substring(0, separator);
    final symbol = implementation.substring(separator + 2);
    final exported = switch (entrypoint) {
      'lib/rgb_sdk_flutter.dart' => stable,
      'lib/rgb_sdk_flutter_advanced.dart' => advanced,
      _ => null,
    };
    if (exported == null) {
      errors.add(
        'core_exports.json/$id must reference a package entrypoint, not '
        '$entrypoint.',
      );
    } else if (symbol != id || !exported.contains(symbol)) {
      errors.add(
        'core_exports.json/$id claims $implementation, but `$symbol` is not '
        'exported by that entrypoint.',
      );
    }
  }
}

Set<String> _collectEntrypointSymbols(
  String entrypointPath,
  List<String> errors,
) {
  final entrypoint = File(entrypointPath);
  if (!entrypoint.existsSync()) {
    errors.add('Missing package entrypoint: $entrypointPath');
    return <String>{};
  }
  final graph = collectDartExportGraph(
    entrypoints: [entrypointPath],
    readSource: (path) => File(path).readAsStringSync(),
  );
  return {
    for (final entry in graph.entries)
      ..._publicTopLevelSymbols(File(entry.key)).where(entry.value.allows),
  };
}

Set<String> _publicTopLevelSymbols(File file) {
  final symbols = <String>{};
  final declaration = RegExp(
    r'^(?:abstract\s+final\s+class|abstract\s+interface\s+class|'
    r'abstract\s+class|sealed\s+class|final\s+class|class|enum|typedef|extension)\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)',
  );
  final callable = RegExp(
    r'^(?:[A-Za-z][A-Za-z0-9_<>,? ]*\s+)'
    r'([a-zA-Z][A-Za-z0-9_]*)\s*\(',
  );
  final variable = RegExp(
    r'^(?:const|final)\s+[A-Za-z][A-Za-z0-9_<>,? ]*\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
  );
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith(' ') || line.startsWith('\t')) continue;
    for (final pattern in <RegExp>[declaration, callable, variable]) {
      final match = pattern.firstMatch(line);
      if (match != null && !match.group(1)!.startsWith('_')) {
        symbols.add(match.group(1)!);
        break;
      }
    }
  }
  return symbols;
}

Map<String, Object?> _readMatrix(
  Directory root,
  String relativePath,
  List<String> errors,
) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    errors.add('Missing matrix file: $relativePath');
    return <String, Object?>{};
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
    errors.add('$relativePath must contain a JSON object.');
  } catch (error) {
    errors.add('$relativePath is not valid JSON: $error');
  }
  return <String, Object?>{};
}

Map<String, Object?> _readEvidenceCatalog(
  Directory root,
  String relativePath,
  List<String> errors,
) {
  final catalog = _readMatrix(root, relativePath, errors);
  if (catalog.isEmpty) return <String, Object?>{};
  if (catalog['schemaVersion'] != 1) {
    errors.add('$relativePath must have schemaVersion 1.');
  }
  final buckets = catalog['buckets'];
  if (buckets is Map<String, Object?>) return buckets;
  errors.add('$relativePath must contain a buckets object.');
  return <String, Object?>{};
}

void _validateMatrixShape(
  String name,
  Map<String, Object?> matrix,
  Map<String, Object?> evidenceCatalog,
  List<String> errors,
) {
  final methods = matrix['methods'];
  if (matrix['schemaVersion'] != 1) {
    errors.add('$name must have schemaVersion 1.');
  }
  if (methods is! List<Object?>) {
    errors.add('$name must have a methods array.');
    return;
  }

  final seen = <String>{};
  for (final raw in methods) {
    if (raw is! Map<String, Object?>) {
      errors.add('$name contains a non-object method row.');
      continue;
    }
    final id = raw['id'];
    if (id is! String || id.isEmpty) {
      errors.add('$name contains a method row without id.');
      continue;
    }
    if (!seen.add(id)) {
      errors.add('$name contains duplicate method id: $id');
    }
    for (final field in <String>[
      'group',
      'support',
      'fixture',
      'contract',
      'implementation',
      'evidenceBucket',
    ]) {
      if (raw[field] is! String || (raw[field] as String).isEmpty) {
        errors.add('$name/$id is missing required string field: $field');
      }
    }
    final implementation = raw['implementation'];
    if (implementation is String &&
        !implementation.contains('::') &&
        implementation != 'native-artifact') {
      errors.add(
        '$name/$id implementation must name a concrete symbol, for example '
        'path/to/file.dart::Class.method.',
      );
    }
    final evidenceBucket = raw['evidenceBucket'];
    final fixture = raw['fixture'];
    if (evidenceBucket is String &&
        fixture is String &&
        evidenceBucket != fixture) {
      errors.add(
        '$name/$id evidenceBucket must match fixture until executable test IDs '
        'replace fixture buckets.',
      );
    }
    if (evidenceBucket is String) {
      final evidence = evidenceCatalog[evidenceBucket];
      if (evidence is! Map<String, Object?>) {
        errors.add('$name/$id has uncataloged evidenceBucket: $evidenceBucket');
      } else {
        final testIds = evidence['testIds'];
        final assertions = evidence['assertions'];
        final claimLevel = evidence['claimLevel'];
        if (claimLevel is! String || claimLevel.isEmpty) {
          errors.add(
            '$name/$id evidenceBucket $evidenceBucket lacks claimLevel.',
          );
        }
        if (testIds is! List<Object?> || testIds.isEmpty) {
          errors.add('$name/$id evidenceBucket $evidenceBucket lacks testIds.');
        }
        if (assertions is! List<Object?> || assertions.isEmpty) {
          errors.add(
            '$name/$id evidenceBucket $evidenceBucket lacks assertions.',
          );
        }
      }
    }
    final support = raw['support'];
    if (support is String && !_validSupport.contains(support)) {
      errors.add('$name/$id has invalid support value: $support');
    }
    final contract = raw['contract'];
    if (contract is String && !_validContract.contains(contract)) {
      errors.add(
        '$name/$id has invalid contract value: $contract. '
        'Use covered or implemented; planned rows are not release-ready.',
      );
    }
    for (final field in <String>['ios', 'android']) {
      final status = raw[field];
      if (status == null) continue;
      if (status is! String || !_validPlatformStatus.contains(status)) {
        errors.add('$name/$id has invalid $field status: $status');
      }
    }
    if (support == 'supported' && contract is String) {
      final isContracted = contract == 'covered' || contract == 'implemented';
      if (!isContracted) {
        errors.add('$name/$id is supported but lacks contract coverage.');
      }
    }
  }
}

void _validateSourceCoverage({
  required String name,
  required String className,
  required String sourcePath,
  required Map<String, Object?> matrix,
  required List<String> errors,
}) {
  final sourceMethods = _extractPublicClassMethods(sourcePath, className);
  final matrixMethods = _methodIds(matrix);

  final missing = sourceMethods.difference(matrixMethods).toList()..sort();
  final stale = matrixMethods.difference(sourceMethods).toList()..sort();

  for (final method in missing) {
    errors.add('$name.$method is public but has no test matrix row.');
  }
  for (final method in stale) {
    errors.add('$name matrix row is stale or no longer public: $method');
  }
}

Set<String> _methodIds(Map<String, Object?> matrix) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row['id'])
      .whereType<String>()
      .toSet();
}

Set<String> _extractPublicClassMethods(String relativePath, String className) {
  final file = File(relativePath);
  if (!file.existsSync()) return <String>{};

  final methods = <String>{};
  final files = _dartLibraryFiles(file);
  for (final libraryFile in files) {
    methods.addAll(
      _extractPublicMembersFromScope(libraryFile, 'class', className),
    );
  }
  if (className == 'UtexoWallet') {
    methods.addAll(
      _extractPublicMembersFromScope(
        file,
        'extension',
        'UtexoWalletEngineAccess',
      ),
    );
    methods.addAll(
      _extractPublicMembersFromScope(
        File('lib/src/wallet/utexo_wallet_raw_compatibility.dart'),
        'extension',
        'UtexoWalletRawApi',
      ),
    );
  } else if (className == 'RlnWallet') {
    const scopes = <(String, String)>[
      ('class', '_RlnWalletBackend'),
      ('mixin', '_UtexoWallet'),
      ('extension', 'RlnWalletRawApi'),
    ];
    for (final libraryFile in files) {
      for (final (keyword, scope) in scopes) {
        methods.addAll(
          _extractPublicMembersFromScope(libraryFile, keyword, scope),
        );
      }
    }
  } else if (className == 'UtexoLsp') {
    const mixins = <String>[
      '_UtexoLspConnection',
      '_UtexoLspAssetBridge',
      '_UtexoLspAddress',
      '_UtexoLspApay',
      '_UtexoLspRelay',
    ];
    for (final libraryFile in files) {
      for (final mixin in mixins) {
        methods.addAll(
          _extractPublicMembersFromScope(libraryFile, 'mixin', mixin),
        );
      }
    }
  }
  return methods;
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

Set<String> _extractPublicMembersFromScope(
  File file,
  String keyword,
  String scopeName,
) {
  final unit = parseString(
    content: file.readAsStringSync(),
    path: file.path,
  ).unit;
  final methods = <String>{};
  for (final declaration in unit.declarations) {
    final (kind, name, members) = switch (declaration) {
      ClassDeclaration(:final namePart, :final body) => (
        'class',
        namePart.typeName.lexeme,
        body is BlockClassBody ? body.members : const <ClassMember>[],
      ),
      MixinDeclaration(:final name, :final body) => (
        'mixin',
        name.lexeme,
        body.members,
      ),
      ExtensionDeclaration(:final name, :final body) => (
        'extension',
        name?.lexeme,
        body.members,
      ),
      _ => ('', null, const <ClassMember>[]),
    };
    final matches =
        name == scopeName ||
        (scopeName == '_UtexoWallet' && (name?.startsWith(scopeName) ?? false));
    if (kind != keyword || !matches) continue;
    methods.addAll(
      members
          .whereType<MethodDeclaration>()
          .where(
            (method) =>
                !method.isGetter &&
                !method.isSetter &&
                !method.isStatic &&
                !method.name.lexeme.startsWith('_'),
          )
          .map((method) => method.name.lexeme),
    );
  }
  return methods;
}
