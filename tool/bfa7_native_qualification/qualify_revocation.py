#!/usr/bin/env python3.13
"""Final sealed partial dispatch, legacy-cancel race and explicit safe revocation."""
import argparse, email.parser, email.policy, fcntl, hashlib, http.server, json, os, subprocess, sys, threading, urllib.error, urllib.request
from pathlib import Path
from build import load_verified_build
from run import SDK, FIXTURE, ASSET, BIN, require, save


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--authorize-new-partial-and-explicit-revocation', action='store_true')
    parser.add_argument('--case-label',default='rgb-ack-revoke-v3')
    args = parser.parse_args(); root = args.root.resolve()
    require(args.authorize_new_partial_and_explicit_revocation, 'Explicit partial-dispatch scope required.')
    require(root.parent == SDK / '.buildlog/bfa7-native/qualification-wallets' and root.is_dir(), 'Unowned run.')
    built = load_verified_build()
    sys.path.insert(0, str(FIXTURE)); import fixture
    fixture.own_runtime()
    issuer_lock = os.open(FIXTURE / 'runtime/.issuer.lock', os.O_RDONLY | os.O_NOFOLLOW)
    fcntl.flock(issuer_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    require(fixture.rpc(fixture.BTC,'getrawmempool') == [], 'Unrelated mempool work exists.')
    case_label=args.case_label
    require(1<=len(case_label)<=32 and all(c.islower()or c.isdigit()or c=='-'for c in case_label),'Invalid unique operation label.')
    target = root / (case_label+'-qualification'); target.mkdir(mode=0o700)
    save(target / 'scope.json', {**built,'assetId':ASSET,'amountUnits':1,'newMint':False,'newFunding':False,
         'fault':'Forward exact ack.prepare once successfully, return malformed reply before any consignment.post.',
         'forwarder':'127.0.0.1:49890','upstream':'127.0.0.1:49790',
         'sourceSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()})
    state = {'methods':{},'ackPreparesForwarded':0,'consignmentPostsForwarded':0,'consignmentPostsBlocked':0,
             'repeatedWritesBlocked':0,'faultInjected':False,'upstreamAccepted':False,'recoveryReadOnly':False,'revocationMode':None,'revocationAttempts':0,'revocationsForwarded':0,'revocationAccepted':False}
    state_lock = threading.Lock()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    readonly = {'server.info','invoice.check','consignment.get','media.get','transfer.list','ack.get'}
    steps = []

    def checkpoint():
        path = target / 'rpc-counts.json.tmp'
        fd = os.open(path,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as file:
            json.dump(state,file,indent=2);file.flush();os.fsync(file.fileno())
        os.replace(path,target/'rpc-counts.json')

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def send(self,status,body):
            self.send_response(status);self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def do_POST(self):
            if self.path != '/json-rpc':self.send(404,b'{}');return
            size = int(self.headers.get('Content-Length','0'))
            if not 0 < size < 8*1024*1024:self.send(413,b'{}');return
            body=self.rfile.read(size);content_type=self.headers.get('Content-Type','')
            if content_type.startswith('multipart/form-data'):
                message=email.parser.BytesParser(policy=email.policy.default).parsebytes(
                    ('Content-Type: '+content_type+'\r\nMIME-Version: 1.0\r\n\r\n').encode()+body)
                fields={part.get_param('name',header='content-disposition'):part.get_payload(decode=True)
                        for part in message.iter_parts() if part.get_param('name',header='content-disposition')!='file'}
                method=fields['method'].decode();params=json.loads(fields['params'])
            else:
                request=json.loads(body);method=request['method'];params=request.get('params')or{}
            with state_lock:
                state['methods'][method]=state['methods'].get(method,0)+1
                if state['recoveryReadOnly'] and method not in readonly and not (method=='ack.clean' and state['revocationMode']):
                    state['repeatedWritesBlocked']+=1;checkpoint();self.send(503,b'{}');return
                if method=='ack.clean':
                    if not state['revocationMode'] or sorted(params.get('transfer_ids',[]))!=state['transferIds']:
                        state['repeatedWritesBlocked']+=1;checkpoint();self.send(503,b'{}');return
                    state['revocationAttempts']+=1
                    mode=state['revocationMode']
                    if mode in {'unknown','released','false','unavailable'}:
                        state.setdefault('simulatedRevocationResponses',[]).append(mode);checkpoint()
                        if mode=='unavailable':self.send(503,b'{}');return
                        response={'jsonrpc':'2.0','id':request.get('id') if content_type.startswith('application/json') else None,
                                  'result':False if mode=='false' else None,
                                  'error':None if mode=='false' else {'code':-104 if mode=='unknown' else -107,'message':'qualification injected outcome'}}
                        self.send(200,json.dumps(response).encode());return
                    if mode!='real' or state['revocationsForwarded']:
                        state['repeatedWritesBlocked']+=1;checkpoint();self.send(503,b'{}');return
                    state['revocationsForwarded']=1
                    state['revocationRequestSha256']=hashlib.sha256(body).hexdigest()
                if method=='consignment.post':
                    state['consignmentPostsBlocked']+=1;checkpoint();self.send(503,b'{}');return
                if method=='ack.prepare':
                    if state['ackPreparesForwarded']:
                        state['repeatedWritesBlocked']+=1;checkpoint();self.send(503,b'{}');return
                    state['ackPreparesForwarded']=1
                    state['transferIds']=sorted(params['transfer_data'])
                    state['prepareRequestSha256']=hashlib.sha256(body).hexdigest()
                checkpoint()
            try:
                response=opener.open(urllib.request.Request('http://127.0.0.1:49790/json-rpc',data=body,
                    headers={'Content-Type':content_type},method='POST'),timeout=15)
                result=response.read(8*1024*1024)
                if method=='ack.prepare':
                    parsed=json.loads(result)
                    with state_lock:
                        state['upstreamAccepted']=response.status==200 and parsed.get('error')is None and parsed.get('result')is True
                        state['faultInjected']=True;checkpoint()
                    self.send(200,b'{deliberately lost ack.prepare success reply')
                else:
                    if method=='ack.clean':
                        parsed=json.loads(result)
                        with state_lock:
                            state['revocationAccepted']=response.status==200 and parsed.get('error')is None and parsed.get('result')is True
                            checkpoint()
                    self.send(response.status,result)
            except urllib.error.HTTPError as error:self.send(error.code,error.read(65536))
            except Exception:self.send(502,b'{}')

    server=http.server.ThreadingHTTPServer(('127.0.0.1',49890),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()

    def action(step,wallet,operation,**fields):
        request={'root':str(root),'wallet':wallet,'action':operation,'faultProxy':'rgb-consignment-reply',**fields}
        save(target/(step+'.intent.json'),request)
        response=subprocess.run([str(BIN)],input=json.dumps(request).encode(),capture_output=True,timeout=120)
        save(target/(step+'.stdout.private.json'),response.stdout);save(target/(step+'.stderr.private.log'),response.stderr)
        require(response.returncode==0,'Native action failed at '+step+'; preserve original operation.')
        value=json.loads(response.stdout);save(target/(step+'.receipt.json'),value);steps.append(step);return value

    try:
        require(action('initial-native-audit','sender','audit')['pending']==[],'Native pending operation exists.')
        before_balance=action('sender-before','sender','balance')['rgb']
        original_cancel=action('original-v1-cancel-certificate-readback','sender','status',label='rgb-ack-prepare-loss')
        require(original_cancel['phase']=='rejected' and original_cancel['failureCode']=='cancelled' and not original_cancel['endAuthorized'],'Old exact v1 cancellation certificate did not reopen.')
        invoice=action('unique-witness-invoice','receiver','receive',amount=1)['receive']['invoice']
        action('approved-command','sender','command',label=case_label,kind='rgb',amount=1,invoice=invoice)
        prepared=action('prepare-exact','sender','prepare',label=case_label)
        require(prepared['phase']=='prepared' and not prepared['endAuthorized'],'Exact plan not prepared.')
        stale_observation=action('check-observed-prepared','sender','status',label=case_label)
        require(stale_observation['phase']=='prepared' and not stale_observation['endAuthorized'],'Predispatch Check observation changed.')
        interrupted=action('commit-once-partial-dispatch','sender','commit',label=case_label)
        require(interrupted['phase']=='committing' and interrupted['endAuthorized'],'Unknown partial dispatch not retained.')
        require(state['upstreamAccepted'] and state['ackPreparesForwarded']==1 and state['consignmentPostsForwarded']==0,
                'Required real partial-dispatch boundary was not established.')
        require(fixture.rpc(fixture.BTC,'getrawmempool')==[],'Unexpected Bitcoin broadcast.')
        with state_lock:
            state['recoveryReadOnly']=True;before=dict(state['methods']);checkpoint()
        recovered=action('restart-status-read-only','sender','status',label=case_label)
        cancel=action('queued-legacy-cancel-after-dispatch','sender','cancel',label=case_label)
        require(recovered['phase']=='committing' and cancel['phase']=='committing','Current boundary changed; inspect original receipts.')
        with state_lock:
            changed={method:count-before.get(method,0) for method,count in state['methods'].items() if count!=before.get(method,0)}
            require(all(method in readonly for method in changed) and state['repeatedWritesBlocked']==0,'Recovery attempted mutation.')
        audit=action('final-pending-audit','sender','audit')
        require(len(audit['pending'])==1 and audit['pending'][0]['txid']==prepared['txid'],'Exact native pending fence missing.')
        negative=[]
        for mode in ('unknown','released','false','unavailable'):
            with state_lock:state['revocationMode']=mode;checkpoint()
            protected=action('explicit-revoke-'+mode,'sender','revoke',label=case_label)
            expected='cancellation_not_safe' if mode=='released' else 'cancellation_unavailable'
            require(protected['phase']=='committing' and protected['endAuthorized'] and protected['failureCode']==expected,
                    'Unsafe revocation response released the exact reservation.')
            pending=action('protected-audit-'+mode,'sender','audit')['pending']
            require(len(pending)==1 and pending[0]['txid']==prepared['txid'],'Uncertain revocation lost its fence.')
            negative.append({'response':mode,'nativePhase':protected['phase'],'failureCode':protected['failureCode'],
                             'realProxyMutation':False})
        with state_lock:state['revocationMode']='real';checkpoint()
        revoked=action('explicit-real-revocation-once','sender','revoke',label=case_label)
        require(revoked['phase']=='rejected' and not revoked['endAuthorized'] and revoked['failureCode']=='cancelled',
                'Actual affirmative revocation did not cancel the exact operation.')
        with state_lock:state['revocationMode']=None;checkpoint()
        require(action('restart-terminal-status-read-only','sender','status',label=case_label)==revoked,'Terminal cancellation changed after process restart.')
        require(action('native-final-audit','sender','audit')['pending']==[],'Native pending reservation remains.')
        after_balance=action('sender-after','sender','balance')['rgb']
        require(after_balance['settled']==before_balance['settled'] and after_balance['spendable']==after_balance['settled'],
                'Explicit cancellation did not return the exact existing spendable units.')
        require(fixture.rpc(fixture.BTC,'getrawmempool')==[],'Cancellation broadcast a Bitcoin transaction.')
        require(state['revocationAccepted'] and state['revocationsForwarded']==1 and state['revocationAttempts']==5
                and state['repeatedWritesBlocked']==0,'Actual revocation request counts differ.')
        result={'passed':True,**built,'amountUnits':1,'txid':prepared['txid'],'newOperation':True,
                'oldV1CancellationCertificateReadBack':True,'prepareCalls':1,'commitCalls':1,'legacyCancelCalls':1,
                'legacyCancelAfterDispatchDidNotRevoke':True,'explicitRevokeCalls':5,
                'ackPrepareAccepted':True,'consignmentPostsForwarded':0,'bitcoinBroadcasts':0,
                'rpcCounts':dict(state),'readOnlyRecoveryRpcMethods':changed,'simulatedNegativeResponses':negative,
                'beforeBalance':before_balance,'afterBalance':after_balance,'terminalStatus':revoked,
                'newMint':False,'newFunding':False,'gatesRemainClosed':True}
        save(target/'RESULT.json',result);print(json.dumps(result))
    except Exception as error:
        save(target/'STOPPED.json',{'passed':False,'steps':steps,'stoppedAt':str(error),'rpcCounts':dict(state),'automaticReplay':False})
        print(json.dumps({'passed':False,'stoppedAt':str(error),'evidence':str(target)}));raise SystemExit(1)
    finally:
        server.shutdown();server.server_close();fcntl.flock(issuer_lock,fcntl.LOCK_UN);os.close(issuer_lock)


if __name__=='__main__':main()
