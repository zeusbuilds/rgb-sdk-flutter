#!/usr/bin/env python3.13
"""One authorized 100-unit transfer to an actual mobile-generated witness invoice."""
import argparse, hashlib, json, subprocess, sys, time
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, ASSET, BIN, require, save


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--platform', choices=['ios', 'android'], required=True)
    parser.add_argument('--public-marker', type=Path, required=True)
    args = parser.parse_args()
    root = args.root
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets', 'Unowned qualification root.')
    marker = json.loads(args.public_marker.read_text())
    require(marker['assetId'] == ASSET and int(marker['amount']) == 100 and marker['invoice'].startswith('rgb:'), 'Mobile invoice scope changed.')
    built = load_verified_build()
    require(built['rustToolchain'] == '1.94.0' and built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest(), 'Unverified host client.')
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime()
    invoice_digest = hashlib.sha256(marker['invoice'].encode()).hexdigest()
    for previous in root.glob('mobile-' + args.platform + '-rgb*/scope.json'):
        require(json.loads(previous.read_text()).get('mobileInvoiceSha256') != invoice_digest,
                'This exact mobile invoice already has an intent; never fund it twice.')
    target = root / ('mobile-' + args.platform + '-rgb-' + invoice_digest[:8])
    target.mkdir(mode=0o700)
    save(target / 'scope.json', {**built, 'platform': args.platform, 'amountUnits': 100, 'assetId': ASSET,
         'mobileInvoiceSha256': hashlib.sha256(marker['invoice'].encode()).hexdigest(),
         'newMint': False, 'newFunding': False})
    label = 'mobile-' + args.platform + '-funding-' + invoice_digest[:8]
    steps = []

    def action(step, operation, **fields):
        request = {'root': str(root), 'wallet': 'sender', 'action': operation, **fields}
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout); save(target / (step + '.stderr.private.log'), response.stderr)
        require(response.returncode == 0, 'Native action failed at ' + step + '; do not repeat payment.')
        value = json.loads(response.stdout); save(target / (step + '.receipt.json'), value)
        steps.append(step); return value

    try:
        require(action('initial-audit', 'audit')['pending'] == [], 'Host sender has unresolved operation.')
        action('approved-command', 'command', label=label, kind='rgb', amount=100, invoice=marker['invoice'])
        prepared = action('prepare', 'prepare', label=label)
        require(prepared['phase'] == 'prepared' and not prepared['endAuthorized'], 'Mobile funding not prepared.')
        sent = action('commit-once', 'commit', label=label)
        require(sent['phase'] == 'accepted' and sent['txid'] == prepared['txid'], 'Native mobile funding not accepted.')
        require(action('restart-status', 'status', label=label) == sent, 'Funding identity changed on restart.')
        deadline = time.monotonic() + 45
        iteration = 0
        while sent['txid'] not in fixture.rpc(fixture.BTC, 'getrawmempool'):
            require(time.monotonic() < deadline, 'Mobile recipient has not broadcast; inspect exact original transfer only.')
            action('sender-observe-' + str(iteration), 'refresh')
            iteration += 1; time.sleep(1)
        save(target / 'confirmation.intent.json', {'txid': sent['txid'], 'blocks': 3})
        save(target / 'confirmation.receipt.json', fixture.mine(3))
        observed = fixture.rpc(fixture.BTC, 'getrawtransaction', [sent['txid'], True])
        require(observed['confirmations'] >= 3, 'Independent Core confirmation missing.')
        action('sender-confirmed', 'refresh')
        result = {'passed': True, 'platform': args.platform, 'amountUnits': 100, 'txid': sent['txid'],
                  'confirmations': observed['confirmations'], 'commitCalls': 1, 'steps': steps, **built,
                  'mobileInvoiceSha256': hashlib.sha256(marker['invoice'].encode()).hexdigest(),
                  'noMintOrFunding': True, 'gatesRemainClosed': True}
        save(target / 'FUNDING_RESULT.json', result); print(json.dumps(result))
    except Exception as error:
        save(target / 'STOPPED.json', {'passed': False, 'steps': steps, 'stoppedAt': str(error), 'automaticReplay': False})
        print(json.dumps({'passed': False, 'stoppedAt': str(error), 'evidence': str(target)})); raise SystemExit(1)


if __name__ == '__main__':
    main()
