"""Run pinned native tests with owned profiles and explicit exit receipts."""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
script = sys.argv[1]
label = Path(script).stem
label = os.environ.get('BMT_TEST_LABEL', label)
project = Path(os.environ.get('BMT_TEST_PROJECT', str(ROOT / 'game')))
profile = ROOT / 'build/race-verification-speed-20261107' / label
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='')
command = [sys.executable, str(ROOT / 'scripts/run_no_crash_dialog.py'), '--',
           r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe', '--headless',
           '--path', str(project), '--rendering-method', 'gl_compatibility',
           '--audio-driver', 'Dummy', '--script', script]
if len(sys.argv) > 2:
    command += ['--', *sys.argv[2:]]
log = OUT / (label + '.log')
with log.open('w', encoding='utf-8') as output:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, check=False)
        code = 124
(OUT / (label + '-exit.json')).write_text(json.dumps({'returncode': code}) + '\n', encoding='utf-8')
print(log.read_text(encoding='utf-8', errors='replace')[-4500:])
raise SystemExit(code)

