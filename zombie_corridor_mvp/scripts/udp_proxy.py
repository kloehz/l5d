#!/usr/bin/env python3
"""Controlled UDP delay/jitter/loss on isolated localhost test ports only."""
import argparse,heapq,json,random,select,socket,time,signal,pathlib
p=argparse.ArgumentParser();p.add_argument('--listen',type=int,required=True);p.add_argument('--server',type=int,required=True);p.add_argument('--rtt',type=float,required=True);p.add_argument('--jitter',type=float,default=0);p.add_argument('--loss',type=float,default=0);p.add_argument('--report',required=True);a=p.parse_args()
front=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);front.bind(('127.0.0.1',a.listen));front.setblocking(False)
upstreams={};clients={};queue=[];seq=0;counts={'received':0,'dropped':0,'forwarded':0,'delay_samples_ms':[]};rng=random.Random(99);alive=True
start=time.monotonic()
def stop(*_):
 global alive;alive=False
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
print('PROXY_READY',a.listen,flush=True)
try:
 while alive:
  now=time.monotonic()
  while queue and queue[0][0]<=now:
   _,_,sock,data,destination=heapq.heappop(queue)
   sock.sendto(data,destination);counts['forwarded']+=1
  readable,_,_=select.select([front]+list(upstreams.values()),[],[],min(.01,max(0,queue[0][0]-now)) if queue else .01)
  for sock in readable:
   data,address=sock.recvfrom(65535);counts['received']+=1
   if sock is front:
    if address not in upstreams:
     u=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);u.bind(('127.0.0.1',0));u.setblocking(False);upstreams[address]=u;clients[u]=address
    target=upstreams[address];destination=('127.0.0.1',a.server)
   else:target=front;destination=clients[sock]
   if rng.random()<a.loss:counts['dropped']+=1;continue
   delay=max(0,a.rtt/2+rng.uniform(-a.jitter,a.jitter))/1000;seq+=1
   if len(counts['delay_samples_ms'])<2000:counts['delay_samples_ms'].append(delay*1000)
   heapq.heappush(queue,(time.monotonic()+delay,seq,target,data,destination))
finally:
 counts.update(configured_rtt_ms=a.rtt,configured_jitter_ms=a.jitter,configured_loss=a.loss,elapsed_s=time.monotonic()-start,remaining_queue=len(queue),client_endpoints=len(upstreams))
 pathlib.Path(a.report).write_text(json.dumps(counts,indent=2)+'\n')
 front.close()
 for sock in upstreams.values():sock.close()
