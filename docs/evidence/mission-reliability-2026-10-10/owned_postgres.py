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
name='bmt-mission-'+secrets.token_hex(4)
label='mission-'+secrets.token_hex(8)
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
    result=subprocess.run([sys.executable,'-m','pytest','backend/tests/test_mission_reliability.py','backend/tests/test_mission_processes.py','backend/tests/test_readiness.py','backend/tests/test_histogram_recovery.py','backend/tests/test_lap_bests.py','backend/tests/test_histogram_snapshots.py','-k','postgres and not sqlite','-q','--tb=short','--junitxml='+str(Path(__file__).with_name('postgres-final.xml'))],env=env,capture_output=True,text=True,timeout=420,check=False)
    Path(__file__).with_name('postgres-final.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    print(result.stdout[-10000:],flush=True)
    if result.returncode:raise RuntimeError('Mission PostgreSQL tests failed; receipt retained')

finally:
    checked=call('inspect',name,'--format','{{json .Config.Labels}}')
    if checked.returncode==0 and json.loads(checked.stdout).get('bmt.task')==label:
        stopped=call('stop',name);print('Owned PostgreSQL removed:',stopped.returncode==0)
    else:raise RuntimeError('Ownership changed; container retained')
