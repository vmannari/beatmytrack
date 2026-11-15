"""Publish qualified Challenger files only, with manifest-last rollback."""
from pathlib import Path
import hashlib,json,os
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-panel-corrections-2026-11-14'
DEST=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
start=json.loads((OUT/'task-start.json').read_text())
preparation=json.loads((OUT/'preparation-command.json').read_text())
assert preparation['stable'] and preparation['exit_code']==0
assert all(sha(Path(p))==digest for p,digest in preparation['after'].items()), 'Conversion inputs changed'
assert json.loads((OUT/'panels-final.json').read_text())['failures']==0
native_receipt=json.loads((OUT/'native-final-command.json').read_text())
assert native_receipt['exit_code']==0 and not native_receipt['changed_inputs']
for name,digest in start.items():
    if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') or name.startswith('game/resources/cars/'):
        assert sha(ROOT/name)==digest, 'Live input changed: '+name
source=BUILD/'native'
files=sorted(p for p in source.iterdir() if p.suffix in ['.res','.json'] and p.name!='manifest.json')+[source/'manifest.json']
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
(OUT/'native-publication.json').write_text(json.dumps(receipt,indent=2))
assert all(receipt['controls'].values())
print('CHALLENGER_PUBLICATION',len(receipt['changed']),'changed files; conversion and car configuration fences exact')
