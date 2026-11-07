import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart';
import 'package:rgb_sdk_flutter/src/errors/native_bridge_error_mapper.dart';

import 'burn_operations_test.dart' show MemoryBurnStore;

final _txid = 'ab' * 32;
const _assetId = 'rgb:asset';
const _payout = BurnPayout(
  chainId: 'eip155:42161',
  address: '0x1212121212121212121212121212121212121212',
);
const _tronAddress = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
const _tronRecipient =
    '000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c';
const _tronChains = ['tron:728126428', 'tron:2494104990', 'tron:3448148188'];
const _args = WebRgbBurnAssetArgs(
  network: 'regtest',
  assetId: _assetId,
  amount: '18446744073709551615',
  burnRecipient: _payout,
);
CoreAssetBalance _balance(BigInt amount) => CoreAssetBalance(
  settled: amount,
  future: amount,
  spendable: amount,
  offchainInbound: BigInt.zero,
  offchainOutbound: BigInt.zero,
);

class _Wallet implements UtexoWallet {
  bool disposed = false;
  int burns = 0;
  String proof = base64Encode(utf8.encode('abc'));
  String transferKind = 'Burn';
  int? anchor = 100;
  bool hasBfa = true;
  bool supportsBurn = true;
  bool supportsProof = true;
  BigInt amount = BigInt.from(42);
  String assignmentType = 'Fungible';
  Future<String> Function()? address;
  Future<BurnResult> Function()? burning;
  Future<String> Function(String)? readingProof;
  Object? decodeFailure;
  RgbInvoiceRequest? received;
  String? receivedMethod;
  final List<String> signedMessages = [];
  String expectedBurnRecipient = '${'0' * 24}${'12' * 20}';
  Future<String> Function(String)? signing;
  @override
  bool isDisposed() => disposed;
  @override
  String getNetwork() => 'regtest';
  @override
  Future<String> getAddress() async =>
      address == null ? 'bc1address' : await address!();
  @override
  Future<BfaCapabilities> getBfaCapabilities() async => BfaCapabilities(
    burn: supportsBurn,
    consignment: supportsProof,
    bfa: true,
  );
  @override
  Future<CoreListAssets> listAssets({
    List<String> filterAssetSchemas = const [],
  }) async => CoreListAssets(
    bfa: [
      if (hasBfa)
        CoreAssetBfa(
          assetId: _assetId,
          ticker: 'USDT',
          name: 'Tether',
          precision: 6,
          timestamp: 1,
          addedAt: 2,
          balance: _balance(amount),
          initialSupply: BigInt.parse('18446744073709551615'),
        ),
    ],
    nia: const [],
    cfa: const [],
    ifa: const [],
    uda: const [],
  );
  @override
  Future<CoreAssetBalance> getAssetBalance(String assetId) async =>
      _balance(amount);
  @override
  Future<BurnResult> burn(BurnParams params) async {
    burns++;
    expect(params.amount, _args.amount);
    expect(params.burnRecipient, expectedBurnRecipient);
    return burning == null
        ? BurnResult(txid: _txid, batchTransferIdx: 42)
        : await burning!();
  }

  @override
  Future<List<CoreTransfer>> listTransfers({String? assetId}) async => [
    for (final id in [_txid, 'cd' * 32])
      CoreTransfer(
        idx: 9,
        kind: transferKind,
        status: 'Settled',
        txid: id,
        assignments: [Assignment(type: 'Fungible', amount: amount)],
        requestedAssignment: Assignment(type: 'Fungible', amount: amount),
        transportEndpoints: const [],
      ),
  ];
  @override
  Future<List<CoreTransaction>> listTransactionsByTxid(
    String txid, {
    bool skipSync = false,
  }) async => [
    CoreTransaction(
      txid: txid,
      transactionType: 'RgbSend',
      received: 0,
      sent: 1,
      fee: 1,
      confirmationTime: anchor == null
          ? null
          : CoreBlockTime(height: anchor!, timestamp: 1),
    ),
  ];
  @override
  Future<WalletNetworkInfo> getNetworkInfo() async =>
      const WalletNetworkInfo(network: 'regtest', height: 102);
  @override
  Future<void> refreshWallet() async {}
  @override
  Future<String> getConsignment(String assetId, String txid) async =>
      readingProof == null ? proof : await readingProof!(txid);
  @override
  Future<CoreInvoiceReceiveData> blindReceive(RgbInvoiceRequest request) async {
    received = request;
    receivedMethod = 'blindReceive';
    return const CoreInvoiceReceiveData(
      invoice: 'rgb:invoice',
      recipientId: 'recipient',
      expirationTimestamp: 123,
      batchTransferIdx: 4,
    );
  }

  @override
  Future<CoreInvoiceReceiveData> witnessReceive(
    RgbInvoiceRequest request,
  ) async {
    final result = await blindReceive(request);
    receivedMethod = 'witnessReceive';
    return result;
  }

  @override
  Future<String> signMessage(String message) async {
    signedMessages.add(message);
    return signing == null ? 'native-signature' : await signing!(message);
  }

  @override
  Future<CoreInvoiceData> decodeRgbInvoice(String invoice) async {
    if (decodeFailure case final failure?) throw failure;
    return CoreInvoiceData(
      invoice: invoice,
      assetId: _assetId,
      recipientId: 'recipient',
      network: 'regtest',
      assignment: Assignment(type: assignmentType, amount: amount),
      expirationTimestamp: 123,
      transportEndpoints: const ['rpc://proxy.example'],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Matcher _error(String code) =>
    throwsA(isA<WebRgbError>().having((e) => e.code, 'code', code));

void main() {
  late _Wallet wallet;
  late MemoryBurnStore store;
  late BurnOperations operations;
  late List<WebRgbApproval> prompts;
  var approve = true;
  WebRgbProvider provider({
    bool approved = true,
    bool burn = true,
    Future<bool> Function(WebRgbApproval)? confirm,
    String origin = 'https://mint.example',
    Iterable<String> allowedPayoutChainIds = const ['eip155:42161'],
  }) => WebRgbProvider(
    wallet,
    WebRgbOptions(
      origin: origin,
      sessionApproved: approved,
      confirm:
          confirm ??
          (request) async {
            prompts.add(request);
            return approve;
          },
      burn: burn
          ? WebRgbBurnOptions(
              operations: operations,
              allowedPayoutChainIds: allowedPayoutChainIds,
            )
          : null,
    ),
  );
  setUp(() {
    wallet = _Wallet();
    store = MemoryBurnStore();
    operations = BurnOperations(wallet, store);
    prompts = [];
    approve = true;
  });

  test(
    'optional entrypoint advertises only supported, configured methods',
    () async {
      expect((await provider(burn: false).getInfo()).methods, [
        ...webRgbReadMethods,
        'signMessage',
      ]);
      expect((await provider().getInfo()).methods, [
        ...webRgbReadMethods,
        'signMessage',
        'burnAsset',
        'getConsignment',
      ]);
      wallet.supportsBurn = false;
      expect((await provider().getInfo()).methods, [
        ...webRgbReadMethods,
        'signMessage',
        'getConsignment',
      ]);
      wallet.supportsProof = false;
      expect((await provider().getInfo()).methods, [
        ...webRgbReadMethods,
        'signMessage',
      ]);
      await expectLater(
        provider().burnAsset(_args),
        _error('METHOD_NOT_SUPPORTED'),
      );
      expect(wallet.burns, 0);
    },
  );

  test(
    'burn namespaces follow native capabilities and host chain policy',
    () async {
      expect((await provider().getInfo()).toJson()['burnRecipientNamespaces'], [
        'eip155',
      ]);
      final both = await provider(
        allowedPayoutChainIds: ['tron:728126428', 'eip155:42161'],
      ).getInfo();
      expect(both.burnRecipientNamespaces, ['eip155', 'tron']);
      expect(
        () => both.burnRecipientNamespaces!.add('unapproved'),
        throwsUnsupportedError,
      );
      expect(
        (await provider(burn: false).getInfo()).toJson(),
        isNot(contains('burnRecipientNamespaces')),
      );
      wallet.supportsBurn = false;
      expect(
        (await provider().getInfo()).toJson(),
        isNot(contains('burnRecipientNamespaces')),
      );
      wallet.supportsBurn = true;
      wallet.supportsProof = false;
      expect(
        (await provider().getInfo()).toJson(),
        isNot(contains('burnRecipientNamespaces')),
      );
    },
  );

  for (final chain in _tronChains) {
    test(
      'Tron $chain preserves approved address and exact commitment',
      () async {
        wallet.expectedBurnRecipient = _tronRecipient;
        final session = provider(allowedPayoutChainIds: [chain]);
        final burned = await session.burnAsset(
          WebRgbBurnAssetArgs(
            network: 'regtest',
            assetId: _assetId,
            amount: _args.amount,
            burnRecipient: BurnPayout(chainId: chain, address: _tronAddress),
          ),
        );
        expect(burned.burnRecipient.chainId, chain);
        expect(burned.burnRecipient.address, _tronAddress);
        expect(prompts.single.params['burnRecipient'], {
          'chainId': chain,
          'address': _tronAddress,
        });
        final record = (await operations.records()).single;
        expect(record.params.burnRecipient, _tronRecipient);
        expect(record.metadata.payout.address, _tronAddress);
        expect(record.metadata.payout.chainId, chain);
        final restarted = BurnOperations(wallet, store);
        expect(
          (await restarted.records()).single.metadata.payout.address,
          _tronAddress,
        );
        final status = await session.getTransferStatus(_txid);
        expect(status.transfer!.burnRecipient!.address, _tronAddress);
        expect(wallet.burns, 1);
      },
    );
  }

  test(
    'invalid or unapproved Tron recipients never prompt, persist or burn',
    () async {
      final session = provider(allowedPayoutChainIds: [_tronChains.first]);
      for (final payout in [
        BurnPayout(
          chainId: _tronChains.first,
          address: _tronAddress.toLowerCase(),
        ),
        BurnPayout(
          chainId: _tronChains.first,
          address: '${_tronAddress.substring(0, 33)}a',
        ),
        BurnPayout(
          chainId: _tronChains.first,
          address: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
        ),
        BurnPayout(
          chainId: _tronChains.first,
          address: 'TZQ7s7Wkv2SyN5pgpJ7AMdTsXyvYLbktsg',
        ),
        BurnPayout(
          chainId: _tronChains.first,
          address: '0x${_tronRecipient.substring(24)}',
        ),
        BurnPayout(chainId: _tronChains[1], address: _tronAddress),
        const BurnPayout(chainId: 'tron:1', address: _tronAddress),
        const BurnPayout(chainId: 'tron:0728126428', address: _tronAddress),
        const BurnPayout(chainId: 'tron:0x2b6653dc', address: _tronAddress),
        const BurnPayout(chainId: 'eip155:42161', address: _tronAddress),
      ]) {
        await expectLater(
          session.burnAsset(
            WebRgbBurnAssetArgs(
              network: 'regtest',
              assetId: _assetId,
              amount: _args.amount,
              burnRecipient: payout,
            ),
          ),
          _error('INVALID_PARAMS'),
        );
      }
      expect(prompts, isEmpty);
      expect(store.data, isEmpty);
      expect(wallet.burns, 0);
    },
  );

  test(
    'witness receive has distinct consent and the same confirmation floor',
    () async {
      final result = await provider().witnessReceive(
        const WebRgbWitnessReceiveArgs(amount: 5, minConfirmations: 1),
      );
      expect(wallet.receivedMethod, 'witnessReceive');
      expect(wallet.received!.minConfirmations, 3);
      expect(result.toJson(), {
        'invoice': 'rgb:invoice',
        'recipientId': 'recipient',
        'expirationTimestamp': 123,
        'minConfirmations': 3,
      });
      expect(prompts.single.method, 'witnessReceive');
      expect(prompts.single.params['amount'], 5);
      approve = false;
      wallet.received = null;
      await expectLater(provider().witnessReceive(), _error('USER_REJECTED'));
      expect(wallet.received, isNull);
    },
  );

  test(
    'message signing approves the exact Unicode string and native identity',
    () async {
      const message = 'Sign in\n\u{1f512} e\u0301';
      final result = await provider().signMessage(message);
      expect(result.toJson(), {'signature': 'native-signature'});
      expect(wallet.signedMessages, [message]);
      expect(prompts.single.origin, 'https://mint.example');
      expect(prompts.single.params, {'message': message});
      expect(prompts.single.method, 'signMessage');
      await provider().signMessage('');
      expect(wallet.signedMessages.last, '');
    },
  );

  test('malformed Unicode fails before prompting or signing', () async {
    for (final units in [
      [0xd800],
      [0xdc00],
      [0xd800, 65],
      [0xdc00, 0xd800],
    ]) {
      await expectLater(
        provider().signMessage(String.fromCharCodes(units)),
        _error('INVALID_PARAMS'),
      );
    }
    expect(prompts, isEmpty);
    expect(wallet.signedMessages, isEmpty);
  });

  test('signing decline and revoke/re-enable races cannot dispatch', () async {
    approve = false;
    await expectLater(
      provider().signMessage('message'),
      _error('USER_REJECTED'),
    );
    final gate = Completer<bool>();
    final session = provider(confirm: (_) => gate.future);
    final pending = session.signMessage('message');
    final assertion = expectLater(pending, _error('NOT_ENABLED'));
    session.revoke();
    gate.complete(true);
    await assertion;
    expect(wallet.signedMessages, isEmpty);
  });

  test(
    'revoked signing results and raw native failures never escape',
    () async {
      final gate = Completer<String>();
      wallet.signing = (_) => gate.future;
      final session = provider();
      final pending = session.signMessage('message');
      final assertion = expectLater(pending, _error('NOT_ENABLED'));
      await Future<void>.delayed(Duration.zero);
      expect(wallet.signedMessages, ['message']);
      session.revoke();
      gate.complete('secret-result');
      await assertion;
      wallet.signing = (_) async => throw StateError('/private/secret-wallet');
      await expectLater(
        provider().signMessage('message'),
        throwsA(
          isA<WebRgbError>().having(
            (e) => e.message,
            'sanitized',
            isNot(contains('secret-wallet')),
          ),
        ),
      );
    },
  );

  test(
    'enable approval is coalesced and revocation invalidates pending consent',
    () async {
      final approval = Completer<bool>();
      var calls = 0;
      final session = provider(
        approved: false,
        confirm: (_) {
          calls++;
          return approval.future;
        },
      );
      await expectLater(session.getAddress(), _error('NOT_ENABLED'));
      final first = session.enable();
      final second = session.enable();
      expect(calls, 1);
      final firstError = expectLater(first, _error('NOT_ENABLED'));
      final secondError = expectLater(second, _error('NOT_ENABLED'));
      session.revoke();
      approval.complete(true);
      await Future.wait([firstError, secondError]);
      expect(session.enabled, false);
    },
  );

  group('WalletConnect 0.1.3 wallet-side routing', () {
    var now = DateTime.utc(2026, 10, 13);
    late WebRgbWalletConnectGrant? current;
    late WebRgbWalletConnectSession router;
    WebRgbWalletConnectGrant grant({
      Iterable<String>? methods,
      String account = 'rgb:regtest:wallet-a',
    }) => WebRgbWalletConnectGrant(
      topic: 'session-topic',
      origin: 'https://mint.example',
      network: 'regtest',
      account: account,
      expiry: DateTime.utc(2026, 10, 14).millisecondsSinceEpoch ~/ 1000,
      methods:
          methods ??
          [
            ...webRgbReadMethods,
            'signMessage',
            'getConsignment',
            'burnAsset',
          ].map((m) => 'rgb_$m'),
    );
    Future<Map<String, Object?>> call(
      int id,
      String method, [
      List<Object?> params = const [],
      int? expiry,
    ]) => router.handle(
      id: id,
      topic: 'session-topic',
      chainId: 'rgb:regtest',
      method: 'rgb_$method',
      params: params,
      expiry: expiry,
    );
    String? code(Map<String, Object?> reply) =>
        (reply['error'] as Map<String, Object?>?)?['data'] as String?;
    setUp(() {
      now = DateTime.utc(2026, 10, 13);
      current = grant();
      router = WebRgbWalletConnectSession(
        wallet: wallet,
        grant: current!,
        currentGrant: () => current,
        clock: () => now,
        confirm: (p) async {
          prompts.add(p);
          return approve;
        },
        burn: WebRgbBurnOptions(
          operations: operations,
          allowedPayoutChainIds: ['eip155:42161'],
        ),
      );
    });
    tearDown(() => router.dispose());

    test(
      'enable, narrowed capabilities, witness and approved signing shapes',
      () async {
        expect(code(await call(1, 'getAddress')), 'NOT_ENABLED');
        expect((await call(2, 'enable'))['result'], isNull);
        expect((await call(3, 'signMessage', ['exact message']))['result'], {
          'signature': 'native-signature',
        });
        expect(wallet.signedMessages, ['exact message']);
        final witness = await call(4, 'witnessReceive', [
          {'amount': 5},
        ]);
        expect((witness['result'] as Map)['invoice'], 'rgb:invoice');
        expect(wallet.receivedMethod, 'witnessReceive');
        current = grant(methods: ['rgb_enable', 'rgb_getInfo']);
        final info = (await call(5, 'getInfo'))['result'] as Map;
        expect(info['methods'], ['enable', 'getInfo']);
        expect(info, isNot(contains('burnRecipientNamespaces')));
        expect(
          code(await call(6, 'signMessage', ['blocked'])),
          'METHOD_NOT_SUPPORTED',
        );
        expect(wallet.signedMessages, ['exact message']);
      },
    );

    test(
      'Tron namespaces and unchanged address survive RPC dispatch',
      () async {
        router.dispose();
        wallet.expectedBurnRecipient = _tronRecipient;
        router = WebRgbWalletConnectSession(
          wallet: wallet,
          grant: current!,
          currentGrant: () => current,
          clock: () => now,
          confirm: (prompt) async {
            prompts.add(prompt);
            return true;
          },
          burn: WebRgbBurnOptions(
            operations: operations,
            allowedPayoutChainIds: _tronChains,
          ),
        );
        await call(1, 'enable');
        final info = (await call(2, 'getInfo'))['result'] as Map;
        expect(info['burnRecipientNamespaces'], ['tron']);
        final burned = await call(3, 'burnAsset', [
          {
            'network': 'regtest',
            'assetId': _assetId,
            'amount': _args.amount,
            'burnRecipient': {
              'chainId': _tronChains.first,
              'address': _tronAddress,
            },
          },
        ]);
        expect(code(burned), isNull);
        expect((burned['result'] as Map)['burnRecipient'], {
          'chainId': _tronChains.first,
          'address': _tronAddress,
        });
        expect(wallet.burns, 1);
      },
    );

    test(
      'duplicates reuse one approval and reject changed arguments',
      () async {
        await call(1, 'enable');
        final first = call(2, 'signMessage', ['message']);
        final second = call(2, 'signMessage', ['message']);
        expect(await second, await first);
        expect(wallet.signedMessages, ['message']);
        expect(prompts.where((p) => p.method == 'signMessage'), hasLength(1));
        expect(code(await call(2, 'signMessage', ['other'])), 'INVALID_PARAMS');
        current = grant(methods: ['rgb_enable', 'rgb_getInfo']);
        expect(
          code(await call(2, 'signMessage', ['message'])),
          'METHOD_NOT_SUPPORTED',
        );
      },
    );

    test('host edits cannot corrupt a deduplicated signing reply', () async {
      await call(1, 'enable');
      final first = await call(2, 'signMessage', ['message']);
      (first['result'] as Map)['signature'] = 'replaced';
      final second = await call(2, 'signMessage', ['message']);
      expect((second['result'] as Map)['signature'], 'native-signature');
      expect(wallet.signedMessages, ['message']);
    });

    test(
      'expired active request does not reject the next queued request',
      () async {
        router.dispose();
        final gate = Completer<bool>();
        router = WebRgbWalletConnectSession(
          wallet: wallet,
          grant: current!,
          currentGrant: () => current,
          clock: () => now,
          confirm: (_) => gate.future,
        );
        await call(1, 'enable');
        final first = call(2, 'signMessage', [
          'expired',
        ], now.millisecondsSinceEpoch ~/ 1000 + 5);
        await Future<void>.delayed(Duration.zero);
        now = now.add(const Duration(seconds: 6));
        final next = call(3, 'getAddress');
        gate.complete(true);
        expect(code(await first), 'NOT_ENABLED');
        expect(code(await next), isNull);
        expect(wallet.signedMessages, isEmpty);
      },
    );

    test(
      'wrong network, method, arity and noninteger amounts never dispatch',
      () async {
        await call(1, 'enable');
        expect(
          code(
            await router.handle(
              id: 2,
              topic: 'session-topic',
              chainId: 'rgb:mainnet',
              method: 'rgb_signMessage',
              params: ['message'],
            ),
          ),
          'NOT_ENABLED',
        );
        expect(code(await call(3, 'sendAsset', [{}])), 'METHOD_NOT_SUPPORTED');
        expect(code(await call(4, 'signMessage', [])), 'INVALID_PARAMS');
        expect(
          code(
            await call(5, 'witnessReceive', [
              {'amount': 1.25},
            ]),
          ),
          'INVALID_PARAMS',
        );
        expect(wallet.signedMessages, isEmpty);
        expect(wallet.received, isNull);
      },
    );

    test(
      'input snapshots and in-flight disposal prevent later mutation',
      () async {
        await call(1, 'enable');
        final args = <Object?>['original'];
        final result = call(2, 'signMessage', args);
        args[0] = 'changed';
        expect(code(await result), isNull);
        expect(wallet.signedMessages, ['original']);
        router.dispose();
        expect(code(await call(3, 'signMessage', ['blocked'])), 'NOT_ENABLED');
        expect(wallet.signedMessages, ['original']);
      },
    );

    test('expiry while approval waits prevents signing', () async {
      router.dispose();
      final gate = Completer<bool>();
      router = WebRgbWalletConnectSession(
        wallet: wallet,
        grant: current!,
        currentGrant: () => current,
        clock: () => now,
        confirm: (_) => gate.future,
      );
      await call(1, 'enable');
      final result = call(2, 'signMessage', [
        'message',
      ], now.millisecondsSinceEpoch ~/ 1000 + 5);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 6));
      gate.complete(true);
      expect(code(await result), 'NOT_ENABLED');
      expect(wallet.signedMessages, isEmpty);
    });

    test('wallet switch and session disappearance revoke access', () async {
      await call(1, 'enable');
      current = grant(account: 'rgb:regtest:wallet-b');
      expect(code(await call(2, 'getAddress')), 'NOT_ENABLED');
      current = null;
      expect(code(await call(3, 'getInfo')), 'NOT_ENABLED');
    });

    test(
      'bounded IDs fail closed instead of evicting mutation results',
      () async {
        await call(0, 'enable');
        for (var id = 1; id < 256; id++) {
          expect(code(await call(id, 'getAddress')), isNull);
        }
        expect(
          code(await call(256, 'signMessage', ['must not sign'])),
          'INTERNAL_ERROR',
        );
        expect(wallet.signedMessages, isEmpty);
        expect(code(await call(1, 'getAddress')), isNull);
      },
    );

    test(
      'proof chunks are bounded, exact and require fresh session approval',
      () async {
        wallet.proof = base64Encode(List<int>.generate(50000, (i) => i % 256));
        await call(1, 'enable');
        final first =
            (await call(2, 'getConsignment', [
                  {'assetId': _assetId, 'txid': _txid},
                ]))['result']
                as Map;
        expect(base64Decode(first['data'] as String), hasLength(49152));
        expect(first['nextOffset'], 49152);
        final second =
            (await call(3, 'getConsignment', [
                  {'assetId': _assetId, 'txid': _txid, 'offset': 49152},
                ]))['result']
                as Map;
        expect(base64Decode(second['data'] as String), hasLength(848));
        expect(second['nextOffset'], isNull);
        expect(first['digest'], second['digest']);
        expect(
          prompts.where((p) => p.method == 'getConsignment'),
          hasLength(1),
        );
        expect(
          code(
            await call(4, 'getConsignment', [
              {'assetId': _assetId, 'txid': _txid, 'offset': 50000},
            ]),
          ),
          'INVALID_PARAMS',
        );
        router.dispose();
        expect(
          code(
            await call(5, 'getConsignment', [
              {'assetId': _assetId, 'txid': _txid, 'offset': 49152},
            ]),
          ),
          'NOT_ENABLED',
        );
      },
    );
  });

  test(
    'revoke then re-enable cannot authorize an old in-flight response',
    () async {
      final response = Completer<String>();
      wallet.address = () => response.future;
      final session = provider();
      final pending = session.getAddress();
      final assertion = expectLater(pending, _error('NOT_ENABLED'));
      session.revoke();
      await session.enable();
      response.complete('private wallet address');
      await assertion;
      expect(session.enabled, true);
    },
  );

  test('native errors are redacted rather than exposed to a dApp', () async {
    wallet.address = () async =>
        throw StateError('secret /wallet/path password=123');
    await expectLater(
      provider().getAddress(),
      throwsA(
        isA<WebRgbError>().having(
          (e) => e.toString(),
          'redacted',
          isNot(contains('password')),
        ),
      ),
    );
  });

  test(
    'blind receive approval shows effective confirmation floor and inputs',
    () async {
      final session = provider(burn: false);
      final received = await session.blindReceive(
        const WebRgbBlindReceiveArgs(
          assetId: _assetId,
          amount: 12,
          minConfirmations: 1,
        ),
      );
      expect(wallet.received!.minConfirmations, 3);
      expect(prompts.single.params['minConfirmations'], 3);
      expect(received.toJson()['invoice'], 'rgb:invoice');
      approve = false;
      await expectLater(session.blindReceive(), _error('USER_REJECTED'));
      await expectLater(
        session.blindReceive(const WebRgbBlindReceiveArgs(amount: 0)),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test(
    'balances reject JS precision loss; history preserves exact decimal amounts',
    () async {
      final session = provider();
      expect((await session.listAssets()).single.schema, 'bfa');
      expect((await session.getAssetBalance(_assetId)).balance, 42);
      wallet.amount = BigInt.parse('9007199254740992');
      await expectLater(
        session.getAssetBalance(_assetId),
        _error('INTERNAL_ERROR'),
      );
      final transfers = await session.listTransfers(_assetId);
      expect(transfers.first.amount, isNull);
      expect(transfers.first.amountBaseUnits, '9007199254740992');
      expect(transfers.first.toJson(), isNot(contains('amount')));
      expect(transfers.first.toJson(), isNot(contains('blockHeight')));
    },
  );

  test(
    'read result JSON follows the reviewed WebRGB field contracts',
    () async {
      final session = provider(burn: false);
      expect((await session.getAddress()).toJson(), {'address': 'bc1address'});
      expect((await session.getInfo()).toJson(), {
        'ready': true,
        'network': 'regtest',
        'protocol': 'RGB_LN',
        'methods': [...webRgbReadMethods, 'signMessage'],
      });
      expect((await session.listAssets()).single.toJson(), {
        'id': _assetId,
        'schema': 'bfa',
        'ticker': 'USDT',
        'name': 'Tether',
        'precision': 6,
      });
      expect((await session.getAssetBalance(_assetId)).toJson(), {
        'assetId': _assetId,
        'balance': 42,
        'raw': {
          'settled': 42,
          'future': 42,
          'spendable': 42,
          'offchainOutbound': 0,
          'offchainInbound': 0,
        },
      });
      final known = await session.getTransferStatus(9, _assetId);
      expect(known.toJson(), {
        'found': true,
        'status': 'Settled',
        'transfer': {
          'assetId': _assetId,
          'transferId': 9,
          'status': 'Settled',
          'kind': 'Burn',
          'amount': 42,
          'amountBaseUnits': '42',
          'txid': _txid,
        },
      });
      expect((await session.getTransferStatus('unknown')).toJson(), {
        'found': false,
        'status': null,
        'transfer': null,
      });
      await expectLater(
        session.getTransferStatus(''),
        _error('INVALID_PARAMS'),
      );
      await expectLater(
        session.getTransferStatus([]),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test(
    'invoice decoder preserves seconds, endpoints and unspecified amounts',
    () async {
      final session = provider();
      expect((await session.decodeRgbInvoice('rgb:invoice')).toJson(), {
        'assetId': _assetId,
        'amount': 42,
        'recipientId': 'recipient',
        'expirationTimestamp': 123,
        'network': 'regtest',
        'transportEndpoints': ['rpc://proxy.example'],
      });
      wallet.amount = BigInt.zero;
      expect((await session.decodeRgbInvoice('rgb:invoice')).amount, isNull);
      wallet.assignmentType = 'Any';
      wallet.amount = BigInt.one;
      expect((await session.decodeRgbInvoice('rgb:invoice')).amount, isNull);
      wallet.assignmentType = 'Fungible';
      wallet.amount = BigInt.from(-1);
      await expectLater(
        session.decodeRgbInvoice('rgb:invoice'),
        _error('INTERNAL_ERROR'),
      );
      wallet.amount = BigInt.parse('9007199254740992');
      await expectLater(
        session.decodeRgbInvoice('rgb:invoice'),
        _error('INTERNAL_ERROR'),
      );
      for (final invoice in ['', 'lnbc1', 'rgb:${'a' * 16384}']) {
        await expectLater(
          session.decodeRgbInvoice(invoice),
          _error('INVALID_PARAMS'),
        );
      }
    },
  );

  test(
    'host authorization expiry after consent prevents native work',
    () async {
      var active = true;
      final session = WebRgbProvider(
        wallet,
        WebRgbOptions(
          origin: 'https://mint.example',
          sessionApproved: true,
          assertAuthorized: () {
            if (!active) throw StateError('expired');
          },
          confirm: (_) async {
            active = false;
            return true;
          },
        ),
      );
      await expectLater(session.blindReceive(), _error('NOT_ENABLED'));
      expect(wallet.received, isNull);
      await expectLater(session.enable(), _error('NOT_ENABLED'));
      final disconnected = provider(approved: false);
      approve = false;
      await expectLater(disconnected.enable(), _error('USER_REJECTED'));
      approve = true;
      await disconnected.enable();
      wallet.disposed = true;
      expect(disconnected.enabled, false);
      await expectLater(disconnected.getInfo(), _error('NOT_ENABLED'));
    },
  );

  test('session origins and chain policies reject untrusted identities', () {
    for (final origin in [
      'file:///wallet',
      'https://user:pass@mint.example',
      'https://mint.example/path',
      'https://mint.example?token=secret',
      'https://mint.example#fragment',
    ]) {
      expect(() => provider(origin: origin), throwsA(isA<WebRgbError>()));
    }
    for (final chain in [
      'eip155:0',
      'eip155:1\n',
      'eip155:1\r',
      'eip155:1\r\n',
      'eip155:1\u2028',
      'eip155:1\u2029',
      'eip155:1\u0000',
      'eip155:1\t',
    ]) {
      expect(
        () => provider(allowedPayoutChainIds: [chain]),
        throwsA(isA<WebRgbError>()),
      );
    }
  });

  test(
    'burn preserves u64, journal ID is private, approval covers proof export',
    () async {
      final session = provider();
      final burned = await session.burnAsset(_args);
      expect(burned.amount, _args.amount);
      expect(burned.toJson().keys, isNot(contains('requestId')));
      expect(prompts.single.params['getConsignment'], true);
      final record = (await operations.records()).single;
      expect(record.state, BurnOperationState.complete);
      expect(burned.toJson().toString(), isNot(contains(record.id)));
      final proof = await session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
      );
      expect(proof.data, wallet.proof);
      expect(proof.byteLength, 3);
      // Independent published Keccak-256("abc") vector, not SHA3-256.
      expect(
        proof.digest,
        '0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45',
      );
      expect(prompts, hasLength(1));
    },
  );

  test(
    'wrong chain, network, asset and zero EVM recipient never burn',
    () async {
      final session = provider();
      for (final args in [
        const WebRgbBurnAssetArgs(
          network: 'mainnet',
          assetId: _assetId,
          amount: '1',
          burnRecipient: _payout,
        ),
        WebRgbBurnAssetArgs(
          network: 'regtest',
          assetId: _assetId,
          amount: '1',
          burnRecipient: BurnPayout(
            chainId: 'eip155:1',
            address: _payout.address,
          ),
        ),
        WebRgbBurnAssetArgs(
          network: 'regtest',
          assetId: _assetId,
          amount: '1',
          burnRecipient: BurnPayout(
            chainId: _payout.chainId,
            address: '0x${'0' * 40}',
          ),
        ),
      ]) {
        await expectLater(session.burnAsset(args), _error('INVALID_PARAMS'));
      }
      wallet.hasBfa = false;
      await expectLater(session.burnAsset(_args), _error('ASSET_NOT_FOUND'));
      expect(wallet.burns, 0);
      expect(store.data, isEmpty);
      expect(prompts, isEmpty);
    },
  );

  test(
    'native InvalidRequest becomes a sanitized WebRGB parameter error',
    () async {
      wallet.decodeFailure = mapNativeBridgeException(
        PlatformException(
          code: 'InvalidRequest',
          message: 'private invoice payload',
        ),
        operation: 'rlnDecodeRgbInvoice',
      );
      await expectLater(
        provider().decodeRgbInvoice('rgb:invalid'),
        _error('INVALID_PARAMS'),
      );
    },
  );

  test('unknown named assets fail before receive approval or mutation', () async {
    final session = provider();
    await expectLater(
      session.blindReceive(
        const WebRgbBlindReceiveArgs(assetId: 'rgb:unknown'),
      ),
      _error('ASSET_NOT_FOUND'),
    );
    await expectLater(
      session.getAssetBalance('rgb:unknown'),
      _error('ASSET_NOT_FOUND'),
    );
    expect(prompts, isEmpty);
    expect(wallet.received, isNull);
    // The no-asset invoice remains the supported way to receive a new contract.
    await session.blindReceive();
    expect(wallet.received!.assetId, isNull);
  });

  test('another wallet cannot reuse a burn journal', () {
    final other = _Wallet();
    expect(
      () => WebRgbProvider(
        other,
        WebRgbOptions(
          origin: 'https://mint.example',
          confirm: (_) async => true,
          burn: WebRgbBurnOptions(
            operations: operations,
            allowedPayoutChainIds: [_payout.chainId],
          ),
        ),
      ),
      throwsA(isA<WebRgbError>()),
    );
  });

  for (final phase in [
    BurnOperationState.prepared,
    BurnOperationState.pending,
  ]) {
    test('revoke during $phase cancels durably before native burn', () async {
      final session = provider();
      store.afterWrite = (record) async {
        if (record.state == phase) session.revoke();
      };
      await expectLater(session.burnAsset(_args), _error('NOT_ENABLED'));
      expect(wallet.burns, 0);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.cancelled,
      );
    });
  }

  test(
    'revoke during dispatched burn preserves result but withholds response',
    () async {
      final session = provider();
      wallet.burning = () async {
        session.revoke();
        return BurnResult(txid: _txid, batchTransferIdx: 42);
      };
      await expectLater(session.burnAsset(_args), _error('NOT_ENABLED'));
      expect(wallet.burns, 1);
      expect(
        (await operations.records()).single.state,
        BurnOperationState.complete,
      );
    },
  );

  test(
    'new sessions require proof consent, even after a same-origin burn',
    () async {
      await provider().burnAsset(_args);
      approve = false;
      await expectLater(
        provider().getConsignment(
          WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
        ),
        _error('USER_REJECTED'),
      );
      expect(prompts.last.method, 'getConsignment');
    },
  );

  test('proof export rejects non-burn, malformed and oversized data', () async {
    final session = provider();
    final args = WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid);
    wallet.transferKind = 'Send';
    await expectLater(session.getConsignment(args), _error('INVALID_PARAMS'));
    wallet.transferKind = 'Burn';
    for (final value in [
      '',
      '%AA',
      'YWJj\n',
      'A' * (((16 * 1024 * 1024 + 2) ~/ 3) * 4 + 1),
    ]) {
      wallet.proof = value;
      await expectLater(session.getConsignment(args), _error('INTERNAL_ERROR'));
    }
  });

  test('concurrent proof requests retain their own data and digests', () async {
    final session = provider();
    wallet.readingProof = (txid) async => txid == _txid ? 'YWJj' : 'BwgJ';
    final results = await Future.wait([
      session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: _txid),
      ),
      session.getConsignment(
        WebRgbGetConsignmentArgs(assetId: _assetId, txid: 'cd' * 32),
      ),
    ]);
    expect(results.map((result) => result.data), ['YWJj', 'BwgJ']);
    expect(results.first.digest, isNot(results.last.digest));
  });

  test(
    'burn status uses anchor height and responds to reorg without burning',
    () async {
      final session = provider();
      await session.burnAsset(_args);
      final status = await session.getTransferStatus(_txid);
      expect(status.transfer!.confirmations, 3);
      expect(status.transfer!.amount, isNull);
      expect(status.transfer!.amountBaseUnits, _args.amount);
      wallet.anchor = null;
      expect(
        (await session.getTransferStatus(_txid)).transfer!.confirmations,
        0,
      );
      final other = await provider(
        origin: 'https://other.example',
      ).getTransferStatus(_txid);
      expect(other.transfer!.burnRecipient, isNull);
      expect(wallet.burns, 1);
    },
  );
}
