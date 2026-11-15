from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD='challenger-surface-quality-2026-11-15';BUILD=ROOT/'build'/OUT.name
BUILD.mkdir(parents=True,exist_ok=True)
assert not (OUT/'task-start.json').exists()
paths=list((ROOT/'scripts').glob('challenger_*.py'))+[ROOT/'scripts/prepare_challenger.py',ROOT/'game/tests/bake_challenger_hellcat.gd',ROOT/'game/vehicle/super_rally_model.gd',ROOT/'game/vehicle/handling_config.gd',ROOT/'game/vehicle/vehicle_simulation.gd']
paths+=list((ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*'))+list((ROOT/'game/resources/cars').glob('*.tres'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(OUT/'task-start.json').write_text(json.dumps({p.relative_to(ROOT).as_posix():sha(p) for p in paths if p.is_file()},indent=2))
for p in paths:
    if not p.is_file():continue
    dest=BUILD/'before'/p.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
for name in ['run_check.py','capture.gd','export_meshes.gd','run_preparation.py','allocation.gd','contours_candidate.gd','panel_candidate_inputs.gd','normal_diagnostic.gd','bake_coarse.gd','opaque.gd','guarded_assets.py','gpu_checks.py','import_images.py','run_retention.py']:
    source=ROOT/'docs/evidence'/OLD/name
    (OUT/name).write_text(source.read_text(encoding='utf-8-sig').replace(OLD,OUT.name),encoding='utf-8')
print('CURRENT_SIDE_PROPORTION baseline retained; private routes configured')
