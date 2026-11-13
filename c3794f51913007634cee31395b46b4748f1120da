"""Isolated task runs; pinned engine and process-scoped crash dialog suppression."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
script = next((a for a in sys.argv[1:] if not a.startswith('--')), 'test_daily_card_redesign')
renderer = 'mobile' if '--mobile' in sys.argv else 'gl_compatibility'
graphical = '--graphical' in sys.argv
profile = root / 'build' / ('daily-player-accent-corners-' + script + '-' + renderer)
profile.mkdir(parents=True, exist_ok=True)
images = out / 'native' / renderer
images.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='',
           BMT_DAILY_CARD_OUTPUT=str(images), BMT_DAILY_MEDAL_OUTPUT=str(images),
           BMT_DAILY_FIXED_EVIDENCE=str(images), BMT_DAILY_PAGE_OUTPUT=str(images))
wrapper = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--']
if '--entry' in sys.argv:
    command = wrapper + ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                         str(root / 'scripts/dev.ps1'), '-Action', 'TestScript', '-ScriptPath',
                         'res://tests/' + script + '.gd', '-RenderingMethod', renderer]
    if graphical:
        command.append('-Graphical')
else:
    command = wrapper + [r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
                         '--path', str(root / 'game'), '--rendering-method', renderer,
                         '--audio-driver', 'Dummy', '--script', 'res://tests/' + script + '.gd']
    if not graphical:
        command.append('--headless')
    if '--import' in sys.argv:
        command = command[:command.index('--script')] + ['--headless', '--editor', '--import', '--quit']
result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True,
                        encoding='utf-8', errors='replace', timeout=300)
output = result.stdout + result.stderr
log = out / (script + '-' + renderer + ('-native-' if graphical else '-headless-') + str(os.getpid()) + '.log')
log.write_text(output, encoding='utf-8')
print(output[-14000:])
print('LOG:', log)
raise SystemExit(result.returncode)
