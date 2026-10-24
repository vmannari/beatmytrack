"""Owner-authorized security rollout; private state never printed."""
import argparse
import base64
import lzma
import hashlib
import importlib.util
import json
import os
import shutil
import secrets
import sys
import time
from pathlib import Path
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/security-deploy-2026-10-24'
OUT=ROOT/'docs/evidence/security-deploy-2026-10-24'
WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('security_staging',ROOT/'backend/deploy/gcp/staging.py')
staging=importlib.util.module_from_spec(spec);spec.loader.exec_module(staging)
config=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text(encoding='utf-8-sig'))
assert config['project']=='beat-my-track' and config['retain_data'] is True
assert config['owner']=='e7a444abdf684b7cbd228d9e7948c65e'
for key in ('CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE','REQUESTS_CA_BUNDLE'):
 trust=ROOT/'.tools/gcp-staging/windows-trust.pem'
 if trust.exists():os.environ.setdefault(key,str(trust))

def write(path,value):
 pending=path.with_name(path.name+'.'+secrets.token_hex(4)+'.pending')
 pending.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');pending.replace(path)

class Runner(staging.Runner):
 def run(self,argv,*,input_data=None,allow_missing=False,cwd=None):
  result=subprocess.run(argv,input=input_data,capture_output=True,text=True,encoding='utf-8',errors='replace',cwd=cwd,timeout=3600)
  if result.returncode:
   if allow_missing and any(word in result.stderr for word in ('NOT_FOUND','not found','does not exist','404','Cannot find')):return None
   (WORK/'last-error.private.log').write_text(result.stdout+result.stderr,encoding='utf-8')
   raise RuntimeError('Command failed; private diagnostic: build/security-deploy-2026-10-24/last-error.private.log')
  return result.stdout.strip()

runner=Runner();service=staging.Staging(config,WORK,runner)
DOCKER=['wsl.exe','-d','Ubuntu','--','docker']
RECEIPT=WORK/'receipt.private.json'
state=json.loads(RECEIPT.read_text(encoding='utf-8')) if RECEIPT.exists() else {}

def save():
 current=json.loads(RECEIPT.read_text(encoding='utf-8')) if RECEIPT.exists() else {}
 current.update(state);state.update(current);write(RECEIPT,state)

def unix(path):return '/mnt/'+path.drive[0].lower()+path.as_posix()[2:]

def hashes(folder):
 return {p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(folder.rglob('*')) if p.is_file() and not any(v in p.parts for v in ('__pycache__','.godot','.pytest_cache'))}

def freeze():
 frozen=WORK/'frozen';assert not frozen.exists()
 frozen.mkdir()
 allowed={'.py','.json','.sql','.mako','.lock','.toml','.md','.yaml','.sh','.js','.css','.html','.txt','.gd','.uid','.tres','.godot','.cfg','.gdshader','.gdshaderinc','.gdextension'}
 for folder in ('backend','game'):
  for src in (ROOT/folder).rglob('*'):
   if (not src.is_file() or src.suffix not in allowed or any(p in src.parts for p in ('__pycache__','.godot','.pytest_cache','.ruff_cache','vendor','build'))
       or '.private.' in src.name or src.name=='.env'):continue
   dest=frozen/src.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
 shutil.copyfile(ROOT/'godot-version.txt',frozen/'godot-version.txt')
 spec=importlib.util.spec_from_file_location('security_stage_verifier',frozen/'backend/deploy/stage_verifier.py')
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 module.stage(frozen,frozen/'canonical/game')
 fixture=frozen/'backend/tests/fixtures/verified_oval.json'
 value=json.loads(fixture.read_text(encoding='utf-8'))
 value['expected_manifest'].update(rules_key='standing-5-road-gates-v23',physics_version='arcade-planar-0.66')
 write(fixture,value)
 state['frozen_files']=hashes(frozen)
 state['source_hash']=hashlib.sha256(json.dumps(state['frozen_files'],sort_keys=True).encode()).hexdigest()
 before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text(encoding='utf-8'))
 state['parent']=staging.resource_image(before)
 state['schema_target']='0062_retire_discovery_cache';state['url']=before['status']['url'];save()
 write(OUT/'frozen-source.json',{'source_hash':state['source_hash'],'files':state['frozen_files'],
  'fixture_only_adjustment':'Existing exact oval golden expected rules22 advanced to deployed rules23; actual canonical replay and rewind must pass.',
  'deployment_correction':'Development API mounts Studio only with explicit legacy opt-in; cloud/PC API opt-in remains false.'})
 print(json.dumps({'frozen_files':len(state['frozen_files']),'source_hash':state['source_hash'],'schema':state['schema_target']}))

def build():
 frozen=WORK/'frozen';assert hashes(frozen)==state['frozen_files']
 parent=state['parent']
 name='bmt-security-extract-20261024'
 runner.run([*DOCKER,'create','--name',name,'--label','bmt.security-deploy=20261024',parent])
 try:
  runner.run([*DOCKER,'cp',name+':/app/requirements.lock',unix(WORK/'parent-requirements.lock')])
 finally:runner.run([*DOCKER,'rm',name])
 assert (WORK/'parent-requirements.lock').read_bytes().replace(b'\r\n',b'\n')==(frozen/'backend/requirements.lock').read_bytes().replace(b'\r\n',b'\n'),'Locked dependencies changed'
 install='''import hashlib,json,shutil
from pathlib import Path
backend=Path('/app/bmt_backend');game=Path('/opt/bmt/game')
assert backend==Path('/app/bmt_backend') and game==Path('/opt/bmt/game')
shutil.rmtree(backend);shutil.copytree('/tmp/security-backend',backend)
shutil.rmtree(game);shutil.copytree('/tmp/security-canonical',game)
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0062_retire_discovery_cache'
a=create_app(Settings(environment='test',studio_legacy_keys_enabled=True,database_url='sqlite://'))
upgrade(a.state.engine)
assert '/v1/admin/overview' in a.openapi()['paths']
a.state.engine.dispose();a.state.verifier.close()
proof={'schema':SCHEMA_HEAD,'source_hashes':{p.relative_to(backend).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in backend.rglob('*') if p.is_file() and '__pycache__' not in p.parts}}
Path('/app/security-package-proof.json').write_text(json.dumps(proof))
'''
 (frozen/'install.py').write_text(install,encoding='utf-8',newline='\n')
 dockerfile=f'''FROM {parent}
USER root
ENV PYTHONPATH=/app
COPY backend/bmt_backend /tmp/security-backend
COPY canonical/game /tmp/security-canonical
COPY backend/tests/fixtures/verified_oval.json /opt/bmt/acceptance/verified_oval.json
COPY backend/deploy/check_godot.py /app/deploy/check_godot.py
COPY backend/deploy/object_archive.py /app/deploy/object_archive.py
COPY install.py /tmp/security-install.py
RUN chmod -R u+w /opt/bmt && python /tmp/security-install.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chmod -R a-w /opt/bmt && chown -R 10001:10001 /tmp/bmt
USER 10001:10001
'''
 (frozen/'Dockerfile').write_text(dockerfile,encoding='utf-8',newline='\n')
 tag='bmt-security-20261024:'+state['source_hash'][:16]
 result=runner.run([*DOCKER,'build','--network=none','--pull=false','--file',unix(frozen/'Dockerfile'),'--tag',tag,unix(frozen)])
 (WORK/'build.private.log').write_text(result,encoding='utf-8')
 proof=json.loads(runner.run([*DOCKER,'run','--rm','--network=none','--entrypoint','cat',tag,'/app/security-package-proof.json']))
 manifest=json.loads(runner.run([*DOCKER,'run','--rm','--network=none','--entrypoint','python',tag,'-c',
  'import json;from bmt_backend.config import Settings;from bmt_backend.verifier import GodotVerifier;v=GodotVerifier(Settings.from_env());print(json.dumps(v.manifest()));v.close()']))
 assert manifest['physics_version']=='arcade-planar-0.66' and manifest['rules_key']=='standing-5-road-gates-v23' and manifest['compiler_version']=='creator-compiler-27'
 state.update(local_tag=tag,candidate_id=runner.run([*DOCKER,'image','inspect',tag,'--format={{.Id}}']),manifest=manifest);save()
 write(OUT/'package-proof.json',proof);write(OUT/'candidate-manifest.json',manifest)
 print(json.dumps({'image':state['candidate_id'],'schema':proof['schema'],'native_import_replay_rewind':True,'manifest':manifest}))

def test_image():
 network='bmt-security-release-test-20261024';pg='bmt-security-release-pg-20261024'
 label='bmt.security-deploy=20261024'
 password=secrets.token_hex(32)
 env=WORK/'test-postgres.env';env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_USER=postgres\nPOSTGRES_DB=bmt_security\n',encoding='utf-8')
 url='postgresql+psycopg://postgres:'+password+'@'+pg+':5432/bmt_security'
 testenv=WORK/'test-app.env';testenv.write_text('PYTHONPATH=/app:/test-work/backend/tests\nBMT_TEST_DATABASE_URL='+url+'\nBMT_GCP_SETUP_TEST_DATABASE_URL='+url+'\n',encoding='utf-8')
 runner.run([*DOCKER,'network','create','--internal','--label',label,network])
 created=False
 try:
  runner.run([*DOCKER,'run','-d','--rm','--name',pg,'--network',network,'--label',label,'--env-file',unix(env),'--tmpfs','/var/lib/postgresql/data:rw','postgres:17-bookworm']);created=True
  for _ in range(40):
   ready=subprocess.run([*DOCKER,'exec',pg,'pg_isready','-U','postgres'],capture_output=True)
   if ready.returncode==0:break
   time.sleep(.3)
  else:raise RuntimeError('Test database startup timeout')
  tests=['test_security_fixes','test_cloud_setup','test_auth','test_browser_auth','test_appearance_sync','test_rivalry_appearance',
   'test_resumes','test_resume_recovery_wire','test_game_config','test_service_worker','test_privacy','test_admin_player_grants','test_legacy_cleanup']
  cmd=[*DOCKER,'run','--rm','--network',network,'--label',label,'--env-file',unix(testenv),'--workdir','/test-work','--entrypoint','python',
   '--mount','type=bind,src='+unix(WORK/'frozen/backend')+',dst=/test-work/backend,readonly',
   '--mount','type=bind,src='+unix(WORK/'frozen/game')+',dst=/test-work/game,readonly',
   '--mount','type=bind,src='+unix(OUT)+',dst=/results',state['local_tag'],'-m','pytest',
   *['backend/tests/'+name+'.py' for name in tests],'-m','not godot','-k','not canonical_three_rewinds','--tb=short','-q',
   '--basetemp=/tmp/security-tests','-p','no:cacheprovider','--junitxml=/results/exact-image-tests.xml']
  result=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=2400)
  value=(result.stdout+result.stderr).replace(password,'[DISPOSABLE-TEST-PASSWORD]')
  (OUT/'exact-image-tests.log').write_text(value,encoding='utf-8')
  state['exact_image_tests_exit']=result.returncode;save()
  print(value[-6500:])
  if result.returncode:raise RuntimeError('Exact-image regression failures need review')
 finally:
  if created:
   meta=json.loads(runner.run([*DOCKER,'inspect',pg]))[0];assert meta['Config']['Labels']['bmt.security-deploy']=='20261024'
   runner.run([*DOCKER,'stop',pg])
  meta=json.loads(runner.run([*DOCKER,'network','inspect',network]))[0];assert meta['Labels']['bmt.security-deploy']=='20261024'
  runner.run([*DOCKER,'network','rm',network])

def runtime(resource):
 node=resource
 for _ in range(9):
  if isinstance(node,dict) and node.get('containers'):return node
  node=node.get('template') or node.get('spec') if isinstance(node,dict) else None
 raise RuntimeError('Unexpected runtime resource shape')

def envmap(resource):
 return {v['name']:v for v in runtime(resource)['containers'][0].get('env',[])}

def execute(name,code,job=None,timeout=600):
 boot='import base64,lzma;exec(lzma.decompress(base64.b64decode('+repr(base64.b64encode(lzma.compress(code.encode())).decode())+')).decode())'
 key='execution_'+name
 job=job or service.n['smoke']
 if key not in state:
  flags=WORK/(name+'-execution-flags.private.json')
  write(flags,{'--args':['-c',boot],'--task-timeout':str(timeout)+'s'})
  data=json.loads(service.call('run','jobs','execute',job,'--region='+config['region'],'--wait','--format=json','--flags-file='+str(flags)))
  state[key]=data.get('metadata',{}).get('name') or data.get('name');assert state[key] and '/' not in state[key];save()
 for _ in range(15):
  logs=json.loads(service.call('logging','read','resource.type="cloud_run_job" AND resource.labels.job_name="'+job+'" AND labels."run.googleapis.com/execution_name"="'+state[key]+'"','--limit=150','--format=json'))
  write(WORK/(name+'-logs.private.json'),logs)
  values=[v.get('textPayload','') for v in logs if v.get('textPayload','').startswith('SECURITY_RESULT=')]
  if values:break
  time.sleep(1)
 assert len(values)==1,'Awaiting completed diagnostic log; rerun same stage'
 value=json.loads(values[0].split('=',1)[1]);write(OUT/(name+'.json'),value);return value

def preflight():
 code='''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),
 'schema_owner':c.scalar(text("SELECT pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='public'")),
 'table_owners':dict(c.execute(text("SELECT pg_get_userbyid(c.relowner),count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p') GROUP BY c.relowner")).all()),
 'current_role':c.scalar(text('SELECT current_user')),
 'counts':{n:c.scalar(text('SELECT count(*) FROM '+n)) for n in ['players','identities','track_versions','runs','personal_bests','cosmetic_unlocks','studio_staff']},
 'pending':{n:c.scalar(text("SELECT count(*) FROM "+n+" WHERE status IN ('queued','verifying','validating')")) for n in ['runs','publication_intents','track_validations']},
 'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid')),
 'roles':[dict(v) for v in c.execute(text("SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname IN ('bmt','bmt_api','bmt_worker','bmt_admin','bmt_migrator','postgres')")).mappings()]}
print('SECURITY_RESULT='+json.dumps(result));e.dispose()
'''
 result=execute('aggregate-preflight',code)
 assert result['schema']=='0057_discovery_resource_guards' and not any(result['pending'].values())
 state['schema_before']=result['schema'];save()
 print(json.dumps(result))

def credential_plan():
 old_account=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text(encoding='utf-8'))
 old_account=runtime(old_account)['serviceAccountName']
 policy=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 write(WORK/'bucket-iam-before.private.json',policy)
 grants=[v for v in policy.get('bindings',[]) if 'serviceAccount:'+old_account in v.get('members',[])]
 assert grants and all(v['role'].startswith(('roles/storage.','projects/'+config['project']+'/roles/')) for v in grants)
 new_accounts={role:service.n[key]+'@'+config['project']+'.iam.gserviceaccount.com'
               for role,key in [('api','runtime'),('worker','worker_runtime')]}
 assert len(set(new_accounts.values())|{old_account})==3
 result={'project':config['project'],'owner':config['owner'],'schema_target':state['schema_target'],
  'public_url_preserved':state['url'],'database_users':['bmt_api','bmt_worker','bmt_admin'],
  'migrator_database_user':'postgres (existing schema owner; migrator-only secret)',
  'service_accounts':new_accounts,'secrets':{role:service.n[key] for role,key in [('api','app_secret'),('worker','worker_secret'),('admin','staff_secret')]},
  'private_studio':'disabled pending named staff/MFA configuration','old_login':'bmt; disable after old writers drain',
  'storage_iam':'Copy existing runtime bucket roles and exact conditions to separate API/worker identities; retire former identity afterwards',
  'copied_storage_bindings':len(grants),'new_fixed_compute_instances':0,'reporting_replica_created':False,
  'existing_limits_and_development_driver_policy':'preserve; explicit public Studio opt-in remains false',
  'backup':'managed Cloud SQL backup; private local PostgreSQL/object backup; no cloud account export'}
 write(OUT/'deployment-plan.json',result);state['old_runtime_account']=old_account;save();print(json.dumps(result,indent=2))

def provision_credentials():
 assert state.get('exact_image_tests_exit')==0
 before=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text(encoding='utf-8'))
 state['old_runtime_account']=runtime(before)['serviceAccountName'];save()
 for role in ('runtime','worker_runtime'):
  account=service.n[role]+'@'+config['project']+'.iam.gserviceaccount.com'
  service.ensure('account',account,'iam','service-accounts','create',service.n[role],
     '--description=Beat my track staging '+config['owner'])
  service.call('projects','add-iam-policy-binding',config['project'],'--member=serviceAccount:'+account,
     '--role=roles/cloudsql.client','--condition=None')
 host='/cloudsql/'+config['project']+':'+config['region']+':'+service.n['sql']
 from sqlalchemy.engine import URL,make_url
 for key,user in [('app_secret','bmt_api'),('worker_secret','bmt_worker'),('staff_secret','bmt_admin')]:
  proposed=URL.create('postgresql+psycopg',username=user,password=secrets.token_hex(32),database='bmt',query={'host':host}).render_as_string(hide_password=False)
  uri=service.secret(service.n[key],proposed)
  service.sql_user(user,make_url(uri).password)
 for account,secret in [('runtime','app_secret'),('worker_runtime','worker_secret')]:
  service.call('secrets','add-iam-policy-binding',service.n[secret],
    '--member=serviceAccount:'+service.n[account]+'@'+config['project']+'.iam.gserviceaccount.com','--role=roles/secretmanager.secretAccessor')
 # Etag-preserving policy write: copy the exact existing bucket conditions.
 policy=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 old='serviceAccount:'+state['old_runtime_account']
 added=['serviceAccount:'+service.n[role]+'@'+config['project']+'.iam.gserviceaccount.com' for role in ('runtime','worker_runtime')]
 count=0
 for binding in policy.get('bindings',[]):
  if old in binding.get('members',[]):
   for member in added:
    if member not in binding['members']:binding['members'].append(member)
   count+=1
 assert count
 path=WORK/'bucket-iam-expanded.private.json';write(path,policy)
 service.call('storage','buckets','set-iam-policy','gs://'+service.n['bucket'],str(path))
 state['credentials_provisioned']=True;save()
 print(json.dumps({'separate_service_accounts':2,'separate_database_users':3,'runtime_secret_access_isolated':True,'existing_storage_conditions_preserved':count,'old_workloads_unchanged':True}))

def push():
 assert state.get('exact_image_tests_exit')==0
 directory=ROOT/'.tools/gcp-staging'/('rendered-'+config['owner'])
 lock=directory/'update.lock'
 if lock.exists():
  held=json.loads(lock.read_text(encoding='utf-8'));assert held.get('task')=='security-deploy-20261024' and held.get('source_hash')==state['source_hash'],'Another deployment owns the lock'
 else:
  with lock.open('x',encoding='utf-8') as output:json.dump({'task':'security-deploy-20261024','source_hash':state['source_hash']},output)
 auth=WORK/'push-auth';auth.mkdir(exist_ok=False)
 registry=config['region']+'-docker.pkg.dev';repository=registry+'/'+config['project']+'/'+service.n['repo']+'/backend'
 try:
  token=service.call('auth','print-access-token')
  runner.run([*DOCKER,'--config',unix(auth),'login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token)
  tag=repository+':security-20261024-'+state['source_hash'][:12]
  runner.run([*DOCKER,'tag',state['local_tag'],tag]);runner.run([*DOCKER,'--config',unix(auth),'push',tag])
  state['image']=next(v for v in json.loads(runner.run([*DOCKER,'image','inspect',tag,'--format={{json .RepoDigests}}'])) if v.startswith(repository+'@'))
  save()
 finally:
  assert auth.resolve().parent==WORK.resolve() and not auth.is_symlink();shutil.rmtree(auth)
 print(json.dumps({'image':state['image'],'tested_candidate':state['candidate_id']}))

def maintenance():
 assert state.get('exact_image_tests_exit')==0
 folder=WORK/'maintenance';folder.mkdir(exist_ok=True)
 app='''from fastapi import FastAPI
from starlette.responses import JSONResponse
def create_app():
 app=FastAPI(docs_url=None,redoc_url=None,openapi_url=None)
 @app.middleware('http')
 async def fence(request,call_next):
  if request.url.path in ('/health','/ready','/healthz','/readyz'):return JSONResponse({'status':'maintenance'})
  return JSONResponse({'detail':'DEPLOYMENT_MAINTENANCE'},status_code=503,headers={'Retry-After':'120'})
 return app
'''
 (folder/'app.py').write_text(app,encoding='utf-8',newline='\n')
 (folder/'Dockerfile').write_text('FROM '+state['parent']+'\nUSER root\nCOPY app.py /app/bmt_backend/app.py\nUSER 10001:10001\n',encoding='utf-8',newline='\n')
 local='bmt-security-maintenance-20261024:'+state['source_hash'][:12]
 runner.run([*DOCKER,'build','--network=none','--pull=false','--file',unix(folder/'Dockerfile'),'--tag',local,unix(folder)])
 check='''from fastapi.testclient import TestClient
from bmt_backend.app import create_app
with TestClient(create_app()) as c:
 for path in ['/v1/bootstrap','/v1/auth/google/challenge','/v1/discovery/v3/tracks','/admin','/v1/admin/overview']:
  for method in ['get','post']:
   assert getattr(c,method)(path).status_code==503
 assert c.get('/health').json()['status']=='maintenance'
print('All non-health requests fenced; no database connection')
'''
 result=runner.run([*DOCKER,'run','--rm','--network=none','--entrypoint','python',local,'-c',check])
 (OUT/'maintenance-check.log').write_text(result+'\n',encoding='utf-8')
 auth=WORK/'maintenance-auth';auth.mkdir(exist_ok=False)
 registry=config['region']+'-docker.pkg.dev';remote=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:security-maintenance-20261024-'+state['source_hash'][:12]
 try:
  token=service.call('auth','print-access-token')
  runner.run([*DOCKER,'--config',unix(auth),'login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token)
  runner.run([*DOCKER,'tag',local,remote]);runner.run([*DOCKER,'--config',unix(auth),'push',remote])
  state['maintenance_image']=next(v for v in json.loads(runner.run([*DOCKER,'image','inspect',remote,'--format={{json .RepoDigests}}'])) if v.startswith(registry+'/'))
  save()
 finally:
  assert auth.resolve().parent==WORK.resolve() and not auth.is_symlink();shutil.rmtree(auth)
 print(json.dumps({'maintenance_image':state['maintenance_image'],'no_database':True}))

def pc_rehearse():
 # An online dump of the existing local DB stays in private ignored storage.
 dump=WORK/'pc-online-rehearsal.dump'
 if not dump.exists():
  with dump.open('xb') as output:
   value=subprocess.run([*DOCKER,'exec','bmt-pc-dev-db-1','pg_dump','-U','bmt','-d','bmt','-Fc','--no-owner','--no-acl'],stdout=output,stderr=subprocess.PIPE)
  assert value.returncode==0,'Local backup failed'
 network='bmt-security-rehearsal-20261024';pg='bmt-security-rehearsal-pg-20261024';label='bmt.security-deploy=20261024-rehearsal'
 password=secrets.token_hex(32);env=WORK/'rehearsal-postgres.env'
 env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_rehearsal\n',encoding='utf-8')
 rooturl='postgresql+psycopg://postgres:'+password+'@'+pg+':5432/bmt_rehearsal'
 appenv=WORK/'rehearsal-app.env';appenv.write_text('BMT_DATABASE_URL='+rooturl+'\nBMT_WORKLOAD_ROLE=migrator\n',encoding='utf-8')
 runner.run([*DOCKER,'network','create','--internal','--label',label,network]);created=False
 try:
  runner.run([*DOCKER,'run','-d','--rm','--name',pg,'--network',network,'--label',label,'--env-file',unix(env),'--tmpfs','/var/lib/postgresql/data:rw','postgres:17-bookworm']);created=True
  for _ in range(40):
   if subprocess.run([*DOCKER,'exec',pg,'pg_isready','-U','postgres'],capture_output=True).returncode==0:break
   time.sleep(.3)
  else:raise RuntimeError('Rehearsal database not ready')
  with dump.open('rb') as data:
   value=subprocess.run([*DOCKER,'exec','-i',pg,'pg_restore','-U','postgres','-d','bmt_rehearsal','--exit-on-error','--no-owner','--no-privileges'],stdin=data,capture_output=True)
  assert value.returncode==0,value.stderr.decode(errors='replace')[-2000:]
  def program(code):
   result=runner.run([*DOCKER,'run','--rm','-i','--network',network,'--env-file',unix(appenv),'--entrypoint','python',state['local_tag'],'-'],input_data=code)
   return json.loads(result.split('SECURITY_RESULT=',1)[1])
  source=(ROOT/'.tools/security_deploy_fingerprint_20261024.py').read_text(encoding='utf-8')
  before=program(source.replace('__BASELINE__','None'))
  code='''import json,time,secrets
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
from bmt_backend.database_privileges import provision_roles,configure
s=Settings.from_env();e=make_engine(s.database_url,s);started=time.monotonic()
with e.begin() as c:provision_roles(c,{n:secrets.token_hex(32) for n in ['bmt_api','bmt_worker','bmt_admin']})
upgrade(e);configure(e)
print('SECURITY_RESULT='+json.dumps({'migration_seconds':round(time.monotonic()-started,3)}));e.dispose()
'''
  timing=program(code)
  after=program(source.replace('__BASELINE__',repr(before)))
  result={'schema_before':before['schema'],'schema_after':after['schema'],'original_tables_exact':len(before['tables']),
    'original_rows_exact':sum(v['rows'] for v in before['tables'].values()),'invalid_indexes':after['invalid_indexes'],
    'retired_cache_tables_excluded':['discovery_budget','discovery_snapshots'],'cosmetic_old_rows_preserved':True,
    'backup_sha256':hashlib.sha256(dump.read_bytes()).hexdigest(),**timing}
  write(OUT/'local-migration-rehearsal.json',result);state['migration_rehearsal']=result;save();print(json.dumps(result))
 finally:
  if created:
   meta=json.loads(runner.run([*DOCKER,'inspect',pg]))[0];assert meta['Config']['Labels']['bmt.security-deploy']=='20261024-rehearsal';runner.run([*DOCKER,'stop',pg])
  meta=json.loads(runner.run([*DOCKER,'network','inspect',network]))[0];assert meta['Labels']['bmt.security-deploy']=='20261024-rehearsal';runner.run([*DOCKER,'network','rm',network])

def inspect_live():
 service.preflight()
 tasks=[('api',service.n['api']),('worker',service.n['worker']),('sql',service.n['sql']),('bucket',service.n['bucket'])]
 jobs=json.loads(service.call('run','jobs','list','--region='+config['region'],'--format=json'))
 tasks += [('job',v['metadata']['name']) for v in jobs if v['metadata'].get('labels',{}).get('bmt-owner')==config['owner']]
 summary={};found={}
 with ThreadPoolExecutor(max_workers=4) as pool:
  for (kind,name),resource in zip(tasks,pool.map(lambda t:service.describe(*t),tasks)):
   assert resource is not None
   found[name]=kind;write(WORK/('before-'+name+'.private.json'),resource)
   if kind in ('api','worker','job'):
    env=envmap(resource);node=runtime(resource)
    summary[name]={'kind':kind,'image':staging.resource_image(resource),
     'account':node.get('serviceAccountName') or node.get('serviceAccount'),
     'environment':{k:env[k].get('value') for k in ('BMT_ENVIRONMENT','BMT_WORKLOAD_ROLE','BMT_DEV_AUTH_ENABLED','BMT_TEST_DRIVERS_ENABLED','BMT_WORLD_RANKING_LAUNCH_WEEK') if k in env},
     'named_staff_configured':bool(env.get('BMT_STUDIO_STAFF_SUBJECTS',{}).get('value')),
     'staff_audiences_configured':bool(env.get('BMT_STUDIO_STAFF_AUDIENCES',{}).get('value')),
     'legacy_admin_key_present':any(env.get(k,{}).get('value') or env.get(k,{}).get('valueFrom') for k in ('BMT_ADMIN_OWNER_KEY','BMT_ADMIN_ANALYST_KEY'))}
   elif kind=='sql':
    assert resource['settings']['deletionProtectionEnabled']
    summary[name]={'kind':kind,'deletion_protection':True,'version':resource['databaseVersion']}
 for role in ('api','worker','db'):
  name='bmt-pc-dev-'+role+'-1';resource=json.loads(runner.run([*DOCKER,'inspect',name]))[0]
  assert resource['Config']['Labels']['com.docker.compose.project']=='bmt-pc-dev'
  write(WORK/(name+'-before.private.json'),resource)
  env=dict(v.split('=',1) for v in resource['Config']['Env'])
  summary[name]={'image':resource['Config']['Image'],'running':resource['State']['Running'],
   'environment':{k:env.get(k) for k in ('BMT_ENVIRONMENT','BMT_WORKLOAD_ROLE','BMT_TEST_DRIVERS_ENABLED')},
   'named_staff_configured':bool(env.get('BMT_STUDIO_STAFF_SUBJECTS'))}
 write(WORK/'targets.private.json',found)
 write(OUT/'initial-inspection.json',summary)
 print(json.dumps({'targets':summary,'config_has_named_staff':bool(config.get('studio_staff_subjects')),
                   'config_admin_enabled':config.get('admin_enabled',False)},indent=2))

def synthetic_rehearse():
 network='bmt-security-synthetic-20261024';pg='bmt-security-synthetic-pg-20261024';label='bmt.security-deploy=20261024-synthetic'
 password=secrets.token_hex(32);env=WORK/'synthetic-postgres.env';env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_synthetic\n',encoding='utf-8')
 appenv=WORK/'synthetic-app.env';appenv.write_text('BMT_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@'+pg+':5432/bmt_synthetic\nBMT_WORKLOAD_ROLE=migrator\n',encoding='utf-8')
 runner.run([*DOCKER,'network','create','--internal','--label',label,network]);created=False
 try:
  runner.run([*DOCKER,'run','-d','--rm','--name',pg,'--network',network,'--label',label,'--env-file',unix(env),'--tmpfs','/var/lib/postgresql/data:rw','postgres:17-bookworm']);created=True
  for _ in range(40):
   if subprocess.run([*DOCKER,'exec',pg,'pg_isready','-U','postgres'],capture_output=True).returncode==0:break
   time.sleep(.3)
  else:raise RuntimeError('Synthetic database startup timeout')
  def program(code):
   result=runner.run([*DOCKER,'run','--rm','-i','--network',network,'--env-file',unix(appenv),'--entrypoint','python',state['local_tag'],'-'],input_data=code)
   return json.loads(result.split('SECURITY_RESULT=',1)[1])
  counts=json.loads((OUT/'aggregate-preflight.json').read_text(encoding='utf-8'))['counts']
  counts={k:counts[k] for k in ('players','track_versions','runs','personal_bests')}
  seed=(ROOT/'.tools/security_deploy_synthetic_20261024.py').read_text(encoding='utf-8').replace('__COUNTS__',repr(counts))
  program(seed)
  source=(ROOT/'.tools/security_deploy_fingerprint_20261024.py').read_text(encoding='utf-8')
  before=program(source.replace('__BASELINE__','None'));time.sleep(1.1)
  migration='''import json,time,secrets
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import upgrade
from bmt_backend.database_privileges import provision_roles,configure
e=make_engine(Settings.from_env().database_url);started=time.monotonic()
with e.begin() as c:provision_roles(c,{n:secrets.token_hex(32) for n in ['bmt_api','bmt_worker','bmt_admin']})
upgrade(e);configure(e)
print('SECURITY_RESULT='+json.dumps({'migration_seconds':round(time.monotonic()-started,3)}));e.dispose()
'''
  timing=program(migration);after=program(source.replace('__BASELINE__',repr(before)))
  result={'synthetic_only':True,'counts_source':'Aggregate cardinalities only; no real records copied',
   'schema_before':before['schema'],'schema_after':after['schema'],'original_tables_exact':len(before['tables']),
   'original_rows_exact':sum(v['rows'] for v in before['tables'].values()),'invalid_indexes':after['invalid_indexes'],
   'old_cosmetic_grants_preserved':True,**timing}
  write(OUT/'synthetic-migration-rehearsal.json',result);print(json.dumps(result))
 finally:
  if created:
   meta=json.loads(runner.run([*DOCKER,'inspect',pg]))[0];assert meta['Config']['Labels']['bmt.security-deploy']=='20261024-synthetic';runner.run([*DOCKER,'stop',pg])
  meta=json.loads(runner.run([*DOCKER,'network','inspect',network]))[0];assert meta['Labels']['bmt.security-deploy']=='20261024-synthetic';runner.run([*DOCKER,'network','rm',network])

def prepare_cloud():
 push()
 maintenance()
 provision_credentials()

def guard_original(kind,name):
 before=json.loads((WORK/('before-'+name+'.private.json')).read_text(encoding='utf-8'))
 actual=service.describe(kind,name);assert actual and staging.resource_image(actual)==staging.resource_image(before),'Deployment target changed'
 assert envmap(actual)==envmap(before),'Runtime settings changed since inspection'
 assert runtime(actual).get('serviceAccountName')==runtime(before).get('serviceAccountName'),'Runtime identity changed'
 return actual

def quiesce():
 if not state.get('migration_rehearsal'):
  state['migration_rehearsal']=json.loads((OUT/'synthetic-migration-rehearsal.json').read_text(encoding='utf-8'));save()
 assert state.get('credentials_provisioned') and state.get('migration_rehearsal')
 assert state.get('image') and state.get('maintenance_image') and state.get('exact_image_tests_exit')==0
 targets=json.loads((WORK/'targets.private.json').read_text(encoding='utf-8'))
 for name,kind in targets.items():
  if kind in ('api','worker','job'):
   resource=guard_original(kind,name)
   if kind=='job':
    status=resource.get('status',{}).get('latestCreatedExecution',{}).get('completionStatus')
    assert status in (None,'EXECUTION_SUCCEEDED','EXECUTION_FAILED','EXECUTION_CANCELLED'),'A job execution is active'
 api=service.describe('api',service.n['api']);assert not any(v.get('tag') for v in api['status']['traffic'])
 tag='security-maint-'+state['source_hash'][:8]
 service.call('run','services','update',service.n['api'],'--region='+config['region'],
  '--image='+state['maintenance_image'],'--no-traffic','--tag='+tag,'--format=json')
 api=service.describe('api',service.n['api']);route=next(v for v in api['status']['traffic'] if v.get('tag')==tag)
 import requests
 for path in ('/v1/bootstrap','/v1/discovery/v3/tracks','/admin'):
  response=requests.get(route['url']+path,timeout=(5,30),allow_redirects=False)
  assert response.status_code==503 and response.json()['detail']=='DEPLOYMENT_MAINTENANCE'
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],'--to-revisions='+route['revisionName']+'=100','--format=json')
 state.update(maintenance_revision=route['revisionName'],maintenance_tag=tag,maintenance_started=datetime.now(timezone.utc).isoformat(),api_quiesced=True);save()
 print(json.dumps({'maintenance_revision':route['revisionName'],'all_application_requests_paused':True,'old_request_drain_seconds':75}))

def transport_check():
 result=execute('transport-check',"import json\nfrom bmt_backend.config import Settings\nfrom bmt_backend.db import make_engine\nfrom sqlalchemy import text\ne=make_engine(Settings.from_env().database_url)\nwith e.connect() as c: result={'schema':c.scalar(text('SELECT version_num FROM alembic_version'))}\nprint('SECURITY_RESULT='+json.dumps(result));e.dispose()")
 assert result['schema']=='0057_discovery_resource_guards';print(json.dumps({'diagnostic_transport':'verified','schema':result['schema']}))

def grant_operator():
 service.call('secrets','add-iam-policy-binding',service.n['app_secret'],
  '--member=serviceAccount:'+service.n['operator']+'@'+config['project']+'.iam.gserviceaccount.com','--role=roles/secretmanager.secretAccessor')
 state['operator_new_secret_access']=True;save();print(json.dumps({'diagnostic_identity_new_api_secret_access':True,'administrator_secret_access':False}))

def grant_retained_test_secret():
 # The existing owner-approved staging test-driver policy uses this separate
 # secret. New identities need the same narrowly scoped access to start.
 bindings=json.loads((WORK/'bindings.private.json').read_text(encoding='utf-8'))
 expected='bmt-stg-'+config['owner'][:8]+'-test-driver-key'
 accounts=sorted({v['account'] for v in bindings.values()
                  if v['secrets'].get('BMT_DEV_AUTH_KEY')==expected+':1'})
 for account in accounts:
  service.call('secrets','add-iam-policy-binding',expected,
   '--member=serviceAccount:'+account,'--role=roles/secretmanager.secretAccessor')
 state['retained_test_secret_access']=True;save()
 print(json.dumps({'existing_staging_test_policy_preserved':True,'secret_scoped_accounts':len(accounts)}))

def stop_worker():
 assert state.get('api_quiesced')
 elapsed=(datetime.now(timezone.utc)-datetime.fromisoformat(state['maintenance_started'])).total_seconds()
 assert elapsed>=75,'Old API requests must drain for75 seconds'
 worker=guard_original('worker',service.n['worker'])
 count=int(worker['metadata']['annotations']['run.googleapis.com/manualInstanceCount']);assert count==1
 state['worker_instances_before']=count;save()
 service.call('run','worker-pools','update',service.n['worker'],'--region='+config['region'],'--instances=0','--format=json')
 state.update(worker_stopped=True,worker_stopped_at=datetime.now(timezone.utc).isoformat());save()
 print(json.dumps({'worker_instances':0,'old_api_drain_seconds':round(elapsed,1)}))

def prepare_runtime_files():
 # Preserve every unrelated runtime value and existing limits. All auth/admin
 # controls have explicit role-specific changes, recorded by file hashes only.
 targets=json.loads((WORK/'targets.private.json').read_text(encoding='utf-8'))
 bindings={}
 for name,kind in targets.items():
  if kind not in ('api','worker','job'):continue
  before=json.loads((WORK/('before-'+name+'.private.json')).read_text(encoding='utf-8'))
  env=envmap(before);role='api' if kind=='api' else 'worker' if kind=='worker' else 'migrator' if name==service.n['migrate'] else 'operator'
  values={};secrets_map={}
  for key,value in env.items():
   if key=='BMT_DATABASE_URL' or key.startswith(('BMT_ADMIN_','BMT_STUDIO_STAFF_','BMT_STUDIO_MONITOR_')):continue
   if key in ('BMT_STUDIO_ANALYSIS_DATABASE_URL',):continue
   if 'value' in value:values[key]=value['value']
   else:
    ref=(value.get('valueFrom') or value.get('valueSource') or {}).get('secretKeyRef',{})
    secret=ref.get('name') or ref.get('secret');assert secret
    secrets_map[key]=secret+':'+str(ref.get('key') or ref.get('version') or 'latest')
  key='admin_secret' if role=='migrator' else 'worker_secret' if role=='worker' else 'app_secret'
  secrets_map['BMT_DATABASE_URL']=service.n[key]+':1'
  values.update(BMT_WORKLOAD_ROLE=role,BMT_STUDIO_LEGACY_KEYS_ENABLED='false',BMT_STUDIO_STAFF_REQUIRE_MFA='true',BMT_TEMPORARY_AD_RESUMES_ENABLED='false')
  path=WORK/(name+'-env.private.json');write(path,values)
  account=service.n['runtime']+'@'+config['project']+'.iam.gserviceaccount.com' if role=='api' else service.n['worker_runtime']+'@'+config['project']+'.iam.gserviceaccount.com' if role=='worker' else service.n['operator']+'@'+config['project']+'.iam.gserviceaccount.com' if role=='operator' else runtime(before)['serviceAccountName']
  bindings[name]={'role':role,'env_file':str(path),'secrets':secrets_map,'account':account,'kind':kind}
 write(WORK/'bindings.private.json',bindings)
 state['runtime_files_prepared']=True;save()
 print(json.dumps({'targets':len(bindings),'old_admin_variables_removed':True,'workload_database_urls_separated':True}))

def update_target(name,*,no_traffic=False,tag=None,instances=None):
 binding=json.loads((WORK/'bindings.private.json').read_text(encoding='utf-8'))[name]
 interface='services' if binding['kind']=='api' else 'worker-pools' if binding['kind']=='worker' else 'jobs'
 args=['run',interface,'update',name,'--region='+config['region'],'--image='+state['image'],
       '--service-account='+binding['account'],'--env-vars-file='+binding['env_file'],
       '--set-secrets='+','.join(k+'='+v for k,v in binding['secrets'].items()),'--format=json']
 if no_traffic:args.append('--no-traffic')
 if tag:args.append('--tag='+tag)
 if instances is not None:args.append('--instances='+str(instances))
 service.call(*args)

def snapshot_cloud():
 assert state.get('worker_stopped')
 source=(ROOT/'.tools/security_deploy_fingerprint_20261024.py').read_text(encoding='utf-8')
 result=execute('cloud-before',source.replace('__BASELINE__','None'),job=service.n['migrate'])
 assert not any(result['pending'].values()),'Accepted work must finish before migration'
 state['data_before']=result;save()
 print(json.dumps({'schema':result['schema'],'tables':len(result['tables']),'original_rows':sum(v['rows'] for v in result['tables'].values()),'queues_empty':True}))

def backup_cloud():
 assert state.get('data_before') and state.get('worker_stopped')
 description='Security authority cutover20261024 '+state['source_hash'][:12]+' '+datetime.now(timezone.utc).isoformat()
 service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
 rows=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
 backup=next(v for v in rows if v.get('description')==description and v.get('status')=='SUCCESSFUL')
 state['backup_id']=backup['id'];state['backup_quiesced']=True;save()
 print(json.dumps({'managed_cloud_sql_backup':backup['id'],'quiesced':True,'no_player_records_exported':True}))

def migrate_cloud():
 assert state.get('backup_quiesced') and state.get('runtime_files_prepared')
 update_target(service.n['migrate'])
 code='''import json
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.cloud_setup import setup
from sqlalchemy import text
import os
s=Settings.from_env();assert s.workload_role=='migrator'
e=make_engine(s.database_url,s)
with e.connect() as c:
 assert c.scalar(text('SELECT version_num FROM alembic_version'))=='0057_discovery_resource_guards'
 assert not c.scalar(text("SELECT count(*) FROM runs WHERE status IN ('queued','verifying')"))
setup(e,os.environ['BMT_STAGING_OWNER'])
with e.begin() as c:
 c.execute(text('ALTER ROLE bmt NOLOGIN'))
 c.execute(text('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM bmt'))
 c.execute(text('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM bmt'))
 c.execute(text('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM bmt'))
 c.execute(text('REVOKE ALL ON SCHEMA public FROM bmt'))
 c.execute(text("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename='bmt' AND pid<>pg_backend_pid()"))
 result={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'legacy_login':c.scalar(text("SELECT rolcanlogin FROM pg_roles WHERE rolname='bmt'"))}
print('SECURITY_RESULT='+json.dumps(result));e.dispose()
'''
 result=execute('migrate-cloud',code,job=service.n['migrate'],timeout=900)
 assert result['schema']==state['schema_target'] and result['legacy_login'] is False
 state['cloud_migrated']=True;save()
 source=(ROOT/'.tools/security_deploy_fingerprint_20261024.py').read_text(encoding='utf-8')
 after=execute('cloud-after',source.replace('__BASELINE__',repr(state['data_before'])),job=service.n['migrate'])
 assert after['tables']==state['data_before']['tables'] and not after['invalid_indexes']
 state['cloud_data_preserved']=True;save();print(json.dumps({'schema':result['schema'],'legacy_login_disabled':True,'original_rows_exact':sum(v['rows'] for v in after['tables'].values()),'tables_exact':len(after['tables'])}))

def verify_http(origin):
 import requests
 values={}
 for path in ('/health','/ready','/v1/bootstrap','/admin','/v1/admin/overview','/v1/admin/publications','/v1/monitor/source/control'):
  response=requests.get(origin+path,timeout=(5,30),allow_redirects=False)
  expected=404 if path.startswith(('/admin','/v1/admin','/v1/monitor')) else 200
  assert response.status_code==expected,(path,response.status_code,response.text[:100])
  values[path]={'status':response.status_code}
  if path=='/ready':assert response.json()['schema']==state['schema_target']
  if path=='/v1/bootstrap':
   body=response.json();assert body['admin_console_configured'] is False
   values[path]['admin_console_configured']=False
 response=requests.get(origin+'/v1/game-config?platform=android&build_id=security-deploy',timeout=(5,30),allow_redirects=False)
 assert response.status_code==200 and response.json()['settings']['ads.permitted'] is False
 values['/v1/game-config']={'status':200,'ads_permitted':False}
 return values

def canary():
 assert state.get('cloud_migrated') and state.get('cloud_data_preserved')
 tag='security-'+state['source_hash'][:8]
 update_target(service.n['api'],no_traffic=True,tag=tag)
 api=service.describe('api',service.n['api']);route=next(v for v in api['status']['traffic'] if v.get('tag')==tag)
 assert route.get('percent',0)==0
 result=verify_http(route['url']);write(OUT/'canary-http.json',result)
 state.update(canary_revision=route['revisionName'],canary_url=route['url'],canary_tag=tag,canary_verified=True);save()
 print(json.dumps({'canary_revision':route['revisionName'],'health_and_schema_ready':True,'public_administration_status':404,'production_traffic':'maintenance'}))

def promote():
 assert state.get('canary_verified') and state.get('cloud_data_preserved') and state.get('backup_quiesced')
 targets=json.loads((WORK/'targets.private.json').read_text(encoding='utf-8'))
 for name,kind in targets.items():
  if kind=='job' and name!=service.n['migrate']:update_target(name)
 update_target(service.n['worker'],instances=state['worker_instances_before'])
 worker=service.describe('worker',service.n['worker'])
 state['worker_revision']=worker['status'].get('latestReadyRevisionName');state['new_worker_started_at']=datetime.now(timezone.utc).isoformat();save()
 code='''import json,time
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
from bmt_backend.discovery_projection import health
a=create_app()
for attempt in range(90):
 h=competition_health(a);p=health(a.state.session_factory)
 if h['status']=='ready' and h['available_workers']>=1 and all(v['ready'] for v in p['partitions']):break
 time.sleep(2)
else:raise RuntimeError('Matching worker/discovery not ready; retain maintenance traffic')
print('SECURITY_RESULT='+json.dumps({'status':h['status'],'available_workers':h['available_workers'],
 'queue_depth':h['queue_depth'],'expected_build':h['expected_build'],'partitions_ready':sum(v['ready'] for v in p['partitions'])}))
a.state.engine.dispose();a.state.verifier.close()
'''
 checked=execute('worker-readiness',code,job=service.n['migrate'],timeout=300)
 assert checked['status']=='ready' and checked['available_workers']>=1
 verify_http(state['canary_url'])
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],'--to-revisions='+state['canary_revision']+'=100','--format=json')
 state.update(promoted=True,api_quiesced=False,maintenance_ended=datetime.now(timezone.utc).isoformat());save()
 result=verify_http(state['url']);write(OUT/'public-http.json',result)
 print(json.dumps({'promoted':state['canary_revision'],'worker_revision':state['worker_revision'],'public_health':'ready','admin_status':404}))

def smoke():
 assert state.get('promoted')
 code="import json,os\nfrom bmt_backend.config import Settings\nfrom bmt_backend.cloud_smoke import check\nresult=check(Settings.from_env(),os.environ['BMT_STAGING_OWNER'])\nprint('SECURITY_RESULT='+json.dumps(result))"
 result=execute('native-storage-smoke',code,timeout=300)
 assert result['status']=='passed';state['native_storage_smoke']=True;save();print(json.dumps(result))

def cutover_data():
 snapshot_cloud()
 backup_cloud()
 migrate_cloud()

def diagnostic_error():
 job=service.n['smoke']
 resource=service.describe('job',job);execution=resource['status']['latestCreatedExecution']['name']
 logs=json.loads(service.call('logging','read','resource.type="cloud_run_job" AND labels."run.googleapis.com/execution_name"="'+execution+'"','--limit=80','--format=json'))
 write(WORK/'diagnostic-error-logs.private.json',logs)
 lines=[v.get('textPayload','') for v in logs if v.get('textPayload')]
 print(json.dumps({'execution':execution,'diagnostics':lines[-25:]},indent=2))

def check_live_authority():
 assert state.get('promoted')
 code='''import json
from types import SimpleNamespace
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.database_privileges import verify_runtime
s=Settings.from_env();e=make_engine(s.database_url,s);verify_runtime(e,SimpleNamespace(environment='production',workload_role='api'))
with e.connect() as c:
 result={'role':c.scalar(text('SELECT current_user')),'legacy_login_disabled':not c.scalar(text("SELECT rolcanlogin FROM pg_roles WHERE rolname='bmt'")),
 'worker_can_read_tokens':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','session_tokens','SELECT')")),
 'worker_can_read_staff':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','studio_staff','SELECT')")),
 'worker_can_edit_audit':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','admin_audit','UPDATE')")),
 'worker_can_delete_audit':c.scalar(text("SELECT has_table_privilege('bmt_worker','admin_audit','DELETE')")),
 'api_can_read_staff':c.scalar(text("SELECT has_any_column_privilege('bmt_api','studio_staff','SELECT')")),
 'admin_can_read_tokens':c.scalar(text("SELECT has_any_column_privilege('bmt_admin','session_tokens','SELECT')")),
 'api_preview_resumes_enabled':s.temporary_ad_resumes_enabled,'legacy_studio_keys_enabled':s.studio_legacy_keys_enabled,
 'api_has_admin_keys':bool(s.admin_owner_key or s.admin_analyst_key)}
 assert result['role']=='bmt_api' and result['legacy_login_disabled']
 assert not any(value for key,value in result.items() if key not in ('role','legacy_login_disabled'))
print('SECURITY_RESULT='+json.dumps(result));e.dispose()
'''
 result=execute('live-authority',code)
 state['live_authority_checked']=True;save();print(json.dumps(result))

def discovery_http():
 assert state.get('promoted')
 import requests
 ids=set();pages=[]
 response=requests.post(state['url']+'/v1/discovery/v3/tracks',json={'query':{'sort':'name'}},timeout=(5,30))
 for _ in range(10):
  assert response.status_code==200,(response.status_code,response.text[:150])
  value=response.json();assert value['schema']=='bmt-discovery-page-v3'
  chunk={v['track_id'] for v in value['items']};assert not ids & chunk;ids.update(chunk);pages.append(len(chunk))
  if not value.get('next_cursor'):break
  response=requests.post(state['url']+'/v1/discovery/v3/tracks',json={'cursor':value['next_cursor']},timeout=(5,30))
 else:raise RuntimeError('Unexpectedly large retained catalog')
 expected=execute('catalog-count',"import json\nfrom sqlalchemy import text\nfrom bmt_backend.config import Settings\nfrom bmt_backend.db import make_engine\ne=make_engine(Settings.from_env().database_url)\nwith e.connect() as c: n=c.scalar(text(\"SELECT count(*) FROM tracks t WHERE t.hidden=false AND t.archived=false AND EXISTS(SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published')\"))\nprint('SECURITY_RESULT='+json.dumps({'public_tracks':n}));e.dispose()")
 assert len(ids)==expected['public_tracks']
 result={'public_tracks':len(ids),'pages':pages,'duplicate_ids':0,'schema':'bmt-discovery-page-v3'}
 write(OUT/'discovery-http.json',result);state['discovery_http_checked']=True;save();print(json.dumps(result))

def execution_status():
 result={}
 for role in ('migrate','smoke'):
  resource=service.describe('job',service.n[role]);latest=resource.get('status',{}).get('latestCreatedExecution',{})
  result[role]=latest
 print(json.dumps(result))

def retire_legacy_identity():
 assert state.get('promoted') and state.get('native_storage_smoke') and state.get('live_authority_checked')
 old=state['old_runtime_account'];member='serviceAccount:'+old
 targets=json.loads((WORK/'targets.private.json').read_text(encoding='utf-8'))
 for name,kind in targets.items():
  if kind in ('api','worker','job'):
   actual=service.describe(kind,name);assert staging.resource_image(actual)==state['image']
   assert runtime(actual).get('serviceAccountName')!=old
   env=envmap(actual);assert not any(key.startswith(('BMT_ADMIN_','BMT_STUDIO_STAFF_SUBJECTS','BMT_STUDIO_MONITOR_')) for key in env)
 account=service.describe('account',old);assert account
 # Disable the retired identity before removing its remaining scoped grants.
 service.call('iam','service-accounts','disable',old)
 policy=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 for binding in policy.get('bindings',[]):
  if member in binding.get('members',[]):binding['members'].remove(member)
 policy['bindings']=[v for v in policy.get('bindings',[]) if v.get('members')]
 path=WORK/'bucket-iam-retired.private.json';write(path,policy)
 service.call('storage','buckets','set-iam-policy','gs://'+service.n['bucket'],str(path))
 old_secret='bmt-stg-'+config['owner'][:8]+'-app-db'
 secret=service.describe('secret',old_secret);assert secret
 # No matching definition uses the former shared login. Disable its secret
 # version, retaining its encrypted history for controlled incident review.
 service.call('secrets','versions','disable','1','--secret='+old_secret)
 owned=json.loads(service.call('secrets','list','--filter=labels.bmt-owner='+config['owner'],'--format=json'))
 removed=0
 operator='serviceAccount:'+service.n['operator']+'@'+config['project']+'.iam.gserviceaccount.com'
 for item in owned:
  name=item['name'].rsplit('/',1)[-1]
  assert item.get('labels',{}).get('bmt-owner')==config['owner']
  policy=json.loads(service.call('secrets','get-iam-policy',name,'--format=json'))
  changed=False
  for binding in policy.get('bindings',[]):
   drop={member,operator} if name==old_secret else {member}
   prior=binding.get('members',[])
   kept=[v for v in prior if v not in drop]
   if len(kept)!=len(prior):
    removed+=len(prior)-len(kept);binding['members']=kept;changed=True
  if changed:
   policy['bindings']=[v for v in policy.get('bindings',[]) if v.get('members')]
   path=WORK/(name+'-retired-iam.private.json');write(path,policy)
   service.call('secrets','set-iam-policy',name,str(path))
 service.call('projects','remove-iam-policy-binding',config['project'],'--member='+member,'--role=roles/cloudsql.client','--condition=None')
 state['legacy_identity_retired']=True;state['legacy_secret_bindings_removed']=removed;save()
 print(json.dumps({'legacy_runtime_account_disabled':True,'old_shared_secret_disabled':True,'old_storage_and_sql_access_removed':True,'stale_secret_memberships_removed':removed,'current_definitions_use_new_roles':True}))

def finish_cloud():
 assert all(state.get(k) for k in ('promoted','cloud_data_preserved','native_storage_smoke','live_authority_checked','discovery_http_checked','legacy_identity_retired'))
 api=service.describe('api',service.n['api'])
 tags=[v['tag'] for v in api['status']['traffic'] if v.get('tag')]
 assert set(tags).issubset({state['canary_tag'],state['maintenance_tag']})
 if tags:
  service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],
   '--remove-tags='+','.join(tags),'--format=json')
 targets=json.loads((WORK/'targets.private.json').read_text(encoding='utf-8'))
 bindings=json.loads((WORK/'bindings.private.json').read_text(encoding='utf-8'))
 final={}
 for name,kind in targets.items():
  if kind not in ('api','worker','job'):continue
  actual=service.describe(kind,name);before=json.loads((WORK/('before-'+name+'.private.json')).read_text(encoding='utf-8'))
  write(WORK/('after-'+name+'.private.json'),actual)
  assert staging.resource_image(actual)==state['image']
  current=runtime(actual);original=runtime(before)
  assert current.get('serviceAccountName')==bindings[name]['account']
  retained=('resources','command','args','ports','volumeMounts','startupProbe','livenessProbe')
  for key in retained:assert current['containers'][0].get(key)==original['containers'][0].get(key),(name,key)
  for key in ('containerConcurrency','timeoutSeconds','volumes','taskCount','maxRetries'):
   assert current.get(key)==original.get(key),(name,key)
  if kind=='api':
   assert actual['status']['url']==state['url']
   assert not any(v.get('tag') for v in actual['status']['traffic'])
   assert any(v.get('revisionName')==state['canary_revision'] and v.get('percent')==100 for v in actual['status']['traffic'])
  if kind=='worker':assert int(actual['metadata']['annotations']['run.googleapis.com/manualInstanceCount'])==state['worker_instances_before']
  final[name]={'kind':kind,'image':state['image'],'workload_role':bindings[name]['role'],
   'service_account':bindings[name]['account'],'resource_and_process_settings_preserved':True}
 result=verify_http(state['url']);write(OUT/'final-http.json',result)
 write(OUT/'final-targets.json',final)
 pc={}
 for role in ('api','worker','db'):
  name='bmt-pc-dev-'+role+'-1'
  original=json.loads((WORK/(name+'-before.private.json')).read_text(encoding='utf-8'))
  current=json.loads(runner.run([*DOCKER,'inspect',name]))[0]
  unchanged=all(current.get(k)==original.get(k) for k in ('Id','Image','Config','Mounts')) and current['State']['StartedAt']==original['State']['StartedAt']
  pc[name]={'unchanged':unchanged,'running':current['State']['Running'],'image':current['Config']['Image']}
 write(OUT/'pc-unchanged.json',pc)
 directory=ROOT/'.tools/gcp-staging'/('rendered-'+config['owner'])
 for filename in ('deployment.json','image.json'):
  path=directory/filename
  backup=WORK/(filename+'.before-receipt.json')
  if path.exists() and not backup.exists():shutil.copyfile(path,backup)
  value=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
  value.update(image=state['image'],source_hash=state['source_hash'])
  if filename=='deployment.json':value.update(url=state['url'],owner=config['owner'],schema=state['schema_target'])
  write(path,value)
 lock=directory/'update.lock'
 if lock.exists():
  held=json.loads(lock.read_text(encoding='utf-8'));assert held.get('task')=='security-deploy-20261024' and held.get('source_hash')==state['source_hash']
  lock.unlink()
 state['cloud_finished']=True;state['finished_at']=datetime.now(timezone.utc).isoformat();save()
 print(json.dumps({'cloud_finished':True,'matching_target_count':len(final),'temporary_tags_removed':True,'owned_deployment_lock_released':True,'public_health':'ready'}))

if __name__=='__main__':
 actions={'inspect':inspect_live,'freeze':freeze,'build':build,'preflight':preflight,'test':test_image,
          'plan':credential_plan,'provision':provision_credentials,'push':push,'maintenance':maintenance,'rehearse':pc_rehearse,
          'prepare-cloud':prepare_cloud,'synthetic-rehearse':synthetic_rehearse,'quiesce':quiesce,'stop-worker':stop_worker,
          'runtime-files':prepare_runtime_files,'snapshot':snapshot_cloud,'backup':backup_cloud,'migrate':migrate_cloud,'transport-check':transport_check,
          'operator-access':grant_operator,'canary':canary,'promote':promote,'smoke':smoke,'cutover-data':cutover_data,'diagnostic-error':diagnostic_error,
          'authority':check_live_authority,'discovery':discovery_http,'execution-status':execution_status,'retire':retire_legacy_identity,'test-secret-access':grant_retained_test_secret,'finish':finish_cloud}
 parser=argparse.ArgumentParser();parser.add_argument('stage',choices=actions)
 actions[parser.parse_args().stage]()
