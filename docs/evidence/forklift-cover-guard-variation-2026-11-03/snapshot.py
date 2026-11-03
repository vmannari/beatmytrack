from pathlib import Path
import hashlib, json, shutil

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
paths=['game/vehicle/forklift_kits.gd','game/vehicle/forklift_kit_surface.gd',
    'game/vehicle/vehicle_customisation.gd','game/vehicle/forklift_model.gd',
    'scripts/update_forklift_cabin_catalog.py','backend/bmt_backend/vehicle_appearance_catalog.json']
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/modular_kits_v1/forklift').rglob('*.scn')]
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/modular_car_bases_v1').glob('forklift_*.scn')]
paths += ['game/assets/garage/cars_v1/forklift.scn']
manifest={}
for name in paths:
    source=ROOT/name
    target=OUT/'before'/name
    target.parent.mkdir(parents=True,exist_ok=True)
    assert not target.exists(),name
    shutil.copy2(source,target)
    manifest[name]=hashlib.sha256(source.read_bytes()).hexdigest()
(OUT/'before-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'Saved {len(paths)} task-start files')
