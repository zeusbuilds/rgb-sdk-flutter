part of 'rgb_lib_wallet.dart';

const _maxSafeInteger = 9007199254740991;

String _feeRate(int value) =>
    _range(value, 'feeRate', 1, _maxSafeInteger).toString();

int _range(int value, String field, int minimum, int maximum) {
  if (value < minimum || value > maximum) {
    throw WalletValidationException(
      'Value must be between $minimum and $maximum.',
      field: field,
    );
  }
  return value;
}

String _required(String value, String field) {
  if (value.trim().isEmpty || value.contains('\u0000')) {
    throw WalletValidationException('A value is required.', field: field);
  }
  return value;
}

String _assetId(String value) {
  validateBurnAssetId(value);
  return value;
}

String? _optionalAssetId(String? value) =>
    value == null ? null : _assetId(value);

String _validateTxid(String value) {
  if (!burnHex32.hasMatch(value)) {
    throw const WalletValidationException(
      'Invalid transaction ID.',
      field: 'txid',
    );
  }
  return value.toLowerCase();
}

bool _boolean(Object? value) =>
    value is bool ? value : invalidRgbLibWire('result');

void _void(Object? value) {
  if (value != null) invalidRgbLibWire('result');
}

BurnResult _operationResult(Object? value) {
  final row = RgbLibWire(value, 'operation');
  return BurnResult(
    txid: row.txid('txid'),
    batchTransferIdx: row.integer('batchTransferIdx', max: 0x7fffffff),
  );
}

Map<String, Object?> _assetName(String name, int precision) => {
  'name': _required(name, 'name'),
  'precision': _range(precision, 'precision', 0, 18),
};

List<String> _amountList(List<BigInt> amounts, String field) => [
  for (final amount in amounts) rgbLibAmount(amount, field, positive: true),
];

({List<String> issued, List<String> inflation}) _issuanceAmounts(
  List<BigInt> issued,
  List<BigInt> inflation,
) {
  final amounts = _amountList(issued, 'amounts');
  final rights = _amountList(inflation, 'inflationAmounts');
  if ([...issued, ...inflation].fold(BigInt.zero, (sum, n) => sum + n) >
      BigInt.from(_maxSafeInteger)) {
    throw const RgbLibWalletException(
      'Issuance exceeds the supported total supply.',
      code: 'AMOUNT_OVERFLOW',
    );
  }
  return (issued: amounts, inflation: rights);
}

Map<String, Object?> _transferSelection(
  int? batchTransferIdx,
  bool noAssetOnly,
) => {
  'batchTransferIdx': batchTransferIdx == null
      ? null
      : _range(batchTransferIdx, 'batchTransferIdx', 1, 0x7fffffff),
  'noAssetOnly': noAssetOnly,
};
