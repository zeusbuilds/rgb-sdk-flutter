import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:crypto/crypto.dart' show sha256;

void main() {
  final root = Directory.current;
  final errors = <String>[];

  final manifest = _readJsonObject(
    File('${root.path}/tool/rn_parity_manifest.json'),
    errors,
  );
  final lspManifest = _readJsonObject(
    File('${root.path}/tool/core_lsp_parity_manifest.json'),
    errors,
  );
  final baseline = _readJsonObject(
    File('${root.path}/tool/release_baseline.json'),
    errors,
  );
  final rnPath = _resolveRnPath();
  final rnRoot = Directory(rnPath);
  if (!rnRoot.existsSync()) {
    errors.add(
      'RN reference repo not found at $rnPath. Set RGB_SDK_RN_PATH to the '
      'rgb-sdk-rn dev checkout.',
    );
    _finish(errors);
  }

  final upstreamCommit = _validateRnUpstreamBaseline(rnRoot, baseline, errors);
  _validateRnBaseline(rnRoot, baseline, errors);
  _validateLowLevelNativeMethods(root, rnRoot, errors);
  _validateTypedPigeonWire(root, errors);
  _validateWalletMethods(root, rnRoot, errors);
  _validateRuntimeExports(root, rnRoot, manifest, errors);
  _validateTypeExports(root, rnRoot, manifest, errors);
  _validateScopedTypeStars(rnRoot, manifest, errors);
  _validateCoreLspErrorAliases(manifest, lspManifest, errors);
  _validateCoreLspTypeExports(root, rnRoot, lspManifest, errors);
  _validateCoreLspDartSignatures(root, lspManifest, errors);
  _validateRlnSurfaceExcludedByRn(root, rnRoot, lspManifest, errors);
  _validateWebRgb(root, rnRoot, errors);

  _finish(errors);

  stdout.writeln(
    'RN parity valid against ${_shortCommit(_nestedString(baseline, <String>['reactNative', 'commit']))}: '
    'NativeRgb methods, UTEXOWallet methods, and runtime package exports. '
    'Upstream dev ${_shortCommit(upstreamCommit)} was checked for drift.',
  );
}

void _validateWebRgb(Directory root, Directory rnRoot, List<String> errors) {
  final manifest = _readJsonObject(
    File('${root.path}/tool/webrgb_parity_manifest.json'),
    errors,
  );
  final sources = manifest['reviewedSources'];
  if (sources is! Map<String, Object?> || sources.isEmpty) {
    errors.add('WebRGB reviewed-source inventory is missing.');
    return;
  }
  for (final source in sources.entries) {
    final file = File('${rnRoot.path}/${source.key}');
    if (!file.existsSync() ||
        sha256.convert(file.readAsBytesSync()).toString() != source.value) {
      errors.add(
        'WebRGB contract changed: ${source.key}. Review behavior and tests before repinning.',
      );
    }
  }
  final providerFile = File(
    '${root.path}/lib/src/integrations/webrgb/provider.dart',
  );
  final unit = parseString(content: providerFile.readAsStringSync()).unit;
  final type = unit.declarations.whereType<ClassDeclaration>().singleWhere(
    (type) => type.namePart.typeName.lexeme == 'WebRgbProvider',
  );
  final actual = (type.body as BlockClassBody).members
      .whereType<MethodDeclaration>()
      .where(
        (method) => !method.isGetter && !method.name.lexeme.startsWith('_'),
      )
      .map((method) => method.name.lexeme)
      .toSet();
  final expected = (manifest['methods'] as List<Object?>)
      .cast<String>()
      .toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    errors.add(
      'WebRGB provider method coverage differs: expected $expected, found $actual.',
    );
  }
  final rnPackage = _readJsonObject(
    File('${rnRoot.path}/package.json'),
    errors,
  );
  final peers = rnPackage['peerDependencies'] as Map<String, Object?>?;
  if (peers?['@utexo/webrgb'] != manifest['peerRange']) {
    errors.add(
      'WebRGB peer specification version changed; review wire shapes.',
    );
  }
  final devDependencies = rnPackage['devDependencies'] as Map<String, Object?>?;
  if (devDependencies?['@utexo/webrgb'] != manifest['peerVersion']) {
    errors.add('WebRGB development peer version changed; review wire shapes.');
  }
  final lock = File('${rnRoot.path}/yarn.lock');
  // Yarn may resolve the exact devDependency alone, or merge it with the peer
  // range. Bind every matching selector to its own reviewed archive block.
  final entry =
      '  version "${manifest['peerVersion']}"\n'
      '  resolved "${manifest['peerArchiveUrl']}"\n'
      '  integrity ${manifest['peerIntegrity']}';
  final lockedBlocks = lock.existsSync()
      ? lock.readAsStringSync().split(RegExp(r'\r?\n\r?\n')).where((block) {
          final header = block.split('\n').first.trim();
          return header.endsWith(':') &&
              (header.contains('"@utexo/webrgb@${manifest['peerRange']}"') ||
                  header.contains(
                    '"@utexo/webrgb@${manifest['peerVersion']}"',
                  ));
        }).toList()
      : const <String>[];
  if (lockedBlocks.isEmpty ||
      lockedBlocks.any((block) => !block.contains(entry))) {
    errors.add(
      'WebRGB resolved peer archive changed; review the wire contract.',
    );
  }
  final tarball = Platform.environment['RGB_SDK_WEBRGB_TARBALL'];
  if (tarball != null) {
    final file = File(tarball);
    if (!file.existsSync() ||
        sha256.convert(file.readAsBytesSync()).toString() !=
            manifest['peerArchiveSha256']) {
      errors.add('WebRGB peer tarball does not match the reviewed archive.');
    }
  }
}

void _validateCoreLspDartSignatures(
  Directory root,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  _validateSignatureInventory(
    manifest: manifest,
    signatureKey: 'utexoLspSignatures',
    methodKeys: const <String>['utexoLspMethods', 'utexoLspFlutterAdaptations'],
    errors: errors,
  );
  _validateSignatureInventory(
    manifest: manifest,
    signatureKey: 'lspClientSignatures',
    methodKeys: const <String>[
      'lspClientMethods',
      'lspClientFlutterAdaptations',
    ],
    errors: errors,
  );
  _validateSignatureInventory(
    manifest: manifest,
    signatureKey: 'lspWalletSignatures',
    methodKeys: const <String>[
      'lspWalletMethods',
      'lspWalletFlutterAdaptations',
    ],
    errors: errors,
  );
  _validateDartSignatureGroup(
    root: root,
    manifest: manifest,
    manifestKey: 'utexoLspSignatures',
    sourcePaths: const <String>[
      'lib/src/lsp/utexo_lsp.dart',
      'lib/src/lsp/utexo_lsp_address.dart',
      'lib/src/lsp/utexo_lsp_apay.dart',
      'lib/src/lsp/utexo_lsp_asset_bridge.dart',
      'lib/src/lsp/utexo_lsp_connection.dart',
      'lib/src/lsp/utexo_lsp_relay.dart',
    ],
    errors: errors,
  );
  _validateDartSignatureGroup(
    root: root,
    manifest: manifest,
    manifestKey: 'lspClientSignatures',
    sourcePaths: const <String>['lib/src/lsp/utexo_lsp_client.dart'],
    errors: errors,
  );
  _validateDartSignatureGroup(
    root: root,
    manifest: manifest,
    manifestKey: 'lspWalletSignatures',
    sourcePaths: const <String>['lib/src/lsp/lsp_wallet.dart'],
    errors: errors,
  );
  _validateDartGetterGroup(
    root: root,
    manifest: manifest,
    manifestKey: 'lspWalletGetters',
    sourcePaths: const <String>['lib/src/lsp/lsp_wallet.dart'],
    errors: errors,
  );
}

void _validateDartGetterGroup({
  required Directory root,
  required Map<String, Object?> manifest,
  required String manifestKey,
  required List<String> sourcePaths,
  required List<String> errors,
}) {
  final expected = _stringMap(manifest, manifestKey, errors);
  final actual = <String, String>{};
  for (final sourcePath in sourcePaths) {
    final file = File('${root.path}/$sourcePath');
    if (!file.existsSync()) {
      errors.add('$manifestKey references missing source $sourcePath.');
      continue;
    }
    final unit = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      throwIfDiagnostics: false,
    ).unit;
    for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
      final members = switch (declaration.body) {
        BlockClassBody body => body.members,
        EmptyClassBody() => const <ClassMember>[],
        _ => const <ClassMember>[],
      };
      for (final getter in members.whereType<MethodDeclaration>()) {
        if (!getter.isGetter || !expected.containsKey(getter.name.lexeme)) {
          continue;
        }
        actual[getter.name.lexeme] = getter.returnType?.toSource() ?? 'dynamic';
      }
    }
  }
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) {
      errors.add(
        '$manifestKey/${entry.key} changed: expected ${entry.value}, found '
        '${actual[entry.key] ?? 'no declaration'}.',
      );
    }
  }
}

void _validateSignatureInventory({
  required Map<String, Object?> manifest,
  required String signatureKey,
  required List<String> methodKeys,
  required List<String> errors,
}) {
  final signatures = _stringMap(manifest, signatureKey, errors).keys.toSet();
  final methods = <String>{};
  for (final key in methodKeys) {
    methods.addAll(_stringListSet(manifest, key, errors));
  }
  for (final name in methods.difference(signatures).toList()..sort()) {
    errors.add('$signatureKey is missing method $name.');
  }
  for (final name in signatures.difference(methods).toList()..sort()) {
    errors.add('$signatureKey contains stale method $name.');
  }
}

void _validateDartSignatureGroup({
  required Directory root,
  required Map<String, Object?> manifest,
  required String manifestKey,
  required List<String> sourcePaths,
  required List<String> errors,
}) {
  final expected = _stringMap(manifest, manifestKey, errors);
  final actual = <String, String>{};
  for (final sourcePath in sourcePaths) {
    final file = File('${root.path}/$sourcePath');
    if (!file.existsSync()) {
      errors.add('$manifestKey references missing source $sourcePath.');
      continue;
    }
    final unit = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      throwIfDiagnostics: false,
    ).unit;
    for (final declaration in unit.declarations) {
      final members = switch (declaration) {
        ClassDeclaration() => switch (declaration.body) {
          BlockClassBody body => body.members,
          EmptyClassBody() => const <ClassMember>[],
          _ => const <ClassMember>[],
        },
        MixinDeclaration() => declaration.body.members,
        _ => const <ClassMember>[],
      };
      for (final method in members.whereType<MethodDeclaration>()) {
        final name = method.name.lexeme;
        if (name.startsWith('_') || !expected.containsKey(name)) continue;
        final signature = _normalizedDartMethodSignature(method);
        final previous = actual[name];
        if (previous != null && previous != signature) {
          errors.add(
            '$manifestKey method $name has conflicting declarations: '
            '$previous and $signature.',
          );
        }
        actual[name] = signature;
      }
    }
  }

  for (final entry in expected.entries) {
    final signature = actual[entry.key];
    if (signature != entry.value) {
      errors.add(
        '$manifestKey/${entry.key} changed: expected ${entry.value}, found '
        '${signature ?? 'no declaration'}.',
      );
    }
  }
}

String _normalizedDartMethodSignature(MethodDeclaration method) {
  final returnType = method.returnType?.toSource() ?? 'dynamic';
  final parameters = method.parameters?.toSource() ?? '()';
  return '$returnType$parameters'.replaceAll(RegExp(r'\s+'), '');
}

void _validateCoreLspTypeExports(
  Directory root,
  Directory rnRoot,
  Map<String, Object?> lspManifest,
  List<String> errors,
) {
  final expected = _stringMap(lspManifest, 'rnLspTypeExports', errors);
  final actual = _extractRnTypeExportBlock(
    File('${rnRoot.path}/src/index.ts'),
    module: '@utexo/rgb-sdk-core',
    anchor: 'IUtexoLSPClient',
    errors: errors,
  );
  for (final name
      in actual.difference(expected.keys.toSet()).toList()..sort()) {
    errors.add(
      'RN LSP type export $name is missing from rnLspTypeExports in '
      'core_lsp_parity_manifest.json.',
    );
  }
  for (final name
      in expected.keys.toSet().difference(actual).toList()..sort()) {
    errors.add(
      'core_lsp_parity_manifest.json contains stale RN LSP type $name.',
    );
  }

  final stableSymbols = _collectDartLibrarySymbols(
    root,
    'lib/rgb_sdk_flutter.dart',
    errors,
  );
  for (final entry in expected.entries) {
    if (!stableSymbols.contains(entry.value)) {
      errors.add(
        'RN LSP type ${entry.key} maps to ${entry.value}, which is not '
        'exported by lib/rgb_sdk_flutter.dart.',
      );
    }
  }
}

void _validateCoreLspErrorAliases(
  Map<String, Object?> rnManifest,
  Map<String, Object?> lspManifest,
  List<String> errors,
) {
  final aliases = _stringMap(rnManifest, 'runtimeExportAliases', errors);
  final lspErrors = lspManifest['runtimeErrors'];
  if (lspErrors is! Map<String, Object?>) {
    errors.add(
      'core_lsp_parity_manifest.json/runtimeErrors must be an object.',
    );
    return;
  }
  for (final entry in lspErrors.entries) {
    final dartName = entry.value;
    if (dartName is! String || aliases[entry.key] != dartName) {
      errors.add(
        'RN runtime LSP error ${entry.key} must map to $dartName in '
        'rn_parity_manifest.json.',
      );
    }
  }
}

void _validateRlnSurfaceExcludedByRn(
  Directory root,
  Directory rnRoot,
  Map<String, Object?> lspManifest,
  List<String> errors,
) {
  final generatedSwift = File('${root.path}/ios/RGBLightningNode.swift');
  final rnSwift = File('${rnRoot.path}/ios/RgbSwiftHelper.swift');
  if (!generatedSwift.existsSync() || !rnSwift.existsSync()) {
    errors.add(
      'RLN-to-RN surface audit requires ios/RGBLightningNode.swift and '
      'the RN ios/RgbSwiftHelper.swift.',
    );
    return;
  }

  final protocolMethods = _extractSwiftProtocolMethods(
    generatedSwift.readAsStringSync(),
    'SdkNodeProtocol',
    errors,
  );
  final rnCalls = RegExp(r'\bnode\.`?([A-Za-z_][A-Za-z0-9_]*)`?\s*\(')
      .allMatches(rnSwift.readAsStringSync())
      .map((match) => match.group(1)!)
      .toSet();
  final actualExcluded = protocolMethods.difference(rnCalls);
  final expectedExcluded = _stringListSet(
    lspManifest,
    'rlnNodeMethodsScopedOutByRn',
    errors,
  );
  for (final method
      in expectedExcluded.difference(actualExcluded).toList()..sort()) {
    errors.add(
      'RLN method $method is listed as RN-scoped-out but RN now calls it.',
    );
  }
  for (final method
      in actualExcluded.difference(expectedExcluded).toList()..sort()) {
    errors.add(
      'RLN method $method is not called by RN and lacks a reviewed exclusion.',
    );
  }
  for (final method in rnCalls.difference(protocolMethods).toList()..sort()) {
    errors.add(
      'RN calls SdkNode.$method, which is absent from the pinned RLN protocol.',
    );
  }

  final excludedFields = lspManifest['rlnFieldsScopedOutByRn'];
  if (excludedFields is! Map<String, Object?> ||
      excludedFields['SdkIssueAssetIfaRequest.issuanceType'] is! String) {
    errors.add(
      'The reviewed RLN issuanceType exclusion is missing from '
      'core_lsp_parity_manifest.json.',
    );
    return;
  }
  final generatedSource = generatedSwift.readAsStringSync();
  final rnSource = rnSwift.readAsStringSync();
  if (!generatedSource.contains('public var issuanceType: IfaIssuanceType?')) {
    errors.add(
      'Pinned RLN no longer exposes SdkIssueAssetIfaRequest.issuanceType; '
      're-audit the field exclusion.',
    );
  }
  if (rnSource.contains('issuanceType:')) {
    errors.add(
      'RN now maps SdkIssueAssetIfaRequest.issuanceType; remove the stale '
      'field exclusion and implement parity.',
    );
  }
}

Set<String> _extractSwiftProtocolMethods(
  String source,
  String protocolName,
  List<String> errors,
) {
  final declaration = source.indexOf('public protocol $protocolName');
  if (declaration < 0) {
    errors.add('Pinned Swift binding lacks public protocol $protocolName.');
    return <String>{};
  }
  final opening = source.indexOf('{', declaration);
  final closing = _matchingDelimiter(source, opening, 123, 125);
  if (opening < 0 || closing < 0) {
    errors.add('Unable to parse Swift protocol $protocolName.');
    return <String>{};
  }
  return RegExp(
        r'^\s*func\s+`?([A-Za-z_][A-Za-z0-9_]*)`?\s*\(',
        multiLine: true,
      )
      .allMatches(source.substring(opening + 1, closing))
      .map((match) => match.group(1)!)
      .toSet();
}

Set<String> _stringListSet(
  Map<String, Object?> source,
  String field,
  List<String> errors,
) {
  final raw = source[field];
  if (raw is! List<Object?> || raw.any((value) => value is! String)) {
    errors.add('$field must be a string array.');
    return <String>{};
  }
  final result = raw.whereType<String>().toSet();
  if (result.length != raw.length) {
    errors.add('$field contains duplicate entries.');
  }
  return result;
}

String _resolveRnPath() {
  final envPath = Platform.environment['RGB_SDK_RN_PATH'];
  if (envPath != null && envPath.trim().isNotEmpty) return envPath.trim();
  return '../rgb-sdk-rn';
}

Map<String, Object?> _readJsonObject(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing JSON file: ${file.path}');
    return <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, Object?>) return decoded;
    errors.add('${file.path} must contain a JSON object.');
  } catch (error) {
    errors.add('${file.path} is not valid JSON: $error');
  }
  return <String, Object?>{};
}

String? _validateRnUpstreamBaseline(
  Directory rnRoot,
  Map<String, Object?> baseline,
  List<String> errors,
) {
  final expectedCommit = _nestedString(baseline, <String>[
    'reactNative',
    'commit',
  ]);
  final expectedRepository = _nestedString(baseline, <String>[
    'reactNative',
    'repository',
  ]);
  if (expectedCommit == null || expectedRepository == null) {
    errors.add(
      'release_baseline.json must define reactNative.repository and '
      'reactNative.commit before upstream drift can be checked.',
    );
    return null;
  }

  final remoteRef =
      Platform.environment['RGB_SDK_RN_UPSTREAM_REF']?.trim().isNotEmpty == true
      ? Platform.environment['RGB_SDK_RN_UPSTREAM_REF']!.trim()
      : 'refs/heads/dev';
  final remoteName =
      Platform.environment['RGB_SDK_RN_REMOTE']?.trim().isNotEmpty == true
      ? Platform.environment['RGB_SDK_RN_REMOTE']!.trim()
      : 'origin';

  final upstream = _readRemoteCommit(rnRoot, remoteName, remoteRef, errors);
  if (upstream != null && upstream != expectedCommit) {
    errors.add(
      'RN upstream $remoteName/$remoteRef drifted. Expected baseline '
      '$expectedCommit, remote has $upstream. Fetch/audit the current RN dev '
      'branch and update tool/release_baseline.json before claiming parity.',
    );
  }

  final fetched = _readFetchedCommit(rnRoot, remoteName, remoteRef);
  if (fetched != null && fetched != expectedCommit) {
    errors.add(
      'Fetched RN $remoteName/$remoteRef is $fetched, but baseline expects '
      '$expectedCommit. Run git -C ${rnRoot.path} fetch $remoteName '
      '${remoteRef.replaceFirst('refs/heads/', '')} and update/audit the '
      'baseline if upstream intentionally moved.',
    );
  }

  final configuredUrl = _readGitConfig(rnRoot, 'remote.$remoteName.url');
  if (configuredUrl != null &&
      !_sameRepository(configuredUrl, expectedRepository)) {
    errors.add(
      'RN checkout $remoteName URL is $configuredUrl, but baseline expects '
      '$expectedRepository. Point RGB_SDK_RN_PATH at the intended upstream '
      'checkout.',
    );
  }

  return upstream;
}

String? _readRemoteCommit(
  Directory rnRoot,
  String remoteName,
  String remoteRef,
  List<String> errors,
) {
  final result = Process.runSync('git', <String>[
    '-C',
    rnRoot.path,
    'ls-remote',
    remoteName,
    remoteRef,
  ]);
  if (result.exitCode != 0) {
    errors.add(
      'Unable to check RN upstream drift with git ls-remote $remoteName '
      '$remoteRef: ${result.stderr}',
    );
    return null;
  }
  final output = result.stdout.toString().trim();
  if (output.isEmpty) {
    errors.add('RN upstream $remoteName does not expose $remoteRef.');
    return null;
  }
  return output.split(RegExp(r'\s+')).first;
}

String? _readFetchedCommit(
  Directory rnRoot,
  String remoteName,
  String remoteRef,
) {
  final remoteBranch = remoteRef.startsWith('refs/heads/')
      ? '$remoteName/${remoteRef.substring('refs/heads/'.length)}'
      : remoteRef;
  final result = Process.runSync('git', <String>[
    '-C',
    rnRoot.path,
    'rev-parse',
    '--verify',
    '$remoteBranch^{commit}',
  ]);
  if (result.exitCode != 0) return null;
  return result.stdout.toString().trim();
}

String? _readGitConfig(Directory root, String key) {
  final result = Process.runSync('git', <String>[
    '-C',
    root.path,
    'config',
    '--get',
    key,
  ]);
  if (result.exitCode != 0) return null;
  return result.stdout.toString().trim();
}

bool _sameRepository(String configured, String expected) {
  String normalize(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('git@github.com:')) {
      normalized = 'https://github.com/${normalized.substring(15)}';
    }
    if (normalized.endsWith('.git')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized.toLowerCase();
  }

  return normalize(configured) == normalize(expected);
}

void _validateRnBaseline(
  Directory rnRoot,
  Map<String, Object?> baseline,
  List<String> errors,
) {
  final expectedCommit = _nestedString(baseline, <String>[
    'reactNative',
    'commit',
  ]);
  final expectedPackage = _nestedString(baseline, <String>[
    'reactNative',
    'package',
  ]);
  final expectedVersion = _nestedString(baseline, <String>[
    'reactNative',
    'version',
  ]);
  final expectedCoreVersion = _nestedString(baseline, <String>[
    'core',
    'version',
  ]);
  final expectedRlnVersion = _nestedString(baseline, <String>[
    'rln',
    'version',
  ]);
  if (<String?>[
    expectedCommit,
    expectedPackage,
    expectedVersion,
    expectedCoreVersion,
    expectedRlnVersion,
  ].any((value) => value == null || value.isEmpty)) {
    errors.add(
      'release_baseline.json must define the RN commit/package/version, '
      'core version, and RLN version.',
    );
    return;
  }

  final result = Process.runSync('git', <String>[
    '-C',
    rnRoot.path,
    'rev-parse',
    'HEAD',
  ]);
  if (result.exitCode != 0) {
    errors.add('Unable to read RN reference git commit: ${result.stderr}');
    return;
  }

  final actual = result.stdout.toString().trim();
  if (actual != expectedCommit) {
    errors.add(
      'RN reference commit mismatch. Expected $expectedCommit, found $actual at '
      '${rnRoot.path}. Update the RN checkout or deliberately update the '
      'release baseline after a new parity audit.',
    );
  }

  final packageJson = _readJsonObject(
    File('${rnRoot.path}/package.json'),
    errors,
  );
  if (packageJson['name'] != expectedPackage) {
    errors.add(
      'RN package mismatch. Expected $expectedPackage, found '
      '${packageJson['name']}.',
    );
  }
  if (packageJson['version'] != expectedVersion) {
    errors.add(
      'RN version mismatch. Expected $expectedVersion, found '
      '${packageJson['version']}.',
    );
  }
  final dependencies = packageJson['dependencies'];
  final actualCoreVersion = dependencies is Map<String, Object?>
      ? dependencies['@utexo/rgb-sdk-core']
      : null;
  if (actualCoreVersion != expectedCoreVersion) {
    errors.add(
      'RN core dependency mismatch. Expected $expectedCoreVersion, found '
      '$actualCoreVersion.',
    );
  }
  _validateCorePackageBaseline(rnRoot, baseline, errors);

  final androidBuild = File('${rnRoot.path}/android/build.gradle');
  final androidSource = androidBuild.existsSync()
      ? androidBuild.readAsStringSync()
      : '';
  final expectedCoordinate =
      'com.utexo:rgb-lightning-node-android:$expectedRlnVersion';
  if (!androidSource.contains(expectedCoordinate)) {
    errors.add(
      'RN Android bridge does not pin baseline artifact $expectedCoordinate.',
    );
  }

  final downloadScript = File(
    '${rnRoot.path}/scripts/download-rln-bindings.js',
  );
  final downloadSource = downloadScript.existsSync()
      ? downloadScript.readAsStringSync()
      : '';
  if (!downloadSource.contains("const VERSION = '$expectedRlnVersion';")) {
    errors.add(
      'RN iOS artifact downloader does not pin RLN $expectedRlnVersion.',
    );
  }
}

void _validateCorePackageBaseline(
  Directory rnRoot,
  Map<String, Object?> baseline,
  List<String> errors,
) {
  final core = baseline['core'];
  if (core is! Map<String, Object?>) {
    errors.add('release_baseline.json/core must be an object.');
    return;
  }
  final version = core['version'];
  final archiveUrl = core['archiveUrl'];
  final archiveSize = core['archiveSizeBytes'];
  final archiveSha256 = core['archiveSha256'];
  final integrity = core['integritySha512'];
  final extracted = core['extractedFiles'];
  if (version is! String ||
      archiveUrl is! String ||
      archiveSize is! int ||
      archiveSize <= 0 ||
      archiveSha256 is! String ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(archiveSha256) ||
      integrity is! String ||
      !integrity.startsWith('sha512-') ||
      extracted is! Map<String, Object?>) {
    errors.add(
      'release_baseline.json/core must pin version, archive URL/size/SHA-256, '
      'npm SHA-512 integrity, and extracted file hashes.',
    );
    return;
  }
  const requiredFiles = <String>{
    'package.json',
    'dist/index.d.ts',
    'dist/index.mjs',
  };
  if (extracted.keys.toSet().difference(requiredFiles).isNotEmpty ||
      requiredFiles.difference(extracted.keys.toSet()).isNotEmpty ||
      extracted.values.any(
        (value) =>
            value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
      )) {
    errors.add(
      'release_baseline.json/core.extractedFiles must contain exact SHA-256 '
      'entries for package.json, dist/index.d.ts, and dist/index.mjs.',
    );
  }

  final yarnLock = File('${rnRoot.path}/yarn.lock');
  final yarnSource = yarnLock.existsSync() ? yarnLock.readAsStringSync() : '';
  final expectedLockEntry =
      '"@utexo/rgb-sdk-core@$version":\n'
      '  version "$version"\n'
      '  resolved "$archiveUrl"\n'
      '  integrity $integrity';
  if (!yarnSource.contains(expectedLockEntry)) {
    errors.add(
      'RN yarn.lock does not pin the audited core archive URL and SHA-512 '
      'integrity from release_baseline.json.',
    );
  }

  final tarballPath = Platform.environment['RGB_SDK_CORE_TARBALL'];
  if (tarballPath == null || tarballPath.trim().isEmpty) return;
  final tarball = File(tarballPath.trim());
  if (!tarball.existsSync()) {
    errors.add('RGB_SDK_CORE_TARBALL does not exist: ${tarball.path}.');
    return;
  }
  final bytes = tarball.readAsBytesSync();
  if (bytes.length != archiveSize ||
      sha256.convert(bytes).toString() != archiveSha256) {
    errors.add(
      'RGB_SDK_CORE_TARBALL does not match the pinned core archive size and '
      'SHA-256.',
    );
    return;
  }
  for (final entry in extracted.entries) {
    final result = Process.runSync(
      'tar',
      <String>['-xOf', tarball.path, 'package/${entry.key}'],
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    if (result.exitCode != 0 || result.stdout is! List<int>) {
      errors.add('Unable to extract package/${entry.key} from core tarball.');
      continue;
    }
    final digest = sha256.convert(result.stdout as List<int>).toString();
    if (digest != entry.value) {
      errors.add(
        'Core archive package/${entry.key} hash mismatch: expected '
        '${entry.value}, found $digest.',
      );
    }
  }
}

String? _nestedString(Map<String, Object?> source, List<String> path) {
  Object? value = source;
  for (final segment in path) {
    if (value is! Map<String, Object?>) return null;
    value = value[segment];
  }
  return value is String ? value : null;
}

void _validateLowLevelNativeMethods(
  Directory root,
  Directory rnRoot,
  List<String> errors,
) {
  final rnSignatures = _extractRnNativeRgbSignatures(
    File('${rnRoot.path}/src/binding/NativeRgb.ts'),
    errors,
  );
  final pigeonSignatures = _extractPigeonHostApiSignatures(
    File('${root.path}/pigeons/rln_api.dart'),
    errors,
  );
  final rnMethods = rnSignatures.keys.toSet();
  final pigeonMethods = pigeonSignatures.keys.toSet();
  final matrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/rln_methods.json'),
    errors,
  );
  final flutterHostApis = _matrixStringField(matrix, 'hostApi');
  // OCT-038: RLN already implements contract import, but RN beta.39 has no
  // wrapper for it. Keep this one reviewed Flutter extension explicit and
  // signature-checked; other unmatched methods remain parity failures.
  // ROOT-01: unpublished durable on-chain operation protocol. This extension
  // requires separately qualified native artifacts; old artifacts fail closed.
  const recoveryExtensions = <String>{
    'rlnPrepareOnchainSend',
    'rlnCommitOnchainSend',
    'rlnOnchainSendStatus',
    'rlnCancelOnchainSend',
  };
  const flutterExtensions = <String>{
    'rlnImportRgbContract',
    ...recoveryExtensions,
  };
  for (final method in flutterExtensions) {
    if (rnMethods.contains(method)) {
      errors.add(
        'RN now exposes $method; review OCT-038 and remove the stale '
        'Flutter-only extension.',
      );
    }
    if (!flutterHostApis.contains(method) || !pigeonMethods.contains(method)) {
      errors.add(
        'Reviewed Flutter extension $method is missing from inventory or Pigeon.',
      );
    }
  }
  for (final method in recoveryExtensions) {
    final signature = pigeonSignatures[method];
    const inputName = 'requestJson';
    if (signature != null &&
        (signature.returnType != _TypeShape.fromDart('String') ||
            signature.parameters.length != 2 ||
            signature.parameters[0].name != 'nodeId' ||
            signature.parameters[0].type != _TypeShape.fromDart('int') ||
            signature.parameters[1].name != inputName ||
            signature.parameters[1].type != _TypeShape.fromDart('String'))) {
      errors.add('ROOT-01 durable send extension signature changed: $method.');
    }
  }
  final importSignature = pigeonSignatures['rlnImportRgbContract'];
  final importNames = <String>['nodeId', 'contractBase64', 'expectedAssetId'];
  final importTypes = <String>['int', 'String', 'String'];
  if (importSignature != null &&
      (importSignature.returnType != _TypeShape.fromDart('RlnWireResponse') ||
          importSignature.parameters.length != importNames.length ||
          List<int>.generate(importNames.length, (index) => index).any(
            (index) =>
                importSignature.parameters.length <= index ||
                importSignature.parameters[index].name != importNames[index] ||
                importSignature.parameters[index].type !=
                    _TypeShape.fromDart(importTypes[index]),
          ))) {
    errors.add(
      'Reviewed Flutter import extension signature changed; re-audit OCT-038.',
    );
  }

  final missing = rnMethods.difference(flutterHostApis).toList()..sort();
  final stale =
      flutterHostApis
          .difference(rnMethods)
          .difference(flutterExtensions)
          .toList()
        ..sort();
  final missingFromPigeon = rnMethods.difference(pigeonMethods).toList()
    ..sort();
  final stalePigeon =
      pigeonMethods
          .where((method) => method.startsWith('rln'))
          .toSet()
          .difference(rnMethods)
          .difference(flutterExtensions)
          .toList()
        ..sort();

  for (final method in missing) {
    errors.add('RN NativeRgb.$method is missing from rln_methods.json.');
  }
  for (final method in stale) {
    errors.add('rln_methods.json hostApi $method is not in RN NativeRgb.ts.');
  }
  for (final method in missingFromPigeon) {
    errors.add('RN NativeRgb.$method is missing from Pigeon RlnHostApi.');
  }
  for (final method in stalePigeon) {
    errors.add('Pigeon RlnHostApi.$method is not in RN NativeRgb.ts.');
  }

  for (final method in rnMethods.intersection(pigeonMethods)) {
    final rn = rnSignatures[method]!;
    final pigeon = pigeonSignatures[method]!;
    if (rn.returnType != pigeon.returnType) {
      errors.add(
        'NativeRgb.$method return mismatch. RN ${rn.returnType.label}, '
        'Pigeon ${pigeon.returnType.label}.',
      );
    }
    // RLN 0.16's request-based external unlock supports Ethereum validation.
    // RN's flat bridge omits it; this reviewed nullable tail is the only delta.
    final externalEthRpc =
        method == 'rlnUnlockNodeWithNativeExternalSigner' &&
        pigeon.parameters.length == rn.parameters.length + 1 &&
        pigeon.parameters.last.name == 'ethRpcUrl' &&
        pigeon.parameters.last.type == _TypeShape.fromDart('String?');
    if (rn.parameters.length != pigeon.parameters.length && !externalEthRpc) {
      errors.add(
        'NativeRgb.$method parameter count mismatch. RN '
        '${rn.parameters.length}, Pigeon ${pigeon.parameters.length}.',
      );
      continue;
    }
    for (var index = 0; index < rn.parameters.length; index++) {
      final rnParam = rn.parameters[index];
      final pigeonParam = pigeon.parameters[index];
      if (rnParam.name != pigeonParam.name) {
        errors.add(
          'NativeRgb.$method parameter ${index + 1} name mismatch. RN '
          '${rnParam.name}, Pigeon ${pigeonParam.name}.',
        );
      }
      if (rnParam.type != pigeonParam.type) {
        errors.add(
          'NativeRgb.$method parameter ${rnParam.name} type mismatch. RN '
          '${rnParam.type.label}, Pigeon ${pigeonParam.type.label}.',
        );
      }
    }
  }
}

Map<String, _MethodSignature> _extractRnNativeRgbSignatures(
  File file,
  List<String> errors,
) {
  if (!file.existsSync()) {
    errors.add('Missing RN NativeRgb source: ${file.path}');
    return <String, _MethodSignature>{};
  }
  final source = file.readAsStringSync();
  final methods = <String, _MethodSignature>{};
  final methodRegex = RegExp(
    r'^\s*(rln[A-Za-z0-9_]+)\s*\(([\s\S]*?)\)\s*:\s*Promise<([^>]+)>;',
    multiLine: true,
  );
  for (final match in methodRegex.allMatches(source)) {
    final name = match.group(1)!;
    methods[name] = _MethodSignature(
      name: name,
      returnType: _TypeShape.fromRn(match.group(3)!.trim()),
      parameters: _parseRnParameters(match.group(2)!),
    );
  }
  return methods;
}

Map<String, _MethodSignature> _extractPigeonHostApiSignatures(
  File file,
  List<String> errors,
) {
  if (!file.existsSync()) {
    errors.add('Missing Pigeon source: ${file.path}');
    return <String, _MethodSignature>{};
  }
  final source = file.readAsStringSync();
  final methods = <String, _MethodSignature>{};
  final methodRegex = RegExp(
    r'^\s*([A-Za-z0-9_<>, ?]+)\s+(rln[A-Za-z0-9_]+)\s*\(([\s\S]*?)\);',
    multiLine: true,
  );
  for (final match in methodRegex.allMatches(source)) {
    final name = match.group(2)!;
    methods[name] = _MethodSignature(
      name: name,
      returnType: _TypeShape.fromDart(match.group(1)!.trim()),
      parameters: _parseDartParameters(match.group(3)!),
    );
  }
  return methods;
}

List<_ParameterShape> _parseRnParameters(String source) {
  return _splitParameters(source)
      .map((raw) {
        final match = RegExp(
          r'^\s*([A-Za-z_][A-Za-z0-9_]*)(\?)?\s*:\s*(.+?)\s*,?\s*$',
        ).firstMatch(raw);
        if (match == null) return null;
        final optional = match.group(2) != null;
        final typeSource = match.group(3)!.trim();
        return _ParameterShape(
          name: match.group(1)!,
          type: _TypeShape.fromRn(optional ? '$typeSource | null' : typeSource),
        );
      })
      .whereType<_ParameterShape>()
      .toList(growable: false);
}

List<_ParameterShape> _parseDartParameters(String source) {
  return _splitParameters(source)
      .map((raw) {
        final match = RegExp(
          r'^\s*([A-Za-z0-9_<>, ?]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*,?\s*$',
        ).firstMatch(raw);
        if (match == null) return null;
        return _ParameterShape(
          name: match.group(2)!,
          type: _TypeShape.fromDart(match.group(1)!.trim()),
        );
      })
      .whereType<_ParameterShape>()
      .toList(growable: false);
}

List<String> _splitParameters(String source) {
  return source
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

void _validateTypedPigeonWire(Directory root, List<String> errors) {
  final pigeon = File('${root.path}/pigeons/rln_api.dart');
  if (!pigeon.existsSync()) {
    errors.add('Missing Pigeon source: ${pigeon.path}');
    return;
  }

  final source = pigeon.readAsStringSync();
  if (!source.contains('class RlnWireResponse')) {
    errors.add('Pigeon source must define typed RlnWireResponse wire DTO.');
  }
  for (final forbidden in <String>[
    'Map<Object?, Object?>',
    'List<Map<Object?, Object?>>',
  ]) {
    if (source.contains(forbidden)) {
      errors.add(
        'Pigeon source still exposes broad $forbidden; use RlnWireResponse '
        'and strict Dart decoding at the client boundary.',
      );
    }
  }
}

final class _MethodSignature {
  const _MethodSignature({
    required this.name,
    required this.returnType,
    required this.parameters,
  });

  final String name;
  final _TypeShape returnType;
  final List<_ParameterShape> parameters;
}

final class _ParameterShape {
  const _ParameterShape({required this.name, required this.type});

  final String name;
  final _TypeShape type;
}

final class _TypeShape {
  const _TypeShape(this.kind, {this.nullable = false});

  factory _TypeShape.fromRn(String source) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    final nullable =
        normalized.contains('null') || normalized.contains('undefined');
    final nonNull = normalized
        .replaceAll(RegExp(r'\s*\|\s*null'), '')
        .replaceAll(RegExp(r'\s*\|\s*undefined'), '')
        .replaceAll('?', '')
        .trim();
    return _TypeShape(_rnKind(nonNull), nullable: nullable);
  }

  factory _TypeShape.fromDart(String source) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == 'Object?') {
      return const _TypeShape('map');
    }
    final nullable = normalized.endsWith('?');
    final nonNull = nullable
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    return _TypeShape(_dartKind(nonNull), nullable: nullable);
  }

  final String kind;
  final bool nullable;

  String get label => nullable ? '$kind?' : kind;

  @override
  bool operator ==(Object other) {
    return other is _TypeShape &&
        other.kind == kind &&
        other.nullable == nullable;
  }

  @override
  int get hashCode => Object.hash(kind, nullable);

  static String _rnKind(String source) {
    return switch (source) {
      'string' => 'string',
      'number' => 'number',
      'boolean' => 'bool',
      'void' => 'void',
      'object' => 'map',
      '{ burn: boolean; consignment: boolean; bfa: boolean; }' => 'map',
      'object[]' => 'list-map',
      'string[]' => 'list-string',
      'number[]' => 'list-number',
      'any' => 'map',
      _ => source,
    };
  }

  static String _dartKind(String source) {
    return switch (source) {
      'String' => 'string',
      'int' || 'double' => 'number',
      'bool' => 'bool',
      'void' => 'void',
      'Map<Object?, Object?>' => 'map',
      'Object' => 'map',
      'RlnWireResponse' => 'map',
      'RlnRefreshTransfersData' => 'map',
      'List<Map<Object?, Object?>>' => 'list-map',
      'List<RlnWireResponse>' => 'list-map',
      'List<String>' => 'list-string',
      'List<int>' => 'list-number',
      _ => source,
    };
  }
}

void _validateWalletMethods(
  Directory root,
  Directory rnRoot,
  List<String> errors,
) {
  final rnMethods = _extractRnWalletMethods(
    File('${rnRoot.path}/src/wallet/utexo-wallet.ts'),
    errors,
  );
  final matrix = _readJsonObject(
    File('${root.path}/tool/test_matrix/wallet_methods.json'),
    errors,
  );
  final walletMatrixIds = _matrixIds(matrix);
  final manifest = _readJsonObject(
    File('${root.path}/tool/rn_parity_manifest.json'),
    errors,
  );
  final advancedAliases = _stringMap(
    manifest,
    'advancedWalletMethodAliases',
    errors,
  );
  _validateRnWalletSurfaceFingerprint(rnRoot, manifest, errors);
  _validateAdvancedWalletAliases(root, advancedAliases, errors);
  _validateCanonicalWalletReturnShapes(
    root,
    rnRoot,
    advancedAliases.keys.toSet(),
    errors,
  );

  final missing =
      rnMethods
          .difference(walletMatrixIds)
          .difference(advancedAliases.keys.toSet())
          .toList()
        ..sort();
  for (final method in missing) {
    errors.add('RN UTEXOWallet.$method is missing from wallet_methods.json.');
  }

  for (final method in advancedAliases.keys) {
    if (!rnMethods.contains(method)) {
      errors.add(
        'advancedWalletMethodAliases contains stale RN method $method.',
      );
    }
  }
}

void _validateRnWalletSurfaceFingerprint(
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final file = File('${rnRoot.path}/src/wallet/utexo-wallet.ts');
  final actual = _rnWalletSurfaceFingerprint(file, errors);
  final expected = manifest['walletSurfaceSha256'];
  if (expected is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
    errors.add(
      'rn_parity_manifest.json/walletSurfaceSha256 must be a SHA-256 digest; '
      'current audited surface is ${actual ?? 'unavailable'}.',
    );
    return;
  }
  if (actual != null && actual != expected) {
    errors.add(
      'RN UTEXOWallet parameter/return surface changed. Expected $expected, '
      'found $actual. Audit every changed method shape before updating the '
      'fingerprint.',
    );
  }
}

String? _rnWalletSurfaceFingerprint(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN wallet source: ${file.path}');
    return null;
  }
  final source = file.readAsStringSync();
  final classMatch = RegExp(
    r'export\s+class\s+UTEXOWallet\b',
  ).firstMatch(source);
  if (classMatch == null) {
    errors.add('RN source does not declare export class UTEXOWallet.');
    return null;
  }
  final classOpen = source.indexOf('{', classMatch.end);
  final classClose = _matchingDelimiter(source, classOpen, 123, 125);
  if (classOpen < 0 || classClose < 0) {
    errors.add('RN UTEXOWallet class body could not be parsed.');
    return null;
  }
  final classSource = source.substring(classOpen + 1, classClose);
  final methodRegex = RegExp(
    r'^  (?! )(?:(?:async|public)\s+)*([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  final signatures = <String>[];
  final seen = <String>{};
  for (final match in methodRegex.allMatches(classSource)) {
    final name = match.group(1)!;
    if (name == 'constructor') continue;
    if (!seen.add(name)) {
      errors.add('RN UTEXOWallet declares overloaded method $name.');
      continue;
    }
    final absoluteStart = classOpen + 1 + match.start;
    final opening = source.indexOf('(', absoluteStart);
    final closing = _matchingDelimiter(source, opening, 40, 41);
    final returnType = _rnWalletReturnType(source, name);
    if (opening < 0 || closing < 0 || returnType == null) {
      errors.add('Unable to parse complete RN UTEXOWallet.$name signature.');
      continue;
    }
    final parameters = source.substring(opening + 1, closing);
    signatures.add(
      '$name(${_normalizeTypeScriptSurface(parameters)}):'
      '${_normalizeTypeScriptSurface(returnType)}',
    );
  }
  signatures.sort();
  return sha256.convert(utf8.encode(signatures.join('\n'))).toString();
}

String _normalizeTypeScriptSurface(String source) {
  return source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//[^\n]*'), '')
      .replaceAll(RegExp(r'\s+'), '');
}

void _validateCanonicalWalletReturnShapes(
  Directory root,
  Directory rnRoot,
  Set<String> advancedAliases,
  List<String> errors,
) {
  final rnSource = File(
    '${rnRoot.path}/src/wallet/utexo-wallet.ts',
  ).readAsStringSync();
  final dartSource = <String>[
    'lib/src/wallet/utexo_wallet.dart',
    'lib/src/wallet/utexo_wallet_bfa.dart',
    'lib/src/wallet/utexo_wallet_lifecycle.dart',
    'lib/src/wallet/utexo_wallet_lsp_apay.dart',
    'lib/src/wallet/utexo_wallet_onchain.dart',
    'lib/src/wallet/utexo_wallet_lightning.dart',
  ].map((path) => File('${root.path}/$path').readAsStringSync()).join('\n');
  const expected = <String, (String, String)>{
    'burn': ('BurnResult', 'Future<BurnResult>'),
    // RN infers this return; the BfaCapabilities decoder and contract tests
    // verify all three boolean fields instead of pretending it is annotated.
    'getBfaCapabilities': ('<inferred>', 'Future<BfaCapabilities>'),
    'getConsignment': ('string', 'Future<String>'),
    'getConsignmentPath': ('string', 'Future<String>'),
    'init': ('void', 'Future<void>'),
    'unlock': ('void', 'Future<void>'),
    'reinit': ('void', 'Future<void>'),
    'shutdown': ('void', 'Future<void>'),
    'destroy': ('void', 'Future<void>'),
    'initialize': ('void', 'Future<void>'),
    'getNetwork': ('Network', 'String'),
    'dispose': ('void', 'Future<void>'),
    'isDisposed': ('boolean', 'bool'),
    'getBtcBalance': ('BtcBalance', 'Future<CoreBtcBalance>'),
    'getAddress': ('string', 'Future<String>'),
    'rotateVanillaAddress': ('string', 'Future<String>'),
    'listUnspents': ('Unspent[]', 'Future<List<CoreUnspent>>'),
    'createUtxos': ('number', 'Future<int>'),
    'listAssets': ('ListAssets', 'Future<CoreListAssets>'),
    'getAssetBalance': ('AssetBalance', 'Future<CoreAssetBalance>'),
    'issueAssetNia': ('AssetNIA', 'Future<CoreAssetNia>'),
    'issueAssetIfa': ('AssetIfa', 'Future<CoreAssetIfa>'),
    'inflate': ('{ txid: string }', 'Future<InflateAssetIfaResponse>'),
    'sendBtc': ('string', 'Future<String>'),
    'blindReceive': ('InvoiceReceiveData', 'Future<CoreInvoiceReceiveData>'),
    'witnessReceive': ('InvoiceReceiveData', 'Future<CoreInvoiceReceiveData>'),
    'listTransactions': ('Transaction[]', 'Future<List<CoreTransaction>>'),
    'listTransactionsByTxid': (
      'Transaction[]',
      'Future<List<CoreTransaction>>',
    ),
    'listTransfers': ('Transfer[]', 'Future<List<CoreTransfer>>'),
    'listTransfersByTxid': ('Transfer[]', 'Future<List<CoreTransfer>>'),
    'failTransfers': ('boolean', 'Future<bool>'),
    'refreshWallet': ('void', 'Future<void>'),
    'refreshTransfers': (
      'RefreshTransfersResult',
      'Future<RefreshTransfersResult>',
    ),
    'syncWallet': ('void', 'Future<void>'),
    'estimateFeeRate': (
      'GetFeeEstimationResponse',
      'Future<FeeEstimationResponse>',
    ),
    'createBackup': ('WalletBackupResponse', 'Future<WalletBackupResponse>'),
    'signMessage': ('string', 'Future<String>'),
    'verifyMessage': ('boolean', 'Future<bool>'),
    'createLightningInvoice': (
      'LightningReceiveRequest',
      'Future<LightningReceiveRequest>',
    ),
    'createHodlInvoice': ('LightningInvoice', 'Future<HodlInvoice>'),
    'claimHodlInvoice': ('HodlInvoiceResult', 'Future<HodlInvoiceResult>'),
    'cancelHodlInvoice': ('HodlInvoiceResult', 'Future<HodlInvoiceResult>'),
    'listPayments': ('LightningPayment[]', 'Future<List<LightningPayment>>'),
    'apayNew': ('ApayNewResponse', 'Future<ApayNewResponse>'),
    'apayNewWithAddress': ('ApayNewResponse', 'Future<ApayNewResponse>'),
    'createLsp': ('UtexoLsp', 'Future<UtexoLsp>'),
    'getLspConfig': (
      '{ baseUrl: string | null; bearerToken: string | null }',
      'UtexoLspConfig',
    ),
    'getLightningReceiveStatus': (
      'RlnInvoiceStatus',
      'Future<RlnInvoiceStatusValue>',
    ),
    'getLightningSendStatus': (
      'RlnPaymentStatus | null',
      'Future<RlnPaymentStatusValue?>',
    ),
    'payLightningInvoice': (
      'LightningSendRequest',
      'Future<LightningSendRequest>',
    ),
    'listLightningPayments': (
      'ListLightningPaymentsResponse',
      'Future<ListLightningPaymentsResponse>',
    ),
    'onchainReceive': (
      'OnchainReceiveResponse',
      'Future<OnchainReceiveResponse>',
    ),
    'onchainSend': ('OnchainSendResponse', 'Future<OnchainSendResponse>'),
    'listOnchainTransfers': ('Transfer[]', 'Future<List<CoreTransfer>>'),
    'getNodeInfo': ('LightningNodeInfo', 'Future<WalletNodeInfo>'),
    'getNetworkInfo': ('LightningNetworkInfo', 'Future<WalletNetworkInfo>'),
    'connectPeer': ('void', 'Future<void>'),
    'listPeers': ('LightningPeer[]', 'Future<List<LightningPeer>>'),
    'disconnectPeer': ('void', 'Future<void>'),
    'listChannels': ('LightningChannel[]', 'Future<List<LightningChannel>>'),
    'openChannel': ('OpenChannelResult', 'Future<LightningChannelOpenResult>'),
    'closeChannel': ('void', 'Future<void>'),
    'getChannelId': ('string', 'Future<String>'),
    'keysend': ('SendPaymentResult', 'Future<SendPaymentResult>'),
    'decodeLnInvoice': ('DecodedLnInvoice', 'Future<DecodedLightningInvoice>'),
    'invoiceStatus': ('RlnInvoiceStatus', 'Future<RlnInvoiceStatusValue>'),
    'checkIndexerUrl': (
      'RlnCheckIndexerUrlResponse',
      'Future<IndexerCheckResponse>',
    ),
    'checkProxyEndpoint': ('void', 'Future<void>'),
    'vssClearFence': ('void', 'Future<void>'),
    'backupNow': ('number', 'Future<int>'),
  };

  final rnMethods = _extractRnWalletMethods(
    File('${rnRoot.path}/src/wallet/utexo-wallet.ts'),
    errors,
  );
  final covered = expected.keys.toSet()..addAll(advancedAliases);
  for (final method in rnMethods.difference(covered).toList()..sort()) {
    errors.add(
      'RN UTEXOWallet.$method has no canonical return-shape contract.',
    );
  }
  for (final method in covered.difference(rnMethods).toList()..sort()) {
    errors.add('Canonical wallet contract contains stale method $method.');
  }

  final dartMethodPattern = RegExp(
    r'^\s{2}([A-Za-z][A-Za-z0-9_<>, ?]*)\s+'
    r'([A-Za-z][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  final dartReturns = <String, String>{};
  for (final match in dartMethodPattern.allMatches(dartSource)) {
    final method = match.group(2)!;
    if (!method.startsWith('_')) {
      dartReturns[method] = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  for (final entry in expected.entries) {
    final rnReturn = _rnWalletReturnType(rnSource, entry.key);
    if (rnReturn != entry.value.$1) {
      errors.add(
        'RN UTEXOWallet.${entry.key} return changed: expected '
        '${entry.value.$1}, found ${rnReturn ?? 'no declaration'}.',
      );
    }
    final dartReturn = dartReturns[entry.key];
    if (dartReturn != entry.value.$2) {
      errors.add(
        'Flutter UtexoWallet.${entry.key} must map to ${entry.value.$2}; '
        'found ${dartReturn ?? 'no declaration'}.',
      );
    }
  }

  const expectedDartParameters = <String, String>{
    'getBtcBalance': '',
    'listUnspents': '',
    'createUtxos': '{boolupTo=true,int?num,int?size,doublefeeRate=1,}',
    'listAssets': '',
    'listTransactions': '',
    'refreshWallet': '',
    'refreshTransfers': '{boolskipSync=false,}',
    'createLightningInvoice':
        '{int?amountSats,LightningAsset?asset,intexpirySeconds=3600,'
        'int?minFinalCltvExpiryDelta,String?descriptionHash,}',
    'payLightningInvoice':
        '{requiredStringlnInvoice,int?amount,String?assetId,'
        'int?assetAmount,}',
    'onchainReceive': 'RgbInvoiceRequestrequest,',
    'openChannel':
        '{requiredStringpeerPubkey,requiredintcapacitySat,intpushMsat=0,'
        'boolisPublic=false,boolwithAnchors=true,int?feeBaseMsat,'
        'int?feeProportionalMillionths,String?temporaryChannelId,'
        'String?assetId,int?assetLocalAmount,int?pushAssetAmount,'
        'String?virtualOpenMode,}',
  };
  for (final entry in expectedDartParameters.entries) {
    final actual = _dartWalletParameters(dartSource, entry.key);
    if (actual != entry.value) {
      errors.add(
        'Flutter UtexoWallet.${entry.key} input contract changed: expected '
        '${entry.value}, found ${actual ?? 'no declaration'}.',
      );
    }
  }

  final walletTypes = File(
    '${root.path}/lib/src/wallet/utexo_wallet_types.dart',
  ).readAsStringSync();
  if (!RegExp(
    r'class RgbInvoiceRequest[\s\S]*?final bool witness;',
  ).hasMatch(walletTypes)) {
    errors.add(
      'RgbInvoiceRequest must preserve the RN onchainReceive witness option.',
    );
  }
}

String? _dartWalletParameters(String source, String method) {
  final declaration = RegExp(
    '^  [A-Za-z][A-Za-z0-9_<>, ?]*\\s+${RegExp.escape(method)}\\s*\\(',
    multiLine: true,
  ).firstMatch(source);
  if (declaration == null) return null;
  final opening = source.indexOf('(', declaration.start);
  final closing = _matchingDelimiter(source, opening, 40, 41);
  if (closing < 0) return null;
  return source.substring(opening + 1, closing).replaceAll(RegExp(r'\s+'), '');
}

String? _rnWalletReturnType(String source, String method) {
  final declaration = RegExp(
    '^  (?! )(?:async\\s+)?${RegExp.escape(method)}\\s*\\(',
    multiLine: true,
  ).firstMatch(source);
  if (declaration == null) return null;
  final openingParenthesis = source.indexOf('(', declaration.start);
  final closingParenthesis = _matchingDelimiter(
    source,
    openingParenthesis,
    40,
    41,
  );
  if (closingParenthesis < 0) return null;
  final suffix = source.substring(closingParenthesis + 1);
  final annotation = RegExp(r'^\s*:').firstMatch(suffix);
  if (annotation == null) {
    return suffix.trimLeft().startsWith('{') ? '<inferred>' : null;
  }
  final colon = closingParenthesis + 1 + annotation.end - 1;
  final returnStart = colon + 1;
  final promise = source.indexOf('Promise<', returnStart);
  if (promise < 0 || promise - returnStart > 16) {
    var index = returnStart;
    while (index < source.length && source[index].trim().isEmpty) {
      index += 1;
    }
    if (index >= source.length) return null;
    if (source[index] == '{') {
      final closing = _matchingDelimiter(source, index, 123, 125);
      if (closing < 0) return null;
      return source
          .substring(index, closing + 1)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    final body = source.indexOf('{', index);
    if (body < 0) return null;
    return source.substring(index, body).replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  final openingAngle = source.indexOf('<', promise);
  final closingAngle = _matchingDelimiter(source, openingAngle, 60, 62);
  if (closingAngle < 0) return null;
  return source
      .substring(openingAngle + 1, closingAngle)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _matchingDelimiter(
  String source,
  int openingIndex,
  int openingCodeUnit,
  int closingCodeUnit,
) {
  if (openingIndex < 0) return -1;
  var depth = 0;
  for (var index = openingIndex; index < source.length; index++) {
    final codeUnit = source.codeUnitAt(index);
    if (codeUnit == openingCodeUnit) depth += 1;
    if (codeUnit == closingCodeUnit) {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  return -1;
}

void _validateAdvancedWalletAliases(
  Directory root,
  Map<String, String> aliases,
  List<String> errors,
) {
  final advanced = File('${root.path}/lib/rgb_sdk_flutter_advanced.dart');
  if (!advanced.existsSync()) {
    errors.add('Missing advanced Dart entrypoint: ${advanced.path}');
    return;
  }
  final source = advanced.readAsStringSync();
  for (final entry in aliases.entries) {
    final parts = entry.value.split('.');
    if (parts.length != 2 ||
        parts.any((part) => part.trim().isEmpty) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(parts[0]) ||
        !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(parts[1])) {
      errors.add(
        'advancedWalletMethodAliases/${entry.key} must be Extension.method.',
      );
      continue;
    }
    final extensionName = parts[0];
    final methodName = parts[1];
    if (!RegExp(
      'extension\\s+${RegExp.escape(extensionName)}\\s+on\\s+UtexoWallet',
    ).hasMatch(source)) {
      errors.add(
        'advancedWalletMethodAliases/${entry.key} references missing '
        'extension $extensionName.',
      );
    }
    if (!RegExp(
      '[A-Za-z0-9_<>, ?]+\\s+${RegExp.escape(methodName)}\\s*\\(',
    ).hasMatch(source)) {
      errors.add(
        'advancedWalletMethodAliases/${entry.key} references missing '
        'method $methodName.',
      );
    }
  }
}

Set<String> _extractRnWalletMethods(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN wallet source: ${file.path}');
    return <String>{};
  }

  final source = file.readAsStringSync();
  final methods = <String>{};
  final classMatch = RegExp(
    r'export\s+class\s+UTEXOWallet\b',
  ).firstMatch(source);
  if (classMatch == null) {
    errors.add('RN source does not declare export class UTEXOWallet.');
    return methods;
  }
  final classOpen = source.indexOf('{', classMatch.end);
  final classClose = _matchingDelimiter(source, classOpen, 123, 125);
  if (classOpen < 0 || classClose < 0) {
    errors.add('RN UTEXOWallet class body could not be parsed.');
    return methods;
  }
  final classSource = source.substring(classOpen + 1, classClose);
  final methodRegex = RegExp(
    r'^  (?! )(?:(?:async|public)\s+)*([A-Za-z_][A-Za-z0-9_]*)\s*\(',
    multiLine: true,
  );
  for (final match in methodRegex.allMatches(classSource)) {
    final method = match.group(1)!;
    if (method != 'constructor') methods.add(method);
  }

  return methods;
}

void _validateRuntimeExports(
  Directory root,
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final rnExports = _extractRnRuntimeExports(
    File('${rnRoot.path}/src/index.ts'),
    errors,
  );
  final aliases = _stringMap(manifest, 'runtimeExportAliases', errors);
  final scopedOut = _stringMap(manifest, 'scopedOutRuntimeExports', errors);
  final dartSymbols = _collectDartEntrypointSymbols(root, errors);

  for (final exportName in rnExports) {
    if (aliases.containsKey(exportName)) {
      final dartSymbol = aliases[exportName]!;
      if (!dartSymbols.contains(dartSymbol)) {
        errors.add(
          'RN runtime export $exportName maps to Dart symbol $dartSymbol, '
          'but $dartSymbol is not exported by lib/rgb_sdk_flutter.dart.',
        );
      }
      continue;
    }
    if (scopedOut.containsKey(exportName)) {
      if (scopedOut[exportName]!.trim().isEmpty) {
        errors.add('Scoped-out runtime export $exportName needs a reason.');
      }
      continue;
    }
    errors.add(
      'RN runtime export $exportName is not mapped or explicitly scoped out.',
    );
  }

  for (final alias in aliases.entries) {
    if (!rnExports.contains(alias.key)) {
      errors.add('runtimeExportAliases contains stale RN export ${alias.key}.');
    }
  }
  for (final exportName in scopedOut.keys) {
    if (!rnExports.contains(exportName)) {
      errors.add(
        'scopedOutRuntimeExports contains stale RN export $exportName.',
      );
    }
  }
}

void _validateTypeExports(
  Directory root,
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final rnExports = _extractRnTypeExports(
    File('${rnRoot.path}/src/index.ts'),
    errors,
  );
  final aliases = _stringMap(manifest, 'typeExportAliases', errors);
  final scopedOut = _stringMap(manifest, 'scopedOutTypeExports', errors);
  final overlap = aliases.keys.toSet().intersection(scopedOut.keys.toSet());
  for (final name in overlap.toList()..sort()) {
    errors.add(
      'RN type export $name is both mapped and scoped out; choose one.',
    );
  }

  final dartSymbols = _collectDartEntrypointSymbols(root, errors);
  for (final exportName in rnExports) {
    final dartName = aliases[exportName];
    if (dartName != null) {
      if (!dartSymbols.contains(dartName)) {
        errors.add(
          'RN type export $exportName maps to Dart symbol $dartName, but '
          '$dartName is not exported by either package entrypoint.',
        );
      }
      continue;
    }
    final reason = scopedOut[exportName];
    if (reason != null) {
      if (reason.trim().isEmpty) {
        errors.add('Scoped-out RN type export $exportName needs a reason.');
      }
      continue;
    }
    errors.add(
      'RN type export $exportName is not mapped or explicitly scoped out.',
    );
  }

  for (final name
      in aliases.keys.toSet().difference(rnExports).toList()..sort()) {
    errors.add('typeExportAliases contains stale RN type export $name.');
  }
  for (final name
      in scopedOut.keys.toSet().difference(rnExports).toList()..sort()) {
    errors.add('scopedOutTypeExports contains stale RN type export $name.');
  }
}

Set<String> _extractRnTypeExports(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN package barrel: ${file.path}');
    return <String>{};
  }
  final exports = <String>{};
  final blockRegex = RegExp(
    r'export\s+type\s+\{([\s\S]*?)\}\s+from\s+[^\n;]+;',
    multiLine: true,
  );
  for (final match in blockRegex.allMatches(file.readAsStringSync())) {
    exports.addAll(_typescriptExportNames(match.group(1)!));
  }
  return exports;
}

Set<String> _extractRnTypeExportBlock(
  File file, {
  required String module,
  required String anchor,
  required List<String> errors,
}) {
  if (!file.existsSync()) {
    errors.add('Missing RN package barrel: ${file.path}');
    return <String>{};
  }
  final escapedModule = RegExp.escape(module);
  final blockRegex = RegExp(
    "export\\s+type\\s+\\{([\\s\\S]*?)\\}\\s+from\\s+['\"]"
    '$escapedModule'
    "['\"]\\s*;",
    multiLine: true,
  );
  final matches = blockRegex.allMatches(file.readAsStringSync());
  final anchored = matches
      .map((match) => _typescriptExportNames(match.group(1)!))
      .where((names) => names.contains(anchor))
      .toList(growable: false);
  if (anchored.length != 1) {
    errors.add(
      'Expected exactly one $module type-export block containing $anchor; '
      'found ${anchored.length}.',
    );
    return <String>{};
  }
  return anchored.single;
}

Set<String> _typescriptExportNames(String block) {
  final withoutComments = block
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');
  return withoutComments
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .map((value) {
        final alias = RegExp(
          r'^[A-Za-z_][A-Za-z0-9_]*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$',
        ).firstMatch(value);
        return alias?.group(1) ?? value;
      })
      .where((value) => RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value))
      .toSet();
}

Set<String> _extractRnRuntimeExports(File file, List<String> errors) {
  if (!file.existsSync()) {
    errors.add('Missing RN package barrel: ${file.path}');
    return <String>{};
  }

  final source = file.readAsStringSync();
  final exportRegex = RegExp(
    r'export\s+(?!type\b)\{([\s\S]*?)\}\s+from\s+[^\n;]+;',
    multiLine: true,
  );
  final exports = <String>{};
  for (final match in exportRegex.allMatches(source)) {
    final block = match.group(1)!;
    final withoutComments = block
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
    for (final rawName in withoutComments.split(',')) {
      var name = rawName.trim();
      if (name.isEmpty) continue;
      final aliasMatch = RegExp(
        r'^[A-Za-z_][A-Za-z0-9_]*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$',
      ).firstMatch(name);
      if (aliasMatch != null) {
        name = aliasMatch.group(1)!;
      }
      exports.add(name);
    }
  }
  return exports;
}

Set<String> _collectDartEntrypointSymbols(Directory root, List<String> errors) {
  return <String>{
    ..._collectDartLibrarySymbols(root, 'lib/rgb_sdk_flutter.dart', errors),
    ..._collectDartLibrarySymbols(
      root,
      'lib/rgb_sdk_flutter_advanced.dart',
      errors,
    ),
  };
}

Set<String> _collectDartLibrarySymbols(
  Directory root,
  String relativePath,
  List<String> errors,
) {
  final barrel = File('${root.path}/$relativePath');
  if (!barrel.existsSync()) {
    errors.add('Missing Dart entrypoint: ${barrel.path}');
    return <String>{};
  }

  final symbols = <String>{};
  final exportRegex = RegExp(r"export\s+'([^']+)'([^;]*);");
  for (final match in exportRegex.allMatches(barrel.readAsStringSync())) {
    final relative = match.group(1)!;
    final file = File('${root.path}/lib/$relative');
    if (!file.existsSync()) {
      errors.add('Dart barrel exports missing file: $relative');
      continue;
    }
    final librarySymbols = <String>{};
    for (final libraryFile in _dartLibraryFiles(file)) {
      librarySymbols.addAll(_extractDartSymbols(libraryFile));
    }
    symbols.addAll(
      _filterDartSymbols(
        librarySymbols,
        show: _symbolsFromCombinator(match.group(2)!, 'show'),
        hide: _symbolsFromCombinator(match.group(2)!, 'hide'),
      ),
    );
  }
  symbols.addAll(_extractDartSymbols(barrel));
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

Set<String> _filterDartSymbols(
  Set<String> symbols, {
  required Set<String>? show,
  required Set<String>? hide,
}) {
  final hidden = hide ?? const <String>{};
  return symbols
      .where((symbol) => show == null || show.contains(symbol))
      .where((symbol) => !hidden.contains(symbol))
      .toSet();
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

Set<String> _extractDartSymbols(File file) {
  final symbols = <String>{};
  final typeRegex = RegExp(
    r'^(?:sealed\s+class|abstract\s+final\s+class|abstract\s+interface\s+class|abstract\s+class|class|enum|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final functionRegex = RegExp(
    r'^(?:Future<[^>]+>|[A-Za-z_][A-Za-z0-9_<>, ?]*?)\s+([A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?\s*\(',
  );
  final variableRegex = RegExp(
    r'^(?:const|final)\s+[A-Za-z_][A-Za-z0-9_<>, ?]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*[=;]',
  );

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith(' ') || line.startsWith('\t')) continue;
    for (final regex in <RegExp>[typeRegex, functionRegex, variableRegex]) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        if (!name.startsWith('_')) symbols.add(name);
        break;
      }
    }
  }
  return symbols;
}

void _validateScopedTypeStars(
  Directory rnRoot,
  Map<String, Object?> manifest,
  List<String> errors,
) {
  final index = File('${rnRoot.path}/src/index.ts');
  if (!index.existsSync()) return;

  final scopedOut = _stringMap(manifest, 'scopedOutTypeStars', errors);
  final starRegex = RegExp(r"export\s+type\s+\*\s+from\s+'([^']+)';");
  final typeStars = starRegex
      .allMatches(index.readAsStringSync())
      .map((match) => match.group(1)!)
      .toSet();

  for (final target in typeStars) {
    if (!scopedOut.containsKey(target)) {
      errors.add(
        'RN type-star export $target is not explicitly documented in '
        'scopedOutTypeStars.',
      );
    } else if (scopedOut[target]!.trim().isEmpty) {
      errors.add('Type-star export $target needs a scoped-out reason.');
    }
  }
  for (final target in scopedOut.keys) {
    if (!typeStars.contains(target)) {
      errors.add('scopedOutTypeStars contains stale target $target.');
    }
  }
}

Map<String, String> _stringMap(
  Map<String, Object?> source,
  String key,
  List<String> errors,
) {
  final value = source[key];
  if (value is! Map<String, Object?>) {
    errors.add('Parity manifest must define object $key.');
    return <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.value is! String) {
      errors.add('$key/${entry.key} must be a string.');
      continue;
    }
    result[entry.key] = entry.value! as String;
  }
  return result;
}

Set<String> _matrixIds(Map<String, Object?> matrix) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row['id'])
      .whereType<String>()
      .toSet();
}

Set<String> _matrixStringField(Map<String, Object?> matrix, String field) {
  final methods = matrix['methods'];
  if (methods is! List<Object?>) return <String>{};
  return methods
      .whereType<Map<String, Object?>>()
      .map((row) => row[field])
      .whereType<String>()
      .toSet();
}

String _shortCommit(Object? commit) {
  if (commit is! String || commit.length < 12) return 'configured RN commit';
  return commit.substring(0, 12);
}

void _finish(List<String> errors) {
  if (errors.isEmpty) return;
  stderr.writeln('RN parity validation failed:');
  for (final error in errors) {
    stderr.writeln('- $error');
  }
  exit(1);
}
