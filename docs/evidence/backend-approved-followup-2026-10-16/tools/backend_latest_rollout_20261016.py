"""Owner-authorized latest backend/UI deployment to the retained service."""
import argparse, copy, hashlib, importlib.util, json, locale, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/backend-latest-deploy-2026-10-16'
OUTPUT=ROOT/'docs/evidence/backend-latest-deploy-2026-10-16'
CONTEXT=WORK/'image'
WORK.mkdir(parents=True,exist_ok=True);OUTPUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('latest_deploy_utils',ROOT/'.tools/backend_studio_rollout_20261011.py')
u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
config=u.config;stage=u.stage;DIRECTORY=u.DIRECTORY
class Runner(stage.Runner):
 def run(self,argv,*,input_data=None,allow_missing=False,cwd=None):
  encoding='utf-8' if str(argv[0]).lower().endswith('wsl.exe') else locale.getpreferredencoding(False)
  result=subprocess.run(argv,input=input_data,capture_output=True,text=True,encoding=encoding,errors='strict',cwd=cwd,timeout=1800,check=False)
  if result.returncode:
   if allow_missing and any(s in result.stderr.lower() for s in ('not_found','not found','does not exist','no such image','404')):return None
   (WORK/'last-error.private.log').write_text(result.stdout+result.stderr,encoding='utf-8')
   raise RuntimeError('Cloud/container command failed; see private build/backend-latest-deploy-2026-10-16/last-error.private.log')
  return result.stdout.strip()
service=stage.Staging(config,DIRECTORY,Runner());u.service=service
RECEIPT=OUTPUT/'rollout.json'
r=json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}
def save():RECEIPT.write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8')
def digest(value):return hashlib.sha256(value).hexdigest()
def targets():return [('api',service.n['api']),('worker',service.n['worker']),('job',service.n['migrate']),('job',service.n['smoke']),('job','bmt-stg-'+config['owner'][:8]+'-catalog')]
def builder():
 c=copy.deepcopy(config)
 if '--cd' in c['docker']:c['docker'][c['docker'].index('--cd')+1]='/mnt/'+WORK.drive[0].lower()+WORK.as_posix()[2:]
 return stage.Staging(c,DIRECTORY,Runner())
def inspect_live():
 previous=json.loads((DIRECTORY/'deployment.json').read_text())
 found={}
 with ThreadPoolExecutor(max_workers=4) as pool:values=list(pool.map(lambda item:(item,service.describe(*item)),targets()+[('sql',service.n['sql']),('bucket',service.n['bucket']),('repo',service.n['repo'])]))
 for (kind,name),value in values:
  if value is None and name.endswith('-catalog'):continue
  assert value is not None,name
  (WORK/('before-'+name+'.private.json')).write_text(json.dumps(value),encoding='utf-8')
  if kind in ('api','worker','job'):
   assert stage.resource_image(value)==previous['image'],'Unreconciled image '+name
   found[name]=kind
  if kind=='sql':assert value['settings']['deletionProtectionEnabled']
  if kind=='api':api=value
 url=api['status']['url'];assert url==previous['url']
 key=u.staff_key(api)
 overview=u.fetch(url,'/v1/admin/overview',key).json();health=u.fetch(url,'/v1/admin/competition-health',key).json();bootstrap=u.fetch(url,'/v1/bootstrap').json()
 r.update(parent=previous['image'],url=url,owner=config['owner'],targets=found,schema_before=overview['schema'],old_traffic=api['status']['traffic'],started_utc=datetime.now(timezone.utc).isoformat())
 (WORK/'bootstrap-before.private.json').write_text(json.dumps(bootstrap),encoding='utf-8')
 (WORK/'health-before.private.json').write_text(json.dumps(health),encoding='utf-8')
 save()
 result={'url':url,'parent':r['parent'],'schema':r['schema_before'],'health':health['status'],'queue_depth':health['queue_depth'],'available_workers':health['available_workers'],'expected_build':health['expected_build'],'owner_verified':True,'runtime_targets':found}
 (OUTPUT/'initial-readonly.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
def extract_parent():
 import secrets, shutil
 b=builder();docker=b.c['docker']
 if b.runner.run([*docker,'image','inspect',r['parent'],'--format={{.Id}}'],allow_missing=True) is None:
  auth=WORK/'pull-auth';auth.mkdir(exist_ok=False)
  try:
   token=service.call('auth','print-access-token');b.runner.run([*docker,'--config=pull-auth','login',config['region']+'-docker.pkg.dev','--username=oauth2accesstoken','--password-stdin'],input_data=token)
   b.runner.run([*docker,'--config=pull-auth','pull',r['parent']])
  finally:
   assert auth.resolve().parent==WORK.resolve() and WORK.resolve().is_relative_to(ROOT.resolve()) and not auth.is_symlink();shutil.rmtree(auth)
 name='bmt-latest-parent-'+secrets.token_hex(4)
 b.runner.run([*docker,'create','--name='+name,'--label=bmt.latest-owner='+config['owner'],r['parent']])
 try:
  for source,target in [('/app/bmt_backend','parent-backend'),('/opt/bmt','parent-canonical'),('/app/requirements.lock','parent-requirements.lock')]:
   assert not (WORK/target).exists();b.runner.run([*docker,'cp',name+':'+source,'./'+target])
 finally:
  labels=json.loads(b.runner.run([*docker,'inspect',name,'--format={{json .Config.Labels}}']));assert labels.get('bmt.latest-owner')==config['owner'];b.runner.run([*docker,'rm',name])
 r['parent_extracted']=True;save();print(json.dumps({'parent_extracted':True,'requirements_match':(WORK/'parent-requirements.lock').read_bytes().replace(b'\r\n',b'\n')==(ROOT/'backend/requirements.lock').read_bytes().replace(b'\r\n',b'\n')}))
def freeze():
 import shutil
 assert not (WORK/'frozen').exists()
 dest=WORK/'frozen';dest.mkdir()
 for source in (ROOT/'backend').rglob('*'):
  if source.is_file() and not any(x in source.parts for x in ('__pycache__','vendor','.pytest_cache','.ruff_cache')):
   target=dest/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 (dest/'godot-version.txt').write_bytes((ROOT/'godot-version.txt').read_bytes())
 sys.path.insert(0,str(dest/'backend/deploy'))
 import stage_verifier
 stage_verifier.stage(ROOT,dest/'canonical/game')
 # Preserve the existing deployed write gate in the frozen candidate middleware.
 path=dest/'backend/bmt_backend/middleware.py';text=path.read_text(encoding='utf-8')
 if 'DEPLOYMENT_MAINTENANCE' not in text:
  assert text.count('import json\n')==1;text=text.replace('import json\n','import json\nimport os\n',1)
  anchor='            path = scope["path"]\n'
  assert text.count(anchor)==1
  text=text.replace(anchor,anchor+'            if (os.environ.get("BMT_DEPLOYMENT_MAINTENANCE", "false").lower() == "true"\n                    and path.startswith("/v1/") and method not in ("GET", "HEAD", "OPTIONS")):\n                return await error(503, "DEPLOYMENT_MAINTENANCE")\n',1)
  path.write_text(text,encoding='utf-8',newline='\n')
 (dest/'check_godot.py').write_bytes((ROOT/'backend/deploy/check_godot.py').read_bytes())
 files={p.relative_to(dest).as_posix():digest(p.read_bytes()) for p in dest.rglob('*') if p.is_file()}
 r['frozen_files']=files;r['source_hash']=digest(json.dumps(files,sort_keys=True).encode());r['schema']='0036_community_safety';save()
 (OUTPUT/'frozen-source.json').write_text(json.dumps({'source_hash':r['source_hash'],'files':files,'packaged_only_adjustment':'Retain the existing BMT_DEPLOYMENT_MAINTENANCE write gate in frozen middleware; shared workspace source untouched.'},indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'frozen_files':len(files),'schema':r['schema'],'source_hash':r['source_hash']}))
def prepare_build():
 import shutil
 assert r.get('parent_extracted') and r.get('frozen_files') and not CONTEXT.exists()
 frozen=WORK/'frozen'
 assert r['frozen_files']=={p.relative_to(frozen).as_posix():digest(p.read_bytes()) for p in frozen.rglob('*') if p.is_file()}
 CONTEXT.mkdir()
 shutil.copytree(frozen/'backend/bmt_backend',CONTEXT/'source')
 shutil.copytree(frozen/'backend/schemas',CONTEXT/'schemas')
 shutil.copytree(frozen/'canonical',CONTEXT/'canonical')
 for name in ('requirements.lock','pyproject.toml'):(CONTEXT/name).write_bytes((frozen/'backend'/name).read_bytes())
 (CONTEXT/'check_godot.py').write_bytes((frozen/'check_godot.py').read_bytes())
 (CONTEXT/'verified_oval.json').write_bytes((frozen/'backend/tests/fixtures/verified_oval.json').read_bytes())
 patch='''import hashlib,json,shutil,sys
from pathlib import Path
def hashes(p):
 return {f.relative_to(p).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in p.rglob('*') if f.is_file() and not any(x in f.parts for x in ('__pycache__','.godot'))}
backend=Path('/app/bmt_backend');game=Path('/opt/bmt/game')
old=hashes(backend);old_game=hashes(game);expected=hashes(Path('/tmp/latest-source'))
assert backend==Path('/app/bmt_backend') and game==Path('/opt/bmt/game')
shutil.rmtree(backend);shutil.copytree('/tmp/latest-source',backend)
shutil.rmtree(game);shutil.copytree('/tmp/latest-canonical/game',game)
shutil.copyfile('/tmp/latest-canonical/godot-version.txt','/opt/bmt/godot-version.txt')
shutil.copyfile('/tmp/latest-fixture.json','/opt/bmt/acceptance/verified_oval.json')
assert hashes(backend)==expected
sys.path.insert(0,'/app')
from bmt_backend.config import Settings
from bmt_backend.app import create_app
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
from bmt_backend.cloud_smoke import check_comparison_route
assert SCHEMA_HEAD=='0036_community_safety'
a=create_app(Settings(environment='test',database_url='sqlite://',telemetry_enabled=True,client_quality_enabled=True))
upgrade(a.state.engine);check_comparison_route(a)
routes={r.path for r in a.routes if hasattr(r,'path')}
assert '/v1/admin/alarms' in a.openapi()['paths'] and '/v1/community/terms' in a.openapi()['paths']
a.state.engine.dispose();a.state.verifier.close()
proof={'schema':SCHEMA_HEAD,'backend_files':len(expected),'changed_backend_files':sorted(k for k in expected if old.get(k)!=expected[k]),'removed_backend_files':sorted(set(old)-set(expected)),'canonical_files':len(hashes(game)),'changed_canonical_files':sorted(k for k in hashes(game) if old_game.get(k)!=hashes(game)[k]),'source_hashes':expected}
Path('/app/latest-package-proof.json').write_text(json.dumps(proof))
print('LATEST_BACKEND_SCHEMA_ROUTES_VALID')
'''
 (CONTEXT/'install.py').write_text(patch,encoding='utf-8')
 dockerfile='FROM '+r['parent']+'\nUSER root\nENV PYTHONPATH=/app\nCOPY requirements.lock /app/requirements.lock\nCOPY pyproject.toml /app/pyproject.toml\nCOPY schemas /app/schemas\nRUN pip install --no-cache-dir --require-hashes --only-binary=:all: -r /app/requirements.lock\nCOPY source /tmp/latest-source\nCOPY canonical /tmp/latest-canonical\nCOPY verified_oval.json /tmp/latest-fixture.json\nCOPY install.py /tmp/latest-install.py\nCOPY check_godot.py /app/deploy/check_godot.py\nRUN chmod -R u+w /opt/bmt && python /tmp/latest-install.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chown -R 10001:10001 /tmp/bmt && chmod -R a-w /opt/bmt\nUSER 10001:10001\n'
 (CONTEXT/'Dockerfile').write_text(dockerfile,encoding='utf-8')
 r['build_files']={p.relative_to(CONTEXT).as_posix():digest(p.read_bytes()) for p in CONTEXT.rglob('*') if p.is_file()};save()
 print(json.dumps({'build_prepared':True,'frozen_backend_and_canonical':True}))
def build_image():
 assert r['build_files']=={p.relative_to(CONTEXT).as_posix():digest(p.read_bytes()) for p in CONTEXT.rglob('*') if p.is_file()}
 b=builder();tag='bmt-latest-20261016:'+r['source_hash'][:16]
 output=b.runner.run([*b.c['docker'],'build','--pull=false','--platform=linux/amd64','--file=image/Dockerfile','--tag='+tag,'image'])
 (WORK/'build.private.log').write_text(output,encoding='utf-8')
 proof=json.loads(b.runner.run([*b.c['docker'],'run','--rm','--network=none','--entrypoint=cat',tag,'/app/latest-package-proof.json']))
 manifest=json.loads(b.runner.run([*b.c['docker'],'run','--rm','--network=none','--entrypoint=python',tag,'-c','import json;from bmt_backend.config import Settings;from bmt_backend.verifier import GodotVerifier;v=GodotVerifier(Settings.from_env());print(json.dumps(v.manifest()));v.close()']))
 assert manifest['compiler_version']=='creator-compiler-27' and manifest['physics_version']=='arcade-planar-0.59'
 (OUTPUT/'packaged-proof.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
 (OUTPUT/'candidate-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 r.update(local_tag=tag,candidate_id=json.loads(b.runner.run([*b.c['docker'],'image','inspect',tag,'--format={{json .Id}}'])),expected_manifest=manifest);save()
 print(json.dumps({'candidate':r['candidate_id'],'backend_files':proof['backend_files'],'changed_backend_files':len(proof['changed_backend_files']),'compiler':27,'physics':'0.59','native_import_replay_rewind':True}))
def test_image():
 import secrets
 b=builder();docker=b.c['docker'];suffix=secrets.token_hex(4);network='bmt-latest-test-'+suffix;pg='bmt-latest-pg-'+suffix
 password=secrets.token_urlsafe(24)
 b.runner.run([*docker,'network','create','--internal','--label=bmt.latest-owner='+config['owner'],network])
 created=False
 try:
  b.runner.run([*docker,'run','-d','--rm','--name='+pg,'--network='+network,'--label=bmt.latest-owner='+config['owner'],'-e','POSTGRES_USER=latest_test','-e','POSTGRES_DB=latest_test','-e','POSTGRES_PASSWORD='+password,'postgres:17']);created=True
  import time
  for _ in range(40):
   try:ready=b.runner.run([*docker,'exec',pg,'pg_isready','-U','latest_test'],allow_missing=True)
   except RuntimeError:ready=''
   if ready and 'accepting connections' in ready:break
   time.sleep(.3)
  else:raise RuntimeError('Owned PostgreSQL test database did not become ready')
  tests=['test_admin','test_admin_support','test_studio','test_studio_operations','test_studio_alarms','test_studio_catalogue','test_community_safety','test_privacy','test_privacy_postgres','test_network_health','test_network_health_postgres','test_attack_resistance','test_robustness_fixes']
  frozen='/mnt/'+WORK.drive[0].lower()+WORK.as_posix()[2:]+'/frozen/backend'
  args=[*docker,'run','--rm','--network='+network,'--entrypoint=python','--mount=type=bind,source='+frozen+'/tests,target=/test-work/backend/tests,readonly','--mount=type=bind,source='+frozen+'/schemas,target=/test-work/backend/schemas,readonly','--mount=type=bind,source='+frozen+'/pyproject.toml,target=/test-work/backend/pyproject.toml,readonly','--mount=type=bind,source='+frozen+'/deploy,target=/test-work/backend/deploy,readonly','-e','PYTHONPATH=/app:/test-work/backend/tests','-e','BMT_TEST_DATABASE_URL=postgresql+psycopg://latest_test:'+password+'@'+pg+':5432/latest_test',r['local_tag'],'-m','pytest',*['/test-work/backend/tests/'+t+'.py' for t in tests],'-q','--tb=short','-c','/app/pyproject.toml','-o','cache_dir=/tmp/latest-pytest-cache']
  output=b.runner.run(args);(OUTPUT/'exact-image-tests.log').write_text(output.replace(password,'[REDACTED]')+'\n',encoding='utf-8')
  r['exact_image_tests']=True;save();print(output[-2200:])
 finally:
  if created:
   labels=json.loads(b.runner.run([*docker,'inspect',pg,'--format={{json .Config.Labels}}']));assert labels.get('bmt.latest-owner')==config['owner'];b.runner.run([*docker,'stop',pg])
  labels=json.loads(b.runner.run([*docker,'network','inspect',network,'--format={{json .Labels}}']));assert labels.get('bmt.latest-owner')==config['owner'];b.runner.run([*docker,'network','rm',network])
def guard(kind,name,images):
 current=service.describe(kind,name);assert current and stage.resource_image(current) in images,'Unexpected image: '+name
 original=json.loads((WORK/('before-'+name+'.private.json')).read_text())
 def normal(resource):
  value=u.normalized_template(resource);c=u.container(value)
  c['env']=sorted([v for v in c.get('env',[]) if v['name']!='BMT_DEPLOYMENT_MAINTENANCE'],key=lambda v:v['name'])
  return value
 assert normal(current)==normal(original),'Runtime changed: '+name
 for resource in (current,original):resource.get('metadata',{}).get('labels',{}).pop('run.googleapis.com/lastUpdatedTime',None)
 assert current.get('metadata',{}).get('labels',{})==original.get('metadata',{}).get('labels',{}),'Labels changed: '+name
 return current
def push_image():
 import shutil
 assert r.get('exact_image_tests')
 lock=DIRECTORY/'update.lock'
 if lock.exists():
  value=json.loads(lock.read_text());assert value.get('task')=='latest-backend-ui-20261016' and value.get('source_hash')==r['source_hash'],'Another deployment owns the update lock'
 else:
  with lock.open('x') as handle:handle.write(json.dumps({'task':'latest-backend-ui-20261016','source_hash':r['source_hash']}))
 b=builder();auth=WORK/'push-auth';auth.mkdir(exist_ok=False)
 try:
  token=service.call('auth','print-access-token');registry=config['region']+'-docker.pkg.dev'
  b.runner.run([*b.c['docker'],'--config=push-auth','login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token)
  tag=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:latest-'+r.get('image_variant','full')+'-20261016-'+r['source_hash'][:12]
  b.runner.run([*b.c['docker'],'tag',r['local_tag'],tag]);b.runner.run([*b.c['docker'],'--config=push-auth','push',tag])
  r['image']=next(v for v in json.loads(b.runner.run([*b.c['docker'],'image','inspect',tag,'--format={{json .RepoDigests}}'])) if v.startswith(registry+'/'));save()
 finally:
  assert auth.resolve().parent==WORK.resolve() and WORK.resolve().is_relative_to(ROOT.resolve()) and not auth.is_symlink();shutil.rmtree(auth)
 print(json.dumps({'image':r['image'],'tested_candidate':r['candidate_id']}))
def backup():
 assert r.get('image')
 for name,kind in r['targets'].items():guard(kind,name,[r['parent']])
 description='Before latest backend and UI 2026-10-16 '+r['source_hash'][:12]+' '+datetime.now(timezone.utc).isoformat()
 service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
 records=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
 record=next(v for v in records if v.get('description')==description and v.get('status')=='SUCCESSFUL')
 r['backup_id']=record['id'];save();print(json.dumps({'successful_backup':r['backup_id']}))
def execute(name,code,prefix='LATEST_RESULT=',timeout=600):
 import base64,gzip,time
 boot='import base64,gzip;exec(gzip.decompress(base64.b64decode('+repr(base64.b64encode(gzip.compress(code.encode())).decode())+')).decode())'
 assert len(boot)<7400
 execution=r.get(name+'_execution')
 if execution is None:
  data=json.loads(service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait','--task-timeout='+str(timeout)+'s','--args=^@^-c@'+boot,'--format=json'))
  execution=data.get('metadata',{}).get('name') or data.get('name');assert execution and '/' not in execution
  r[name+'_execution']=execution;save()
 for _ in range(12):
  logs=json.loads(service.call('logging','read','resource.type="cloud_run_job" AND resource.labels.job_name="'+service.n['smoke']+'" AND labels."run.googleapis.com/execution_name"="'+execution+'"','--limit=150','--format=json'))
  (WORK/(name+'-logs.private.json')).write_text(json.dumps(logs),encoding='utf-8')
  lines=[row.get('textPayload','') for row in logs if row.get('textPayload','').startswith(prefix)]
  if lines:break
  time.sleep(1)
 assert len(lines)==1,'Diagnostic log not yet visible; rerun this stage to reread the same completed execution'
 result=json.loads(lines[0][len(prefix):]);(OUTPUT/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');return result
def catalog_program(apply=False):
 return '''import hashlib,json,time
from uuid import UUID,uuid5
from sqlalchemy import select,text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.gcs_storage import GCSBlobStore
from bmt_backend.storage import canonical_json
from bmt_backend.verifier import GodotVerifier
s=Settings.from_env();e=make_engine(s.database_url,s);v=GodotVerifier(s);store=GCSBlobStore(s)
try:
 with e.connect() as c:
  c.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
  heads=c.execute(text("SELECT DISTINCT ON (v.track_id) v.id,v.track_id,v.name,v.number,v.content_hash,v.manifest FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE t.official=true AND t.hidden=false AND t.archived=false AND v.state='published' ORDER BY v.track_id,v.number DESC")).mappings().all()
  assert 1<=len(heads)<=100
  max_created=c.execute(text("SELECT COALESCE(MAX(created_at),0) FROM track_versions")).scalar()
 validated=[];failures=[]
 for h in heads:
  try:
   document=store.get_json(h['content_hash']);assert hashlib.sha256(canonical_json(document)).hexdigest()==h['content_hash']
   manifest=v.validate_track(document)
   assert manifest['laps']==5 and manifest['tick_rate']==120 and bool(manifest['track_content_hash'])
   if canonical_json(manifest)!=canonical_json(h['manifest']):validated.append((dict(h),manifest))
  except Exception as error:failures.append({'track':h['name'],'error':str(error)[:240]})
 assert not failures,failures
 added=0
 if __APPLY__:
  from bmt_backend.track_models import Track,TrackVersion
  with make_session_factory(e)() as db:
   for h,manifest in validated:
    track=db.scalar(select(Track).where(Track.id==h['track_id']).with_for_update());assert track.official and not track.hidden and not track.archived
    assert db.scalar(select(TrackVersion.id).where(TrackVersion.track_id==track.id,TrackVersion.state=='published').order_by(TrackVersion.number.desc()).limit(1))==h['id']
    head=db.get(TrackVersion,h['id']);assert head.content_hash==h['content_hash'] and head.manifest==h['manifest']
    mh=hashlib.sha256(canonical_json(manifest)).hexdigest();identity=str(uuid5(UUID(head.id),'canonical-transfer-v1:'+mh))
    if db.get(TrackVersion,identity) is None:
     at=max(int(time.time()),max_created+1)
     db.add(TrackVersion(id=identity,track_id=head.track_id,number=head.number+1,name=head.name,content_hash=head.content_hash,manifest=manifest,discovery=head.discovery,state='published',created_at=at,published_at=at,revision_key=hashlib.sha256(canonical_json({'source_version':head.id,'manifest':manifest})).hexdigest(),creator_test_run_id=None,rating_sum=0,rating_count=0,verified_finishers=0))
     added+=1
   db.commit()
 print('LATEST_RESULT='+json.dumps({'validated_tracks':len(heads),'matching_new_revisions_required':len(validated),'inserted_versions':added,'original_documents_preserved':True,'old_versions_and_scores_preserved':True,'contract':v.manifest()}))
finally:v.close();e.dispose()
'''.replace('__APPLY__',str(apply))
def preview_catalog():
 assert r.get('backup_id')
 job=guard('job',service.n['smoke'],[r['parent'],r['image']])
 if stage.resource_image(job)!=r['image']:service.call('run','jobs','update',service.n['smoke'],'--region='+config['region'],'--image='+r['image'],'--format=json')
 result=execute('catalog-preview',catalog_program(False));r['catalog_validated']=True;save();print(json.dumps(result))
def maintenance():
 import requests
 assert r.get('backup_id') and r.get('catalog_validated') and not r.get('migration_complete')
 guard('api',service.n['api'],[r['parent']]);tag='latest-maint-'+r['source_hash'][:8]
 service.call('run','services','update',service.n['api'],'--region='+config['region'],'--image='+r['parent'],'--no-traffic','--tag='+tag,'--update-env-vars=BMT_DEPLOYMENT_MAINTENANCE=true','--format=json')
 api=guard('api',service.n['api'],[r['parent']]);route=next(v for v in api['status']['traffic'] if v.get('tag')==tag)
 assert route.get('percent',0)==0
 expected={(v['revisionName'],v.get('percent',0)) for v in r['old_traffic'] if v.get('percent',0)}
 assert expected=={(v['revisionName'],v.get('percent',0)) for v in api['status']['traffic'] if v.get('percent',0)}
 denied=requests.post(route['url']+'/v1/telemetry/batches',json={},timeout=(5,30),allow_redirects=False);assert denied.status_code==503 and denied.json()['detail']=='DEPLOYMENT_MAINTENANCE'
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],'--to-revisions='+route['revisionName']+'=100','--format=json')
 worker=guard('worker',service.n['worker'],[r['parent']]);count=int(worker['metadata']['annotations']['run.googleapis.com/manualInstanceCount']);assert count>=1
 r.update(maintenance_revision=route['revisionName'],maintenance_tag=tag,worker_instances_before=count,maintenance_started_utc=datetime.now(timezone.utc).isoformat());save()
 service.call('run','worker-pools','update',service.n['worker'],'--region='+config['region'],'--instances=0','--format=json')
 r['writers_paused']=True;save();print(json.dumps({'maintenance':True,'write_response':503,'worker_instances':0}))
def snapshot(name):
 before=r.get('data_before')
 code='''import hashlib,json,time
from sqlalchemy import inspect,text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s);before=__BEFORE__
with e.connect() as c:
 c.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"));i=inspect(c);available=set(i.get_table_names());tables={}
 for name in ['players','identities','tracks','track_versions','boards','runs','personal_bests','lap_personal_bests','ratings','rivalry_groups','rivalry_members','challenge_members','challenges','purchases','resume_wallets']:
  if name not in available:continue
  columns=before['tables'][name]['columns'] if before else [r['name'] for r in i.get_columns(name)]
  primary=i.get_pk_constraint(name)['constrained_columns'];assert primary
  condition=''
  if before and name=='track_versions':condition=' WHERE created_at<='+str(before['tables'][name]['max_created_at'])
  rows=c.execute(text('SELECT '+','.join('"'+x+'"' for x in columns)+' FROM "'+name+'"'+condition+' ORDER BY '+','.join('"'+x+'"' for x in primary)))
  h=hashlib.sha256();count=0
  for row in rows:h.update(json.dumps(list(row),sort_keys=True,separators=(',',':'),default=str).encode()+b'\\n');count+=1
  tables[name]={'columns':columns,'rows':count,'sha256':h.hexdigest()}
  if name=='track_versions':tables[name]['max_created_at']=c.execute(text('SELECT COALESCE(MAX(created_at),0) FROM track_versions')).scalar()
 pending={t:c.execute(text('SELECT count(*) FROM '+t+" WHERE status IN ('queued','verifying','validating')")).scalar() for t in ['runs','track_validations','publication_intents'] if t in available}
 assert not any(pending.values()),pending
 result={'tables':tables,'pending':pending,'schema':c.execute(text('SELECT version_num FROM alembic_version')).scalar()}
 if before:
  for table,value in tables.items():assert value['rows']==before['tables'][table]['rows'] and value['sha256']==before['tables'][table]['sha256'],table
 print('LATEST_RESULT='+json.dumps(result))
e.dispose()
'''.replace('__BEFORE__',repr(before))
 result=execute(name,code)
 if before is None:r['data_before']=result;save()
 print(json.dumps({'snapshot':name,'schema':result['schema'],'tables_checked':len(result['tables']),'empty_queue':True,'original_data_exact':before is not None}))
def migrate():
 assert r.get('writers_paused') and r.get('data_before') and r.get('backup_id')
 job=guard('job',service.n['migrate'],[r['parent'],r['image']])
 if stage.resource_image(job)!=r['image']:service.call('run','jobs','update',service.n['migrate'],'--region='+config['region'],'--image='+r['image'],'--format=json')
 service.call('run','jobs','execute',service.n['migrate'],'--region='+config['region'],'--wait','--format=json')
 r['migration_complete']=True;save();snapshot('data-after-migration');print(json.dumps({'schema':r['schema'],'migration_complete':True}))
def apply_catalog():
 assert r.get('migration_complete')
 result=execute('catalog-apply',catalog_program(True));r['catalog_applied']=True;save();snapshot('data-after-catalog');print(json.dumps({k:v for k,v in result.items() if k!='contract'}))
def verify_http(origin,worker=False):
 api=service.describe('api',service.n['api']);key=u.staff_key(api)
 assert u.fetch(origin,'/ready').json()['status']=='ready'
 overview=u.fetch(origin,'/v1/admin/overview',key).json();assert overview['schema']==r['schema']
 bootstrap=u.fetch(origin,'/v1/bootstrap').json();assert bootstrap['community_safety_version']==1 and bootstrap['trajectory_verification'] is True
 alarms=u.fetch(origin,'/v1/admin/alarms',key).json();assert alarms['checks']==8 and isinstance(alarms['items'],list)
 assert u.fetch(origin,'/v1/admin/studio/capabilities',key).json()['schema']=='bmt-studio-capabilities-v1'
 u.fetch(origin,'/v1/admin/cases',key);u.fetch(origin,'/v1/admin/catalogue/tracks?limit=1',key)
 assets={}
 for path in (CONTEXT/'source/admin_ui').iterdir():
  if not path.is_file():continue
  url='/admin' if path.name=='index.html' else '/admin/assets/'+path.name
  response=u.fetch(origin,url);assert response.content==path.read_bytes(),path.name;assets[path.name]=digest(response.content)
 result={'observed_at':datetime.now(timezone.utc).isoformat(),'schema':overview['schema'],'ready':True,'assets':assets,'alarms':{'checks':alarms['checks'],'current_items':len(alarms['items'])},'community_safety':True,'trajectory_verification':True,'read_only':True}
 if worker:
  h=u.fetch(origin,'/v1/admin/competition-health',key).json();assert h['status']=='ready' and h['available_workers']>=1
  assert h['expected_build']=={k:v for k,v in r['expected_manifest'].items() if k!='max_frames'};result['health']='ready';result['available_workers']=h['available_workers']
 return result
def canary():
 assert r.get('migration_complete') and (r.get('catalog_applied') or r.get('catalog_mode')=='existing contract preserved; no catalog mutation')
 guard('api',service.n['api'],[r['parent'],r['image']]);tag='latest-'+r['source_hash'][:10]
 service.call('run','services','update',service.n['api'],'--region='+config['region'],'--image='+r['image'],'--no-traffic','--tag='+tag,'--update-env-vars=BMT_DEPLOYMENT_MAINTENANCE=false','--format=json')
 api=guard('api',service.n['api'],[r['image']]);route=next(v for v in api['status']['traffic'] if v.get('tag')==tag);assert route.get('percent',0)==0
 assert any(v.get('revisionName')==r['maintenance_revision'] and v.get('percent')==100 for v in api['status']['traffic'])
 r.update(canary_tag=tag,canary_revision=route['revisionName'],canary_url=route['url']);save()
 result=verify_http(route['url']);(OUTPUT/'verify-canary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 r['verify_canary']=True;save();print(json.dumps({'canary':r['canary_revision'],'ready36':True,'assets':len(result['assets']),'normal_traffic_still_maintenance':True}))
def verify_existing_canary():
 assert r.get('canary_url') and not r.get('promoted')
 result=verify_http(r['canary_url']);(OUTPUT/'verify-canary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');r['verify_canary']=True;save();print(json.dumps({'canary':r['canary_revision'],'ready36':True,'assets':len(result['assets'])}))
def promote():
 assert r.get('verify_canary')
 guard('api',service.n['api'],[r['image']])
 # Restore the sole existing worker and its supervisor before opening writes.
 guard('worker',service.n['worker'],[r['parent']])
 service.call('run','worker-pools','update',service.n['worker'],'--region='+config['region'],'--image='+r['image'],'--instances='+str(r['worker_instances_before']),'--format=json')
 guard('worker',service.n['worker'],[r['image']])
 for name,kind in r['targets'].items():
  if kind!='job':continue
  current=guard(kind,name,[r['parent'],r['image']])
  if stage.resource_image(current)!=r['image']:service.call('run','jobs','update',name,'--region='+config['region'],'--image='+r['image'],'--format=json')
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],'--to-revisions='+r['canary_revision']+'=100','--format=json')
 r['promoted']=True;r['maintenance_ended_utc']=datetime.now(timezone.utc).isoformat();save();print(json.dumps({'promoted':r['canary_revision'],'worker_instances':r['worker_instances_before']}))
def smoke():
 import time
 assert r.get('promoted')
 service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait','--format=json');r['native_storage_smoke']=True;save()
 for _ in range(18):
  try:result=verify_http(r['url'],True);break
  except AssertionError:time.sleep(5)
 else:raise RuntimeError('Current verifier worker did not become available')
 (OUTPUT/'verify-live.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');r['verify_live']=True;save();print(json.dumps({'ready':True,'schema':r['schema'],'available_workers':result['available_workers'],'native_storage_smoke':True,'assets':len(result['assets'])}))
def finish():
 assert r.get('verify_live') and r.get('live_browser') and r.get('native_storage_smoke')
 service.call('run','services','update-traffic',service.n['api'],'--region='+config['region'],'--remove-tags='+r['canary_tag']+','+r['maintenance_tag'],'--format=json')
 api=guard('api',service.n['api'],[r['image']]);assert any(v.get('revisionName')==r['canary_revision'] and v.get('percent')==100 for v in api['status']['traffic'])
 for name,kind in r['targets'].items():guard(kind,name,[r['image']])
 prior=json.loads((DIRECTORY/'deployment.json').read_text());assert prior['image']==r['parent']
 (DIRECTORY/('deployment-before-latest-'+str(r['backup_id'])+'.json')).write_text(json.dumps(prior,indent=2)+'\n')
 (DIRECTORY/'deployment.json').write_text(json.dumps({**prior,'image':r['image']},indent=2)+'\n')
 population=DIRECTORY/'test-population.json'
 if population.exists():
  value=json.loads(population.read_text());population.write_text(json.dumps({**value,'image':r['image']},indent=2)+'\n')
 r.update(completed=True,completed_utc=datetime.now(timezone.utc).isoformat(),temporary_tags_removed=True);save();print(json.dumps({'completed':True,'revision':r['canary_revision'],'url':r['url'],'schema':r['schema']}))
 lock=DIRECTORY/'update.lock';value=json.loads(lock.read_text());assert value.get('task')=='latest-backend-ui-20261016' and value.get('source_hash')==r['source_hash'];lock.unlink()
def progress():
 b=builder();rows=b.runner.run([*b.c['docker'],'ps','--filter=ancestor='+r['local_tag'],'--format={{json .}}'])
 for line in rows.splitlines():
  item=json.loads(line);print(json.dumps({'test_container':item['ID'],'status':item['Status']}))
  logs=b.runner.run([*b.c['docker'],'logs','--tail=5',item['ID']]);print(logs[-1400:])
  print(b.runner.run([*b.c['docker'],'top',item['ID'],'-eo','pid,ppid,stat,comm']))
def permissions():
 member='serviceAccount:'+service.account('runtime')
 policy=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 (WORK/'bucket-policy-before.private.json').write_text(json.dumps(policy),encoding='utf-8')
 roles=[v['role'] for v in policy.get('bindings',[]) if member in v.get('members',[])]
 (OUTPUT/'storage-permissions.json').write_text(json.dumps({'runtime_bucket_roles':roles,'delete_allowed_by_standard_bucket_role':any(x in roles for x in ['roles/storage.objectUser','roles/storage.objectAdmin','roles/storage.admin'])},indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'runtime_bucket_roles':roles,'delete_allowed_by_standard_bucket_role':any(x in roles for x in ['roles/storage.objectUser','roles/storage.objectAdmin','roles/storage.admin'])}))
def grant_object_delete():
 import re
 assert r.get('backup_id') and r.get('catalog_validated')
 service.describe('bucket',service.n['bucket'])
 member='serviceAccount:'+service.account('runtime')
 api=json.loads((WORK/('before-'+service.n['api']+'.private.json')).read_text())
 prefix=u.env(api).get('BMT_GCS_PREFIX',{}).get('value','bmt/v1');assert re.fullmatch(r'[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*',prefix) and not prefix.startswith('bmt-erasure-v1')
 current=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 roles=[v['role'] for v in current.get('bindings',[]) if member in v.get('members',[]) and not v.get('condition')]
 if any(x in roles for x in ['roles/storage.objectUser','roles/storage.objectAdmin','roles/storage.admin']):
  r['object_delete_permission']='pre-existing';save();return
 role_id='bmtStg'+config['owner'][:8]+'ObjectDelete';role_name='projects/'+config['project']+'/roles/'+role_id
 description='Beat my track staging '+config['owner']+' ordinary-object deletion only'
 old=service.call('iam','roles','describe',role_id,'--format=json',allow_missing=True)
 if old is None:
  role=json.loads(service.call('iam','roles','create',role_id,'--title=Beat my track scoped object deletion','--description='+description,'--permissions=storage.objects.delete','--stage=GA','--format=json'))
 else:role=json.loads(old)
 assert role['description']==description and role['includedPermissions']==['storage.objects.delete'] and not role.get('deleted')
 condition={'title':'bmt-ordinary-objects-'+config['owner'][:8],'description':'Exclude the independent erasure journal; ordinary game object prefix only','expression':'resource.name.startsWith("projects/_/buckets/'+service.n['bucket']+'/objects/'+prefix+'/")'}
 binding={'role':role_name,'members':[member],'condition':condition}
 candidate=copy.deepcopy(current);candidate['version']=3
 if binding not in candidate.get('bindings',[]):candidate.setdefault('bindings',[]).append(binding)
 policy_file=WORK/'bucket-policy-latest.private.json';policy_file.write_text(json.dumps(candidate),encoding='utf-8')
 service.call('storage','buckets','set-iam-policy','gs://'+service.n['bucket'],str(policy_file),'--format=json')
 actual=json.loads(service.call('storage','buckets','get-iam-policy','gs://'+service.n['bucket'],'--format=json'))
 assert binding in actual['bindings']
 assert sorted(json.dumps(v,sort_keys=True) for v in actual['bindings'] if v!=binding)==sorted(json.dumps(v,sort_keys=True) for v in current.get('bindings',[]) if v!=binding)
 result={'permission':'storage.objects.delete','custom_role':role_name,'ordinary_prefix':prefix,'erasure_journal_excluded':True,'existing_bindings_preserved':True}
 (OUTPUT/'scoped-object-delete.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');r['object_delete_permission']='scoped ordinary-prefix custom role';save();print(json.dumps(result))
def build_existing_contract():
 import shutil
 directory=WORK/'existing-contract-image';directory.mkdir(exist_ok=False)
 shutil.copytree(WORK/'parent-canonical',directory/'canonical')
 script='''import hashlib,json,shutil
from pathlib import Path
proof=json.loads(Path('/app/latest-package-proof.json').read_text())
for name,expected in proof['source_hashes'].items():assert hashlib.sha256((Path('/app/bmt_backend')/name).read_bytes()).hexdigest()==expected
assert Path('/opt/bmt')==Path('/opt')/'bmt'
shutil.rmtree('/opt/bmt');shutil.copytree('/tmp/existing-canonical','/opt/bmt')
from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier
v=GodotVerifier(Settings.from_env());fixture=json.loads(Path('/opt/bmt/acceptance/verified_oval.json').read_text());geometry=v.race_geometry(fixture['document']);assert geometry['manifest']['physics_version']=='arcade-planar-0.54';v.close()
Path('/app/existing-contract-proof.json').write_text(json.dumps({'latest_backend_identical':True,'old_contract_geometry_supported':True,'catalog_mutations':0}))
'''
 (directory/'preserve.py').write_text(script,encoding='utf-8')
 (directory/'Dockerfile').write_text('FROM '+r['image']+'\nUSER root\nCOPY canonical /tmp/existing-canonical\nCOPY preserve.py /tmp/preserve-contract.py\nRUN chmod -R u+w /opt/bmt && python /tmp/preserve-contract.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chmod -R a-w /opt/bmt\nUSER 10001:10001\n')
 b=builder();tag='bmt-latest-existing-contract:'+r['source_hash'][:16]
 output=b.runner.run([*b.c['docker'],'build','--network=none','--pull=false','--platform=linux/amd64','--file=existing-contract-image/Dockerfile','--tag='+tag,'existing-contract-image']);(WORK/'existing-contract-build.private.log').write_text(output,encoding='utf-8')
 proof=json.loads(b.runner.run([*b.c['docker'],'run','--rm','--network=none','--entrypoint=cat',tag,'/app/existing-contract-proof.json']))
 manifest=json.loads(b.runner.run([*b.c['docker'],'run','--rm','--network=none','--entrypoint=python',tag,'-c','import json;from bmt_backend.config import Settings;from bmt_backend.verifier import GodotVerifier;v=GodotVerifier(Settings.from_env());print(json.dumps(v.manifest()));v.close()']))
 r.update(existing_contract_local_tag=tag,existing_contract_manifest=manifest);save();(OUTPUT/'existing-contract-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(proof))
def use_existing_contract():
 assert r.get('existing_contract_local_tag') and not r.get('catalog_applied') and not r.get('promoted')
 r['latest_prepared_image']=r['image'];r['latest_prepared_manifest']=r['expected_manifest']
 r['local_tag']=r['existing_contract_local_tag'];r['expected_manifest']=r['existing_contract_manifest'];r['image_variant']='existing-contract'
 b=builder();r['candidate_id']=json.loads(b.runner.run([*b.c['docker'],'image','inspect',r['local_tag'],'--format={{json .Id}}']));save()
 push_image()
 for name,kind in r['targets'].items():
  if kind!='job':continue
  job=guard(kind,name,[r['parent'],r['latest_prepared_image'],r['image']])
  if stage.resource_image(job)!=r['image']:service.call('run','jobs','update',name,'--region='+config['region'],'--image='+r['image'],'--format=json')
 r['catalog_mode']='existing contract preserved; no catalog mutation';save();print(json.dumps({'latest_backend_and_ui':True,'existing_contract_preserved':True,'catalog_mutations':0,'image':r['image']}))
def main():
 actions={'inspect':inspect_live,'extract':extract_parent,'freeze':freeze,'prepare':prepare_build,'build':build_image,'test':test_image,'progress':progress,'permissions':permissions,'grant-delete':grant_object_delete,'existing-contract':build_existing_contract,'use-existing-contract':use_existing_contract,'push':push_image,'backup':backup,'preview-catalog':preview_catalog,'maintenance':maintenance,'snapshot':lambda:snapshot('data-before'),'migrate':migrate,'catalog':apply_catalog,'canary':canary,'verify-canary':verify_existing_canary,'promote':promote,'smoke':smoke,'finish':finish}
 p=argparse.ArgumentParser();p.add_argument('action',choices=actions);a=p.parse_args();actions[a.action]()
if __name__=='__main__':main()
