#!/usr/bin/env python3
"""At most six serial unchanged active50 acceptance runs; stop on first failure."""
from runtime import *
import run_validation as acceptance
import argparse,shutil,sys
p=argparse.ArgumentParser();p.add_argument('--label',default='default');a=p.parse_args()
base=ROOT/'logs'/('adaptive-diagnosis-'+a.label);base.mkdir(exist_ok=True)
original_start=Processes.start;original_cleanup=Processes.cleanup;attempts=[];current=base/'0'
def traced_start(self,name,args,build=False,gui=False):
    return original_start(self,name,list(args)+['--transport-trace',current/(name+'-poll.jsonl')],build,gui)
def flushed_cleanup(self):
    # The explicit server duration allows its bounded trace buffer to flush normally.
    for proc,log in self.items:
        if log.name=='four_player-server.log' and proc.poll() is None:
            try:proc.wait(timeout=6)
            except subprocess.TimeoutExpired:pass
    original_cleanup(self)
Processes.start=traced_start;Processes.cleanup=flushed_cleanup
try:
    for index in range(6):
        current=base/str(index);current.mkdir(exist_ok=True)
        error=None
        try:acceptance.case('four_player','active50',['move']*4,12,False)
        except BaseException as exc:error=repr(exc)
        for file in (ROOT/'logs').glob('four_player*'):
            if file.is_file():shutil.copy2(file,current/file.name)
        attempts.append({'run':index,'status':'FAIL' if error else 'PASS','error':error,'logs':str(current.relative_to(ROOT))})
        (ROOT/'results'/('adaptive-diagnosis-'+a.label+'.json')).write_text(json.dumps(attempts,indent=2)+'\n')
        print(attempts[-1],flush=True)
        if error:raise AssertionError(error)
finally:Processes.start=original_start;Processes.cleanup=original_cleanup
