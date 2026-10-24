"""Pinned native checks with fictional sessions in isolated application profiles."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/security-second-review-2026-10-24'
WORK=ROOT/'build/security-second-review-2026-10-24/native'
BIN=Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
version=subprocess.check_output([BIN,'--version'],text=True).strip()
assert version==(ROOT/'godot-version.txt').read_text(encoding='utf-8').strip()
results=[]
tests=sys.argv[1:] or ('test_security_ownership','test_session_rotation','test_backend_exception_recovery',
                       'test_draft_privacy','test_cost_downloads','test_account_privacy')
for test in tests:
    profile=WORK/test
    profile.mkdir(parents=True,exist_ok=True)
    env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
    env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile/'local'))
    script=str(OUT/(test+'.gd')) if (OUT/(test+'.gd')).exists() else 'res://tests/'+test+'.gd'
    command=[str(BIN),'--headless','--path',str(ROOT/'game'),'--script',script,
             '--log-file',str(OUT/(test+'-engine.log'))]
    started=time.monotonic()
    process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,
                             encoding='utf-8',errors='replace',env=env,cwd=ROOT)
    timed_out=False
    try:
        stdout,stderr=process.communicate(timeout=50)
    except subprocess.TimeoutExpired:
        timed_out=True
        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=10,check=False)
        if process.poll() is None:process.kill()
        stdout,stderr=process.communicate(timeout=5)
    output=stdout+stderr
    (OUT/(test+'.log')).write_text(output,encoding='utf-8')
    record={'test':test,'exit_code':process.returncode,'timed_out':timed_out,
            'seconds':round(time.monotonic()-started,3),
            'summaries':re.findall(r'[^\r\n]*\d+ checks[^\r\n]*',output),
            'failures':re.findall(r'^FAIL[^\r\n]*',output,re.M),
            'script_errors':len(re.findall('SCRIPT ERROR',output))}
    results.append(record)
    print(json.dumps(record),flush=True)
    filename=tests[0]+'-results.json' if sys.argv[1:] else 'native-results.json'
    (OUT/filename).write_text(json.dumps({'engine':version,'results':results},indent=2)+'\n',encoding='utf-8')
