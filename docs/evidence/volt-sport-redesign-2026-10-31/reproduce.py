"""Isolated, logged native Volt authoring and verification commands."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = next(path for path in Path(__file__).resolve().parents if (path / 'game/project.godot').exists())
OUT = ROOT / 'docs/evidence/volt-sport-redesign-2026-10-31'
OUT.mkdir(parents=True, exist_ok=True)
name, script, *options = sys.argv[1:]
profile = ROOT / 'tmp/volt-sport-redesign-profile' / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
command = [sys.executable, str(ROOT / 'scripts/run_no_crash_dialog.py'), '--',
           r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
           '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy',
           '--position', '10000,10000']
command += ['--headless', '--editor', '--import'] if script == '@import' else ['--script', script]
command += options
started = time.monotonic()
with (OUT / f'{name}.log').open('w', encoding='utf-8') as log:
    try:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                       stdout=log, stderr=subprocess.STDOUT, check=False)
        process.wait()
        code = 'timeout'
result = dict(command=command, exit_code=code, seconds=round(time.monotonic()-started, 3))
(OUT / f'{name}.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result), flush=True)
lines = (OUT / f'{name}.log').read_text(encoding='utf-8').splitlines()
print('\n'.join(lines[-16:]))
sys.exit(0 if code == 0 else 1)
