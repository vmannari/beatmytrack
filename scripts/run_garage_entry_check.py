"""Run isolated Garage checks with the pinned engine; keep commands and logs."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/garage-entry-carousel-2026-10-26'
name, script, *options = sys.argv[1:]
project = ROOT/'game'
if '--stage-baseline' in options:
    options.remove('--stage-baseline')
    stage = ROOT/'tmp/garage-entry-baseline'
    stage.mkdir(parents=True, exist_ok=True)
    project = stage/'game'
    project.mkdir(exist_ok=True)
    def junction(source, target):
        if not target.exists():
            link_env = os.environ.copy()
            link_env.update(BMT_STAGE_LINK=str(target), BMT_STAGE_TARGET=str(source))
            subprocess.run(['powershell', '-NoProfile', '-Command',
                            'New-Item -ItemType Junction -Path $env:BMT_STAGE_LINK -Target $env:BMT_STAGE_TARGET | Out-Null'],
                           env=link_env, check=True)
    for child in (ROOT/'game').iterdir():
        target = project/child.name
        if child.name in ('ui', 'core'):
            shutil.copytree(child, target, dirs_exist_ok=True)
        elif child.name == '.godot':
            target.mkdir(exist_ok=True)
            for entry in ('global_script_class_cache.cfg', 'extension_list.cfg'):
                if (child/entry).exists(): shutil.copy2(child/entry, target/entry)
            junction(child/'imported', target/'imported')
        elif child.is_dir():
            junction(child, target)
        elif not target.exists():
            shutil.copy2(child, target)
    junction(ROOT/'docs', stage/'docs')
    for path in ('core/app.gd', 'ui/garage_preview_cache.gd', 'ui/garage_cached_thumbnail.gd'):
        shutil.copy2(OUT/'before/game'/path, project/path)
    # A concurrent paint-animation task added an optional parent argument.
    # Match that signature without changing any task-start thumbnail behavior.
    thumbnail = project/'ui/garage_cached_thumbnail.gd'
    thumbnail.write_text(thumbnail.read_text(encoding='utf-8').replace(
        'func apply_livery(value: Dictionary) -> void:',
        'func apply_livery(value: Dictionary, _animate_paint: bool = false) -> void:'), encoding='utf-8')
env = os.environ.copy()
env.update(APPDATA=str(OUT/'profiles'/name), LOCALAPPDATA=str(OUT/'profiles'/name/'local'),
           BMT_API_URL='', BMT_DEV_AUTH_KEY='')
Path(env['APPDATA']).mkdir(parents=True, exist_ok=True)
args = [r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
        '--path', str(project), '--audio-driver', 'Dummy', '--position', '10000,10000',
        '--script', script, *options]
start = time.monotonic()
with (OUT/f'{name}.log').open('w', encoding='utf-8') as log:
    try:
        code = subprocess.run(args, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180).returncode
    except subprocess.TimeoutExpired:
        code = 'timeout'
result = dict(command=args, exit_code=code, seconds=round(time.monotonic()-start, 3))
(OUT/f'{name}.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result), flush=True)
print('\n'.join((OUT/f'{name}.log').read_text(encoding='utf-8').splitlines()[-12:]))
sys.exit(0 if code == 0 else 1)
