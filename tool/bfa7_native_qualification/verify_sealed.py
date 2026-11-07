#!/usr/bin/env python3.13
"""Read an existing owned wallet under the current seal; never make a payment.

The earlier, explicitly authorized tiny-payment campaign remains in historical
evidence. This maintained successor helper intentionally exposes no funding,
mining, preparation, commit, cancellation, revocation or restoration operation.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from build import load_verified_build
from run import SDK, FIXTURE, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--case-label', required=True)
    parser.add_argument('--expected-sender-units', type=int, required=True)
    parser.add_argument('--expected-receiver-units', type=int, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets'
            and root.is_dir(), 'Not an existing owned run.')
    require(1 <= len(args.case_label) <= 48 and all(
        c in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in args.case_label),
        'Invalid evidence case label.')
    require(args.expected_sender_units >= 0 and args.expected_receiver_units >= 0,
            'Expected balances cannot be negative.')
    built = load_verified_build()
    target = root / args.case_label
    target.mkdir(mode=0o700)  # Refuse replay/overwriting earlier observations.
    sys.path.insert(0, str(FIXTURE))
    import fixture
    fixture.own_runtime()
    lock = os.open(FIXTURE / 'runtime/.issuer.lock', os.O_RDONLY | os.O_NOFOLLOW)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    steps = []

    def chain():
        return {'height': fixture.rpc(fixture.BTC, 'getblockcount'),
                'tip': fixture.rpc(fixture.BTC, 'getbestblockhash'),
                'mempool': fixture.rpc(fixture.BTC, 'getrawmempool')}

    def action(step, wallet, operation, **fields):
        require(operation in {'refresh', 'balance', 'audit', 'receipts', 'status-offline'},
                'This helper only admits observations.')
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(),
                                  capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout)
        save(target / (step + '.stderr.private.log'), response.stderr)
        require(response.returncode == 0, 'Native observation failed at ' + step + '; preserve evidence.')
        value = json.loads(response.stdout)
        save(target / (step + '.receipt.json'), value)
        steps.append(step)
        return value

    try:
        before = chain()
        require(before['mempool'] == [], 'Coordinate active fixture users first.')
        save(target / 'scope.json', {**built, 'case': args.case_label,
             'runnerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'initialChain': before, 'financialActions': False,
             'newContainers': False, 'resetExistingData': False})
        audit = action('initial-native-audit', 'sender', 'audit')
        require(audit['pending'] == [], 'Do not refresh an unresolved operation in this helper.')
        statuses = {}
        for label, phase in [('btc-send', 'accepted'), ('rgb-send', 'accepted'),
                             ('btc-cancel', 'rejected'),
                             ('rgb-ack-prepare-loss', 'rejected'),
                             ('rgb-ack-revoke-v3', 'rejected')]:
            status = action('historical-' + label, 'sender', 'status-offline', label=label)
            require(status['phase'] == phase, 'Historical outcome changed: ' + label)
            if phase == 'rejected':
                require(not status['endAuthorized'], 'Historical cancellation lost its certificate.')
            statuses[label] = status
        for label, filename in [('btc-send', 'send-commit-once.receipt.json'),
                                ('rgb-send', 'remedy-commit-once.receipt.json')]:
            require(statuses[label] == json.loads((root / filename).read_text()),
                    'Historical accepted identity changed: ' + label)
        receipts = action('initial-accepted-receipts', 'sender', 'receipts')
        balances = {}
        for wallet, expected in [('sender', args.expected_sender_units),
                                 ('receiver', args.expected_receiver_units)]:
            refreshed = action(wallet + '-one-healthy-refresh', wallet, 'refresh')['refresh']
            require(all(not entry.get('failure') for entry in refreshed.values()),
                    'Native refresh reported incomplete observations.')
            value = action(wallet + '-balance', wallet, 'balance')['rgb']
            require(all(value[key] == expected for key in ('settled', 'future', 'spendable')),
                    'Preserved fungible balance differs: ' + wallet)
            balances[wallet] = value
        final_audit = action('final-native-audit', 'sender', 'audit')
        require(final_audit['pending'] == [] and final_audit['cohort'] == audit['cohort'],
                'Native pending/cohort changed.')
        require(action('final-accepted-receipts', 'sender', 'receipts') == receipts,
                'Historical accepted receipt inventory changed.')
        after = chain()
        require(after == before, 'Observation campaign changed the chain or mempool.')
        result = {'passed': True, **built, 'case': args.case_label,
                  'steps': steps, 'balances': balances, 'pending': 0,
                  'historicalOutcomesVerified': len(statuses),
                  'acceptedReceipts': receipts['total'], 'chain': after,
                  'financialActions': False, 'newContainers': False,
                  'resetExistingData': False, 'gatesRemainClosed': True,
                  'scope': 'Current-seal host readback; historical fault campaigns retain their original source identities.'}
        save(target / 'RESULT.json', result)
        print(json.dumps(result))
    except Exception as error:
        save(target / 'STOPPED.json', {'passed': False, 'steps': steps,
             'stoppedAt': str(error), 'automaticReplay': False})
        raise
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        os.close(lock)


if __name__ == '__main__':
    main()
