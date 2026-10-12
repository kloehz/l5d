#!/usr/bin/env python3
"""One owned dedicated server and two independent GUI clients. Ctrl-C cleans only these PIDs."""
from runtime import *
import argparse
p=argparse.ArgumentParser();p.add_argument('--source',action='store_true');p.add_argument('--port',type=int);p.add_argument('--duration',type=float);a=p.parse_args();owned=Processes();pnum=a.port or port()
try:
    server,log=owned.start('local-server',['--server','--port',pnum],not a.source);owned.wait_ready(server,log,'SERVER_READY')
    clients=[]
    for i in range(2):
        client,l=owned.start(f'local-client-{i}',['--client','--port',pnum],not a.source,True);owned.wait_ready(client,l,'CLIENT_READY');clients.append(client)
    state=ROOT/'logs/local-session.json';state.write_text(json.dumps({'port':pnum,'server_pid':server.pid,'client_pids':[p.pid for p in clients],'launcher_pid':os.getpid()},indent=2)+'\n')
    print(f'PLAYABLE_LOCAL: UDP 127.0.0.1:{pnum}; dedicated PID {server.pid}; clients {[p.pid for p in clients]}. Ctrl-C stops this session.',flush=True)
    start=time.monotonic()
    while server.poll() is None and any(p.poll() is None for p in clients):
        if a.duration and time.monotonic()-start>=a.duration:break
        time.sleep(.25)
    owned.check_logs()
except KeyboardInterrupt:pass
finally:
    owned.cleanup();(ROOT/'logs/local-session.json').unlink(missing_ok=True)
