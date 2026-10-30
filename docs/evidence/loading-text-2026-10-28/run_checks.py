"""Run the repository entry point with an isolated offline profile and receipts."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
name = sys.argv[1]
profile = ROOT / 'tmp/loading-text-profiles' / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / 'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='', PYTHONIOENCODING='utf-8')
metadata = {p: p.read_bytes() for p in [ROOT / 'game/project.godot', ROOT / 'game/core/build_identity.gd']}
for path, data in metadata.items():
    target = OUT / 'before' / path.relative_to(ROOT)
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
helper = None
arguments = ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
             str(ROOT / 'scripts/dev.ps1'), '-Action', 'TestScript']
if name == 'headless':
    arguments += ['-ScriptPath', 'res://tests/test_race_loading.gd']
elif name == 'native':
    helper = ROOT / 'game/tests/capture_loading_text_2026_10_28.gd'
    if helper.exists():
        raise RuntimeError(f'Unexpected existing helper: {helper}')
    shutil.copy2(OUT / 'capture_loading_text.gd', helper)
    arguments += ['-ScriptPath', 'res://tests/' + helper.name, '-Graphical',
                  '-RenderingMethod', 'gl_compatibility']
else:
    raise ValueError(name)
started = time.monotonic()
try:
    with (OUT / f'{name}.log').open('w', encoding='utf-8') as log:
        process = subprocess.run(arguments, cwd=ROOT, env=env, stdout=log,
                                 stderr=subprocess.STDOUT, timeout=180)
    code = process.returncode
finally:
    for path, data in metadata.items():
        generated = OUT / name / path.relative_to(ROOT)
        generated.parent.mkdir(parents=True, exist_ok=True)
        generated.write_bytes(path.read_bytes())
        path.write_bytes(data)
    if helper is not None:
        helper.unlink(missing_ok=True)
        helper.with_suffix(helper.suffix + '.uid').unlink(missing_ok=True)
receipt = {'command': arguments, 'exit_code': code,
           'seconds': round(time.monotonic() - started, 3)}
(OUT / f'{name}.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt))
print('\n'.join((OUT / f'{name}.log').read_text(encoding='utf-8').splitlines()[-14:]))
sys.exit(code)
