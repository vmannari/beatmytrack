import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
label, script, mode = sys.argv[1:4]
out = Path(__file__).resolve().parent / label
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(ROOT / 'build/carousel-overlay-user' / label)
env['BMT_API_URL'] = ''
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
script_path = script if script.startswith('res://') else 'res://tests/' + script
wrapper_args = ['-Action', 'CheckScript' if mode == 'check' else 'TestScript', '-ScriptPath', script_path]
def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"
launch_text = "$ErrorActionPreference = 'Stop'\n& " + ps_quote(ROOT / 'scripts/dev.ps1') + ' -Action ' + ps_quote(wrapper_args[1]) + ' -ScriptPath ' + ps_quote(script_path)
if mode != 'check':
    test_args = ['--output=' + str(out)] + sys.argv[4:]
    launch_text += ' -TestArgument @(' + ','.join(ps_quote(x) for x in test_args) + ')'
if mode not in ('headless', 'check'):
    launch_text += ' -Graphical -RenderingMethod ' + ps_quote(mode)
launch_path = out / 'launch.ps1'
launch_path.write_text(launch_text + "\n", encoding='utf-8')
source_paths = ['game/core/app.gd', 'game/ui/garage_preloader.gd', 'game/ui/garage_preview_cache.gd',
                'game/ui/garage_cached_thumbnail.gd', 'game/ui/garage_page.gd',
                'game/vehicle/vehicle_catalog.gd', 'game/vehicle/hovercraft_model.gd',
                'game/vehicle/electric_coachwork.gd']
if mode != 'check':
    source_paths.append('game/' + script_path.removeprefix('res://'))
def source_hashes():
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in source_paths if (ROOT / path).exists()}
before_hashes = source_hashes()
if mode != 'check':
    (out / 'test-source.gd').write_bytes((ROOT / source_paths[-1]).read_bytes())
cmd = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(launch_path)]
started = time.monotonic()
with (out / 'run.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
raw = (out / 'run.log').read_text(encoding='utf-8', errors='replace')
errors = [line for line in raw.splitlines() if any(marker in line for marker in ('SCRIPT ERROR:', 'FAIL:', 'Parse Error:', 'ERROR:', 'FullyQualifiedErrorId'))]
record = dict(command=cmd, exit_code=result.returncode or int(bool(errors)), seconds=time.monotonic()-started, error_lines=errors,
              environment={key: env[key] for key in ('APPDATA', 'BMT_API_URL')},
              before_hashes=before_hashes, after_hashes=source_hashes())
(out / 'command.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
print(raw[-3500:])
sys.exit(record['exit_code'])
