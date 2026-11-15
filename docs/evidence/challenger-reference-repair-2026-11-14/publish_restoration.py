"""Publish qualified Challenger files only, with manifest-last rollback."""
from pathlib import Path
import hashlib,json,os
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-reference-repair-2026-11-14'
DEST=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
start=json.loads((OUT/'task-start.json').read_text())
preparation=json.loads((OUT/'preparation-command.json').read_text())
assert preparation['stable'] and preparation['exit_code']==0
assert all(sha(Path(p))==digest for p,digest in preparation['after'].items()), 'Conversion inputs changed'
assert json.loads((OUT/'factory-shape-factory-shape-final.json').read_text())['failures']==0
native_receipt=json.loads((OUT/'native-final-command.json').read_text())
assert native_receipt['exit_code']==0 and not native_receipt['changed_inputs']
previous_receipt=OUT/'native-restoration-publication.json'
previous_publication=json.loads((previous_receipt if previous_receipt.is_file() else OUT/'native-publication.json').read_text())['private_native']
for name,digest in previous_publication.items():
    assert sha(DEST/name)==digest,'Previously published Challenger input changed: '+name
for name,digest in start.items():
    if name.startswith('game/resources/cars/'):
        assert sha(ROOT/name)==digest,'Car configuration changed: '+name
    if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(name).name not in previous_publication:
        assert sha(ROOT/name)==digest,'Unconsumed legacy native input changed: '+name
source=BUILD/'native'
manifest=json.loads((source/'manifest.json').read_text())
consumed={entry['mesh'] for tier in manifest['tiers'].values() for entry in tier}
consumed.update(['hood_profile.json','bonnet_contour.json','source.json'])
files=sorted(source/name for name in consumed)+[source/'manifest.json']
assert len(files)==48, len(files)
pinned={p.name:sha(p) for p in files}
previous={p.name:(DEST/p.name).read_bytes() if (DEST/p.name).is_file() else None for p in files}
index=sha(ROOT/'.git/index')
def put(path,data):
    temporary=path.with_name(path.name+'.panel-candidate')
    temporary.write_bytes(data);os.replace(temporary,path)
try:
    for file in files:
        assert sha(file)==pinned[file.name]
        put(DEST/file.name,file.read_bytes())
    assert all(sha(Path(p))==digest for p,digest in preparation['after'].items()), 'Inputs changed during publication'
except Exception:
    for name,data in previous.items():
        if data is not None:put(DEST/name,data)
    raise
receipt={'manifest_published_last':True,'source_fence_exact':True,'private_native':pinned,
    'changed':[p.name for p in files if previous[p.name]!=p.read_bytes()],
    'main_index_unchanged':index==sha(ROOT/'.git/index'),
    'controls':{n:sha(ROOT/n)==digest for n,digest in start.items() if n.startswith('game/resources/cars/')}}
(OUT/'native-restoration-publication.json').write_text(json.dumps(receipt,indent=2))
assert all(receipt['controls'].values())
print('CHALLENGER_PUBLICATION',len(receipt['changed']),'changed files; conversion and car configuration fences exact')
