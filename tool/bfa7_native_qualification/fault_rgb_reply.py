#!/usr/bin/env python3.13
"""Drop one successful final consignment reply; recover only from exact reads."""
import argparse, email.parser, email.policy, hashlib, http.server, json, os, subprocess, sys, threading, urllib.error, urllib.request
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, ASSET, BIN, require, save


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--authorize-one-unit-send', action='store_true')
    args = parser.parse_args(); root = args.root
    require(args.authorize_one_unit_send, 'Explicit existing-asset qualification scope required.')
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(), 'Unowned run.')
    built = load_verified_build()
    require(built['rustToolchain'] == '1.94.0' and built['binarySha256'] == hashlib.sha256(BIN.read_bytes()).hexdigest(), 'Unverified host client.')
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime(); require(fixture.rpc(fixture.BTC, 'getrawmempool') == [], 'Coordinate pending fixture work first.')
    target = root / 'rgb-consignment-reply-loss'; target.mkdir(mode=0o700)
    save(target / 'scope.json', {**built, 'amountUnits': 1, 'assetId': ASSET, 'forwarder': '127.0.0.1:49890',
         'upstream': '127.0.0.1:49790', 'fault': 'Forward exact final consignment.post once, return malformed JSON after upstream accepted.',
         'newMint': False, 'newFunding': False})
    lock = threading.Lock(); state = {'methods': {}, 'consignmentPostsForwarded': 0, 'repeatedWritesBlocked': 0,
                                     'faultInjected': False, 'upstreamAccepted': False, 'transferId': None}
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    readonly = {'server.info', 'invoice.check', 'consignment.get', 'media.get', 'transfer.list', 'ack.get'}

    def checkpoint():
        temp = target / 'rpc-counts.json.tmp'
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(state, stream, indent=2); stream.flush(); os.fsync(stream.fileno())
        os.replace(temp, target / 'rpc-counts.json')

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def send(self, status, body, content_type='application/json'):
            self.send_response(status); self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
        def do_POST(self):
            if self.path != '/json-rpc': self.send(404, b'{}'); return
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size < 8 * 1024 * 1024: self.send(413, b'{}'); return
            body = self.rfile.read(size); content_type = self.headers.get('Content-Type', '')
            if content_type.startswith('multipart/form-data'):
                message = email.parser.BytesParser(policy=email.policy.default).parsebytes(
                    ('Content-Type: ' + content_type + '\r\nMIME-Version: 1.0\r\n\r\n').encode() + body)
                fields = {part.get_param('name', header='content-disposition'): part.get_payload(decode=True)
                          for part in message.iter_parts() if part.get_param('name', header='content-disposition') != 'file'}
                method = fields['method'].decode(); params = json.loads(fields['params'])
            else:
                request = json.loads(body); method = request['method']; params = request.get('params') or {}
            with lock:
                state['methods'][method] = state['methods'].get(method, 0) + 1
                # During outcome recovery, any accidental mutating proxy call is
                # recorded and refused. Observation uses the exact known record.
                if state.get('recoveryReadOnly') and method not in readonly:
                    state['repeatedWritesBlocked'] += 1; checkpoint(); self.send(503, b'{}'); return
                if method == 'consignment.post':
                    if state['consignmentPostsForwarded']:
                        state['repeatedWritesBlocked'] += 1; checkpoint(); self.send(503, b'{}'); return
                    state['consignmentPostsForwarded'] = 1
                    state['transferId'] = params['transfer_id']
                    state['consignmentRequestSha256'] = hashlib.sha256(body).hexdigest()
                checkpoint()  # Durable external-write marker before forwarding.
            try:
                request = urllib.request.Request('http://127.0.0.1:49790/json-rpc', data=body,
                                                 headers={'Content-Type': content_type}, method='POST')
                response = opener.open(request, timeout=15); result = response.read(8 * 1024 * 1024)
                if method == 'consignment.post':
                    parsed = json.loads(result)
                    with lock:
                        state['upstreamAccepted'] = response.status == 200 and parsed.get('error') is None and parsed.get('result') is True
                        state['faultInjected'] = True; checkpoint()
                    self.send(200, b'{deliberately lost original success reply')
                else:
                    self.send(response.status, result)
            except urllib.error.HTTPError as error:
                self.send(error.code, error.read(65536))
            except Exception:
                self.send(502, b'{}')

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 49890), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start(); steps = []

    def action(step, wallet, operation, **fields):
        request = {'root': str(root), 'wallet': wallet, 'action': operation,
                   'faultProxy': 'rgb-consignment-reply', **fields}
        save(target / (step + '.intent.json'), request)
        response = subprocess.run([str(BIN)], input=json.dumps(request).encode(), capture_output=True, timeout=120)
        save(target / (step + '.stdout.private.json'), response.stdout); save(target / (step + '.stderr.private.log'), response.stderr)
        require(response.returncode == 0, 'Native action failed at ' + step + '; preserve exact operation.')
        value = json.loads(response.stdout); save(target / (step + '.receipt.json'), value); steps.append(step); return value

    try:
        before_sender = action('sender-before', 'sender', 'balance')['rgb']['settled']
        before_receiver = action('receiver-before', 'receiver', 'balance')['rgb']['settled']
        invoice = action('unique-witness-invoice', 'receiver', 'receive', amount=1)['receive']['invoice']
        action('approved-command', 'sender', 'command', label='rgb-consignment-reply-loss', kind='rgb', amount=1, invoice=invoice)
        prepared = action('prepare-exact', 'sender', 'prepare', label='rgb-consignment-reply-loss')
        require(prepared['phase'] == 'prepared' and not prepared['endAuthorized'], 'Native RGB plan not prepared.')
        interrupted = action('commit-once-lost-reply', 'sender', 'commit', label='rgb-consignment-reply-loss')
        require(interrupted['phase'] == 'committing' and interrupted['endAuthorized'], 'Native End did not retain unknown outcome.')
        require(state['upstreamAccepted'] and state['consignmentPostsForwarded'] == 1, 'Successful actual final write not established.')
        require(prepared['txid'] not in fixture.rpc(fixture.BTC, 'getrawmempool'), 'Recipient was refreshed before proxy-only proof.')
        with lock:
            before_methods = dict(state['methods']); state['recoveryReadOnly'] = True; checkpoint()
        recovered = action('restart-status-read-only', 'sender', 'status', label='rgb-consignment-reply-loss')
        require(recovered['phase'] == 'accepted' and recovered['txid'] == prepared['txid'], 'Exact proxy evidence did not repair native SQL.')
        require(action('accepted-status-again', 'sender', 'status', label='rgb-consignment-reply-loss') == recovered, 'Native acceptance changed.')
        with lock:
            changed = {method: count - before_methods.get(method, 0) for method, count in state['methods'].items()
                       if count != before_methods.get(method, 0)}
            require(all(method in readonly for method in changed) and state['repeatedWritesBlocked'] == 0,
                    'Status attempted external mutation.')
            recovery_reads = changed; state['recoveryReadOnly'] = False; checkpoint()
        # Only after read-only recovery established submission do recipients
        # continue the ordinary acknowledgement and Bitcoin-broadcast protocol.
        action('recipient-observe', 'receiver', 'refresh'); action('sender-observe', 'sender', 'refresh')
        action('recipient-handoff', 'receiver', 'refresh')
        require(prepared['txid'] in fixture.rpc(fixture.BTC, 'getrawmempool'), 'Exact recovered witness not broadcast.')
        save(target / 'confirmation.intent.json', {'txid': recovered['txid'], 'blocks': 3})
        save(target / 'confirmation.receipt.json', fixture.mine(3))
        action('recipient-confirmed', 'receiver', 'refresh'); action('sender-confirmed', 'sender', 'refresh')
        sender = action('sender-final', 'sender', 'balance')['rgb']['settled']
        receiver = action('receiver-final', 'receiver', 'balance')['rgb']['settled']
        require(sender == before_sender - 1 and receiver == before_receiver + 1, 'Exact confirmed RGB movement differs.')
        require(action('final-native-audit', 'sender', 'audit')['pending'] == [], 'Native pending operation remains.')
        result = {'passed': True, **built, 'steps': steps, 'amountUnits': 1, 'txid': recovered['txid'],
                  'commitCalls': 1, 'commitReturnedPhase': interrupted['phase'], 'readOnlyRecoveryBeforeBroadcast': True,
                  'recoveryRpcMethods': recovery_reads, 'rpcCounts': dict(state),
                  'senderSettledUnits': sender, 'receiverSettledUnits': receiver, 'confirmations': 3,
                  'newMint': False, 'newFunding': False, 'mobileQualified': False, 'gatesRemainClosed': True}
        save(target / 'RESULT.json', result); print(json.dumps(result))
    except Exception as error:
        save(target / 'STOPPED.json', {'passed': False, 'steps': steps, 'stoppedAt': str(error),
             'rpcCounts': dict(state), 'automaticReplay': False})
        print(json.dumps({'passed': False, 'stoppedAt': str(error), 'evidence': str(target)})); raise SystemExit(1)
    finally:
        server.shutdown(); server.server_close()


if __name__ == '__main__':
    main()
