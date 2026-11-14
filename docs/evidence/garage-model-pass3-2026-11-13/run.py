import os
import subprocess
import sys
from pathlib import Path
base = Path.cwd()/'build/garage-model-pass3-2026-11-13'

name, renderer, script, *extra = sys.argv[1:]
env = dict(os.environ, APPDATA=str(base/'profile/roaming'), LOCALAPPDATA=str(base/'profile/local'), BMT_API_URL='')
args = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe','--path',os.environ.get('GARAGE_FIXTURE_PROJECT','game'),'--audio-driver','Dummy']
args += ['--headless'] if renderer=='headless' else ['--rendering-method',renderer,'--position','10000,10000']
args += ['--script',script,'--',*extra]
with (base/(name+'.log')).open('w',encoding='utf-8') as log:
    process = subprocess.Popen([sys.executable,'scripts/run_no_crash_dialog.py','--',*args],env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True)
        raise
result = (base/(name+'.log')).read_text(encoding='utf-8')
print(result[-4000:])
if 'ERROR:' in result or 'FAIL:' in result: code = code or 2
sys.exit(code)
