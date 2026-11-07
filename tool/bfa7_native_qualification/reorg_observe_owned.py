#!/usr/bin/env python3.13
"""Observe only a previous case's exact owned blocks; never create/retry a payment."""
import argparse, fcntl, hashlib, json, os, subprocess, sys, time, urllib.request
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--authorize-owned-confirmation-loss', action='store_true')
    parser.add_argument('--prior-case', default='rgb-reorg-qualification-v1')
    parser.add_argument('--result-case', default='rgb-reorg-observation-v2')
    parser.add_argument('--command-label', default='rgb-reorg-v1')
    args = parser.parse_args()
    require(args.authorize_owned_confirmation_loss, 'Explicit owned-block reorg authorization required.')
    root = args.root.resolve()
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(), 'Unowned run.')
    require(all(1<=len(v)<=48 and all(c.islower() or c.isdigit() or c=='-' for c in v) for v in (args.prior_case,args.result_case,args.command_label)), 'Invalid owned case label.')
    previous = root / args.prior_case
    require((previous / 'RESULT.json').is_file(), 'Previous runner must have stopped and released its scope.')
    scope = json.loads((previous / 'scope.json').read_text())
    plan = json.loads((previous / 'owned-blocks.json').read_text())
    original = json.loads((previous / 'original-mempool.summary.json').read_text())
    submitted = json.loads((previous / 'commit-once.receipt.json').read_text())
    built = load_verified_build()
    require(scope['integrationTree'] == built['integrationTree'] and scope['baselineHeight'] >= 270,
            'Source/baseline differs from the original owned case.')
    target = root / args.result_case
    target.mkdir(mode=0o700)
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime()
    lock = os.open(FIXTURE / 'runtime/.issuer.lock', os.O_RDONLY | os.O_NOFOLLOW)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    txid, blocks = plan['txid'], plan['blocks']
    baseline, baseline_hash = scope['baselineHeight'], scope['baselineHash']
    require(fixture.rpc(fixture.BTC, 'getblockcount') == baseline + len(blocks), 'Unexpected chain advance.')
    require(fixture.rpc(fixture.BTC, 'getbestblockhash') == blocks[-1], 'Owned tip changed.')
    require(fixture.rpc(fixture.BTC, 'getblockhash', [baseline]) == baseline_hash, 'Old baseline changed.')
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Unrelated mempool exists.')
    for block in blocks:
        require(set(fixture.rpc(fixture.BTC, 'getblock', [block])['tx'][1:]) <= {txid}, 'Unowned block contents.')
    save(target / 'scope.json', {**built, 'runtimeIndexer': 'Electrum49702', 'independentAuthority': 'Core49743',
         'originalCase': previous.name, 'transaction': txid, 'ownedBlocks': blocks, 'baselineHeight': baseline,
         'baselineHash': baseline_hash, 'newFinancialCalls': 0, 'sourceSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
    observations = {}
    errors = []
    invalidation_attempted = False

    def action(step, wallet, operation):
        require(operation in {'status','balance','history','refresh','audit'}, 'Observation only.')
        request = {'root': str(root), 'wallet': wallet, 'action': operation,
                   **({'label':args.command_label} if operation == 'status' else {})}
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout)
        save(target / (step + '.stderr.private.log'), response.stderr)
        if response.returncode:
            return {'nativeActionFailed':True}
        value = json.loads(response.stdout)
        save(target / (step + '.receipt.json'), value)
        return value

    def wait_tip(height):
        for _ in range(60):
            try:
                if fixture.electrum_tip()['height'] == height:
                    return
            except Exception:
                pass
            time.sleep(.5)
        raise RuntimeError('Actual native Electrum indexer did not converge.')

    def snapshot(label):
        for wallet in ('receiver','sender'):
            refresh = action(label + '-' + wallet + '-refresh', wallet, 'refresh')
            balance = action(label + '-' + wallet + '-balance', wallet, 'balance')
            history = action(label + '-' + wallet + '-history', wallet, 'history')
            rows = [row for row in history.get('rgb', []) if row.get('txid') == txid]
            observations[label + '-' + wallet] = {'balance':balance.get('rgb'),
                'transactions':[{key:row.get(key) for key in ('idx','txid','status','kind','assignment','amount')} for row in rows],
                'nativeActionFailed':any(value.get('nativeActionFailed') for value in (refresh,balance,history))}
        observations[label + '-submission'] = action(label + '-submission','sender','status')
        save(target / (label + '.summary.json'), {key:value for key,value in observations.items() if key.startswith(label + '-')})

    try:
        current = action('original-accepted-receipt','sender','status')
        require(current == submitted, 'Exact original accepted receipt changed.')
        snapshot('confirmed')
        save(target / 'invalidate-owned.intent.json', {'firstBlock':blocks[0], 'preserveAllBlocksAtOrBelow':baseline})
        invalidation_attempted = True
        save(target / 'invalidate-owned.receipt.json', {'result':fixture.rpc(fixture.BTC,'invalidateblock',[blocks[0]])})
        require(fixture.rpc(fixture.BTC,'getbestblockhash') == baseline_hash, 'Old baseline changed.')
        require(set(fixture.rpc(fixture.BTC,'getrawmempool')) == {txid}, 'Unexpected mempool after owned rollback.')
        wait_tip(baseline)
        snapshot('lost-confirmations')
        raw = fixture.rpc(fixture.BTC,'getrawtransaction',[txid,True])
        require(raw.get('confirmations',0) == 0, 'Actual witness is still confirmed.')
        save(target / 'independent-zero-confirmation.json', {'txid':txid, 'confirmations':raw.get('confirmations',0),
             'coreHeight':fixture.rpc(fixture.BTC,'getblockcount'), 'electrum':fixture.electrum_tip()})
    except Exception as error:
        errors.append(str(error))
    finally:
        if invalidation_attempted:
            save(target / 'reconsider-owned.intent.json', {'firstBlock':blocks[0]})
            try:
                save(target / 'reconsider-owned.receipt.json', {'result':fixture.rpc(fixture.BTC,'reconsiderblock',[blocks[0]])})
                wait_tip(baseline + len(blocks))
                require(fixture.rpc(fixture.BTC,'getbestblockhash') == blocks[-1], 'Original owned tip was not restored.')
                require(fixture.rpc(fixture.BTC,'getblockhash',[baseline]) == baseline_hash, 'Original baseline changed.')
                require(fixture.rpc(fixture.BTC,'getrawmempool') == [], 'Unexpected final mempool.')
                snapshot('reconfirmed')
            except Exception as error:
                errors.append('Chain restore/check: ' + str(error))
        fcntl.flock(lock,fcntl.LOCK_UN);os.close(lock)
    lost = observations.get('lost-confirmations-receiver',{})
    before = original['original-mempool-receiver']
    stale_history = any(row.get('status') == 'Settled' for row in lost.get('transactions',[]))
    stale_balance = lost.get('balance') != before.get('balance')
    sender_lost=observations.get('lost-confirmations-sender',{})
    sender_stale=any(row.get('status')=='Settled' for row in sender_lost.get('transactions',[]))
    sender_stale_balance=sender_lost.get('balance')!=original['original-mempool-sender'].get('balance')
    receipts_same=(observations.get('confirmed-submission')==observations.get('lost-confirmations-submission')==observations.get('reconfirmed-submission'))
    result = {'passed':not errors and not stale_history and not stale_balance and not sender_stale and not sender_stale_balance and receipts_same,
         **built, 'transaction':txid,'newFinancialCalls':0,'errors':errors,
         'recipientStillSettledAtZeroConfirmations':stale_history,
         'recipientBalanceDiffersFromOriginalMempoolState':stale_balance,
         'senderStillSettledAtZeroConfirmations':sender_stale,'senderBalanceDiffersFromOriginalMempoolState':sender_stale_balance,
         'acceptedReceiptUnchangedThroughReorg':receipts_same,
         'nativeObservationFailed':bool(lost.get('nativeActionFailed')),
         'originalChainRestored':not any(e.startswith('Chain restore') for e in errors),
         'observations':observations,'gatesRemainClosed':True}
    save(target / 'RESULT.json', result)
    print(json.dumps({key:value for key,value in result.items() if key != 'observations'}))
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
