import '../../errors/rgb_sdk_exception.dart';
import '../../models/burn_models.dart';
import '../../models/utexo_core_models.dart';
import '../utexo_wallet_types.dart';

/// The verified backup scope of the supported public `RgbLibWallet` API.
///
/// Raw upstream native mutators used outside its platform operation policy are
/// not a standalone restore-safe API.
///
/// An encrypted snapshot preserves private RGB state and payment evidence. It
/// does not establish that another copy has not authorized a later payment.
final class RgbLibBackupRecoveryCapabilities {
  const RgbLibBackupRecoveryCapabilities._();

  bool get encryptedSnapshotCreation => true;

  /// Local inspection and exact read-only Status; generic transfer refresh is
  /// blocked because it may ACK or broadcast pending transfers.
  bool get readOnlySnapshotRestoration => true;

  /// No approved authority currently establishes portable snapshot freshness.
  bool get restoredWalletSpending => false;

  /// A phrase does not reconstruct consignments, allocation history or outbox.
  bool get mnemonicOnlyRgbRecovery => false;
}

/// Identity of one RGB_L1 profile, independent of transient native handles.
final class RgbLibWalletIdentity {
  const RgbLibWalletIdentity({
    required this.id,
    required this.network,
    required this.masterFingerprint,
    this.recoveryCohort,
  });

  final String id;
  final String network;
  final String masterFingerprint;
  final String? recoveryCohort;

  String get protocol => 'RGB_L1';
}

/// Pinned artifact identity and bridge protocol reported by the mobile runtime.
final class RgbLibRuntimeInfo {
  const RgbLibRuntimeInfo({
    required this.version,
    required this.sourceRevision,
    required this.bridgeVersion,
    required this.capabilities,
    required this.integrationTree,
    required this.overlayPatchSha256,
    required this.sourceLockSha256,
    required this.sourceManifestSha256,
    this.contractRegistration = false,
    this.durableOnchainRecovery = false,
    this.supportsDispatchedRgbRevocation = false,
    this.supportsExistingOnlyOpen = false,
    this.supportsHostedDevSignet = false,
    this.supportsDurableHostedDevBridge = false,
  });

  static const expectedVersion =
      '0.3.0-beta.7-upstream-dev-bfa.7-bfa-flutter.2';
  static const expectedSourceRevision =
      '9ec49c08be2e68f08521281e3efbd760ec989cb9';
  static const expectedBridgeVersion = 5;
  static const expectedIntegrationTree =
      '8ac556ee67db70b93abb69b4ebd8fb0e6752dc0e';
  static const expectedOverlayPatchSha256 =
      'd3369ff9d4dfd5638781b259688ee9bd9f43e52464b61e6408ea7a75c81bc273';
  static const expectedSourceLockSha256 =
      '81af7c87fac88abbd40b1621ce2fa7655165b6b0c8bdd23faa313d25139330a6';
  static const expectedSourceManifestSha256 =
      'cf769ed49356e49a914dff638a4bddee9fd57fc6ebecf4b0193d8dd53aec2897';

  final String version;
  final String sourceRevision;
  final int bridgeVersion;
  final String integrationTree;
  final String overlayPatchSha256;
  final String sourceLockSha256;
  final String sourceManifestSha256;
  final BfaCapabilities capabilities;
  final bool contractRegistration;
  final bool durableOnchainRecovery;

  /// Explicit cancellation may revoke an exact dispatched RGB operation.
  /// This capability never permits a Status check to mutate the proxy.
  final bool supportsDispatchedRgbRevocation;

  /// The compiled platform wrapper can reject absent storage without creating
  /// a native profile. This is independent of the Rust archive capabilities.
  final bool supportsExistingOnlyOpen;

  /// The platform wrapper admits the explicitly configured hosted Dev profile.
  final bool supportsHostedDevSignet;

  /// The pinned artifact and platform wrapper support durable hosted Dev bridge operations.
  final bool supportsDurableHostedDevBridge;

  RgbLibBackupRecoveryCapabilities get backupRecovery =>
      const RgbLibBackupRecoveryCapabilities._();
}

enum RgbLibAssetSchema {
  nia('Nia'),
  cfa('Cfa'),
  uda('Uda'),
  ifa('Ifa'),
  bfa('Bfa');

  const RgbLibAssetSchema(this.wireValue);
  final String wireValue;
}

enum RgbLibReceiveAssignment {
  fungible('Fungible', requiresAmount: true),
  nonFungible('NonFungible'),
  inflationRight('InflationRight', requiresAmount: true),
  mintRight('MintRight'),
  any('Any');

  const RgbLibReceiveAssignment(this.wireValue, {this.requiresAmount = false});
  final String wireValue;
  final bool requiresAmount;
}

/// Asset metadata, including optional IFA/BFA links and exact native supplies.
final class RgbLibAssetMetadata {
  RgbLibAssetMetadata._(RgbLibWire value)
    : assetSchema = value.schema('assetSchema'),
      initialSupply = value.amount('initialSupply'),
      maxSupply = value.amount('maxSupply'),
      knownCirculatingSupply = value.amount('knownCirculatingSupply'),
      timestamp = value.decimalInt('timestamp'),
      name = value.requiredText('name'),
      precision = value.integer('precision', max: 18),
      ticker = value.optionalText('ticker'),
      details = value.optionalText('details'),
      rejectListUrl = value.optionalText('rejectListUrl'),
      linkedFromContract = value.optionalText('linkedFromContract'),
      linkedToContract = value.optionalText('linkedToContract');

  final RgbLibAssetSchema assetSchema;
  final BigInt initialSupply;
  final BigInt maxSupply;
  final BigInt knownCirculatingSupply;
  final int timestamp;
  final String name;
  final int precision;
  final String? ticker;
  final String? details;
  final String? rejectListUrl;
  final String? linkedFromContract;
  final String? linkedToContract;
}

/// A native-validated received mint requiring a matching external-chain lock.
/// This is an observation, not proof that the mint or backing lock completed.
final class RgbLibReceivedMint {
  RgbLibReceivedMint._(RgbLibWire value)
    : opid = value.requiredText('opid'),
      lockId = value.requiredText('lockId'),
      amount = value.amount('amount'),
      beforeBlock = value.amount('beforeBlock'),
      evmChainId = value.amount('evmChainId'),
      bridgeContract = value.requiredText('bridgeContract');

  final String opid;
  final String lockId;
  final BigInt amount;
  final BigInt beforeBlock;
  final BigInt evmChainId;
  final String bridgeContract;
}

/// An RGB_L1 receive request, with the transport encryption public key.
final class RgbLibReceiveData extends CoreInvoiceReceiveData {
  RgbLibReceiveData._(RgbLibWire value)
    : publicKey = value.text('publicKey'),
      super(
        invoice: value.requiredText('invoice'),
        recipientId: value.requiredText('recipientId'),
        expirationTimestamp: value.decimalInt('expirationTimestamp'),
        batchTransferIdx: value.integer('batchTransferIdx'),
      );

  final String publicKey;
}

/// Decoded RGB_L1 invoice. Decoding alone does not authorize sending.
final class RgbLibInvoiceData extends CoreInvoiceData {
  RgbLibInvoiceData._(String invoice, RgbLibWire value)
    : assignmentName = value.optionalText('assignmentName'),
      publicKey = value.optionalText('publicKey'),
      encryption = value.known('encryption', {
        'Required',
        'Unsupported',
        'Optional',
      }),
      unknownQueryParams = Map.unmodifiable({
        for (final row in value.rows('unknownQueryParams'))
          row.requiredText('key'): row.text('value'),
      }),
      super(
        invoice: invoice,
        recipientId: value.requiredText('recipientId'),
        recipientType: value.known('recipientType', {'Blind', 'Witness'}),
        assetSchema: value.optionalText('assetSchema') == null
            ? null
            : value.schema('assetSchema').wireValue,
        assetId: value.optionalText('assetId'),
        network: value.known('network', _networks),
        assignment: value.child('assignment').assignment,
        expirationTimestamp: value.optionalDecimalInt('expirationTimestamp'),
        transportEndpoints: value.strings('transportEndpoints'),
      );

  final String? assignmentName;
  final String? publicKey;
  final String encryption;
  final Map<String, String> unknownQueryParams;
}

/// RGB_L1 transfer history, including the wallet-local consignment location.
final class RgbLibTransfer extends CoreTransfer {
  RgbLibTransfer._(RgbLibWire value)
    : invoiceString = value.optionalText('invoiceString'),
      consignmentPath = value.optionalText('consignmentPath'),
      changeUtxos = List.unmodifiable(
        value.rows('changeUtxos').map((row) => row.outpoint),
      ),
      super(
        idx: value.integer('idx'),
        batchTransferIdx: value.integer('batchTransferIdx'),
        createdAt: value.decimalInt('createdAt'),
        updatedAt: value.decimalInt('updatedAt'),
        status: value.known('status', _transferStatuses),
        kind: value.known('kind', _transferKinds),
        requestedAssignment: value
            .optionalChild('requestedAssignment')
            ?.assignment,
        assignments: value
            .rows('assignments')
            .map((row) => row.assignment)
            .toList(),
        txid: value.optionalTxid('txid'),
        recipientId: value.optionalText('recipientId'),
        receiveUtxo: value.optionalChild('receiveUtxo')?.outpoint,
        changeUtxo: value.rows('changeUtxos').length == 1
            ? value.rows('changeUtxos').single.outpoint
            : null,
        expiration: value.optionalDecimalInt('expiration'),
        transportEndpoints: [
          for (final row in value.rows('transportEndpoints'))
            CoreTransferTransportEndpoint(
              endpoint: row.requiredText('endpoint'),
              transportType: row.requiredText('transportType'),
              used: row.flag('used'),
            ),
        ],
      );

  final String? invoiceString;
  final String? consignmentPath;

  /// Every native change output; the legacy singular field is null for multiple outputs.
  final List<Outpoint> changeUtxos;
}

/// Chain metadata; a height is absent when native has no observed tip.
typedef RgbLibNetworkInfo = ({String network, int? blockHeight});

/// Indexer protocol detected by the pinned native library.
typedef RgbLibIndexerCheck = ({String indexerProtocol});

const _networks = {
  'mainnet',
  'testnet',
  'testnet4',
  'regtest',
  'signet',
  'utexo',
};
const _transferKinds = {
  'Issuance',
  'ReceiveBlind',
  'ReceiveWitness',
  'Send',
  'Inflation',
  'Burn',
  'Mint',
  'Link',
};
const _transferStatuses = {
  'Initiated',
  'WaitingCounterparty',
  'WaitingSafeHeight',
  'WaitingBroadcast',
  'WaitingConfirmations',
  'Settled',
  'Failed',
};
final _u64Max = BigInt.parse('18446744073709551615');
final _decimal = RegExp(r'^(0|[1-9][0-9]{0,19})$');

String rgbLibAmount(BigInt value, String field, {bool positive = false}) {
  if (value.isNegative ||
      value > _u64Max ||
      (positive && value == BigInt.zero)) {
    throw WalletValidationException('Amount must fit UInt64.', field: field);
  }
  return value.toString();
}

Never invalidRgbLibWire(String field) => throw NativeProtocolException(
  'Invalid RGB_L1 native response.',
  field: field,
);

/// Strict decoder for typed maps on the platform channel.
final class RgbLibWire {
  RgbLibWire(Object? value, String field)
    : map = value is Map<Object?, Object?> ? value : invalidRgbLibWire(field);

  final Map<Object?, Object?> map;

  RgbLibReceivedMint get receivedMint => RgbLibReceivedMint._(this);

  RgbLibWire child(String key) => RgbLibWire(map[key], key);

  RgbLibWire? optionalChild(String key) => map[key] == null ? null : child(key);

  String text(String key) => switch (map[key]) {
    final String value => value,
    _ => invalidRgbLibWire(key),
  };

  String requiredText(String key) {
    final value = text(key);
    if (value.isEmpty) invalidRgbLibWire(key);
    return value;
  }

  String? optionalText(String key) => map[key] == null ? null : text(key);

  String known(String key, Set<String> options) {
    final value = text(key);
    return options.contains(value) ? value : invalidRgbLibWire(key);
  }

  String txid(String key) {
    final value = text(key);
    return burnHex32.hasMatch(value)
        ? value.toLowerCase()
        : invalidRgbLibWire(key);
  }

  String? optionalTxid(String key) => map[key] == null ? null : txid(key);

  bool flag(String key) => switch (map[key]) {
    final bool value => value,
    _ => invalidRgbLibWire(key),
  };

  int integer(String key, {int max = 0xffffffff}) => switch (map[key]) {
    final int value when value >= 0 && value <= max => value,
    final double value
        when value.isFinite && value >= 0 && value <= max && value % 1 == 0 =>
      value.toInt(),
    _ => invalidRgbLibWire(key),
  };

  BigInt amount(String key) {
    final value = text(key);
    if (!_decimal.hasMatch(value)) invalidRgbLibWire(key);
    final amount = BigInt.parse(value);
    return amount <= _u64Max ? amount : invalidRgbLibWire(key);
  }

  int decimalInt(String key) {
    final value = amount(key);
    return value.isValidInt ? value.toInt() : invalidRgbLibWire(key);
  }

  int? optionalDecimalInt(String key) =>
      map[key] == null ? null : decimalInt(key);

  List<Object?> list(String key) => switch (map[key]) {
    final List<Object?> value => value,
    _ => invalidRgbLibWire(key),
  };

  List<RgbLibWire> rows(String key) => rgbLibRows(list(key), key);

  List<String> strings(String key) => List.unmodifiable([
    for (final item in list(key))
      if (item is String) item else invalidRgbLibWire(key),
  ]);

  RgbLibAssetSchema schema(String key) {
    final value = text(key);
    return RgbLibAssetSchema.values.firstWhere(
      (schema) => schema.wireValue == value,
      orElse: () => invalidRgbLibWire(key),
    );
  }

  Assignment get assignment {
    final type = known('type', {
      'Fungible',
      'InflationRight',
      'NonFungible',
      'MintRight',
      'LinkRight',
      'Any',
    });
    final requiresAmount = type == 'Fungible' || type == 'InflationRight';
    if (requiresAmount != (map['amount'] != null)) {
      invalidRgbLibWire('assignment.amount');
    }
    return Assignment(
      type: type,
      amount: requiresAmount ? amount('amount') : null,
    );
  }

  Outpoint get outpoint => Outpoint(txid: txid('txid'), vout: integer('vout'));

  CoreAssetBalance get assetBalance => CoreAssetBalance(
    settled: amount('settled'),
    future: amount('future'),
    spendable: amount('spendable'),
    offchainOutbound: BigInt.zero,
    offchainInbound: BigInt.zero,
  );

  CoreBalance get btcBalance => CoreBalance(
    settled: decimalInt('settled'),
    future: decimalInt('future'),
    spendable: decimalInt('spendable'),
  );

  CoreTransaction get transaction {
    final confirmation = optionalChild('confirmationTime');
    return CoreTransaction(
      txid: txid('txid'),
      transactionType: known('transactionType', {
        'RgbSend',
        'Drain',
        'CreateUtxos',
        'SendBtc',
        'Incoming',
      }),
      received: decimalInt('received'),
      sent: decimalInt('sent'),
      fee: decimalInt('fee'),
      confirmationTime: confirmation == null
          ? null
          : CoreBlockTime(
              height: confirmation.integer('height'),
              timestamp: confirmation.decimalInt('timestamp'),
            ),
    );
  }

  CoreUnspent get unspent {
    final utxo = child('utxo');
    return CoreUnspent(
      utxo: CoreUtxo(
        outpoint: utxo.child('outpoint').outpoint,
        btcAmount: utxo.decimalInt('btcAmount'),
        colorable: utxo.flag('colorable'),
        exists: utxo.flag('exists'),
      ),
      rgbAllocations: [
        for (final row in rows('rgbAllocations'))
          CoreRgbAllocation(
            assetId: row.optionalText('assetId'),
            assignment: row.child('assignment').assignment,
            settled: row.flag('settled'),
          ),
      ],
      pendingBlinded: integer('pendingBlinded'),
    );
  }

  RgbLibTransfer get transfer => RgbLibTransfer._(this);
  RgbLibReceiveData get receive => RgbLibReceiveData._(this);
  RgbLibInvoiceData invoice(String encoded) =>
      RgbLibInvoiceData._(encoded, this);
  RgbLibAssetMetadata get metadata => RgbLibAssetMetadata._(this);

  RefreshedTransfer get refreshedTransfer {
    final failure = optionalChild('failure');
    final status = optionalText('updatedStatus');
    final code = failure?.requiredText('name');
    if (code != null &&
        !RegExp(r'^RGB_LIB_[A-Z][A-Za-z0-9]*$').hasMatch(code)) {
      invalidRgbLibWire('refresh.failure.name');
    }
    return RefreshedTransfer(
      updatedStatus: status == null
          ? null
          : known('updatedStatus', _transferStatuses),
      failure: code == null
          ? null
          : RefreshFailure(name: code, message: 'RGB transfer refresh failed.'),
    );
  }

  CoreMedia get media => RgbLibMedia(
    filePath: requiredText('filePath'),
    mime: requiredText('mime'),
    digest: requiredText('digest'),
  );

  CoreAssetToken get token => CoreAssetToken(
    index: integer('index'),
    ticker: optionalText('ticker'),
    name: optionalText('name'),
    details: optionalText('details'),
    embeddedMedia: flag('embeddedMedia'),
    media: optionalChild('media')?.media,
    attachments: [
      for (final row in rows('attachments'))
        CoreTokenAttachment(
          key: row.integer('key', max: 255),
          filePath: row.requiredText('filePath'),
          mime: row.requiredText('mime'),
          digest: row.requiredText('digest'),
        ),
    ],
    reserves: flag('reserves'),
  );

  CoreAsset get asset {
    final id = requiredText('assetId');
    final name = requiredText('name');
    final details = optionalText('details');
    final precision = integer('precision', max: 18);
    final timestamp = decimalInt('timestamp');
    final addedAt = decimalInt('addedAt');
    final balance = child('balance').assetBalance;
    final media = optionalChild('media')?.media;
    return switch (schema('schema')) {
      RgbLibAssetSchema.nia => CoreAssetNia(
        assetId: id,
        name: name,
        details: details,
        precision: precision,
        timestamp: timestamp,
        addedAt: addedAt,
        balance: balance,
        media: media,
        ticker: requiredText('ticker'),
        issuedSupply: amount('issuedSupply'),
      ),
      RgbLibAssetSchema.cfa => CoreAssetCfa(
        assetId: id,
        name: name,
        details: details,
        precision: precision,
        timestamp: timestamp,
        addedAt: addedAt,
        balance: balance,
        media: media,
        issuedSupply: amount('issuedSupply'),
      ),
      RgbLibAssetSchema.uda => CoreAssetUda(
        assetId: id,
        name: name,
        details: details,
        precision: precision,
        timestamp: timestamp,
        addedAt: addedAt,
        balance: balance,
        ticker: requiredText('ticker'),
        token: optionalChild('token')?.token,
      ),
      RgbLibAssetSchema.ifa => CoreAssetIfa(
        assetId: id,
        name: name,
        details: details,
        precision: precision,
        timestamp: timestamp,
        addedAt: addedAt,
        balance: balance,
        media: media,
        ticker: requiredText('ticker'),
        initialSupply: amount('initialSupply'),
        maxSupply: amount('maxSupply'),
        knownCirculatingSupply: amount('knownCirculatingSupply'),
        rejectListUrl: optionalText('rejectListUrl'),
      ),
      RgbLibAssetSchema.bfa => CoreAssetBfa(
        assetId: id,
        name: name,
        details: details,
        precision: precision,
        timestamp: timestamp,
        addedAt: addedAt,
        balance: balance,
        media: media,
        ticker: requiredText('ticker'),
        initialSupply: amount('initialSupply'),
        rejectListUrl: optionalText('rejectListUrl'),
      ),
    };
  }
}

/// Asset media with the content digest supplied by the native wallet.
final class RgbLibMedia extends CoreMedia {
  const RgbLibMedia({
    required super.filePath,
    required super.mime,
    required this.digest,
  });

  final String digest;
}

List<RgbLibWire> rgbLibRows(Object? value, String field) {
  if (value is! List<Object?>) invalidRgbLibWire(field);
  return [for (final row in value) RgbLibWire(row, field)];
}
