#!/usr/bin/env python3
"""Actual Linux dedicated exports with two independent macOS release bots."""
from runtime import *
from source_identity import identity
import hashlib
import argparse,uuid
HOST='unix:///Users/guidocotelesso/.docker/run/docker.sock'
def docker(*args):return subprocess.run(['docker','--host',HOST]+list(map(str,args)),check=True,text=True,capture_output=True,timeout=30).stdout
results=[]
def run(arch):
    owned=Processes();pnum=port();name='zombie-transport-'+arch+'-'+uuid.uuid4().hex[:8]
    image,platform=('postgres:16','linux/arm64') if arch=='arm64' else ('debian:bookworm-slim','linux/amd64')
    try:
        docker('run','-d','--rm','--name',name,'--platform',platform,'-e','HOME=/tmp','-p',f'127.0.0.1:{pnum}:27015/udp','-v',str(ROOT/f'builds/linux-{arch}')+':/game:ro',image,'/game/zombie-server','--headless','--','--server','--scenario','combat','--port','27015','--metrics','/tmp/server.jsonl','--duration','40')
        deadline=time.monotonic()+15
        while 'SERVER_READY' not in docker('logs',name):
            assert time.monotonic()<deadline,'Linux readiness timeout';time.sleep(.2)
        bots=[]
        for i,behavior in enumerate(['combat','victim']):
            report=ROOT/f'logs/linux-{arch}-bot-{i}.jsonl'
            p,l=owned.start(f'linux-{arch}-bot-{i}',['--bot','--port',pnum,'--scenario','combat','--behavior',behavior,'--duration',28,'--report',report],True);owned.wait_ready(p,l,'CLIENT_READY');bots.append((p,report))
        for p,_ in bots:assert p.wait(timeout=40)==0
        log=docker('logs',name);(ROOT/f'logs/linux-{arch}-transport.log').write_text(log)
        assert not any(s in log for s in ['ERROR:','SCRIPT ERROR','Trying to run rollback for ticks'])
        raw=docker('exec',name,'cat','/tmp/server.jsonl');(ROOT/f'logs/linux-{arch}-server.jsonl').write_text(raw)
        samples=[r for r in rows(ROOT/f'logs/linux-{arch}-server.jsonl') if r['kind']=='sample'];full=[r for r in samples if r['players']==2];assert full
        reports=[rows(path)[-1] for _,path in bots];assert reports[0]['kills']>0 and any(r['deaths']>0 and r['respawns']>0 for r in reports)
        assert full[-1]['combat_hits']>=4*full[-1]['kills']
        assert all(27<=r['network_hz']<=33 and 50<=r['poll_hz']<=67 for r in full[2:])
        owned.check_logs();results.append({'arch':arch,'status':'PASS','runtime_source_sha256':identity()['runtime_source_sha256'],'linux_executable_sha256':hashlib.sha256((ROOT/f'builds/linux-{arch}/zombie-server').read_bytes()).hexdigest(),'image':image,'platform':platform,'scope':'Docker localhost UDP mapped only on127.0.0.1; not VPS/public path','server_hits':full[-1]['combat_hits'],'server_kills':full[-1]['kills'],'bot_deaths':[r['deaths'] for r in reports],'bot_respawns':[r['respawns'] for r in reports]});print(json.dumps(results[-1]),flush=True)
    finally:
        owned.cleanup();subprocess.run(['docker','--host',HOST,'rm','-f',name],capture_output=True,timeout=15)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--arch',choices=['both','arm64','x86_64'],default='both');a=p.parse_args()
    try:
        for arch in ['arm64','x86_64'] if a.arch=='both' else [a.arch]:run(arch)
    finally:(ROOT/'results/linux-transport.json').write_text(json.dumps(results,indent=2)+'\n')
