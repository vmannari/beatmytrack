from pathlib import Path
import hashlib, json, shutil

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
files=list((REPO/'game/assets/vehicles/compact_kits_v1').rglob('*'))
files += list((REPO/'game/vehicle').glob('compact_*.gd'))
files += [REPO/p for p in ('game/vehicle/car_visual.gd','game/vehicle/vehicle_simulation.gd','game/vehicle/handling_config.gd','game/vehicle/vehicle_customisation.gd','game/ui/car_showroom.gd','game/ui/garage_customisation_camera.gd','game/tests/test_compact_kit_construction.gd','game/tests/test_compact_kit_geometry.gd','game/tests/test_expanded_compact_catalog.gd','game/tests/test_compact_aero_variety.gd','game/resources/compact_fun.tres','AGENTS.md','DEVELOPMENT_STATUS.md')]
hashes={}
for path in sorted(set(files)):
    if not path.is_file(): continue
    relative=path.relative_to(REPO)
    target=ROOT/'before'/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    if target.exists(): assert target.read_bytes()==path.read_bytes(),relative
    else: shutil.copyfile(path,target)
    hashes[relative.as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
(ROOT/'before-hashes.json').write_text(json.dumps(hashes,indent=2)+'\n',encoding='utf-8')
print(f'Preserved {len(hashes)} task-start files')
