import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/native_ios_privacy_policy.dart';

void main() {
  test('the exact BFA.7 successor retains its final-app privacy fence', () {
    final review = rgbLibIosPrivacyDisposition();
    expect(review['sourceCommit'], '9ec49c08be2e68f08521281e3efbd760ec989cb9');
    expect(review['status'], 'blocked-final-app-review');
    expect(review['productionReady'], false);
    expect(review['linkedDiskSpaceImports'], isEmpty);
    expect('${review['blockers']}', contains('signed-app'));
    expect('${review['blockers']}', contains('legacy RLN'));
  });
  test('older RGB_L1 archives retain their independent DiskSpace blocker', () {
    for (final inputs in [
      (
        '9ec49c08be2e68f08521281e3efbd760ec989cb9',
        'b6d5baaaec5433f5f69b2da6f43a25225d7d7e4d441e1868de08ce34d022c11d',
      ),
      (
        '0a9d352f2690902df2b6fae9bca1a6c13c3354d4',
        '44890e57b78935a2c7842d9baeed5172bbd99e9b2b91c6a599fbc2c745760669',
      ),
    ]) {
      final review = rgbLibIosPrivacyDispositionForInputs(
        sourceCommit: inputs.$1,
        archiveSha256: inputs.$2,
      );
      expect(review['status'], 'blocked-known-unresolved');
      expect(review['productionReady'], false);
      expect('${review['blockers']}', contains('statfs/fstatfs'));
    }
  });
  test('an unknown RGB_L1 pair cannot inherit the linked-component review', () {
    for (final inputs in <(Object?, Object?)>[
      (
        '1' * 40,
        '60c33914222a62a822440bf155babd0b030a74f4fc166f7bd5c5955e6f49932c',
      ),
      ('9ec49c08be2e68f08521281e3efbd760ec989cb9', '2' * 64),
      (null, null),
    ]) {
      final review = rgbLibIosPrivacyDispositionForInputs(
        sourceCommit: inputs.$1,
        archiveSha256: inputs.$2,
      );
      expect(review['status'], 'unreviewed');
      expect(review['productionReady'], false);
      expect(review.containsKey('linkedDiskSpaceImports'), false);
    }
  });
  test(
    'exact audited source and archive retain the known DiskSpace blocker',
    () {
      final review = nativeIosPrivacyDisposition(
        sourceCommit: auditedIosPrivacySourceCommit,
        archiveSha256: auditedIosPrivacyArchiveSha256,
      );
      expect(review['productionReady'], false);
      expect(review['status'], 'blocked-known-unresolved');
      expect('${review['blockers']}', contains('statfs/fstatfs/fstatvfs'));
      expect('${review['blockers']}', contains('FileTimestamp C617.1'));
    },
  );

  test('unknown source, archive or missing inputs never inherit an audit', () {
    for (final inputs in <(Object?, Object?)>[
      ('a' * 40, auditedIosPrivacyArchiveSha256),
      (auditedIosPrivacySourceCommit, 'b' * 64),
      (null, null),
    ]) {
      final review = nativeIosPrivacyDisposition(
        sourceCommit: inputs.$1,
        archiveSha256: inputs.$2,
      );
      expect(review['status'], 'unreviewed');
      expect(review['productionReady'], false);
      expect(review['blockers'], isNotEmpty);
    }
  });

  for (final unknown in [false, true]) {
    test(
      'production ignores forged JSON approval and environment overrides (${unknown ? 'unknown' : 'known'})',
      () async {
        final root = Directory.systemTemp.createTempSync('native-privacy-');
        addTearDown(() => root.deleteSync(recursive: true));
        final baseline = File('${root.path}/tool/release_baseline.json');
        baseline.parent.createSync(recursive: true);
        baseline.writeAsStringSync(
          jsonEncode({
            'releaseTier': 'production',
            'nativeIosPrivacyReview': {
              'productionReady': true,
              'blockers': <String>[],
            },
            'rln': {
              'commit': unknown ? 'a' * 40 : auditedIosPrivacySourceCommit,
              'privacyApproved': true,
              'ios': {
                'archiveSha256': auditedIosPrivacyArchiveSha256,
                'requiredReasonApiApproved': true,
                'approvedReasons': ['E174.1'],
              },
            },
          }),
        );
        final script = File(
          'tool/native_ios_privacy_policy.dart',
        ).absolute.path;
        final result = await Process.run(
          Platform.environment['DART_BIN'] ?? 'dart',
          [script, '--production'],
          workingDirectory: root.path,
          environment: {
            'ALLOW_IOS_PRIVACY_SKIP': '1',
            'ALLOW_SUPPLY_CHAIN_NETWORK_SKIP': '1',
            'NATIVE_IOS_PRIVACY_APPROVED': '1',
            'RELEASE_PROFILE': 'internal-beta',
          },
        );
        expect(
          result.exitCode,
          1,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final report = jsonDecode(result.stdout as String) as Map;
        expect(report['mode'], 'production');
        expect(report['productionReady'], false);
        expect(report['blockers'], isNotEmpty);
        expect(
          report['status'],
          unknown ? 'unreviewed' : 'blocked-known-unresolved',
        );

        final diagnostic = await Process.run(
          Platform.environment['DART_BIN'] ?? 'dart',
          [script],
          workingDirectory: root.path,
        );
        expect(diagnostic.exitCode, 0);
        final beta = jsonDecode(diagnostic.stdout as String) as Map;
        expect(beta['mode'], 'internal-beta');
        expect(beta['productionReady'], false);
      },
    );
  }

  test(
    'supply-chain production includes the independent privacy disposition',
    () {
      final source = File('tool/validate_supply_chain.dart').readAsStringSync();
      expect(
        source,
        contains("report['nativeIosPrivacyReview'] = nativePrivacy"),
      );
      expect(source, contains("sourceCommit: rln['commit']"));
      expect(source, contains("archiveSha256: ios['archiveSha256']"));
      expect(
        source,
        matches(
          RegExp(
            r"for \(final blocker in nativePrivacy\['blockers'\]! as List<String>\) \{\s*_addProvenanceBlocker\(\s*production: production,\s*failures: failures,\s*warnings: warnings,\s*message: blocker,",
          ),
        ),
      );
    },
  );
}
