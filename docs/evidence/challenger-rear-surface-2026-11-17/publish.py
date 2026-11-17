"""Publish the checked native bank with manifest last and rollback."""
from pathlib import Path
import hashlib,json,os
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
source=root/'build'/out.name/'native'
dest=root/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
start=json.loads((out/'task-start.json').read_text())
prep=json.loads((out/'preparation-command.json').read_text())
assert prep['exit_code']==0 and prep['stable']
assert all(sha(Path(p))==h for p,h in prep['after'].items())
assert json.loads((out/'candidate-rear.json').read_text())['failures']==0
assert json.loads((out/'candidate-trunk.json').read_text())['failures']==0
for label in ['native-bake','allocation','candidate-contours']:
 assert json.loads((out/(label+'-command.json')).read_text())['exit_code']==0,label
previous_publication=json.loads((out/'previous-publication.json').read_text()) if (out/'previous-publication.json').exists() else None
expected=dict(start['native'])
if previous_publication:expected.update(previous_publication['private_native'])
assert all(sha(dest/name)==h for name,h in expected.items()),'Production native bank changed during authoring'
manifest=json.loads((source/'manifest.json').read_text())
names={row['mesh'] for tier in manifest['tiers'].values() for row in tier}
names.update(['hood_profile.json','bonnet_contour.json','source.json'])
files=[source/name for name in sorted(names)]+[source/'manifest.json']
assert len(files)==48
previous={p.name:(dest/p.name).read_bytes() for p in files}
pinned={p.name:sha(p) for p in files}
def put(path,data):
 temporary=path.with_name(path.name+'.rear-candidate')
 temporary.write_bytes(data)
 os.replace(temporary,path)
try:
 for p in files:
  assert sha(p)==pinned[p.name]
  put(dest/p.name,p.read_bytes())
 assert all(sha(Path(p))==h for p,h in prep['after'].items())
except Exception:
 for name,data in previous.items():put(dest/name,data)
 raise
(out/'native-publication.json').write_text(json.dumps({'manifest_last':True,'private_native':pinned,'changed':[p.name for p in files if previous[p.name]!=p.read_bytes()]},indent=2))
print('REAR_NATIVE_PUBLICATION',sum(previous[p.name]!=p.read_bytes() for p in files),'changed files')
