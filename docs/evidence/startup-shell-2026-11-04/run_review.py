"""Bounded, offline native loading review with private profiles and source receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

p = argparse.ArgumentParser()
p.add_argument('label')
p.add_argument('script')
p.add_argument('--profile', default='')
p.add_argument('--renderer', default='gl_compatibility')
p.add_argument('--timeout', type=int, default=360)
p.add_argument('--headless', action='store_true')
p.add_argument('--frozen', action='store_true')
args, extra = p.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
project = Path(json.loads((evidence/'frozen-project.json').read_text(encoding='utf-8'))['project']) if args.frozen else root/'game'
profile = root / 'build/startup-shell-20261104' / (args.profile or args.label)
if args.script == 'res://tests/test_rivalry_ready_entry.gd':
    profile = project.parent/'build/rivalry-ready-entry'/args.label
profile.mkdir(parents=True, exist_ok=True)
config = profile / 'Circuit01Lab/backend.cfg'
config.parent.mkdir(exist_ok=True)
config.write_text('[backend]\nurl=""\n', encoding='utf-8')
env = os.environ.copy()
env.update(APPDATA=str(profile), BMT_API_URL='', BMT_LOADING_OUTPUT=str(evidence / (args.label+'.json')))
command = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--',
    'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe', '--path', str(project),
    '--audio-driver', 'Dummy', '--rendering-method', args.renderer,
    *(['--headless'] if args.headless else []), '--script', args.script, '--', *extra]

def hashes():
    paths = [path for path in project.rglob('*') if path.is_file()
             and '.godot' not in path.parts and path.suffix in ('.gd', '.gdshader', '.gdshaderinc', '.tscn')]
    paths.append(project/'project.godot')
    paths.extend((project/'assets/garage').rglob('*.scn'))
    paths.extend((project/'assets/garage/previews_v1').glob('*.png'))
    paths.extend((project/'assets/vehicles/modular_car_bases_v1').glob('*.scn'))
    paths.extend((project/'assets/menu/header_car_templates_v1').glob('*.scn'))
    return {'game/'+path.relative_to(project).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}

receipt = dict(command=command, profile=str(profile), before=hashes())
began = time.monotonic()
with (evidence/(args.label+'.log')).open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    receipt['owned_process_id'] = process.pid
    (evidence/(args.label+'-running.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    try:
        receipt['exit_code'] = process.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'], capture_output=True, check=False)
        process.wait(timeout=20)
        receipt['exit_code'] = 124
receipt.update(elapsed_seconds=time.monotonic()-began, after=hashes())
receipt['changed_sources'] = [path for path in receipt['before'].keys() | receipt['after'].keys()
                            if receipt['before'].get(path) != receipt['after'].get(path)]
(evidence/(args.label+'-receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps({key: receipt[key] for key in ('exit_code','elapsed_seconds','changed_sources')}))
sys.exit(receipt['exit_code'])
