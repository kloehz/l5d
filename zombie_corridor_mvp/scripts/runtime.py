#!/usr/bin/env python3
"""Scoped runtime helpers. No global process killing or ambient Godot selection."""
import json, os, pathlib, signal, socket, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
ENGINE=ROOT/'.tools/godot-4.7/Godot.app/Contents/MacOS/Godot'
def command(build=False, headless=True):
    executable=ROOT/'builds/macos/Zombie Corridor MVP.app/Contents/MacOS/Zombie Corridor MVP' if build else ENGINE
    if not executable.exists(): raise RuntimeError(f'Missing executable: {executable}; run scripts/export_builds.sh')
    return [str(executable)]+(['--headless'] if headless else [])+([] if build else ['--path',str(ROOT)])
def port():
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
class Processes:
    def __init__(self): self.items=[]
    def start(self,name,args,build=False,gui=False):
        log=ROOT/'logs'/f'{name}.log'; file=log.open('w')
        p=subprocess.Popen(command(build,not gui)+['--']+list(map(str,args)),cwd=ROOT,stdout=file,stderr=subprocess.STDOUT,start_new_session=True)
        file.close();self.items.append((p,log));return p,log
    def wait_ready(self,p,log,tag,timeout=20):
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            text=log.read_text()
            if 'SCRIPT ERROR' in text or 'ERROR:' in text:raise RuntimeError(f'{log}: {text[-3500:]}')
            if tag in text:return
            if p.poll() is not None:raise RuntimeError(f'Process exited {p.returncode}: {log}\n{text}')
            time.sleep(.05)
        raise RuntimeError(f'Readiness timeout {tag}: {log.read_text()[-1500:]}')
    def cleanup(self):
        for p,_ in self.items:
            if p.poll() is None:p.terminate()
        for p,_ in self.items:
            try:p.wait(timeout=4)
            except subprocess.TimeoutExpired:p.kill();p.wait()
    def check_logs(self,expected_errors=None):
        for p,log in self.items:
            text=log.read_text()
            for expected in (expected_errors or {}).get(log,[]):
                assert expected in text,('missing expected negative-test diagnostic',log,expected)
                text=text.replace(expected,'')
            if 'ERROR:' in text or 'SCRIPT ERROR' in text or 'Trying to run rollback for ticks' in text:raise RuntimeError(f'Runtime errors in {log}: {text[-3000:]}')
def rows(path):
    text=pathlib.Path(path).read_text()
    lines=text.splitlines()
    if not text.endswith('\n'):lines=lines[:-1]
    return [json.loads(s) for s in lines if s.strip()]
