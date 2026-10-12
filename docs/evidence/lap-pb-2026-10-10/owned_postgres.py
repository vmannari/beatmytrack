"""Run read-only algorithm benchmarks in an owned disposable PostgreSQL container."""
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
docker=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text())['docker']
name='bmt-lap-pb-'+secrets.token_hex(4)
label='lap-pb-'+secrets.token_hex(8)
password=secrets.token_urlsafe(24)
with socket.socket() as listener:
    listener.bind(('127.0.0.1',0));port=listener.getsockname()[1]
def call(*args):return subprocess.run([*docker,*args],capture_output=True,text=True,timeout=30,check=False)
if call('image','inspect','postgres:17').returncode:raise RuntimeError('Local PostgreSQL image missing; no download attempted')
started=call('run','-d','--rm','--name',name,'--label','bmt.task='+label,'-p',f'127.0.0.1:{port}:5432',
    '-e','POSTGRES_USER=review','-e','POSTGRES_DB=review','-e','POSTGRES_PASSWORD='+password,'postgres:17')
if started.returncode:raise RuntimeError('Owned review database did not start')
try:
    for _ in range(30):
        if call('exec',name,'pg_isready','-U','review').returncode==0:break
        time.sleep(.5)
    else:raise RuntimeError('Owned database unavailable')
    env={**os.environ,'PYTHONPATH':str(ROOT/'backend'),'PYTHONUTF8':'1',
         'BMT_HISTOGRAM_REVIEW_DATABASE_URL':f'postgresql+psycopg://review:{password}@127.0.0.1:{port}/review'}
    env['BMT_TEST_DATABASE_URL']=env['BMT_HISTOGRAM_REVIEW_DATABASE_URL']
    env['BMT_SCALABILITY_REVIEW_DATABASE_URL']=env['BMT_TEST_DATABASE_URL']
    tests=subprocess.run([sys.executable,'-m','pytest','backend/tests/test_lap_bests.py','-k','postgres and not sqlite','-q','--tb=short','--junitxml='+str(Path(__file__).with_name('postgres-lap-final.xml'))],env=env,capture_output=True,text=True,timeout=180,check=False)
    Path(__file__).with_name('postgres-lap-final.log').write_text(tests.stdout+tests.stderr,encoding='utf-8')
    print(tests.stdout[-5000:],flush=True)
    if tests.returncode:raise RuntimeError('Final PostgreSQL lap tests failed')
    result=subprocess.run([sys.executable,str(Path(__file__).with_name('probe.py'))],env=env,capture_output=True,text=True,timeout=600,check=False)
    Path(__file__).with_name('postgres-probe.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    print(result.stdout[-6000:],flush=True)
    if result.returncode:
        print(result.stderr[-3000:],flush=True)
        raise RuntimeError('Owned PostgreSQL benchmark failed')

finally:
    checked=call('inspect',name,'--format','{{json .Config.Labels}}')
    if checked.returncode==0 and json.loads(checked.stdout).get('bmt.task')==label:
        stopped=call('stop',name);print('Owned PostgreSQL removed:',stopped.returncode==0)
    else:raise RuntimeError('Ownership changed; container retained')
