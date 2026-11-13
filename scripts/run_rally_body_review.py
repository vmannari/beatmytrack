"""Run offline Rally kit review with a private user profile."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/rally-body-cleanup-2026-11-08'

def main():
    name, script, *args = sys.argv[1:]
    env = os.environ.copy()
    for key in ('APPDATA', 'LOCALAPPDATA'):
        folder = ROOT / 'build/rally-body-review' / name / key.lower()
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env['BMT_API_URL'] = ''
    OUT.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, 'scripts/run_no_crash_dialog.py', '--',
               r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
               '--path', 'game', '--audio-driver', 'Dummy', '--script', script, *args]
    try:
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                text=True, timeout=480)
        output = result.stdout + result.stderr
        status = result.returncode
    except subprocess.TimeoutExpired as error:
        output = str(error)
        status = 124
    (OUT / (name + '.log')).write_text(subprocess.list2cmdline(command) + '\n' + output,
                                     encoding='utf-8')
    print(output[-5000:])
    return status or int(any('ERROR:' in line and 'root certificate store' not in line
                            for line in output.splitlines()))

if __name__ == '__main__':
    sys.exit(main())
