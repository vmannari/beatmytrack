"""Run the pinned engine with disposable offline storage and retain exact receipts."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
script, mode, label = sys.argv[1:4]
profile = ROOT / 'tmp' / ('object-properties-' + label)
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
env = {key: value for key, value in os.environ.items() if not key.startswith('BMT_')}
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
command = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe', '--audio-driver', 'Dummy',
           '--path', str(ROOT / 'game'), '--script', script]
if mode == 'headless':
    command += ['--headless']
else:
    command += ['--rendering-method', mode]
paths = ['game/core/app.gd', 'game/editor/object_browser.gd', 'game/editor/object_properties.gd',
         'game/editor/object_thumbnail.gd', script.replace('res://', 'game/')]
def hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths}
before = hashes()
start = time.monotonic()
with (OUT / (label + '.log')).open('wb') as log:
    try:
        code = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180).returncode
    except subprocess.TimeoutExpired:
        code = 'timeout'
result = dict(command=command, exit=code, seconds=round(time.monotonic()-start, 3),
              source_before=before, source_after=hashes())
(OUT / (label + '.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
print(json.dumps(result))
print((OUT / (label + '.log')).read_text(encoding='utf-8', errors='replace')[-3500:])
