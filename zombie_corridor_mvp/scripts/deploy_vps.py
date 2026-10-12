#!/usr/bin/env python3
"""Explicit-target deployment; never guesses an SSH host or changes a firewall."""
import argparse, pathlib,re,subprocess,tempfile,shlex
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--host',required=True);p.add_argument('--user',required=True);p.add_argument('--directory',required=True);p.add_argument('--service',default='zombie-corridor-mvp');p.add_argument('--port',type=int,default=27015);p.add_argument('--arch',choices=['arm64','x86_64'],required=True);p.add_argument('--key');p.add_argument('--install-service',action='store_true',help='Explicitly install a NEW systemd service using sudo; refuses an existing service')
a=p.parse_args();root=pathlib.Path(__file__).resolve().parents[1]
for value in [a.host,a.user,a.service]:
 if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*',value):p.error('host/user/service must be plain identifiers, not shell syntax')
if not re.fullmatch(r'/[A-Za-z0-9_./-]+',a.directory) or '..' in a.directory.split('/') or a.directory in ['/','/usr','/etc','/home','/opt']:p.error('directory must be a new, dedicated absolute path')
if not 1024<=a.port<=65535:p.error('UDP port must be 1024..65535')
key=[]
if a.key:
 k=pathlib.Path(a.key).expanduser().resolve()
 if not k.is_file():p.error('key file does not exist')
 key=['-i',str(k)]
ssh=['ssh']+key+['-o','BatchMode=yes',f'{a.user}@{a.host}']
def remote(script):return subprocess.run(ssh+[script],check=True,text=True,capture_output=True).stdout
actual=remote('uname -m').strip(); expected={'arm64':'aarch64','x86_64':'x86_64'}[a.arch]
if actual!=expected:raise SystemExit(f'Architecture mismatch: selected {expected}, remote {actual}; nothing uploaded')
# Refuse overwrite: no existing folder or service is ever replaced.
check=f'test ! -e {shlex.quote(a.directory)} && ! systemctl list-unit-files {shlex.quote(a.service+".service")} --no-legend | grep -Fq {shlex.quote(a.service+".service")}'
remote(check)
remote(f'mkdir -p {shlex.quote(a.directory)}')
source=root/f'builds/linux-{a.arch}/zombie-server'
if not source.is_file():raise SystemExit('Build is missing; run export_builds.sh first')
subprocess.run(['scp']+key+[str(source),f'{a.user}@{a.host}:{a.directory}/zombie-server'],check=True)
remote(f'chmod 755 {shlex.quote(a.directory+"/zombie-server")}')
service=(root/'scripts/zombie-corridor.service.in').read_text().replace('@USER@',a.user).replace('@DIRECTORY@',a.directory).replace('@PORT@',str(a.port))
with tempfile.TemporaryDirectory() as tmp:
 path=pathlib.Path(tmp)/(a.service+'.service');path.write_text(service)
 subprocess.run(['scp']+key+[str(path),f'{a.user}@{a.host}:{a.directory}/{a.service}.service'],check=True)
if a.install_service:
 remote(f'sudo install -m 644 {shlex.quote(a.directory+"/"+a.service+".service")} /etc/systemd/system/{a.service}.service && sudo systemctl daemon-reload && sudo systemctl enable --now {a.service}.service')
 print(remote(f'systemctl is-active {a.service}.service; ss -lun | grep -F :{a.port}'))
else:print(f'Uploaded only. Service is staged in {a.directory}; --install-service explicitly authorizes installing this NEW unit.')
print('Firewall/provider UDP rule was NOT changed. Public ENet handshake must still be verified from an external client; deployment is not public-connectivity proof.')
