import json
import os
from pathlib import Path
import subprocess
import sys

root = next(parent for parent in Path(__file__).resolve().parents if (parent / 'game/project.godot').exists())
folder = root / 'build/news-load-20261114'
label, test, renderer, *extra = sys.argv[1:]
profile = folder / ('profile-' + label)
env = os.environ.copy()
env['APPDATA'] = str(profile / 'roaming')
env['LOCALAPPDATA'] = str(profile / 'local')
env['BMT_API_URL'] = ''
for path in [env['APPDATA'], env['LOCALAPPDATA']]:
    Path(path).mkdir(parents=True, exist_ok=True)
command = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--',
           'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe',
           '--path', str(root / 'game'), '--audio-driver', 'Dummy']
if renderer == 'headless':
    command += ['--headless']
else:
    command += ['--rendering-method', renderer]
command += ['--script', test, '--log-file', str(folder / (label + '.log'))]
if extra:
    command += ['--'] + extra
(folder / (label + '-command.json')).write_text(json.dumps({'command':command,'environment':{'APPDATA':env['APPDATA'],'LOCALAPPDATA':env['LOCALAPPDATA'],'BMT_API_URL':''}},indent=2))
raise SystemExit(subprocess.run(command,cwd=root,env=env).returncode)
