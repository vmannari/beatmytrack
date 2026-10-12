"""Frozen admin-only overlay for the owner-linked retained development service."""
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / '.tools/gcp-staging'
EVIDENCE = ROOT / 'docs/evidence/admin-support-2026-10-08'
CONTEXT = ROOT / '.tools/admin-support-image-20261008'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(PRIVATE / 'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE'] = str(PRIVATE / 'windows-trust.pem')
spec = importlib.util.spec_from_file_location('admin_staging', ROOT/'backend/deploy/gcp/staging.py')
stage = importlib.util.module_from_spec(spec); spec.loader.exec_module(stage)
config = json.loads((PRIVATE/'config.json').read_text())
assert config['retain_data'] and config['project']=='beat-my-track'
DIRECTORY = PRIVATE/('rendered-'+config['owner'])
service = stage.Staging(config,DIRECTORY)
RECEIPT = EVIDENCE/'development-rollout.json'
receipt = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}


def save():
    RECEIPT.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')


def runtime_env(resource):
    node=resource
    for _ in range(8):
        if 'containers' in node:return {v['name']:v for v in node['containers'][0].get('env',[])}
        node=node.get('template') or node.get('spec')
    raise RuntimeError('No runtime environment')


def guard():
    for kind,key in [('api','api'),('worker','worker'),('job','migrate'),('job','smoke')]:
        data=service.describe(kind,service.n[key])
        assert stage.resource_image(data)==receipt['parent'], 'Live parent changed'
        if kind in ('api','worker'):
            env=runtime_env(data)
            assert env['BMT_ENVIRONMENT']['value']=='development'
            assert env['BMT_DEV_AUTH_ENABLED']['value']=='true'
    assert service.describe('sql',service.n['sql'])['settings']['deletionProtectionEnabled']


def build_service():
    c=dict(config);c['docker']=list(c['docker'])
    if '--cd' in c['docker']:c['docker'][c['docker'].index('--cd')+1]='/mnt/'+CONTEXT.drive[0].lower()+CONTEXT.as_posix()[2:]
    class BuildRunner(stage.Runner):
        def run(self,argv,*,input_data=None,allow_missing=False,cwd=None):
            result=subprocess.run(argv,input=input_data,capture_output=True,text=True,cwd=cwd,check=False)
            if result.returncode:
                (CONTEXT/'last-error.private.log').write_text(result.stdout+result.stderr,encoding='utf-8')
                raise RuntimeError('Overlay command failed; private diagnostic retained')
            return result.stdout.strip()
    return stage.Staging(c,DIRECTORY,BuildRunner())


action=sys.argv[1]
if action=='prepare':
    old=json.loads((DIRECTORY/'deployment.json').read_text())
    receipt.update(parent=old['image'],owner=config['owner'],url=old['url'],started_utc=datetime.now(timezone.utc).isoformat())
    guard();assert not receipt.get('image') and not receipt.get('deployed')
    CONTEXT.mkdir(exist_ok=False)
    files=['admin.py','admin_commerce.py','commerce.py','admin_ranges.py','admin_support.py','admin_purchase_controls.py',
        'admin_ui/app.js','admin_ui/commerce.js','admin_ui/support.js','admin_ui/index.html','admin_ui/style.css']
    baseline=EVIDENCE/'checkpoint-base'
    before={}
    for name in files:
        target=CONTEXT/'source'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/'backend/bmt_backend'/name,target)
        previous=baseline/('backend__bmt_backend__'+name.replace('/','__'))
        if previous.exists():before[name]=hashlib.sha256(previous.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    (CONTEXT/'baseline.json').write_text(json.dumps(before),encoding='utf-8')
    patch='''import hashlib,json,shutil
from pathlib import Path
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts and '.godot' not in p.parts}
game=Path('/opt/bmt');backend=Path('/app/bmt_backend');source=Path('/tmp/admin-source')
original=hashes(game);baseline=json.loads(Path('/tmp/admin-baseline.json').read_text())
for name,expected in baseline.items():
 actual=hashlib.sha256((backend/name).read_bytes().replace(b'\\r\\n',b'\\n')).hexdigest()
 assert actual==expected,('Unreviewed deployed-source difference',name)
for p in source.rglob('*'):
 if p.is_file():
  target=backend/p.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
p=backend/'app.py';s=p.read_text();assert 'admin_support.router' not in s
needle='    from .verifier import GodotVerifier\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    from . import admin_purchase_controls, admin_support\\n')
needle='    app.include_router(admin_commerce.router)\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    app.include_router(admin_purchase_controls.router)\\n    app.include_router(admin_support.router)\\n');p.write_text(s)
for name in ('admin.py','admin_commerce.py','commerce.py','admin_ranges.py','admin_support.py','admin_purchase_controls.py','app.py'):compile((backend/name).read_text(),name,'exec')
import sys;sys.path.insert(0,'/app')
import bmt_backend.app,bmt_backend.admin_support,bmt_backend.admin_purchase_controls
assert original==hashes(game)
Path('/app/admin-support-proof.json').write_text(json.dumps({'canonical_unchanged':True,'canonical_files':len(original),'game_hashes':original,'changed_files':sorted(str(p.relative_to(source)) for p in source.rglob('*') if p.is_file())+['app.py']}))
print('ADMIN_SUPPORT_OVERLAY_VALID')
'''
    (CONTEXT/'patch.py').write_text(patch,encoding='utf-8')
    (CONTEXT/'Dockerfile').write_text('FROM '+receipt['parent']+'\nUSER root\nCOPY source /tmp/admin-source\nCOPY baseline.json /tmp/admin-baseline.json\nCOPY patch.py /tmp/admin-support-patch.py\nRUN python /tmp/admin-support-patch.py\nUSER 10001:10001\n',encoding='utf-8')
    receipt['source_hash']=hashlib.sha256(b''.join(p.read_bytes() for p in sorted(CONTEXT.rglob('*')) if p.is_file())).hexdigest()
    save();print(json.dumps({'prepared':True,'source_files':len(files),'schema_change':False,'population_filter':False,'simulation_setting':'development only'}))
elif action=='build':
    guard();builder=build_service();registry=config['region']+'-docker.pkg.dev'
    tag=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:admin-support-'+receipt['source_hash'][:24]
    auth=CONTEXT/'docker-private';auth.mkdir(exist_ok=False)
    try:
        token=service.call('auth','print-access-token')
        builder.runner.run([*builder.c['docker'],'--config=docker-private','login',registry,'--username=oauth2accesstoken','--password-stdin'],input_data=token,cwd=CONTEXT)
        output=builder.runner.run([*builder.c['docker'],'--config=docker-private','build','--platform=linux/amd64','--file=Dockerfile','--tag='+tag,'.'],cwd=CONTEXT)
        (CONTEXT/'build.private.log').write_text(output,encoding='utf-8')
        proof=json.loads(builder.runner.run([*builder.c['docker'],'run','--rm','--entrypoint=cat',tag,'/app/admin-support-proof.json'],cwd=CONTEXT))
        assert proof['canonical_unchanged'];(EVIDENCE/'packaged-game-proof.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
        builder.runner.run([*builder.c['docker'],'--config=docker-private','push',tag],cwd=CONTEXT)
        images=json.loads(builder.runner.run([*builder.c['docker'],'image','inspect',tag,'--format={{json .RepoDigests}}'],cwd=CONTEXT))
        receipt['image']=next(x for x in images if x.startswith(registry+'/'));save()
    finally:
        assert auth.resolve().parent==CONTEXT.resolve() and CONTEXT.resolve().is_relative_to(ROOT.resolve())
        assert not auth.is_symlink() and all(not p.is_symlink() for p in auth.rglob('*'))
        shutil.rmtree(auth)
    print(json.dumps({'image':receipt['image'],'canonical_unchanged':True}))
elif action=='backup':
    guard();assert receipt.get('image')
    description='Before admin support update '+datetime.now(timezone.utc).isoformat()
    service.call('sql','backups','create','--instance='+service.n['sql'],'--description='+description,'--format=json')
    backups=json.loads(service.call('sql','backups','list','--instance='+service.n['sql'],'--format=json'))
    matches=[v for v in backups if v.get('description')==description and v.get('status')=='SUCCESSFUL'];assert matches
    receipt['backup_id']=matches[0]['id'];save();print(json.dumps({'successful_backup':receipt['backup_id']}))
elif action=='deploy':
    guard();assert receipt.get('backup_id') and receipt.get('image')
    for kind,args in [('worker',['run','worker-pools','update']),('api',['run','services','update'])]:
        service.call(*args,service.n[kind],'--region='+config['region'],'--image='+receipt['image'],
            '--update-env-vars=BMT_PURCHASE_SIMULATION_ENABLED=true','--format=json')
        receipt[kind+'_updated']=True;save();print('Updated development '+kind,flush=True)
    for key in ('migrate','smoke'):
        service.call('run','jobs','update',service.n[key],'--region='+config['region'],'--image='+receipt['image'],'--format=json')
    catalog='bmt-stg-'+config['owner'][:8]+'-catalog';data=service.describe('job',catalog)
    if data:
        assert stage.resource_image(data)==receipt['parent']
        service.call('run','jobs','update',catalog,'--region='+config['region'],'--image='+receipt['image'],'--format=json')
    old=json.loads((DIRECTORY/'deployment.json').read_text());assert old['image']==receipt['parent']
    stage.write_json(DIRECTORY/('deployment-before-admin-support-'+str(receipt['backup_id'])+'.json'),old)
    stage.write_json(DIRECTORY/'deployment.json',{**old,'image':receipt['image']})
    population=DIRECTORY/'test-population.json'
    if population.exists():stage.write_json(population,{**json.loads(population.read_text()),'image':receipt['image']})
    receipt['deployed']=True;save();print('Admin support deployed; no migration or player-data operation')
elif action=='smoke':
    assert receipt.get('deployed')
    for kind in ('api','worker'):assert stage.resource_image(service.describe(kind,service.n[kind]))==receipt['image']
    service.call('run','jobs','execute',service.n['smoke'],'--region='+config['region'],'--wait')
    receipt['native_smoke_passed']=True;save();print('Native replay/storage/schema smoke passed')
else:raise RuntimeError('Unknown action')
