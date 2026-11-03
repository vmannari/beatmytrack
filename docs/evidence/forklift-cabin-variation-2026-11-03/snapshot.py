from pathlib import Path
import hashlib, json, shutil

root=Path(__file__).resolve().parents[3]
evidence=Path(__file__).resolve().parent
paths=list((root/'game/assets/vehicles/modular_kits_v1/forklift').rglob('*.scn'))
paths+=list((root/'game/assets/vehicles/modular_car_bases_v1').glob('forklift_*.scn'))
paths+=[root/'game/assets/garage/cars_v1/forklift.scn',root/'backend/bmt_backend/vehicle_appearance_catalog.json']
manifest={}
for source in paths:
    relative=source.relative_to(root)
    dest=evidence/'before'/relative
    dest.parent.mkdir(parents=True,exist_ok=True)
    assert not dest.exists(),dest
    shutil.copy2(source,dest)
for source in (evidence/'before').rglob('*'):
    if source.is_file():
        manifest[str(source.relative_to(evidence/'before')).replace('\\','/')]=hashlib.sha256(source.read_bytes()).hexdigest()
(evidence/'before-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'Snapshotted {len(manifest)} files')
