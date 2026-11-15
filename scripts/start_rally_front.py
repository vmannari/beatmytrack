"""Capture exact task-start source and shared-work controls before authoring."""
import hashlib
import json
import re
from run_rally_front import ROOT,OUT,WORK
OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
names=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md',
       'game/vehicle/compact_front_lamps.gd','game/vehicle/compact_grille.gd','game/vehicle/compact_headlamp.gdshader',
       'game/vehicle/car_visual.gd','game/vehicle/car_detail_reduction.gd','game/vehicle/car_coarse_reduction.gd',
       'game/vehicle/compact_coachwork.gd','game/vehicle/compact_detail.gd','game/vehicle/prepared_asset_dependencies.json',
       'game/vehicle/super_rally_model.gd','game/vehicle/kart_model.gd','game/vehicle/electric_car_model.gd',
       'game/vehicle/forklift_model.gd','game/vehicle/hovercraft_model.gd','game/vehicle/kart_steering.gd',
       'game/physics/handling_config.gd','game/project.godot','.git/index']
names += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/resources/cars').glob('*.tres')]
controls={}
for name in names:
    source=ROOT/name
    if not source.exists():continue
    data=source.read_bytes();controls[name]=hashlib.sha256(data).hexdigest()
    if name in names[:6] or name=='game/vehicle/prepared_asset_dependencies.json':
        target=WORK/'before'/name;target.parent.mkdir(parents=True,exist_ok=True);assert not target.exists();target.write_bytes(data)
(OUT/'before-controls.json').write_text(json.dumps(controls,indent=2)+'\n')
identity=(ROOT/'game/core/build_identity.gd').read_text()
(OUT/'initial-car-keys.json').write_text(json.dumps(json.loads(re.search(r'const MODULAR_CAR_SHA256: Dictionary = (.*)',identity)[1]),indent=2)+'\n')
print('RALLY_FRONT_START',len(controls),'controls')
