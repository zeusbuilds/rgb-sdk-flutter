#!/usr/bin/env python3.13
"""A read-only TCP forwarder drops an already-open native Electrum session."""
import argparse,email.parser,email.policy,fcntl,http.server,json,os,select,socket,socketserver,subprocess,sys,threading,time,urllib.error,urllib.request
from pathlib import Path
from build import load_verified_build
from run import SDK,FIXTURE,BIN,require,save


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,required=True)
    parser.add_argument('--authorize-active-readonly-outage',action='store_true')
    parser.add_argument('--case-label',default='active-indexer-outage-v3')
    parser.add_argument('--probe-label',default='btc-active-outage-v3')
    parser.add_argument('--rgb-probe-label',default='rgb-active-end-v3')
    parser.add_argument('--expected-units',type=int,default=547);args=parser.parse_args()
    require(args.authorize_active_readonly_outage,'Explicit bounded read-only outage scope required.')
    root=args.root.resolve();require(root.parent==SDK/'.buildlog/bfa7-native/qualification-wallets','Unowned run.')
    built=load_verified_build();sys.path.insert(0,str(FIXTURE));import fixture
    fixture.own_runtime()
    lock=os.open(FIXTURE/'runtime/.issuer.lock',os.O_RDONLY|os.O_NOFOLLOW);fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    require(all(1<=len(v)<=48 and all(c.islower()or c.isdigit()or c=='-'for c in v)for v in(args.case_label,args.probe_label,args.rgb_probe_label)),'Invalid unique scope labels.')
    target=root/args.case_label;target.mkdir(mode=0o700)
    before_chain={'height':fixture.rpc(fixture.BTC,'getblockcount'),'tip':fixture.rpc(fixture.BTC,'getbestblockhash'),
                  'mempool':fixture.rpc(fixture.BTC,'getrawmempool')}
    require(before_chain['mempool']==[],'Unrelated mempool work exists.')
    state={'available':True,'methods':{},'blockedMutations':0,'droppedConnections':0,'connectionsOpened':0,
           'proxyMethods':{},'proxyBlockedMutations':0,'invoiceSetupAllowed':True,'invoiceMetadataWrites':0}
    connections=set();state_lock=threading.Lock()
    save(target/'scope.json',{**built,'allowedChainWrites':0,'newPayments':0,'indexerForwarder':'127.0.0.1:49802',
         'existingUpstream':'127.0.0.1:49702','beforeChain':before_chain})

    def checkpoint():
        path=target/'rpc-counts.json.tmp';fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w')as out:json.dump(state,out,indent=2);out.flush();os.fsync(out.fileno())
        os.replace(path,target/'rpc-counts.json')

    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    proxy_reads={'server.info','invoice.check','consignment.get','media.get','transfer.list','ack.get'}
    class ProxyHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def send(self,status,body):
            self.send_response(status);self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        def do_POST(self):
            size=int(self.headers.get('Content-Length','0'))
            if self.path!='/json-rpc'or not 0<size<8*1024*1024:self.send(400,b'{}');return
            body=self.rfile.read(size);content_type=self.headers.get('Content-Type','')
            if content_type.startswith('multipart/form-data'):
                message=email.parser.BytesParser(policy=email.policy.default).parsebytes(
                  ('Content-Type: '+content_type+'\r\nMIME-Version: 1.0\r\n\r\n').encode()+body)
                fields={part.get_param('name',header='content-disposition'):part.get_payload(decode=True)
                        for part in message.iter_parts()if part.get_param('name',header='content-disposition')!='file'}
                method=fields['method'].decode()
            else:method=json.loads(body)['method']
            with state_lock:
                state['proxyMethods'][method]=state['proxyMethods'].get(method,0)+1
                if method not in proxy_reads:
                    if method=='invoice.prepare'and state['invoiceSetupAllowed']:
                        state['invoiceMetadataWrites']+=1
                    else:
                        state['proxyBlockedMutations']+=1;checkpoint();self.send(503,b'{}');return
                checkpoint()
            try:
                response=opener.open(urllib.request.Request('http://127.0.0.1:49790/json-rpc',data=body,
                    headers={'Content-Type':content_type},method='POST'),timeout=10)
                self.send(response.status,response.read(8*1024*1024))
            except urllib.error.HTTPError as error:self.send(error.code,error.read(65536))
            except Exception:self.send(502,b'{}')
    proxy_server=http.server.ThreadingHTTPServer(('127.0.0.1',49890),ProxyHandler)
    threading.Thread(target=proxy_server.serve_forever,daemon=True).start()

    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            with state_lock:
                if not state['available']:
                    state['droppedConnections']+=1;checkpoint();return
                state['connectionsOpened']+=1;checkpoint()
            upstream=socket.create_connection(('127.0.0.1',49702),timeout=5)
            sockets=(self.request,upstream);buffer=b''
            with state_lock:connections.update(sockets)
            try:
                while True:
                    with state_lock:available=state['available']
                    if not available:return
                    readable,_,_=select.select(sockets,[],[],.2)
                    for src in readable:
                        data=src.recv(65536)
                        if not data:return
                        if src is self.request:
                            buffer+=data
                            require(len(buffer)<1024*1024,'Excessive Electrum frame.')
                            while b'\n'in buffer:
                                line,buffer=buffer.split(b'\n',1)
                                if not line:continue
                                request=json.loads(line);items=request if isinstance(request,list)else[request]
                                with state_lock:
                                    for item in items:
                                        method=item.get('method','')
                                        state['methods'][method]=state['methods'].get(method,0)+1
                                        if method=='blockchain.transaction.broadcast':
                                            state['blockedMutations']+=1;checkpoint();return
                                    checkpoint()
                                upstream.sendall(line+b'\n')
                        else:self.request.sendall(data)
            except (OSError,ValueError):pass
            finally:
                with state_lock:
                    for value in sockets:connections.discard(value)
                upstream.close()

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address=False
        daemon_threads=True
    server=Server(('127.0.0.1',49802),Handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    process=None

    def action(step,operation,wallet='sender',**fields):
        request={'root':str(root),'wallet':wallet,'action':operation,**fields}
        save(target/(step+'.intent.json'),request)
        result=subprocess.run([str(BIN)],input=json.dumps(request).encode(),capture_output=True,timeout=120)
        save(target/(step+'.stdout.private.json'),result.stdout);save(target/(step+'.stderr.private.log'),result.stderr)
        require(result.returncode==0,'Native action failed at '+step)
        value=json.loads(result.stdout);save(target/(step+'.receipt.json'),value);return value

    def wait_file(name,limit=100):
        end=time.monotonic()+limit
        while time.monotonic()<end:
            if (target/name).is_file():return json.loads((target/name).read_text())
            if process.poll()is not None:raise RuntimeError('Native active session exited before '+name)
            time.sleep(.1)
        raise RuntimeError('Native active outage handshake timed out: '+name)

    try:
        address=json.loads((root/'receiver-address.receipt.json').read_text())['address']
        action('approved-prepare-only-command','command',label=args.probe_label,kind='bitcoin',amount=1500,address=address)
        received=action('fresh-owned-RGB-invoice','receive',wallet='receiver',amount=1,faultProxy='rgb-consignment-reply')['receive']
        action('approved-RGB-before-Prepare','command',label=args.rgb_probe_label,kind='rgb',amount=1,
               invoice=received['invoice'],faultProxy='rgb-consignment-reply')
        approved=json.loads((root/'sender'/('command-'+args.rgb_probe_label+'.json')).read_text())
        require(approved['request']['senderTransportEndpoint']=='rpc://127.0.0.1:49890/json-rpc'
                and approved['request']['transportEndpoints']==['rpc://127.0.0.1:49890/json-rpc'],
                'The exact original approved sender/recipient endpoints were not bound before Prepare.')
        save(target/'original-approved-proxy-binding.json',{'operationId':approved['request']['operationId'],
            'fingerprint':approved['request']['fingerprint'],'senderEndpoint':approved['request']['senderTransportEndpoint'],
            'recipientEndpoints':approved['request']['transportEndpoints']})
        request={'root':str(root),'wallet':'sender','action':'active-indexer-outage','faultIndexer':'active-electrum-outage',
                 'faultProxy':'rgb-consignment-reply','controlCase':args.case_label,'probeLabel':args.probe_label,
                 'rgbProbeLabel':args.rgb_probe_label,'expectedUnits':args.expected_units}
        save(target/'active-session.intent.json',request)
        stdout=(target/'active-session.stdout.private.json').open('wb')
        stderr=(target/'active-session.stderr.private.log').open('wb')
        process=subprocess.Popen([str(BIN)],stdin=subprocess.PIPE,stdout=stdout,stderr=stderr)
        process.stdin.write(json.dumps(request).encode());process.stdin.close()
        wait_file('ONLINE_READY.json')
        with state_lock:
            state['invoiceSetupAllowed']=False
            state['available']=False
            for connection in tuple(connections):
                try:connection.shutdown(socket.SHUT_RDWR)
                except OSError:pass
                connection.close();state['droppedConnections']+=1
            checkpoint()
        save(target/'OUTAGE_ACTIVE.json',{'active':True})
        outage=wait_file('OUTAGE_OBSERVED.json')
        with state_lock:state['available']=True;checkpoint()
        save(target/'RESTORE_ACTIVE.json',{'restored':True})
        process.wait(timeout=120);stdout.close();stderr.close()
        require(process.returncode==0,'Active native session failed to restore; preserve original state.')
        value=json.loads((target/'active-session.stdout.private.json').read_text())
        def refresh_failed(value):
            if isinstance(value,dict):
                return value.get('returned')is False or any(k=='failure'and v is not None or refresh_failed(v)for k,v in value.items())
            if isinstance(value,list):return any(refresh_failed(v)for v in value)
            return False
        signalled=refresh_failed(outage['refresh'])
        restricted=outage['duringBalance']['spendable']<value['beforeBalance']['spendable']
        require(signalled or restricted,'Active outage was silently treated as fresh.')
        require(outage['prepareOutcome']['phase']in{'error','rejected'},'A new plan escaped unavailable indexer observations.')
        require(outage['rgbCommitOutcome']['phase']=='prepared'and not outage['rgbCommitOutcome']['endAuthorized']
                and outage['rgbCommitOutcome']['failureCode']=='submission_not_started',
                'Prepared RGB End was not authoritatively stopped before external dispatch.')
        require(outage['rgbLocalCancel']['phase']=='rejected'and not outage['rgbLocalCancel']['endAuthorized'],
                'Known-unsubmitted RGB plan did not cancel locally.')
        require(outage['acceptedStatus']['phase']=='accepted'and value['restoredAccepted']==outage['acceptedStatus'],
                'Historical submission was lost or rewritten.')
        require(value['restoredBalance']==value['beforeBalance'],'Existing fungible allocation balance did not recover.')
        def identities(rows):return sorted((row['idx'],row['txid'],row['kind'])for row in rows)
        original_ids=identities(value['beforeHistory'])
        restored_ids=identities(value['restoredHistory'])
        require(set(original_ids)<=set(restored_ids),'Canonical history rows changed.')
        extra=[row for row in value['restoredHistory']if row['idx']not in{item[0]for item in original_ids}]
        require(len(extra)==1 and extra[0]['status']=='Failed','Expected only the new locally cancelled test plan.')
        after_chain={'height':fixture.rpc(fixture.BTC,'getblockcount'),'tip':fixture.rpc(fixture.BTC,'getbestblockhash'),
                     'mempool':fixture.rpc(fixture.BTC,'getrawmempool')}
        require(after_chain==before_chain and state['blockedMutations']==0 and state['proxyBlockedMutations']==0,'Outage probe attempted a chain mutation.')
        require(action('final-native-audit','audit')['pending']==[],'Prepare-only outage left a pending operation.')
        result={'passed':True,**built,'activeSessionOpenedBeforeOutage':True,'refreshSignalledFailure':signalled,
                'spendabilityRestrictedDuringOutage':restricted,'duringBalance':outage['duringBalance'],
                'beforeRecoveryBalance':value['beforeRecoveryBalance'],'beforeBalance':value['beforeBalance'],'restoredBalance':value['restoredBalance'],
                'prepareOutcome':outage['prepareOutcome'],'preparedRgbCommitOutcome':outage['rgbCommitOutcome'],
                'preparedRgbLocalCancel':outage['rgbLocalCancel'],'commitAttempts':1,'externalSubmissionDispatches':0,'historicalAcceptedPreserved':True,
                'canonicalRowsPreserved':True,'newLocalCancelledRows':1,'chainUnchanged':True,'rpcCounts':state,
                'recoveryScope':'fungible QBFA allocations; not mint/inflation rights','gatesRemainClosed':True}
        save(target/'RESULT.json',result);print(json.dumps(result))
    except Exception as error:
        save(target/'STOPPED.json',{'passed':False,'stoppedAt':str(error),'rpcCounts':state,'automaticReplay':False})
        print(json.dumps({'passed':False,'stoppedAt':str(error),'evidence':str(target)}));raise SystemExit(1)
    finally:
        with state_lock:state['available']=True
        # Restore the test forwarder's read access even if a native assertion failed.
        if (target/'ONLINE_READY.json').exists()and not(target/'RESTORE_ACTIVE.json').exists():
            save(target/'RESTORE_ACTIVE.json',{'restored':True,'cleanup':True})
        if process is not None and process.poll()is None:
            try:process.wait(timeout=120)
            except subprocess.TimeoutExpired:process.terminate();process.wait(timeout=10)
        server.shutdown();server.server_close();proxy_server.shutdown();proxy_server.server_close();fcntl.flock(lock,fcntl.LOCK_UN);os.close(lock)


if __name__=='__main__':main()
