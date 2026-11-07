import '../../models/utexo_core_models.dart';
import '../../wallet/rgb_lib/rgb_lib_wallet.dart';
import '../../wallet/utexo_wallet.dart';
import '../../wallet/utexo_wallet_types.dart';
import 'burn.dart';
import 'errors.dart';
import 'session.dart';
import 'types.dart';
import 'wallet.dart';

/// Receiving/read subset actually implemented by RN, not the entire WebRGB spec.
const webRgbReadMethods = <String>[
  'enable',
  'getInfo',
  'getAddress',
  'blindReceive',
  'witnessReceive',
  'listAssets',
  'getAssetBalance',
  'listTransfers',
  'getTransferStatus',
  'decodeRgbInvoice',
];

/// Transport-independent provider for one authorized dApp session.
///
/// No webview/WalletConnect transport is installed. Hosts validate transport
/// identities and decode untrusted requests into these typed arguments. Call
/// [revoke] on disconnect, expiry or wallet switch; never reuse an old provider
/// for a different origin. Every async boundary rechecks session authorization.
class WebRgbProvider {
  WebRgbProvider(UtexoWallet wallet, WebRgbOptions options)
    : this._(WebRgbWallet.rln(wallet), options);

  /// Opens a WebRGB session for an on-chain wallet without message signing.
  WebRgbProvider.rgbLib(RgbLibWallet wallet, WebRgbOptions options)
    : this._(WebRgbWallet.rgbLib(wallet), options);

  WebRgbProvider._(WebRgbWallet wallet, WebRgbOptions options)
    : _wallet = wallet,
      _session = WebRgbSession(wallet, options),
      _floor = webRgbInteger(
        options.minConfirmations,
        'minConfirmations',
        min: 0,
        max: 255,
      ) {
    if (_floor < 3) _floor = 3;
    if (options.burn case final burn?) {
      _burn = WebRgbBurnController(wallet, _session, burn);
    }
  }

  final WebRgbWallet _wallet;
  final WebRgbSession _session;
  int _floor;
  WebRgbBurnController? _burn;
  bool get enabled => _session.enabled;
  Future<void> enable() => _session.enable();

  /// Clears proof cache and export permissions as well as connection consent.
  void revoke() {
    _session.revoke();
    _burn?.revoke();
  }

  Future<WebRgbInfo> getInfo() async {
    final revision = _session.revision;
    return _session.call(revision, () async {
      final burnMethods = await _burn?.methods(revision) ?? const <String>[];
      return WebRgbInfo(
        network: _wallet.getNetwork(),
        protocol: _wallet.protocol,
        methods: [
          ...webRgbReadMethods,
          if (_wallet.signMessage != null) 'signMessage',
          ...burnMethods,
        ],
        burnRecipientNamespaces: burnMethods.contains('burnAsset')
            ? _burn!.recipientNamespaces
            : null,
        burnDestinationRoutes: burnMethods.contains('burnAsset')
            ? _burn!.destinationRoutes
            : const [],
      );
    });
  }

  Future<WebRgbAddressResult> getAddress() async {
    final revision = _session.revision;
    final address = await _session.call(revision, _wallet.getAddress);
    return WebRgbAddressResult(address: address);
  }

  Future<WebRgbBlindReceiveResult> blindReceive([
    WebRgbBlindReceiveArgs args = const WebRgbBlindReceiveArgs(),
  ]) => _receive('blindReceive', args, _wallet.blindReceive);

  /// Requests explicit approval before allocating a witness receiving output.
  Future<WebRgbWitnessReceiveResult> witnessReceive([
    WebRgbWitnessReceiveArgs args = const WebRgbWitnessReceiveArgs(),
  ]) => _receive('witnessReceive', args, _wallet.witnessReceive);

  /// Signs only the exact approved message using the native wallet identity.
  ///
  /// The host must display origin and full message. Unpaired UTF-16 surrogates
  /// are rejected rather than silently replaced during native UTF-8 encoding.
  Future<WebRgbSignMessageResult> signMessage(String message) async {
    _session.check();
    final sign = _wallet.signMessage;
    if (sign == null) {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Signing is unavailable.',
      );
    }
    for (var index = 0; index < message.length; index++) {
      final unit = message.codeUnitAt(index);
      if (unit < 0xd800 || unit > 0xdfff) continue;
      if (unit <= 0xdbff && index + 1 < message.length) {
        final low = message.codeUnitAt(index + 1);
        if (low >= 0xdc00 && low <= 0xdfff) {
          index++;
          continue;
        }
      }
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Expected a well-formed Unicode message string.',
      );
    }
    final revision = _session.revision;
    await _session.confirm(revision, 'signMessage', {'message': message});
    final signature = await _session.call(revision, () => sign(message));
    return WebRgbSignMessageResult(signature: signature);
  }

  Future<WebRgbBlindReceiveResult> _receive(
    String method,
    WebRgbBlindReceiveArgs args,
    Future<CoreInvoiceReceiveData> Function(RgbInvoiceRequest) receive,
  ) async {
    _session.check();
    final revision = _session.revision;
    webRgbAsset(args.assetId);
    if (args.amount != null) webRgbInteger(args.amount!, 'amount');
    webRgbInteger(args.durationSeconds, 'durationSeconds', max: 2592000);
    final requested = webRgbInteger(
      args.minConfirmations ?? _floor,
      'minConfirmations',
      min: 0,
      max: 255,
    );
    final confirmations = requested < _floor ? _floor : requested;
    final request = RgbInvoiceRequest(
      assetId: args.assetId,
      amount: args.amount,
      durationSeconds: args.durationSeconds,
      minConfirmations: confirmations,
    );
    if (args.assetId case final assetId?) {
      await _requireKnownAsset(revision, assetId);
    }
    await _session.confirm(revision, method, {
      if (args.assetId != null) 'assetId': args.assetId,
      if (args.amount != null) 'amount': args.amount,
      'durationSeconds': args.durationSeconds,
      'minConfirmations': confirmations,
    });
    final result = await _session.call(revision, () => receive(request));
    return WebRgbBlindReceiveResult(
      invoice: result.invoice,
      recipientId: result.recipientId,
      expirationTimestamp: result.expirationTimestamp,
      minConfirmations: confirmations,
    );
  }

  Future<List<WebRgbAsset>> listAssets() async {
    final revision = _session.revision;
    final assets = await _session.call(revision, _wallet.listAssets);
    final groups = <String, Iterable<CoreAsset>>{
      'bfa': assets.bfa,
      'nia': assets.nia,
      'cfa': assets.cfa,
      'ifa': assets.ifa,
      'uda': assets.uda,
    };
    return List.unmodifiable([
      for (final group in groups.entries)
        for (final asset in group.value)
          WebRgbAsset(
            id: asset.assetId,
            schema: group.key,
            ticker: asset.ticker,
            name: asset.name,
            precision: asset.precision,
          ),
    ]);
  }

  Future<WebRgbAssetBalance> getAssetBalance(String assetId) async {
    _session.check();
    final revision = _session.revision;
    webRgbAsset(assetId);
    await _requireKnownAsset(revision, assetId);
    final value = await _session.call(
      revision,
      () => _wallet.getAssetBalance(assetId),
    );
    return WebRgbAssetBalance(
      assetId: assetId,
      balance: webRgbAmount(value.spendable),
      raw: {
        'settled': webRgbAmount(value.settled),
        'future': webRgbAmount(value.future),
        'spendable': webRgbAmount(value.spendable),
        'offchainOutbound': webRgbAmount(value.offchainOutbound),
        'offchainInbound': webRgbAmount(value.offchainInbound),
      },
    );
  }

  Future<void> _requireKnownAsset(int revision, String assetId) async {
    // Native NotFound also covers missing node/proof state. Do not guess its
    // subject from a redacted error message or mislabel it as an unknown asset.
    final assets = await _session.call(revision, _wallet.listAssets);
    if (!assets.assetIds.contains(assetId)) {
      throw const WebRgbError('ASSET_NOT_FOUND', 'Asset was not found.');
    }
  }

  Future<List<WebRgbTransfer>> listTransfers([String? assetId]) async {
    _session.check();
    webRgbAsset(assetId);
    final transfers = await _session.call(
      _session.revision,
      () => _wallet.burnWallet.listTransfers(assetId: assetId),
    );
    return List.unmodifiable(
      transfers.map((transfer) {
        final amount = transfer.amount;
        return WebRgbTransfer(
          assetId: assetId,
          transferId: transfer.idx,
          status: transfer.status,
          kind: transfer.kind,
          amount: amount == null || amount > BigInt.from(9007199254740991)
              ? null
              : webRgbAmount(amount),
          amountBaseUnits: transfer.amountBaseUnits,
          recipientId: transfer.recipientId,
          txid: transfer.txid,
        );
      }),
    );
  }

  Future<WebRgbTransferStatusResult> getTransferStatus(
    Object transferId, [
    String? assetId,
  ]) async {
    _session.check();
    final revision = _session.revision;
    if ((transferId is! String && transferId is! int) ||
        transferId.toString().isEmpty) {
      throw const WebRgbError('INVALID_PARAMS', 'A transfer ID is required.');
    }
    webRgbAsset(assetId);
    if (_burn case final burn?) {
      final status = await _session.call(
        revision,
        () => burn.getTransferStatus(revision, transferId.toString(), assetId),
      );
      if (status != null) return status;
    }
    await _session.call(revision, _wallet.refreshWallet);
    final transfers = await _session.call(
      revision,
      () => listTransfers(assetId),
    );
    for (final transfer in transfers) {
      if (transfer.transferId?.toString() == transferId.toString() ||
          transfer.txid == transferId ||
          transfer.recipientId == transferId) {
        return WebRgbTransferStatusResult(
          found: true,
          status: transfer.status,
          transfer: transfer,
        );
      }
    }
    return const WebRgbTransferStatusResult(found: false);
  }

  Future<WebRgbDecodedInvoice> decodeRgbInvoice(String invoice) async {
    _session.check();
    if (!invoice.startsWith('rgb:') || invoice.length > 16384) {
      throw const WebRgbError('INVALID_PARAMS', 'Invalid RGB invoice.');
    }
    final decoded = await _session.call(
      _session.revision,
      () => _wallet.decodeRgbInvoice(invoice),
    );
    final amount = decoded.assignment.type == 'Fungible'
        ? decoded.assignment.amount
        : null;
    return WebRgbDecodedInvoice(
      assetId: decoded.assetId,
      amount: amount == null || amount == BigInt.zero
          ? null
          : webRgbAmount(amount),
      recipientId: decoded.recipientId,
      expirationTimestamp: decoded.expirationTimestamp,
      network: decoded.network,
      transportEndpoints: decoded.transportEndpoints,
    );
  }

  Future<WebRgbBurnAssetResult> burnAsset(WebRgbBurnAssetArgs args) async {
    _session.check();
    final revision = _session.revision;
    final burn = _requireBurn();
    return _session.call(revision, () => burn.burnAsset(revision, args));
  }

  Future<WebRgbGetConsignmentResult> getConsignment(
    WebRgbGetConsignmentArgs args,
  ) async {
    _session.check();
    final revision = _session.revision;
    final burn = _requireBurn();
    return _session.call(revision, () => burn.getConsignment(revision, args));
  }

  WebRgbBurnController _requireBurn() {
    final burn = _burn;
    if (burn == null) {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Burn extension is not configured.',
      );
    }
    return burn;
  }
}
