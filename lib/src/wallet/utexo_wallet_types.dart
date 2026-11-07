import '../errors/rgb_sdk_exception.dart';

/// Configuration used to create an RLN node.
///
/// [storageDirPath] must point at an app-owned persistent directory. On native
/// platforms the SDK validates owner-only directory permissions before handing
/// the path to RGB Lightning Node. Amount-like ports and sizes use integer
/// native units.
class UtexoWalletConfig {
  UtexoWalletConfig({
    required this.storageDirPath,
    this.network = 'regtest',
    this.daemonListeningPort = 9735,
    this.ldkPeerListeningPort = 9736,
    this.maxMediaUploadSizeMb = 20,
    this.enableVirtualChannelsV0,
    List<String>? virtualPeerPubkeys,
    this.vssUrl,
    this.vssAllowHttp = false,
    this.vssAllowEmptyRestore = false,
    this.lspBaseUrl,
    this.lspBearerToken,
    this.reuseAddresses = false,
    this.xpubVan,
    this.xpubCol,
    this.masterFingerprint,
  }) : virtualPeerPubkeys = virtualPeerPubkeys == null
           ? null
           : List<String>.unmodifiable(virtualPeerPubkeys);

  /// Persistent RLN node storage directory path.
  final String storageDirPath;

  /// SDK-facing network name: `mainnet`, `testnet`, `testnet4`, `signet`,
  /// `utexo`, or `regtest`. Native Bitcoin naming is not an input alias.
  /// Mainnet is onchain-only and supports the built-in password signer only.
  /// External/custom signers fail before node creation on mainnet until their
  /// native crash recovery, teardown and VSS key derivation are qualified.
  final String network;

  /// Lightning daemon listening port.
  final int daemonListeningPort;

  /// LDK peer listening port.
  final int ldkPeerListeningPort;

  /// Maximum media upload size in megabytes.
  final int maxMediaUploadSizeMb;

  /// Optional native virtual-channel feature flag.
  final bool? enableVirtualChannelsV0;

  /// Optional virtual peer public keys. The list is defensively copied.
  final List<String>? virtualPeerPubkeys;

  /// Optional VSS service URL.
  /// Recoverable on-chain sends reject VSS configuration because its restore
  /// does not include the durable operation outbox.
  final String? vssUrl;

  /// Whether non-loopback plain HTTP is allowed for VSS.
  final bool vssAllowHttp;

  /// Whether an empty VSS restore result is accepted.
  final bool vssAllowEmptyRestore;

  /// Optional LSP base URL.
  final String? lspBaseUrl;

  /// Optional bearer token for the configured LSP.
  final String? lspBearerToken;

  /// Whether native address generation may reuse addresses.
  final bool reuseAddresses;

  /// Reserved identity option; non-null values are rejected before node creation.
  /// Supply identity through the signer, not through this legacy field.
  final String? xpubVan;

  /// Reserved identity option; non-null values are rejected before node creation.
  final String? xpubCol;

  /// Reserved identity option; non-null values are rejected before node creation.
  final String? masterFingerprint;
}

/// Network service configuration used to unlock an initialized wallet.
class UtexoUnlockConfig {
  UtexoUnlockConfig({
    this.bitcoindRpcUsername,
    this.bitcoindRpcPassword,
    this.bitcoindRpcHost,
    this.bitcoindRpcPort,
    this.indexerUrl,
    this.proxyEndpoint,
    List<String> announceAddresses = const <String>[],
    this.announceAlias,
    this.gossipRgsServerUrl,
    this.ethRpcUrl,
  }) : announceAddresses = List<String>.unmodifiable(announceAddresses);

  /// Optional Bitcoin RPC username.
  final String? bitcoindRpcUsername;

  /// Optional Bitcoin RPC password. Apps own durable storage of this secret.
  final String? bitcoindRpcPassword;

  /// Optional Bitcoin RPC host.
  final String? bitcoindRpcHost;

  /// Optional Bitcoin RPC port.
  final int? bitcoindRpcPort;

  /// Electrum/indexer endpoint accepted by the native RLN node.
  final String? indexerUrl;

  /// Optional proxy endpoint used by RLN.
  final String? proxyEndpoint;

  /// Peer announce addresses. The list is defensively copied.
  final List<String> announceAddresses;

  /// Optional node alias announced through Lightning.
  final String? announceAlias;

  /// Optional RGS server URL, supported by the native password-backed signer.
  /// Native external-signer mode rejects it before dispatch because that native
  /// unlock API does not accept RGS configuration.
  final String? gossipRgsServerUrl;

  /// Ethereum RPC for native BFA validation with either built-in signer.
  ///
  /// May contain credentials; never log or expose it to a dApp.
  /// RLN 0.16 external unlock uses its request-based API to preserve this value.
  final String? ethRpcUrl;
}

/// Capability flags for optional wallet feature groups.
///
/// These flags are derived from the public carriers. The current Flutter/RLN
/// platform has no rgb-lib PSBT engine and no externally signed begin/end
/// wallet flows, matching the current React Native contract.
class WalletCapabilities {
  const WalletCapabilities({
    required this.psbtSigning,
    required this.beginEndFlows,
    this.rgbUtxoCreation = true,
    this.rgbAssetIssuance = true,
  });

  /// Whether PSBT signing is available through the stable wallet facade.
  final bool psbtSigning;

  /// Whether begin/end wallet flows are available.
  final bool beginEndFlows;

  /// Whether RGB UTXO creation is supported for the active signer.
  final bool rgbUtxoCreation;

  /// Whether RGB asset issuance is supported for the active signer.
  final bool rgbAssetIssuance;
}

/// Optional PSBT feature group. It is absent while the pinned native/RN
/// baseline has no production PSBT engine.
abstract interface class PsbtWalletCarrier {
  /// Signs a base64 PSBT. Any supplied mnemonic is borrowed, never persisted.
  Future<String> signPsbt(String psbt, {String? mnemonic});

  /// Estimates the absolute sat fee, virtual size, and sat/vbyte fee rate.
  Future<PsbtFeeEstimate> estimateFee(String psbtBase64);
}

/// Fee estimation contract for the optional PSBT carrier; not an RLN capability.
class PsbtFeeEstimate {
  const PsbtFeeEstimate({
    required this.fee,
    required this.vbytes,
    required this.feeRate,
  });

  /// Absolute transaction fee in satoshis.
  final int fee;

  /// Transaction virtual size in vbytes.
  final int vbytes;

  /// Fee rate in satoshis per vbyte.
  final double feeRate;
}

/// Optional begin/end wallet-flow feature group. It is absent while the pinned
/// native/RN baseline has no externally signed begin/end flow.
abstract interface class BeginEndWalletCarrier {
  /// Builds an unsigned UTXO-creation PSBT without broadcasting it.
  Future<String> createUtxosBegin({
    bool? upTo,
    int? num,
    int? size,
    double? feeRate,
  });

  /// Finalizes a signed PSBT, returning the engine's created UTXO count.
  Future<int> createUtxosEnd({required String signedPsbt, bool? skipSync});

  /// Builds an unsigned RGB transfer PSBT.
  Future<String> onchainSendBegin(RgbSendRequest request);

  /// Finalizes the RGB transfer, returning its txid and batch index.
  Future<OnchainSendResponse> onchainSendEnd({
    required String signedPsbt,
    bool? skipSync,
  });

  /// Builds an unsigned Bitcoin transfer PSBT; amount is sats, feeRate sat/vbyte.
  Future<String> sendBtcBegin({
    required String address,
    required int amount,
    required double feeRate,
    bool? skipSync,
  });

  /// Finalizes a Bitcoin PSBT and returns the transaction ID.
  Future<String> sendBtcEnd({required String signedPsbt, bool? skipSync});

  /// Builds an unsigned inflation PSBT using integer smallest RGB units.
  Future<String> inflateBegin(InflateAssetIfaRequest request);

  /// Finalizes inflation and returns the transaction ID plus batch index.
  Future<OnchainSendResponse> inflateEnd({required String signedPsbt});
}

/// Assignment supported by the RLN invoice format.
enum RgbReceiveAssignmentKind { fungible, nonFungible, inflationRight, any }

/// Request for a blinded or witness RGB invoice.
///
/// [amount] is an RGB asset amount in the asset's smallest unit. [durationSeconds]
/// is a wall-clock expiry duration in seconds. [minConfirmations] is the native
/// RGB confirmation threshold and must fit UInt8.
class RgbInvoiceRequest {
  const RgbInvoiceRequest({
    this.assetId,
    this.amount,
    this.assignmentKind,
    this.durationSeconds,
    this.minConfirmations = 0,
    this.witness = true,
  });

  /// Optional RGB asset ID.
  final String? assetId;

  /// Optional asset amount in smallest units.
  final int? amount;

  /// Defaults to a fungible assignment with [amount], or any assignment
  /// when omitted. Inflation rights also require a positive amount.
  final RgbReceiveAssignmentKind? assignmentKind;

  /// Optional invoice lifetime in seconds.
  final int? durationSeconds;

  /// Required minimum Bitcoin confirmations.
  final int minConfirmations;

  /// Whether `onchainReceive` creates a witness invoice. Dedicated
  /// `blindReceive` and `witnessReceive` methods ignore this field and enforce
  /// their named receive mode.
  final bool witness;
}

/// Request for an atomic RGB on-chain transfer.
///
/// [assetId] may be omitted when the invoice encodes it. An atomic
/// `onchainSend` can take an omitted [amount] from a fungible invoice.
/// Recoverable sends require an explicit reviewed amount. For asset-less
/// donation invoices, pass [assetId] and
/// [amount] explicitly and set [donation]. [feeRate] is sats/vbyte and must be
/// integer-equivalent for the current native bridge. [skipSync] is fail-fast
/// because the pinned native artifacts accept the RN argument but do not
/// implement a corresponding RLN request field.
class RgbSendRequest {
  const RgbSendRequest({
    required this.invoice,
    this.assetId,
    this.amount,
    this.donation = false,
    this.feeRate = 1,
    this.minConfirmations = 1,
    this.skipSync = false,
    this.witnessAmountSat,
    this.witnessBlinding,
  });

  /// RGB invoice to pay.
  final String invoice;

  /// Optional RGB asset ID.
  final String? assetId;

  /// Optional asset amount in smallest units.
  final int? amount;

  /// Whether the transfer is an asset donation.
  final bool donation;

  /// Bitcoin fee rate in sats/vbyte; must be integer-equivalent.
  final double feeRate;

  /// Required minimum Bitcoin confirmations.
  final int minConfirmations;

  /// Unsupported native `skipSync` flag. `true` fails before native execution.
  final bool skipSync;

  /// Optional witness amount in sats.
  final int? witnessAmountSat;

  /// Optional witness blinding value.
  final int? witnessBlinding;
}

/// Request for atomic inflation of an IFA RGB asset.
class InflateAssetIfaRequest {
  InflateAssetIfaRequest({
    required this.assetId,
    required List<int> inflationAmounts,
    this.feeRate = 1,
    this.minConfirmations = 1,
  }) : inflationAmounts = List<int>.unmodifiable(inflationAmounts);

  /// RGB IFA asset ID.
  final String assetId;

  /// Inflation amounts in the asset's smallest unit.
  final List<int> inflationAmounts;

  /// Bitcoin fee rate in sats/vbyte; must be integer-equivalent.
  final double feeRate;

  /// Required minimum Bitcoin confirmations.
  final int minConfirmations;
}

/// Result of atomically inflating an IFA asset.
class InflateAssetIfaResponse {
  const InflateAssetIfaResponse({required this.txid});

  final String txid;
}

/// Fee-rate estimate for a target confirmation window.
class FeeEstimationResponse {
  const FeeEstimationResponse({required this.feeRate});

  /// Satoshis per virtual byte.
  final double feeRate;
}

/// Capability information reported for an indexer endpoint.
class IndexerCheckResponse {
  const IndexerCheckResponse({required this.indexerProtocol});

  final String indexerProtocol;
}

/// RN-core transfer status returned by UTEXO status helpers.
///
/// This intentionally remains a string alias for React Native parity. Prefer
/// comparing against [CoreTransferStatuses] constants instead of hard-coding
/// status literals in app code.
typedef CoreTransferStatus = String;

/// Canonical RLN invoice-status string returned by public wallet helpers.
typedef RlnInvoiceStatusValue = String;

/// Canonical RLN payment-status string returned by public wallet helpers.
typedef RlnPaymentStatusValue = String;

/// Known RN-core transfer-status values.
abstract final class CoreTransferStatuses {
  /// Transfer has been initialized locally.
  static const CoreTransferStatus initiated = 'Initiated';

  /// Counterparty action is still required.
  static const CoreTransferStatus waitingCounterparty = 'WaitingCounterparty';

  /// Transfer is waiting for a safe Bitcoin chain height.
  static const CoreTransferStatus waitingSafeHeight = 'WaitingSafeHeight';

  /// Transfer is ready and waiting for transaction broadcast.
  static const CoreTransferStatus waitingBroadcast = 'WaitingBroadcast';

  /// Bitcoin confirmations are still required.
  static const CoreTransferStatus waitingConfirmations = 'WaitingConfirmations';

  /// Transfer has settled.
  static const CoreTransferStatus settled = 'Settled';

  /// Transfer failed.
  static const CoreTransferStatus failed = 'Failed';
}

/// Failure reported while refreshing one RGB batch transfer.
class RefreshFailure {
  const RefreshFailure({required this.name, required this.message});

  final String name;
  final String message;
}

/// Refresh outcome for one RGB batch transfer.
class RefreshedTransfer {
  const RefreshedTransfer({this.updatedStatus, this.failure});

  final CoreTransferStatus? updatedStatus;
  final RefreshFailure? failure;
}

/// Transfer refresh outcomes keyed by rgb-lib batch transfer ID.
class RefreshTransfersResult {
  RefreshTransfersResult({required Map<int, RefreshedTransfer> transfers})
    : transfers = Map<int, RefreshedTransfer>.unmodifiable(transfers);

  final Map<int, RefreshedTransfer> transfers;
}

/// Canonical RLN invoice statuses from `@utexo/rgb-sdk-core`.
abstract final class RlnInvoiceStatuses {
  /// Invoice has not reached a terminal state.
  static const RlnInvoiceStatusValue pending = 'Pending';

  /// HODL invoice can be claimed.
  static const RlnInvoiceStatusValue claimable = 'Claimable';

  /// HODL invoice claim is in progress.
  static const RlnInvoiceStatusValue claiming = 'Claiming';

  /// Invoice settled successfully.
  static const RlnInvoiceStatusValue succeeded = 'Succeeded';

  /// Invoice was cancelled.
  static const RlnInvoiceStatusValue cancelled = 'Cancelled';

  /// Invoice failed.
  static const RlnInvoiceStatusValue failed = 'Failed';

  /// Invoice expired.
  static const RlnInvoiceStatusValue expired = 'Expired';
}

/// Canonical RLN payment statuses from `@utexo/rgb-sdk-core`.
abstract final class RlnPaymentStatuses {
  /// Payment has not reached a terminal state.
  static const RlnPaymentStatusValue pending = 'Pending';

  /// HODL payment can be claimed.
  static const RlnPaymentStatusValue claimable = 'Claimable';

  /// HODL payment claim is in progress.
  static const RlnPaymentStatusValue claiming = 'Claiming';

  /// Payment settled successfully.
  static const RlnPaymentStatusValue succeeded = 'Succeeded';

  /// Payment was cancelled.
  static const RlnPaymentStatusValue cancelled = 'Cancelled';

  /// Payment failed.
  static const RlnPaymentStatusValue failed = 'Failed';
}

const List<RlnInvoiceStatusValue> _invoiceStatusValues = <String>[
  RlnInvoiceStatuses.pending,
  RlnInvoiceStatuses.claimable,
  RlnInvoiceStatuses.claiming,
  RlnInvoiceStatuses.succeeded,
  RlnInvoiceStatuses.cancelled,
  RlnInvoiceStatuses.failed,
  RlnInvoiceStatuses.expired,
];

const List<RlnPaymentStatusValue> _paymentStatusValues = <String>[
  RlnPaymentStatuses.pending,
  RlnPaymentStatuses.claimable,
  RlnPaymentStatuses.claiming,
  RlnPaymentStatuses.succeeded,
  RlnPaymentStatuses.cancelled,
  RlnPaymentStatuses.failed,
];

const Map<String, String> _statusAliases = <String, String>{
  'paid': 'Succeeded',
  'settled': 'Succeeded',
  'success': 'Succeeded',
  'canceled': 'Cancelled',
};

/// Normalizes a native or core invoice-status value to canonical PascalCase.
RlnInvoiceStatusValue normalizeInvoiceStatus(Object? raw) {
  return _normalizeStatus(raw, _invoiceStatusValues, 'invoiceStatus');
}

/// Normalizes a native or core payment-status value to canonical PascalCase.
RlnPaymentStatusValue normalizePaymentStatus(Object? raw) {
  return _normalizeStatus(raw, _paymentStatusValues, 'paymentStatus');
}

/// Best-effort invoice-status normalization. Returns `null` for unknown input.
RlnInvoiceStatusValue? tryNormalizeInvoiceStatus(Object? raw) {
  try {
    return normalizeInvoiceStatus(raw);
  } on ValidationError {
    return null;
  }
}

/// Best-effort payment-status normalization. Returns `null` for unknown input.
RlnPaymentStatusValue? tryNormalizePaymentStatus(Object? raw) {
  try {
    return normalizePaymentStatus(raw);
  } on ValidationError {
    return null;
  }
}

/// Returns true when [status] is a terminal Lightning payment or invoice state.
bool isTerminalPaymentStatus(String status) {
  return status == RlnPaymentStatuses.succeeded ||
      status == RlnPaymentStatuses.cancelled ||
      status == RlnPaymentStatuses.failed ||
      status == RlnInvoiceStatuses.expired;
}

/// Returns true when [status] represents a claimable HODL state.
bool isClaimablePaymentStatus(String status) {
  return status == RlnPaymentStatuses.claimable ||
      status == RlnPaymentStatuses.claiming;
}

String _normalizeStatus(Object? raw, List<String> allowed, String label) {
  if (raw is! String || raw.trim().isEmpty) {
    throw ValidationError(
      '$label: expected a non-empty string, received $raw',
      label,
    );
  }
  final trimmed = raw.trim();
  final aliased =
      _statusAliases[trimmed.toLowerCase()] ?? _toPascalCase(trimmed);
  for (final value in allowed) {
    if (value == aliased) return value;
  }
  throw ValidationError(
    '$label: unknown value "$raw" (expected one of ${allowed.join(', ')})',
    label,
  );
}

String _toPascalCase(String raw) {
  return raw
      .trim()
      .toLowerCase()
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

/// RN-style wrapper returned by `listLightningPayments`.
class ListLightningPaymentsResponse {
  ListLightningPaymentsResponse({required List<LightningSendRequest> payments})
    : payments = List<LightningSendRequest>.unmodifiable(payments);

  /// Payment send records. The list is defensively copied.
  final List<LightningSendRequest> payments;
}

/// RN-style response returned by `createBackup`.
class WalletBackupResponse {
  const WalletBackupResponse({required this.message, required this.backupPath});

  /// Native backup status message.
  final String message;

  /// Native backup path when the operation succeeds.
  final String backupPath;
}

/// LSP configuration captured by the wallet node creation params.
class UtexoLspConfig {
  const UtexoLspConfig({this.baseUrl, this.bearerToken});

  /// Optional LSP base URL.
  final String? baseUrl;

  /// Optional LSP bearer token. Apps own durable storage of this secret.
  final String? bearerToken;
}

/// Optional RGB asset payload for Lightning invoice creation.
class LightningAsset {
  const LightningAsset({required this.assetId, required this.amount});

  /// RGB asset ID.
  final String assetId;

  /// Asset amount in smallest units.
  final int amount;
}

/// RN-style Lightning receive request.
class LightningReceiveRequest {
  const LightningReceiveRequest({required this.lnInvoice});

  /// BOLT11 Lightning invoice.
  final String lnInvoice;
}

/// RN-style Lightning send request/status response.
class LightningSendRequest {
  const LightningSendRequest({
    required this.txid,
    this.status,
    this.consignmentEndpoint,
  });

  /// Native payment transaction or payment hash identifier.
  final String txid;

  /// Canonical PascalCase payment status, when native reports one.
  final String? status;

  /// Optional RGB consignment endpoint associated with the payment.
  final String? consignmentEndpoint;
}

/// RN-style on-chain receive response.
class OnchainReceiveResponse {
  const OnchainReceiveResponse({
    required this.invoice,
    this.recipientId,
    this.expirationTimestamp,
    required this.batchTransferIdx,
  });

  /// RGB invoice string.
  final String invoice;

  /// Optional recipient identifier.
  final String? recipientId;

  /// Optional expiry timestamp in Unix seconds.
  final int? expirationTimestamp;

  /// Native batch transfer index.
  final int batchTransferIdx;
}

/// RN-style on-chain send response.
class OnchainSendResponse {
  const OnchainSendResponse({
    required this.txid,
    required this.batchTransferIdx,
  });

  /// Bitcoin transaction ID.
  final String txid;

  /// Native batch transfer index.
  final int batchTransferIdx;
}
