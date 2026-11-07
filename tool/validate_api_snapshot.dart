import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'api_export_graph.dart';

const _snapshotPath = 'tool/api_snapshot.json';

void main(List<String> args) {
  _verifyAstExtraction();
  final current = _buildSnapshot();
  if (args.contains('--update')) {
    const encoder = JsonEncoder.withIndent('  ');
    File(_snapshotPath).writeAsStringSync('${encoder.convert(current)}\n');
    stdout.writeln('Updated $_snapshotPath from the AST-normalized surface.');
    return;
  }
  if (args.contains('--print-current')) {
    const encoder = JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert(current));
    return;
  }

  final errors = <String>[];
  final snapshotFile = File(_snapshotPath);
  if (!snapshotFile.existsSync()) {
    errors.add('Missing $_snapshotPath. Run with --print-current to inspect.');
  } else {
    try {
      final expected =
          jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
      if (expected['schemaVersion'] != current['schemaVersion']) {
        errors.add(
          'snapshot schema changed: expected ${expected['schemaVersion']}, '
          'current ${current['schemaVersion']}.',
        );
      }
      _compareSection('dartExportedSurface', expected, current, errors);
      _compareSection('stableWalletSurface', expected, current, errors);
      _compareSection('advancedWalletRawSurface', expected, current, errors);
      _compareSection('pigeonSchema', expected, current, errors);
      _compareSection('generatedPigeonSurface', expected, current, errors);
      _compareSection('nativeBridgeSurface', expected, current, errors);
    } catch (error) {
      errors.add('$_snapshotPath is not valid snapshot JSON: $error');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('API snapshot validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    stderr.writeln(
      'Intentional API/ABI changes must update $_snapshotPath and cite the '
      'tracker row plus migration note in the same change.',
    );
    exit(1);
  }

  stdout.writeln('API snapshot validation passed.');
}

void _compareSection(
  String key,
  Map<String, Object?> expected,
  Map<String, Object?> current,
  List<String> errors,
) {
  final expectedSection = expected[key];
  final currentSection = current[key];
  if (expectedSection is! Map<String, Object?> ||
      currentSection is! Map<String, Object?>) {
    errors.add('$key must be a JSON object.');
    return;
  }

  for (final field in <String>['hash', 'count']) {
    if (expectedSection[field] != currentSection[field]) {
      errors.add(
        '$key $field changed: expected ${expectedSection[field]}, '
        'current ${currentSection[field]}.',
      );
    }
  }
}

Map<String, Object?> _buildSnapshot() {
  final exportedFiles = collectDartExportGraph(
    entrypoints: const [
      'lib/rgb_sdk_flutter.dart',
      'lib/rgb_sdk_flutter_advanced.dart',
      'lib/rgb_sdk_flutter_webrgb.dart',
    ],
    readSource: (path) => File(path).readAsStringSync(),
  );
  final nativeFiles = <String>[
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbSdkFlutterPlugin.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnAssetMapper.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnAssetMedia.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnNodeStore.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnStorageDirectoryPolicy.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibChannel.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibSessionStore.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibDtos.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibExistingOpenPolicy.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibOperationPolicy.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibProfileReader.kt',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RgbLibRevocationPolicy.kt',
    'ios/Classes/RgbSdkFlutterPlugin.swift',
    'ios/Classes/RgbLibChannel.swift',
    'ios/Classes/RgbLibSwiftHelper.swift',
    'ios/Classes/RgbLibDtos.swift',
    'ios/Classes/RgbLibExistingOpenPolicy.swift',
    'ios/Classes/RgbLibOperationPolicy.swift',
    'ios/Classes/RgbLibProfileReader.swift',
    'ios/Classes/RgbLibRevocationPolicy.swift',
    'ios/Classes/RgbLibStorageDirectoryPolicy.swift',
    'ios/Classes/RlnAssetMapper.swift',
    'ios/Classes/RlnAssetMedia.swift',
    'ios/Classes/RlnRecoverableSendBridge.swift',
    'ios/Classes/RlnBridgeErrorDetails.swift',
    'ios/Classes/RlnWireCodec.swift',
    'ios/Classes/RlnNodeStore.swift',
    'ios/Classes/RlnStorageDirectoryPolicy.swift',
  ];
  final generatedPigeonFiles = <String>[
    'lib/src/pigeon/rln_api.g.dart',
    'android/src/main/kotlin/com/utexo/rgb_sdk_flutter/RlnApi.g.kt',
    'ios/Classes/RlnApi.g.swift',
  ];

  return <String, Object?>{
    'schemaVersion': 2,
    'description':
        'AST-normalized public API and bridge snapshot. Update only with a tracker row and migration note.',
    'dartExportedSurface': _surface(
      exportedFiles.keys.toList(growable: false),
      dartExports: exportedFiles,
    ),
    'stableWalletSurface': _dartMemberSurface(<String>[
      'lib/src/wallet/utexo_wallet.dart',
      'lib/src/wallet/utexo_wallet_bfa.dart',
      'lib/src/wallet/utexo_wallet_lifecycle.dart',
      'lib/src/wallet/utexo_wallet_lsp_apay.dart',
      'lib/src/wallet/utexo_wallet_onchain.dart',
      'lib/src/wallet/utexo_wallet_asset_media.dart',
      'lib/src/wallet/rgb_lib/rgb_lib_wallet.dart',
      'lib/src/wallet/utexo_wallet_lightning.dart',
    ]),
    'advancedWalletRawSurface': _dartMemberSurface(<String>[
      'lib/src/wallet/utexo_wallet_raw.dart',
    ]),
    'pigeonSchema': _surface(<String>['pigeons/rln_api.dart']),
    'generatedPigeonSurface': _surface(generatedPigeonFiles),
    'nativeBridgeSurface': _surface(nativeFiles),
  };
}

void _verifyAstExtraction() {
  const source = '''
class PublicApi {
  Future<void> realMethod(String value) async {
    final leakedLocal = value;
    throw StateError(leakedLocal);
  }
}
''';
  final members = _publicDartMembers('<api-snapshot-self-test>', source);
  if (members.length != 1 ||
      members.single != 'Future<void> realMethod(String value)') {
    throw StateError(
      'API member extraction included executable implementation text: $members',
    );
  }
  final surface = _normalizedDartSurface('<api-snapshot-self-test>', source);
  if (surface.any(
    (entry) => entry.contains('leakedLocal') || entry.contains('StateError'),
  )) {
    throw StateError(
      'Exported-surface extraction included executable implementation text: '
      '$surface',
    );
  }
}

Map<String, Object?> _dartMemberSurface(List<String> files) {
  final members = <String>[];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Snapshot source does not exist: $path');
    }
    members.addAll(_publicDartMembers(path, file.readAsStringSync()));
  }
  final uniqueMembers = members.toSet().toList()..sort();
  final normalized = uniqueMembers.join('\n');
  return <String, Object?>{
    'count': uniqueMembers.length,
    'hash': crypto.sha256.convert(utf8.encode(normalized)).toString(),
    'files': files,
    'members': uniqueMembers,
  };
}

List<String> _publicDartMembers(String path, String source) {
  final result = parseString(content: source, path: path);
  if (result.errors.isNotEmpty) {
    throw StateError(
      'Cannot snapshot invalid Dart source $path: ${result.errors.join('; ')}',
    );
  }

  final members = <String>[];
  for (final declaration in result.unit.declarations) {
    final (ownerName, classMembers) = switch (declaration) {
      ClassDeclaration(:final namePart, :final body) => (
        namePart.typeName.lexeme,
        body is BlockClassBody ? body.members : const <ClassMember>[],
      ),
      MixinDeclaration(:final name, :final body) => (name.lexeme, body.members),
      ExtensionDeclaration(:final name, :final body) => (
        name?.lexeme ?? '<anonymous extension>',
        body.members,
      ),
      _ => (null, const <ClassMember>[]),
    };
    for (final member in classMembers) {
      if (member is MethodDeclaration && !member.name.lexeme.startsWith('_')) {
        members.add(_methodSignature(member));
      } else if (member is ConstructorDeclaration &&
          ownerName == 'UtexoWallet' &&
          (member.name == null || !member.name!.lexeme.startsWith('_'))) {
        members.add(_constructorSignature(ownerName!, member));
      }
    }
  }
  return members;
}

String _methodSignature(MethodDeclaration method) {
  final returnType = method.returnType?.toSource() ?? 'dynamic';
  final name = method.name.lexeme;
  if (method.isGetter) return '$returnType get $name';
  if (method.isSetter) {
    return _normalizeSignature('$returnType set $name${method.parameters}');
  }
  final operator = method.isOperator ? 'operator ' : '';
  final typeParameters = method.typeParameters?.toSource() ?? '';
  return _normalizeSignature(
    '$returnType $operator$name$typeParameters${method.parameters}',
  );
}

String _constructorSignature(
  String ownerName,
  ConstructorDeclaration constructor,
) {
  final name = constructor.name == null ? '' : '.${constructor.name!.lexeme}';
  return _normalizeSignature('$ownerName$name${constructor.parameters}');
}

String _normalizeSignature(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Map<String, Object?> _surface(
  List<String> files, {
  Map<String, DartExportVisibility> dartExports =
      const <String, DartExportVisibility>{},
}) {
  final entries = <String>[];
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Snapshot source does not exist: $path');
    }
    entries.add('### $path');
    if (path.endsWith('.dart')) {
      entries.addAll(
        _normalizedDartSurface(
          path,
          file.readAsStringSync(),
          dartExport: dartExports[path],
        ),
      );
    } else {
      entries.addAll(
        _normalizedNativePublicLines(path, file.readAsLinesSync()),
      );
    }
  }
  final normalized = entries.join('\n');
  return <String, Object?>{
    'count': entries.length,
    'hash': crypto.sha256.convert(utf8.encode(normalized)).toString(),
    'files': files,
  };
}

List<String> _normalizedDartSurface(
  String path,
  String source, {
  DartExportVisibility? dartExport,
}) {
  final result = parseString(content: source, path: path);
  if (result.errors.isNotEmpty) {
    throw StateError(
      'Cannot snapshot invalid Dart source $path: ${result.errors.join('; ')}',
    );
  }

  final output = <String>[];
  for (final declaration in result.unit.declarations) {
    switch (declaration) {
      case ClassDeclaration(:final namePart, :final body):
        _addTypeSurface(
          output,
          source,
          declaration,
          namePart.typeName.lexeme,
          body,
          dartExport,
        );
      case MixinDeclaration(:final name, :final body):
        _addTypeSurface(
          output,
          source,
          declaration,
          name.lexeme,
          body,
          dartExport,
        );
      case ExtensionDeclaration(:final name, :final body):
        final extensionName = name?.lexeme;
        if (extensionName != null &&
            !_isSymbolExported(extensionName, dartExport)) {
          continue;
        }
        output.add(
          _normalizeSignature(
            source.substring(declaration.offset, body.offset),
          ),
        );
        _addClassMembers(
          output,
          extensionName ?? '<anonymous extension>',
          body.members,
        );
      case ExtensionTypeDeclaration(:final primaryConstructor, :final body):
        final name = primaryConstructor.typeName.lexeme;
        _addTypeSurface(output, source, declaration, name, body, dartExport);
      case EnumDeclaration(:final namePart, :final body):
        final name = namePart.typeName.lexeme;
        if (!_isSymbolExported(name, dartExport)) continue;
        output.add(
          _normalizeSignature(
            source.substring(declaration.offset, body.offset),
          ),
        );
        for (final constant in body.constants) {
          if (!constant.name.lexeme.startsWith('_')) {
            output.add('$name::${_normalizeSignature(constant.toSource())}');
          }
        }
        _addClassMembers(output, name, body.members);
      case FunctionDeclaration(:final name):
        if (!_isSymbolExported(name.lexeme, dartExport)) continue;
        output.add('top::${_functionSignature(declaration)}');
      case TopLevelVariableDeclaration(:final variables):
        for (final variable in variables.variables) {
          final name = variable.name.lexeme;
          if (!_isSymbolExported(name, dartExport)) continue;
          output.add('top::${_variableSignature(variables, variable)}');
        }
      case GenericTypeAlias(:final name):
        if (_isSymbolExported(name.lexeme, dartExport)) {
          output.add('top::${_normalizeSignature(declaration.toSource())}');
        }
      case FunctionTypeAlias(:final name):
        if (_isSymbolExported(name.lexeme, dartExport)) {
          output.add('top::${_normalizeSignature(declaration.toSource())}');
        }
      default:
        // Directives are represented outside CompilationUnit.declarations.
        // Any future declaration kind must be added deliberately so the
        // snapshot cannot fall back to body-text heuristics.
        throw StateError(
          'Unsupported public-surface declaration in $path: '
          '${declaration.runtimeType}',
        );
    }
  }
  return output;
}

void _addTypeSurface(
  List<String> output,
  String source,
  AstNode declaration,
  String name,
  ClassBody body,
  DartExportVisibility? dartExport,
) {
  if (!_isSymbolExported(name, dartExport)) return;
  output.add(
    _normalizeSignature(source.substring(declaration.offset, body.offset)),
  );
  if (body is BlockClassBody) {
    _addClassMembers(output, name, body.members);
  }
}

void _addClassMembers(
  List<String> output,
  String ownerName,
  Iterable<ClassMember> members,
) {
  for (final member in members) {
    switch (member) {
      case MethodDeclaration(:final name):
        if (!name.lexeme.startsWith('_')) {
          output.add('$ownerName::${_methodSignature(member)}');
        }
      case ConstructorDeclaration(:final name):
        if (name == null || !name.lexeme.startsWith('_')) {
          output.add('$ownerName::${_constructorSignature(ownerName, member)}');
        }
      case FieldDeclaration(:final fields):
        for (final variable in fields.variables) {
          if (!variable.name.lexeme.startsWith('_')) {
            output.add(
              '$ownerName::${_variableSignature(fields, variable, isStatic: member.isStatic)}',
            );
          }
        }
      default:
        throw StateError(
          'Unsupported member in $ownerName: ${member.runtimeType}',
        );
    }
  }
}

String _functionSignature(FunctionDeclaration function) {
  final returnType = function.returnType?.toSource() ?? 'dynamic';
  final name = function.name.lexeme;
  if (function.isGetter) return '$returnType get $name';
  final expression = function.functionExpression;
  final parameters = expression.parameters?.toSource() ?? '';
  if (function.isSetter) {
    return _normalizeSignature('$returnType set $name$parameters');
  }
  final typeParameters = expression.typeParameters?.toSource() ?? '';
  return _normalizeSignature('$returnType $name$typeParameters$parameters');
}

String _variableSignature(
  VariableDeclarationList declaration,
  VariableDeclaration variable, {
  bool isStatic = false,
}) {
  final modifiers = <String>[
    if (isStatic) 'static',
    if (declaration.isLate) 'late',
    if (declaration.keyword != null) declaration.keyword!.lexeme,
    if (declaration.type != null) declaration.type!.toSource(),
  ];
  final initializer = variable.initializer;
  final value = initializer == null ? '' : ' = ${initializer.toSource()}';
  return _normalizeSignature(
    '${modifiers.join(' ')} ${variable.name.lexeme}$value',
  );
}

bool _isSymbolExported(String symbol, DartExportVisibility? directive) =>
    (directive ?? const DartExportVisibility.all()).allows(symbol);

List<String> _normalizedNativePublicLines(String path, List<String> lines) {
  final output = <String>[];
  var inBlockComment = false;
  for (final original in lines) {
    var line = original.trim();
    if (line.isEmpty) continue;

    if (inBlockComment) {
      if (line.contains('*/')) inBlockComment = false;
      continue;
    }
    if (line.startsWith('/*')) {
      if (!line.contains('*/')) inBlockComment = true;
      continue;
    }
    if (line.startsWith('//') || line.startsWith('*')) continue;
    if (line.startsWith('import ')) continue;
    if (line.startsWith('@') && !line.startsWith('@HostApi')) continue;

    if (path.endsWith('.kt')) {
      if (_isKotlinPublicSurfaceLine(line)) output.add(line);
      continue;
    }
    if (path.endsWith('.swift')) {
      if (_isSwiftPublicSurfaceLine(line)) output.add(line);
      continue;
    }
    output.add(line);
  }
  return output;
}

bool _isKotlinPublicSurfaceLine(String line) {
  return line.startsWith('class ') ||
      line.startsWith('interface ') ||
      line.startsWith('data class ') ||
      line.startsWith('enum class ') ||
      line.startsWith('fun ') ||
      line.startsWith('override fun ') ||
      line.startsWith('val ') ||
      line.startsWith('var ');
}

bool _isSwiftPublicSurfaceLine(String line) {
  return line.startsWith('class ') ||
      line.startsWith('struct ') ||
      line.startsWith('protocol ') ||
      line.startsWith('enum ') ||
      line.startsWith('func ') ||
      line.startsWith('static func ') ||
      line.startsWith('let ') ||
      line.startsWith('var ');
}
