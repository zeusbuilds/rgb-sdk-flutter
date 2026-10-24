import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

import 'utexo_wallet_test.dart' show FakeRlnHostApi;

const _operationId = '0123456789abcdef0123456789abcdef';
const _txid =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
late Directory _temporaryRoot;

class _RecoveryHost extends FakeRlnHostApi {
  String? accountXpubVanilla = 'xpub-van';
  String? accountXpubColored = 'xpub-col';
  int identityReads = 0;
  int shutdowns = 0;
  Completer<void>? identityEntered;
  Future<void>? identityGate;

  @override
  Future<RlnWireResponse> rlnNodeInfo(int nodeId) async {
    identityReads++;
    identityEntered?.complete();
    await identityGate;
    final base =
        jsonDecode((await super.rlnNodeInfo(nodeId)).json)
            as Map<String, dynamic>;
    return RlnWireResponse(
      json: jsonEncode({
        ...base,
        'accountXpubVanilla': accountXpubVanilla,
        'accountXpubColored': accountXpubColored,
      }),
    );
  }

  @override
  Future<void> rlnShutdown(int nodeId) async {
    shutdowns++;
    await super.rlnShutdown(nodeId);
  }

  Completer<void>? paymentGate;
  int prepares = 0;
  int commits = 0;
  int checks = 0;
  int cancels = 0;
  String? cancelledRequest;
  String? committedRequest;
  String? checkedRequest;
  String? preparedRequest;
  String response = '';
  Object? failure;
  Map<String, Object?> invoiceOverrides = {};
  String? storageDirPath;
  int invoiceDecodes = 0;
  bool initializeOutboxOnStatus = true;

  @override
  Future<RlnWireResponse> rlnDecodeRgbInvoice(
    int nodeId,
    String invoice,
  ) async {
    invoiceDecodes++;
    final base =
        jsonDecode((await super.rlnDecodeRgbInvoice(nodeId, invoice)).json)
            as Map<String, dynamic>;
    return RlnWireResponse(json: jsonEncode({...base, ...invoiceOverrides}));
  }

  @override
  Future<String> rlnPrepareOnchainSend(int nodeId, String requestJson) async {
    prepares++;
    preparedRequest = requestJson;
    await paymentGate?.future;
    if (failure != null) throw failure!;
    return response;
  }

  @override
  Future<String> rlnCommitOnchainSend(int nodeId, String requestJson) async {
    commits++;
    committedRequest = requestJson;
    await paymentGate?.future;
    if (failure != null) throw failure!;
    return response;
  }

  @override
  Future<String> rlnCancelOnchainSend(int nodeId, String requestJson) async {
    cancels++;
    cancelledRequest = requestJson;
    if (failure != null) throw failure!;
    return response;
  }

  @override
  Future<String> rlnOnchainSendStatus(int nodeId, String requestJson) async {
    checks++;
    checkedRequest = requestJson;
    if (failure != null) throw failure!;
    if (initializeOutboxOnStatus) {
      await Directory('$storageDirPath/durable-onchain-v1').create();
    }
    return response;
  }
}

Map<String, Object?> _status(
  RecoverableOnchainSendCommand command, {
  String phase = 'prepared',
  Map<String, Object?> overrides = const {},
}) => {
  'version': 1,
  'operationId': command.operationId,
  'fingerprint': phase == 'absent' ? null : command.fingerprint,
  'kind': phase == 'absent' ? null : command.kind.name,
  'phase': phase,
  'txid': ['prepared', 'committing', 'accepted'].contains(phase) ? _txid : null,
  'batchTransferIndex':
      command.kind == RecoverableOnchainSendKind.rgb &&
          ['prepared', 'committing', 'accepted'].contains(phase)
      ? 12
      : null,
  'failureCode': phase == 'rejected' ? 'native_prepare_rejected' : null,
  'endAuthorized': ['committing', 'accepted'].contains(phase),
  ...overrides,
};

Future<UtexoWallet> _wallet(
  _RecoveryHost host, {
  String? storageDirPath,
  String network = 'regtest',
  bool outbox = true,
  String? vssUrl,
  RlnOperationTimeoutPolicy operationTimeouts =
      const RlnOperationTimeoutPolicy(),
}) async {
  storageDirPath ??= _temporaryRoot.path;
  await Directory(storageDirPath).create(recursive: true);
  if (outbox) {
    await Directory('$storageDirPath/durable-onchain-v1').create();
  }
  host.storageDirPath = storageDirPath;
  final wallet = createAdvancedUtexoWallet(
    config: UtexoWalletConfig(
      storageDirPath: storageDirPath,
      network: network,
      vssUrl: vssUrl,
    ),
    client: RlnClient(hostApi: host),
    operationTimeouts: operationTimeouts,
  );
  await wallet.init(password: 'password');
  await wallet.unlock(
    password: 'password',
    config: UtexoUnlockConfig(
      bitcoindRpcHost: '127.0.0.1',
      bitcoindRpcUsername: 'user',
      bitcoindRpcPassword: 'password',
      bitcoindRpcPort: 18444,
    ),
  );
  return wallet;
}

Future<RecoverableOnchainSendCommand> _btc(UtexoWallet wallet) =>
    wallet.createRecoverableBtcSendCommand(
      operationId: _operationId,
      amount: 1500,
      address: 'bcrt1-test-destination',
      feeRate: 2,
    );

RecoverableOnchainSendCommand _legacyCommand(
  RecoverableOnchainSendCommand command,
  String path,
) {
  final request = Map<String, Object?>.from(
    (jsonDecode(command.requestJson) as Map<String, dynamic>)['request'] as Map,
  )..remove('fingerprint');
  final envelope = <String, Object?>{
    'version': 1,
    'network': command.network,
    'storageDirPath': path,
    'request': request,
  };
  request['fingerprint'] = sha256
      .convert(utf8.encode(jsonEncode(envelope)))
      .toString();
  return RecoverableOnchainSendCommand.fromJson(jsonEncode(envelope));
}

void main() {
  setUp(() async {
    _temporaryRoot = await Directory.systemTemp.createTemp('sdk-durable-send-');
    addTearDown(() => _temporaryRoot.delete(recursive: true));
  });

  test(
    'stable wallet identity preserves exact command across directory relocation',
    () async {
      final oldRoot = '${_temporaryRoot.path}/before-update';
      final newRoot = '${_temporaryRoot.path}/after-update';
      final first = await _wallet(_RecoveryHost(), storageDirPath: oldRoot);
      final original = await _btc(first);
      expect(original.version, 2);
      expect(original.storageDirPath, isNull);
      expect(original.walletBinding, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(original.requestJson.contains(oldRoot), isFalse);
      await first.shutdown();
      await Directory(oldRoot).rename(newRoot);
      final host = _RecoveryHost();
      final relocated = await _wallet(host, storageDirPath: newRoot);
      final restored = RecoverableOnchainSendCommand.fromJson(
        original.requestJson,
      );
      expect((await _btc(relocated)).requestJson, original.requestJson);
      for (final action in [
        relocated.onchainSendStatus,
        relocated.prepareOnchainSend,
        relocated.commitOnchainSend,
        relocated.cancelOnchainSend,
      ]) {
        host.response = jsonEncode(_status(restored));
        expect((await action(restored)).fingerprint, original.fingerprint);
      }
      final native = (jsonDecode(original.requestJson) as Map)['request'];
      for (final request in [
        host.checkedRequest,
        host.preparedRequest,
        host.committedRequest,
        host.cancelledRequest,
      ]) {
        expect(jsonDecode(request!), native);
      }
      expect(
        [host.checks, host.prepares, host.commits, host.cancels],
        [1, 1, 1, 1],
      );
      expect(await Directory(oldRoot).exists(), isFalse);
    },
  );

  for (final key in ['vanilla', 'colored']) {
    test(
      'stable wallet identity rejects a different $key account even with same path',
      () async {
        final original = await _btc(await _wallet(_RecoveryHost()));
        final host = _RecoveryHost();
        if (key == 'vanilla') host.accountXpubVanilla = 'different-vanilla';
        if (key == 'colored') host.accountXpubColored = 'different-colored';
        final different = await _wallet(host);
        final restored = RecoverableOnchainSendCommand.fromJson(
          original.requestJson,
        );
        for (final action in [
          different.onchainSendStatus,
          different.prepareOnchainSend,
          different.commitOnchainSend,
          different.cancelOnchainSend,
        ]) {
          await expectLater(
            action(restored),
            throwsA(isA<WalletValidationException>()),
          );
        }
        expect(
          [host.checks, host.prepares, host.commits, host.cancels],
          [0, 0, 0, 0],
        );
      },
    );
  }

  test(
    'legacy path-bound envelope remains exact and refuses relocation',
    () async {
      final first = await _wallet(_RecoveryHost());
      final legacy = _legacyCommand(await _btc(first), _temporaryRoot.path);
      final saved = legacy.requestJson;
      expect(legacy.version, 1);
      expect(legacy.walletBinding, isNull);
      final sameHost = _RecoveryHost();
      final same = await _wallet(sameHost);
      sameHost.response = jsonEncode(_status(legacy));
      await same.onchainSendStatus(legacy);
      expect(sameHost.checks, 1);
      final movedHost = _RecoveryHost();
      final moved = await _wallet(
        movedHost,
        storageDirPath: '${_temporaryRoot.path}/relocated',
      );
      for (final action in [
        moved.onchainSendStatus,
        moved.prepareOnchainSend,
        moved.commitOnchainSend,
        moved.cancelOnchainSend,
      ]) {
        await expectLater(
          action(legacy),
          throwsA(isA<WalletValidationException>()),
        );
      }
      expect(
        [
          movedHost.checks,
          movedHost.prepares,
          movedHost.commits,
          movedHost.cancels,
        ],
        [0, 0, 0, 0],
      );
      expect(legacy.requestJson, saved);
    },
  );

  for (final invalid in [null, '', ' key ', 'key\nvalue']) {
    test(
      'missing or malformed native account identity fails before outbox dispatch: $invalid',
      () async {
        final host = _RecoveryHost()..accountXpubColored = invalid;
        final wallet = await _wallet(host);
        await expectLater(
          _btc(wallet),
          throwsA(isA<NativeProtocolException>()),
        );
        expect(
          [host.checks, host.prepares, host.commits, host.cancels],
          [0, 0, 0, 0],
        );
      },
    );
  }

  test(
    'native identity loss after restore refuses every outbox action',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final restored = RecoverableOnchainSendCommand.fromJson(
        (await _btc(wallet)).requestJson,
      );
      host.accountXpubVanilla = null;
      for (final action in [
        wallet.onchainSendStatus,
        wallet.prepareOnchainSend,
        wallet.commitOnchainSend,
        wallet.cancelOnchainSend,
      ]) {
        await expectLater(
          action(restored),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      expect(
        [host.checks, host.prepares, host.commits, host.cancels],
        [0, 0, 0, 0],
      );
    },
  );

  test(
    'envelope versions and stable wallet binding are strict and fingerprint-bound',
    () async {
      final command = await _btc(await _wallet(_RecoveryHost()));
      for (final change in [
        'version',
        'walletBinding',
        'path',
        'unknown',
        'missingBinding',
      ]) {
        final envelope =
            jsonDecode(command.requestJson) as Map<String, dynamic>;
        switch (change) {
          case 'version':
            envelope['version'] = 3;
          case 'walletBinding':
            envelope['walletBinding'] = 'a' * 64;
          case 'path':
            envelope['storageDirPath'] = _temporaryRoot.path;
          case 'unknown':
            envelope['other'] = true;
          case 'missingBinding':
            envelope.remove('walletBinding');
        }
        expect(
          () => RecoverableOnchainSendCommand.fromJson(jsonEncode(envelope)),
          throwsA(isA<WalletValidationException>()),
          reason: change,
        );
      }
    },
  );

  test(
    'identity read and recovery dispatch hold the wallet lifecycle lease',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(_status(command));
      final gate = Completer<void>();
      host.identityGate = gate.future;
      host.identityEntered = Completer<void>();
      final checking = wallet.onchainSendStatus(command);
      await host.identityEntered!.future;
      final shuttingDown = wallet.shutdown();
      await Future<void>.delayed(Duration.zero);
      expect(host.shutdowns, 0);
      expect(host.checks, 0);
      gate.complete();
      await checking;
      await shuttingDown;
      expect(host.checks, 1);
      expect(host.shutdowns, 1);
    },
  );

  test(
    'restored commands never recreate a lost native outbox on any action',
    () async {
      final first = await _wallet(_RecoveryHost());
      final stored = (await _btc(first)).requestJson;
      await Directory(
        '${_temporaryRoot.path}/durable-onchain-v1',
      ).rename('${_temporaryRoot.path}/outbox-preserved');
      final host = _RecoveryHost();
      final reopened = await _wallet(host, outbox: false);
      final restored = RecoverableOnchainSendCommand.fromJson(stored);
      for (final action in [
        reopened.onchainSendStatus,
        reopened.prepareOnchainSend,
        reopened.commitOnchainSend,
        reopened.cancelOnchainSend,
      ]) {
        await expectLater(
          action(restored),
          throwsA(isA<RecoverableSendStorageException>()),
        );
      }
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 0],
      );
      expect(
        await Directory('${_temporaryRoot.path}/durable-onchain-v1').exists(),
        isFalse,
      );
      expect(
        await Directory('${_temporaryRoot.path}/outbox-preserved').exists(),
        isTrue,
      );
      expect(restored.requestJson, stored);
    },
  );

  for (final replacement in ['symlink', 'file']) {
    test(
      'restored $replacement outbox is rejected before native dispatch',
      () async {
        final host = _RecoveryHost();
        final wallet = await _wallet(host);
        final restored = RecoverableOnchainSendCommand.fromJson(
          (await _btc(wallet)).requestJson,
        );
        final directory = Directory(
          '${_temporaryRoot.path}/durable-onchain-v1',
        );
        await directory.rename('${_temporaryRoot.path}/outbox-preserved');
        if (replacement == 'symlink') {
          await Link(
            directory.path,
          ).create('${_temporaryRoot.path}/outbox-preserved');
        } else {
          await File(directory.path).writeAsString('not a directory');
        }
        for (final action in [
          wallet.onchainSendStatus,
          wallet.prepareOnchainSend,
          wallet.commitOnchainSend,
          wallet.cancelOnchainSend,
        ]) {
          await expectLater(
            action(restored),
            throwsA(isA<RecoverableSendStorageException>()),
          );
        }
        expect(
          [host.prepares, host.commits, host.checks, host.cancels],
          [0, 0, 0, 0],
        );
      },
    );
  }

  for (final replacement in ['missing', 'symlink']) {
    test('a $replacement wallet root cannot recreate recovery state', () async {
      final root = '${_temporaryRoot.path}/native-wallet';
      final host = _RecoveryHost();
      final wallet = await _wallet(host, storageDirPath: root);
      final restored = RecoverableOnchainSendCommand.fromJson(
        (await _btc(wallet)).requestJson,
      );
      await Directory(root).rename('${_temporaryRoot.path}/wallet-preserved');
      if (replacement == 'symlink') {
        await Link(root).create('${_temporaryRoot.path}/wallet-preserved');
      }
      for (final action in [
        wallet.onchainSendStatus,
        wallet.prepareOnchainSend,
        wallet.commitOnchainSend,
        wallet.cancelOnchainSend,
      ]) {
        await expectLater(
          action(restored),
          throwsA(isA<RecoverableSendStorageException>()),
        );
      }
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 0],
      );
      expect(
        await Directory('${_temporaryRoot.path}/wallet-preserved').exists(),
        isTrue,
      );
    });
  }

  test(
    'only first fresh status preflight initializes outbox; later loss stays fenced',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host, outbox: false);
      final command = await _btc(wallet);
      for (final action in [
        wallet.prepareOnchainSend,
        wallet.commitOnchainSend,
        wallet.cancelOnchainSend,
      ]) {
        await expectLater(
          action(command),
          throwsA(isA<RecoverableSendStorageException>()),
        );
      }
      host.response = jsonEncode(_status(command, phase: 'absent'));
      expect(
        (await wallet.onchainSendStatus(command)).phase,
        RecoverableOnchainSendPhase.absent,
      );
      expect(host.checks, 1);
      await Directory(
        '${_temporaryRoot.path}/durable-onchain-v1',
      ).rename('${_temporaryRoot.path}/outbox-preserved');
      for (final action in [
        wallet.onchainSendStatus,
        wallet.prepareOnchainSend,
        wallet.commitOnchainSend,
        wallet.cancelOnchainSend,
      ]) {
        await expectLater(
          action(command),
          throwsA(isA<RecoverableSendStorageException>()),
        );
      }
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 1, 0],
      );
    },
  );

  test(
    'failed first preflight cannot initialize again using the same object',
    () async {
      final host = _RecoveryHost()
        ..failure = const WalletException('Read failed.');
      final wallet = await _wallet(host, outbox: false);
      final command = await _btc(wallet);
      await expectLater(
        wallet.onchainSendStatus(command),
        throwsA(isA<WalletException>()),
      );
      host.failure = null;
      host.response = jsonEncode(_status(command, phase: 'absent'));
      await expectLater(
        wallet.onchainSendStatus(command),
        throwsA(isA<RecoverableSendStorageException>()),
      );
      expect(host.checks, 1);
      expect(
        await Directory('${_temporaryRoot.path}/durable-onchain-v1').exists(),
        isFalse,
      );
    },
  );

  test(
    'configured VSS rejects factories and all recovery actions before native calls',
    () async {
      final plain = await _wallet(_RecoveryHost());
      final command = await _btc(plain);
      final host = _RecoveryHost();
      final wallet = await _wallet(host, vssUrl: 'https://vss.invalid/vss');
      await expectLater(
        _btc(wallet),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      await expectLater(
        wallet.createRecoverableRgbSendCommand(
          operationId: _operationId,
          request: const RgbSendRequest(invoice: 'invoice', amount: 100),
        ),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      for (final candidate in [
        command,
        RecoverableOnchainSendCommand.fromJson(command.requestJson),
      ]) {
        for (final action in [
          wallet.onchainSendStatus,
          wallet.prepareOnchainSend,
          wallet.commitOnchainSend,
          wallet.cancelOnchainSend,
        ]) {
          await expectLater(
            action(candidate),
            throwsA(isA<UnsupportedWalletFeatureException>()),
          );
        }
      }
      expect(host.invoiceDecodes, 0);
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 0],
      );
    },
  );

  test('storage-loss diagnostics never contain paths or caller payloads', () {
    const error = RecoverableSendStorageException();
    expect(error.code, 'RECOVERABLE_SEND_STORAGE_LOST');
    expect(error.toJson().toString(), isNot(contains(_temporaryRoot.path)));
    expect(error.toString(), isNot(contains('durable-onchain-v1')));
  });
  test(
    'expired prepared RGB commit retains exact identity without authorizing End',
    () async {
      final host = _RecoveryHost()
        ..invoiceOverrides = {'expirationTimestamp': 1};
      final wallet = await _wallet(host);
      final command = await wallet.createRecoverableRgbSendCommand(
        operationId: _operationId,
        request: const RgbSendRequest(invoice: 'invoice', amount: 100),
      );
      host.response = jsonEncode(
        _status(
          command,
          phase: 'prepared',
          overrides: {'failureCode': 'invoice_expired'},
        ),
      );
      final result = await wallet.commitOnchainSend(command);
      expect(result.phase, RecoverableOnchainSendPhase.prepared);
      expect(result.failureCode, 'invoice_expired');
      expect(result.endAuthorized, isFalse);
      expect(result.txid, _txid);
      expect(result.batchTransferIndex, 12);
      expect(result.fingerprint, command.fingerprint);
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 1, 0, 0],
      );
    },
  );

  test(
    'timeless RGB invoice gets one concrete native-default expiry which restore retains',
    () async {
      final host = _RecoveryHost()
        ..invoiceOverrides = {'expirationTimestamp': null};
      final wallet = await _wallet(host);
      final before = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final command = await wallet.createRecoverableRgbSendCommand(
        operationId: _operationId,
        request: const RgbSendRequest(invoice: 'invoice', amount: 100),
      );
      final after = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final native = (jsonDecode(command.requestJson) as Map)['request'] as Map;
      expect(
        native['expirationTimestamp'],
        inInclusiveRange(before + 86400, after + 86400),
      );
      expect(
        RecoverableOnchainSendCommand.fromJson(command.requestJson).requestJson,
        command.requestJson,
      );
      expect(host.prepares + host.commits + host.checks + host.cancels, 0);
    },
  );

  test(
    'RGB native structural restrictions fail before app journal or prepare',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      for (final input in <Map<String, Object?>>[
        {'transportEndpoints': <String>[]},
        {
          'transportEndpoints': ['x' * 8001],
        },
        {'recipientId': 'r' * 4001},
        {'expirationTimestamp': 0},
      ]) {
        host.invoiceOverrides = input;
        await expectLater(
          wallet.createRecoverableRgbSendCommand(
            operationId: _operationId,
            request: const RgbSendRequest(invoice: 'invoice', amount: 100),
          ),
          throwsA(isA<WalletValidationException>()),
        );
      }
      host.invoiceOverrides = {};
      await expectLater(
        wallet.createRecoverableRgbSendCommand(
          operationId: _operationId,
          request: const RgbSendRequest(
            invoice: 'invoice',
            amount: 100,
            witnessAmountSat: 0,
          ),
        ),
        throwsA(isA<WalletValidationException>()),
      );
      expect(host.prepares + host.commits + host.checks + host.cancels, 0);
    },
  );

  test(
    'accepted operation restores across wallet wrapper restart with exact identity',
    () async {
      final first = await _wallet(_RecoveryHost());
      final stored = (await _btc(first)).requestJson;
      final host = _RecoveryHost();
      final reopened = await _wallet(host);
      final restored = RecoverableOnchainSendCommand.fromJson(stored);
      host.response = jsonEncode(_status(restored, phase: 'accepted'));
      final result = await reopened.onchainSendStatus(restored);
      expect(result.txid, _txid);
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 1, 0],
      );
      expect(host.lastSendBtc, isNull);
      expect(host.lastSendRgb, isNull);
    },
  );

  test(
    'malformed incomplete duplicate oversized and wrong-phase statuses stay unresolved',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      final missing = _status(command)..remove('txid');
      final samples = <String>[
        '{bad-json',
        'null',
        '[]',
        ' ' * 131073,
        jsonEncode(missing),
        jsonEncode(
          _status(command),
        ).replaceFirst('{"version":1,', '{"version":1,"version":1,'),
        jsonEncode(_status(command, overrides: {'txid': null})),
        jsonEncode(
          _status(
            command,
            phase: 'absent',
            overrides: {'fingerprint': command.fingerprint},
          ),
        ),
        jsonEncode(
          _status(
            command,
            phase: 'committing',
            overrides: {'endAuthorized': false},
          ),
        ),
        jsonEncode(
          _status(
            command,
            phase: 'rejected',
            overrides: {'endAuthorized': true},
          ),
        ),
        jsonEncode(
          _status(
            command,
            phase: 'accepted',
            overrides: {'failureCode': 'native_commit_failed'},
          ),
        ),
      ];
      for (final json in samples) {
        host.response = json;
        await expectLater(
          wallet.onchainSendStatus(command),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      expect([host.prepares, host.commits, host.cancels], [0, 0, 0]);
    },
  );

  test('invalid Bitcoin commands fail before native prepare', () async {
    final host = _RecoveryHost();
    final wallet = await _wallet(host);
    for (final amount in [0, -1]) {
      await expectLater(
        wallet.createRecoverableBtcSendCommand(
          operationId: _operationId,
          amount: amount,
          address: 'destination',
        ),
        throwsA(isA<WalletValidationException>()),
      );
    }
    for (final rate in [
      0.0,
      -1.0,
      1.5,
      double.nan,
      double.infinity,
      9223372036854775808.0,
    ]) {
      await expectLater(
        wallet.createRecoverableBtcSendCommand(
          operationId: _operationId,
          amount: 1,
          address: 'destination',
          feeRate: rate,
        ),
        throwsA(isA<WalletValidationException>()),
      );
    }
    for (final id in ['', 'ABCDEF0123456789ABCDEF0123456789', 'short']) {
      await expectLater(
        wallet.createRecoverableBtcSendCommand(
          operationId: id,
          amount: 1,
          address: 'destination',
        ),
        throwsA(isA<WalletValidationException>()),
      );
    }
    for (final address in ['', ' destination', 'destination\n']) {
      await expectLater(
        wallet.createRecoverableBtcSendCommand(
          operationId: _operationId,
          amount: 1,
          address: address,
        ),
        throwsA(isA<WalletValidationException>()),
      );
    }
    expect(host.prepares + host.commits + host.checks + host.cancels, 0);
  });

  test(
    'RGB accepted batch is authoritative but identity must be complete in every phase',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await wallet.createRecoverableRgbSendCommand(
        operationId: _operationId,
        request: const RgbSendRequest(invoice: 'invoice', amount: 100),
      );
      host.response = jsonEncode(_status(command));
      expect((await wallet.onchainSendStatus(command)).batchTransferIndex, 12);
      host.response = jsonEncode(
        _status(
          command,
          phase: 'accepted',
          overrides: {'batchTransferIndex': 99},
        ),
      );
      expect((await wallet.onchainSendStatus(command)).batchTransferIndex, 99);
      for (final overrides in [
        {'txid': null},
        {'batchTransferIndex': null},
      ]) {
        host.response = jsonEncode(_status(command, overrides: overrides));
        await expectLater(
          wallet.onchainSendStatus(command),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      host.response = jsonEncode(
        _status(command, phase: 'preparing', overrides: {'txid': _txid}),
      );
      await expectLater(
        wallet.onchainSendStatus(command),
        throwsA(isA<NativeProtocolException>()),
      );
      host.response = jsonEncode(
        _status(
          command,
          phase: 'preparing',
          overrides: {
            'txid': _txid,
            'batchTransferIndex': 12,
            'failureCode': 'native_sign_failed',
          },
        ),
      );
      expect((await wallet.onchainSendStatus(command)).endAuthorized, isFalse);
    },
  );

  test(
    'command construction is read-only and canonical envelope roundtrips',
    () async {
      final host = _RecoveryHost();
      final command = await _btc(await _wallet(host));
      expect(host.prepares + host.commits + host.checks, 0);
      expect(
        RecoverableOnchainSendCommand.fromJson(command.requestJson).requestJson,
        command.requestJson,
      );
      expect(command.fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(command.kind, RecoverableOnchainSendKind.bitcoin);
      expect(command.network, 'regtest');
    },
  );

  test('fingerprint changes for every binding and payment input', () async {
    final wallet = await _wallet(_RecoveryHost());
    final command = await _btc(wallet);
    final commands = [
      await wallet.createRecoverableBtcSendCommand(
        operationId: '1123456789abcdef0123456789abcdef',
        amount: 1500,
        address: 'bcrt1-test-destination',
        feeRate: 2,
      ),
      await wallet.createRecoverableBtcSendCommand(
        operationId: _operationId,
        amount: 1501,
        address: 'bcrt1-test-destination',
        feeRate: 2,
      ),
      await wallet.createRecoverableBtcSendCommand(
        operationId: _operationId,
        amount: 1500,
        address: 'bcrt1-other-destination',
        feeRate: 2,
      ),
      await wallet.createRecoverableBtcSendCommand(
        operationId: _operationId,
        amount: 1500,
        address: 'bcrt1-test-destination',
        feeRate: 3,
      ),
      await _btc(
        await _wallet(
          _RecoveryHost()..accountXpubColored = 'different-colored-xpub',
          storageDirPath: '${_temporaryRoot.path}/other-wallet',
        ),
      ),
      await _btc(await _wallet(_RecoveryHost(), network: 'signet')),
    ];
    expect(
      commands.map((value) => value.fingerprint).toSet().length,
      commands.length,
    );
    expect(
      commands.every((value) => value.fingerprint != command.fingerprint),
      isTrue,
    );
  });

  test(
    'private restore rejects mutations unknown keys duplicates and oversized input',
    () async {
      final command = await _btc(await _wallet(_RecoveryHost()));
      for (final mutation in [
        'amount',
        'network',
        'unknown',
        'extraWhitespace',
        'duplicate',
        'huge',
      ]) {
        final map = jsonDecode(command.requestJson) as Map<String, dynamic>;
        var json = command.requestJson;
        switch (mutation) {
          case 'amount':
            map['request']['amount'] = 1501;
            json = jsonEncode(map);
          case 'network':
            map['network'] = 'signet';
            json = jsonEncode(map);
          case 'unknown':
            map['request']['extra'] = true;
            json = jsonEncode(map);
          case 'extraWhitespace':
            json = '$json ';
          case 'duplicate':
            json = json.replaceFirst(
              '{"version":2,',
              '{"version":2,"version":2,',
            );
          case 'huge':
            json = ' ' * 131073;
        }
        expect(
          () => RecoverableOnchainSendCommand.fromJson(json),
          throwsA(isA<WalletValidationException>()),
          reason: mutation,
        );
      }
    },
  );

  test(
    'wallet and network mismatch are rejected without native dispatch',
    () async {
      final command = await _btc(await _wallet(_RecoveryHost()));
      final host = _RecoveryHost()
        ..accountXpubVanilla = 'different-vanilla-xpub';
      final other = await _wallet(
        host,
        storageDirPath: '${_temporaryRoot.path}/other-wallet',
      );
      for (final action in [
        other.prepareOnchainSend,
        other.commitOnchainSend,
        other.onchainSendStatus,
        other.cancelOnchainSend,
      ]) {
        await expectLater(
          action(command),
          throwsA(isA<WalletValidationException>()),
        );
      }
      expect(host.prepares + host.commits + host.checks, 0);
    },
  );

  test(
    'prepare commit and status each dispatch only their named operation',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(_status(command));
      expect(
        (await wallet.prepareOnchainSend(command)).phase,
        RecoverableOnchainSendPhase.prepared,
      );
      expect(
        jsonDecode(host.preparedRequest!),
        (jsonDecode(command.requestJson) as Map)['request'],
      );
      expect([host.prepares, host.commits, host.checks], [1, 0, 0]);
      host.response = jsonEncode(_status(command, phase: 'accepted'));
      final accepted = await wallet.commitOnchainSend(command);
      expect(accepted.txid, _txid);
      expect(
        jsonDecode(host.committedRequest!),
        (jsonDecode(command.requestJson) as Map)['request'],
      );
      expect(accepted.endAuthorized, isTrue);
      expect([host.prepares, host.commits, host.checks], [1, 1, 0]);
      await wallet.onchainSendStatus(command);
      expect(
        jsonDecode(host.checkedRequest!),
        (jsonDecode(command.requestJson) as Map)['request'],
      );
      expect([host.prepares, host.commits, host.checks], [1, 1, 1]);
    },
  );

  for (final phase in RecoverableOnchainSendPhase.values) {
    test(
      'strict valid ${phase.name} state decodes without other operations',
      () async {
        final host = _RecoveryHost();
        final wallet = await _wallet(host);
        final command = await _btc(wallet);
        host.response = jsonEncode(_status(command, phase: phase.name));
        expect((await wallet.onchainSendStatus(command)).phase, phase);
        expect([host.prepares, host.commits, host.checks], [0, 0, 1]);
      },
    );
  }

  test(
    'preparing may retain exact identity or failure with no End authorization',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(
        _status(
          command,
          phase: 'preparing',
          overrides: {'txid': _txid, 'failureCode': 'native_sign_failed'},
        ),
      );
      final result = await wallet.onchainSendStatus(command);
      expect(result.txid, _txid);
      expect(result.endAuthorized, isFalse);
      expect(result.failureCode, 'native_sign_failed');
    },
  );

  test(
    'RGB decoded before journal dispatch retains exact normalized native fields',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await wallet.createRecoverableRgbSendCommand(
        operationId: _operationId,
        request: const RgbSendRequest(
          invoice: 'invoice',
          amount: 100,
          feeRate: 2,
          witnessAmountSat: 1000,
          witnessBlinding: 123,
        ),
      );
      final request =
          (jsonDecode(command.requestJson) as Map)['request'] as Map;
      expect(request['assetId'], 'asset');
      expect(request['recipientId'], 'recipient');
      expect(request['transportEndpoints'], ['rpc://proxy/json-rpc']);
      expect(request['expirationTimestamp'], 4102444800);
      expect(host.prepares + host.commits, 0);
      host.response = jsonEncode(_status(command, phase: 'accepted'));
      final result = await wallet.onchainSendStatus(command);
      expect(result.batchTransferIndex, 12);
      expect(
        RecoverableOnchainSendCommand.fromJson(command.requestJson).fingerprint,
        command.fingerprint,
      );
    },
  );

  test(
    'RGB rejects missing amount donation skipSync mismatched invoice asset',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      for (final request in [
        const RgbSendRequest(invoice: 'invoice'),
        const RgbSendRequest(invoice: 'invoice', amount: 100, donation: true),
        const RgbSendRequest(invoice: 'invoice', amount: 100, assetId: 'other'),
      ]) {
        await expectLater(
          wallet.createRecoverableRgbSendCommand(
            operationId: _operationId,
            request: request,
          ),
          throwsA(isA<WalletValidationException>()),
        );
      }
      await expectLater(
        wallet.createRecoverableRgbSendCommand(
          operationId: _operationId,
          request: const RgbSendRequest(
            invoice: 'invoice',
            amount: 100,
            skipSync: true,
          ),
        ),
        throwsA(isA<UnsupportedWalletFeatureException>()),
      );
      expect(host.prepares + host.commits, 0);
    },
  );

  for (final override in <Map<String, Object?>>[
    {'version': 2},
    {'operationId': '1123456789abcdef0123456789abcdef'},
    {'fingerprint': 'a' * 64},
    {'kind': 'rgb'},
    {'phase': 'unknown'},
    {'endAuthorized': true},
    {'txid': 'invalid'},
    {'batchTransferIndex': 1},
    {
      'phase': 'accepted',
      'endAuthorized': true,
      'failureCode': 'native_commit_failed',
    },
    {'extra': true},
  ]) {
    test(
      'mismatched or contradictory status fails closed: $override',
      () async {
        final host = _RecoveryHost();
        final wallet = await _wallet(host);
        final command = await _btc(wallet);
        host.response = jsonEncode(_status(command, overrides: override));
        await expectLater(
          wallet.onchainSendStatus(command),
          throwsA(isA<NativeProtocolException>()),
        );
        expect([host.prepares, host.commits, host.checks], [0, 0, 1]);
      },
    );
  }

  test(
    'old native unsupported status never becomes absent or a one-shot fallback',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.failure = PlatformException(
        code: 'UnsupportedOperationException',
        message: 'No durable protocol',
        details: {
          'operation': 'rlnOnchainSendStatus',
          'category': 'unsupported',
          'retryable': false,
          'feature': 'recoverableOnchainSend',
        },
      );
      await expectLater(
        wallet.onchainSendStatus(command),
        throwsA(isA<RgbSdkException>()),
      );
      expect([host.prepares, host.commits, host.checks], [0, 0, 1]);
    },
  );

  test(
    'cancel sends full bound command and requires matching rejected tombstone',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(
        _status(
          command,
          phase: 'rejected',
          overrides: {'failureCode': 'cancelled'},
        ),
      );
      final status = await wallet.cancelOnchainSend(command);
      expect(status.phase, RecoverableOnchainSendPhase.rejected);
      expect(status.endAuthorized, isFalse);
      expect(status.fingerprint, command.fingerprint);
      expect(
        jsonDecode(host.cancelledRequest!),
        (jsonDecode(command.requestJson) as Map)['request'],
      );
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 1],
      );
    },
  );

  test(
    'cancellation cannot turn commit-authorized status into safe rejection',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(
        _status(
          command,
          phase: 'committing',
          overrides: {'failureCode': 'native_commit_failed'},
        ),
      );
      final status = await wallet.cancelOnchainSend(command);
      expect(status.phase, RecoverableOnchainSendPhase.committing);
      expect(status.endAuthorized, isTrue);
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 1],
      );
    },
  );

  test(
    'interrupted cancellation remains preparing and never authorizes End',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.response = jsonEncode(
        _status(
          command,
          phase: 'preparing',
          overrides: {'txid': _txid, 'failureCode': 'native_cancel_pending'},
        ),
      );
      final status = await wallet.cancelOnchainSend(command);
      expect(status.phase, RecoverableOnchainSendPhase.preparing);
      expect(status.endAuthorized, isFalse);
      expect(status.failureCode, 'native_cancel_pending');
      expect(
        [host.prepares, host.commits, host.checks, host.cancels],
        [0, 0, 0, 1],
      );
    },
  );

  for (final committing in [false, true]) {
    test(
      '${committing ? 'commit' : 'prepare'} deadline permits serialized exact inspection without releasing quarantine',
      () async {
        final host = _RecoveryHost();
        final wallet = await _wallet(
          host,
          operationTimeouts: const RlnOperationTimeoutPolicy(
            sendTimeout: Duration(milliseconds: 30),
          ),
        );
        final command = await _btc(wallet);
        host.response = jsonEncode(_status(command, phase: 'accepted'));
        host.paymentGate = Completer<void>();
        await expectLater(
          committing
              ? wallet.commitOnchainSend(command)
              : wallet.prepareOnchainSend(command),
          throwsA(isA<RlnOperationTimeoutException>()),
        );
        final identityReadsBefore = host.identityReads;
        final inspection = wallet.onchainSendStatus(command);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(host.identityReads, identityReadsBefore);
        expect(host.checks, 0);
        // The original native completion must precede both identity and status.
        host.paymentGate!.complete();
        final status = await inspection;
        expect(status.phase, RecoverableOnchainSendPhase.accepted);
        expect(
          host.checkedRequest,
          committing ? host.committedRequest : host.preparedRequest,
        );
        expect([
          host.prepares,
          host.commits,
          host.checks,
          host.cancels,
        ], committing ? [0, 1, 1, 0] : [1, 0, 1, 0]);
        await expectLater(wallet.syncWallet(), throwsA(isA<WalletError>()));
        await expectLater(
          wallet.prepareOnchainSend(command),
          throwsA(isA<WalletError>()),
        );
        expect([host.prepares, host.commits], committing ? [0, 1] : [1, 0]);
        // Explicit lifecycle recovery preserves the same private storage and
        // credentials. Only this shutdown/reopen/unlock restores mutations.
        await wallet.reinit(
          password: 'password',
          unlockConfig: UtexoUnlockConfig(
            bitcoindRpcHost: '127.0.0.1',
            bitcoindRpcUsername: 'user',
            bitcoindRpcPassword: 'password',
            bitcoindRpcPort: 18444,
          ),
        );
        await wallet.syncWallet();
        expect(wallet.isUnlocked, isTrue);
        expect(host.shutdowns, 1);
        expect([host.prepares, host.commits], committing ? [0, 1] : [1, 0]);
        await wallet.destroy();
      },
    );
  }

  for (final committing in [false, true]) {
    test(
      'RGB ${committing ? 'commit' : 'prepare'} deadline permits full decoded-intent validation before exact inspection',
      () async {
        final host = _RecoveryHost();
        final wallet = await _wallet(
          host,
          operationTimeouts: const RlnOperationTimeoutPolicy(
            sendTimeout: Duration(milliseconds: 30),
          ),
        );
        const request = RgbSendRequest(
          invoice: 'invoice',
          amount: 100,
          feeRate: 2,
        );
        final command = await wallet.createRecoverableRgbSendCommand(
          operationId: _operationId,
          request: request,
        );
        host.response = jsonEncode(_status(command, phase: 'accepted'));
        host.paymentGate = Completer<void>();
        await expectLater(
          committing
              ? wallet.commitOnchainSend(command)
              : wallet.prepareOnchainSend(command),
          throwsA(isA<RlnOperationTimeoutException>()),
        );
        final decodes = host.invoiceDecodes;
        final revalidation = wallet.createRecoverableRgbSendCommand(
          operationId: _operationId,
          request: request,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(host.invoiceDecodes, decodes);
        expect(host.checks, 0);
        host.paymentGate!.complete();
        final rebuilt = await revalidation;
        expect(rebuilt.requestJson, command.requestJson);
        final restored = RecoverableOnchainSendCommand.fromJson(
          command.requestJson,
        );
        final status = await wallet.onchainSendStatus(restored);
        expect(status.phase, RecoverableOnchainSendPhase.accepted);
        expect(status.batchTransferIndex, 12);
        expect([
          host.prepares,
          host.commits,
          host.checks,
          host.cancels,
        ], committing ? [0, 1, 1, 0] : [1, 0, 1, 0]);
        await expectLater(wallet.syncWallet(), throwsA(isA<WalletError>()));
        await wallet.destroy();
      },
    );
  }

  test(
    'inspection deadline while native is running never dispatches later',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(
        host,
        operationTimeouts: const RlnOperationTimeoutPolicy(
          defaultTimeout: Duration(milliseconds: 30),
          sendTimeout: Duration(milliseconds: 30),
        ),
      );
      final command = await _btc(wallet);
      host.response = jsonEncode(_status(command, phase: 'accepted'));
      host.paymentGate = Completer<void>();
      await expectLater(
        wallet.commitOnchainSend(command),
        throwsA(isA<RlnOperationTimeoutException>()),
      );
      final readsBefore = host.identityReads;
      await expectLater(
        wallet.onchainSendStatus(command),
        throwsA(isA<RlnOperationTimeoutException>()),
      );
      expect(host.identityReads, readsBefore);
      expect(host.checks, 0);
      host.paymentGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(host.identityReads, readsBefore);
      expect(host.checks, 0);
      final status = await wallet.onchainSendStatus(command);
      expect(status.phase, RecoverableOnchainSendPhase.accepted);
      expect(host.commits, 1);
      expect(host.cancels, 0);
      await wallet.destroy();
    },
  );

  test(
    'failed prepare is not retried and commit is never dispatched implicitly',
    () async {
      final host = _RecoveryHost();
      final wallet = await _wallet(host);
      final command = await _btc(wallet);
      host.failure = PlatformException(
        code: 'Internal',
        message: 'native failed',
      );
      await expectLater(
        wallet.prepareOnchainSend(command),
        throwsA(isA<RgbSdkException>()),
      );
      expect([host.prepares, host.commits, host.checks], [1, 0, 0]);
    },
  );
}
