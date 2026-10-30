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
env['APPDATA'] = str(ROOT / 'build/garage-persistent-user' / label)
env['BMT_API_URL'] = ''
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
script_path = script if script.startswith('res://') else 'res://tests/' + script
wrapper_args = ['-Action', 'CheckScript' if mode == 'check' else 'TestScript', '-ScriptPath', script_path]
def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"
launch_text = "$ErrorActionPreference = 'Stop'\n& " + ps_quote(ROOT / 'scripts/dev.ps1') + ' -Action ' + ps_quote(wrapper_args[1]) + ' -ScriptPath ' + ps_quote(script_path)
if mode != 'check':
    test_args = ['--output=' + str(out)] + sys.argv[4:]
    launch_text += ' -TestArgument @(' + ','.join(ps_quote(x) for x in test_args) + ')'
if mode not in ('headless', 'check'):
    launch_text += ' -Graphical -RenderingMethod ' + ps_quote(mode)
launch_path = out / 'launch.ps1'
launch_path.write_text(launch_text + "\n", encoding='utf-8')
cmd = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(launch_path)]
started = time.monotonic()
with (out / 'run.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
raw = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines() if any(marker in line for marker in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:', 'FullyQualifiedErrorId'))]
record = dict(command=cmd, exit_code=result.returncode or int(bool(errors)), seconds=time.monotonic()-started, error_lines=errors,
              environment={key: env[key] for key in ('APPDATA', 'BMT_API_URL')})
(out / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-3500:])
sys.exit(record['exit_code'])
