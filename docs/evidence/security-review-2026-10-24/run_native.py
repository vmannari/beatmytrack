"""Headless client checks with isolated Windows application-data directories."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
WORK = ROOT / 'build/security-review-20261024/native'
BIN = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
tests = ['test_session_rotation', 'test_backend_exception_recovery', 'test_backend_second_pass',
         'test_account_privacy', 'test_communication_followup', 'test_medium_communication',
         'test_draft_privacy']
if len(sys.argv) > 1:
    tests = sys.argv[1:]
version = subprocess.check_output([BIN, '--version'], text=True).strip()
assert version == (ROOT / 'godot-version.txt').read_text().strip()
results = []
for test in tests:
    profile = WORK / test
    profile.mkdir(parents=True, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
    env['APPDATA'] = str(profile)
    env['LOCALAPPDATA'] = str(profile / 'local')
    command = [str(BIN), '--headless', '--path', str(ROOT / 'game'), '--script',
        'res://tests/' + test + '.gd', '--log-file', str(OUT / (test + '-engine.log'))]
    stamp = time.monotonic()
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, env=env, cwd=ROOT)
        try:
            stdout, stderr = process.communicate(timeout=50)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                capture_output=True, timeout=10, check=False)
            process.kill() if process.poll() is None else None
            stdout, stderr = process.communicate(timeout=5)
            (OUT / (test + '.log')).write_text(stdout + stderr, encoding='utf-8')
            raise subprocess.TimeoutExpired(command, 50, output=stdout, stderr=stderr)
        output = stdout + stderr
        record = {'test': test, 'exit_code': process.returncode,
            'seconds': round(time.monotonic() - stamp, 3),
            'summaries': re.findall(r'[^\r\n]*\d+ checks[^\r\n]*', output),
            'failures': re.findall(r'^FAIL[^\r\n]*', output, re.M),
            'script_errors': len(re.findall('SCRIPT ERROR', output))}
        (OUT / (test + '.log')).write_text(output, encoding='utf-8')
    except subprocess.TimeoutExpired as error:
        record = {'test': test, 'status': 'timeout', 'seconds': 50}
        raw = (error.stdout or '') + (error.stderr or '')
        if isinstance(raw, bytes):
            raw = raw.decode('utf-8', errors='replace')
        (OUT / (test + '.log')).write_text(raw, encoding='utf-8')
    results.append(record)
    print(json.dumps(record), flush=True)
    (OUT / 'native-results.json').write_text(json.dumps({'engine': version, 'results': results}, indent=2) + '\n')
