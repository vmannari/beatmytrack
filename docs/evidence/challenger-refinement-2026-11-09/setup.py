from pathlib import Path
import hashlib
import json
import shutil
import numpy as np

ROOT=Path(__file__).resolve().parents[3]; OUT=Path(__file__).resolve().parent
paths=['scripts/prepare_challenger.py','game/tests/bake_challenger_hellcat.gd',
       'game/vehicle/super_rally_model.gd','game/vehicle/car_visual.gd','game/vehicle/livery_catalog.gd',
       'game/vehicle/vehicle_weathering.gd','game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd',
       'game/vehicle/rally_handbrake.gd','game/ui/garage_customisation_camera.gd',
       'game/tests/test_super_rally_design.gd','game/tests/test_super_rally_c3_kits.gd',
       'game/tests/test_super_rally.gd','game/tests/test_challenger_hellcat.gd','game/legal/challenger_hellcat_notices.txt']
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/resources').rglob('*.tres')]
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*') if p.suffix in ['.res','.json']]
hashes={}
for f in paths:
    target=OUT/'before'/f;target.parent.mkdir(parents=True,exist_ok=True)
    assert not target.exists(),f
    shutil.copyfile(ROOT/f,target);hashes[f]=hashlib.sha256(target.read_bytes()).hexdigest()
(OUT/'start-sources.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
old=ROOT/'docs/evidence/challenger-hellcat-2026-11-09'
for helper in ['run_check.py','review.gd','final_import.py','guarded_assets.py']:
    data=(old/helper).read_text(encoding='utf-8').replace('challenger-hellcat-guarded-assets','challenger-refinement-assets').replace('challenger-hellcat-tests','challenger-refinement-tests').replace('challenger-hellcat-2026-11-09','challenger-refinement-2026-11-09')
    (OUT/helper).write_text(data,encoding='utf-8')
model=json.loads((ROOT/'game/assets/vehicles/challenger_hellcat_v1/source.json').read_text(encoding='utf-8'))
components=json.loads((old/'components.json').read_text(encoding='utf-8'))
matrix=np.array(components['matrix_world']);centres=np.array(list(model['source_wheel_centres'].values()))
cx=centres[:,0].mean();cz=centres[:,2].mean();fy=np.array([v for k,v in model['source_wheel_centres'].items() if '.Ft.' in k])[:,1].mean()
sx,sz,sy=model['body_scale_xyz']
rows=[]
for item in components['components']:
    if item['triangles']<20:continue
    low,high=np.array(item['bounds']);points=np.array([[x,y,z] for x in [low[0],high[0]] for y in [low[1],high[1]] for z in [low[2],high[2]]])
    w=points@matrix[:3,:3].T+matrix[:3,3]
    p=np.c_[-(w[:,0]-cx)*sx,(w[:,2]-cz)*sy+.37,(w[:,1]-fy)*sz-1.28]
    rows.append({**item,'game_bounds':[p.min(0).round(5).tolist(),p.max(0).round(5).tolist()]})
(OUT/'component-game-bounds.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('SNAPSHOT',len(hashes),'sources; component summary:')
for row in rows:
    if row['triangles']>1500 and (set(row['materials']) != {'Metal09'}):print(row['component'],row['triangles'],row['materials'],row['game_bounds'])
