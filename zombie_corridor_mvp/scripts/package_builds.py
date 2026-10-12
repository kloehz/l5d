#!/usr/bin/env python3
import hashlib,json,pathlib,shutil,tarfile
root=pathlib.Path(__file__).resolve().parents[1]
for arch in ['x86_64','arm64']:
 p=root/f'builds/linux-{arch}'
 shutil.copy(root/'scripts/run_packaged_server.sh',p/'run_server.sh')
 shutil.copy(root/'scripts/zombie-corridor.service.in',p/'zombie-corridor.service.in')
 with tarfile.open(root/f'builds/zombie-server-linux-{arch}.tar.gz','w:gz') as tar:tar.add(p,arcname=f'zombie-server-linux-{arch}')
manifest=[]
for p in sorted((root/'builds').rglob('*')):
 if p.is_file() and p.name not in ['manifest.json','SHA256SUMS']:
  manifest.append({'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(root/'builds/manifest.json').write_text(json.dumps({'engine':'4.7.stable.official.5b4e0cb0f','netfox':'1.35.3','artifacts':manifest},indent=2)+'\n')
(root/'builds/SHA256SUMS').write_text(''.join(f"{r['sha256']}  {r['path']}\n" for r in manifest))
