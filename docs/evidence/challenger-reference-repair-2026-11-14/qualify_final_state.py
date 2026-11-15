"""Bind final current sources, prepared keys and imported pictures to receipts."""
from pathlib import Path
import hashlib,json,re,subprocess

ROOT=Path(__file__).resolve().parents[3];EVIDENCE=Path(__file__).resolve().parent
script=EVIDENCE/'refresh_restored_pictures.py'
context=script.read_text().split('\nsys.argv.append("--pictures-only")')[0]
namespace={'__file__':str(script)};exec(compile(context,str(script),'exec'),namespace)
current=namespace['sources']()
receipt=json.loads((ROOT/'build/challenger-reference-repair-2026-11-14/final-catalogue/source-receipt.json').read_text())
assert receipt['before']==receipt['after']==current,'Final sources changed after the complete preflight'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
identity=json.loads((ROOT/'build/challenger-reference-repair-2026-11-14/final-catalogue/client-build-identity.json').read_text(encoding='utf-8-sig'))
code=(ROOT/'game/core/build_identity.gd').read_text()
keys=json.loads(re.search(r'MODULAR_CAR_SHA256: Dictionary = (\{[^\n]+\})',code)[1])
assert identity['modular_car_sha256']==keys,'Final live model keys changed'
imports=json.loads((EVIDENCE/'image-import-receipt.json').read_text())
for row in imports['images']:
    source=ROOT/row['path'];digest=hashlib.md5(source.read_bytes()).hexdigest()
    assert digest==row['source_md5'],'Picture changed after import: '+row['path']
    metadata=Path(str(source)+'.import').read_text()
    path=re.search(r'path="res://([^\"]+\.ctex)"',metadata)[1]
    imported=ROOT/'game'/path
    assert imported.is_file() and 'source_md5="'+digest+'"' in imported.with_suffix('.md5').read_text()
commands=[]
for name in ['check_garage_previews.py','check_garage_workshop.py']:
    command=['python','scripts/'+name]
    result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    commands.append({'command':command,'exit_code':result.returncode,'output':result.stdout})
    assert result.returncode==0,result.stdout
    print(result.stdout.strip())
result={'final_inputs':len(current),'source_fence_exact':True,'live_model_keys_exact':True,
        'source_map_sha256':hashlib.sha256(json.dumps(current,sort_keys=True).encode()).hexdigest(),
        'verified_current_image_imports':len(imports['images']),'validators':commands}
(EVIDENCE/'final-state.json').write_text(json.dumps(result,indent=2))
print('FINAL_STATE',len(current),'stable inputs;',len(imports['images']),'current native picture imports')
