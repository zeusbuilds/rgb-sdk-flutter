import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:pointycastle/digests/keccak.dart';

import '../../wallet/burn_destination.dart';
import '../../wallet/burn_operations.dart';
import '../../wallet/rgb_lib/rgb_lib_wallet.dart';
import '../../wallet/utexo_wallet.dart';
import 'errors.dart';
import 'provider.dart';
import 'types.dart';

/// Experimental UTEXO transport profile, not a WalletConnect standard.
const webRgbWalletConnectProfile = 'webrgb:1';

/// Maximum decoded bytes in one proof reply, matching transport version 0.1.2.
const webRgbConsignmentChunkBytes = 48 * 1024;

/// Host-verified, currently active WalletKit session projection.
///
/// Construct only from WalletKit's active sessions and verification context,
/// never from RPC parameters. [origin] must be the approved normalized origin.
/// Pairing, proposal negotiation, verification warnings and durable session
/// storage remain the host's responsibility. Unknown origins need explicit
/// user approval; invalid/scam verification must never produce this grant.
class WebRgbWalletConnectGrant {
  WebRgbWalletConnectGrant({
    required this.topic,
    required this.origin,
    required this.network,
    required this.account,
    required this.expiry,
    required Iterable<String> methods,
    this.profile = webRgbWalletConnectProfile,
  }) : methods = Set.unmodifiable(methods);

  final String topic;
  final String origin;
  final String network;

  /// Fully qualified approved account: `rgb:<network>:<public-wallet-id>`.
  final String account;

  /// Session expiry in Unix seconds, not milliseconds.
  final int expiry;

  /// Approved wire methods, including the rgb_ prefix.
  final Set<String> methods;
  final String profile;
}

class _Request {
  _Request(this.fingerprint, this.expiry, this.result);
  final String fingerprint;
  final int expiry;
  final Future<Map<String, Object?>> result;
  bool complete = false;
}

/// Bounded wallet-side router for one WalletConnect WebRGB session.
///
/// The host owns WalletKit initialization, pairing/proposal approval and wire
/// response delivery. Supply [currentGrant] from active session state so every
/// await rechecks revocation, expiry, wallet identity and method permissions.
/// Call [dispose] on disconnect, expiry or wallet switch. This adapter neither
/// installs listeners nor uses a global wallet. It never retries a mutation.
/// Duplicate IDs reuse their result only within this live router; irreversible
/// burns additionally require the provider's durable wallet-scoped journal.
class WebRgbWalletConnectSession {
  WebRgbWalletConnectSession({
    required UtexoWallet wallet,
    required WebRgbWalletConnectGrant grant,
    required WebRgbWalletConnectGrant? Function() currentGrant,
    required Future<bool> Function(WebRgbApproval) confirm,
    WebRgbBurnOptions? burn,
    DateTime Function()? clock,
  }) : this._(
         network: wallet.getNetwork(),
         provider: (options) => WebRgbProvider(wallet, options),
         grant: grant,
         currentGrant: currentGrant,
         confirm: confirm,
         burn: burn,
         clock: clock,
       );

  /// Routes the same authorized WebRGB methods to a native on-chain wallet.
  WebRgbWalletConnectSession.rgbLib({
    required RgbLibWallet wallet,
    required WebRgbWalletConnectGrant grant,
    required WebRgbWalletConnectGrant? Function() currentGrant,
    required Future<bool> Function(WebRgbApproval) confirm,
    WebRgbBurnOptions? burn,
    DateTime Function()? clock,
  }) : this._(
         network: wallet.getNetwork(),
         provider: (options) => WebRgbProvider.rgbLib(wallet, options),
         grant: grant,
         currentGrant: currentGrant,
         confirm: confirm,
         burn: burn,
         clock: clock,
       );

  WebRgbWalletConnectSession._({
    required String network,
    required WebRgbProvider Function(WebRgbOptions) provider,
    required WebRgbWalletConnectGrant grant,
    required WebRgbWalletConnectGrant? Function() currentGrant,
    required Future<bool> Function(WebRgbApproval) confirm,
    WebRgbBurnOptions? burn,
    DateTime Function()? clock,
  }) : _grant = grant,
       _currentGrant = currentGrant,
       _clock = clock ?? DateTime.now {
    if (!RegExp(r'^[-_a-zA-Z0-9]{1,32}$').hasMatch(grant.network) ||
        !RegExp(
          '^rgb:${RegExp.escape(grant.network)}:[-.%a-zA-Z0-9]{1,128}\$',
        ).hasMatch(grant.account) ||
        grant.topic.isEmpty ||
        network != grant.network) {
      throw const WebRgbError(
        'INVALID_PARAMS',
        'Invalid wallet session identity.',
      );
    }
    _check();
    _provider = provider(
      WebRgbOptions(
        origin: grant.origin,
        sessionApproved: true,
        confirm: confirm,
        burn: burn,
        assertAuthorized: _check,
      ),
    );
  }

  final WebRgbWalletConnectGrant _grant;
  final WebRgbWalletConnectGrant? Function() _currentGrant;
  final DateTime Function() _clock;
  late final WebRgbProvider _provider;
  final Map<int, _Request> _requests = {};
  Future<void> _queue = Future.value();
  bool _disposed = false;
  bool _enabled = false;
  String? _activeMethod;
  int? _activeExpiry;
  WebRgbGetConsignmentResult? _proof;
  Uint8List? _proofBytes;

  int get _now => _clock().toUtc().millisecondsSinceEpoch ~/ 1000;

  void _check({bool request = true}) {
    final current = _currentGrant();
    if (_disposed ||
        current == null ||
        current.topic != _grant.topic ||
        current.origin != _grant.origin ||
        current.network != _grant.network ||
        current.account != _grant.account ||
        current.profile != webRgbWalletConnectProfile ||
        current.expiry <= _now ||
        (request && _activeExpiry != null && _activeExpiry! <= _now) ||
        !current.methods.containsAll({'rgb_enable', 'rgb_getInfo'}) ||
        (request &&
            _activeMethod != null &&
            !current.methods.contains(_activeMethod))) {
      throw const WebRgbError(
        'NOT_ENABLED',
        'Session or request is no longer authorized.',
      );
    }
  }

  /// Irreversibly revoke this router and release cached proof/results.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    _proof = null;
    _proofBytes = null;
    _requests.clear();
    _provider.revoke();
  }

  /// Routes positional parameters and returns a JSON-RPC 2.0 response.
  ///
  /// Pass the request's original expiry in Unix seconds. The host must deliver
  /// only to [topic], and must cancel its approval UI when the request expires.
  /// Inputs are snapshotted before queuing; at most 256 unexpired request IDs
  /// and 64 KiB per request are retained. Capacity exhaustion fails closed,
  /// rather than evicting a mutation result and accidentally re-executing it.
  Future<Map<String, Object?>> handle({
    required int id,
    required String topic,
    required String chainId,
    required String method,
    required List<Object?> params,
    int? expiry,
  }) async {
    try {
      _check(request: false);
      webRgbInteger(id, 'id', min: 0);
      if (topic != _grant.topic || chainId != 'rgb:${_grant.network}') {
        throw const WebRgbError('NOT_ENABLED', 'Wrong session or network.');
      }
      final deadline = expiry ?? _grant.expiry;
      webRgbInteger(deadline, 'expiry', min: 0);
      if (deadline <= _now) {
        throw const WebRgbError('INVALID_PARAMS', 'Request expired.');
      }
      if (!_currentGrant()!.methods.contains(method)) {
        throw const WebRgbError(
          'METHOD_NOT_SUPPORTED',
          'Method is not authorized.',
        );
      }
      final encoded = jsonEncode(params);
      if (utf8.encode(encoded).length > 65536) {
        throw const WebRgbError('INVALID_PARAMS', 'Request is too large.');
      }
      final frozen = jsonDecode(encoded) as List<Object?>;
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode([chainId, method, deadline, frozen])))
          .toString();
      _requests.removeWhere((_, item) => item.complete && item.expiry <= _now);
      final existing = _requests[id];
      if (existing != null) {
        if (existing.fingerprint != fingerprint) {
          throw const WebRgbError(
            'INVALID_PARAMS',
            'Request ID was reused with different parameters.',
          );
        }
        final reply = await existing.result;
        _check(request: false);
        if (deadline <= _now || !_currentGrant()!.methods.contains(method)) {
          throw const WebRgbError('NOT_ENABLED', 'Request permission expired.');
        }
        return _copyReply(reply);
      }
      if (_requests.length >= 256) {
        throw const WebRgbError(
          'INTERNAL_ERROR',
          'Session request capacity reached.',
        );
      }
      final result = _queue.then((_) async {
        try {
          _activeMethod = method;
          _activeExpiry = deadline;
          _check();
          final value = await _dispatch(method, frozen);
          _check();
          return Map<String, Object?>.unmodifiable({
            'id': id,
            'jsonrpc': '2.0',
            'result': value,
          });
        } catch (error) {
          return _errorReply(id, error);
        } finally {
          _activeMethod = null;
          _activeExpiry = null;
        }
      });
      final request = _Request(fingerprint, deadline, result);
      _requests[id] = request;
      _queue = result.then((_) => request.complete = true);
      return _copyReply(await result);
    } catch (error) {
      return _errorReply(id, error);
    }
  }

  Future<Object?> _dispatch(String method, List<Object?> args) async {
    final name = method.startsWith('rgb_') ? method.substring(4) : '';
    if (!{
      ...webRgbReadMethods,
      'signMessage',
      'burnAsset',
      'getConsignment',
    }.contains(name)) {
      throw const WebRgbError(
        'METHOD_NOT_SUPPORTED',
        'Method is not supported.',
      );
    }
    final zero = {
      'enable',
      'getInfo',
      'getAddress',
      'listAssets',
    }.contains(name);
    final optional = {
      'blindReceive',
      'witnessReceive',
      'listTransfers',
    }.contains(name);
    if (args.length < (zero || optional ? 0 : 1) ||
        args.length >
            (zero
                ? 0
                : name == 'getTransferStatus'
                ? 2
                : 1)) {
      throw const WebRgbError('INVALID_PARAMS', 'Invalid argument count.');
    }
    if (name != 'enable' && !_enabled) {
      throw const WebRgbError('NOT_ENABLED', 'Call enable first.');
    }
    switch (name) {
      case 'enable':
        await _provider.enable();
        _check();
        _enabled = true;
        return null;
      case 'getInfo':
        final info = await _provider.getInfo();
        _check();
        final methods = info.methods
            .where((m) => _currentGrant()!.methods.contains('rgb_$m'))
            .toList();
        return WebRgbInfo(
          network: info.network,
          protocol: info.protocol,
          methods: methods,
          burnRecipientNamespaces: methods.contains('burnAsset')
              ? info.burnRecipientNamespaces
              : null,
          burnDestinationRoutes: methods.contains('burnAsset')
              ? info.burnDestinationRoutes
              : const [],
        ).toJson();
      case 'getAddress':
        return (await _provider.getAddress()).toJson();
      case 'signMessage':
        return (await _provider.signMessage(_string(args.first))).toJson();
      case 'blindReceive':
      case 'witnessReceive':
        final input = args.isEmpty ? <String, Object?>{} : _object(args.first);
        final request = WebRgbBlindReceiveArgs(
          assetId: _optionalString(input['assetId']),
          amount: _optionalInteger(input['amount']),
          durationSeconds: _optionalInteger(input['durationSeconds']) ?? 3600,
          minConfirmations: _optionalInteger(input['minConfirmations']),
        );
        return (await (name == 'blindReceive'
                ? _provider.blindReceive(request)
                : _provider.witnessReceive(request)))
            .toJson();
      case 'listAssets':
        return (await _provider.listAssets()).map((a) => a.toJson()).toList();
      case 'getAssetBalance':
        return (await _provider.getAssetBalance(_string(args.first))).toJson();
      case 'listTransfers':
        return (await _provider.listTransfers(
          args.isEmpty ? null : _optionalString(args.first),
        )).map((t) => t.toJson()).toList();
      case 'getTransferStatus':
        final id = args.first;
        if (id is! String && id is! int) {
          throw const WebRgbError('INVALID_PARAMS', 'Invalid transfer ID.');
        }
        return (await _provider.getTransferStatus(
          id!,
          args.length == 2 ? _optionalString(args[1]) : null,
        )).toJson();
      case 'decodeRgbInvoice':
        final input = args.first;
        return (await _provider.decodeRgbInvoice(
          _string(input is String ? input : _object(input)['invoice']),
        )).toJson();
      case 'burnAsset':
        final input = _object(args.first);
        final payout = _object(input['burnRecipient']);
        return (await _provider.burnAsset(
          WebRgbBurnAssetArgs(
            network: _string(input['network']),
            assetId: _string(input['assetId']),
            amount: _string(input['amount']),
            burnRecipient: BurnPayout(
              chainId: _string(payout['chainId']),
              address: _string(payout['address']),
            ),
            burnDestination: input.containsKey('burnDestination')
                ? await webRgbWalletCall(
                    () async =>
                        BurnDestination.fromJson(input['burnDestination']),
                  )
                : null,
            feeRate: _optionalInteger(input['feeRate']) ?? 2,
            minConfirmations: _optionalInteger(input['minConfirmations']) ?? 3,
          ),
        )).toJson();
      case 'getConsignment':
        return _chunk(_object(args.first));
    }
    throw const WebRgbError('METHOD_NOT_SUPPORTED', 'Method is not supported.');
  }

  Future<Map<String, Object?>> _chunk(Map<String, Object?> input) async {
    final asset = _string(input['assetId']);
    final txid = _string(input['txid']);
    final offset = webRgbInteger(
      _optionalInteger(input['offset']) ?? 0,
      'offset',
      min: 0,
    );
    final length = webRgbInteger(
      _optionalInteger(input['length']) ?? webRgbConsignmentChunkBytes,
      'length',
      max: webRgbConsignmentChunkBytes,
    );
    var proof = _proof;
    var bytes = _proofBytes;
    if (offset == 0 ||
        proof == null ||
        bytes == null ||
        proof.assetId != asset ||
        proof.txid != txid) {
      proof = await _provider.getConsignment(
        WebRgbGetConsignmentArgs(assetId: asset, txid: txid),
      );
      _check();
      if (proof.data.length > ((16 * 1024 * 1024 + 2) ~/ 3) * 4) {
        throw const WebRgbError(
          'INTERNAL_ERROR',
          'Proof exceeds transport limit.',
        );
      }
      bytes = await _decodeTransportProof(proof);
      _check();
      _proof = proof;
      _proofBytes = bytes;
    }
    if (offset >= bytes.length) {
      throw const WebRgbError('INVALID_PARAMS', 'Invalid proof offset.');
    }
    final end = offset + length < bytes.length ? offset + length : bytes.length;
    return {
      ...proof.toJson(),
      'data': base64Encode(Uint8List.sublistView(bytes, offset, end)),
      'offset': offset,
      'nextOffset': end == bytes.length ? null : end,
    };
  }
}

// Only immutable proof data crosses isolates, never the wallet or session.
Future<Uint8List> _decodeTransportProof(WebRgbGetConsignmentResult proof) =>
    Isolate.run(() {
      final bytes = base64Decode(proof.data);
      final digest = KeccakDigest(
        256,
      ).process(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (bytes.isEmpty ||
          bytes.length > 16 * 1024 * 1024 ||
          bytes.length != proof.byteLength ||
          base64Encode(bytes) != proof.data ||
          proof.digest.toLowerCase() != '0x$digest') {
        throw const WebRgbError(
          'INTERNAL_ERROR',
          'Invalid proof encoding or digest.',
        );
      }
      return bytes;
    });

// A host may decorate its reply for delivery without changing a deduped result.
Map<String, Object?> _copyReply(Map<String, Object?> reply) =>
    jsonDecode(jsonEncode(reply)) as Map<String, Object?>;

Map<String, Object?> _object(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw const WebRgbError('INVALID_PARAMS', 'Expected an object.');
}

String _string(Object? value) {
  if (value is String) return value;
  throw const WebRgbError('INVALID_PARAMS', 'Expected a string.');
}

String? _optionalString(Object? value) => value == null ? null : _string(value);
int? _optionalInteger(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  throw const WebRgbError('INVALID_PARAMS', 'Expected an exact integer.');
}

Map<String, Object?> _errorReply(int id, Object error) {
  const codes = {
    'USER_REJECTED',
    'NOT_ENABLED',
    'METHOD_NOT_SUPPORTED',
    'INVALID_PARAMS',
    'ASSET_NOT_FOUND',
    'INTERNAL_ERROR',
  };
  final code = error is WebRgbError && codes.contains(error.code)
      ? error.code
      : 'INTERNAL_ERROR';
  final (number, message) = switch (code) {
    'USER_REJECTED' => (4001, 'User rejected the request.'),
    'NOT_ENABLED' => (3001, 'Session or request is not authorized.'),
    'METHOD_NOT_SUPPORTED' => (-32601, 'Method is not supported.'),
    'INVALID_PARAMS' => (-32602, 'Invalid request parameters.'),
    _ => (-32000, 'Wallet request failed.'),
  };
  return Map.unmodifiable({
    'id': id,
    'jsonrpc': '2.0',
    'error': Map<String, Object?>.unmodifiable({
      'code': number,
      'message': message,
      'data': code,
    }),
  });
}
