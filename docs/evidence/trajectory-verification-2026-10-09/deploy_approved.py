"""Owner-approved trajectory rollout, rebased onto the current development image."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
PRIVATE=ROOT/'.tools/gcp-staging'
CONTEXT=ROOT/'.tools/trajectory-approved-20261009'
EVIDENCE=ROOT/'docs/evidence/trajectory-verification-2026-10-09'
spec=importlib.util.spec_from_file_location('approved_trajectory_stage',ROOT/'backend/deploy/gcp/staging.py')
stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)
config=json.loads((PRIVATE/'config.json').read_text(encoding='utf-8'))
assert config['retain_data'] and config['project']=='beat-my-track'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(PRIVATE/'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE']=str(PRIVATE/'windows-trust.pem')
directory=PRIVATE/('rendered-'+config['owner'])
class PrivateRunner(stage.Runner):
    def run(self,argv,*,input_data=None,allow_missing=False,cwd=None):
        readonly=any(value in argv for value in ('describe','list','print-access-token'))
        for attempt in range(4):
            result=subprocess.run(argv,input=input_data,capture_output=True,text=True,timeout=600,check=False,cwd=cwd)
            diagnostic=result.stdout+result.stderr
            transient=any(value in diagnostic for value in ('UNEXPECTED_EOF_WHILE_READING','Connection reset','timed out','503 Service'))
            if not result.returncode or not readonly or not transient or attempt==3:break
            time.sleep(2*(attempt+1))
        if result.returncode:
            diagnostic=result.stdout+result.stderr
            if allow_missing and ('NOT_FOUND' in diagnostic or 'not found' in diagnostic):return None
            (PRIVATE/'trajectory-command-error.private.log').write_text(diagnostic,encoding='utf-8')
            raise RuntimeError('Cloud command failed; private diagnostic saved')
        return result.stdout.strip()
service=stage.Staging(config,directory,PrivateRunner())
receipt_path=EVIDENCE/'approved-deployment.json'
receipt=json.loads(receipt_path.read_text(encoding='utf-8')) if receipt_path.exists() else {}

def save():stage.write_json(receipt_path,receipt)

def environment(resource):
    node=resource
    for _ in range(8):
        if 'containers' in node:
            return {item['name']:item for item in node['containers'][0].get('env',[])}
        node=node.get('template') or node.get('spec')
    raise RuntimeError('Runtime environment missing')

def guard():
    assert receipt.get('owner_authorized') and receipt['owner']==config['owner']
    for kind in ('api','worker'):
        value=service.describe(kind,service.n[kind])
        expected=receipt['image'] if receipt.get(kind+'_updated') else receipt['parent']
        assert stage.resource_image(value)==expected,'Live image changed; stop and reconcile'
        assert environment(value)['BMT_ENVIRONMENT']['value']=='development','Production is outside this approval'
    assert service.describe('sql',service.n['sql'])['settings']['deletionProtectionEnabled']

def docker(*args,input_data=None):
    command=list(config['docker'])
    if '--cd' in command:command[command.index('--cd')+1]='/mnt/'+CONTEXT.drive[0].lower()+CONTEXT.as_posix()[2:]
    result=subprocess.run([*command,*args],input=input_data,capture_output=True,text=True,timeout=360,check=False)
    if result.returncode:
        (CONTEXT/'last-error.private.log').write_text(result.stdout+result.stderr,encoding='utf-8')
        raise RuntimeError('Owned image operation failed; private diagnostic retained')
    return result.stdout

PATCH=r'''import hashlib,json,shutil
from pathlib import Path
game=Path('/opt/bmt');backend=Path('/app/bmt_backend');source=Path('/tmp/approved-source')
def hashes(root):
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
original=hashes(game);backend_original=hashes(backend);hist_before=(backend/'runs.py').read_text();hist_functions=[]
import ast
for node in ast.parse(hist_before).body:
 if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef)) and ('histogram' in node.name or 'comparison' in node.name):
  hist_functions.append((node.name,ast.dump(node,include_attributes=False)))
phases=json.load(open('/tmp/approved-hunks.json'));changed=set()
for phase in phases:
 for name,pairs in phase.items():
  target=game/'game'/name.removeprefix('game/') if name.startswith('game/') else backend/name.removeprefix('backend/bmt_backend/')
  if not pairs:
   assert not target.exists(),'New file already exists: '+name
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,target)
  else:
   text=target.read_text()
   for old,new in pairs:
    assert text.count(old)==1,'Scope mismatch: '+name
    text=text.replace(old,new)
   target.write_text(text)
  changed.add(name)
for name in ('game/backend/lightweight_verifier.gd','game/backend/lightweight_verifier.gd.uid'):
 path=game/name
 if path.exists():path.unlink()
 changed.add(name)
smoke=backend/'cloud_smoke.py';text=smoke.read_text()
assert text.count('verifier.verify_run(')==1
text=text.replace('verifier.verify_run(','verifier.verify_canonical_diagnostic(')
needle='        values = [{"staging_contract": "track", "document": fixture["document"]},'
assert text.count(needle)==1
extra="""        path = json.loads(Path('/tmp/approved-fixtures/proof.json').read_text())
        geometry = verifier.race_geometry(fixture['document'])
        payload = {'schema':'bmt-trajectory-v1','input_count':fixture['time_ticks'],'race_proof':{'schema':'bmt-race-path-v1','samples':[[s[0],s[1],s[2],s[6]] for s in path['samples']]}}
        def forbidden_engine(*_args,**_kwargs):
            raise AssertionError('Race acceptance invoked the engine')
        verifier._invoke = forbidden_engine
        accepted = verifier.verify_run(fixture['document'],payload,fixture['vehicle_id'],geometry=geometry,capture_ghost=False)
        if accepted['time_ticks'] != result['time_ticks'] or accepted['lap_ticks'] != result['lap_ticks'] or accepted['verification_method'] != 'trajectory-v1':
            raise RuntimeError('Trajectory acceptance differs from the pinned fixture')
"""
text=text.replace(needle,extra+needle)
needle='"canonical_ticks": result["time_ticks"], "player_writes": 0'
assert text.count(needle)==1
text=text.replace(needle,'"canonical_ticks": result["time_ticks"], "trajectory_ticks": accepted["time_ticks"], "trajectory_compute_ms":accepted["verification_compute_ms"], "trajectory_engine_calls":0, "player_writes": 0')
smoke.write_text(text)
current=hashes(game)
for name,digest in original.items():
 if name not in {path for path in changed if path.startswith('game/')}:
  assert current[name]==digest,'Unrelated packaged game file changed: '+name
hist_after=(backend/'runs.py').read_text()
after={node.name:ast.dump(node,include_attributes=False) for node in ast.parse(hist_after).body if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef))}
assert hist_functions and all(after.get(name)==value for name,value in hist_functions),'Histogram correction changed'
backend_current=hashes(backend)
backend_changed={name.removeprefix('backend/bmt_backend/') for name in changed if name.startswith('backend/bmt_backend/')}|{'cloud_smoke.py'}
assert all(backend_current[name]==digest for name,digest in backend_original.items() if name not in backend_changed),'Unrelated backend file changed'
for p in backend.glob('*.py'):compile(p.read_text(),str(p),'exec')
Path('/app/approved-trajectory-proof.json').write_text(json.dumps({'original_game_files':len(original),'unrelated_game_files_exact':True,'unrelated_backend_files_exact':True,'histogram_functions_exact':True,'histogram_functions':[name for name,_ in hist_functions],'changed':sorted(changed),'game_hashes':current}))
'''

TEST=r'''import json,time,statistics
from types import SimpleNamespace
from bmt_backend.verifier import GodotVerifier,VerificationError
fixture=json.load(open('/tmp/approved-fixtures/fixture.json'));proof=json.load(open('/tmp/approved-fixtures/proof.json'))
v=GodotVerifier(SimpleNamespace(godot_bin='godot',game_project='/opt/bmt/game',verifier_timeout_seconds=90,persistent_verifier=True))
try:
 geometry=v.race_geometry(fixture['document']);payload={'schema':'bmt-trajectory-v1','input_count':12757,'race_proof':{'schema':'bmt-race-path-v1','samples':[[s[0],s[1],s[2],s[6]] for s in proof['samples']]}}
 def forbidden(*a,**k):raise AssertionError('Engine invoked during acceptance')
 v._invoke=forbidden;samples=[]
 for _ in range(200):
  r=v.verify_run(fixture['document'],payload,'compact',geometry=geometry,capture_ghost=False);assert r['time_ticks']==12757 and r['lap_ticks']==[2634,2532,2531,2530,2530];samples.append(r['verification_compute_ms'])
 try:v.verify_run(fixture['document'],fixture['replay'],'compact',geometry=geometry)
 except VerificationError:pass
 else:raise AssertionError('Input-only recording bypassed trajectory policy')
 samples.sort();print(json.dumps({'trajectory_ticks':12757,'trajectory_method':r['verification_method'],'engine_calls':0,'median_ms':statistics.median(samples),'p95_ms':samples[189],'max_ms':max(samples)}))
finally:v.close()
'''

def job_code(code,timeout=900):
    service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait',
        '--task-timeout='+str(timeout)+'s','--args=^|^-c|'+code)

parser=argparse.ArgumentParser()
parser.add_argument('action',choices=['prepare','rebase','build','test','push','backup','preflight','deploy','smoke'])
action=parser.parse_args().action
if action=='prepare':
    old=json.loads((directory/'deployment.json').read_text(encoding='utf-8'))
    receipt.update(parent=old['image'],url=old['url'],owner=config['owner'],owner_authorized=True,
        authorization='Owner: backend update approved',started_utc=datetime.now(timezone.utc).isoformat())
    guard();CONTEXT.mkdir(exist_ok=False)
    paths=[ROOT/'.tools/verification-image-20261009/hunks.json',ROOT/'.tools/trajectory-image-20261009-r2/hunks.json']
    phases=[json.loads(p.read_text(encoding='utf-8')) for p in paths]
    for phase in phases:
        for name,pairs in phase.items():
            target=CONTEXT/'source'/name
            if target.exists():continue
            target.parent.mkdir(parents=True,exist_ok=True)
            src=(ROOT/'.tools/verification-image-20261009/source'/name) if not pairs and name.endswith('lightweight_verifier.gd') else (ROOT/'.tools/trajectory-image-20261009-r2/source'/name)
            if not src.exists():src=ROOT/'.tools/verification-image-20261009/source'/name
            shutil.copyfile(src,target)
    (CONTEXT/'hunks.json').write_text(json.dumps(phases),encoding='utf-8')
    (CONTEXT/'patch.py').write_text(PATCH,encoding='utf-8')
    for source,target in [('backend/tests/fixtures/verified_oval.json','fixture.json'),('build/verification-speed-2026-10-09/proof.json','proof.json')]:shutil.copyfile(ROOT/source,CONTEXT/target)
    (CONTEXT/'Dockerfile').write_text('FROM '+receipt['parent']+'\nUSER root\nCOPY source /tmp/approved-source\nCOPY hunks.json /tmp/approved-hunks.json\nCOPY patch.py /tmp/approved-patch.py\nCOPY fixture.json proof.json /tmp/approved-fixtures/\nRUN python /tmp/approved-patch.py\nUSER 10001:10001\n',encoding='utf-8')
    receipt['source_hash']=hashlib.sha256(b''.join(p.read_bytes() for p in sorted(CONTEXT.rglob('*')) if p.is_file())).hexdigest()
    receipt['tag']='bmt-trajectory-approved:'+receipt['source_hash'][:20]
    save();print(json.dumps({'prepared':True,'parent':receipt['parent'],'development_only':True}),flush=True)
elif action=='rebase':
    assert not receipt.get('api_updated') and not receipt.get('worker_updated')
    old=json.loads((directory/'deployment.json').read_text(encoding='utf-8'))
    receipt.setdefault('superseded_preparations',[]).append({key:receipt.get(key) for key in ('parent','image','source_hash','tag')})
    receipt['parent']=old['image']
    for key in ('image','backup_id','backup_utc','built','tested','queue_drained'):receipt.pop(key,None)
    guard()
    dockerfile=(CONTEXT/'Dockerfile').read_text(encoding='utf-8').splitlines(True)
    dockerfile[0]='FROM '+receipt['parent']+'\n';(CONTEXT/'Dockerfile').write_text(''.join(dockerfile),encoding='utf-8')
    save();print(json.dumps({'rebased':True,'parent':receipt['parent']}),flush=True)
elif action=='build':
    guard();docker('image','inspect',receipt['parent'])
    # A refused build may require a scoped diagnostic adjustment before publishing.
    (CONTEXT/'patch.py').write_text(PATCH,encoding='utf-8')
    receipt['source_hash']=hashlib.sha256(b''.join(p.read_bytes() for p in sorted(CONTEXT.rglob('*'))
        if p.is_file() and not p.name.endswith('.log') and 'docker-private' not in p.parts)).hexdigest()
    receipt['tag']='bmt-trajectory-approved:'+receipt['source_hash'][:20];save()
    output=docker('build','--pull=false','--network=none','--platform=linux/amd64','--tag='+receipt['tag'],'.')
    (EVIDENCE/'approved-build.log').write_text(output,encoding='utf-8')
    proof=json.loads(docker('run','--rm','--network=none','--entrypoint=cat',receipt['tag'],'/app/approved-trajectory-proof.json'))
    assert proof['unrelated_game_files_exact'] and proof['histogram_functions_exact']
    (EVIDENCE/'approved-packaged-proof.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
    receipt['built']=True;save();print('Rebased image built; histogram functions and unrelated game files exact',flush=True)
elif action=='test':
    assert receipt.get('built')
    output=docker('run','--rm','--network=none','--cpus=1','--entrypoint=python',receipt['tag'],'-c',TEST)
    (EVIDENCE/'approved-linux-test.log').write_text(output,encoding='utf-8')
    receipt['tested']=True;save();print(output,flush=True)
elif action=='push':
    guard();assert receipt.get('tested')
    registry=config['region']+'-docker.pkg.dev'
    tag=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:trajectory-'+receipt['source_hash'][:20]
    auth=CONTEXT/'docker-private';auth.mkdir(exist_ok=False)
    try:
        token=service.call('auth','print-access-token')
        docker('--config=docker-private','login',registry,'--username=oauth2accesstoken','--password-stdin',input_data=token)
        docker('tag',receipt['tag'],tag);docker('--config=docker-private','push',tag)
        digests=json.loads(docker('image','inspect',tag,'--format={{json .RepoDigests}}'))
        receipt['image']=next(value for value in digests if value.startswith(registry+'/'));save()
    finally:
        assert auth.resolve().parent==CONTEXT.resolve() and CONTEXT.resolve().is_relative_to(ROOT.resolve())
        assert not auth.is_symlink() and all(not p.is_symlink() for p in auth.rglob('*'))
        shutil.rmtree(auth)
    print(json.dumps({'pushed':True,'image':receipt['image']}),flush=True)
elif action=='backup':
    guard();assert receipt.get('image') and receipt.get('tested')
    description='Before approved trajectory-only update '+datetime.now(timezone.utc).isoformat()
    service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
    values=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
    backup=next(value for value in values if value.get('description')==description and value.get('status')=='SUCCESSFUL')
    receipt['backup_id']=backup['id'];receipt['backup_utc']=datetime.now(timezone.utc).isoformat();save()
    print(json.dumps({'successful_backup':receipt['backup_id']}),flush=True)
elif action=='preflight':
    guard();assert receipt.get('backup_id')
    # Update only the diagnostic job first; its read checks retain old runtimes.
    if not receipt.get('smoke_updated'):
        assert stage.resource_image(service.describe('job',service.n['smoke']))==receipt['parent']
        service.call('run','jobs','update',service.n['smoke'],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
        receipt['smoke_updated']=True;save()
    code="""from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
from bmt_backend.track_models import Run
from sqlalchemy import select,func
import json
a=create_app()
with a.state.session_factory() as s:
 count=s.scalar(select(func.count()).select_from(Run).where(Run.status.in_(('queued','verifying'))))
assert count==0,'Existing verification queue must drain before the policy switch'
print(json.dumps({'queue_depth':count,'preflight':True,'player_writes':0}))
a.state.engine.dispose();a.state.verifier.close()
"""
    job_code(code)
    receipt['queue_drained']=True;save();print('Existing verification queue drained',flush=True)
elif action=='deploy':
    guard();assert receipt.get('queue_drained') and receipt.get('backup_id') and receipt.get('tested')
    for key,command in [('worker','worker-pools'),('api','services')]:
        if not receipt.get(key+'_updated'):
            service.call('run',command,'update',service.n[key],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
            receipt[key+'_updated']=True;save();print('Updated development '+key,flush=True)
    for key in ('migrate',):
        if not receipt.get(key+'_updated'):
            assert stage.resource_image(service.describe('job',service.n[key]))==receipt['parent']
            service.call('run','jobs','update',service.n[key],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
            receipt[key+'_updated']=True;save()
    catalog='bmt-stg-'+config['owner'][:8]+'-catalog'
    value=service.describe('job',catalog)
    if value and not receipt.get('catalog_updated'):
        assert stage.resource_image(value)==receipt['parent']
        service.call('run','jobs','update',catalog,'--region='+config['region'],'--image='+receipt['image'],'--format=json')
        receipt['catalog_updated']=True;save()
    old=json.loads((directory/'deployment.json').read_text(encoding='utf-8'));assert old['image']==receipt['parent']
    stage.write_json(directory/('deployment-before-trajectory-'+str(receipt['backup_id'])+'.json'),old)
    stage.write_json(directory/'deployment.json',{**old,'image':receipt['image']})
    for name in ('test-population.json',):
        p=directory/name
        if p.exists():stage.write_json(p,{**json.loads(p.read_text(encoding='utf-8')),'image':receipt['image']})
    receipt['deployed']=True;receipt['deployed_utc']=datetime.now(timezone.utc).isoformat();save()
    print('Trajectory-only development backend deployed; no migration or reseed',flush=True)
elif action=='smoke':
    guard();assert receipt.get('deployed')
    service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait')
    import requests
    value=requests.get(receipt['url']+'/v1/bootstrap',timeout=20);value.raise_for_status();cap=value.json()
    assert cap['verification']=='trajectory-v1' and cap['trajectory_verification'] is True
    readiness=requests.get(receipt['url']+'/readyz',timeout=20);readiness.raise_for_status()
    (EVIDENCE/'approved-live-capabilities.json').write_text(json.dumps({k:cap[k] for k in ('verification','trajectory_verification','trajectory_schema','api_version','track_schema','server_now')},indent=2),encoding='utf-8')
    (EVIDENCE/'approved-readiness.json').write_text(json.dumps(readiness.json(),indent=2),encoding='utf-8')
    receipt['smoke_passed']=True;save();print('Live trajectory capability, native/storage/schema smoke and readiness passed',flush=True)
