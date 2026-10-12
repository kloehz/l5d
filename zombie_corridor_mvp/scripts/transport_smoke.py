#!/usr/bin/env python3
from runtime import *
def main():
    owned=Processes(); pnum=port()
    try:
        server,log=owned.start('transport-server',['--server','--port',pnum,'--scenario','player','--metrics',ROOT/'logs/transport.jsonl'])
        owned.wait_ready(server,log,'SERVER_READY')
        bots=[]
        for i in range(2):
            report=ROOT/f'logs/transport-bot-{i}.jsonl'
            p,l=owned.start(f'transport-client-{i}',['--bot','--port',pnum,'--scenario','player','--report',report,'--duration',8])
            bots.append((p,report));owned.wait_ready(p,l,'CLIENT_READY')
        for p,_ in bots: assert p.wait(timeout=15)==0
        for _,report in bots:
            r=rows(report)[-1];assert 8<=r['distance']<=11,r
            assert 8<=abs(r['accepted_pose'][1]+7)<=11,r
            assert all(x['enet_peer'].get('throttle_limit')==32 for x in rows(report) if x['ready']),report
            assert len(r['state_owners'])==2,r['state_owners']
            assert all(x[0]==1 and x[1]==x[2] and not x[3] for x in r['state_owners'])
        samples=[r for r in rows(ROOT/'logs/transport.jsonl') if r['kind']=='sample']
        assert samples[-1]['players']==2
        assert 28<=samples[-1]['network_hz']<=32 and 55<=samples[-1]['poll_hz']<=65
        owned.check_logs();print('TRANSPORT_PASS: 2 real ENet clients; owner/root authority; 5m/s Netfox movement; 30Hz clocks; ~60Hz polling')
    finally:owned.cleanup()
if __name__=='__main__':main()
