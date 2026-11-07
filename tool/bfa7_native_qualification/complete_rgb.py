#!/usr/bin/env python3.13
"""Extend one completed owned BTC run with an approved existing-contract tiny mint."""
import argparse, concurrent.futures, datetime, hashlib, importlib.util, json, os, subprocess, sys, time
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, ASSET, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--allow-fixture-mint', action='store_true')
    args = parser.parse_args()
    require(args.allow_fixture_mint, 'Existing-contract test mint requires explicit scope.')
    root = args.root
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets'
            and root.is_dir() and not root.is_symlink(), 'Not an owned qualification run.')
    built = load_verified_build()
    manifest = SDK / 'native/rgb_l1/source-manifest.json'
    require(built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest()
            and built['sourceManifestSha256'] == hashlib.sha256(manifest.read_bytes()).hexdigest()
            and built['rustToolchain'] == json.loads(manifest.read_text())['build']['rust'],
            'Host client does not match the current sealed build.')
    btc = json.loads((root / 'BTC_RESULT.json').read_text())
    require(btc['passed'] is True and btc['btcSentSats'] == 1000, 'BTC scope incomplete.')
    require(not (root / 'RGB_SCOPE.json').exists(), 'RGB attempt exists; inspect its original status instead.')
    sys.path.insert(0, str(FIXTURE))
    import fixture
    fixture.own_runtime()
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Coordinate existing pending transactions first.')
    save(root / 'RGB_SCOPE.json', {'approved': 'Tiny mint of existing qualification QBFA; no deployment/reset',
         'assetId': ASSET, 'mintUnits': 1000, 'sendUnits': 100, 'backingChainId': 31337,
         'binarySha256': hashlib.sha256(BIN.read_bytes()).hexdigest(),
         'runnerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
         'nativeSource': '9ec49c08be2e68f08521281e3efbd760ec989cb9'})
    steps = []

    def action(step, wallet, operation, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        save(root / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(),
                                  capture_output=True, timeout=120)
        save(root / (step + '.stderr.private.log'), response.stderr)
        save(root / (step + '.stdout.private.json'), response.stdout)
        require(response.returncode == 0, 'Native action failed at ' + step + '; preserve exact intent.')
        value = json.loads(response.stdout)
        save(root / (step + '.receipt.json'), value)
        steps.append({'step': step, 'passed': True})
        return value

    def issuer(step, operation, payload=None, extra=()):
        save(root / (step + '.intent.json'), {'operation': operation, 'payload': payload, 'arguments': extra})
        response = subprocess.run(['python3', str(FIXTURE / 'issuer.py'), operation, *extra],
                                  input=None if payload is None else json.dumps(payload).encode(),
                                  capture_output=True, timeout=120)
        save(root / (step + '.stderr.private.log'), response.stderr)
        save(root / (step + '.stdout.private.json'), response.stdout)
        require(response.returncode == 0, 'Issuer action failed at ' + step + '; never replay automatically.')
        value = json.loads(response.stdout)
        save(root / (step + '.receipt.json'), value)
        steps.append({'step': step, 'passed': True})
        return value

    def field(row, camel, snake):
        return row[camel] if camel in row else row[snake]

    try:
        require(action('rgb-start-native-audit', 'sender', 'audit')['pending'] == [], 'Existing native send pending.')
        require(action('rgb-start-balance', 'sender', 'balance')['rgb']['settled'] == 0, 'Unexpected initial QBFA balance.')
        # Fixture issuer requires a blinded recipient for minting. This exercises
        # the SDK-only API; Aster remains witness-only and is not changed.
        receiver = action('mint-blind-recipient', 'sender', 'blind-receive-for-fixture-mint', amount=1000)['receive']
        prepared = issuer('mint-new-prepare', 'prepare', {'invoice': receiver['invoice'], 'amount': '1000'})
        action('mint-recipient-check', 'sender', 'refresh')
        pending = action('mint-recipient-lock-proof', 'sender', 'received-mint',
                         recipientId=field(receiver, 'recipientId', 'recipient_id'))['mint']
        require(pending is not None and pending['opid'] == prepared['opid']
                and field(pending, 'lockId', 'lock_id') == prepared['lockId']
                and int(pending['amount']) == 1000
                and int(field(pending, 'evmChainId', 'evm_chain_id')) == 31337
                and str(field(pending, 'beforeBlock', 'before_block')) == prepared['beforeBlock'],
                'Native recipient did not establish the exact mint lock.')
        # Only one settle/End invocation. Concurrent receive refreshes progress
        # the already authorised proxy handoff, never create or repeat a send.
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            settling = executor.submit(issuer, 'mint-new-settle-once', 'settle', None,
                                       (prepared['opid'], prepared['lockId']))
            for index in range(6):
                if settling.done():
                    break
                time.sleep(1)
                action('mint-release-observe-' + str(index), 'sender', 'refresh')
            settled = settling.result(timeout=120)
        require(settled['txid'] == prepared['witnessTxid'], 'Mint witness transaction identity changed.')
        action('mint-confirmed-refresh', 'sender', 'refresh')
        balance = action('mint-confirmed-balance', 'sender', 'balance')
        require(balance['rgb']['settled'] == balance['rgb']['spendable'] == 1000,
                'Fresh exact QBFA mint not settled; do not repeat.')
        destination = action('rgb-witness-recipient', 'receiver', 'receive', amount=100)['receive']
        action('rgb-approved-command', 'sender', 'command', label='rgb-send', kind='rgb', amount=100,
               invoice=destination['invoice'])
        plan = action('rgb-native-prepare', 'sender', 'prepare', label='rgb-send')
        require(plan['phase'] == 'prepared' and not plan['endAuthorized'], 'RGB not prepared.')
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'RGB prepare broadcast unexpectedly.')
        restarted = action('rgb-process-restart-status', 'sender', 'status', label='rgb-send')
        require(restarted['phase'] == 'prepared' and restarted['txid'] == plan['txid'], 'Restart changed RGB plan.')
        accepted = action('rgb-native-commit-once', 'sender', 'commit', label='rgb-send')
        require(accepted['phase'] == 'accepted' and accepted['txid'] == plan['txid'], 'RGB acceptance missing.')
        require(action('rgb-accepted-restart-status', 'sender', 'status', label='rgb-send') == accepted,
                'RGB acceptance changed after process restart.')
        action('rgb-recipient-refresh', 'receiver', 'refresh')
        action('rgb-sender-observe', 'sender', 'refresh')
        action('rgb-recipient-observe', 'receiver', 'refresh')
        require(accepted['txid'] in fixture.rpc(fixture.BTC, 'getrawmempool'), 'Exact RGB witness not in mempool.')
        save(root / 'rgb-confirmation.intent.json', {'txid': accepted['txid'], 'blocks': 3})
        save(root / 'rgb-confirmation.receipt.json', fixture.mine(3))
        action('rgb-recipient-confirmed', 'receiver', 'refresh')
        action('rgb-sender-confirmed', 'sender', 'refresh')
        incoming = action('rgb-final-receiver-balance', 'receiver', 'balance')
        outgoing = action('rgb-final-sender-balance', 'sender', 'balance')
        require(incoming['rgb']['settled'] == 100 and outgoing['rgb']['settled'] == 900,
                'Final exact QBFA balances differ.')
        audit = action('rgb-final-native-audit', 'sender', 'audit')
        require(audit['pending'] == [], 'Native send remains pending.')
        receipts = action('rgb-final-native-receipts', 'sender', 'receipts')
        require(receipts['total'] == 2, 'Expected immutable BTC/RGB native receipts.')
        result = {'passed': True, 'runId': root.name, 'steps': steps, 'mintUnits': 1000, 'rgbSentUnits': 100,
                  'mintTxid': settled['txid'], 'rgbTxid': accepted['txid'], 'btcTxid': btc['btcTxid'],
                  'receiverSettledUnits': 100, 'senderSettledUnits': 900, 'nativeSource': '9ec49c08be2e68f08521281e3efbd760ec989cb9',
                  'overlay': 'flutter-bfa7-durable-v1', 'platform': 'macOS native Rust',
                  'mobileQualified': False, 'gatesRemainClosed': True}
        save(root / 'RGB_RESULT.json', result)
        print(json.dumps(result))
    except Exception as error:
        result = {'passed': False, 'runId': root.name, 'completedSteps': steps,
                  'stoppedAt': str(error), 'automaticReplay': False}
        save(root / 'RGB_STOPPED.json', result)
        print(json.dumps(result))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
