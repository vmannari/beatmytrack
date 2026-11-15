"""Keep final native views and exact survey inputs outside build retention."""
from pathlib import Path
import gzip,hashlib,json,shutil

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-reference-repair-2026-11-14'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
retained={}
for name in ['decoded-restoration-final.json','decoded-final.json','decoded-before.json']:
    source=BUILD/name;target=OUT/(name+'.gz')
    with target.open('wb') as destination:
        destination.write(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    assert gzip.decompress(target.read_bytes())==source.read_bytes()
    retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target),'decoded_sha256':sha(source)}
for name in ['coarse-parts.json','coarse-parts-without-detail.json','key-diagnostic.json']:
    source=BUILD/name;target=OUT/(name+'.gz')
    target.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    assert gzip.decompress(target.read_bytes())==source.read_bytes()
    retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target),'decoded_sha256':sha(source)}
for folder in ['restored-all-prepared','assets','final-catalogue']:
    source=BUILD/folder;destination=OUT/(folder+'-receipts');destination.mkdir(exist_ok=True)
    for file in source.iterdir():
        if file.suffix not in ['.json','.log']:continue
        target=destination/file.name
        if file.stat().st_size>1000000:
            target=destination/(file.name+'.gz')
            target.write_bytes(gzip.compress(file.read_bytes(),compresslevel=9,mtime=0))
            assert gzip.decompress(target.read_bytes())==file.read_bytes()
        else:shutil.copyfile(file,target)
        retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target)}
for label in ['views-restored-prepared','views-restored-prepared-close','app-restored','opaque-restored']:
    source=BUILD/label
    if not source.is_dir():continue
    for file in source.rglob('*'):
        if not file.is_file() or file.suffix not in ['.png','.json']:continue
        target=OUT/'final'/label/file.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(file,target)
        retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target)}
index=sha(ROOT/'.git/index')
start=json.loads((OUT/'task-start.json').read_text())
controls={name:sha(ROOT/name)==digest for name,digest in start.items() if not name.startswith('game/assets/vehicles/challenger_hellcat_v1/')}
publication=json.loads((OUT/'native-restoration-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items())
legacy={name:sha(ROOT/name)==digest for name,digest in start.items() if name.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(name).name not in publication['private_native']}
assert len(legacy)==4 and all(legacy.values())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
assert all(same for name,same in controls.items() if name not in ['scripts/prepare_challenger.py','game/tests/bake_challenger_hellcat.gd','game/vehicle/car_mesh_lods.gd','.git/index'])
(OUT/'retained-restoration.json').write_text(json.dumps({'retained':retained,'task_start_controls':controls,
    'native_matches_publication':True,'unconsumed_legacy_exact':legacy,'owned_sources_match_checkpoint':True,
    'main_index_unchanged_during_retention':index==sha(ROOT/'.git/index')},indent=2))
print('RESTORATION_EVIDENCE',len(retained),'retained files; native and source checkpoint exact')
