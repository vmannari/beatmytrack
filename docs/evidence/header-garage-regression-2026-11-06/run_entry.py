"""Verify the working sources through the normal entry point, with private saves."""
import json
import os
from pathlib import Path
import subprocess

out = Path(__file__).resolve().parent
root = out.parents[2]
profile = root / 'build/header-garage-regression-20261106/entry-profile'
env = os.environ.copy()
for key in ('BMT_API_URL', 'BMT_DEV_AUTH_KEY'):
    env.pop(key, None)
for key in ('APPDATA', 'LOCALAPPDATA'):
    target = profile / key.lower()
    target.mkdir(parents=True, exist_ok=True)
    env[key] = str(target)
user = Path(env['APPDATA']) / 'Circuit01Lab'
user.mkdir(exist_ok=True)
(user / 'backend.cfg').write_text('[backend]\nurl=""\n')
env['BMT_LOADING_OUTPUT'] = str(out / 'entry-result.json')
command = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
           str(root / 'scripts/dev.ps1'), 'TestScript', '-ScriptPath',
           'res://tests/test_header_capture_fences.gd', '-CommandTimeoutSeconds', '120']
with (out / 'entry.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(command, cwd=root, env=env, stdout=log,
                            stderr=subprocess.STDOUT, timeout=160)
(out / 'entry-run.json').write_text(json.dumps(dict(command=command,
    profile=str(profile), exit_code=result.returncode), indent=2)+'\n')
print(json.dumps(dict(exit_code=result.returncode, log=str(out / 'entry.log'))))
raise SystemExit(result.returncode)
