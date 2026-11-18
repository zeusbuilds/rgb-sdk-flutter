import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';

CoreTransfer _transfer(
  String kind, {
  String? requested,
  List<String> actual = const [],
}) => RlnTransfer.fromMap({
  'idx': 1,
  'status': 'Settled',
  'kind': kind,
  'requestedAssignment': requested,
  'assignments': actual,
  'transportEndpoints': <Object>[],
}).toCore();

void main() {
  for (final kind in ['Send', 'Burn', 'Inflation']) {
    test('$kind uses requested amount, never change or whole batch', () {
      final transfer = _transfer(
        kind,
        requested: 'Fungible(10)',
        actual: ['Fungible(900)', 'Fungible(100)'],
      );
      expect(transfer.amount, BigInt.from(10));
      expect(transfer.amountBaseUnits, '10');
      expect(transfer.requestedAssignment!.amountBaseUnits, '10');
      expect(_transfer(kind, actual: ['Fungible(1000)']).amount, isNull);
      expect(
        _transfer(kind, requested: 'Any', actual: ['Fungible(1000)']).amount,
        isNull,
      );
    });
  }
  for (final kind in ['ReceiveBlind', 'ReceiveWitness', 'Issuance']) {
    test('$kind sums actual allocations, never requested invoice amount', () {
      final transfer = _transfer(
        kind,
        requested: 'Fungible(1000)',
        actual: ['Fungible(10)', 'Fungible(20)', 'InflationRight(99)'],
      );
      expect(transfer.amount, BigInt.from(30));
      expect(transfer.amountBaseUnits, '30');
      expect(_transfer(kind, requested: 'Fungible(1000)').amount, isNull);
      expect(_transfer(kind, actual: ['NonFungible']).amount, isNull);
      expect(_transfer(kind, actual: ['Fungible(0)']).amount, BigInt.zero);
    });
  }
  test('UInt64 and JS boundaries preserve exact base units', () {
    for (final value in [
      '9007199254740991',
      '9007199254740992',
      '9223372036854775808',
      '18446744073709551615',
    ]) {
      final transfer = _transfer('Send', requested: 'Fungible($value)');
      expect(transfer.amount, BigInt.parse(value));
      expect(transfer.amountBaseUnits, value);
      expect(
        parseCoreAssignment('InflationRight($value)').amountBaseUnits,
        value,
      );
    }
    expect(
      () => _transfer(
        'ReceiveBlind',
        actual: ['Fungible(18446744073709551615)', 'Fungible(1)'],
      ),
      throwsA(isA<NativeProtocolException>()),
    );
  });
  test('legacy RLN change output populates the shared change outputs list', () {
    final txid = 'ab' * 32;
    final transfer = RlnTransfer.fromMap({
      'idx': 1,
      'status': 'Settled',
      'kind': 'Send',
      'assignments': <Object>[],
      'transportEndpoints': <Object>[],
      'changeUtxo': '$txid:2',
    }).toCore();
    final output = transfer.changeUtxos.single;
    expect((output.txid, output.vout), (txid, 2));
  });
  test('malformed native amounts fail closed before exposing history', () {
    for (final kind in ['Fungible', 'InflationRight']) {
      for (final invalid in [
        '01',
        '-1',
        '+1',
        '1.0',
        '',
        '18446744073709551616',
        '1${'0' * 200}',
      ]) {
        expect(
          () => _transfer('Send', requested: '$kind($invalid)'),
          throwsA(isA<NativeProtocolException>()),
        );
      }
    }
  });
  test(
    'manually supplied allocations cannot create negative or invented amounts',
    () {
      CoreTransfer make(List<Assignment> assignments) => CoreTransfer(
        idx: 1,
        status: 'Settled',
        kind: 'ReceiveBlind',
        assignments: assignments,
        transportEndpoints: const [],
      );
      expect(make(const [Assignment(type: 'Fungible')]).amount, isNull);
      expect(
        () => make([Assignment(type: 'Fungible', amount: -BigInt.one)]),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );
}
