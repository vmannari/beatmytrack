import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
label, script, mode = sys.argv[1:4]
out = Path(__file__).resolve().parent / label
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(ROOT / 'build/garage-initial-liveries-user' / label)
env['BMT_API_URL'] = ''
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
cmd = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
       str(ROOT / 'scripts/dev.ps1'), '-Action', 'CheckScript' if mode == 'check' else 'TestScript', '-ScriptPath',
       script if script.startswith('res://') else 'res://tests/' + script]
if mode != 'check':
    cmd += ['-TestArgument', '--output=' + str(out)]
if mode not in ('headless', 'check'):
    cmd += ['-Graphical', '-RenderingMethod', mode]
started = time.monotonic()
with (out / 'run.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
raw = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines()
          if any(marker in line for marker in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:'))
          and 'Failed to read the root certificate store' not in line]
record = dict(command=cmd, exit_code=result.returncode or int(bool(errors)),
              seconds=time.monotonic() - started,
              environment={key: env[key] for key in ('APPDATA', 'BMT_API_URL')}, error_lines=errors,
              certificate_store_environment_error='Failed to read the root certificate store' in raw)
(out / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-6000:])
sys.exit(record['exit_code'])
