"""Validate the task-only profiler against the real App in private desktop data."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-phase-profile-20261107'
EVIDENCE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('label')
parser.add_argument('--native',action='store_true')
parser.add_argument('--mode',default='races')
parser.add_argument('--editor-only',action='store_true')
args = parser.parse_args()
profile = OUT/'profiles'/args.label
user = profile/'appdata/Circuit01Lab'
user.mkdir(parents=True)
(user/'backend.cfg').write_text('[backend]\nurl=""\n')
(user/'tablet_phase_profile.json').write_text(json.dumps({'schema':1,'run':args.label,'mode':args.mode,
    'desktop_fixture':True,'themes':['pine'],'star':False,'pages':['rivalry'] if args.editor_only else ['rivalry','tracks','profile','garage'],
    'editor':True,'quit':True}))
env = os.environ.copy()
env.update(APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),BMT_API_URL='')
env.pop('BMT_DEV_AUTH_KEY',None)
command = ['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe',
    '--path',str(OUT/'isolated-current/game'),'--audio-driver','Dummy']
command += ['--rendering-method','gl_compatibility','--position','10000,10000','--resolution','1280x720'] if args.native else ['--headless']
started = time.monotonic()
paths = [p for p in (OUT/'isolated-current/game').rglob('*.gd') if '/.godot/' not in p.as_posix() and '/assets/' not in p.as_posix()]
import hashlib
before = {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
with (OUT/(args.label+'.log')).open('w',encoding='utf-8') as log:
    result = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240,
                            creationflags=subprocess.CREATE_NO_WINDOW,check=False)
text = (OUT/(args.label+'.log')).read_text()
receipt = {'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started,
           'source_changes':[str(p) for p in paths if hashlib.sha256(p.read_bytes()).hexdigest()!=before[str(p)]],
           'script_error':bool(re.search(r'SCRIPT ERROR|Parse Error|Compile Error',text)),
           'summaries':[line for line in text.splitlines() if 'TABLET_PHASE_COMPLETE' in line]}
report = user/'tablet-phase-20261107'/args.label/'result.json'
if report.exists():
    receipt['report'] = json.loads(report.read_text())
(EVIDENCE/(args.label+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='report'}))
if result.returncode or receipt['script_error'] or receipt['source_changes'] or not receipt.get('report') or receipt['report']['failures']:
    raise SystemExit(1)
