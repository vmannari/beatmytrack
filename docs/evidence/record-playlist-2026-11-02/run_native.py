"""Offline isolated playlist checks using the pinned engine and crash-dialog wrapper."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
script = next((arg for arg in sys.argv[1:] if not arg.startswith('--')), 'test_record_playlist')
graphical = '--graphical' in sys.argv
renderer = 'mobile' if '--mobile' in sys.argv else 'gl_compatibility'
profile = root / 'build/record-playlist-2026-11-02' / (script + '-' + renderer)
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL='',
           BMT_PLAYLIST_EVIDENCE=str(out / renderer))
(out / renderer).mkdir(parents=True, exist_ok=True)
(root / 'build/soundtrack-2026-test').mkdir(parents=True, exist_ok=True)
command = [sys.executable, str(root / 'scripts/run_no_crash_dialog.py'), '--',
           r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
           '--path', str(root / 'game'), '--rendering-method', renderer,
           '--audio-driver', 'Dummy', '--script', 'res://tests/' + script + '.gd']
if not graphical:
    command.append('--headless')
process = subprocess.Popen(command, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           text=True, encoding='utf-8', errors='replace')
try:
    stdout, stderr = process.communicate(timeout=240)
except subprocess.TimeoutExpired:
    # The wrapper owns Godot; terminate this exact launched tree before draining pipes.
    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True, check=False)
    stdout, stderr = process.communicate(timeout=15)
    stderr += '\nTask-owned native test exceeded 240 seconds.\n'
output = stdout + stderr
(out / (script + '-' + renderer + ('-native' if graphical else '-headless') + '.log')).write_text(output, encoding='utf-8')
print(output)
raise SystemExit(process.returncode)
