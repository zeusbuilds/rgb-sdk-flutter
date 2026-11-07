import 'dart:convert';
import 'dart:io';

/// Exact inputs of the source/symbol audit in doc/IOS_PRIVACY_API_AUDIT.md.
/// This audit found an unresolved category; it is not production approval.
const auditedIosPrivacySourceCommit =
    'ecc69f20308231400561f6f060fea88acfa40cc4';
const auditedIosPrivacyArchiveSha256 =
    'dd5c483753e58c0c1c49f94098a2cc6eef18e16d3eebd167d31131fbd888890a';

/// Code-backed privacy disposition. Release metadata, manifests, signatures and
/// environment variables cannot approve an unreviewed native API call path.
/// Add a positive disposition only after reviewing exact replacement inputs and
/// the final signed archive's required-API report and aggregate manifests.
Map<String, Object?> nativeIosPrivacyDisposition({
  required Object? sourceCommit,
  required Object? archiveSha256,
}) {
  final known =
      sourceCommit == auditedIosPrivacySourceCommit &&
      archiveSha256 == auditedIosPrivacyArchiveSha256;
  return <String, Object?>{
    'scope': 'native-ios-required-reason-api',
    'sourceCommit': sourceCommit,
    'archiveSha256': archiveSha256,
    'status': known ? 'blocked-known-unresolved' : 'unreviewed',
    'productionReady': false,
    'blockers': known
        ? const <String>[
            'iOS privacy: the exact pinned native archive retains statfs/fstatfs/fstatvfs with no reviewed, truthful DiskSpace required-reason disposition. FileTimestamp C617.1 does not close this category. The native publisher must remove unused calls or justify the actual linked use; final signed-archive API and aggregate privacy reports remain required.',
          ]
        : const <String>[
            'iOS privacy: this native source/archive pair has no code-backed required-reason API disposition. Review exact native inputs and final signed-archive API and aggregate privacy reports before production approval.',
          ],
  };
}

/// Independent review of the second native runtime linked by this SDK.
Map<String, Object?> rgbLibIosPrivacyDisposition() {
  final manifest = File('tool/rgb_lib_native_baseline.json');
  final data = manifest.existsSync()
      ? jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>
      : const <String, Object?>{};
  final ios = data['ios'] as Map<String, Object?>?;
  final source = data['sourceRevision'];
  final archive = ios?['sha256'];
  final known =
      source == '0a9d352f2690902df2b6fae9bca1a6c13c3354d4' &&
      archive ==
          '44890e57b78935a2c7842d9baeed5172bbd99e9b2b91c6a599fbc2c745760669';
  return {
    'scope': 'rgb-l1-native-ios-required-reason-api',
    'sourceCommit': source,
    'archiveSha256': archive,
    'status': known ? 'blocked-known-unresolved' : 'unreviewed',
    'productionReady': false,
    'blockers': [
      if (known)
        'iOS privacy: RGB_L1 BFA.5 imports statfs/fstatfs. Review the linked call paths and signed archive before selecting a DiskSpace reason.'
      else
        'iOS privacy: RGB_L1 has no approved required-reason API disposition for its exact source and archive.',
    ],
  };
}

/// A dependency-free production preflight, before builds or supplied evidence.
void main(List<String> args) {
  if (args.isNotEmpty && (args.length != 1 || args.single != '--production')) {
    stderr.writeln('Unsupported native privacy validation mode.');
    exitCode = 64;
    return;
  }
  final production = args.contains('--production');
  try {
    final baseline = jsonDecode(
      File('tool/release_baseline.json').readAsStringSync(),
    );
    final rln = baseline is Map<String, Object?> ? baseline['rln'] : null;
    final ios = rln is Map<String, Object?> ? rln['ios'] : null;
    final disposition = nativeIosPrivacyDisposition(
      sourceCommit: rln is Map<String, Object?> ? rln['commit'] : null,
      archiveSha256: ios is Map<String, Object?> ? ios['archiveSha256'] : null,
    );
    final rgbLib = rgbLibIosPrivacyDisposition();
    final ready =
        disposition['productionReady'] == true &&
        rgbLib['productionReady'] == true;
    stdout.writeln(
      jsonEncode({
        ...disposition,
        'productionReady': ready,
        'rgbLib': rgbLib,
        'mode': production ? 'production' : 'internal-beta',
      }),
    );
    if (production && !ready) exitCode = 1;
  } on Object {
    stderr.writeln('Native iOS privacy input validation failed.');
    exitCode = 1;
  }
}
