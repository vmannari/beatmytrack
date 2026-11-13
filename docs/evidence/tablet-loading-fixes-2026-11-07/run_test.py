"""Pinned standard entry point, isolated offline data and bounded execution."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-loading-fixes-20261107'
EVIDENCE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('label')
parser.add_argument('script')
parser.add_argument('--native', choices=['gl_compatibility','mobile'])
parser.add_argument('--seconds', type=int, default=240)
parser.add_argument('--project',default='candidate',choices=['candidate','qualified'])
parser.add_argument('--test-argument')
args = parser.parse_args()
profile = OUT/'profiles'/args.label
user = profile/'appdata/Circuit01Lab'
user.mkdir(parents=True,exist_ok=True)
(user/'backend.cfg').write_text('[backend]\nurl=""\n')
env = os.environ.copy()
env.update(APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),BMT_API_URL='',GIT_OPTIONAL_LOCKS='0',
           BMT_LOADING_FIX_OUTPUT=str(OUT/'captures'/args.label),BMT_LOADING_OUTPUT=str(OUT/(args.label+'-results.json')))
env.update(GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='safe.directory',GIT_CONFIG_VALUE_0=str(OUT/args.project).replace('\\','/'))
env.pop('BMT_DEV_AUTH_KEY',None)
command = ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(OUT/args.project/'scripts/dev.ps1'),
           '-Action','TestScript','-ScriptPath','res://tests/'+args.script,
           '-CommandTimeoutSeconds',str(args.seconds)]
if args.native: command += ['-Graphical','-RenderingMethod',args.native]
if args.test_argument: command += ['-TestArgument',args.test_argument]
started = time.monotonic()
with (OUT/(args.label+'.log')).open('w',encoding='utf-8') as log:
    result = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=args.seconds+180,
                            creationflags=subprocess.CREATE_NO_WINDOW,check=False)
log_text = (OUT/(args.label+'.log')).read_text()
receipt = {'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started,
           'script_error':bool(re.search(r'SCRIPT ERROR|Parse Error|Compile Error',log_text)),
           'summaries':[line for line in log_text.splitlines() if 'checks' in line or 'FAIL' in line or 'Error' in line]}
expected = {'test_race_loading_first_lap.gd':'LOADING_FIRST_LAP_COMPLETE',
            'test_fitted_simple_cache.gd':'FITTED_SIMPLE_CACHE:'}.get(args.script)
receipt['completion_observed'] = expected in log_text if expected else None
(EVIDENCE/(args.label+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
raise SystemExit(1 if result.returncode or receipt['script_error'] or receipt['completion_observed'] is False else 0)
