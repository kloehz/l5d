#!/usr/bin/env python3
"""Eight serial release-server scenarios: exactly 10s warmup + 60s observed."""
from runtime import *
import argparse,platform,uuid,sys,hashlib
from source_identity import identity
SCENARIOS=[('idle',0,0),('player',1,0),('active20',1,20),('dormant20',1,20),('dormant100',1,100),('active50',4,50),('split',2,20),('combat',2,20)]
def cpu_seconds(value):
    days=0
    if '-' in value:d,value=value.split('-');days=int(d)
    fields=[float(x) for x in value.split(':')]
    return days*86400+sum(x*60**i for i,x in enumerate(reversed(fields)))
def sample_process(pid):
    raw=subprocess.check_output(['ps','-p',str(pid),'-o','time=','-o','rss='],text=True).split()
    return cpu_seconds(raw[0]),int(raw[1])/1024

def collect_os_samples_until_exit(process,sample_fn=sample_process,now_fn=time.monotonic,sleep_fn=time.sleep,origin=None,interval=.98):
    if origin is None:origin=now_fn()
    if process.poll() is not None:return []
    try:
        old_cpu,_=sample_fn(process.pid)
    except subprocess.CalledProcessError:
        if process.poll() is not None:return []
        raise
    old_time=now_fn();samples=[]
    while process.poll() is None:
        sleep_fn(interval)
        now=now_fn()
        if now<=old_time:raise ValueError('OS sample clock did not advance')
        if process.poll() is not None:break
        try:
            cpu,rss=sample_fn(process.pid)
        except subprocess.CalledProcessError:
            if process.poll() is not None:break
            raise
        if process.poll() is not None:break
        if cpu<old_cpu:raise ValueError('Live process CPU counter decreased')
        if rss<0:raise ValueError('Process RSS sample must be nonnegative')
        samples.append({'elapsed_s':now-origin,'cpu_core_percent':100*(cpu-old_cpu)/(now-old_time),'rss_mb':rss})
        old_cpu=cpu;old_time=now
    return samples

def run(scenario,count,mob_count,build):
    owned=Processes();pnum=port();raw=ROOT/f'logs/benchmark-{scenario}-raw.jsonl';final=ROOT/f'logs/benchmark-{scenario}.jsonl';os_samples=[];origin=time.monotonic();run_id=f'local_{scenario}_{uuid.uuid4().hex[:10]}';source=identity();build_hash=hashlib.sha256((ROOT/'builds/manifest.json').read_bytes()).hexdigest() if build else None
    try:
        server,log=owned.start(f'benchmark-{scenario}-server',['--server','--port',pnum,'--scenario',scenario,'--duration',70.2,'--metrics',raw,'--run-id',run_id],build)
        owned.wait_ready(server,log,'SERVER_READY')
        for i in range(count):
            behavior='combat' if scenario=='combat' else 'move'
            p,l=owned.start(f'benchmark-{scenario}-bot-{i}',['--bot','--port',pnum,'--scenario',scenario,'--behavior',behavior,'--duration',76,'--report',ROOT/f'logs/benchmark-{scenario}-bot-{i}.jsonl'],build)
            owned.wait_ready(p,l,'CLIENT_READY')
        os_samples=collect_os_samples_until_exit(server,origin=origin)
        assert server.wait(timeout=4)==0
        data=rows(raw)
        for row in data:
            if row['kind']=='metadata':row.update({'runtime_source_sha256':source['runtime_source_sha256'],'build_manifest_sha256':build_hash})
        (ROOT/f'results/benchmark-{scenario}-identity.json').write_text(json.dumps({'run_id':run_id,'runtime_source_sha256':source['runtime_source_sha256'],'build_manifest_sha256':build_hash,'warmup_s':10,'observed_s':60},indent=2)+'\n')
        for r in data:
            if r['kind']=='sample':
                nearest=min(os_samples,key=lambda v:abs(v['elapsed_s']-r['elapsed_s']))
                r['cpu_core_percent']=nearest['cpu_core_percent'];r['rss_mb']=nearest['rss_mb'];r['os_alignment_error_s']=abs(nearest['elapsed_s']-r['elapsed_s'])
        final.write_text(''.join(json.dumps(r)+'\n' for r in data));(ROOT/f'logs/benchmark-{scenario}-os.json').write_text(json.dumps(os_samples,indent=2)+'\n')
        samples=[r for r in data if r['kind']=='sample' and 10<=r['elapsed_s']<70]
        ticks=[r for r in data if r['kind']=='tick' and 10<=r['elapsed_s']<70]
        for tick in ticks:
            for key in ['movement_ms','mob_movement_ms','mob_ai_ms','activation_ms','interest_ms','publication_ms','serialization_ms','combat_ms','physics_slide_calls','physics_ray_queries','analytic_wall_queries','analytic_capsule_queries']:
                assert key in tick and tick[key]>=0,(scenario,'missing/invalid actual metric',key)
            assert tick['physics_ray_queries']==0
            if tick['network_tick']%2:assert tick['mob_movement_ms']==0,(scenario,'stale mob movement duration')
            if tick['network_tick']%6:assert tick['mob_ai_ms']==0,(scenario,'stale AI duration')
            if tick['network_tick']%3:assert tick['publication_ms']==0,(scenario,'stale publication duration')
        assert len(samples)>=59 and 1780<=len(ticks)<=1820,(scenario,len(samples),len(ticks))
        assert all(r['players']==count for r in samples),(scenario,'disconnected benchmark players')
        assert all(27<=r['network_hz']<=33 and 54<=r['poll_hz']<=66 for r in samples)
        if scenario.startswith('dormant'):
            assert all(r['dormant_mobs']==mob_count and r['active_mobs']==0 and r['movement_steps']==0 and r['ai_steps']==0 for r in samples)
            assert samples[0]['mob_states']==samples[-1]['mob_states']
        elif scenario in ['active20','active50','split']:assert all(r['active_mobs']==mob_count for r in samples),(scenario,'active population changed')
        if scenario=='combat':assert samples[-1]['combat_hits']>20 and samples[-1]['kills']>0
        owned.check_logs()
        print(f'BENCHMARK_PASS {scenario}: {len(ticks)} ticks, {len(samples)} OS samples, 10+60s; players={count}',flush=True)
        return final
    finally:owned.cleanup()
def main():
    p=argparse.ArgumentParser();p.add_argument('--source',action='store_true');p.add_argument('--scenario');a=p.parse_args()
    files=[]
    (ROOT/'results/benchmark-machine.json').write_text(json.dumps({'platform':platform.platform(),'machine':platform.machine(),'cpu_count':os.cpu_count(),'cpu_model':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'scope':'local macOS dedicated-server process only; bots on same host; no VPS capacity inference','warmup_s':10,'observed_s':60,'cpu_method':'ps cumulative process TIME delta / monotonic elapsed *100;100%=one core','rss_method':'ps RSS KiB /1024 -> MiB'},indent=2)+'\n')
    for row in SCENARIOS:
        if a.scenario and row[0]!=a.scenario:continue
        files.append(run(*row,not a.source))
    command=[sys.executable,str(ROOT/'scripts/summarize_metrics.py')]+list(map(str,files))+['--warmup','10','--duration','60','--csv',str(ROOT/'results/benchmark.csv'),'--markdown',str(ROOT/'results/benchmark.md')]
    subprocess.run(command,check=True,stdout=(ROOT/'results/benchmark-summary.json').open('w'))
if __name__=='__main__':main()
