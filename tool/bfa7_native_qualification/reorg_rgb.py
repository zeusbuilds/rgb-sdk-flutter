#!/usr/bin/env python3.13
"""One owned RGB witness: live confirmation loss/reconfirmation, preserving old blocks."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.request
from build import load_verified_build
from run import SDK, FIXTURE, ASSET, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--authorize-one-unit-send-and-owned-block-reorg', action='store_true')
    parser.add_argument('--expected-baseline-height', type=int, required=True)
    parser.add_argument('--case-label', default='rgb-reorg-v2')
    args = parser.parse_args()
    require(args.authorize_one_unit_send_and_owned_block_reorg, 'Explicit bounded reorg scope required.')
    root = args.root.resolve()
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(), 'Unowned wallet run.')
    built = load_verified_build()
    sys.path.insert(0, str(FIXTURE))
    import fixture
    fixture.own_runtime()
    lock = os.open(FIXTURE / 'runtime/.issuer.lock', os.O_RDONLY | os.O_NOFOLLOW)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    label = args.case_label
    require(1<=len(label)<=32 and all(c.islower() or c.isdigit() or c=='-' for c in label), 'Invalid unique case label.')
    target = root / (label + '-qualification')
    target.mkdir(mode=0o700)
    steps = []
    baseline = fixture.rpc(fixture.BTC, 'getblockcount')
    require(baseline == args.expected_baseline_height and baseline >= 270, 'Coordinated baseline changed.')
    baseline_hash = fixture.rpc(fixture.BTC, 'getblockhash', [baseline])
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Unrelated mempool work exists.')
    save(target / 'scope.json', {**built, 'assetId': ASSET, 'amountUnits': 1,
         'baselineHeight': baseline, 'baselineHash': baseline_hash, 'preserveAllBlocksAtOrBelow': baseline,
         'newFunding': False, 'newMint': False, 'newOrResetContainers': False,
         'runtimeIndexer': 'Electrum49702', 'independentAuthority': 'Core49743',
         'sourceSha256':__import__('hashlib').sha256(Path(__file__).read_bytes()).hexdigest()})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    first_block = None
    txid = None
    invalidation_attempted = False
    observations = {}
    errors = []

    def action(step, wallet, operation, allow_failure=False, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout)
        save(target / (step + '.stderr.private.log'), response.stderr)
        if response.returncode:
            if allow_failure:
                value = {'nativeActionFailed': True}
                save(target / (step + '.receipt.json'), value)
                return value
            raise RuntimeError('Native action failed at ' + step + '; original state preserved.')
        value = json.loads(response.stdout)
        save(target / (step + '.receipt.json'), value)
        steps.append(step)
        return value

    def wait_tip(height):
        for _ in range(40):
            try:
                electrum = fixture.electrum_tip()['height']
                if electrum == height:
                    return
            except Exception:
                pass
            time.sleep(.5)
        raise RuntimeError('Existing indexers did not converge to the expected tip.')

    def snapshot(stage, allow_failure=False):
        for wallet in ('receiver', 'sender'):
            action(stage + '-' + wallet + '-refresh', wallet, 'refresh', allow_failure=allow_failure)
            balance = action(stage + '-' + wallet + '-balance', wallet, 'balance', allow_failure=allow_failure)
            history = action(stage + '-' + wallet + '-history', wallet, 'history', allow_failure=allow_failure)
            rows = [row for row in history.get('rgb', []) if row.get('txid') == txid]
            observations[stage + '-' + wallet] = {'balance': balance.get('rgb'),
                'transactions': [{key: row.get(key) for key in ('idx', 'batch_transfer_idx', 'txid', 'status', 'kind', 'assignment', 'amount')}
                                 for row in rows],
                'nativeActionFailed': bool(balance.get('nativeActionFailed') or history.get('nativeActionFailed'))}
        status = action(stage + '-accepted-receipt', 'sender', 'status', label=label, allow_failure=allow_failure)
        observations[stage + '-submission'] = status
        save(target / (stage + '.summary.json'), {key: value for key, value in observations.items() if key.startswith(stage + '-')})

    try:
        before_sender = action('sender-baseline-balance', 'sender', 'balance')['rgb']['settled']
        before_receiver = action('receiver-baseline-balance', 'receiver', 'balance')['rgb']['settled']
        require(action('sender-baseline-audit', 'sender', 'audit')['pending'] == [], 'Sender pending operation exists.')
        require(action('receiver-baseline-audit', 'receiver', 'audit')['pending'] == [], 'Receiver pending operation exists.')
        invoice = action('unique-witness-invoice', 'receiver', 'receive', amount=1)['receive']['invoice']
        action('approved-command', 'sender', 'command', label=label, kind='rgb', amount=1, invoice=invoice)
        prepared = action('prepare-exact', 'sender', 'prepare', label=label)
        require(prepared['phase'] == 'prepared' and not prepared['endAuthorized'], 'Plan was not prepared.')
        txid = prepared['txid']
        submitted = action('commit-once', 'sender', 'commit', label=label)
        require(submitted['phase'] == 'accepted' and submitted['txid'] == txid, 'Submission did not complete.')
        for i in range(8):
            action(f'handoff-{i}-receiver', 'receiver', 'refresh')
            action(f'handoff-{i}-sender', 'sender', 'refresh')
            pool = fixture.rpc(fixture.BTC, 'getrawmempool')
            require(set(pool) <= {txid}, 'Unrelated mempool transaction appeared; stop.')
            if txid in pool:
                break
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [txid], 'Expected unique witness not in mempool.')
        snapshot('original-mempool')
        require(all(len(observations['original-mempool-'+wallet]['transactions'])==1 for wallet in ('receiver','sender')), 'Exact native transfer identity missing.')
        save(target / 'mine-own-three.intent.json', {'txid': txid, 'count': 3, 'baseline': baseline_hash})
        blocks = fixture.mine(3)
        save(target / 'mine-own-three.receipt.json', blocks)
        require(fixture.rpc(fixture.BTC, 'getblockcount') == baseline + 3, 'Unexpected chain advance.')
        owned_blocks = [fixture.rpc(fixture.BTC, 'getblockhash', [h]) for h in range(baseline + 1, baseline + 4)]
        for block in owned_blocks:
            content = fixture.rpc(fixture.BTC, 'getblock', [block])
            require(set(content['tx'][1:]) <= {txid}, 'A new block contains an unrelated transaction.')
        first_block = owned_blocks[0]
        save(target / 'owned-blocks.json', {'blocks': owned_blocks, 'txid': txid})
        wait_tip(baseline + 3)
        snapshot('confirmed')
        require(observations['confirmed-receiver']['balance']['settled'] == before_receiver + 1, 'Original recipient settlement differs.')
        require(observations['confirmed-sender']['balance']['settled'] == before_sender - 1, 'Original sender settlement differs.')
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Unrelated mempool before reorg.')
        require(fixture.rpc(fixture.BTC, 'getbestblockhash') == owned_blocks[-1], 'Another actor changed the tip.')
        save(target / 'invalidate-only-owned-blocks.intent.json', {'firstBlock': first_block,
             'baselineHeight': baseline, 'baselineHash': baseline_hash, 'ownedBlocks': owned_blocks})
        invalidation_attempted = True
        response = fixture.rpc(fixture.BTC, 'invalidateblock', [first_block])
        save(target / 'invalidate-only-owned-blocks.receipt.json', {'result': response})
        require(fixture.rpc(fixture.BTC, 'getblockcount') == baseline, 'Baseline was not preserved.')
        require(fixture.rpc(fixture.BTC, 'getbestblockhash') == baseline_hash, 'Old baseline hash changed.')
        require(set(fixture.rpc(fixture.BTC, 'getrawmempool')) == {txid}, 'Unexpected post-reorg mempool.')
        wait_tip(baseline)
        snapshot('lost-confirmations', allow_failure=True)
        observed = fixture.rpc(fixture.BTC, 'getrawtransaction', [txid, True])
        try:
            esplora_status=json.loads(opener.open('http://127.0.0.1:49794/tx/' + txid + '/status',timeout=1).read())
        except Exception:
            esplora_status={'unavailable':True}
        require(observed.get('confirmations',0)==0,'Independent witness still confirmed.')
        save(target / 'independent-zero-confirmations.json', {'txid': txid, 'confirmations': observed.get('confirmations', 0),
             'coreHeight': baseline, 'electrum':fixture.electrum_tip(), 'esploraStatus':esplora_status})
    except Exception as error:
        errors.append(str(error))
    finally:
        if invalidation_attempted:
            save(target / 'restore-original-owned-blocks.intent.json', {'firstBlock': first_block, 'method': 'reconsiderblock'})
            try:
                response = fixture.rpc(fixture.BTC, 'reconsiderblock', [first_block])
                save(target / 'restore-original-owned-blocks.receipt.json', {'result': response})
                wait_tip(baseline + 3)
                require(fixture.rpc(fixture.BTC, 'getblockhash', [baseline]) == baseline_hash, 'Baseline changed during restore.')
                require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Restored chain has unexpected mempool work.')
                snapshot('reconfirmed', allow_failure=True)
            except Exception as error:
                errors.append('Chain restore/check failed: ' + str(error))
        fcntl.flock(lock, fcntl.LOCK_UN)
        os.close(lock)
    lost = observations.get('lost-confirmations-receiver', {})
    original = observations.get('original-mempool-receiver', {})
    stale_settled = any(row.get('status') == 'Settled' for row in lost.get('transactions', []))
    incorrect_balance = lost.get('balance') != original.get('balance')
    sender_lost=observations.get('lost-confirmations-sender',{})
    sender_stale=any(row.get('status')=='Settled' for row in sender_lost.get('transactions',[]))
    sender_incorrect=sender_lost.get('balance')!=observations.get('original-mempool-sender',{}).get('balance')
    receipt_unchanged=(observations.get('confirmed-submission')==observations.get('lost-confirmations-submission')==observations.get('reconfirmed-submission'))
    result = {'passed': not errors and not stale_settled and not incorrect_balance and not sender_stale and not sender_incorrect and receipt_unchanged,
        **built, 'amountUnits': 1, 'txid': txid, 'baselineHeight': baseline, 'baselineHash': baseline_hash,
        'commitCalls': 1, 'originalChainRestored': bool(invalidation_attempted and not any(e.startswith('Chain restore') for e in errors)),
        'recipientStillSettledAtZeroConfirmations': stale_settled,
        'recipientBalanceDiffersFromOriginalMempoolState': incorrect_balance,
        'senderStillSettledAtZeroConfirmations':sender_stale,'senderBalanceDiffersFromOriginalMempoolState':sender_incorrect,
        'acceptedReceiptUnchangedThroughReorg':receipt_unchanged,
        'observations': observations, 'errors': errors, 'newMint': False, 'newFunding': False,
        'mobileQualified': False, 'gatesRemainClosed': True}
    save(target / 'RESULT.json', result)
    print(json.dumps({key: value for key, value in result.items() if key != 'observations'}))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
