"""Import the frozen app using source-matched cache data and an owned profile."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

WORK = Path(__file__).resolve().parent
ROOT = WORK.parents[1]
source = ROOT / 'game/.godot'
target = WORK / 'frozen/game/.godot'
target.mkdir(parents=True, exist_ok=True)
for name in ('global_script_class_cache.cfg', 'uid_cache.bin'):
    if (source / name).is_file():
        shutil.copy2(source / name, target / name)
shutil.copytree(source / 'imported', target / 'imported', dirs_exist_ok=True)
env = dict(os.environ, APPDATA=str(WORK / 'profile/appdata'), LOCALAPPDATA=str(WORK / 'profile/localappdata'), BMT_API_URL='')
command = [sys.executable, str(ROOT / 'scripts/run_no_crash_dialog.py'), '--',
           r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe', '--headless', '--editor', '--import',
           '--path', str(WORK / 'frozen/game'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy']
with (WORK / 'import.log').open('w', encoding='utf-8') as output:
    result = subprocess.run(command, env=env, cwd=WORK / 'frozen', stdout=output, stderr=subprocess.STDOUT,
                            timeout=1500, creationflags=subprocess.CREATE_NO_WINDOW, check=False)
print('Frozen project import exit:', result.returncode)
raise SystemExit(result.returncode)
