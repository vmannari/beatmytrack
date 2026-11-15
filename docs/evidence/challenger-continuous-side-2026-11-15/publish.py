"""Publish only the qualified Challenger allowlist, manifest last, with rollback."""
from pathlib import Path
import json,hashlib,os
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
SOURCE=ROOT/'build/challenger-continuous-side-2026-11-15/native'
DEST=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
start=json.loads((OUT/'task-start.json').read_text())
preparation=json.loads((OUT/'preparation-command.json').read_text())
assert preparation['exit_code']==0 and preparation['stable']
assert all(sha(Path(p))==digest for p,digest in preparation['after'].items())
assert json.loads((OUT/'native-quality-final.json').read_text())['failures']==0
for label in ['native-final','allocation-final','contours-candidate-final']:
    receipt=json.loads((OUT/(label+'-command.json')).read_text())
    assert receipt['exit_code']==0 and not receipt['changed_inputs'],label
for path,digest in start.items():
    if path.startswith('game/assets/vehicles/challenger_hellcat_v1/') or path.startswith('game/resources/cars/'):
        assert sha(ROOT/path)==digest,'Task-start production control changed: '+path
manifest=json.loads((SOURCE/'manifest.json').read_text())
names={row['mesh'] for tier in manifest['tiers'].values() for row in tier}
names.update(['hood_profile.json','bonnet_contour.json','source.json'])
files=[SOURCE/n for n in sorted(names)]+[SOURCE/'manifest.json']
assert len(files)==48
pinned={p.name:sha(p) for p in files};previous={p.name:(DEST/p.name).read_bytes() for p in files}
index=sha(ROOT/'.git/index')
def put(p,data):
    temporary=p.with_name(p.name+'.side-candidate');temporary.write_bytes(data);os.replace(temporary,p)
try:
    for file in files:
        assert sha(file)==pinned[file.name];put(DEST/file.name,file.read_bytes())
    assert all(sha(Path(p))==digest for p,digest in preparation['after'].items())
except Exception:
    for name,data in previous.items():put(DEST/name,data)
    raise
result={'manifest_published_last':True,'source_fence_exact':True,'private_native':pinned,
    'changed':[p.name for p in files if previous[p.name]!=p.read_bytes()],
    'main_index_unchanged':index==sha(ROOT/'.git/index')}
(OUT/'native-publication.json').write_text(json.dumps(result,indent=2))
print('CONTINUOUS_SIDE_PUBLICATION',len(result['changed']),'changed files; all configuration and native controls exact')
