#!/usr/bin/env python3
"""Fail-fast final-byte verification; no dependent benchmark launch after a failed gate."""
from runtime import *
from source_identity import identity
import sys,hashlib
source=identity()['runtime_source_sha256'];build=hashlib.sha256((ROOT/'builds/manifest.json').read_bytes()).hexdigest();results=[]
commands=[
 ('invariants-final',[str(ENGINE),'--headless','--path',str(ROOT),'res://tests/invariants.tscn'],30),
 ('transport-final-result',[sys.executable,'scripts/transport_smoke.py'],30),
 ('validation-final-release',[sys.executable,'scripts/run_validation.py','--case','all','--build'],240),
 ('lifecycle-final',[sys.executable,'scripts/run_lifecycle_checks.py'],120),
 ('linux-transport-final',[sys.executable,'scripts/run_linux_transport.py'],150),
 ('render-final',[sys.executable,'scripts/capture_release_frames.py'],40),
 ('gui-final',[sys.executable,'scripts/run_local_demo.py','--duration','12'],50),
 ('benchmark-final-run',[sys.executable,'scripts/run_benchmark.py'],650),
]
try:
 for name,cmd,timeout in commands:
  assert identity()['runtime_source_sha256']==source and hashlib.sha256((ROOT/'builds/manifest.json').read_bytes()).hexdigest()==build,'runtime/build mutated during frozen verification'
  start=time.monotonic()
  with (ROOT/f'logs/{name}.log').open('w') as output:p=subprocess.run(cmd,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
  results.append({'stage':name,'command':cmd,'exit_code':p.returncode,'wall_seconds':time.monotonic()-start,'log':f'logs/{name}.log'})
  (ROOT/'results/final-suite.json').write_text(json.dumps({'runtime_source_sha256':source,'build_manifest_sha256':build,'status':'RUNNING' if p.returncode==0 else 'FAIL','stages':results},indent=2)+'\n')
  print(name,p.returncode,round(results[-1]['wall_seconds'],2),flush=True)
  assert p.returncode==0,(name,'failed; dependent stages not launched')
 assert identity()['runtime_source_sha256']==source
 (ROOT/'results/final-suite.json').write_text(json.dumps({'runtime_source_sha256':source,'build_manifest_sha256':build,'status':'PASS','stages':results},indent=2)+'\n')
 print('FINAL_FROZEN_SUITE_PASS',source,build,flush=True)
except BaseException as e:
 (ROOT/'results/final-suite.json').write_text(json.dumps({'runtime_source_sha256':source,'build_manifest_sha256':build,'status':'FAIL','error':repr(e),'stages':results},indent=2)+'\n');raise
