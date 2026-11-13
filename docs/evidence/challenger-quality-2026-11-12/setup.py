from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
paths=['scripts/prepare_challenger.py','game/tests/bake_challenger_hellcat.gd','game/vehicle/super_rally_model.gd',
 'game/vehicle/car_visual.gd','game/vehicle/handling_config.gd','game/vehicle/vehicle_simulation.gd','game/vehicle/rally_handbrake.gd',
 'game/vehicle/livery_catalog.gd','game/vehicle/vehicle_weathering.gd','game/ui/car_showroom.gd',
 'game/legal/challenger_hellcat_notices.txt','game/tests/test_challenger_hellcat.gd','game/tests/test_super_rally_design.gd','game/tests/test_super_rally_c3_kits.gd','game/tests/test_super_rally.gd']
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/resources').rglob('*.tres')]
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*') if p.suffix in ['.res','.json']]
hashes={}
for f in paths:
    target=OUT/'before'/f;target.parent.mkdir(parents=True,exist_ok=True);assert not target.exists(),f
    shutil.copyfile(ROOT/f,target);hashes[f]=hashlib.sha256(target.read_bytes()).hexdigest()
(OUT/'start-sources.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
old=ROOT/'docs/evidence/challenger-refinement-2026-11-09'
for name in ['run_check.py','detail.gd','review.gd','garage_surface.gd','final_import.py','guarded_assets.py','run_preparation.py']:
    s=(old/name).read_text(encoding='utf-8').replace('challenger-refinement-assets','challenger-quality-assets').replace('challenger-refinement-tests','challenger-quality-tests').replace('challenger-refinement-2026-11-09','challenger-quality-2026-11-12')
    (OUT/name).write_text(s,encoding='utf-8')
picture_paths=json.loads((old/'unrelated-picture-controls.json').read_text(encoding='utf-8'))
(OUT/'pictures-before.json').write_text(json.dumps({f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in picture_paths},indent=2),encoding='utf-8')
print('CHALLENGER_QUALITY_START:',len(hashes),'source/resource snapshots and',len(picture_paths),'picture controls')
