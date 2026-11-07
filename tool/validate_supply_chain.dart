import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'android_source_build_record.dart';
import 'native_artifact_paths.dart';
import 'native_ios_privacy_policy.dart';
import 'native_provenance_verifier.dart';
import 'native_security_policy.dart';
import 'verify_android_elf.dart' show inspectAndroidArchive;

const _osvQueryBatchUrl = 'https://api.osv.dev/v1/querybatch';
const _osvTimeout = Duration(seconds: 20);
const _allowNetworkSkipEnv = 'ALLOW_SUPPLY_CHAIN_NETWORK_SKIP';
const _provenanceManifestPath = 'tool/native_artifact_provenance.json';
const _allowedLicenseClassifications = <String>{
  'Apache-2.0',
  'BSD-2-Clause-like',
  'BSD-3-Clause-like',
  'Flutter-SDK-bundled',
  'MIT',
  'MPL-2.0',
};
const _restrictedLicensePatterns = <String>[
  'gnu general public license',
  'gnu affero general public license',
  'server side public license',
  'business source license',
  'elastic license',
  'commons clause',
  'non-commercial',
  'noncommercial',
];

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _commitPattern = RegExp(r'^[0-9a-f]{40}$');
final _requiredSymbolMarkers = <String>[
  'UNIFFI_META_NAMESPACE_RGB_LIGHTNING_NODE',
  'UNIFFI_META_UDL_RGB_LIGHTNING_NODE',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_INIT_WITH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_UNLOCK_WITH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_METHOD_SDKNODE_ATTACH_NATIVE_EXTERNAL_SIGNER',
  'UNIFFI_META_RGB_LIGHTNING_NODE_INTERFACE_NATIVEEXTERNALSIGNER',
  'uniffi_rgb_lightning_node_fn_func_uniffi_healthcheck',
];

Future<void> main(List<String> args) async {
  final production = args.contains('--production');
  final failures = <String>[];
  final warnings = <String>[];
  final report = <String, Object?>{
    'suite': 'supply-chain',
    'mode': production ? 'production' : 'internal-beta',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'repositoryDirty': _gitDirty(),
  };

  final baseline =
      jsonDecode(File('tool/release_baseline.json').readAsStringSync())
          as Map<String, Object?>;
  final rln = baseline['rln']! as Map<String, Object?>;
  final ios = rln['ios']! as Map<String, Object?>;
  final android = rln['android']! as Map<String, Object?>;

  _validateBaseline(
    baseline: baseline,
    rln: rln,
    ios: ios,
    android: android,
    failures: failures,
  );
  final nativeBlockers = nativeProductionBlockers(rln['commit'].toString());
  report['nativeSecurityReview'] = <String, Object?>{
    'scope': 'pinned-native-source-onchain-and-selected-TLS-path',
    'sourceCommit': rln['commit'],
    'productionReady': nativeBlockers.isEmpty,
    'blockers': nativeBlockers,
    'isCompleteNativeSbomAudit': false,
  };
  for (final blocker in nativeBlockers) {
    _addProvenanceBlocker(
      production: production,
      failures: failures,
      warnings: warnings,
      message: blocker,
    );
  }
  final nativePrivacy = nativeIosPrivacyDisposition(
    sourceCommit: rln['commit'],
    archiveSha256: ios['archiveSha256'],
  );
  report['nativeIosPrivacyReview'] = nativePrivacy;
  for (final blocker in nativePrivacy['blockers']! as List<String>) {
    _addProvenanceBlocker(
      production: production,
      failures: failures,
      warnings: warnings,
      message: blocker,
    );
  }
  final rgbLibBaseline =
      jsonDecode(File('tool/rgb_lib_native_baseline.json').readAsStringSync())
          as Map<String, Object?>;
  final rgbLibBlockers = rgbLibProductionBlockers(
    rgbLibBaseline['sourceLockSha256'],
  );
  report['rgbLibNativeSecurityReview'] = {
    'sourceCommit': rgbLibBaseline['sourceRevision'],
    'sourceLockSha256': rgbLibBaseline['sourceLockSha256'],
    'productionReady': rgbLibBlockers.isEmpty,
    'blockers': rgbLibBlockers,
  };
  for (final blocker in rgbLibBlockers) {
    _addProvenanceBlocker(
      production: production,
      failures: failures,
      warnings: warnings,
      message: blocker,
    );
  }
  final rgbLibPrivacy = rgbLibIosPrivacyDisposition();
  report['rgbLibIosPrivacyReview'] = rgbLibPrivacy;
  for (final blocker in rgbLibPrivacy['blockers']! as List<String>) {
    _addProvenanceBlocker(
      production: production,
      failures: failures,
      warnings: warnings,
      message: blocker,
    );
  }

  report['baseline'] = <String, Object?>{
    'reactNativeCommit': _at<Map<String, Object?>>(
      baseline,
      'reactNative',
    )?['commit'],
    'rlnCommit': rln['commit'],
    'rlnVersion': rln['version'],
    'releaseTier': baseline['releaseTier'],
  };
  final sourceBuildRecord = validateAndroidSourceBuildRecord(
    rln: rln,
    android: android,
    failures: failures,
  );
  report['androidSourceBuildRecord'] =
      sourceBuildRecord?.report ??
      <String, Object?>{
        'scope': 'source-build-record-consistency',
        'status': 'failed',
        'trustedProvenance': false,
        'independentlyReproduced': false,
      };

  final dependencies = _dependencyInventory(failures, warnings);
  report['dartDependencies'] = dependencies;
  report['licensePolicy'] = _licensePolicyReport(dependencies, failures);
  report['vulnerabilityAudit'] = await _vulnerabilityAudit(
    dependencies,
    failures,
    warnings,
  );

  final nativeReport = <String, Object?>{};
  nativeReport['ios'] = await _validateIosSymbols(ios, failures, warnings);
  nativeReport['android'] = await _validateAndroidArtifact(
    android,
    failures,
    warnings,
    production: production,
    sourceBuildRecord: sourceBuildRecord,
  );
  report['nativeArtifacts'] = nativeReport;

  report['provenance'] = await _validateProvenanceManifest(
    baseline: baseline,
    rln: rln,
    ios: ios,
    android: android,
    production: production,
    failures: failures,
    warnings: warnings,
    sourceBuildRecord: sourceBuildRecord,
  );

  report['warnings'] = warnings;
  report['failures'] = failures;
  _writeReport(report);

  if (failures.isNotEmpty) {
    stderr.writeln('Supply-chain validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Supply-chain validation passed.');
  if (warnings.isNotEmpty) {
    stdout.writeln('Warnings:');
    for (final warning in warnings) {
      stdout.writeln('- $warning');
    }
  }
}

Future<Map<String, Object?>> _validateProvenanceManifest({
  required Map<String, Object?> baseline,
  required Map<String, Object?> rln,
  required Map<String, Object?> ios,
  required Map<String, Object?> android,
  required bool production,
  required List<String> failures,
  required List<String> warnings,
  required AndroidSourceBuildRecord? sourceBuildRecord,
}) async {
  final file = File(_provenanceManifestPath);
  if (!file.existsSync()) {
    failures.add('native artifact provenance manifest is missing.');
    return <String, Object?>{'status': 'missing'};
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    failures.add('native artifact provenance manifest must be a JSON object.');
    return <String, Object?>{'status': 'malformed'};
  }
  if (decoded['schemaVersion'] != 1) {
    failures.add('native artifact provenance schemaVersion must be 1.');
  }

  final reviewedAgainst = _at<Map<String, Object?>>(decoded, 'reviewedAgainst');
  if (reviewedAgainst == null) {
    failures.add('native artifact provenance reviewedAgainst is missing.');
  } else {
    _expectEqual(
      reviewedAgainst['releaseBaselineSchemaVersion'],
      baseline['schemaVersion'],
      'provenance reviewedAgainst.releaseBaselineSchemaVersion',
      failures,
    );
    _expectEqual(
      reviewedAgainst['rlnVersion'],
      rln['version'],
      'provenance reviewedAgainst.rlnVersion',
      failures,
    );
    _expectEqual(
      reviewedAgainst['rlnCommit'],
      rln['commit'],
      'provenance reviewedAgainst.rlnCommit',
      failures,
    );
  }

  final artifactObjects = decoded['artifacts'];
  if (artifactObjects is! List<Object?> || artifactObjects.isEmpty) {
    failures.add('native artifact provenance artifacts must be non-empty.');
    return <String, Object?>{'status': 'malformed'};
  }

  final expectedArtifacts = <String, Map<String, Object?>>{
    'rln-ios-swift': <String, Object?>{
      'platform': 'ios',
      'artifactUrl': ios['archiveUrl'],
      'artifactSha256': ios['archiveSha256'],
      'artifactSizeBytes': ios['archiveSizeBytes'],
    },
    'rln-android-aar': <String, Object?>{
      'platform': 'android',
      'artifactUrl': android['archiveUrl'],
      'artifactSha256': android['archiveSha256'],
      'artifactSizeBytes': android['archiveSizeBytes'],
    },
  };

  final artifactsById = <String, Map<String, Object?>>{};
  for (final artifactObject in artifactObjects) {
    if (artifactObject is! Map<String, Object?>) {
      failures.add('native artifact provenance entries must be objects.');
      continue;
    }
    final id = artifactObject['id']?.toString();
    if (id == null || id.isEmpty) {
      failures.add('native artifact provenance entry is missing id.');
      continue;
    }
    if (artifactsById.containsKey(id)) {
      failures.add('duplicate native artifact provenance id: $id.');
      continue;
    }
    artifactsById[id] = artifactObject;
  }

  final reports = <Map<String, Object?>>[];
  var verifiedSignatures = 0;
  var absentSignatures = 0;
  var unverifiedSignatures = 0;
  var verifiedAttestations = 0;
  var verifiedReproducibleBuilds = 0;

  for (final entry in expectedArtifacts.entries) {
    final artifact = artifactsById[entry.key];
    if (artifact == null) {
      failures.add('missing native artifact provenance entry: ${entry.key}.');
      continue;
    }
    final expected = entry.value;
    _expectEqual(
      artifact['platform'],
      expected['platform'],
      'provenance ${entry.key}.platform',
      failures,
    );
    _expectEqual(
      artifact['artifactUrl'],
      expected['artifactUrl'],
      'provenance ${entry.key}.artifactUrl',
      failures,
    );
    _expectEqual(
      artifact['artifactSha256'],
      expected['artifactSha256'],
      'provenance ${entry.key}.artifactSha256',
      failures,
    );
    _expectEqual(
      artifact['artifactSizeBytes'],
      expected['artifactSizeBytes'],
      'provenance ${entry.key}.artifactSizeBytes',
      failures,
    );
    if (entry.key == 'rln-android-aar') {
      _expectEqual(
        artifact['source'],
        'sdk-source-build',
        'provenance Android source classification',
        failures,
      );
      sourceBuildRecord?.checkProvenanceDeclaration(
        artifact['sourceBuild'],
        failures,
      );
    }

    final signature = _requiredObject(
      artifact,
      'signature',
      'provenance ${entry.key}.signature',
      failures,
    );
    final attestation = _requiredObject(
      artifact,
      'attestation',
      'provenance ${entry.key}.attestation',
      failures,
    );
    final reproducible = _requiredObject(
      artifact,
      'reproducibleBuild',
      'provenance ${entry.key}.reproducibleBuild',
      failures,
    );
    final signatureStatus = signature?['status']?.toString() ?? 'missing';
    final attestationStatus = attestation?['status']?.toString() ?? 'missing';
    final reproducibleStatus = reproducible?['status']?.toString() ?? 'missing';
    Map<String, Object?>? verification;
    final submittedForVerification = [
      signatureStatus,
      attestationStatus,
      reproducibleStatus,
    ].every((status) => status == 'verified');
    if (submittedForVerification) {
      try {
        final policy =
            jsonDecode(
                  File('tool/native_provenance_trust.json').readAsStringSync(),
                )
                as Map<String, Object?>;
        File archive;
        if (entry.key == 'rln-ios-swift') {
          archive = File(
            Platform.environment['RGB_SDK_IOS_ARCHIVE_PATH'] ??
                'ios/rgb-lightning-node-swift.zip',
          );
        } else {
          final explicit = Platform.environment['RGB_SDK_ANDROID_AAR_PATH'];
          final candidates = explicit != null && explicit.isNotEmpty
              ? [File(explicit)]
              : _findAndroidAars(
                  MavenArtifactCoordinate.parse(
                    android['mavenCoordinate'].toString(),
                  ),
                );
          if (candidates.isEmpty) throw StateError('Archive missing.');
          archive = candidates.first;
        }
        verification =
            await NativeProvenanceVerifier(
              root: Directory.current,
              policy: policy,
            ).verify(
              artifactId: entry.key,
              artifact: archive,
              expectedDigest: expected['artifactSha256']! as String,
              expectedSize: expected['artifactSizeBytes']! as int,
              sourceRepository: rln['repository']! as String,
              sourceCommit: rln['commit']! as String,
              declaration: artifact,
              failures: failures,
            );
        if (verification['signatureVerified'] == true) verifiedSignatures += 1;
        if (verification['attestationVerified'] == true) {
          verifiedAttestations += 1;
        }
        if (verification['reproductionVerified'] == true) {
          verifiedReproducibleBuilds += 1;
        }
      } on Object {
        failures.add(
          '${entry.key}: reviewed trust policy or archive is unavailable.',
        );
      }
    } else {
      if (signatureStatus == 'absent') {
        absentSignatures += 1;
      } else if (signatureStatus == 'present-unverified') {
        unverifiedSignatures += 1;
        _validateSignatureMetadata(entry.key, signature!, failures);
      } else if (signatureStatus != 'verified') {
        failures.add('${entry.key}: unsupported signature status.');
      }
      for (final evidence in <String, String>{
        'detached signature': signatureStatus,
        'source/builder attestation': attestationStatus,
        'independent reproduction': reproducibleStatus,
      }.entries) {
        if (!{
          'absent',
          'present-unverified',
          'verified',
        }.contains(evidence.value)) {
          failures.add('${entry.key}: unsupported ${evidence.key} status.');
        }
        _addProvenanceBlocker(
          production: production,
          failures: failures,
          warnings: warnings,
          message: '${entry.key} lacks verified ${evidence.key} evidence.',
        );
      }
      if ([
        signatureStatus,
        attestationStatus,
        reproducibleStatus,
      ].contains('verified')) {
        failures.add(
          '${entry.key}: partial status claims cannot replace complete cryptographic verification.',
        );
      }
    }

    reports.add(<String, Object?>{
      'id': entry.key,
      'platform': artifact['platform'],
      'source': artifact['source'],
      'artifactUrl': artifact['artifactUrl'],
      'artifactSha256': artifact['artifactSha256'],
      'signatureStatus': signatureStatus,
      'attestationStatus': attestationStatus,
      'reproducibleBuildStatus': reproducibleStatus,
      'verification': ?verification,
    });
  }

  final unexpected =
      artifactsById.keys
          .where((id) => !expectedArtifacts.containsKey(id))
          .toList()
        ..sort();
  if (unexpected.isNotEmpty) {
    failures.add(
      'native artifact provenance contains unexpected artifact ids: '
      '${unexpected.join(', ')}.',
    );
  }

  final artifactCount = expectedArtifacts.length;
  final productionReady =
      verifiedSignatures == artifactCount &&
      verifiedAttestations == artifactCount &&
      verifiedReproducibleBuilds == artifactCount;
  if (production && !productionReady) {
    failures.add(
      'production provenance is not satisfied for all native artifacts.',
    );
  }

  return <String, Object?>{
    'status': productionReady ? 'production-ready' : 'internal-beta-only',
    'manifest': _provenanceManifestPath,
    'sourcePins': 'present',
    'checksums': 'present',
    'artifactCount': artifactCount,
    'verifiedSignatures': verifiedSignatures,
    'absentSignatures': absentSignatures,
    'unverifiedSignatures': unverifiedSignatures,
    'verifiedAttestations': verifiedAttestations,
    'verifiedReproducibleBuilds': verifiedReproducibleBuilds,
    'productionReady': productionReady,
    'artifacts': reports,
  };
}

Map<String, Object?>? _requiredObject(
  Map<String, Object?> source,
  String key,
  String label,
  List<String> failures,
) {
  final value = source[key];
  if (value is Map<String, Object?>) return value;
  failures.add('$label must be an object.');
  return null;
}

void _validateSignatureMetadata(
  String artifactId,
  Map<String, Object?> signature,
  List<String> failures,
) {
  final signatureUrl = signature['signatureUrl']?.toString() ?? '';
  final signatureSha256 = signature['signatureSha256']?.toString() ?? '';
  final uri = Uri.tryParse(signatureUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    failures.add(
      'provenance $artifactId.signature.signatureUrl must be an HTTPS URL.',
    );
  }
  if (!_sha256Pattern.hasMatch(signatureSha256)) {
    failures.add(
      'provenance $artifactId.signature.signatureSha256 must be a SHA-256.',
    );
  }
}

void _addProvenanceBlocker({
  required bool production,
  required List<String> failures,
  required List<String> warnings,
  required String message,
}) {
  if (production) {
    failures.add(message);
  } else {
    warnings.add('$message This can only pass as an internal-beta gate.');
  }
}

void _expectEqual(
  Object? actual,
  Object? expected,
  String label,
  List<String> failures,
) {
  if (actual == expected) return;
  failures.add('$label mismatch. Expected "$expected", got "$actual".');
}

void _validateBaseline({
  required Map<String, Object?> baseline,
  required Map<String, Object?> rln,
  required Map<String, Object?> ios,
  required Map<String, Object?> android,
  required List<String> failures,
}) {
  final rn = baseline['reactNative']! as Map<String, Object?>;
  final core = baseline['core']! as Map<String, Object?>;
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('reactNative.repository', rn['repository']),
    MapEntry('core.repository', core['repository']),
    MapEntry('rln.repository', rln['repository']),
    MapEntry('rln.ios.archiveUrl', ios['archiveUrl']),
    MapEntry('rln.android.archiveUrl', android['archiveUrl']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!value.startsWith('https://')) {
      failures.add('${entry.key} must be an https URL.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('reactNative.commit', rn['commit']),
    MapEntry('rln.commit', rln['commit']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!_commitPattern.hasMatch(value)) {
      failures.add('${entry.key} must be a full 40-character commit hash.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('rln.ios.archiveSha256', ios['archiveSha256']),
    MapEntry('rln.android.archiveSha256', android['archiveSha256']),
  ]) {
    final value = entry.value?.toString() ?? '';
    if (!_sha256Pattern.hasMatch(value)) {
      failures.add('${entry.key} must be a lowercase SHA-256 digest.');
    }
  }
  for (final entry in <MapEntry<String, Object?>>[
    MapEntry('rln.ios.archiveSizeBytes', ios['archiveSizeBytes']),
    MapEntry('rln.android.archiveSizeBytes', android['archiveSizeBytes']),
  ]) {
    final value = entry.value;
    if (value is! int || value <= 0) {
      failures.add('${entry.key} must be a positive integer.');
    }
  }
}

List<Map<String, Object?>> _dependencyInventory(
  List<String> failures,
  List<String> warnings,
) {
  final lockText = File('pubspec.lock').readAsStringSync();
  final lockPackages = _parsePubspecLock(lockText);
  final packageConfigFile = File('.dart_tool/package_config.json');
  if (!packageConfigFile.existsSync()) {
    failures.add(
      '.dart_tool/package_config.json is missing; run flutter pub get first.',
    );
    return const <Map<String, Object?>>[];
  }
  final packageConfig =
      jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, Object?>;
  final packages = (packageConfig['packages']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final roots = <String, Uri>{};
  for (final package in packages) {
    final name = package['name']?.toString();
    final rootUri = package['rootUri']?.toString();
    if (name == null || rootUri == null) continue;
    roots[name] = Uri.parse(rootUri);
  }

  final inventory = <Map<String, Object?>>[];
  for (final package in lockPackages) {
    final name = package['name']!.toString();
    final root = roots[name];
    final licenseFiles = root == null
        ? const <String>[]
        : _licenseFilesIncludingSdkRoot(Directory.fromUri(root));
    final source = package['source']?.toString();
    final license = source == 'sdk'
        ? const _LicenseClassification.accepted('Flutter-SDK-bundled')
        : root == null
        ? _LicenseClassification.unknown('missing package root')
        : _classifyLicense(Directory.fromUri(root), licenseFiles);
    if (licenseFiles.isEmpty) {
      failures.add(
        'dependency $name has no local LICENSE/COPYING/NOTICE file.',
      );
    }
    inventory.add(<String, Object?>{
      'name': name,
      'version': package['version'],
      'source': source,
      'dependency': package['dependency'],
      'sha256': package['sha256'],
      'licenseFiles': licenseFiles,
      'license': license.name,
      'licensePolicy': license.policy,
      'licenseReason': license.reason,
    });
  }
  if (inventory.isEmpty) {
    failures.add('pubspec.lock dependency inventory is empty.');
  }
  return inventory;
}

Map<String, Object?> _licensePolicyReport(
  List<Map<String, Object?>> dependencies,
  List<String> failures,
) {
  final accepted = <Map<String, Object?>>[];
  final unknown = <Map<String, Object?>>[];
  final rejected = <Map<String, Object?>>[];

  for (final dependency in dependencies) {
    final policy = dependency['licensePolicy']?.toString() ?? 'unknown';
    final row = <String, Object?>{
      'name': dependency['name'],
      'version': dependency['version'],
      'license': dependency['license'],
      'policy': policy,
      'reason': dependency['licenseReason'],
    };
    if (policy == 'accepted') {
      accepted.add(row);
    } else if (policy == 'rejected') {
      rejected.add(row);
    } else {
      unknown.add(row);
    }
  }

  for (final dependency in rejected) {
    failures.add(
      'dependency ${dependency['name']} has rejected license evidence: '
      '${dependency['reason']}',
    );
  }
  for (final dependency in unknown) {
    failures.add(
      'dependency ${dependency['name']} has unclassified license evidence: '
      '${dependency['reason']}',
    );
  }

  return <String, Object?>{
    'allowed': _allowedLicenseClassifications.toList()..sort(),
    'acceptedCount': accepted.length,
    'unknownCount': unknown.length,
    'rejectedCount': rejected.length,
    'accepted': accepted,
    'unknown': unknown,
    'rejected': rejected,
  };
}

List<Map<String, Object?>> _parsePubspecLock(String text) {
  final packages = <Map<String, Object?>>[];
  String? current;
  String? dependency;
  String? source;
  String? version;
  String? sha256;
  for (final line in text.split('\n')) {
    final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (packageMatch != null) {
      if (current != null) {
        packages.add(<String, Object?>{
          'name': current,
          'dependency': dependency,
          'source': source,
          'version': version,
          'sha256': sha256,
        });
      }
      current = packageMatch.group(1);
      dependency = null;
      source = null;
      version = null;
      sha256 = null;
      continue;
    }
    if (current == null) continue;
    String? scalar(String key) {
      final match = RegExp('^    $key: (.*)\$').firstMatch(line);
      return match?.group(1)?.replaceAll('"', '');
    }

    dependency ??= scalar('dependency');
    source ??= scalar('source');
    version ??= scalar('version');
    sha256 ??= scalar('      sha256');
    final shaMatch = RegExp(r'^      sha256: "?([^"]+)"?$').firstMatch(line);
    if (shaMatch != null) sha256 = shaMatch.group(1);
  }
  if (current != null) {
    packages.add(<String, Object?>{
      'name': current,
      'dependency': dependency,
      'source': source,
      'version': version,
      'sha256': sha256,
    });
  }
  return packages
      .where((package) => package['name'] != 'rgb_sdk_flutter')
      .toList(growable: false);
}

List<String> _licenseFiles(Directory root) {
  if (!root.existsSync()) return const <String>[];
  final files = <String>[];
  for (final entity in root.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last.toLowerCase();
    if (name == 'license' ||
        name == 'license.md' ||
        name == 'copying' ||
        name == 'notice' ||
        name == 'notice.md') {
      files.add(entity.path);
    }
  }
  files.sort();
  return files;
}

List<String> _licenseFilesIncludingSdkRoot(Directory root) {
  final direct = _licenseFiles(root);
  if (direct.isNotEmpty) return direct;
  var current = root;
  for (var depth = 0; depth < 4; depth += 1) {
    current = current.parent;
    final parentLicenses = _licenseFiles(current);
    if (parentLicenses.isNotEmpty) return parentLicenses;
  }
  return const <String>[];
}

_LicenseClassification _classifyLicense(Directory root, List<String> files) {
  if (files.isEmpty) return _LicenseClassification.unknown('no license file');
  final text = files
      .map((path) => File(path).readAsStringSync())
      .join('\n\n')
      .toLowerCase();
  for (final pattern in _restrictedLicensePatterns) {
    if (text.contains(pattern)) {
      return _LicenseClassification.rejected(
        'restricted/copyleft-commercial pattern "$pattern" found',
      );
    }
  }
  if (text.contains('apache license') && text.contains('version 2.0')) {
    return const _LicenseClassification.accepted('Apache-2.0');
  }
  if (text.contains('mozilla public license') && text.contains('version 2.0')) {
    return const _LicenseClassification.accepted('MPL-2.0');
  }
  if (text.contains('mit license') ||
      text.contains('permission is hereby granted, free of charge')) {
    return const _LicenseClassification.accepted('MIT');
  }
  if (text.contains('redistribution and use in source and binary forms')) {
    final hasAdvertisingClause = text.contains(
      'all advertising materials mentioning features or use of this software',
    );
    final license = hasAdvertisingClause
        ? 'BSD-4-Clause-like'
        : 'BSD-3-Clause-like';
    if (_allowedLicenseClassifications.contains(license)) {
      return _LicenseClassification.accepted(license);
    }
    return _LicenseClassification.rejected('$license is not allowlisted');
  }
  return _LicenseClassification.unknown(
    'no accepted SPDX-compatible pattern found in ${root.path}',
  );
}

Future<Map<String, Object?>> _vulnerabilityAudit(
  List<Map<String, Object?>> dependencies,
  List<String> failures,
  List<String> warnings,
) async {
  final hosted = dependencies
      .where((dependency) => dependency['source'] == 'hosted')
      .where((dependency) => dependency['version'] != null)
      .toList(growable: false);
  if (hosted.isEmpty) {
    failures.add('no hosted dependencies available for OSV audit.');
    return <String, Object?>{'status': 'failed', 'reason': 'empty inventory'};
  }

  final queries = hosted
      .map(
        (dependency) => <String, Object?>{
          'package': <String, Object?>{
            'name': dependency['name'],
            'ecosystem': 'Pub',
          },
          'version': dependency['version'],
        },
      )
      .toList(growable: false);

  late final Map<String, Object?> decoded;
  try {
    decoded = await _postJson(Uri.parse(_osvQueryBatchUrl), <String, Object?>{
      'queries': queries,
    });
  } catch (error) {
    final message = 'OSV vulnerability audit failed: $error';
    if (Platform.environment[_allowNetworkSkipEnv] == '1') {
      warnings.add('$message. Allowed by $_allowNetworkSkipEnv=1.');
      return <String, Object?>{
        'status': 'skipped',
        'reason': message,
        'queryCount': queries.length,
      };
    }
    failures.add(message);
    return <String, Object?>{
      'status': 'failed',
      'reason': message,
      'queryCount': queries.length,
    };
  }

  final results = decoded['results'];
  if (results is! List || results.length != hosted.length) {
    failures.add('OSV querybatch returned malformed result shape.');
    return <String, Object?>{
      'status': 'failed',
      'reason': 'malformed result shape',
      'queryCount': queries.length,
    };
  }

  final vulnerable = <Map<String, Object?>>[];
  for (var i = 0; i < hosted.length; i += 1) {
    final result = results[i];
    final vulns = result is Map ? result['vulns'] : null;
    if (vulns is! List || vulns.isEmpty) continue;
    final dependency = hosted[i];
    vulnerable.add(<String, Object?>{
      'name': dependency['name'],
      'version': dependency['version'],
      'vulnerabilities': vulns
          .whereType<Map<Object?, Object?>>()
          .map(
            (vuln) => <String, Object?>{
              'id': vuln['id'],
              'aliases': vuln['aliases'],
              'summary': vuln['summary'],
              'modified': vuln['modified'],
            },
          )
          .toList(growable: false),
    });
  }

  if (vulnerable.isNotEmpty) {
    failures.add(
      'OSV vulnerability audit found affected hosted dependencies: '
      '${vulnerable.map((row) => row['name']).join(', ')}',
    );
  }

  return <String, Object?>{
    'status': vulnerable.isEmpty ? 'passed' : 'failed',
    'source': _osvQueryBatchUrl,
    'ecosystem': 'Pub',
    'queryCount': queries.length,
    'vulnerableCount': vulnerable.length,
    'vulnerable': vulnerable,
  };
}

Future<Map<String, Object?>> _postJson(
  Uri uri,
  Map<String, Object?> body,
) async {
  final client = HttpClient()..connectionTimeout = _osvTimeout;
  try {
    final request = await client.postUrl(uri).timeout(_osvTimeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(_osvTimeout);
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}: $text');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    throw const FormatException('expected JSON object response');
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _validateIosSymbols(
  Map<String, Object?> ios,
  List<String> failures,
  List<String> warnings,
) async {
  final installedFiles =
      (ios['installedFiles']! as Map<String, Object?>).keys.toList()..sort();
  for (final path in installedFiles) {
    final file = File(path);
    if (!file.existsSync() ||
        (await sha256.bind(file.openRead()).first).toString() !=
            (ios['installedFiles']! as Map<String, Object?>)[path]) {
      failures.add('Installed iOS artifact differs from its baseline: $path');
    }
  }
  final libraries = installedFiles
      .where((path) => path.endsWith('/librgb_lightning_node.a'))
      .toList(growable: false);
  final slices = <Map<String, Object?>>[];
  if (!Platform.isMacOS) {
    warnings.add('iOS symbol validation requires macOS; skipped on this host.');
    return <String, Object?>{'status': 'skipped', 'reason': 'not macOS'};
  }
  for (final relativePath in libraries) {
    final file = File(relativePath);
    if (!file.existsSync()) {
      failures.add('missing iOS native library: $relativePath');
      continue;
    }
    final symbols = _runSymbols('nm', <String>['-gU', relativePath]);
    final missing = _missingMarkers(symbols, _requiredSymbolMarkers);
    if (missing.isNotEmpty) {
      failures.add(
        'iOS native library $relativePath is missing ABI markers: '
        '${missing.join(', ')}',
      );
    }
    slices.add(<String, Object?>{
      'path': relativePath,
      'sizeBytes': file.lengthSync(),
      'markersChecked': _requiredSymbolMarkers.length,
      'missingMarkers': missing,
    });
  }
  if (slices.isEmpty) {
    failures.add('no iOS native libraries found in release baseline.');
  }
  return <String, Object?>{'status': 'checked', 'libraries': slices};
}

Future<Map<String, Object?>> _validateAndroidArtifact(
  Map<String, Object?> android,
  List<String> failures,
  List<String> warnings, {
  required bool production,
  required AndroidSourceBuildRecord? sourceBuildRecord,
}) async {
  final coordinate = MavenArtifactCoordinate.parse(
    android['mavenCoordinate'].toString(),
  );
  final explicitPath = Platform.environment['RGB_SDK_ANDROID_AAR_PATH'];
  final aarPaths = explicitPath != null && explicitPath.isNotEmpty
      ? <File>[File(explicitPath)]
      : _findAndroidAars(coordinate);
  if (aarPaths.isEmpty) {
    failures.add('Android AAR is not resolved in the local Gradle cache.');
    return <String, Object?>{'status': 'missing'};
  }
  final expectedAbis = (android['abis']! as List<Object?>)
      .map((abi) => abi.toString())
      .toSet();
  final archives = <Map<String, Object?>>[];
  for (final aar in aarPaths) {
    if (!aar.existsSync() || aar.lengthSync() != android['archiveSizeBytes']) {
      failures.add(
        'Android AAR is missing or has an untrusted size: ${aar.path}',
      );
      continue;
    }
    final digest = (await sha256.bind(aar.openRead()).first).toString();
    if (digest != android['archiveSha256']) {
      failures.add(
        'Android AAR checksum does not match the pinned baseline: ${aar.path}',
      );
      continue;
    }
    final entries = _run('unzip', <String>['-Z1', aar.path]).stdoutLines;
    final abis = entries
        .map(
          (entry) => RegExp(
            r'^jni/([^/]+)/librgb_lightning_node\.so$',
          ).firstMatch(entry),
        )
        .whereType<RegExpMatch>()
        .map((match) => match.group(1)!)
        .toSet();
    if (abis.length != expectedAbis.length || !abis.containsAll(expectedAbis)) {
      failures.add(
        'Android AAR ${aar.path} ABI set ${abis.toList()..sort()} does not '
        'match expected ${expectedAbis.toList()..sort()}.',
      );
    }
    final abiReports = <Map<String, Object?>>[];
    for (final abi in abis.toList()..sort()) {
      final markerReport = _androidSymbolMarkers(
        aar,
        abi,
        failures,
        warnings,
        sourceBuildRecord: sourceBuildRecord,
      );
      abiReports.add(markerReport);
    }
    Map<String, Object?> pageCompatibility;
    try {
      pageCompatibility = await inspectAndroidArchive(aar, 'aar', expectedAbis);
      if (pageCompatibility['compatible'] != true) {
        final message =
            'Android AAR ${aar.path} fails static ELF page compatibility: '
            '${pageCompatibility['failures']}';
        if (production) {
          failures.add(message);
        } else {
          warnings.add(
            '$message Internal-beta integrity is not 16 KiB qualification.',
          );
        }
      }
    } on Object catch (error) {
      failures.add('Cannot validate Android ELF page compatibility: $error');
      pageCompatibility = <String, Object?>{
        'compatible': false,
        'error': error.toString(),
      };
    }
    archives.add(<String, Object?>{
      'path': aar.path,
      'sizeBytes': aar.lengthSync(),
      'abis': abis.toList()..sort(),
      'symbols': abiReports,
      'pageCompatibility': pageCompatibility,
    });
  }
  return <String, Object?>{'status': 'checked', 'archives': archives};
}

Map<String, Object?> _androidSymbolMarkers(
  File aar,
  String abi,
  List<String> failures,
  List<String> warnings, {
  required AndroidSourceBuildRecord? sourceBuildRecord,
}) {
  final temp = Directory.systemTemp.createTempSync('rgb-sdk-abi-');
  final entry = 'jni/$abi/librgb_lightning_node.so';
  try {
    final unzip = _run('unzip', <String>[
      '-q',
      aar.path,
      entry,
      '-d',
      temp.path,
    ]);
    if (unzip.exitCode != 0) {
      failures.add(
        'failed to extract $entry from ${aar.path}: ${unzip.stderr}',
      );
      return <String, Object?>{'abi': abi, 'status': 'extract-failed'};
    }
    final library = File('${temp.path}/$entry');
    final size = library.lengthSync();
    if (size > 256 * 1024 * 1024) {
      failures.add('Android JNI library exceeds 256 MiB: $entry');
      return <String, Object?>{'abi': abi, 'status': 'oversized'};
    }
    final digest = sha256.convert(library.readAsBytesSync()).toString();
    final recordMatches = sourceBuildRecord?.checkLibrary(
      abi: abi,
      sizeBytes: size,
      digest: digest,
      failures: failures,
    );
    final symbols = _runSymbols('nm', <String>['-gD', library.path]);
    final missing = _missingMarkers(symbols, _requiredSymbolMarkers);
    if (missing.isNotEmpty) {
      failures.add(
        'Android $abi native library is missing ABI markers: ${missing.join(', ')}',
      );
    }
    return <String, Object?>{
      'abi': abi,
      'sizeBytes': size,
      'sha256': digest,
      'sourceBuildRecordConsistent': recordMatches,
      'markersChecked': _requiredSymbolMarkers.length,
      'missingMarkers': missing,
    };
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      warnings.add(
        'temporary ABI directory could not be removed: ${temp.path}',
      );
    }
  }
}

List<File> _findAndroidAars(MavenArtifactCoordinate coordinate) {
  final home = Platform.environment['HOME'];
  if (home == null) return const <File>[];
  final base = Directory(coordinate.cacheDirectory(home));
  if (!base.existsSync()) return const <File>[];
  return base
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.uri.pathSegments.last == coordinate.fileName)
      .toList(growable: false);
}

String _runSymbols(String executable, List<String> args) {
  final result = _run(executable, args);
  if (result.exitCode == 0) return result.stdoutText;
  return _run('strings', <String>[args.last]).stdoutText;
}

List<String> _missingMarkers(String symbols, List<String> markers) {
  return markers.where((marker) => !symbols.contains(marker)).toList();
}

_CommandResult _run(String executable, List<String> args) {
  final result = Process.runSync(executable, args, stdoutEncoding: utf8);
  return _CommandResult(
    exitCode: result.exitCode,
    stdoutText: result.stdout.toString(),
    stderr: result.stderr.toString(),
  );
}

void _writeReport(Map<String, Object?> report) {
  final reportDir = Platform.environment['REPORT_DIR'];
  if (reportDir == null || reportDir.isEmpty) return;
  final dir = Directory(reportDir)..createSync(recursive: true);
  final commit = _run('git', <String>[
    'rev-parse',
    '--short',
    'HEAD',
  ]).stdoutText.trim();
  final path =
      '${dir.path}/supply-chain-${commit.isEmpty ? 'unknown' : commit}.json';
  File(
    path,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('supply-chain report: $path');
}

bool _gitDirty() {
  final result = _run('git', <String>['status', '--porcelain']);
  return result.stdoutText.trim().isNotEmpty;
}

T? _at<T>(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is T ? value : null;
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.stdoutText,
    required this.stderr,
  });

  final int exitCode;
  final String stdoutText;
  final String stderr;

  List<String> get stdoutLines => stdoutText
      .split('\n')
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

class _LicenseClassification {
  const _LicenseClassification._(this.name, this.policy, this.reason);

  const _LicenseClassification.accepted(String name)
    : this._(name, 'accepted', 'allowlisted license classification');

  _LicenseClassification.rejected(String reason)
    : this._('REJECTED', 'rejected', reason);

  _LicenseClassification.unknown(String reason)
    : this._('UNKNOWN', 'unknown', reason);

  final String name;
  final String policy;
  final String reason;
}
