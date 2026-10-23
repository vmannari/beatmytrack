"""Owned PostgreSQL product benchmark and isolated correctness reproductions."""
import argparse
import importlib.util
import json
import os
import secrets
import socket
import subprocess
import sys
import time
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/backend-product-review-2026-10-16'
FROZEN = ROOT / 'build/backend-latest-deploy-2026-10-16/frozen/backend'

def child():
    sys.path.insert(0, str(FROZEN))
    import bmt_backend
    assert Path(bmt_backend.__file__).resolve().is_relative_to(FROZEN.resolve())
    path=ROOT/'scripts/benchmark_product_analytics.py'
    source=path.read_text()
    anchor='Player(id=str(uuid4()), display_name="Bench " + str(index))'
    assert source.count(anchor)==1
    source=source.replace(anchor,'Player(id=str(uuid4()), display_name="Bench " + str(index), analytics_enabled=True)')
    b=types.ModuleType('owned_product_benchmark');b.__file__=str(path)
    # Explicit synthetic opt-in is required by the current ingestion contract.
    # The repository benchmark and runtime code remain untouched.
    exec(compile(source,str(path),'exec'),b.__dict__)
    results=[b.benchmark(n,postgres=True) for n in (10000,50000)]
    (OUT/'postgres-product-profile.json').write_text(json.dumps({'frozen_backend':True,'production_writes':0,'profiles':results},indent=2)+'\n')
    print(json.dumps([{'backlog_rows':r['backlog_rows'],**{k:r[k] for k in ('ingest_50','project_500','dashboard','idle_probe')}} for r in results]))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    config=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text())
    docker=config['docker']
    name='bmt-review-pg-'+secrets.token_hex(4)
    label='review-'+secrets.token_hex(8)
    password=secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
    def call(*args):
        return subprocess.run([*docker,*args],capture_output=True,text=True,encoding='utf-8',timeout=45)
    started=call('run','-d','--rm','--name',name,'--label','bmt.task='+label,
        '-p',f'127.0.0.1:{port}:5432','-e','POSTGRES_USER=review_test','-e','POSTGRES_DB=review_test',
        '-e','POSTGRES_PASSWORD='+password,'postgres:17')
    if started.returncode:
        raise RuntimeError('Owned PostgreSQL failed to start; no existing service changed')
    try:
        for _ in range(40):
            if call('exec',name,'pg_isready','-U','review_test').returncode==0:break
            time.sleep(.25)
        else:raise RuntimeError('Owned test database did not become ready')
        env={**os.environ,'BMT_TEST_DATABASE_URL':f'postgresql+psycopg://review_test:{password}@127.0.0.1:{port}/review_test'}
        tested=subprocess.run([sys.executable,'-X','utf8',str(Path(__file__)),'--child'],env=env,
            capture_output=True,text=True,encoding='utf-8',timeout=600)
        output=(tested.stdout+tested.stderr).replace(password,'[REDACTED]')
        (OUT/'postgres-profile.log').write_text(output,encoding='utf-8')
        print(output[-5000:])
        return tested.returncode
    finally:
        value=call('inspect',name,'--format','{{json .Config.Labels}}')
        assert value.returncode==0 and json.loads(value.stdout).get('bmt.task')==label
        assert call('stop',name).returncode==0
        print('Owned temporary PostgreSQL removed')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--child',action='store_true')
    args=parser.parse_args()
    if args.child:child()
    else:raise SystemExit(main())
