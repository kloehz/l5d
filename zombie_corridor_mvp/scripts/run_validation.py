#!/usr/bin/env python3
"""Real-transport acceptance; any failed invariant exits nonzero."""
from runtime import *
import argparse,re,statistics,sys
RESULTS=[]
def check_case_logs(owned):
    """Examine only this case's sealed raw logs; never waive existing errors."""
    owned.check_logs()
    for _,log in owned.items:
        text=log.read_text()
        missing=re.search(r'Reference tick -?\d+ missing for #-?\d+ applying -?\d+',text)
        if missing:
            raise RuntimeError(f'Missing rollback reference in {log}: {missing.group()}')
        expired=re.search(r'Received data for -?\d+, rejecting because older than \d+ frames|Received input snapshot for @-?\d+, rejecting because older than \d+ frames',text)
        if expired:
            raise RuntimeError(f'Expired rollback input in {log}: {expired.group()}')
def case(name,scenario,behaviors,duration=12,build=False,network=None):
    owned=Processes();pnum=port();raw=ROOT/f'logs/{name}-server.jsonl';reports=[];proxy=None
    try:
        server,log=owned.start(f'{name}-server',['--server','--port',pnum,'--scenario',scenario,'--metrics',raw,'--duration',duration+3],build)
        owned.wait_ready(server,log,'SERVER_READY')
        endpoint=pnum
        if network:
            endpoint=port();f=open(ROOT/f'logs/{name}-proxy.log','w')
            proxy=subprocess.Popen([sys.executable,str(ROOT/'scripts/udp_proxy.py'),'--listen',str(endpoint),'--server',str(pnum),'--rtt',str(network[0]),'--loss',str(network[1]),'--jitter',str(network[2]),'--report',str(ROOT/f'results/{name}-proxy.json')],stdout=f,stderr=subprocess.STDOUT);f.close()
            owned.items.append((proxy,ROOT/f'logs/{name}-proxy.log'));owned.wait_ready(proxy,ROOT/f'logs/{name}-proxy.log','PROXY_READY')
        for i,behavior in enumerate(behaviors):
            report=ROOT/f'logs/{name}-bot-{i}.jsonl'
            p,l=owned.start(f'{name}-bot-{i}',['--bot','--port',endpoint,'--scenario',scenario,'--behavior',behavior,'--report',report,'--duration',duration],build)
            owned.wait_ready(p,l,'CLIENT_READY');reports.append((p,report))
        for p,_ in reports:assert p.wait(timeout=duration+20)==0,(name,p.returncode)
        series=[rows(path) for _,path in reports];latest=[r[-1] for r in series]
        samples=[r for r in rows(raw) if r['kind']=='sample']; full=[r for r in samples if r['players']==len(behaviors)]
        assert full,(name,'no full roster')
        for report in latest:
            assert report['ready'] and all(x[0]==1 and x[1]==x[2] and not x[3] for x in report['state_owners'])
            assert len(report['state_owners'])>=len(behaviors)
            if scenario!='split':assert report['distance']>6,(name,'movement absent')
            if scenario in ['smoke','combat','validation','split']:assert report['updates']>10,(name,'snapshots absent')
        if scenario in ['smoke','validation','combat']:
            assert latest[0]['kills']>0 and latest[0]['hits']>=4,(name,'no combat kills',latest[0])
            assert full[-1]['combat_hits']>=4*full[-1]['kills'],(name,'duplicate damage')
            if behaviors[0]=='malicious':
                rejects=full[-1]['combat_rejected'];assert rejects.get('life_session',0)>0 and rejects.get('finite',0)>0 and rejects.get('time',0)>0 and rejects.get('queued_duplicate',0)>0 and rejects.get('id_window',0)>0 and rejects.get('cadence',0)>0 and full[-1]['combat_cached_retries']>0,(name,rejects)
            if duration>=25:assert any(r['deaths']>0 and r['respawns']>0 for r in latest),(name,'no death/respawn',[(r['deaths'],r['respawns']) for r in latest])
        if scenario.startswith('dormant'):
            count=int(scenario.removeprefix('dormant'))
            assert all(r['dormant_mobs']==count and r['active_mobs']==0 and r['movement_steps']==0 and r['ai_steps']==0 and all(r[key]==0 for key in ['dormant_movement_steps','dormant_ai_steps','dormant_navigation_steps']) for r in full),(name,'dormant work')
            assert full[0]['mob_states']==full[-1]['mob_states'],(name,'dormant mutated')
        if scenario=='split':
            assert all(r['active_mobs']==20 and r['dormant_mobs']==0 for r in full[2:])
            assert all(r['relevant']==10 for r in latest),[(r['pose'],r['relevant']) for r in latest]
            assert abs(latest[0]['pose'][1]-latest[1]['pose'][1])>100
        rtts=[v for r in latest for v in r['rtt_ms']];median=statistics.median(rtts)
        if network:assert network[0]*.75<median<network[0]+100,(name,'actual RTT not imposed',median)
        owned.cleanup()
        check_case_logs(owned)
        result={'name':name,'status':'PASS','build':build,'players':len(behaviors),'duration_s':duration,'rtt_median_ms':median,'bot_kills':[r['kills'] for r in latest],'bot_deaths':[r['deaths'] for r in latest],'bot_respawns':[r['respawns'] for r in latest],'snapshots':[r['updates'] for r in latest],'server_combat_hits':full[-1]['combat_hits'],'server_kills':full[-1]['kills'],'cached_retries':full[-1]['combat_cached_retries'],'combat_rejected':full[-1]['combat_rejected'],'counts':[full[-1]['active_mobs'],full[-1]['dormant_mobs']],'logs':str(raw.relative_to(ROOT))}
        RESULTS.append(result);print(json.dumps(result),flush=True)
        return result
    finally:owned.cleanup()
def reconnect(build=False):
    owned=Processes();pnum=port()
    try:
        server,log=owned.start('reconnect-server',['--server','--port',pnum,'--scenario','player','--metrics',ROOT/'logs/reconnect-server.jsonl'],build);owned.wait_ready(server,log,'SERVER_READY')
        def bot(i,duration):
            path=ROOT/f'logs/reconnect-{i}.jsonl';p,l=owned.start(f'reconnect-{i}',['--bot','--port',pnum,'--scenario','player','--report',path,'--duration',duration],build);owned.wait_ready(p,l,'CLIENT_READY');return p,path
        first,f=bot(0,8);time.sleep(2);late,l=bot(1,4);assert late.wait(timeout=10)==0
        assert len(rows(l)[-1]['state_owners'])==2
        assert first.wait(timeout=10)==0;time.sleep(1)
        again,a=bot(2,5);assert again.wait(timeout=10)==0;time.sleep(1)
        samples=[r for r in rows(ROOT/'logs/reconnect-server.jsonl') if r['kind']=='sample']
        assert max(r['players'] for r in samples)==2 and samples[-1]['players']==0
        assert rows(a)[-1]['distance']>6
        owned.cleanup();check_case_logs(owned);RESULTS.append({'name':'late_join_reconnect_cleanup','status':'PASS','new_connection_peer':rows(a)[-1]['peer']});print('LATE_JOIN_RECONNECT_PASS',flush=True)
    finally:owned.cleanup()
def main():
    p=argparse.ArgumentParser();p.add_argument('--case',default='all');p.add_argument('--build',action='store_true');a=p.parse_args()
    try:
        if a.case in ['all','combat']:case('combat_authority','validation',['malicious','victim'],32,a.build)
        if a.case in ['all','dormancy']:
            for count in [20,100]:case(f'dormant{count}','dormant'+str(count),['move'],8,a.build)
            case('split_aoi','split',['move','move'],10,a.build)
        if a.case in ['all','reconnect']:reconnect(a.build)
        if a.case in ['all','adverse']:
            case('adverse100','combat',['combat','victim'],32,a.build,(100,.02,0))
            case('adverse150','combat',['combat','victim'],32,a.build,(150,.05,20))
        if a.case in ['all','four']:case('four_player','active50',['move']*4,12,a.build)
    except BaseException as e:
        RESULTS.append({'status':'FAIL','error':repr(e)});raise
    finally:(ROOT/'results/validation.json').write_text(json.dumps(RESULTS,indent=2)+'\n')
if __name__=='__main__':main()
