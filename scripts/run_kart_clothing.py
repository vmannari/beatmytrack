"""Bounded pinned-engine runner with isolated, offline review data."""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/kart-clothing-2026-11-14'


def main():
    label, script, *options = sys.argv[1:]
    assert label and all(c.isalnum() or c in '-_' for c in label)
    OUT.mkdir(parents=True, exist_ok=True)
    profile = ROOT / 'build/kart-clothing-2026-11-14/profiles' / label
    for name in ['roaming', 'local']:
        (profile / name).mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / 'roaming'), LOCALAPPDATA=str(profile / 'local'),
               BMT_API_URL='', BMT_DEV_AUTH_KEY='')
    engine = r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    version = subprocess.check_output([engine, '--version'], text=True).strip()
    assert version == (ROOT / 'godot-version.txt').read_text().strip(), version
    command = [engine, '--path', str(ROOT / 'game'), '--audio-driver', 'Dummy',
               '--position', '10000,10000', '--script', script] + options
    path = OUT / (label + '.log')
    started = time.monotonic()
    with path.open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        reason = None
        while process.poll() is None:
            time.sleep(0.2)
            contents = path.read_text(encoding='utf-8', errors='replace')
            if 'SCRIPT ERROR:' in contents or time.monotonic() - started > 600:
                reason = 'script error' if 'SCRIPT ERROR:' in contents else '600s timeout'
                process.kill()
                break
        code = process.wait()
    contents = path.read_text(encoding='utf-8', errors='replace')
    receipt = dict(engine=version, command=command, exit_code=code, stop_reason=reason,
                   seconds=time.monotonic()-started,
                   errors=[line for line in contents.splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))])
    (OUT / (label + '-receipt.json')).write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt, indent=2))
    print(contents[-2500:])
    return int(code != 0 or bool(reason))


if __name__ == '__main__':
    raise SystemExit(main())
