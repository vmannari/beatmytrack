"""Pinned repository entry point, offline profiles and conditional metadata restore."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
name = sys.argv[1]
scripts = {'translations': 'test_translations.gd', 'licences': 'test_licences_page.gd',
           'app': 'test_app.gd', 'capture': 'capture_all_text_encoding_2026_10_28.gd'}
profile = ROOT / 'tmp/all-text-encoding-profiles' / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='', PYTHONIOENCODING='utf-8')
metadata = {path: path.read_bytes() for path in (ROOT / 'game/project.godot', ROOT / 'game/core/build_identity.gd')}
for path, data in metadata.items():
    dest = OUT / name / 'before' / path.relative_to(ROOT)
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
helper = None
if name == 'capture':
    helper = ROOT / 'game/tests' / scripts[name]
    assert not helper.exists()
    shutil.copy2(OUT / 'capture_editor_text.gd', helper)
command = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
           str(ROOT / 'scripts/dev.ps1'), '-Action', 'TestScript', '-ScriptPath',
           'res://tests/' + scripts[name]]
if name == 'capture':
    command += ['-Graphical', '-RenderingMethod', 'gl_compatibility']
started = time.monotonic()
restored = {}
try:
    with (OUT / (name + '.log')).open('w', encoding='utf-8') as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=180)
finally:
    log_text = (OUT / (name + '.log')).read_text(encoding='utf-8')
    generated = re.search(r'Client build: (\S+)', log_text)
    for path, before in metadata.items():
        current = path.read_bytes()
        dest = OUT / name / 'after' / path.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(current)
        owned = generated is not None and generated[1].encode() in current
        if path.name == 'project.godot':
            pattern = rb'config/version="[^"\r\n]*"'
            owned &= re.sub(pattern, b'config/version=""', before) == re.sub(pattern, b'config/version=""', current)
        if owned:
            path.write_bytes(before)
            restored[path.relative_to(ROOT).as_posix()] = 'restored exact pre-run bytes'
        else:
            restored[path.relative_to(ROOT).as_posix()] = 'preserved concurrent bytes'
    if helper is not None:
        helper.unlink(missing_ok=True)
        helper.with_suffix('.gd.uid').unlink(missing_ok=True)
receipt = {'command': command, 'exit_code': result.returncode,
           'seconds': round(time.monotonic() - started, 3), 'metadata': restored}
(OUT / (name + '.json')).write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt))
print('\n'.join(log_text.splitlines()[-12:]))
sys.exit(result.returncode)
