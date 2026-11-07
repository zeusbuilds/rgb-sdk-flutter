#!/usr/bin/env python3.13
"""Bind preserved proof to the final seal and run explicitly approved tiny sends."""
import argparse, hashlib, json, subprocess, sys
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--authorize-small-transfers', action='store_true')
    args = parser.parse_args()
    root = args.root
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(),
            'Not an existing owned run.')
    built = load_verified_build()
    manifest = json.loads((SDK / 'native/rgb_l1/source-manifest.json').read_text())
    require(built['rustToolchain'] == manifest['build']['rust'] == '1.94.0'
            and built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest()
            and built['sourceManifestSha256'] == hashlib.sha256((SDK / 'native/rgb_l1/source-manifest.json').read_bytes()).hexdigest(),
            'Host client does not match final sealed pinned-compiler build.')
    require(subprocess.run(['git', '-C', str(SDK / '.buildlog/bfa7-native/source'),
                           'diff', '--quiet', built['integrationTree']], capture_output=True).returncode == 0,
            'Prepared source differs from final seal.')
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime()
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Coordinate active fixture users first.')
    save(root / 'FINAL_SEALED_SCOPE.json', {**built, 'smallTransfersAuthorized': args.authorize_small_transfers,
         'newFunding': False, 'newMint': False, 'newContainers': False,
         'runnerSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
    steps = []

    def action(step, wallet, operation, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        save(root / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(root / (step + '.stdout.private.json'), response.stdout)
        save(root / (step + '.stderr.private.log'), response.stderr)
        require(response.returncode == 0, 'Native action failed at ' + step + '; do not replay.')
        value = json.loads(response.stdout); save(root / (step + '.receipt.json'), value)
        steps.append(step); return value

    def mine(step, txid):
        require(txid in fixture.rpc(fixture.BTC, 'getrawmempool'), 'Expected exact witness absent from mempool.')
        save(root / (step + '.intent.json'), {'txid': txid, 'blocks': 3})
        save(root / (step + '.receipt.json'), fixture.mine(3))
        observed = fixture.rpc(fixture.BTC, 'getrawtransaction', [txid, True])
        require(observed['confirmations'] >= 3, 'Independent Core confirmation missing.')
        return observed['confirmations']

    try:
        old_btc = json.loads((root / 'send-commit-once.receipt.json').read_text())
        old_rgb = json.loads((root / 'remedy-commit-once.receipt.json').read_text())
        require(action('sealed-old-btc-readback', 'sender', 'status', label='btc-send') == old_btc,
                'Existing accepted BTC identity changed.')
        require(action('sealed-old-rgb-readback', 'sender', 'status', label='rgb-send') == old_rgb,
                'Existing accepted RGB identity changed.')
        cancelled = action('sealed-old-cancellation-readback', 'sender', 'status', label='btc-cancel')
        require(cancelled['phase'] == 'rejected' and not cancelled['endAuthorized'], 'Cancellation certificate changed.')
        require(action('sealed-old-receipt-page', 'sender', 'receipts')['total'] == 2, 'Old receipts missing.')
        require(action('sealed-old-audit', 'sender', 'audit')['pending'] == [], 'Native operation still pending.')
        require(action('sealed-old-sender-balance', 'sender', 'balance')['rgb']['settled'] == 900, 'Sender baseline changed.')
        require(action('sealed-old-receiver-balance', 'receiver', 'balance')['rgb']['settled'] == 100, 'Receiver baseline changed.')
        if not args.authorize_small_transfers:
            save(root / 'FINAL_SEALED_READBACK.json', {'passed': True, 'steps': steps, **built,
                 'monetaryActions': False, 'mobileQualified': False, 'gatesRemainClosed': True})
            return
        address = json.loads((root / 'receiver-address.receipt.json').read_text())['address']
        action('sealed-btc-cancel-command', 'sender', 'command', label='sealed-btc-cancel', kind='bitcoin', amount=1000, address=address)
        plan = action('sealed-btc-cancel-prepare', 'sender', 'prepare', label='sealed-btc-cancel')
        require(plan['phase'] == 'prepared' and not plan['endAuthorized'], 'BTC prepare failed.')
        require(action('sealed-btc-cancel-restart', 'sender', 'status', label='sealed-btc-cancel')['txid'] == plan['txid'], 'Prepared BTC changed.')
        rejected = action('sealed-btc-cancel', 'sender', 'cancel', label='sealed-btc-cancel')
        require(rejected['phase'] == 'rejected' and not rejected['endAuthorized'], 'BTC cancellation failed.')
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Preparation/cancellation broadcast unexpectedly.')
        action('sealed-btc-command', 'sender', 'command', label='sealed-btc-send', kind='bitcoin', amount=1000, address=address)
        plan = action('sealed-btc-prepare', 'sender', 'prepare', label='sealed-btc-send')
        require(plan['phase'] == 'prepared' and not plan['endAuthorized'], 'Fresh BTC not prepared.')
        require(action('sealed-btc-restart', 'sender', 'status', label='sealed-btc-send')['txid'] == plan['txid'], 'BTC restart mismatch.')
        btc = action('sealed-btc-commit-once', 'sender', 'commit', label='sealed-btc-send')
        require(btc['phase'] == 'accepted' and btc['txid'] == plan['txid'], 'BTC not accepted.')
        require(action('sealed-btc-accepted-readback', 'sender', 'status', label='sealed-btc-send') == btc, 'BTC acceptance changed.')
        btc_conf = mine('sealed-btc-confirmation', btc['txid'])
        recipient = action('sealed-rgb-witness-invoice', 'receiver', 'receive', amount=50)['receive']
        action('sealed-rgb-command', 'sender', 'command', label='sealed-rgb-send', kind='rgb', amount=50, invoice=recipient['invoice'])
        plan = action('sealed-rgb-prepare', 'sender', 'prepare', label='sealed-rgb-send')
        require(plan['phase'] == 'prepared' and not plan['endAuthorized'], 'RGB not prepared.')
        require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'RGB preparation broadcast unexpectedly.')
        require(action('sealed-rgb-restart', 'sender', 'status', label='sealed-rgb-send')['txid'] == plan['txid'], 'RGB restart mismatch.')
        rgb = action('sealed-rgb-commit-once', 'sender', 'commit', label='sealed-rgb-send')
        require(rgb['phase'] == 'accepted' and rgb['txid'] == plan['txid'], 'RGB not accepted.')
        require(action('sealed-rgb-accepted-readback', 'sender', 'status', label='sealed-rgb-send') == rgb, 'RGB acceptance changed.')
        action('sealed-rgb-receiver-observe', 'receiver', 'refresh')
        action('sealed-rgb-sender-observe', 'sender', 'refresh')
        action('sealed-rgb-receiver-handoff', 'receiver', 'refresh')
        rgb_conf = mine('sealed-rgb-confirmation', rgb['txid'])
        action('sealed-rgb-receiver-confirmed', 'receiver', 'refresh')
        action('sealed-rgb-sender-confirmed', 'sender', 'refresh')
        sender = action('sealed-final-sender-balance', 'sender', 'balance')
        receiver = action('sealed-final-receiver-balance', 'receiver', 'balance')
        require(sender['rgb']['settled'] == 850 and receiver['rgb']['settled'] == 150, 'Exact final RGB balances differ.')
        require(receiver['btc']['vanilla']['settled'] == 2000, 'Exact cumulative BTC receipts differ.')
        require(action('sealed-final-audit', 'sender', 'audit')['pending'] == [], 'Native pending operation remains.')
        require(action('sealed-final-receipts', 'sender', 'receipts')['total'] == 4, 'Expected immutable accepted receipts missing.')
        result = {'passed': True, **built, 'steps': steps, 'btcSentSats': 1000, 'rgbSentUnits': 50,
                  'btcTxid': btc['txid'], 'rgbTxid': rgb['txid'], 'btcConfirmations': btc_conf,
                  'rgbConfirmations': rgb_conf, 'senderSettledUnits': 850, 'receiverSettledUnits': 150,
                  'newFunding': False, 'newMint': False, 'mobileQualified': False, 'gatesRemainClosed': True}
        save(root / 'FINAL_SEALED_RESULT.json', result); print(json.dumps(result))
    except Exception as error:
        result = {'passed': False, 'steps': steps, 'stoppedAt': str(error), 'automaticReplay': False}
        save(root / 'FINAL_SEALED_STOPPED.json', result); print(json.dumps(result)); raise SystemExit(1)


if __name__ == '__main__':
    main()
