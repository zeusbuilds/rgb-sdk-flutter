import 'package:flutter_test/flutter_test.dart';

import '../tool/native_security_policy.dart';

void main() {
  test('current exact native source cannot qualify through Pub-only audit', () {
    final blockers = nativeProductionBlockers(
      'ecc69f20308231400561f6f060fea88acfa40cc4',
    );
    expect(blockers, hasLength(4));
    for (final finding in ['P03:', 'P04:', 'P06:', 'RUSTSEC-2026-0098/0099']) {
      expect(blockers.any((blocker) => blocker.contains(finding)), true);
    }
  });
  test('new source pin does not silently inherit an old source review', () {
    final blockers = nativeProductionBlockers('1' * 40);
    expect(blockers, hasLength(1));
    expect(blockers.single, contains('no approved production'));
  });
  test('RGB_L1 has a separate fail-closed native lock disposition', () {
    final blockers = rgbLibProductionBlockers(
      '68a48cc0d37e0c6777871d7c5780e92752a3abdaf5b9cae9b0e16807888bb290',
    );
    expect(blockers.single, contains('nine RustSec advisories'));
    expect(rgbLibProductionBlockers('1' * 64).single, contains('no approved'));
  });
  test('patched BFA.7 audit does not grant production approval', () {
    final blockers = rgbLibProductionBlockers(
      '4b675f6187e069e6236033415ff157379b039717b387a1dd596669ec52f6a21f',
    );
    expect(blockers, hasLength(1));
    expect(blockers.single, contains('zero known vulnerabilities'));
    expect(blockers.single, contains('Three unmaintained dependencies'));
    expect(blockers.single, contains('backup-freshness'));
    expect(blockers.single, contains('not production approved'));
  });
}
