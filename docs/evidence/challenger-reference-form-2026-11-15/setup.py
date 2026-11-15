from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
OLD='challenger-continuous-side-2026-11-15';TAG=OUT.name
BUILD=ROOT/'build'/TAG;BUILD.mkdir(parents=True,exist_ok=True)
previous=ROOT/'docs/evidence'/OLD
for name in ['run_check.py','export_meshes.gd','capture.gd','normal_diagnostic.gd','run_preparation.py','allocation.gd','contours_candidate.gd','publish.py','guarded_assets.py','import_images.py','finalise_assets.py','opaque.gd','production_parse.gd','source_checkpoint.py','run_retention.py']:
    source=previous/name
    if source.exists():(OUT/name).write_text(source.read_text().replace(OLD,TAG))
files=[ROOT/'scripts'/n for n in ['prepare_challenger.py','challenger_exterior_geometry.py','challenger_side_surface.py']]
files += [ROOT/'game/tests/bake_challenger_hellcat.gd',ROOT/'game/vehicle/super_rally_model.gd',ROOT/'game/vehicle/handling_config.gd',ROOT/'game/vehicle/vehicle_simulation.gd',ROOT/'.git/index']
files+=list((ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*'))
files+=list((ROOT/'game/resources/cars').glob('*.tres'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'task-start.json').exists()
(OUT/'task-start.json').write_text(json.dumps({p.relative_to(ROOT).as_posix():sha(p) for p in files if p.is_file()},indent=2))
for file in files:
    if not file.is_file() or file==ROOT/'.git/index':continue
    dest=OUT/'before'/file.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(file,dest)
for folder in ['native','baseline']:
    (BUILD/folder).mkdir(exist_ok=True)
    for file in (ROOT/'game/assets/vehicles/challenger_hellcat_v1').glob('*'):
        if file.is_file():shutil.copyfile(file,BUILD/folder/file.name)
print('REFERENCE_FORM baseline and controls retained')
