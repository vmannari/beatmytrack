import hashlib
import json
import os
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
DEST=WORK/'frozen'
DEST.mkdir(exist_ok=True)
MUTABLE_ASSETS=['game/assets/vehicles/modular_car_bases_v1/','game/assets/vehicles/modular_kits_v1/',
                'game/assets/garage/cars_v1/','game/assets/menu/header_car_templates_v1/',
                'game/assets/garage/previews_v1/']
manifest={}
count={'copied':0,'linked_read_only_inputs':0}
def transfer(source,rel,link=False):
    target=DEST/rel;target.parent.mkdir(parents=True,exist_ok=True)
    assert target.resolve().is_relative_to(DEST.resolve())
    if target.exists():raise RuntimeError('Fresh snapshot required: '+str(target))
    if link:
        os.link(source,target);count['linked_read_only_inputs']+=1
    else:
        shutil.copyfile(source,target);count['copied']+=1
    if source.suffix in ['.gd','.gdshader','.gdshaderinc','.tres','.json','.ps1','.py','.godot']:
        manifest[rel]=hashlib.sha256(target.read_bytes()).hexdigest()
for folder in ['game','scripts']:
    for base,folders,files in os.walk(ROOT/folder):
        folders[:]=[x for x in folders if x not in ['.godot','__pycache__','android','build']]
        for name in files:
            source=Path(base)/name;rel=source.relative_to(ROOT).as_posix()
            link=rel.startswith('game/assets/') and not any(rel.startswith(prefix) for prefix in MUTABLE_ASSETS)
            transfer(source,rel,link)
transfer(ROOT/'godot-version.txt','godot-version.txt')
for name in ['global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg']:
    source=ROOT/'game/.godot'/name
    if source.exists():transfer(source,'game/.godot/'+name)
imports=ROOT/'game/.godot/imported'
if imports.exists():
    for source in imports.rglob('*'):
        if source.is_file():transfer(source,source.relative_to(ROOT).as_posix(),True)
for name in ['garage_preloader.gd','garage_preview_cache.gd']:
    source=ROOT/'docs/evidence/garage-simple-models-2026-11-07/before/game/ui'/name
    transfer(source,'docs/evidence/garage-simple-models-2026-11-07/before/game/ui/'+name)
for name in ['translation-expectations.json']:
    source=ROOT/'docs/evidence/garage-simple-models-2026-11-07'/name
    transfer(source,'docs/evidence/garage-simple-models-2026-11-07/'+name)
for name in ['run.py']:
    transfer(WORK/name,'build/garage-simple-models-2026-11-07/'+name)
for rel,digest in manifest.items():
    live=ROOT/rel
    # Archived controls have a different source path by design.
    if live.is_file():assert hashlib.sha256(live.read_bytes()).hexdigest()==digest,'Concurrent copy change: '+rel
receipt={'root':str(DEST),'counts':count,'source_sha256':manifest,
         'generated_outputs_are_independent_copies':True,'shader_cache_shared':False,
         'linked_inputs_are_only_immutable_assets_and_imports':True}
(WORK/'freeze-receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps({'root':str(DEST),'counts':count,'source_files':len(manifest)}))
