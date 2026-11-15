"""Freeze the final model evidence, checking the actual live publication."""
from pathlib import Path
import gzip,hashlib,json,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-continuous-side-2026-11-15'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
publication=json.loads((OUT/'native-publication.json').read_text())
assert all(sha(ROOT/'game/assets/vehicles/challenger_hellcat_v1'/name)==digest for name,digest in publication['private_native'].items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/name)==digest for name,digest in checkpoint['after'].items())
prep=json.loads((OUT/'preparation-command.json').read_text())
assert prep['stable'] and all(sha(Path(p))==digest for p,digest in prep['after'].items())
start=json.loads((OUT/'task-start.json').read_text())
controls={p:sha(ROOT/p)==digest for p,digest in start.items() if not p.startswith('game/assets/vehicles/challenger_hellcat_v1/')}
assert all(ok for p,ok in controls.items() if p not in ['scripts/prepare_challenger.py','scripts/challenger_exterior_geometry.py','.git/index'])
legacy={p:sha(ROOT/p)==digest for p,digest in start.items() if p.startswith('game/assets/vehicles/challenger_hellcat_v1/') and Path(p).name not in publication['private_native']}
assert len(legacy)==4 and all(legacy.values())
identity=json.loads((BUILD/'assets/client-build-identity.json').read_text(encoding='utf-8-sig'))
code=(ROOT/'game/core/build_identity.gd').read_text()
keys=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',code)[1])
assert keys['super_rally']==identity['modular_car_sha256']['super_rally']
imports=json.loads((OUT/'image-import-receipt.json').read_text());current_imports=[]
for row in imports['images']:
    source=ROOT/row['path'];digest=hashlib.md5(source.read_bytes()).hexdigest()
    metadata=Path(str(source)+'.import').read_text()
    imported=ROOT/'game'/re.search(r'path="res://([^\"]+\.ctex)"',metadata)[1]
    assert imported.is_file() and 'source_md5="'+digest+'"' in imported.with_suffix('.md5').read_text()
    current_imports.append({'path':row['path'],'source_md5':digest})
commands=[]
for arguments in [['scripts/check_garage_previews.py','--vehicles=super_rally'],['scripts/check_garage_workshop.py']]:
    result=subprocess.run([sys.executable,*arguments],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    commands.append({'command':[sys.executable,*arguments],'exit_code':result.returncode,'output':result.stdout})
    assert result.returncode==0,result.stdout
    print(result.stdout.strip())
for renderer in ['gl_compatibility','mobile']:
    app=json.loads((BUILD/'app'/renderer/'acceptance.json').read_text())
    assert app['checks']==13 and app['failures']==0
retained={}
for name in ['baseline.json','candidate.json','side-profile.json']:
    source=BUILD/name;target=OUT/(name+'.gz')
    target.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    assert gzip.decompress(target.read_bytes())==source.read_bytes()
    retained[target.name]={'sha256':sha(target),'decoded_sha256':sha(source)}
destination=OUT/'asset-receipts';destination.mkdir(exist_ok=True)
for source in (BUILD/'assets').iterdir():
    if not source.is_file() or source.suffix not in ['.json','.log']:continue
    target=destination/source.name
    if source.stat().st_size>1000000:
        target=Path(str(target)+'.gz');target.write_bytes(gzip.compress(source.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(source,target)
    retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target)}
for folder in ['views-final','views-final-close','app']:
    for source in (BUILD/folder).rglob('*'):
        if not source.is_file() or source.suffix not in ['.json','.png']:continue
        target=OUT/'final'/folder/source.relative_to(BUILD/folder);target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target);retained[target.relative_to(OUT).as_posix()]={'sha256':sha(target)}
(OUT/'final-state.json').write_text(json.dumps({'native_publication_exact':True,'checkpoint_and_conversion_inputs_exact':True,
    'task_start_controls':controls,'legacy_controls':legacy,'challenger_model_key_exact':True,
    'current_imports':current_imports,'validators':commands,'retained':retained,
    'scope':'Challenger; concurrent Forklift source-map findings remain outside this scope'},indent=2))
print('CONTINUOUS_SIDE_FINAL',len(retained),'retained artifacts;',len(current_imports),'current imports; native/model/source controls exact')
