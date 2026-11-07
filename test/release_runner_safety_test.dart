import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production privacy blocks builds and supplied evidence in aggregate',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'rgb-privacy-aggregate-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final result = await Process.run(
        'bash',
        [
          '-c',
          r'''
source "$1"
WORKTREE_DIRTY=false
ensure_release_disk_space() { return 0; }
eval "$(declare -f run_step | sed '1s/run_step/original_run_step/')"
run_step() {
  case "$1" in
    'release disk-space preflight'|'production iOS required-reason API disposition') original_run_step "$@" ;;
    *) printf 'UNEXPECTED_BUILD_OR_SUPPLIED_EVIDENCE'; return 73 ;;
  esac
}
if main; then result=0; else result=$?; fi
write_report
printf 'REPORT:%s\n' "$REPORT_FILE"
exit "$result"
''',
          'privacy-aggregate',
          File('tool/test_release_candidate.sh').absolute.path,
        ],
        environment: {
          'REPORT_DIR': temp.path,
          'RELEASE_PROFILE': 'mainnet-onchain',
          'ALLOW_IOS_PRIVACY_SKIP': '1',
          'NATIVE_IOS_PRIVACY_APPROVED': '1',
        },
      );
      expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout,
        isNot(contains('UNEXPECTED_BUILD_OR_SUPPLIED_EVIDENCE')),
      );
      final reports = temp.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.json'),
      );
      expect(reports, hasLength(1));
      final report = jsonDecode(reports.single.readAsStringSync()) as Map;
      expect(report['status'], 'failed');
      expect(report['releaseEligible'], false);
      expect((report['steps'] as List).last, containsPair('exitCode', 1));
      expect(
        (report['steps'] as List).last,
        containsPair('name', 'production iOS required-reason API disposition'),
      );
    },
  );

  test('release preflight stops before work on insufficient disk', () async {
    final temp = Directory.systemTemp.createTempSync('rgb-disk-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final result = await Process.run(
      'bash',
      [
        '-c',
        '''
source "\$1"
WORKTREE_DIRTY=false
ensure_release_disk_space() { return 1; }
eval "\$(declare -f run_step | sed '1s/run_step/original_run_step/')"
run_step() {
  if [[ "\$1" != 'release disk-space preflight' ]]; then
    printf 'UNEXPECTED_BUILD_WORK'
    exit 73
  fi
  original_run_step "\$@"
}
main
''',
        'runner-test',
        File('tool/test_release_candidate.sh').absolute.path,
      ],
      environment: {'REPORT_DIR': temp.path},
    );
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('release disk-space preflight'));
    expect(result.stdout, isNot(contains('UNEXPECTED_BUILD_WORK')));
  });

  test(
    'mainnet production profile never dispatches legacy stack/LN runners',
    () async {
      final temp = Directory.systemTemp.createTempSync('rgb-profile-runner-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final result = await Process.run(
        'bash',
        [
          '-c',
          r'''
source "$1"
WORKTREE_DIRTY=false
run_step() {
  printf 'DISPATCH:%s\n' "$*"
  STEP_NAMES+=("$1")
  STEP_CODES+=(0)
}
main
''',
          'profile-safety',
          File('tool/test_release_candidate.sh').absolute.path,
        ],
        environment: {
          'REPORT_DIR': temp.path,
          'RELEASE_PROFILE': 'mainnet-onchain',
          'RUN_PLATFORM': '1',
          'IOS_DEVICE': 'owned-ios',
          'ANDROID_DEVICE': 'owned-android',
        },
      );
      // The deliberately dirty development checkout may invalidate the immutable
      // candidate. This spy verifies dispatches without executing them.
      final output = '${result.stdout}';
      expect(output, contains('validate_supply_chain.dart --production'));
      expect(output, contains('validate_child_evidence.dart'));
      expect(output, contains('mainnet-onchain'));
      for (final forbidden in [
        'test_platform_unfunded.sh',
        'test_platform_funded.sh',
        'test_external_signer_restart.sh',
        'regtest.sh',
        'prepare iOS simulator',
        'prepare Android device',
      ]) {
        expect(output, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('unknown release scope stops before build or native work', () async {
    final temp = Directory.systemTemp.createTempSync('rgb-unknown-profile-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final result = await Process.run(
      'bash',
      [
        '-c',
        r'''
source "$1"
WORKTREE_DIRTY=false
run_step() { printf 'UNEXPECTED_WORK'; exit 73; }
main
''',
        'profile-safety',
        File('tool/test_release_candidate.sh').absolute.path,
      ],
      environment: {'REPORT_DIR': temp.path, 'RELEASE_PROFILE': 'typo'},
    );
    expect(result.exitCode, 1);
    expect(result.stdout, isNot(contains('UNEXPECTED_WORK')));
    expect(result.stderr, contains('Unknown release profile'));
  });

  for (final runner in [
    'test_clean_consumer_matrix.sh',
    'test_release_candidate.sh',
  ]) {
    test('$runner preserves a nested function failure', () async {
      final temp = Directory.systemTemp.createTempSync('rgb-runner-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final script = File('tool/$runner').absolute.path;
      final result = await Process.run(
        'bash',
        [
          '-c',
          '''
source "\$1"
failure() { false; printf 'MASKED_FAILURE'; }
run_step injected-failure failure
[[ "\$FAILED" == 1 && "\${STEP_CODES[0]}" == 1 ]]
''',
          'runner-test',
          script,
        ],
        environment: {
          'REPORT_DIR': temp.path,
          'CONSUMER_WORK_DIR': '${temp.path}/consumer',
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, isNot(contains('MASKED_FAILURE')));
    });
  }

  test(
    'required skips can never be overridden into a passing release',
    () async {
      final temp = Directory.systemTemp.createTempSync('rgb-skip-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final result = await Process.run(
        'bash',
        [
          '-c',
          '''
source "\$1"
mark_required_skip native-test missing-device
[[ "\$FAILED" == 1 && "\${STEP_CODES[0]}" == 125 ]]
''',
          'runner-test',
          File('tool/test_release_candidate.sh').absolute.path,
        ],
        environment: {'REPORT_DIR': temp.path, 'ALLOW_SKIPPED': '1'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );

  test('release finalizer hashes the finished log even on failure', () async {
    final temp = Directory.systemTemp.createTempSync('rgb-log-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final result = await Process.run(
      'bash',
      [
        '-c',
        '''
source "\$1"
start_logging
trap finalize EXIT
printf 'final-log-line\\n'
exit 42
''',
        'runner-test',
        File('tool/test_release_candidate.sh').absolute.path,
      ],
      environment: {'REPORT_DIR': temp.path},
    );
    expect(result.exitCode, 42, reason: '${result.stdout}\n${result.stderr}');
    final reportFile = temp.listSync().whereType<File>().singleWhere(
      (f) => f.path.endsWith('.json'),
    );
    final report =
        jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
    final log = temp.listSync().whereType<File>().singleWhere(
      (f) => f.path.endsWith('.log'),
    );
    expect(log.readAsStringSync(), contains('final-log-line'));
    expect(
      report['logSha256'],
      sha256.convert(log.readAsBytesSync()).toString(),
    );
    expect(report['releaseEligible'], false);
    expect(report['status'], 'failed');
  });

  const requiredNativeEntries = [
    'lib/arm64-v8a/libapp.so',
    'lib/arm64-v8a/libflutter.so',
    'lib/arm64-v8a/libjnidispatch.so',
    'lib/arm64-v8a/librgb_lightning_node.so',
    'lib/arm64-v8a/librgblibuniffi.so',
  ];
  for (final (label, entries, compatible, diagnostic) in [
    ('complete arm64 runtime', requiredNativeEntries, true, null),
    (
      'extra ABI without Flutter runtime',
      [...requiredNativeEntries, 'lib/x86_64/librgb_lightning_node.so'],
      false,
      'unexpected native path or ABI',
    ),
    (
      'missing Flutter engine',
      requiredNativeEntries.where((entry) => !entry.endsWith('/libflutter.so')),
      false,
      'Missing required Flutter/RLN/RGB Lib/JNA libraries',
    ),
    (
      'duplicate native entry',
      [...requiredNativeEntries, requiredNativeEntries.first],
      false,
      'Duplicate native APK entries',
    ),
  ]) {
    test('consumer inventory checks $label', () async {
      final temp = Directory.systemTemp.createTempSync('rgb-consumer-apk-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final apk = File('${temp.path}/consumer.apk');
      final reportFile = File('${temp.path}/inventory.json');
      final fixture = await Process.run('python3', [
        '-c',
        '''
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as archive:
    for entry in json.loads(sys.argv[2]):
        archive.writestr(entry, b'inventory fixture, not an ELF binary')
''',
        apk.path,
        jsonEncode(entries.toList()),
      ]);
      expect(fixture.exitCode, 0, reason: '${fixture.stderr}');
      final result = await Process.run(
        'bash',
        [
          '-c',
          'source "\$1"; verify_consumer_apk_inventory "\$2" "\$3"',
          'consumer-inventory-test',
          File('tool/test_clean_consumer_matrix.sh').absolute.path,
          apk.path,
          reportFile.path,
        ],
        environment: {'REPORT_DIR': temp.path},
      );
      expect(
        result.exitCode,
        compatible ? 0 : 1,
        reason: '${result.stdout}\n${result.stderr}',
      );
      final report = jsonDecode(reportFile.readAsStringSync()) as Map;
      expect(report['compatible'], compatible);
      expect(report['expectedAbis'], ['arm64-v8a']);
      if (diagnostic != null) {
        expect(report['failures'].toString(), contains(diagnostic));
      }
    });
  }
}
