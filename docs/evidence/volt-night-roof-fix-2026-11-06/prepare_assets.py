"""Refresh only the two cars depending on electric_glass, then validate all assets."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
paths = []
for vehicle in ['electric', 'hovercraft']:
    paths += list((root / 'game/assets/vehicles/modular_car_bases_v1').glob(vehicle + '_*.scn'))
    paths += list((root / 'game/assets/vehicles/modular_kits_v1' / vehicle).rglob('*.scn'))
    paths.append(root / 'game/assets/garage/cars_v1' / (vehicle + '.scn'))
paths += list((root / 'game/assets/garage/previews_v1').glob('*.png'))
paths.append(root / 'game/assets/garage/previews_v1/provenance.json')
before = {}
for path in paths:
    relative = path.relative_to(root)
    target = evidence / 'before' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists(): shutil.copyfile(path, target)
    before[relative.as_posix()] = hashlib.sha256(target.read_bytes()).hexdigest()
(evidence / 'assets-before.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
runner = str(evidence / 'run_check.py')
subprocess.run([sys.executable, str(root / 'scripts/check_prepared_asset_dependencies.py')], check=True, cwd=root)
for vehicle in ['electric', 'hovercraft']:
    for stage, script in [('bases','bake_modular_car_bases'),('kits','bake_modular_car_kits'),('garage','bake_garage_cars')]:
        label = 'bake-'+vehicle+'-'+stage
        receipt_path = evidence / (label+'-receipt.json')
        if '--resume' in sys.argv and receipt_path.exists():
            receipt = json.loads(receipt_path.read_text())
            stable = all(hashlib.sha256((root/path).read_bytes()).hexdigest() == digest for path,digest in receipt['after'].items())
            complete = receipt['exit_code'] == 0 and not receipt['script_errors']
            recovery_path = evidence / (label+'-recovery.json')
            if label == 'bake-electric-kits' and recovery_path.exists():
                recovery = json.loads(recovery_path.read_text(encoding='utf-8-sig'))
                log = (evidence/(label+'.log')).read_text()
                complete = recovery['finished'] and 'MODULAR_KIT_BAKE_COUNT 120' in log and 'SCRIPT ERROR:' not in log
            if stable and complete:
                print('Already completed: '+label, flush=True)
                continue
        subprocess.run([sys.executable, runner, 'bake-'+vehicle+'-'+stage, 'res://tests/'+script+'.gd',
                        '--timeout', '900', '--vehicle='+vehicle], check=True, cwd=root)
subprocess.run([sys.executable, runner, 'bake-pictures', 'res://../scripts/bake_garage_previews.gd', '--native'], check=True, cwd=root)
subprocess.run([sys.executable, str(root / 'scripts/prepare_car_assets.py'), '--verify',
                '--output', str(evidence / 'preflight')], check=True, cwd=root)
after = {str(path.relative_to(root)).replace('\\','/'): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
(evidence / 'assets-after.json').write_text(json.dumps(after, indent=2), encoding='utf-8')
print(json.dumps({'checked_assets': len(paths), 'changed': [key for key in before if before[key] != after[key]]}))
