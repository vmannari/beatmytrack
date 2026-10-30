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
env['APPDATA'] = str(ROOT / 'build/garage-first-entry-user' / env.get('BMT_CACHE_PROFILE', label))
env['BMT_API_URL'] = ''
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
script_path = str(ROOT / script) if '/' in script and not script.startswith('res://') else script if script.startswith('res://') else 'res://tests/' + script
cmd = [r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe', '--path', env.get('BMT_VARIANT_PROJECT', str(ROOT / 'game')),
       '--audio-driver', 'Dummy', '--position', '10000,10000', '--script', script_path]
cmd += ['--headless'] if mode == 'headless' else ['--rendering-method', mode]
cmd += ['--', '--output=' + str(out), '--evidence-root=' + str(out)] + sys.argv[4:]
started = time.monotonic()
with (out / 'run.log').open('w', encoding='utf-8') as log:
    try:
        result = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 124
raw = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines()
          if any(marker in line for marker in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:'))
          and 'Failed to read the root certificate store' not in line]
code = code or int(bool(errors))
record = dict(command=cmd, exit_code=code, seconds=time.monotonic() - started,
              environment={key: env[key] for key in ('APPDATA', 'BMT_API_URL')}, error_lines=errors,
              certificate_store_environment_error='Failed to read the root certificate store' in raw)
(out / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-6500:])
sys.exit(code)
