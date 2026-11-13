"""Minimal, same-schema backend release for durable publication geometry."""
import argparse,hashlib,importlib.util,json,secrets,shutil,subprocess,time
from pathlib import Path
WORK=Path(__file__).resolve().parent;ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('previous_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
d=r.d;service=r.service;DOCKER=r.DOCKER;REGION=r.REGION
d.WORK=WORK;d.OUT=OUT;d.STATE=WORK/'server-state.private.json'
d.state=json.loads(d.STATE.read_text()) if d.STATE.exists() else {}
s=d.state;TAG='race-speed-20261107';CANARY='rvf07';LABEL='bmt.race-speed=20261107'

def prepare():
    assert not s.get('targets')
    previous=json.loads((ROOT/'build/backend-compat-deploy-20261107/state.private.json').read_text())
    s['targets']=previous['targets'];s['parents']={}
    for name,kind in s['targets'].items():
        resource=service.describe(kind,name)
        d.write(WORK/('before-'+name+'.private.json'),resource)
        s['parents'][name]=d.staging.resource_image(resource)
    api=service.describe('api',service.n['api']);s['url']=api['status']['url']
    for role,route in [('main',next(v for v in api['status']['traffic'] if v.get('percent')==100)),
                       ('preview',next(v for v in api['status']['traffic'] if v.get('tag')=='website-preview'))]:
        revision=json.loads(service.call('run','revisions','describe',route['revisionName'],REGION,'--format=json'))
        s['parent_'+role]=revision['spec']['containers'][0]['image']
    s['parent_studio']=s['parents'][service.n['admin']]
    s['manifest']=d.http(s['url'],'/v1/manifest').json()
    folder=WORK/'server-image';folder.mkdir(exist_ok=True)
    source=ROOT/'backend/bmt_backend/publications.py'
    shutil.copyfile(source,folder/'publications.py')
    s['module_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
    s['source_hash']=hashlib.sha256(json.dumps({'module':s['module_sha256'],'parents':{role:s['parent_'+role] for role in ('main','studio','preview')}},sort_keys=True).encode()).hexdigest()
    (folder/'Dockerfile').write_text('ARG BASE\nFROM ${BASE}\nRUN ["python","-c","import os; assert (os.getuid(),os.getgid()) == (10001,10001)"]\nUSER root\nCOPY publications.py /app/bmt_backend/publications.py\nCOPY proof.py /tmp/proof.py\nRUN python /tmp/proof.py\nUSER 10001:10001\n')
    (folder/'.dockerignore').write_text('*\n!Dockerfile\n!publications.py\n!proof.py\n')
    proof='''import hashlib,json,py_compile
from pathlib import Path
p=Path('/app/bmt_backend');prior=json.loads(Path('/app/compat-release-proof.json').read_text())
expected=dict(prior['source_hashes']);expected['publications.py']=EXPECTED
actual={f.relative_to(p).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in p.rglob('*') if f.is_file() and '__pycache__' not in f.parts}
assert actual==expected,'The release must change only publications.py'
py_compile.compile(str(p/'publications.py'),doraise=True)
prior['source_hashes']=actual
Path('/app/compat-release-proof.json').write_text(json.dumps(prior))
Path('/app/race-speed-proof.json').write_text(json.dumps({'source_files':len(actual),'only_changed_module':'publications.py','module_sha256':EXPECTED,'preserved_frontend':prior['preserved_frontend']}))
'''.replace('EXPECTED',repr(s['module_sha256']))
    (folder/'proof.py').write_text(proof)
    d.save();print('Fresh runtime guards and one-module image context prepared',flush=True)

def build():
    assert hashlib.sha256((ROOT/'backend/bmt_backend/publications.py').read_bytes()).hexdigest()==s['module_sha256']
    for role in ('main','studio','preview'):
        tag='bmt-race-speed-20261107-'+role+':'+s['source_hash'][:16]
        d.command(DOCKER+['build','--network=none','--build-arg','BASE='+s['parent_'+role],'-t',tag,d.unix(WORK/'server-image')],'server-build-'+role,timeout=600)
        proof=json.loads(d.command(DOCKER+['run','--rm','--network=none','--entrypoint','cat',tag,'/app/race-speed-proof.json'],'server-proof-'+role))
        assert proof['module_sha256']==s['module_sha256']
        current=json.loads(d.command(DOCKER+['image','inspect',tag],'server-user-'+role))[0]
        assert current['Config']['User']=='10001:10001'
        d.write(OUT/('server-package-'+role+'.json'),proof)
        s['local_'+role]=tag;d.save();print('Built exact one-module '+role+' image',flush=True)

def test():
    assert all(s.get('local_'+role) for role in ('main','studio','preview'))
    name='bmt-race-speed-20261107-pg'
    env=WORK/'server-pg.private.env';testenv=WORK/'server-test.private.env'
    password=secrets.token_urlsafe(30)
    env.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=bmt_race_speed\n')
    testenv.write_text('BMT_TEST_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@127.0.0.1/bmt_race_speed\nPYTHONPATH=/app:/test-work/backend/tests\n')
    d.command(DOCKER+['run','-d','--name',name,'--network=none','--label',LABEL,'--tmpfs','/var/lib/postgresql/data','--env-file',d.unix(env),'postgres:17-bookworm','-c','max_connections=80'],'server-test-pg')
    for _ in range(30):
        value=subprocess.run(DOCKER+['exec',name,'pg_isready','-U','postgres'],capture_output=True)
        if value.returncode==0:break
        time.sleep(1)
    else:raise RuntimeError('Owned PostgreSQL not ready')
    results=WORK/'server-test-results';results.mkdir(exist_ok=True)
    for role in ('main','studio','preview'):
        suites=['test_publication_geometry.py']
        if role=='main':suites+=['test_publication_intents.py','test_publication_background_priority.py']
        command=DOCKER+['run','--rm','--network','container:'+name,'--label',LABEL,'--env-file',d.unix(testenv),
          '--mount','type=bind,src='+d.unix(ROOT/'backend/tests')+',dst=/test-work/backend/tests,readonly',
          '--mount','type=bind,src='+d.unix(results)+',dst=/results','--workdir','/test-work/backend/tests','--entrypoint','python',
          s['local_'+role],'-m','pytest',*suites,'-q','--tb=short','-p','no:cacheprovider','--junitxml=/results/'+role+'.xml']
        try:output=d.command(command,'server-tests-'+role,timeout=600)
        finally:
            if (results/(role+'.xml')).exists():(OUT/('server-tests-'+role+'.xml')).write_text((results/(role+'.xml')).read_text().replace(password,'[REDACTED]'))
        (OUT/('server-tests-'+role+'.log')).write_text(output.replace(password,'[REDACTED]'))
        print(role+': '+output.splitlines()[-1],flush=True)
    s['tests_passed']=True;d.save()
    labels=json.loads(d.command(DOCKER+['inspect',name,'--format={{json .Config.Labels}}'],'server-test-cleanup-labels'))
    assert labels.get('bmt.race-speed')=='20261107'
    d.command(DOCKER+['rm','-f',name],'server-test-cleanup')

def push():
    assert s.get('tests_passed')
    directory=ROOT/'.tools/gcp-staging'/('rendered-'+d.config['owner'])
    lock=directory/'update.lock';expected={'task':TAG,'source_hash':s['source_hash']}
    if lock.exists():assert json.loads(lock.read_text())==expected
    else:
        with lock.open('x') as stream:json.dump(expected,stream)
    for name in s['targets']:d.guarded(name)
    auth=WORK/'server-registry.private';auth.mkdir(exist_ok=True)
    registry=d.config['region']+'-docker.pkg.dev'
    token=service.call('auth','print-access-token')
    d.command(DOCKER+['--config',d.unix(auth),'login',registry,'--username=oauth2accesstoken','--password-stdin'],'server-registry-login',input_data=token)
    for role in ('main','studio','preview'):
        remote=registry+'/'+d.config['project']+'/'+service.n['repo']+'/backend:'+TAG+'-'+role+'-'+s['source_hash'][:12]
        d.command(DOCKER+['tag',s['local_'+role],remote],'server-tag-'+role)
        d.command(DOCKER+['--config',d.unix(auth),'push',remote],'server-push-'+role,timeout=600)
        values=json.loads(d.command(DOCKER+['image','inspect',remote],'server-digest-'+role))[0]
        tested=json.loads(d.command(DOCKER+['image','inspect',s['local_'+role]],'server-tested-'+role))[0]
        assert values['Id']==tested['Id']
        s['image_'+role]=next(value for value in values['RepoDigests'] if value.startswith(registry+'/'));d.save()
    assert auth.resolve().parent==WORK.resolve() and not auth.is_symlink()
    for path in auth.iterdir():assert path.name=='config.json' and path.is_file();path.unlink()
    auth.rmdir()
    print('Exact tested images pushed; temporary registry credentials removed',flush=True)

def update(name,role='main',canary=False):
    kind=s['targets'][name]
    allowed=[s['parents'][name],s['image_'+role]]
    if name==service.n['api']:allowed+=[s['image_main'],s['image_preview']]
    d.guarded(name,allowed)
    args=['run',{'api':'services','worker':'worker-pools','job':'jobs'}[kind],'update',name,REGION,'--image='+s['image_'+role],'--format=json']
    if canary:args+=['--no-traffic','--tag='+CANARY+'-'+role]
    service.call(*args)
    if canary:
        route=next(row for row in service.describe('api',name)['status']['traffic'] if row.get('tag')==CANARY+'-'+role)
        assert route.get('percent',0)==0
        s['route_'+role]=route;d.save()

def rollout():
    assert s.get('tests_passed') and s.get('image_preview')
    for role,name in [('main',service.n['api']),('studio',service.n['admin']),('preview',service.n['api'])]:
        if not s.get('route_'+role):update(name,role,True)
        route=s['route_'+role]
        value=d.verify_admin(route['url']) if role=='studio' else d.verify_api(route['url'])
        if role!='studio':assert d.http(route['url'],'/v1/manifest').json()==s['manifest']
        d.write(OUT/('server-canary-'+role+'.json'),value)
        print('Verified same-contract '+role+' canary',flush=True)
    for name,kind in s['targets'].items():
        if kind in ('worker','job'):update(name);print('Updated '+name,flush=True)
    code='''import json,time
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
a=create_app()
try:
 for _ in range(60):
  value=competition_health(a)
  if value['status']=='ready' and value['available_workers']>=1:break
  time.sleep(1)
 else:raise RuntimeError('Matching worker not ready')
 print('RELEASE_RESULT='+json.dumps({'status':value['status'],'available_workers':value['available_workers']}))
finally:a.state.verifier.close();a.state.engine.dispose()
'''
    value=d.execute('publication-cache-worker-ready',code,job=service.n['migrate'],timeout=180)
    assert value['status']=='ready'
    for role,name in [('main',service.n['api']),('studio',service.n['admin'])]:
        service.call('run','services','update-traffic',name,REGION,'--to-revisions='+s['route_'+role]['revisionName']+'=100','--format=json')
    service.call('run','services','update-traffic',service.n['api'],REGION,'--update-tags=website-preview='+s['route_preview']['revisionName'],'--format=json')
    d.write(OUT/'server-final-http.json',d.verify_api(s['url']))
    d.verify_admin(service.describe('api',service.n['admin'])['status']['url'])
    for name,kind in s['targets'].items():
        role='studio' if name==service.n['admin'] else 'preview' if name==service.n['api'] else 'main'
        resource=d.guarded(name,[s['image_'+role]])
        if kind=='api':
            tags=[v['tag'] for v in resource['status']['traffic'] if v.get('tag','').startswith((TAG+'-',CANARY+'-'))]
            if tags:service.call('run','services','update-traffic',name,REGION,'--remove-tags='+','.join(tags),'--format=json')
        if kind=='worker':
            before=json.loads((WORK/('before-'+name+'.private.json')).read_text())
            assert resource['metadata']['annotations']['run.googleapis.com/manualInstanceCount']==before['metadata']['annotations']['run.googleapis.com/manualInstanceCount']
    directory=ROOT/'.tools/gcp-staging'/('rendered-'+d.config['owner'])
    for filename in ('deployment.json','image.json','test-population.json'):
        path=directory/filename
        if not path.exists():continue
        original=json.loads(path.read_text())
        if filename!='image.json':assert original['owner']==d.config['owner']
        if not (WORK/(filename+'.before.private.json')).exists():shutil.copyfile(path,WORK/(filename+'.before.private.json'))
        updated={**original,'image':s['image_main']}
        if filename!='test-population.json':updated['source_hash']=s['source_hash']
        d.write(path,updated)
    lock=directory/'update.lock';assert json.loads(lock.read_text())=={'task':TAG,'source_hash':s['source_hash']};lock.unlink()
    s['complete']=True;d.save()
    d.write(OUT/'server-rollout.json',{'complete':True,'schema':'0075_receipt_reference_indexes','schema_changed':False,'only_changed_module':'publications.py',
       'module_sha256':s['module_sha256'],'source_derivation_sha256':s['source_hash'],'images':{role:s['image_'+role] for role in ('main','studio','preview')},
       'resource_settings_identities_environment_and_preview_preserved':True,'targets':len(s['targets'])})
    print('Publication geometry persistence deployed across all matching workloads',flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('phase',choices=['prepare','build','test','push','rollout'])
    globals()[parser.parse_args().phase]()
