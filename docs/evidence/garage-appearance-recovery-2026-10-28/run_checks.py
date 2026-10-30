import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
label, script, mode = sys.argv[1:4]
destination = OUT / label
destination.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment['APPDATA'] = str(ROOT / 'build/garage-appearance-recovery-user' / label)
environment['BMT_API_URL'] = ''
Path(environment['APPDATA']).mkdir(parents=True, exist_ok=True)
paths = ['game/vehicle/vehicle_customisation.gd', 'game/vehicle/kart_model.gd',
         'game/vehicle/kart_kits.gd', 'game/ui/car_showroom.gd',
         'game/persistence/local_records.gd', 'game/backend/appearance_sync.gd',
         'game/tests/test_garage_appearance_recovery.gd']

def hashes():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
            for p in paths if (ROOT / p).exists()}

def quote(value):
    return "'" + str(value).replace("'", "''") + "'"

script_path = script if script.startswith('res://') else 'res://tests/' + script
launch = '& ' + quote(ROOT / 'scripts/dev.ps1')
launch += ' -Action ' + quote('CheckScript' if mode == 'check' else 'TestScript')
launch += ' -ScriptPath ' + quote(script_path)
if mode != 'check':
    arguments = ['--output=' + str(destination)] + sys.argv[4:]
    launch += ' -TestArgument @(' + ','.join(quote(a) for a in arguments) + ')'
if mode not in ('check', 'headless'):
    launch += ' -Graphical -RenderingMethod ' + quote(mode)
launch_path = destination / 'launch.ps1'
launch_path.write_text("$ErrorActionPreference = 'Stop'\n" + launch + '\n', encoding='utf-8')
command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(launch_path)]
before = hashes()
started = time.monotonic()
with (destination / 'run.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(command, cwd=ROOT, env=environment, stdout=log,
                            stderr=subprocess.STDOUT, timeout=240)
raw = (destination / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines()
          if any(x in line for x in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:', 'FullyQualifiedErrorId'))]
record = {'command': command, 'script': script_path, 'mode': mode,
          'exit_code': result.returncode or int(bool(errors)), 'errors': errors,
          'seconds': time.monotonic()-started, 'before_hashes': before,
          'after_hashes': hashes(), 'isolated_appdata': environment['APPDATA'],
          'backend_url': environment['BMT_API_URL']}
(destination / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-2200:])
sys.exit(record['exit_code'])
