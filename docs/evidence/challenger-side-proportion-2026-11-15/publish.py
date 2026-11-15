"""Atomic allowlist publication after independent native checks, with rollback."""
from pathlib import Path
import hashlib,json,os
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build'/OUT.name;DEST=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
start=json.loads((OUT/'task-start.json').read_text())
prep=json.loads((OUT/'preparation-command.json').read_text())
assert prep['exit_code']==0 and prep['stable']
assert all(sha(Path(path))==digest for path,digest in prep['after'].items())
quality=json.loads((OUT/'candidate-shape.json').read_text())
assert quality['failures']==0
for label in ['native-bake','allocation','candidate-contours']:
    assert json.loads((OUT/(label+'-command.json')).read_text())['exit_code']==0,label
for path,digest in start.items():
    if path.startswith('game/assets/vehicles/challenger_hellcat_v1/') or path.startswith('game/resources/cars/'):
        assert sha(ROOT/path)==digest,'Production input changed: '+path
source=BUILD/'native';manifest=json.loads((source/'manifest.json').read_text())
names={entry['mesh'] for tier in manifest['tiers'].values() for entry in tier}
names.update(['hood_profile.json','bonnet_contour.json','source.json'])
files=[source/name for name in sorted(names)]+[source/'manifest.json']
assert len(files)==48
previous={p.name:(DEST/p.name).read_bytes() for p in files};pinned={p.name:sha(p) for p in files}
def put(path,data):
    tmp=path.with_name(path.name+'.surface-candidate');tmp.write_bytes(data);os.replace(tmp,path)
try:
    for path in files:
        assert sha(path)==pinned[path.name]
        put(DEST/path.name,path.read_bytes())
    assert all(sha(Path(path))==digest for path,digest in prep['after'].items())
except Exception:
    for name,data in previous.items():put(DEST/name,data)
    raise
(OUT/'native-publication.json').write_text(json.dumps({'manifest_last':True,'private_native':pinned,'changed':[p.name for p in files if previous[p.name]!=p.read_bytes()]},indent=2))
print('SURFACE_NATIVE_PUBLICATION',sum(previous[p.name]!=p.read_bytes() for p in files),'changed; 48-file allowlist verified.')
