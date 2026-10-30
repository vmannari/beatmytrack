"""Pinned offline Godot checks with isolated user data and retained commands."""
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
env.update(APPDATA=str(ROOT / 'tmp/guardrail-test-profile' / label),
           LOCALAPPDATA=str(ROOT / 'tmp/guardrail-test-profile' / label / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
cmd = [r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
       '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy',
       '--position', '10000,10000', '--script', script if script.startswith('res://') else 'res://tests/' + script]
cmd += ['--headless'] if mode == 'headless' else ['--rendering-method', mode]
cmd += ['--', '--output=' + str(out), '--evidence-root=' + str(out)]
started = time.monotonic()
with (out / 'run.log').open('w', encoding='utf-8') as log:
    try:
        code = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240).returncode
    except subprocess.TimeoutExpired:
        code = 124
raw = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines()
          if any(marker in line for marker in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:'))
          and 'Failed to read the root certificate store' not in line]
code = code or int(bool(errors))
record = dict(command=cmd, exit_code=code, seconds=round(time.monotonic() - started, 3),
              environment={key: env[key] for key in ('APPDATA', 'LOCALAPPDATA', 'BMT_API_URL', 'BMT_DEV_AUTH_KEY')},
              error_count=len(errors), error_lines=errors[:30],
              certificate_store_environment_error='Failed to read the root certificate store' in raw)
(out / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-3500:])
sys.exit(code)
