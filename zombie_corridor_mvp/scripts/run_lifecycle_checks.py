#!/usr/bin/env python3
"""Release failure-state and game-owned local action checks, never OS input injection."""
from runtime import *
import re,sys
from source_identity import identity
results=[]
def main():
    owned=Processes();pnum=port()
    try:
        server,log=owned.start('lifecycle-server',['--server','--port',pnum,'--scenario','player','--metrics',ROOT/'logs/lifecycle-server.jsonl'],True);owned.wait_ready(server,log,'SERVER_READY')
        # Cross-source/build succeeds only with the same actual map/config signature.
        bot,l=owned.start('lifecycle-cross-source',['--bot','--port',pnum,'--scenario','player','--duration',5,'--report',ROOT/'logs/lifecycle-cross-source.jsonl'],False);owned.wait_ready(bot,l,'CLIENT_READY');assert bot.wait(timeout=10)==0
        assert rows(ROOT/'logs/lifecycle-cross-source.jsonl')[-1]['distance']>6
        bad,l=owned.start('lifecycle-protocol-reject',['--bot','--port',pnum,'--reject-protocol-test'],True);assert bad.wait(timeout=15)==2
        assert 'Protocol/map/build incompatible' in l.read_text()
        collision,l=owned.start('lifecycle-bind-conflict',['--server','--port',pnum],True);assert collision.wait(timeout=10)==2;assert 'UDP bind failed' in l.read_text()
        owned.check_logs({l:["ERROR: Couldn't create an ENet host."]});results.append({'name':'protocol_reject_bind_and_cross_source_handshake','status':'PASS'})
    finally:owned.cleanup()
    owned=Processes();pnum=port()
    try:
        metrics=ROOT/'logs/lifecycle-same-client-server.jsonl'
        server,l=owned.start('lifecycle-same-client-server',['--server','--port',pnum,'--scenario','player','--metrics',metrics],True);owned.wait_ready(server,l,'SERVER_READY')
        gui,l=owned.start('lifecycle-same-client',['--client','--port',pnum,'--reconnect-action-test','--duration',10],True,True)
        assert gui.wait(timeout=25)==0
        text=l.read_text();assert text.count('CLIENT_READY ')==2 and text.count('RECONNECT_ACTION')==1,text
        time.sleep(1)
        samples=[r for r in rows(metrics) if r['kind']=='sample']
        assert max(r['players'] for r in samples)==1 and samples[-1]['players']==0
        peer_ids={p['peer'] for r in samples for p in r['player_states']};assert len(peer_ids)==2
        owned.check_logs();results.append({'name':'same_GUI_client_reconnect_without_duplicate_callbacks','status':'PASS','distinct_connections':len(peer_ids)})
    finally:owned.cleanup()
    owned=Processes()
    try:
        gui,l=owned.start('lifecycle-local-action',['--local-action-test','--duration',12,'--capture-frame',ROOT/'results/local-action.png','--capture-delay',8],True,True)
        owned.wait_ready(gui,l,'LOCAL_CHILDREN');line=re.search(r'LOCAL_CHILDREN (\d+) (\d+) (\d+)',l.read_text());assert line
        child_pids=list(map(int,line.groups()[:2]));assert len(set(child_pids+[gui.pid]))==3
        assert gui.wait(timeout=30)==0
        text=l.read_text();assert text.count('CLIENT_READY ')==2,text
        assert 'FRAME_CAPTURE 0' in text
        time.sleep(.3)
        for pid in child_pids:
            try:os.kill(pid,0)
            except ProcessLookupError:continue
            raise AssertionError(('local action leaked child',pid))
        owned.check_logs();results.append({'name':'exported_Probar_local_action','status':'PASS','child_pids_terminated':child_pids,'capture':'results/local-action.png','input_scope':'test-only direct game action; not native keyboard/mouse'})
    finally:owned.cleanup()
    owned=Processes();pnum=port()
    try:
        metrics=ROOT/'logs/play-wave-server.jsonl'
        server,l=owned.start('play-wave-server',['--server','--port',pnum,'--scenario','play','--metrics',metrics],True);owned.wait_ready(server,l,'SERVER_READY')
        bots=[]
        for i in range(2):
            b,l=owned.start(f'play-wave-bot-{i}',['--bot','--port',pnum,'--scenario','play','--behavior','combat','--duration',35,'--report',ROOT/f'logs/play-wave-bot-{i}.jsonl'],True);owned.wait_ready(b,l,'CLIENT_READY');bots.append(b)
        for b in bots:assert b.wait(timeout=45)==0
        samples=[r for r in rows(metrics) if r['kind']=='sample'];assert max(r['wave'] for r in samples)>=2;assert max(r['kills'] for r in samples)>=6
        assert any(r['dormant_mobs']>=12 for r in samples)
        owned.check_logs();results.append({'name':'normal_play_waves_with_dormant_pack','status':'PASS','max_wave':max(r['wave'] for r in samples),'kills':max(r['kills'] for r in samples)})
    finally:owned.cleanup()
    print(json.dumps(results,indent=2));(ROOT/'results/lifecycle.json').write_text(json.dumps({'runtime_source_sha256':identity()['runtime_source_sha256'],'checks':results},indent=2)+'\n')
if __name__=='__main__':main()
