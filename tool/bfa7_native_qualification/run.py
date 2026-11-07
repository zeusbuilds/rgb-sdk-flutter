#!/usr/bin/env python3.13
"""One fresh, non-retrying qualification run against the existing BFA.7 fixture."""
import argparse, datetime, fcntl, hashlib, importlib.util, json, os, subprocess, re
from pathlib import Path
from build import load_verified_build

SDK = Path(__file__).resolve().parents[2]
FIXTURE = Path('/Users/hardik/Projects/utexo-wdk-onchain-candidate/sdk-alpha12-funded-android/fixture')
ASSET = 'rgb:kOryemwN-I8Iutl8-otIPmDa-rn1cPTq-7VuhGvS-oe6oiMc'
CONTRACT_HASH = '189674bd83baa0a74c06f86d4652d896e7725f33285b9e25c8006b2087044cb0'
BIN = SDK / '.buildlog/bfa7-finalize/target-host/debug/flutter-bfa7-native-qualification'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def save(path, value):
    data = json.dumps(value, indent=2).encode() if not isinstance(value, bytes) else value
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute', action='store_true', help='Run real, tiny qualification transfers.')
    args = parser.parse_args()
    require(args.execute, 'Explicit --execute required; no action taken.')
    require(BIN.is_file(), 'Build the qualification client first.')
    manifest_file = SDK / 'native/rgb_l1/source-manifest.json'
    manifest = json.loads(manifest_file.read_text())
    source = SDK / '.buildlog/bfa7-finalize/source'
    tree = manifest['integration']['tree']
    require(subprocess.run(['git', '-C', str(source), 'diff', '--quiet', tree],
                           capture_output=True).returncode == 0, 'Sealed source tree changed.')
    sealed_lock = source / 'bindings/uniffi/Cargo.lock'
    require(hashlib.sha256(sealed_lock.read_bytes()).hexdigest() ==
            manifest['integration']['uniffiLockSha256'], 'Sealed native lock changed.')
    def package_ids(path):
        ids = set()
        for block in path.read_text().split('[[package]]')[1:]:
            fields = dict(re.findall(r'^(name|version|source|checksum) = "([^"\n]+)"$', block, re.M))
            ids.add(tuple(fields.get(k) for k in ('name', 'version', 'source', 'checksum')))
        return ids
    underlying = package_ids(sealed_lock)
    consumer = package_ids(Path(__file__).parent / 'Cargo.lock')
    require(consumer - underlying == {('flutter-bfa7-native-qualification', '0.1.0', None, None)},
            'Consumer dependency graph differs from sealed native source.')
    built = load_verified_build()
    require(built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest()
            and built['sourceManifestSha256'] == hashlib.sha256(manifest_file.read_bytes()).hexdigest()
            and built['integrationTree'] == tree
            and built['rustToolchain'] == manifest['build']['rust']
            and built['consumerLockSha256'] == hashlib.sha256((Path(__file__).parent / 'Cargo.lock').read_bytes()).hexdigest(),
            'Host qualification binary does not match the current sealed build.')
    spec = importlib.util.spec_from_file_location('fixture', FIXTURE / 'fixture.py')
    fixture = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixture)
    fixture.own_runtime()  # Read-only identities/network/proxy admission.
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Existing mempool is active; coordinate first.')
    lock = os.open(FIXTURE / 'runtime/.issuer.lock', os.O_RDONLY | os.O_NOFOLLOW)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    fcntl.flock(lock, fcntl.LOCK_UN)
    os.close(lock)
    contract = FIXTURE / 'runtime/issuer/public-contract.rgb'
    require(hashlib.sha256(contract.read_bytes()).hexdigest() == CONTRACT_HASH, 'Fixture contract changed.')
    parent = SDK / '.buildlog/bfa7-native/qualification-wallets'
    parent.mkdir(mode=0o700, exist_ok=True)
    os.chmod(parent, 0o700)
    run_id = datetime.datetime.now(datetime.timezone.utc).strftime('newrun-%Y%m%dT%H%M%SZ')
    root = parent / run_id
    root.mkdir(mode=0o700)
    steps = []
    save(root / 'scope.json', {'runId': run_id, 'fixture': str(FIXTURE), 'assetId': ASSET,
         'contractSha256': CONTRACT_HASH, 'binarySha256': hashlib.sha256(BIN.read_bytes()).hexdigest(),
         'backingChainId': 31337, 'newContainers': False, 'resetExistingData': False,
         'integrationTree': tree, 'sourceManifestSha256': hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
         'sourceLockSha256': hashlib.sha256(sealed_lock.read_bytes()).hexdigest(),
         'consumerLockSha256': hashlib.sha256((Path(__file__).parent / 'Cargo.lock').read_bytes()).hexdigest(),
         'sharedPackages': len(consumer & underlying), 'consumerOnlyPackage': 'flutter-bfa7-native-qualification'})

    def action(step, wallet, operation, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        # Every action gets an exclusive intent before invocation. Re-execution
        # cannot overwrite an uncertain attempt. This runner has no resume/retry.
        save(root / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(),
                                  capture_output=True, timeout=120)
        save(root / (step + '.stderr.private.log'), response.stderr)
        save(root / (step + '.stdout.private.json'), response.stdout)
        require(response.returncode == 0, 'Native action failed at ' + step + '; preserve exact intent.')
        value = json.loads(response.stdout)
        steps.append({'step': step, 'passed': True})
        save(root / (step + '.receipt.json'), value)
        return value

    def issuer(step, operation, payload):
        save(root / (step + '.intent.json'), {'operation': operation, 'payload': payload})
        response = subprocess.run(['python3', str(FIXTURE / 'issuer.py'), operation],
                                  input=json.dumps(payload).encode(), capture_output=True, timeout=120)
        save(root / (step + '.stderr.private.log'), response.stderr)
        save(root / (step + '.stdout.private.json'), response.stdout)
        require(response.returncode == 0, 'Issuer action failed at ' + step + '; never replay automatically.')
        value = json.loads(response.stdout)
        save(root / (step + '.receipt.json'), value)
        steps.append({'step': step, 'passed': True})
        return value

    try:
        start = {'btcHeight': fixture.rpc(fixture.BTC, 'getblockcount'),
                 'evmHeight': fixture.rpc(fixture.EVM, 'eth_blockNumber')}
        save(root / 'initial-chain.json', start)
        for wallet in ('sender', 'receiver'):
            action('init-' + wallet, wallet, 'init')
            imported = action('import-' + wallet, wallet, 'import', contractPath=str(contract))
            require(imported['assetId'] == ASSET and imported['metadata']['precision'] == 6
                    and imported['metadata']['assetSchema'] == 'Bfa'
                    and imported['metadata']['name'] == 'WDK L1 Qualification BFA'
                    and imported['metadata']['ticker'] == 'QBFA', 'Imported metadata mismatch.')
        sender = action('sender-address', 'sender', 'address')['address']
        recipient = action('receiver-address', 'receiver', 'address')['address']
        fund_label = 'flt7-' + hashlib.sha256(run_id.encode()).hexdigest()[:12]
        save(root / 'fund-sender.intent.json', {'address': sender, 'sats': 200000, 'label': fund_label})
        funded = fixture.fund(sender, 200000, fund_label)
        save(root / 'fund-sender.receipt.json', funded)
        steps.append({'step': 'fund-sender-200000-regtest-sats-and-mine3', 'passed': True})
        balance = action('funded-balance', 'sender', 'balance')
        require(balance['btc']['vanilla']['spendable'] == 200000, 'Initial funding not observed.')
        action('cancel-command', 'sender', 'command', label='btc-cancel', kind='bitcoin',
               amount=1000, address=recipient)
        prepared = action('cancel-prepare', 'sender', 'prepare', label='btc-cancel')
        require(prepared['phase'] == 'prepared' and prepared['endAuthorized'] is False, 'BTC preparation failed.')
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Prepare unexpectedly broadcast.')
        restarted = action('cancel-restart-status', 'sender', 'status', label='btc-cancel')
        require(restarted['phase'] == 'prepared' and restarted['txid'] == prepared['txid'], 'Prepared identity changed on restart.')
        cancelled = action('cancel-native', 'sender', 'cancel', label='btc-cancel')
        require(cancelled['phase'] == 'rejected' and not cancelled['endAuthorized'], 'Cancellation not authoritative.')
        terminal = action('cancel-late-commit', 'sender', 'commit', label='btc-cancel')
        require(terminal['phase'] == 'rejected' and fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Cancelled command replayed.')
        action('send-command', 'sender', 'command', label='btc-send', kind='bitcoin', amount=1000, address=recipient)
        planned = action('send-prepare', 'sender', 'prepare', label='btc-send')
        require(planned['phase'] == 'prepared', 'BTC send did not prepare.')
        read = action('send-restart-precommit', 'sender', 'status', label='btc-send')
        require(read['txid'] == planned['txid'] and read['phase'] == 'prepared', 'Precommit restart mismatch.')
        sent = action('send-commit-once', 'sender', 'commit', label='btc-send')
        require(sent['phase'] == 'accepted' and sent['txid'] == planned['txid'], 'BTC acceptance missing.')
        mempool = fixture.rpc(fixture.BTC, 'getrawmempool')
        require(mempool == [sent['txid']], 'Expected exactly one Bitcoin payment.')
        accepted = action('send-restart-status', 'sender', 'status', label='btc-send')
        require(accepted == sent, 'Accepted receipt changed on restart.')
        repeated = action('send-idempotent-accepted-commit', 'sender', 'commit', label='btc-send')
        require(repeated == sent and fixture.rpc(fixture.BTC, 'getrawmempool') == mempool, 'Accepted command replay changed transaction state.')
        save(root / 'btc-confirmation.receipt.json', fixture.mine(3))
        observed = action('btc-receiver-balance', 'receiver', 'balance')
        require(observed['btc']['vanilla']['settled'] == 1000, 'Receiver BTC not confirmed.')
        action('create-rgb-change-outputs', 'sender', 'outputs')
        save(root / 'outputs-confirmation.receipt.json', fixture.mine(3))
        incoming = action('witness-incoming', 'sender', 'receive', amount=1000)['receive']
        available = issuer('issuer-read-available-balance', 'balance', {'assetId': ASSET})
        if available['spendable'] < 1000:
            audit = action('final-native-audit-btc-only', 'sender', 'audit')
            require(audit['pending'] == [], 'BTC operation remains pending.')
            partial = {'passed': True, 'scope': 'funded BTC, exact contract registration and native witness receive',
                       'runId': run_id, 'walletStorage': str(root), 'steps': steps,
                       'btcSentSats': 1000, 'btcTxid': sent['txid'],
                       'rgbFundedTransfer': 'not run: existing issuer has no spendable QBFA',
                       'mobileQualified': False, 'gatesRemainClosed': True}
            save(root / 'BTC_RESULT.json', partial)
            print(json.dumps(partial))
            return
        issuer('issuer-send-tiny-qbfa', 'send', {'assetId': ASSET, 'amount': '1000', 'invoice': incoming['invoice']})
        action('receive-refresh', 'sender', 'refresh')
        issuer('issuer-refresh-after-send', 'refresh', {})
        # Proxy handoff can require sender and recipient refreshes, each of
        # which inspects the same existing transfer; no send action repeats.
        action('receive-observe', 'sender', 'refresh')
        save(root / 'rgb-incoming-confirmation.receipt.json', fixture.mine(3))
        action('receive-settle', 'sender', 'refresh')
        issuer('issuer-settle-after-send', 'refresh', {})
        balance = action('rgb-incoming-balance', 'sender', 'balance')
        require(balance['rgb']['settled'] == 1000 and balance['rgb']['spendable'] == 1000,
                'Incoming QBFA did not settle; preserve original transfer.')
        destination = action('witness-return', 'receiver', 'receive', amount=100)['receive']
        action('rgb-command', 'sender', 'command', label='rgb-send', kind='rgb', amount=100, invoice=destination['invoice'])
        rgb_plan = action('rgb-prepare', 'sender', 'prepare', label='rgb-send')
        require(rgb_plan['phase'] == 'prepared' and not rgb_plan['endAuthorized'], 'RGB did not prepare.')
        status = action('rgb-restart-precommit', 'sender', 'status', label='rgb-send')
        require(status['txid'] == rgb_plan['txid'] and status['phase'] == 'prepared', 'RGB prepared identity changed.')
        rgb_sent = action('rgb-commit-once', 'sender', 'commit', label='rgb-send')
        require(rgb_sent['phase'] == 'accepted' and rgb_sent['txid'] == rgb_plan['txid'], 'RGB did not accept.')
        accepted = action('rgb-restart-status', 'sender', 'status', label='rgb-send')
        require(accepted == rgb_sent, 'RGB receipt changed after restart.')
        action('rgb-recipient-refresh', 'receiver', 'refresh')
        action('rgb-sender-refresh', 'sender', 'refresh')
        action('rgb-recipient-observe', 'receiver', 'refresh')
        save(root / 'rgb-send-confirmation.receipt.json', fixture.mine(3))
        action('rgb-recipient-settle', 'receiver', 'refresh')
        action('rgb-sender-settle', 'sender', 'refresh')
        receiver_final = action('receiver-final-balance', 'receiver', 'balance')
        sender_final = action('sender-final-balance', 'sender', 'balance')
        require(receiver_final['rgb']['settled'] == 100 and sender_final['rgb']['settled'] == 900,
                'Final exact QBFA balances differ.')
        audit = action('final-native-audit', 'sender', 'audit')
        require(audit['pending'] == [], 'Native operation remains pending.')
        receipts = action('final-native-receipts', 'sender', 'receipts')
        require(receipts['total'] == 2, 'Expected exact BTC and RGB accepted native receipts.')
        result = {'passed': True, 'runId': run_id, 'walletStorage': str(root), 'steps': steps,
                  'assetId': ASSET, 'btcSentSats': 1000, 'rgbSentUnits': 100,
                  'btcTxid': sent['txid'], 'rgbTxid': rgb_sent['txid'],
                  'backingChainId': 31337, 'nativeSource': '9ec49c08be2e68f08521281e3efbd760ec989cb9',
                  'overlay': 'flutter-bfa7-durable-v1', 'platform': 'macOS native Rust',
                  'mobileQualified': False, 'gatesRemainClosed': True}
        save(root / 'RESULT.json', result)
        print(json.dumps(result))
    except Exception as error:
        result = {'passed': False, 'runId': run_id, 'walletStorage': str(root),
                  'completedSteps': steps, 'stoppedAt': str(error), 'automaticReplay': False}
        save(root / 'STOPPED.json', result)
        print(json.dumps(result))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
