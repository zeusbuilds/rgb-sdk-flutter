#!/usr/bin/env python3.13
"""Forward one exact real broadcast, lose its success reply, recover by reads."""
import argparse, hashlib, http.server, json, os, subprocess, sys, threading, urllib.error, urllib.request
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, BIN, require, save


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--reply-only', action='store_true', help='Allow immediate positive presence recovery.')
    parser.add_argument('--authorize-one-broadcast', action='store_true')
    args = parser.parse_args()
    root = args.root
    require(args.authorize_one_broadcast, 'Explicit one-broadcast qualification scope required.')
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(), 'Unowned run.')
    built = load_verified_build()
    require(built['rustToolchain'] == '1.94.0' and built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest(), 'Unverified host client.')
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime()
    require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Coordinate active fixture users first.')
    target = root / ('btc-reply-loss-immediate' if args.reply_only else 'btc-reply-loss-deferred')
    target.mkdir(mode=0o700)
    save(target / 'scope.json', {**built, 'amountSats': 1000, 'forwarder': '127.0.0.1:49894',
         'upstreamEsplora': '127.0.0.1:49794', 'newMint': False, 'newFunding': False,
         'fault': 'Forward one exact POST /tx successfully, replace reply with HTTP503; temporarily make exact-TX observations unavailable until Commit returns.'})
    lock = threading.Lock()
    counters = {'getRequests': 0, 'broadcastAttempts': 0, 'forwardedBroadcasts': 0,
                'repeatedBroadcastsBlocked': 0, 'upstreamAccepted': False, 'armedTxid': None,
                'observationsAvailable': args.reply_only, 'unavailableTxObservations': 0}
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def checkpoint():
        temp = target / 'rpc-counts.json.tmp'
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(counters, stream, indent=2); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp, target / 'rpc-counts.json')

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, status, body, content_type='text/plain'):
            self.send_response(status); self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)

        def do_GET(self):
            with lock:
                counters['getRequests'] += 1
                if (counters['armedTxid'] is not None and counters['forwardedBroadcasts'] == 1
                        and not counters['observationsAvailable']
                        and self.path.startswith('/tx/' + counters['armedTxid'])):
                    counters['unavailableTxObservations'] += 1; checkpoint()
                    self.send(503, b'Injected temporary unavailability of exact transaction observation'); return
                checkpoint()
            try:
                response = opener.open('http://127.0.0.1:49794' + self.path, timeout=15)
                self.send(response.status, response.read(8 * 1024 * 1024), response.headers.get('Content-Type', 'text/plain'))
            except urllib.error.HTTPError as error:
                self.send(error.code, error.read(65536))
            except Exception:
                self.send(502, b'Qualification read forwarding unavailable')

        def do_POST(self):
            if self.path != '/tx':
                self.send(405, b'Only exact qualified transaction broadcast is permitted'); return
            body = self.rfile.read(min(int(self.headers.get('Content-Length', '0')), 2 * 1024 * 1024))
            with lock:
                counters['broadcastAttempts'] += 1
                if counters['forwardedBroadcasts'] or counters['armedTxid'] is None:
                    counters['repeatedBroadcastsBlocked'] += 1; checkpoint()
                    self.send(503, b'Broadcast replay is blocked by qualification observer'); return
                parsed = fixture.rpc(fixture.BTC, 'decoderawtransaction', [body.decode('ascii')])
                if parsed['txid'] != counters['armedTxid']:
                    checkpoint(); self.send(409, b'Unapproved transaction identity'); return
                counters['forwardedBroadcasts'] = 1
                counters['rawTransactionSha256'] = hashlib.sha256(body).hexdigest()
                checkpoint()  # Durable dispatch marker before external mutation.
            try:
                response = opener.open(urllib.request.Request('http://127.0.0.1:49794/tx', data=body, method='POST'), timeout=15)
                actual_txid = response.read(1024).decode().strip()
                with lock:
                    counters['upstreamAccepted'] = response.status == 200 and actual_txid == counters['armedTxid']; checkpoint()
            except Exception:
                self.send(502, b'Upstream outcome unknown; broadcast will not repeat'); return
            # Original successful reply is intentionally not delivered. Esplora's
            # native broadcast API checks HTTP status but ignores a 200 body.
            self.send(503, b'Injected missing success acknowledgement after exact broadcast')

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 49894), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    steps = []

    def action(step, wallet, operation, fault=False, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation, **fields}
        if fault:
            request['faultIndexer'] = 'esplora-broadcast-reply'
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout); save(target / (step + '.stderr.private.log'), response.stderr)
        require(response.returncode == 0, 'Native action failed at ' + step + '; preserve exact operation.')
        value = json.loads(response.stdout); save(target / (step + '.receipt.json'), value)
        steps.append(step); return value

    try:
        address = action('fresh-recipient-address', 'receiver', 'address')['address']
        action('approved-command', 'sender', 'command', fault=True, label='btc-broadcast-observer-loss' if not args.reply_only else 'btc-reply-only', kind='bitcoin', amount=1000, address=address)
        prepared = action('prepare-exact', 'sender', 'prepare', fault=True, label='btc-broadcast-observer-loss' if not args.reply_only else 'btc-reply-only')
        require(prepared['phase'] == 'prepared' and not prepared['endAuthorized'], 'No exact native prepared plan.')
        with lock:
            require(counters['forwardedBroadcasts'] == 0, 'Prepare dispatched unexpectedly.')
            counters['armedTxid'] = prepared['txid']; checkpoint()
        interrupted = action('commit-once-lost-reply', 'sender', 'commit', fault=True, label='btc-broadcast-observer-loss' if not args.reply_only else 'btc-reply-only')
        require(interrupted['endAuthorized'] and (interrupted['phase'] == 'accepted' if args.reply_only
                else interrupted['phase'] == 'committing'), 'Fault did not establish expected recovery boundary.')
        with lock:
            counters['observationsAvailable'] = True; checkpoint()
        require(counters['upstreamAccepted'] and counters['forwardedBroadcasts'] == 1, 'Exact upstream broadcast not proved.')
        require(prepared['txid'] in fixture.rpc(fixture.BTC, 'getrawmempool'), 'Core did not observe actual broadcast.')
        # Only exact status calls follow the lost reply; Commit is not repeated.
        recovered = action('restart-status-read-only', 'sender', 'status', fault=True, label='btc-broadcast-observer-loss' if not args.reply_only else 'btc-reply-only')
        require(recovered['phase'] == 'accepted' and recovered['txid'] == prepared['txid'], 'Exact external proof did not repair native SQL.')
        require(action('accepted-status-again', 'sender', 'status', fault=True, label='btc-broadcast-observer-loss' if not args.reply_only else 'btc-reply-only') == recovered, 'Accepted receipt changed.')
        with lock:
            require(counters['broadcastAttempts'] == counters['forwardedBroadcasts'] == 1
                    and counters['repeatedBroadcastsBlocked'] == 0, 'Recovery attempted a broadcast retry.')
        save(target / 'confirmation.intent.json', {'txid': recovered['txid'], 'blocks': 3})
        save(target / 'confirmation.receipt.json', fixture.mine(3))
        observed = fixture.rpc(fixture.BTC, 'getrawtransaction', [recovered['txid'], True])
        require(observed['confirmations'] >= 3, 'Core confirmations missing.')
        require(action('final-native-audit', 'sender', 'audit')['pending'] == [], 'Native recovery fence retained.')
        result = {'passed': True, **built, 'steps': steps, 'txid': recovered['txid'], 'amountSats': 1000,
                  'commitCalls': 1, 'commitReturnedPhase': interrupted['phase'],
                  'statusRecoveredAfterActualBroadcast': recovered['phase'] == 'accepted', 'confirmations': observed['confirmations'],
                  'rpcCounts': dict(counters), 'noMonetaryRetry': True, 'newFunding': False, 'newMint': False,
                  'mobileQualified': False, 'gatesRemainClosed': True}
        save(target / 'RESULT.json', result); print(json.dumps(result))
    except Exception as error:
        save(target / 'STOPPED.json', {'passed': False, 'steps': steps, 'stoppedAt': str(error),
             'rpcCounts': dict(counters), 'automaticReplay': False})
        print(json.dumps({'passed': False, 'stoppedAt': str(error), 'evidence': str(target)})); raise SystemExit(1)
    finally:
        server.shutdown(); server.server_close()


if __name__ == '__main__':
    main()
