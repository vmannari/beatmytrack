"""All touched Studio/product tests on a newly owned disposable PostgreSQL 17."""
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def main():
    config=ROOT/'.tools/gcp-staging/config.json'
    docker=json.loads(config.read_text())['docker'] if config.is_file() else ['docker']
    name='bmt-expansion-pg-'+secrets.token_hex(4);label='studio-expansion-'+secrets.token_hex(8)
    password=secrets.token_urlsafe(24)
    with socket.socket() as reservation:reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
    def call(*args):return subprocess.run([*docker,*args],capture_output=True,text=True,timeout=30,check=False)
    started=call('run','-d','--rm','--name',name,'--label','bmt.task='+label,'-p',f'127.0.0.1:{port}:5432',
        '-e','POSTGRES_USER=expansion_test','-e','POSTGRES_DB=expansion_test','-e','POSTGRES_PASSWORD='+password,'postgres:17')
    if started.returncode:raise RuntimeError('Owned PostgreSQL could not start; no existing service changed')
    try:
        for _ in range(30):
            if call('exec',name,'pg_isready','-U','expansion_test').returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('Owned PostgreSQL did not become ready')
        env=dict(os.environ);env['BMT_TEST_DATABASE_URL']=f'postgresql+psycopg://expansion_test:{password}@127.0.0.1:{port}/expansion_test'
        selected=['test_studio_operations','test_studio_moderation','test_studio_expansion_postgres','test_client_quality',
            'test_provider_proofs','test_product_analytics','test_product_domain_events','test_studio','test_admin','test_admin_support','test_store_admin']
        result=subprocess.run([sys.executable,'-m','pytest',*[f'tests/{name}.py' for name in selected],'-q','--tb=short'],
            cwd=ROOT/'backend',env=env,capture_output=True,text=True,check=False,timeout=300)
        output=(result.stdout+result.stderr).replace(password,'[REDACTED]')
        evidence=ROOT/'docs/evidence/studio-expansion-2026-10-11';evidence.mkdir(parents=True,exist_ok=True)
        (evidence/'postgres-tests.log').write_text(output,encoding='utf-8');print(output[-6000:])
    finally:
        checked=call('inspect',name,'--format','{{json .Config.Labels}}')
        if checked.returncode==0 and json.loads(checked.stdout).get('bmt.task')==label:
            print('Owned PostgreSQL removed:',call('stop',name).returncode==0)
        else:raise RuntimeError('Owned database label changed; leaving it untouched')
    return result.returncode


if __name__=='__main__':raise SystemExit(main())
