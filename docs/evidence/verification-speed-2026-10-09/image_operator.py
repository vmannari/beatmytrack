"""Frozen, task-only overlay for the existing owner-controlled development service."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[3]
PRIVATE = ROOT / '.tools/gcp-staging'
CONTEXT = ROOT / '.tools/verification-image-20261009'
EVIDENCE = ROOT / 'docs/evidence/verification-speed-2026-10-09'
spec = importlib.util.spec_from_file_location('verification_stage', ROOT/'backend/deploy/gcp/staging.py')
stage = importlib.util.module_from_spec(spec); spec.loader.exec_module(stage)
config = json.loads((PRIVATE/'config.json').read_text())
assert config['retain_data'] and config['project']=='beat-my-track'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(PRIVATE/'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE']=str(PRIVATE/'windows-trust.pem')
directory = PRIVATE/('rendered-'+config['owner'])
service = stage.Staging(config,directory)
receipt_path = EVIDENCE/'development-rollout.json'
receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}

def save(): receipt_path.write_text(json.dumps(receipt,indent=2))

def env(resource):
    node=resource
    for _ in range(8):
        if 'containers' in node:
            return {item['name']:item for item in node['containers'][0].get('env',[])}
        node=node.get('template') or node.get('spec')
    raise RuntimeError('No runtime environment')

def guard():
    for kind,key in [('api','api'),('worker','worker')]:
        resource=service.describe(kind,service.n[key])
        expected=receipt['image'] if receipt.get(key+'_updated') else receipt['parent']
        assert stage.resource_image(resource)==expected,'Live image changed; review before proceeding'
        assert env(resource)['BMT_ENVIRONMENT']['value']=='development','Only the existing development service is authorized'
    assert service.describe('sql',service.n['sql'])['settings']['deletionProtectionEnabled']

def docker(*args,input_data=None):
    command=list(config['docker'])
    if '--cd' in command:
        command[command.index('--cd')+1]='/mnt/'+CONTEXT.drive[0].lower()+CONTEXT.as_posix()[2:]
    result=subprocess.run([*command,*args],input=input_data,capture_output=True,text=True,check=False,timeout=300)
    if result.returncode:
        (CONTEXT/'last-error.private.log').write_text(result.stdout+result.stderr)
        raise RuntimeError('Frozen overlay command failed; private diagnostic retained')
    return result.stdout

PATCH = r'''import hashlib,json,shutil
from pathlib import Path
source=Path('/tmp/verification-source');game=Path('/opt/bmt/game');backend=Path('/app/bmt_backend')
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts}
original=hashes(game)
hunks=json.loads(Path('/tmp/verification-hunks.json').read_text())
changed=[]
for name,pairs in hunks.items():
 target=(game/name.removeprefix('game/')) if name.startswith('game/') else (backend/name.removeprefix('backend/bmt_backend/'))
 if not pairs:
  assert not target.exists(),f'New task file already exists: {name}'
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,target)
 else:
  content=target.read_text()
  for old,new in pairs:
   assert content.count(old)==1,f'Task context mismatch: {name}'
   content=content.replace(old,new)
  target.write_text(content)
 changed.append(name)
expected=set(hunks)
current=hashes(game)
for name,digest in original.items():
 if 'game/'+name not in expected: assert current[name]==digest,'Unrelated canonical file changed'
for p in backend.glob('*.py'):compile(p.read_text(),str(p),'exec')
Path('/app/verification-overlay-proof.json').write_text(json.dumps({'changed_files':changed,'original_game_files':len(original),'unrelated_game_files_exact':True,'game_hashes':current}))
print('VERIFICATION_OVERLAY_VALID')
'''

action=sys.argv[1]
if action=='prepare':
    old=json.loads((directory/'deployment.json').read_text())
    receipt.update(parent=old['image'],url=old['url'],owner=config['owner'])
    guard()
    CONTEXT.mkdir(exist_ok=False)
    hunks=json.loads((ROOT/'build/verification-speed-2026-10-09/backend-hunks.json').read_text())
    for name in hunks:
        target=CONTEXT/'source'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
    (CONTEXT/'hunks.json').write_text(json.dumps(hunks))
    (CONTEXT/'patch.py').write_text(PATCH)
    for source,target in [('backend/tests/fixtures/verified_oval.json','fixture.json'),('build/verification-speed-2026-10-09/proof.json','proof.json')]:
        shutil.copyfile(ROOT/source,CONTEXT/target)
    (CONTEXT/'Dockerfile').write_text('FROM '+receipt['parent']+'\nUSER root\nCOPY source /tmp/verification-source\nCOPY patch.py /tmp/verification-patch.py\nCOPY hunks.json /tmp/verification-hunks.json\nCOPY fixture.json proof.json /tmp/verification-fixtures/\nRUN python /tmp/verification-patch.py\nUSER 10001:10001\n')
    receipt['source_hash']=hashlib.sha256(b''.join(p.read_bytes() for p in sorted(CONTEXT.rglob('*')) if p.is_file())).hexdigest()
    receipt['tag']='bmt-verification:'+receipt['source_hash'][:20]
    save();print(json.dumps({'prepared':True,'development_only':True,'schema_change':False,'files':len(hunks)}))
elif action=='build':
    guard()
    output=docker('build','--platform=linux/amd64','--tag='+receipt['tag'],'.')
    (CONTEXT/'build.private.log').write_text(output)
    proof=json.loads(docker('run','--rm','--network=none','--entrypoint=cat',receipt['tag'],'/app/verification-overlay-proof.json'))
    (EVIDENCE/'packaged-game-proof.json').write_text(json.dumps(proof,indent=2))
    save();print(json.dumps({'built':True,'unrelated_game_files_exact':True,'tag':receipt['tag']}))
elif action=='test':
    code="""import json,time
from types import SimpleNamespace
from bmt_backend.verifier import GodotVerifier
f=json.load(open('/tmp/verification-fixtures/fixture.json'));p=json.load(open('/tmp/verification-fixtures/proof.json'))
v=GodotVerifier(SimpleNamespace(godot_bin='godot',game_project='/opt/bmt/game',verifier_timeout_seconds=90,persistent_verifier=True))
try:
 a=v.verify_run(f['document'],f['replay'],'compact');assert a['time_ticks']==12757 and a['lap_ticks']==[2634,2532,2531,2530,2530] and a['manifest']==f['expected_manifest']
 r={**f['replay'],'race_proof':p};start=time.perf_counter();b=v.verify_run(f['document'],r,'compact');assert b['verification_method']=='movement-proof-v1' and b['time_ticks']==a['time_ticks'] and b['lap_ticks']==a['lap_ticks']
 print(json.dumps({'linux_canonical':True,'linux_lightweight':True,'lightweight_seconds':time.perf_counter()-start,'ticks':b['time_ticks']}))
finally:v.close()
"""
    output=docker('run','--rm','--network=none','--entrypoint=python',receipt['tag'],'-c',code)
    (EVIDENCE/'linux-verifier.log').write_text(output)
    receipt['linux_verified']=True;save();print(output)
elif action=='push':
    guard();assert receipt.get('linux_verified')
    registry=config['region']+'-docker.pkg.dev'
    tag=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:verification-'+receipt['source_hash'][:20]
    auth=CONTEXT/'docker-private';auth.mkdir(exist_ok=False)
    try:
        token=service.call('auth','print-access-token')
        docker('--config=docker-private','login',registry,'--username=oauth2accesstoken','--password-stdin',input_data=token)
        docker('tag',receipt['tag'],tag)
        docker('--config=docker-private','push',tag)
        digests=json.loads(docker('image','inspect',tag,'--format={{json .RepoDigests}}'))
        receipt['image']=next(value for value in digests if value.startswith(registry+'/'));save()
    finally:
        assert auth.resolve().parent==CONTEXT.resolve() and CONTEXT.resolve().is_relative_to(ROOT.resolve())
        assert not auth.is_symlink() and all(not path.is_symlink() for path in auth.rglob('*'))
        shutil.rmtree(auth)
    print(json.dumps({'pushed':True,'image':receipt['image']}))
elif action=='backup':
    guard();assert receipt.get('image') and receipt.get('linux_verified')
    description='Before lightweight verification '+datetime.now(timezone.utc).isoformat()
    service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
    backups=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
    match=next(value for value in backups if value.get('description')==description and value.get('status')=='SUCCESSFUL')
    receipt['backup_id']=match['id'];save();print(json.dumps({'successful_backup':receipt['backup_id']}))
elif action=='deploy':
    guard();assert receipt.get('backup_id') and receipt.get('linux_verified')
    for key,command in [('worker','worker-pools'),('api','services')]:
        if not receipt.get(key+'_updated'):
            service.call('run',command,'update',service.n[key],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
            receipt[key+'_updated']=True;save();print('Updated development '+key,flush=True)
    for key in ['migrate','smoke']:
        if not receipt.get(key+'_updated'):
            resource=service.describe('job',service.n[key]);assert stage.resource_image(resource)==receipt['parent']
            service.call('run','jobs','update',service.n[key],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
            receipt[key+'_updated']=True;save()
    catalog='bmt-stg-'+config['owner'][:8]+'-catalog'
    resource=service.describe('job',catalog)
    if resource and not receipt.get('catalog_updated'):
        assert stage.resource_image(resource)==receipt['parent']
        service.call('run','jobs','update',catalog,'--region='+config['region'],'--image='+receipt['image'],'--format=json')
        receipt['catalog_updated']=True;save()
    old=json.loads((directory/'deployment.json').read_text());assert old['image']==receipt['parent']
    stage.write_json(directory/('deployment-before-verification-'+str(receipt['backup_id'])+'.json'),old)
    stage.write_json(directory/'deployment.json',{**old,'image':receipt['image']})
    population=directory/'test-population.json'
    if population.exists():stage.write_json(population,{**json.loads(population.read_text()),'image':receipt['image']})
    receipt['deployed']=True;save();print('Development lightweight verification deployed; player records retained')
elif action=='smoke':
    guard();assert receipt.get('deployed')
    service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait')
    import requests
    response=requests.get(receipt['url']+'/v1/bootstrap',timeout=20);response.raise_for_status()
    assert response.json()['lightweight_race_proofs'] is True
    assert response.json()['verification']=='movement-proof-with-replay-fallback'
    receipt['native_smoke_passed']=True;save();print('Native replay/storage/schema smoke and lightweight capability passed')
else:raise RuntimeError('Unsupported operation')
