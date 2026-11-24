import '../binding/rln_binding.dart';
import '../client/rln_client.dart';
import '../errors/rgb_sdk_exception.dart';
import '../lsp/lsp_types.dart';
import '../lsp/lsp_wallet.dart';
import '../lsp/utexo_lsp.dart';
import '../models/burn_models.dart';
import '../models/imported_rgb_contract.dart';
import '../models/utexo_core_models.dart';
import 'burn_operations.dart';
import 'onchain_recovery.dart';
import 'rgb_lib/config.dart';
import 'rgb_lib/rgb_lib_wallet.dart';
import 'rgb_lib/utexo_wallet_adapter.dart';
import 'rgb_lib/wire.dart' show RgbLibAssetMetadata, RgbLibReceivedMint;
import 'rln_signers.dart';
import 'rln_wallet.dart';
import 'utexo_wallet_types.dart';
import 'wallet_engine.dart';

// Kept at this import path for applications that used the original facade library.
export 'onchain_recovery.dart'
    show
        RecoverableOnchainSendCommand,
        RecoverableOnchainSendKind,
        RecoverableOnchainSendPhase,
        RecoverableOnchainSendStatus;
export 'rln_wallet.dart' show resolveUnlockParams, resolveUnlockConfig;

/// A thin facade over one immutable, caller-selected wallet engine.
///
/// Passing [params] and [keys] creates the default RGB_L1 engine. To use RLN,
/// select [UtexoWallet.rln] or pass a [RlnWallet] as [engine]. The facade stores
/// no native handle, credentials, lifecycle state, queue, or recovery journal.
/// The engine owns those resources and all aliases share the same session.
class UtexoWallet implements WalletEngine, ILspWallet, BurnWalletOwner {
  factory UtexoWallet({
    WalletEngine? engine,
    RgbLibWalletParams? params,
    RgbLibKeys? keys,
    RgbLibUnlockParams? online,
  }) => UtexoWallet._(_selectEngine(engine, params, keys, online));

  /// Explicit RGB Lightning Node selection. No other constructor selects RLN
  /// implicitly, and an RGB_L1 error never falls back to this engine.
  factory UtexoWallet.rln({
    required RlnWalletConfig config,
    RlnOperationTimeoutPolicy? operationTimeouts,
    RlnSigner? signer,
  }) => UtexoWallet(
    engine: RlnWallet(
      config: config,
      operationTimeouts: operationTimeouts,
      signer: signer,
    ),
  );

  /// Wraps an existing RGB_L1 engine, preserving its native session and journal.
  factory UtexoWallet.rgbLib({required RgbLibWallet engine}) =>
      UtexoWallet(engine: engine);

  UtexoWallet._(this.engine)
    : _rgbApi = engine is RgbLibWallet ? RgbLibFacadeAdapter(engine) : null;

  /// The exact engine selected at construction. It is never replaced.
  final WalletEngine engine;
  final RgbLibFacadeAdapter? _rgbApi;

  @override
  String get protocol => engine.protocol;
  @override
  String get contractVersion => engine.contractVersion;
  @override
  BurnWallet get burnWalletOwner => engine;

  RlnWallet _requireRln(String operation) {
    final selected = engine;
    if (selected is RlnWallet) return selected;
    throw UnsupportedWalletFeatureException(
      '$operation requires an RGB_LN engine. Use the selected typed engine '
      'for engine-specific operations.',
      feature: operation,
    );
  }

  @override
  bool get isInitialized => engine.isInitialized;

  @override
  bool get isUnlocked => engine.isUnlocked;

  WalletCapabilities get capabilities =>
      _rgbApi?.capabilities ?? _requireRln('capabilities').capabilities;

  PsbtWalletCarrier? get psbt => rlnEngine?.psbt;

  BeginEndWalletCarrier? get beginEnd => rlnEngine?.beginEnd;

  @override
  String get network => engine.network;

  int get nodeId => _requireRln('nodeId').nodeId;

  @override
  bool get isShutdown => engine.isShutdown;

  @override
  bool isDisposed() => engine.isDisposed();

  @override
  String getNetwork() => engine.getNetwork();

  @override
  Future<void> init({String? password, String? mnemonic}) async =>
      password == null && mnemonic == null
      ? engine.init()
      : _rgbApi != null
      ? _rgbApi.init(password: password, mnemonic: mnemonic)
      : _requireRln('init').init(password: password, mnemonic: mnemonic);

  Future<void> initialize({String? password, String? mnemonic}) =>
      init(password: password, mnemonic: mnemonic);

  Future<void> unlock({
    String? password,
    required UtexoUnlockConfig config,
  }) async => _rgbApi != null
      ? _rgbApi.unlock(password: password, config: config)
      : _requireRln('unlock').unlock(password: password, config: config);

  @override
  Future<void> reinit({
    String? password,
    String? mnemonic,
    UtexoUnlockConfig? unlockConfig,
  }) async => password == null && mnemonic == null && unlockConfig == null
      ? engine.reinit()
      : _rgbApi != null
      ? _rgbApi.reinit(
          password: password,
          mnemonic: mnemonic,
          unlockConfig: unlockConfig,
        )
      : _requireRln('reinit').reinit(
          password: password,
          mnemonic: mnemonic,
          unlockConfig: unlockConfig,
        );

  @override
  Future<void> shutdown() => engine.shutdown();

  @override
  Future<void> destroy() => engine.destroy();

  Future<void> dispose() => destroy();

  Future<ApayNewResponse> apayNew(String hostNodeId) async =>
      _requireRln('apayNew').apayNew(hostNodeId);

  @override
  Future<ApayNewResponse> apayNewWithAddress(
    String hostNodeId,
    String username,
    String domain,
  ) async => _requireRln(
    'apayNewWithAddress',
  ).apayNewWithAddress(hostNodeId, username, domain);

  Future<UtexoLsp> createLsp([LspPeer? peer, int peerPort = 9735]) async =>
      _requireRln('createLsp').createLsp(peer, peerPort);

  UtexoLspConfig getLspConfig() => _requireRln('getLspConfig').getLspConfig();

  Future<RecoverableOnchainSendCommand> createRecoverableBtcSendCommand({
    required String operationId,
    required int amount,
    required String address,
    double feeRate = 1,
  }) async => _rgbApi != null
      ? _rgbApi.createRecoverableBtcSendCommand(
          operationId: operationId,
          amount: amount,
          address: address,
          feeRate: feeRate,
        )
      : _requireRln(
          'createRecoverableBtcSendCommand',
        ).createRecoverableBtcSendCommand(
          operationId: operationId,
          amount: amount,
          address: address,
          feeRate: feeRate,
        );

  Future<RecoverableOnchainSendCommand> createRecoverableRgbSendCommand({
    required String operationId,
    required RgbSendRequest request,
  }) async => _rgbApi != null
      ? _rgbApi.createRecoverableRgbSendCommand(
          operationId: operationId,
          request: request,
        )
      : _requireRln(
          'createRecoverableRgbSendCommand',
        ).createRecoverableRgbSendCommand(
          operationId: operationId,
          request: request,
        );

  Future<RecoverableOnchainSendStatus> prepareOnchainSend(
    RecoverableOnchainSendCommand command,
  ) async => _rgbApi != null
      ? _rgbApi.prepareOnchainSend(command)
      : _requireRln('prepareOnchainSend').prepareOnchainSend(command);

  Future<RecoverableOnchainSendStatus> commitOnchainSend(
    RecoverableOnchainSendCommand command,
  ) async => _rgbApi != null
      ? _rgbApi.commitOnchainSend(command)
      : _requireRln('commitOnchainSend').commitOnchainSend(command);

  Future<RecoverableOnchainSendStatus> onchainSendStatus(
    RecoverableOnchainSendCommand command,
  ) async => _rgbApi != null
      ? _rgbApi.onchainSendStatus(command)
      : _requireRln('onchainSendStatus').onchainSendStatus(command);

  Future<RecoverableOnchainSendStatus> cancelOnchainSend(
    RecoverableOnchainSendCommand command,
  ) async => _rgbApi != null
      ? _rgbApi.cancelOnchainSend(command)
      : _requireRln('cancelOnchainSend').cancelOnchainSend(command);

  @override
  Future<WalletNodeInfo> getNodeInfo() async =>
      _requireRln('getNodeInfo').getNodeInfo();

  Future<WalletNetworkInfo> getNetworkInfo() async =>
      _requireRln('getNetworkInfo').getNetworkInfo();

  @override
  Future<CoreBtcBalance> getBtcBalance({bool skipSync = false}) =>
      engine.getBtcBalance(skipSync: skipSync);

  @override
  Future<String> getAddress() => engine.getAddress();

  @override
  Future<List<CoreUnspent>> listUnspents({bool skipSync = false}) =>
      engine.listUnspents(skipSync: skipSync);

  Future<int> createUtxos({
    bool upTo = true,
    int? num,
    int? size,
    double feeRate = 1,
    bool skipSync = false,
  }) async => _rgbApi != null
      ? _rgbApi.createUtxos(
          upTo: upTo,
          num: num,
          size: size,
          feeRate: feeRate,
          skipSync: skipSync,
        )
      : _requireRln('createUtxos').createUtxos(
          upTo: upTo,
          num: num,
          size: size,
          feeRate: feeRate,
          skipSync: skipSync,
        );

  Future<CoreListAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async => _rgbApi != null
      ? _rgbApi.listAssets(filterAssetSchemas: filterAssetSchemas)
      : _requireRln(
          'listAssets',
        ).listAssets(filterAssetSchemas: filterAssetSchemas);

  @override
  Future<CoreAssetBalance> getAssetBalance(String assetId) =>
      engine.getAssetBalance(assetId);

  @override
  Future<String> rotateVanillaAddress() => engine.rotateVanillaAddress();

  Future<CoreAssetNia> issueAssetNia({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
  }) async => _rgbApi != null
      ? _rgbApi.issueAssetNia(
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
        )
      : _requireRln('issueAssetNia').issueAssetNia(
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
        );

  Future<CoreAssetIfa> issueAssetIfa({
    required String ticker,
    required String name,
    required int precision,
    required List<int> amounts,
    required List<int> inflationAmounts,
    String? rejectListUrl,
  }) async => _rgbApi != null
      ? _rgbApi.issueAssetIfa(
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
          inflationAmounts: inflationAmounts,
          rejectListUrl: rejectListUrl,
        )
      : _requireRln('issueAssetIfa').issueAssetIfa(
          ticker: ticker,
          name: name,
          precision: precision,
          amounts: amounts,
          inflationAmounts: inflationAmounts,
          rejectListUrl: rejectListUrl,
        );

  Future<CoreInvoiceReceiveData> blindReceive(
    RgbInvoiceRequest request,
  ) async => _rgbApi != null
      ? _rgbApi.blindReceive(request)
      : _requireRln('blindReceive').blindReceive(request);

  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async => _rgbApi != null
      ? _rgbApi.witnessReceive(request)
      : _requireRln('witnessReceive').witnessReceive(request);

  @override
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) =>
      engine.decodeRgbInvoice(invoice);

  Future<InflateAssetIfaResponse> inflate(
    InflateAssetIfaRequest request,
  ) async => _rgbApi != null
      ? _rgbApi.inflate(request)
      : _requireRln('inflate').inflate(request);

  Future<String> sendBtc({
    required int amount,
    required String address,
    double feeRate = 1,
    bool skipSync = false,
  }) async => _rgbApi != null
      ? _rgbApi.sendBtc(
          amount: amount,
          address: address,
          feeRate: feeRate,
          skipSync: skipSync,
        )
      : _requireRln('sendBtc').sendBtc(
          amount: amount,
          address: address,
          feeRate: feeRate,
          skipSync: skipSync,
        );

  @override
  Future<List<CoreTransaction>> listTransactions({bool skipSync = false}) =>
      engine.listTransactions(skipSync: skipSync);

  @override
  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) => engine.listTransactionsByTxid(txid, skipSync: skipSync);

  @override
  Future<List<CoreTransfer>> listTransfers({String? assetId}) =>
      engine.listTransfers(assetId: assetId);

  @override
  Future<List<CoreTransfer>> listTransfersByTxid(String txid) =>
      engine.listTransfersByTxid(txid);

  @override
  Future<bool> failTransfers({
    int? batchTransferIdx,
    bool noAssetOnly = false,
    bool skipSync = false,
  }) => engine.failTransfers(
    batchTransferIdx: batchTransferIdx,
    noAssetOnly: noAssetOnly,
    skipSync: skipSync,
  );

  @override
  Future<RefreshTransfersResult> refreshTransfers({bool skipSync = false}) =>
      engine.refreshTransfers(skipSync: skipSync);

  @override
  Future<void> refreshWallet() => engine.refreshWallet();

  @override
  Future<void> syncWallet() => engine.syncWallet();

  Future<FeeEstimationResponse> estimateFeeRate(int blocks) async =>
      _rgbApi != null
      ? _rgbApi.estimateFeeRate(blocks)
      : _requireRln('estimateFeeRate').estimateFeeRate(blocks);

  Future<IndexerCheckResponse> checkIndexerUrl(String url) async =>
      _rgbApi != null
      ? _rgbApi.checkIndexerUrl(url)
      : _requireRln('checkIndexerUrl').checkIndexerUrl(url);

  Future<void> checkProxyEndpoint(String endpoint) async =>
      _requireRln('checkProxyEndpoint').checkProxyEndpoint(endpoint);

  Future<WalletBackupResponse> createBackup({
    required String backupPath,
    required String password,
  }) async => _rgbApi != null
      ? _rgbApi.createBackup(backupPath: backupPath, password: password)
      : _requireRln(
          'createBackup',
        ).createBackup(backupPath: backupPath, password: password);

  Future<OnchainReceiveResponse> onchainReceive(
    RgbInvoiceRequest request,
  ) async => _rgbApi != null
      ? _rgbApi.onchainReceive(request)
      : _requireRln('onchainReceive').onchainReceive(request);

  Future<OnchainSendResponse> onchainSend(RgbSendRequest request) async =>
      _rgbApi != null
      ? _rgbApi.onchainSend(request)
      : _requireRln('onchainSend').onchainSend(request);

  Future<List<CoreTransfer>> listOnchainTransfers({String? assetId}) =>
      listTransfers(assetId: assetId);

  @override
  Future<RgbLibAssetMetadata> getAssetMetadata(String assetId) =>
      engine.getAssetMetadata(assetId);

  Future<CoreAssetCfa> issueAssetCfa({
    required String name,
    required int precision,
    required List<int> amounts,
    String? details,
    String? filePath,
  }) async => _rgbApi != null
      ? _rgbApi.issueAssetCfa(
          name: name,
          precision: precision,
          amounts: amounts,
          details: details,
          filePath: filePath,
        )
      : _requireRln('issueAssetCfa').issueAssetCfa(
          name: name,
          precision: precision,
          amounts: amounts,
          details: details,
          filePath: filePath,
        );

  Future<CoreAssetUda> issueAssetUda({
    required String ticker,
    required String name,
    required int precision,
    String? details,
    String? mediaFilePath,
    List<String> attachmentsFilePaths = const [],
  }) async => _rgbApi != null
      ? _rgbApi.issueAssetUda(
          ticker: ticker,
          name: name,
          precision: precision,
          details: details,
          mediaFilePath: mediaFilePath,
          attachmentsFilePaths: attachmentsFilePaths,
        )
      : _requireRln('issueAssetUda').issueAssetUda(
          ticker: ticker,
          name: name,
          precision: precision,
          details: details,
          mediaFilePath: mediaFilePath,
          attachmentsFilePaths: attachmentsFilePaths,
        );

  Future<ImportedRgbContract> importRgbContract({
    required String contractBase64,
    required String expectedAssetId,
  }) async => _rgbApi != null
      ? _rgbApi.importRgbContract(
          contractBase64: contractBase64,
          expectedAssetId: expectedAssetId,
        )
      : _requireRln('importRgbContract').importRgbContract(
          contractBase64: contractBase64,
          expectedAssetId: expectedAssetId,
        );

  @override
  Future<BfaCapabilities> getBfaCapabilities() => engine.getBfaCapabilities();

  @override
  Future<BurnResult> burn(BurnParams params) => engine.burn(params);

  @override
  Future<String> getConsignment(String assetId, String txid) =>
      engine.getConsignment(assetId, txid);

  @override
  Future<String> getConsignmentPath(String assetId, String txid) =>
      engine.getConsignmentPath(assetId, txid);

  @override
  Future<LightningReceiveRequest> createLightningInvoice({
    int? amountSats,
    LightningAsset? asset,
    int expirySeconds = 3600,
    int? minFinalCltvExpiryDelta,
    String? descriptionHash,
    String? description,
  }) async => _requireRln('createLightningInvoice').createLightningInvoice(
    amountSats: amountSats,
    asset: asset,
    expirySeconds: expirySeconds,
    minFinalCltvExpiryDelta: minFinalCltvExpiryDelta,
    descriptionHash: descriptionHash,
    description: description,
  );

  Future<HodlInvoice> createHodlInvoice(CreateHodlInvoiceParams params) async =>
      _requireRln('createHodlInvoice').createHodlInvoice(params);

  @override
  Future<HodlInvoiceResult> claimHodlInvoice(
    String paymentHash,
    String preimage,
  ) async =>
      _requireRln('claimHodlInvoice').claimHodlInvoice(paymentHash, preimage);

  Future<HodlInvoiceResult> cancelHodlInvoice(String paymentHash) async =>
      _requireRln('cancelHodlInvoice').cancelHodlInvoice(paymentHash);

  @override
  Future<DecodedLightningInvoice> decodeLnInvoice(String invoice) async =>
      _requireRln('decodeLnInvoice').decodeLnInvoice(invoice);

  @override
  Future<LightningSendRequest> payLightningInvoice({
    required String lnInvoice,
    int? amount,
    String? assetId,
    int? assetAmount,
  }) async => _requireRln('payLightningInvoice').payLightningInvoice(
    lnInvoice: lnInvoice,
    amount: amount,
    assetId: assetId,
    assetAmount: assetAmount,
  );

  @override
  Future<RlnInvoiceStatusValue> getLightningReceiveStatus(String id) async =>
      _requireRln('getLightningReceiveStatus').getLightningReceiveStatus(id);

  Future<RlnPaymentStatusValue?> getLightningSendStatus(String id) async =>
      _requireRln('getLightningSendStatus').getLightningSendStatus(id);

  Future<RlnInvoiceStatusValue> invoiceStatus(String invoice) async =>
      _requireRln('invoiceStatus').invoiceStatus(invoice);

  @override
  Future<List<LightningPayment>> listPayments() async =>
      _requireRln('listPayments').listPayments();

  Future<ListLightningPaymentsResponse> listLightningPayments() async =>
      _requireRln('listLightningPayments').listLightningPayments();

  @override
  Future<void> connectPeer(String peerPubkeyAndAddr) async =>
      _requireRln('connectPeer').connectPeer(peerPubkeyAndAddr);

  Future<void> disconnectPeer(String peerPubkey) async =>
      _requireRln('disconnectPeer').disconnectPeer(peerPubkey);

  Future<List<LightningPeer>> listPeers() async =>
      _requireRln('listPeers').listPeers();

  @override
  Future<List<LightningChannel>> listChannels() async =>
      _requireRln('listChannels').listChannels();

  Future<LightningChannelOpenResult> openChannel({
    required String peerPubkey,
    required int capacitySat,
    int pushMsat = 0,
    bool isPublic = false,
    bool withAnchors = true,
    int? feeBaseMsat,
    int? feeProportionalMillionths,
    String? temporaryChannelId,
    String? assetId,
    int? assetLocalAmount,
    int? pushAssetAmount,
    String? virtualOpenMode,
  }) async => _requireRln('openChannel').openChannel(
    peerPubkey: peerPubkey,
    capacitySat: capacitySat,
    pushMsat: pushMsat,
    isPublic: isPublic,
    withAnchors: withAnchors,
    feeBaseMsat: feeBaseMsat,
    feeProportionalMillionths: feeProportionalMillionths,
    temporaryChannelId: temporaryChannelId,
    assetId: assetId,
    assetLocalAmount: assetLocalAmount,
    pushAssetAmount: pushAssetAmount,
    virtualOpenMode: virtualOpenMode,
  );

  Future<void> closeChannel({
    required String channelId,
    required String peerPubkey,
    bool force = false,
  }) async => _requireRln(
    'closeChannel',
  ).closeChannel(channelId: channelId, peerPubkey: peerPubkey, force: force);

  Future<String> getChannelId(String temporaryChannelId) async =>
      _requireRln('getChannelId').getChannelId(temporaryChannelId);

  Future<SendPaymentResult> keysend({
    required String destPubkey,
    required int amtMsat,
    String? assetId,
    int? assetAmount,
  }) async => _requireRln('keysend').keysend(
    destPubkey: destPubkey,
    amtMsat: amtMsat,
    assetId: assetId,
    assetAmount: assetAmount,
  );

  Future<String> signNodeMessage(String message) async =>
      _requireRln('signNodeMessage').signNodeMessage(message);

  Future<bool> verifyNodeMessage(String message, String signature) async =>
      _requireRln('verifyNodeMessage').verifyNodeMessage(message, signature);

  Future<String> signMessage(String message) async =>
      _requireRln('signMessage').signMessage(message);

  Future<bool> verifyMessage(String message, String signature) async =>
      _requireRln('verifyMessage').verifyMessage(message, signature);

  Future<void> vssClearFence(String password) async =>
      _requireRln('vssClearFence').vssClearFence(password);

  Future<int> backupNow() async => _requireRln('backupNow').backupNow();
}

WalletEngine _selectEngine(
  WalletEngine? engine,
  RgbLibWalletParams? params,
  RgbLibKeys? keys,
  RgbLibUnlockParams? online,
) {
  if (engine != null) {
    if (engine is UtexoWallet) {
      throw const WalletValidationException(
        'Pass the standalone wallet engine, not another facade.',
        field: 'engine',
      );
    }
    if (params != null || keys != null || online != null) {
      throw const WalletValidationException(
        'Pass either an engine or RGB_L1 configuration, never both.',
        field: 'engine',
      );
    }
    if (engine.contractVersion != '1' ||
        (engine.protocol != 'RGB_L1' && engine.protocol != 'RGB_LN')) {
      throw const WalletValidationException(
        'Unsupported wallet engine contract or protocol.',
        field: 'engine',
      );
    }
    return engine;
  }
  if (params == null || keys == null) {
    throw const WalletValidationException(
      'The default RGB_L1 engine requires wallet parameters and keys.',
      field: 'params/keys',
    );
  }
  return RgbLibWallet(params: params, keys: keys, online: online);
}

/// Typed capabilities of the facade's selected engine.
extension UtexoWalletEngineAccess on UtexoWallet {
  RgbLibWallet? get rgbLibEngine => switch (engine) {
    final RgbLibWallet selected => selected,
    _ => null,
  };
  RlnWallet? get rlnEngine => switch (engine) {
    final RlnWallet selected => selected,
    _ => null,
  };

  /// Read-only native mint lookup. Null is not evidence of settlement.
  Future<RgbLibReceivedMint?> getReceivedMint(String recipientId) async {
    final selected = rgbLibEngine;
    if (selected == null) {
      throw const UnsupportedWalletFeatureException(
        'getReceivedMint requires an RGB_L1 wallet.',
        feature: 'getReceivedMint',
      );
    }
    return selected.getReceivedMint(recipientId);
  }
}

/// Advanced compatibility factory for an explicitly configured RLN facade.
/// Native bridge injection belongs to [createAdvancedRlnWallet].
UtexoWallet createAdvancedUtexoWallet({
  required RlnWalletConfig config,
  RlnClient? client,
  RLNBinding? binding,
  RlnOperationTimeoutPolicy? operationTimeouts,
  RlnSigner? signer,
}) => UtexoWallet(
  engine: createAdvancedRlnWallet(
    config: config,
    client: client,
    binding: binding,
    operationTimeouts: operationTimeouts,
    signer: signer,
  ),
);
