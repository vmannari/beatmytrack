"""Run current-source grant checks against an owned disposable PostgreSQL17."""
import json
from pathlib import Path
import secrets
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'build/sec09-sec10-fixes-2026-10-24'
OUT=ROOT/'docs/evidence/sec09-sec10-fixes-2026-10-24'
DOCKER=['wsl.exe','-d','Ubuntu','--','docker']
NETWORK='bmt-sec0910-fixture';PG=NETWORK+'-pg';LABEL='bmt.sec0910=20261024'
def unix(p):return '/mnt/'+p.drive[0].lower()+p.as_posix()[2:]
def run(args,**kw):
 value=subprocess.run([*DOCKER,*args],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=900,**kw)
 if value.returncode:
  (OUT/'postgres.log').write_text(value.stdout+value.stderr,encoding='utf-8')
  raise RuntimeError('Fixture failed; see PostgreSQL test log')
 return value.stdout

def main():
 password=secrets.token_hex(32)
 env=WORK/'fixture-pg.private.env';env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_fixture\n',encoding='utf-8')
 url='postgresql+psycopg://postgres:'+password+'@'+PG+':5432/bmt_fixture'
 appenv=WORK/'fixture-tests.private.env'
 appenv.write_text('PYTHONPATH=/review/backend:/review/backend/tests\nBMT_GCP_SETUP_TEST_DATABASE_URL='+url+
                   '\nBMT_TEST_DATABASE_URL='+url+'\nBMT_ORIGINAL_PRIVILEGES_SOURCE=/control.py\n',encoding='utf-8')
 run(['network','create','--internal','--label',LABEL,NETWORK]);created=False
 try:
  run(['run','-d','--rm','--name',PG,'--network',NETWORK,'--label',LABEL,'--env-file',unix(env),
       '--tmpfs','/var/lib/postgresql/data:rw','postgres:17-bookworm']);created=True
  for _ in range(60):
   if subprocess.run([*DOCKER,'exec',PG,'pg_isready','-U','postgres'],capture_output=True).returncode==0:break
   time.sleep(.25)
  else:raise RuntimeError('Fixture PostgreSQL startup deadline')
  receipt=json.loads((ROOT/'build/security-deploy-2026-10-24/receipt.private.json').read_text(encoding='utf-8'))
  output=run(['run','--rm','--network',NETWORK,'--label',LABEL,'--env-file',unix(appenv),
      '--mount','type=bind,src='+unix(ROOT/'backend')+',dst=/review/backend,readonly',
      '--mount','type=bind,src='+unix(OUT/'original_database_privileges.py')+',dst=/control.py,readonly',
      '--mount','type=bind,src='+unix(OUT)+',dst=/results','--workdir','/review/backend',
      '--entrypoint','python',receipt['local_tag'],'-m','pytest','tests/test_cloud_setup.py','tests/test_runtime_privileges.py',
      '-m','not godot','-q','--tb=short','--basetemp=/tmp/sec0910','-p','no:cacheprovider','--junitxml=/results/postgres.xml'])
  (OUT/'postgres.log').write_text(output,encoding='utf-8');print(output[-5000:])
 finally:
  if created:
   metadata=json.loads(run(['inspect',PG]))[0];assert metadata['Config']['Labels']['bmt.sec0910']=='20261024'
   run(['stop',PG])
  metadata=json.loads(run(['network','inspect',NETWORK]))[0];assert metadata['Labels']['bmt.sec0910']=='20261024'
  run(['network','rm',NETWORK])

if __name__=='__main__':main()
