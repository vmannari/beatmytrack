"""Sequential, isolated local Godot checks through the repository entry point."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
JOBS = {
    'acceleration': ('test_electric_acceleration.gd', False, ''),
    'historical-drift': ('test_electric_drift_easier.gd', False, ''),
    'turning': ('test_electric_turning_tighter.gd', False, ''),
    'probe': ('probe_electric_stronger_power_drift.gd', False, ''),
    'drift': ('test_electric_stronger_power_drift.gd', False, ''),
    'controls': ('test_electric_brake_reverse.gd', False, ''),
    'driving': ('test_electric_over_under.gd', False, ''),
    'parse-own': ('', False, ''),
}

if sys.argv[1:] == ['snapshot']:
    paths = [ROOT/'game/resources/cars/electric.tres']
    for pattern in ['game/assets/garage/cars_v1/electric.scn',
                    'game/assets/garage/previews_v1/electric.png',
                    'game/assets/garage/previews_v1/provenance.json',
                    'game/assets/menu/header_cars_v1/electric.png',
                    'game/assets/news/vehicles/electric.png',
                    'game/assets/liveries/previews_v2/electric/*.png',
                    'game/assets/vehicles/racing_simple_v1/electric_shadow_*.res',
                    'game/assets/vehicles/racing_simple_v1/manifest.json']:
        paths.extend(ROOT.glob(pattern))
    paths.extend(ROOT.glob('game/resources/cars/*.tres'))
    paths.extend(ROOT.glob('game/simulation/*.gd'))
    paths.extend(ROOT.glob('game/assets/vehicles/electric_coachwork_v22/*'))
    hashes = {}
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        target = OUT/'task-base'/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    (OUT/'hashes-before-derivatives.json').write_text(json.dumps(hashes, indent=2)+'\n')
    print(f'Snapshotted {len(hashes)} scoped/protected files')
    sys.exit(0)

env = os.environ.copy()
env.update(APPDATA=str(ROOT/'tmp/electric-stronger-drift-profile'),
           LOCALAPPDATA=str(ROOT/'tmp/electric-stronger-drift-profile/local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
receipts_path = OUT/'commands.json'
receipts = json.loads(receipts_path.read_text()) if receipts_path.exists() else []
failed = False
for name in sys.argv[1:]:
    (OUT/name).mkdir(parents=True, exist_ok=True)
    script, graphical, renderer = JOBS[name]
    parameters = ['-Action', 'Import'] if name == 'import' else ['-Action', 'TestScript', '-ScriptPath', 'res://tests/'+script]
    if name == 'parse-own':
        parameters = ['-Action', 'CheckScript', '-ScriptPath', 'res://vehicle/vehicle_simulation.gd']
    if graphical:
        parameters += ['-Graphical', '-RenderingMethod', renderer]
    evidence = 'res://../docs/evidence/electric-stronger-powered-drift-2026-10-29/'+name
    test_arguments = ['--vehicle=electric'] if name in ('garage', 'liveries') else ['--evidence-root='+evidence]
    if name == 'before':
        test_arguments.append('--before')
    if name == 'windscreen-before':
        test_arguments.append('--windscreen-before')
    if name in ('news', 'racing'):
        test_arguments.append('--vehicle=electric')
    def quote(value):
        return "'"+value.replace("'", "''")+"'"
    command = '& '+quote(str(ROOT/'scripts/dev.ps1'))+' '
    command += ' '.join(value if value.startswith('-') else quote(value) for value in parameters)
    if name not in ('import', 'parse-own'):
        command += ' -TestArgument @('+','.join(map(quote, test_arguments))+')'
    args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command]
    start = time.monotonic()
    with (OUT/(name+'.log')).open('w', encoding='utf-8') as log:
        try:
            result = subprocess.run(args, cwd=ROOT, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=300)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = 'timeout'
    tail = (OUT/(name+'.log')).read_text(encoding='utf-8', errors='replace').splitlines()
    entry = dict(job=name, argv=args, exit_code=code,
                 seconds=round(time.monotonic()-start, 3),
                 source_sha256=hashlib.sha256((ROOT/'game/resources/cars/electric.tres').read_bytes()).hexdigest(),
                 model_sha256=hashlib.sha256((ROOT/'game/vehicle/electric_car_model.gd').read_bytes()).hexdigest(),
                 livery_sha256=hashlib.sha256((ROOT/'game/vehicle/vehicle_livery.gd').read_bytes()).hexdigest())
    receipts.append(entry)
    receipts_path.write_text(json.dumps(receipts, indent=2)+'\n')
    print(json.dumps(entry), flush=True)
    print('\n'.join(tail[-5:]), flush=True)
    if code != 0:
        failed = True
        break
sys.exit(1 if failed else 0)
