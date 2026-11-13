"""Exact release regression on a new, isolated synthetic PostgreSQL17 fixture."""
import json
import secrets
import subprocess
import time

from rollout import DOCKER, WORK, OUT, release, unix, command, write

suffix=secrets.token_hex(4)
network='bmt-reuse-pg-net-'+suffix
container='bmt-reuse-pg-'+suffix
label='bmt.backend-reuse-fixture=20261026'
password=secrets.token_urlsafe(30)
pg_env=WORK/('pg-'+suffix+'.private.env')
app_env=WORK/('test-'+suffix+'.private.env')
pg_env.write_text('POSTGRES_DB=bmt_reuse\nPOSTGRES_USER=postgres\nPOSTGRES_PASSWORD='+password+'\n',encoding='utf-8')
app_env.write_text('PYTHONPATH=/app:/test-work/backend/tests\nBMT_TEST_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@'+container+':5432/bmt_reuse\n',encoding='utf-8')
created=False;network_created=False;identifier=None;result=None;cleaned=False
try:
 command([*DOCKER,'network','create','--internal','--label',label,network],'pg-network');network_created=True
 identifier=command([*DOCKER,'run','-d','--rm','--name',container,'--network',network,'--label',label,
   '--cpus=1','--memory=512m','--shm-size=64m','--tmpfs','/var/lib/postgresql/data:rw,size=268435456',
   '--env-file',unix(pg_env),'postgres:17-bookworm','-c','max_connections=40','-c','shared_buffers=32MB'],'pg-start')
 created=True
 for _ in range(40):
  ready=subprocess.run([*DOCKER,'exec',container,'pg_isready','-U','postgres'],capture_output=True,timeout=20)
  if ready.returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('Owned test PostgreSQL did not become ready')
 argv=[*DOCKER,'run','--rm','--network',network,'--cpus=1','--memory=768m','--label',label,
  '--env-file',unix(app_env),'--entrypoint=python',
  '--mount','type=bind,src='+unix(WORK/'test-work')+',dst=/test-work,readonly',
  '--mount','type=bind,src='+unix(OUT)+',dst=/results','--workdir','/test-work',release['tag'],
  '-m','pytest','backend/tests/test_backend_reuse.py','-q','-k','postgres','--tb=short',
  '-p','no:cacheprovider','--basetemp=/tmp/reuse-pg-tests','--junitxml=/results/postgres-tests.xml']
 result=subprocess.run(argv,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
 output=(result.stdout+result.stderr).replace(password,'[SYNTHETIC-TEST-PASSWORD]')
 (OUT/'postgres-tests.log').write_text(output,encoding='utf-8')
 print(output[-7000:],flush=True)
finally:
 if created:
  metadata=json.loads(command([*DOCKER,'inspect',container],'pg-inspect'))[0]
  assert metadata['Id']==identifier and metadata['Config']['Labels'].get('bmt.backend-reuse-fixture')=='20261026'
  command([*DOCKER,'stop',container],'pg-stop')
 if network_created:
  metadata=json.loads(command([*DOCKER,'network','inspect',network],'pg-network-inspect'))[0]
  assert metadata['Labels'].get('bmt.backend-reuse-fixture')=='20261026' and not metadata.get('Containers')
  command([*DOCKER,'network','rm',network],'pg-network-remove')
 for path in (pg_env,app_env):
  assert path.resolve().parent==WORK and not path.is_symlink();path.unlink()
 cleaned=True
 write(OUT/'postgres-gate.json',{'exit_code':result.returncode if result is not None else None,
   'owned_fixture_removed':cleaned,'postgres':'17-bookworm','real_player_data_used':False,
   'network':'New internal Docker network; no host port or pre-existing service changed'})
assert result is not None and result.returncode==0,'Exact-release PostgreSQL gates failed'
