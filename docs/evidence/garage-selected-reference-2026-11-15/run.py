"""Disposable task runner: isolated records, pinned engine, command receipts."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').is_file())
WORK = ROOT / 'build/garage-selected-reference-2026-11-15'
OUT = ROOT / 'docs/evidence/garage-selected-reference-2026-11-15'
name, script = sys.argv[1:3]
OUT.mkdir(parents=True, exist_ok=True)
profile = WORK / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
renderer = name.partition('-')[0]
command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
           str(ROOT / 'scripts/dev.ps1'), '-Action', 'TestScript', '-ScriptPath', script,
           '-CommandTimeoutSeconds', '240', '-TestArgument', f'--evidence-root={OUT / name}']
if renderer in ('gl_compatibility', 'mobile'):
    command += ['-Graphical', '-RenderingMethod', renderer]
if '--direct' in sys.argv:
    engine = r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    assert subprocess.check_output([engine, '--version'], text=True).strip() == (ROOT / 'godot-version.txt').read_text().strip()
    command = [engine, '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy', '--script', script]
    command += ['--rendering-method', renderer] if renderer in ('gl_compatibility', 'mobile') else ['--headless']
    command += ['--', f'--evidence-root={OUT / name}']
started = time.monotonic()
with (OUT / f'{name}.log').open('w', encoding='utf-8') as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=270)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=log, stderr=subprocess.STDOUT)
        process.wait()
        code = 'timeout'
receipt = dict(command=command, exit_code=code, seconds=round(time.monotonic()-started, 3))
(OUT / f'{name}.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt))
print('\n'.join((OUT / f'{name}.log').read_text(encoding='utf-8').splitlines()[-14:]))
raise SystemExit(0 if code == 0 else 1)
