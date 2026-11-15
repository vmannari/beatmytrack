"""Retain the exact current vehicle and create private offline review routes."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
OLD = 'challenger-reference-form-2026-11-15'
TAG = OUT.name
BUILD = ROOT / 'build' / TAG
BUILD.mkdir(parents=True, exist_ok=True)
assert not (OUT / 'task-start.json').exists()
paths = list((ROOT / 'scripts').glob('challenger_*.py'))
paths += [ROOT / 'scripts/prepare_challenger.py', ROOT / 'game/tests/bake_challenger_hellcat.gd', ROOT / 'game/vehicle/super_rally_model.gd']
paths += list((ROOT / 'game/assets/vehicles/challenger_hellcat_v1').glob('*'))
controls = list((ROOT / 'game/resources/cars').glob('*.tres'))
controls += [ROOT / 'game/vehicle/handling_config.gd', ROOT / 'game/vehicle/vehicle_simulation.gd', ROOT / '.git/index']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
(OUT / 'task-start.json').write_text(json.dumps({p.relative_to(ROOT).as_posix(): sha(p) for p in paths + controls if p.is_file()}, indent=2))
for path in paths:
    if not path.is_file():
        continue
    dest = BUILD / 'before' / path.relative_to(ROOT)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, dest)
for name in ['run_check.py', 'run_preparation.py', 'export_meshes.gd', 'capture.gd', 'allocation.gd', 'contours_candidate.gd', 'opaque.gd', 'normal_diagnostic.gd']:
    source = ROOT / 'docs/evidence' / OLD / name
    text = source.read_text(encoding='utf-8-sig').replace(OLD, TAG)
    (OUT / name).write_text(text, encoding='utf-8')
text = (OUT / 'run_check.py').read_text()
text = text.replace('source_before=snapshot()', 'source_before=snapshot()')
(OUT / 'run_check.py').write_text(text)
source = (ROOT / 'game/tests/test_panel_contours.gd').read_text(encoding='utf-8-sig')
source = source.replace('res://assets/vehicles/challenger_hellcat_v1/', 'res://../build/' + TAG + '/native/')
(OUT / 'panel_candidate_inputs.gd').write_text(source)
(BUILD / 'native').mkdir(exist_ok=True)
print('Exact source and native baseline retained; controls pinned.')
