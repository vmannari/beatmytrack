"""Pinned local engine, disposable offline profiles, bounded child processes."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
root = Path.cwd()
out = root / 'docs/evidence/editor-ux-improvements-2026-10-28'
script, mode = sys.argv[1:3]
label = Path(script).stem + '-' + mode
profile = root / 'build/editor-ux-improvements-2026-10-28' / label
(profile / 'Circuit01Lab').mkdir(parents=True, exist_ok=True)
(profile / 'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n', encoding='utf-8')
env = {k: v for k, v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile))
command = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe', '--audio-driver', 'Dummy', '--path', str(root / 'game')]
command += ['--headless'] if mode == 'headless' else ['--rendering-method', mode]
command += ['--script', script, '--'] + sys.argv[3:]
start = time.monotonic()
source = root/'game'/script.removeprefix('res://')
source_before = hashlib.sha256(source.read_bytes()).hexdigest()
runtime = ['core/app.gd','editor/editor_canvas.gd','editor/object_browser.gd','editor/object_properties.gd',
           'editor/object_thumbnail.gd','editor/editor_button.gd','editor/editor_detail.gd',
           'editor/overview_prop_models.gd','editor/object_editing.gd','editor/surface_labels.gd',
           'editor/creator_prop_costs.gd','track/prop_structures.gd','track/creator_prop_visual.gd']
def hashes():
    return {p: hashlib.sha256((root/'game'/p).read_bytes()).hexdigest() for p in runtime}
before = hashes()
with (out / (label + '.log')).open('wb') as log:
    child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = child.wait(timeout=360)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
        code = 'timeout'
contents = (out / (label + '.log')).read_text(encoding='utf-8', errors='replace')
result = dict(command=command, exit=code, script_errors=contents.count('SCRIPT ERROR:'),
              seconds=round(time.monotonic()-start,3),
              source_sha256=source_before, source_after_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              runtime_sources_before=before,runtime_sources_after=hashes())
(out / (label + '.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if not k.startswith('runtime_sources_')} | {'runtime_sources_stable':result['runtime_sources_before']==result['runtime_sources_after']}),flush=True)
print(contents[-4500:],flush=True)
sys.exit(0 if code == 0 and result['script_errors'] == 0 else 1)
