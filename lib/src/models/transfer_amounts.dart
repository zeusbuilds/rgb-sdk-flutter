part of 'utexo_core_models.dart';

/// Exact amount contract shared with RN beta.36 transfer history.
abstract interface class TransferAmount {
  /// Integer smallest asset units. Null is unknown, not zero.
  BigInt? get amount;

  /// Decimal base units safe to transport through JSON without precision loss.
  String? get amountBaseUnits;
}

Assignment _parseTransferAssignment(String value) {
  // The general core parser also accepts legacy bare amounts/rights. Native
  // history has a stricter grammar; do not turn an unknown shape into money.
  if (!const {'NonFungible', 'ReplaceRight', 'Any'}.contains(value) &&
      !RegExp(r'^(Fungible|InflationRight)\([0-9]+\)$').hasMatch(value)) {
    throw const NativeProtocolException(
      'Unsupported native transfer assignment.',
      field: 'transfer.assignment',
    );
  }
  return parseCoreAssignment(value);
}

BigInt? _transferAmount(
  String kind,
  Assignment? requested,
  List<Assignment> allocations,
) {
  final source = switch (kind) {
    'Send' || 'Burn' || 'Inflation' || 'Mint' => [?requested],
    'ReceiveBlind' || 'ReceiveWitness' || 'Issuance' => allocations,
    _ => const <Assignment>[],
  };
  final fungible = source.where((item) => item.type == 'Fungible');
  if (fungible.isEmpty || fungible.any((item) => item.amount == null)) {
    return null;
  }
  final maximum = BigInt.parse(rlnMaxUnsigned64Decimal);
  var total = BigInt.zero;
  for (final allocation in fungible) {
    final amount = allocation.amount!;
    if (amount.isNegative || amount > maximum) {
      throw const NativeProtocolException(
        'Transfer allocation must fit UInt64.',
        field: 'transfer.amount',
      );
    }
    total += amount;
  }
  if (total > maximum) {
    throw const NativeProtocolException(
      'Transfer amount exceeds UInt64.',
      field: 'transfer.amount',
    );
  }
  return total;
}
