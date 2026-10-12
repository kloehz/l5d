#!/usr/bin/env python3
"""Content identity for runtime source, separate from changing reports/docs."""
import hashlib,json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def identity():
    paths=[ROOT/'project.godot',ROOT/'export_presets.cfg',ROOT/'dependencies.lock.json']
    for folder in ['game','scenes','config','addons']:
        paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.uid','.import'])
    records=[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(paths)]
    digest=hashlib.sha256(json.dumps(records,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return {'runtime_source_sha256':digest,'files':records}
if __name__=='__main__':print(json.dumps(identity(),indent=2))
