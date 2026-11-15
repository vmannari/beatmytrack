from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build/challenger-continuous-side-2026-11-15';BUILD.mkdir(parents=True,exist_ok=True)
previous=ROOT/'docs/evidence/challenger-reference-repair-2026-11-14'
for name in ['run_check.py','export_meshes.gd','capture.gd']:
    source=(previous/name).read_text()
    source=source.replace('challenger-reference-repair-2026-11-14','challenger-continuous-side-2026-11-15')
    (OUT/name).write_text(source)
files=[ROOT/'scripts/prepare_challenger.py',ROOT/'scripts/challenger_exterior_geometry.py',ROOT/'game/tests/bake_challenger_hellcat.gd',ROOT/'game/vehicle/super_rally_model.gd',ROOT/'game/vehicle/handling_config.gd',ROOT/'game/vehicle/vehicle_simulation.gd',ROOT/'.git/index']
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
print('SIDE_BASELINE pinned current source and native assets; unrelated runtime and configurations retained')
