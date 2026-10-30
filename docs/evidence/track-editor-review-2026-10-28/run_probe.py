"""Direct pinned-engine control; every child has an isolated offline profile."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path.cwd()
OUT = ROOT / 'docs/evidence/track-editor-review-2026-10-28'
script, mode = sys.argv[1:3]
label = Path(script).stem + '-' + mode
profile = ROOT / 'build/track-editor-review-2026-10-28' / label
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
command = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe',
           '--audio-driver', 'Dummy', '--path', str(ROOT / 'game'), '--script', script]
command += ['--headless'] if mode == 'headless' else ['--rendering-method', mode]
command += ['--'] + sys.argv[3:]
start = time.monotonic()
with (OUT / ('direct-' + label + '.log')).open('wb') as log:
    child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
    (OUT / ('direct-' + label + '-pid.json')).write_text(json.dumps(dict(pid=child.pid, command=command)))
    try:
        code = child.wait(timeout=240)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 'timeout'
result = dict(command=command, exit=code, seconds=round(time.monotonic()-start, 3),
              source_sha256=hashlib.sha256((ROOT / 'game' / script.removeprefix('res://')).read_bytes()).hexdigest())
(OUT / ('direct-' + label + '.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result), flush=True)
print((OUT / ('direct-' + label + '.log')).read_text(encoding='utf-8', errors='replace')[-4000:], flush=True)
