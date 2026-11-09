import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart';

const _channel = MethodChannel('com.utexo.rgb_sdk_flutter/rgb_lib');
const _asset = 'rgb:A6k89KtR-e3oXqRP-uH3jUrz-LU_sYL3-hMZ0k3O-6u8DXbE';
const _proxy = 'rpcs://dev.rgb-proxy.utexo.com/json-rpc';
const _origin = 'https://dev.mint.utexo.com';
const _topic =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _payout = '0x1111111111111111111111111111111111111111';
const _txid =
    'abababababababababababababababababababababababababababababababab';
const _walletId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _cohort = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _now = 1800000000;
const _expiry = _now + 86400;

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  late _NativeFixture native;
  late RgbLibWallet wallet;
  late WebRgbWalletConnectGrant? grant;
  late List<WebRgbApproval> approvals;
  var approved = true;

  WebRgbWalletConnectSession router() => WebRgbWalletConnectSession.hostedDev(
    wallet: wallet,
    grant: grant!,
    currentGrant: () => grant,
    confirm: (approval) async {
      approvals.add(approval);
      return approved;
    },
    clock: () => DateTime.fromMillisecondsSinceEpoch(_now * 1000),
  );

  setUp(() async {
    native = _NativeFixture();
    messenger.setMockMethodCallHandler(_channel, native.dispatch);
    wallet = await _open();
    grant = _grant();
    approvals = [];
    approved = true;
  });

  tearDown(() async {
    await wallet.destroy();
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('requires exact wallet grant and qualified durable artifact', () async {
    grant = _grant(origin: 'https://example.test');
    expect(router, throwsA(isA<WebRgbError>()));
    grant = _grant(account: 'rgb:utexo:wrong');
    expect((await _call(router(), 'rgb_getInfo'))['error'], isNotNull);
    grant = _grant();
    await wallet.destroy();
    native.capability = false;
    wallet = await _open();
    expect(wallet.supportsHostedDevBridge, isFalse);
    expect(router, throwsA(isA<WebRgbError>()));
  });

  test(
    'read replies expose only the approved bridge asset and wire fields',
    () async {
      final session = router();
      final assets = await _call(session, 'rgb_listAssets');
      expect(assets['result'], [
        {
          'id': _asset,
          'schema': 'bfa',
          'name': 'Dev USDT',
          'ticker': 'BUSDT',
          'precision': 6,
        },
      ]);
      final balance = await _call(
        session,
        'rgb_getAssetBalance',
        id: 2,
        params: [_asset],
      );
      expect(balance['result'], {
        'assetId': _asset,
        'balance': 5,
        'raw': {'spendable': 5},
      });
      final rejected = await _call(
        session,
        'rgb_getAssetBalance',
        id: 3,
        params: ['rgb:other'],
      );
      expect(rejected['error'], containsPair('data', 'ASSET_NOT_FOUND'));
      final decoded = await _call(
        session,
        'rgb_decodeRgbInvoice',
        id: 4,
        params: ['rgb:fixture'],
      );
      expect(decoded['result'], containsPair('network', 'signet'));
    },
  );

  test('blind invoice is recovered across wallet and router restart', () async {
    final first = router();
    final args = [
      {'amount': 5, 'durationSeconds': 86400},
    ];
    final issued = await _call(first, 'rgb_blindReceive', params: args);
    expect(issued['result'], containsPair('recipientId', 'recipient-fixture'));
    expect(approvals.single.method, 'blindReceive');
    first.dispose();
    await wallet.destroy();
    wallet = await _open();
    final restored = await _call(
      router(),
      'rgb_blindReceive',
      params: [
        {'durationSeconds': 86400, 'amount': 5},
      ],
      recoveryOnly: true,
    );
    expect(restored, issued);
    expect(native.blindCreations, 1);
    expect(approvals, hasLength(1));
    final missing = await _call(
      router(),
      'rgb_blindReceive',
      id: 2,
      params: args,
      recoveryOnly: true,
    );
    expect(missing['error'], isNotNull);
    expect(native.blindCreations, 1);
  });

  test(
    'burn review uses exact fee, replay observes only, proof is scoped',
    () async {
      final first = router();
      final info = await _call(first, 'rgb_getInfo', id: 5);
      expect(info['result'], containsPair('burnDestinationVersion', 1));
      final request = _burnRequest();
      final burned = await _call(first, 'rgb_burnAsset', params: [request]);
      expect(burned['result'], containsPair('txid', _txid));
      expect(approvals.single.params, containsPair('feeSats', 450));
      expect(approvals.single.params, containsPair('minConfirmations', 6));
      first.dispose();
      await wallet.destroy();
      wallet = await _open();
      final restored = router();
      expect(
        await _call(
          restored,
          'rgb_burnAsset',
          params: [request],
          recoveryOnly: true,
        ),
        burned,
      );
      expect(native.prepares, 1);
      expect(native.commits, 1);
      expect(approvals, hasLength(1));
      final proof = await _call(
        restored,
        'rgb_getConsignment',
        id: 2,
        params: [
          {'assetId': _asset, 'txid': _txid, 'length': 4},
        ],
      );
      expect(proof['result'], containsPair('nextOffset', 4));
      expect(approvals.last.method, 'getConsignment');
      expect(native.proofs, 1);
      final history = await _call(restored, 'rgb_listTransfers', id: 3);
      expect(history['result'], [
        allOf(
          containsPair('txid', _txid),
          containsPair('amountBaseUnits', '1500000'),
        ),
      ]);
      final localHistory =
          await WebRgbWalletConnectSession.listHostedDevBridgeBurns(
            wallet: wallet,
            topic: _topic,
            assertAuthorized: () {},
          );
      expect(localHistory.single.txid, _txid);
      final exported =
          await WebRgbWalletConnectSession.exportHostedDevBridgeBurn(
            wallet: wallet,
            topic: _topic,
            txid: _txid,
            assertAuthorized: () {},
          );
      expect(exported, {
        'format': 'utexo-burn',
        'version': 1,
        'consignment': {
          'encoding': 'base64',
          'byteLength': 10,
          'data': 'UkdCAFRGUgECAw==',
        },
        'burnDestination': request['burnDestination'],
      });
      expect(
        await WebRgbWalletConnectSession.cancelUnsubmittedHostedDevBurn(
          wallet: wallet,
          topic: _topic,
          id: 1,
          expiry: _now + 600,
          params: [request],
          assertAuthorized: () {},
        ),
        isFalse,
      );
      expect(native.cancels, 0);
      grant = _grant(topic: 'another-topic');
      final hidden = await _call(
        router(),
        'rgb_listTransfers',
        topic: 'another-topic',
      );
      expect(hidden['result'], isEmpty);
      final rejected = await _call(
        router(),
        'rgb_getConsignment',
        id: 2,
        topic: 'another-topic',
        params: [
          {'assetId': _asset, 'txid': _txid},
        ],
      );
      expect(rejected['error'], isNotNull);
      expect(native.proofs, 2);
    },
  );

  test('a lost commit reply can be recovered without another burn', () async {
    native.loseCommitReply = true;
    final session = router();
    final params = [_burnRequest()];
    final missing = await _call(session, 'rgb_burnAsset', params: params);
    expect(missing['error'], isNotNull);
    final changedExpiry = await _call(
      session,
      'rgb_burnAsset',
      params: params,
      expiry: _now + 601,
      recoveryOnly: true,
    );
    expect(changedExpiry['error'], containsPair('data', 'INVALID_PARAMS'));
    final recovered = await _call(
      session,
      'rgb_burnAsset',
      params: params,
      recoveryOnly: true,
    );
    expect(recovered['result'], containsPair('txid', _txid));
    expect(native.prepares, 1);
    expect(native.commits, 1);
    expect(native.cancels, 0);
    expect(approvals, hasLength(1));
  });

  test(
    'interrupted preparation is rolled back without consent or dispatch',
    () async {
      native.losePrepareReply = true;
      final params = [_burnRequest()];
      final first = router();
      final lost = await _call(first, 'rgb_burnAsset', params: params);
      expect(lost['error'], isNotNull);
      first.dispose();
      await wallet.destroy();
      wallet = await _open();
      final restarted = router();
      final recovered = await _call(
        restarted,
        'rgb_burnAsset',
        params: params,
        recoveryOnly: true,
      );
      expect(recovered['error'], containsPair('data', 'BURN_NOT_SUBMITTED'));
      expect(native.prepares, 1);
      expect(native.commits, 0);
      expect(native.cancels, 1);
      expect(approvals, isEmpty);

      final noRelay = await _call(
        restarted,
        'rgb_burnAsset',
        id: 2,
        params: params,
      );
      expect(noRelay['error'], isNotNull);
      grant = null;
      final cleared =
          await WebRgbWalletConnectSession.cancelUnsubmittedHostedDevBurn(
            wallet: wallet,
            topic: _topic,
            id: 2,
            expiry: _now + 600,
            params: params,
            assertAuthorized: () {},
          );
      expect(cleared, isTrue);
      expect(native.cancels, 2);
      expect(native.commits, 0);
    },
  );

  test(
    'rejects a bad mixed-case EVM checksum before native preparation',
    () async {
      final session = router();
      final invalid = _burnRequest();
      invalid['burnRecipient'] = {
        'chainId': 'eip155:42161',
        'address': '0x5AAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
      };
      final rejected = await _call(session, 'rgb_burnAsset', params: [invalid]);
      expect(rejected['error'], containsPair('data', 'INVALID_PARAMS'));
      expect(native.prepares, 0);
      expect(approvals, isEmpty);

      const address = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
      final valid = _burnRequest();
      valid['burnRecipient'] = {'chainId': 'eip155:42161', 'address': address};
      valid['burnDestination'] = BurnDestination.forPayout(
        BurnDestinationRoute(chainId: 'eip155:42161', dstEid: 0),
        address,
      ).toJson();
      final accepted = await _call(
        session,
        'rgb_burnAsset',
        id: 2,
        params: [valid],
      );
      expect(accepted['result'], containsPair('txid', _txid));
      expect(native.commits, 1);
    },
  );

  test('declined burn cancels only the staged operation', () async {
    approved = false;
    final result = await _call(
      router(),
      'rgb_burnAsset',
      params: [_burnRequest()],
    );
    expect(result['error'], containsPair('data', 'USER_REJECTED'));
    expect(native.prepares, 1);
    expect(native.commits, 0);
    expect(native.cancels, 1);
    final replay = await _call(
      router(),
      'rgb_burnAsset',
      params: [_burnRequest()],
      recoveryOnly: true,
    );
    expect(replay['error'], isNotNull);
    expect(native.commits, 0);
  });
}

Future<RgbLibWallet> _open() async {
  final wallet = RgbLibWallet(
    params: const RgbLibWalletParams(
      network: 'utexo',
      storageDirPath: '/private/test',
      allowUtexoDevSignet: true,
    ),
    keys: RgbLibKeys.mnemonic('test-only fixture'),
  );
  await wallet.init();
  await wallet.unlock(
    RgbLibUnlockParams(
      indexer: const RgbLibIndexer.esplora(
        'https://dev.esplora-01.mint.utexo.com',
      ),
      proxyEndpoint: _proxy,
      evmChains: const {
        '42161': RgbLibEvmChain(
          rpcUrl: 'https://arb1.arbitrum.io/rpc',
          minMintLockBlocks: 2,
          maxMintLockBlocks: 7200,
        ),
      },
    ),
  );
  return wallet;
}

WebRgbWalletConnectGrant _grant({
  String origin = _origin,
  String account = 'rgb:utexo:$_walletId',
  String topic = _topic,
}) => WebRgbWalletConnectGrant(
  topic: topic,
  origin: origin,
  network: 'utexo',
  account: account,
  expiry: _expiry,
  methods: WebRgbWalletConnectSession.hostedDevMethods,
);

Future<Map<String, Object?>> _call(
  WebRgbWalletConnectSession router,
  String method, {
  int id = 1,
  String topic = _topic,
  List<Object?> params = const [],
  bool recoveryOnly = false,
  int expiry = _now + 600,
}) => router.handle(
  id: id,
  topic: topic,
  chainId: 'rgb:utexo',
  method: method,
  params: params,
  expiry: expiry,
  recoveryOnly: recoveryOnly,
);

Map<String, Object?> _burnRequest() => {
  'network': 'utexo',
  'assetId': _asset,
  'amount': '1500000',
  'burnRecipient': {'chainId': 'eip155:42161', 'address': _payout},
  'burnDestination': BurnDestination.forPayout(
    BurnDestinationRoute(chainId: 'eip155:42161', dstEid: 0),
    _payout,
  ).toJson(),
};

final class _NativeFixture {
  bool capability = true;
  bool loseCommitReply = false;
  bool losePrepareReply = false;
  int blindCreations = 0;
  int prepares = 0;
  int commits = 0;
  int cancels = 0;
  int proofs = 0;
  final _requests = <String, Map<String, Object?>>{};

  Future<Object?> dispatch(MethodCall call) async {
    switch (call.method) {
      case 'getRuntimeInfo':
        return {
          'version': RgbLibRuntimeInfo.expectedVersion,
          'sourceRevision': RgbLibRuntimeInfo.expectedSourceRevision,
          'integrationTree': RgbLibRuntimeInfo.expectedIntegrationTree,
          'overlayPatchSha256': RgbLibRuntimeInfo.expectedOverlayPatchSha256,
          'sourceLockSha256': RgbLibRuntimeInfo.expectedSourceLockSha256,
          'sourceManifestSha256':
              RgbLibRuntimeInfo.expectedSourceManifestSha256,
          'bridgeVersion': RgbLibRuntimeInfo.expectedBridgeVersion,
          'nativeOverlay': 'flutter-bfa7-durable-v1',
          'bfa': true,
          'burn': true,
          'consignment': true,
          'contractRegistration': true,
          'durableOnchainRecovery': true,
          'supportsHostedDevSignet': true,
          'supportsDurableHostedDevBridge': capability,
        };
      case 'openWallet':
        return 'handle';
      case 'getWalletIdentity':
        return {
          'id': _walletId,
          'network': 'utexo',
          'masterFingerprint': 'a1b2c3d4',
          'recoveryCohort': _cohort,
        };
      case 'closeWallet':
      case 'goOnline':
        return null;
      case 'listAssets':
        return [
          {
            'schema': 'Bfa',
            'assetId': _asset,
            'name': 'Dev USDT',
            'ticker': 'BUSDT',
            'precision': 6,
            'timestamp': '1',
            'addedAt': '1',
            'initialSupply': '10',
            'balance': {'settled': '5', 'future': '6', 'spendable': '5'},
          },
        ];
      case 'getAssetBalance':
        return {'settled': '5', 'future': '6', 'spendable': '5'};
      case 'listTransfers':
        return [
          for (final transfer in _requests.values.where(
            (row) => row['phase'] == 'accepted',
          ))
            {
              'idx': 8,
              'batchTransferIdx': transfer['batchTransferIdx'],
              'createdAt': '1',
              'updatedAt': '1',
              'status': 'Settled',
              'kind': 'Burn',
              'txid': transfer['txid'],
              'requestedAssignment': {
                'type': 'Fungible',
                'amount': transfer['amount'],
              },
              'assignments': <Object?>[],
              'changeUtxos': <Object?>[],
              'transportEndpoints': <Object?>[],
            },
        ];
      case 'listUnspents':
        return [
          {
            'utxo': {
              'outpoint': {'txid': _txid, 'vout': 0},
              'btcAmount': '1000',
              'colorable': true,
              'exists': true,
            },
            'rgbAllocations': <Object?>[],
            'pendingBlinded': 0,
          },
        ];
      case 'listTransactions':
        return [
          {
            'txid': _txid,
            'transactionType': 'CreateUtxos',
            'received': '0',
            'sent': '1000',
            'fee': '100',
            'confirmationTime': {'height': 1, 'timestamp': '1'},
          },
        ];
      case 'decodeInvoice':
        return {
          'recipientId': 'recipient-fixture',
          'recipientType': 'Blind',
          'assetSchema': 'Bfa',
          'assetId': _asset,
          'network': 'signet',
          'assignment': {'type': 'Fungible', 'amount': '5'},
          'expirationTimestamp': '$_expiry',
          'transportEndpoints': [_proxy],
          'encryption': 'Required',
          'unknownQueryParams': <Object?>[],
        };
    }
    final args = call.arguments as Map<Object?, Object?>;
    final request =
        jsonDecode(args['requestJson']! as String) as Map<String, Object?>;
    final operation = request['operationId'] as String?;
    final stored = operation == null ? null : _requests[operation];
    if (stored != null && stored['requestKey'] != request['requestKey']) {
      throw PlatformException(code: 'RECOVERY_REQUEST_MISMATCH');
    }
    switch (call.method) {
      case 'bridgeBlindReceive':
        if (args['recoveryOnly'] == true) return jsonEncode(stored);
        blindCreations++;
        return jsonEncode(
          _requests[operation!] = {
            ...request,
            'invoice': 'rgb:fixture',
            'recipientId': 'recipient-fixture',
            'expirationTimestamp': '$_expiry',
          },
        );
      case 'observeBridgeBurn':
        if (operation != null) return jsonEncode(stored);
        return jsonEncode(
          _requests.values
              .where(
                (value) =>
                    value['phase'] == 'accepted' &&
                    value['scopeKey'] == request['scopeKey'] &&
                    value['txid'] == request['txid'],
              )
              .firstOrNull,
        );
      case 'prepareBridgeBurn':
        prepares++;
        final prepared = _requests[operation!] = {
          ...request,
          'phase': 'prepared',
          'feeSats': '450',
        };
        if (losePrepareReply) throw PlatformException(code: 'RECOVERY_PENDING');
        return jsonEncode(prepared);
      case 'commitBridgeBurn':
        commits++;
        final accepted = _requests[operation!] = {
          ...stored!,
          'phase': 'accepted',
          'txid': _txid,
          'batchTransferIdx': 9,
        };
        if (loseCommitReply) {
          throw PlatformException(code: 'RECOVERY_PENDING');
        }
        return jsonEncode(accepted);
      case 'cancelBridgeBurn':
        cancels++;
        return jsonEncode(
          _requests[operation!] = {...stored!, 'phase': 'rejected'},
        );
      case 'bridgeBurnProof':
        proofs++;
        final bytes = [82, 71, 66, 0, 84, 70, 82, 1, 2, 3];
        final accepted = _requests.values.singleWhere(
          (value) =>
              value['phase'] == 'accepted' &&
              value['scopeKey'] == request['scopeKey'],
        );
        return jsonEncode({
          ...accepted,
          'data': base64Encode(bytes),
          'sha256': sha256.convert(bytes).toString(),
        });
      default:
        throw StateError('Unexpected native operation ${call.method}');
    }
  }
}
