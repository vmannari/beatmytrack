"""Current monitor/publication/diagnostic tests in a newly owned PostgreSQL17."""
import argparse
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
    parser=argparse.ArgumentParser();parser.add_argument('--focused',action='store_true');args=parser.parse_args()
    config=ROOT/'.tools/gcp-staging/config.json'
    docker=json.loads(config.read_text())['docker'] if config.is_file() else ['docker']
    name='bmt-monitor-pg-'+secrets.token_hex(4);label='studio-monitor-'+secrets.token_hex(8);password=secrets.token_urlsafe(24)
    with socket.socket() as reservation:reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
    def call(*arguments):return subprocess.run([*docker,*arguments],capture_output=True,text=True,timeout=30,check=False)
    started=call('run','-d','--rm','--name',name,'--label','bmt.task='+label,'-p',f'127.0.0.1:{port}:5432',
        '-e','POSTGRES_USER=monitor_test','-e','POSTGRES_DB=monitor_test','-e','POSTGRES_PASSWORD='+password,'postgres:17')
    if started.returncode:raise RuntimeError('Owned PostgreSQL could not start; no existing service changed')
    try:
        for _ in range(30):
            if call('exec',name,'pg_isready','-U','monitor_test').returncode==0:break
            time.sleep(.5)
        else:raise RuntimeError('Owned PostgreSQL did not become ready')
        env=dict(os.environ);env['BMT_TEST_DATABASE_URL']=f'postgresql+psycopg://monitor_test:{password}@127.0.0.1:{port}/monitor_test'
        selected=['test_publication_intents','test_race_statistics','test_studio_catalogue','test_race_statistics_postgres']
        if not args.focused:selected += ['test_product_analytics','test_product_domain_events','test_client_quality','test_studio','test_studio_operations','test_studio_moderation','test_admin','test_admin_support','test_store_admin','test_maintenance','test_commerce','test_track_lifecycle']
        command=[sys.executable,'-m','pytest',*[f'tests/{filename}.py' for filename in selected],'-q','--tb=short']
        result=subprocess.run(command,cwd=ROOT/'backend',env=env,capture_output=True,text=True,check=False,timeout=600)
        output=(result.stdout+result.stderr).replace(password,'[REDACTED]')
        evidence=ROOT/'docs/evidence/studio-monitor-revision-2026-10-12';evidence.mkdir(parents=True,exist_ok=True)
        (evidence/('postgres-focused.log' if args.focused else 'postgres-regression.log')).write_text(output,encoding='utf-8')
        print(output[-8500:])
    finally:
        check=call('inspect',name,'--format','{{json .Config.Labels}}')
        if check.returncode==0 and json.loads(check.stdout).get('bmt.task')==label:
            print('Owned PostgreSQL removed:',call('stop',name).returncode==0)
        else:raise RuntimeError('Owned database label changed; leaving it untouched')
    return result.returncode


if __name__=='__main__':raise SystemExit(main())
