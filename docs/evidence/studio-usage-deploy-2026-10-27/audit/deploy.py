"""Owner-authorized private Studio usage rollout; no game/API/worker changes."""
import argparse
import copy
import difflib
import hashlib
import io
import json
import os
import secrets
import shutil
import subprocess
import tarfile
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
OUT=ROOT/'docs/evidence/studio-usage-deploy-2026-10-27'
CONFIG=json.loads((ROOT/'.tools/gcp-staging/config.json').read_text(encoding='utf-8-sig'))
PROJECT,REGION=CONFIG['project'],CONFIG['region']
BASE='bmt-stg-'+CONFIG['owner'][:8]
assert PROJECT=='beat-my-track' and CONFIG['retain_data'] is True
DOCKER=CONFIG['docker']
CA=ROOT/'.tools/gcp-staging/windows-trust.pem'
ENV=os.environ.copy()
if CA.exists():
    ENV['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(CA)
    ENV['REQUESTS_CA_BUNDLE']=str(CA)
STATE=WORK/'state.private.json'
state=json.loads(STATE.read_text()) if STATE.exists() else {}
COMMON=['app.py','admin.py','config.py','studio_settings.py','studio_governance.py','admin_ui/app.js','admin_ui/index.html']
ADDED=['studio_usage.py','studio_usage_cloud.py','admin_ui/usage.js','admin_ui/usage.css']
LOCK=ROOT/'.tools/gcp-staging'/('rendered-'+CONFIG['owner'])/'update.lock'


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')


def save():
    write(STATE,state)


def unix(path):
    return '/mnt/'+path.drive[0].lower()+path.as_posix()[2:]


def command(argv,label,*,timeout=180,input_data=None,binary=False,ok=(0,)):
    result=subprocess.run(argv,input=input_data,capture_output=True,text=not binary,
        **({} if binary else {'encoding':'utf-8','errors':'replace'}),env=ENV,timeout=timeout,check=False)
    if not binary and 'token' not in label:
        (WORK/(label+'.private.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode not in ok:
        raise RuntimeError('Command failed: '+label+'; inspect private log')
    return result.stdout if binary else result.stdout.strip()


def gc(*args,**kwargs):
    return command([*CONFIG['gcloud'],'--project='+PROJECT,*args,'--quiet'],kwargs.pop('label','gcloud'),**kwargs)


def api(method,url,*,body=None,params=None,missing=False):
    token=gc('auth','print-access-token',label='access-token')
    response=requests.request(method,url,json=body,params=params,timeout=(5,40),verify=str(CA),
        headers={'Authorization':'Bearer '+token},allow_redirects=False)
    if missing and response.status_code==404:
        return None
    if not response.ok:
        error=response.json().get('error',{}) if response.headers.get('content-type','').startswith('application/json') else {}
        # Only fixed resource-operation codes are exposed; complete responses stay private.
        write(WORK/'last-error.private.json',{'method':method,'url':url.split('?')[0],
            'status':response.status_code,'error':error})
        raise RuntimeError('Cloud operation failed: '+url.split('/')[2]+' HTTP'+str(response.status_code)+' '+str(error.get('status','')))
    return response.json() if response.content else {}


def describe(name,kind='services'):
    return api('GET',f'https://run.googleapis.com/v2/projects/{PROJECT}/locations/{REGION}/{kind}/{name}')


def wait_operation(operation):
    if not operation.get('name') or operation.get('done'):
        assert not operation.get('error'), 'Cloud operation failed'
        return operation
    for _ in range(60):
        value=api('GET','https://run.googleapis.com/v2/'+operation['name'])
        if value.get('done'):
            assert not value.get('error'),'Cloud operation failed'
            return value
        time.sleep(2)
    raise RuntimeError('Cloud operation remains pending; inspect the task-owned operation')


def hashes(folder):
    return {p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.rglob('*'))
        if p.is_file() and '__pycache__' not in p.parts}


def definition(resource):
    return {k:resource[k] for k in ('template','traffic','scaling','instanceSplits','labels','annotations',
        'ingress','binaryAuthorization','defaultUriDisabled','invokerIamDisabled','iapEnabled') if k in resource}


def guarded():
    before=state['before']
    for name in ('api','studio'):
        live=describe(BASE+'-'+name)
        assert live['template']['containers'][0]['image']==before[name]['template']['containers'][0]['image'],name+' image changed'
        assert live.get('latestReadyRevision')==before[name].get('latestReadyRevision'),name+' revision changed'
    assert not LOCK.exists() or json.loads(LOCK.read_text()).get('task')=='studio-usage-20261027','Another rollout owns the lock'


def inspect_live():
    assert not state.get('candidate_revision'),'Use retained inventory after candidate creation'
    before={name:describe(BASE+'-'+name) for name in ('api','studio')}
    for resource in before.values():
        assert resource.get('labels',{}).get('bmt-owner')==CONFIG['owner']
    worker=describe(BASE+'-worker','workerPools')
    jobs=api('GET',f'https://run.googleapis.com/v2/projects/{PROJECT}/locations/{REGION}/jobs',params={'pageSize':100})
    assert not jobs.get('nextPageToken')
    owned=[j for j in jobs.get('jobs',[]) if j.get('labels',{}).get('bmt-owner')==CONFIG['owner']]
    policy=json.loads(gc('run','services','get-iam-policy',BASE+'-studio','--region='+REGION,'--format=json',label='studio-iam'))
    assert not any(m in ('allUsers','allAuthenticatedUsers') for b in policy.get('bindings',[]) for m in b.get('members',[]))
    billing=api('GET',f'https://cloudbilling.googleapis.com/v1/projects/{PROJECT}/billingInfo')
    assert billing.get('billingEnabled') is True
    state.update(before=before,worker_before=worker,jobs_before=owned,studio_iam_before=policy,
        billing_account=billing['billingAccountName'],base_image=before['studio']['template']['containers'][0]['image'],
        service_account=before['studio']['template']['serviceAccount'],
        started_at=datetime.now(timezone.utc).isoformat())
    assert state['base_image']==before['api']['template']['containers'][0]['image']
    expected=json.loads((ROOT/'build/backend-compatibility-deploy-2026-10-27/state.private.json').read_text())
    assert state['base_image']==expected['image']
    report=json.loads((ROOT/'docs/evidence/studio-usage-costs-2026-10-27/report.json').read_text())
    for name in COMMON+ADDED:
        path='backend/bmt_backend/'+name
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==report['files'][path],path
    resources={'services':[BASE+'-api',BASE+'-studio'],'workerPools':[BASE+'-worker'],
               'instances':[BASE+'-db'],'jobs':[j['name'].rsplit('/',1)[-1] for j in owned]}
    assert sum(len(v) for v in resources.values())<=12
    state['resources']=resources
    save()
    summary={'api_revision':before['api'].get('latestReadyRevision'),'studio_revision':before['studio'].get('latestReadyRevision'),
        'base_image':state['base_image'],'studio_service_account':state['service_account'],'resources':resources,
        'private_studio':True,'project_billing_enabled':True,'player_records_read':False}
    write(OUT/'initial-inspection.json',summary)
    print(json.dumps(summary),flush=True)


def prepare_build():
    guarded()
    source=WORK/'baseline';source.mkdir(exist_ok=True)
    raw=command([*DOCKER,'run','--rm','--network=none','--entrypoint=python',state['base_image'],'-c',
        "import sys,tarfile;t=tarfile.open(fileobj=sys.stdout.buffer,mode='w|');t.add('/app/bmt_backend',arcname='bmt_backend');t.close()"],
        'extract-base',binary=True)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for member in archive.getmembers():
            target=(source/member.name).resolve()
            assert target.is_relative_to(source.resolve()) and (member.isdir() or member.isfile())
        archive.extractall(source)
    base_hashes=hashes(source/'bmt_backend')
    patch=[]
    for name in COMMON:
        old=(ROOT/'build/studio-usage-costs-2026-10-27/base/backend/bmt_backend'/name).read_text(encoding='utf-8').splitlines(True)
        new=(ROOT/'backend/bmt_backend'/name).read_text(encoding='utf-8').splitlines(True)
        patch.extend(difflib.unified_diff(old,new,fromfile='a/bmt_backend/'+name,tofile='b/bmt_backend/'+name,n=2))
    patch_file=WORK/'usage-runtime.patch';patch_file.write_text(''.join(patch),encoding='utf-8',newline='\n')
    for check in (True,False):
        command(['git','apply',*(['--check'] if check else []),'--directory='+source.relative_to(ROOT).as_posix(),str(patch_file)],'apply-delta')
    for name in ADDED:
        target=source/'bmt_backend'/name;assert not target.exists()
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/'backend/bmt_backend'/name,target)
    merged_hashes=hashes(source/'bmt_backend')
    assert set(merged_hashes)-set(base_hashes)==set(ADDED)
    assert {n for n in base_hashes if base_hashes[n]!=merged_hashes[n]}==set(COMMON)
    context=WORK/'context';context.mkdir(exist_ok=True)
    for name in COMMON+ADDED:
        target=context/'overlay/bmt_backend'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/'bmt_backend'/name,target)
    # A read-only probe is shipped as an operator program, never as an HTTP route.
    shutil.copyfile(WORK/'live_probe.py',context/'live_probe.py')
    dockerfile='FROM '+state['base_image']+'\nCOPY overlay/bmt_backend/ /app/bmt_backend/\nCOPY live_probe.py /app/usage-live-probe.py\nRUN python -c "from bmt_backend.app import create_admin_app; from bmt_backend.studio_usage import usage_costs"\n'
    (context/'Dockerfile').write_text(dockerfile,encoding='utf-8',newline='\n')
    fingerprint=hashlib.sha256(json.dumps(merged_hashes,sort_keys=True).encode()).hexdigest()
    state['local_image']='bmt-studio-usage:'+fingerprint[:16]
    command([*DOCKER,'build','--network=none','--pull=false','-t',state['local_image'],unix(context)],'build',timeout=600)
    proof=json.loads(command([*DOCKER,'run','--rm','--network=none','--entrypoint=python',state['local_image'],'-c',
        "import json,hashlib;from pathlib import Path;p=Path('/app/bmt_backend');print(json.dumps({v.relative_to(p).as_posix():hashlib.sha256(v.read_bytes()).hexdigest() for v in p.rglob('*') if v.is_file() and '__pycache__' not in v.parts}))"], 'package-proof'))
    assert proof==merged_hashes
    state.update(base_package_hashes=base_hashes,package_hashes=merged_hashes,built=True)
    save();write(OUT/'package-proof.json',{'base_image':state['base_image'],'package_files':len(proof),
        'changed_existing':COMMON,'added':ADDED,'unchanged_original_files':len(base_hashes)-len(COMMON),
        'hashes':proof,'schema_changed':False,'canonical_bundle_changed':False})
    print(json.dumps({'built':state['local_image'],'package_files':len(proof),'changed_existing':len(COMMON),'new_runtime_files':len(ADDED)}),flush=True)


def test_image():
    assert state.get('built')
    testroot=WORK/'tests/backend';testroot.mkdir(parents=True,exist_ok=True)
    shutil.copytree(ROOT/'backend/tests',testroot/'tests',dirs_exist_ok=True,ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copyfile(ROOT/'backend/pyproject.toml',testroot/'pyproject.toml')
    label='bmt.usage-deploy=20261027'
    network='bmt-usage-deploy-'+secrets.token_hex(4);pg=network+'-pg';password=secrets.token_hex(24)
    envfile=WORK/'tests.private.env'
    envfile.write_text('PYTHONPATH=/app:/test-work/backend/tests\nBMT_TEST_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@'+pg+':5432/usage_fixture\nBMT_LIMITED_TEST_DATABASE_URL=postgresql+psycopg://postgres:'+password+'@'+pg+':5432/usage_fixture\n',encoding='utf-8')
    pgenv=WORK/'pg.private.env';pgenv.write_text('POSTGRES_PASSWORD='+password+'\nPOSTGRES_DB=usage_fixture\n')
    command([*DOCKER,'network','create','--internal','--label',label,network],'test-network')
    created=False
    try:
        command([*DOCKER,'run','-d','--rm','--name',pg,'--network',network,'--label',label,'--cpus=2','--memory=1536m',
            '--env-file',unix(pgenv),'--tmpfs','/var/lib/postgresql/data:rw,size=768m','postgres:17-bookworm'],'test-pg')
        created=True
        for _ in range(80):
            if subprocess.run([*DOCKER,'exec',pg,'pg_isready','-U','postgres'],capture_output=True,check=False).returncode==0:break
            time.sleep(.25)
        else:raise RuntimeError('Owned PostgreSQL readiness timeout')
        output=command([*DOCKER,'run','--rm','--network',network,'--label',label,'--env-file',unix(envfile),
            '--mount','type=bind,src='+unix(testroot)+',dst=/test-work/backend,readonly',
            '--mount','type=bind,src='+unix(OUT)+',dst=/results','--workdir','/test-work/backend',
            '--entrypoint','python',state['local_image'],'-m','pytest','tests/test_studio_usage.py','tests/test_studio.py',
            'tests/test_studio_shared_reporting.py','tests/test_studio_platform.py','tests/test_public_website.py',
            '--deselect=tests/test_studio.py::test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion',
            '-q','--disable-warnings','--tb=short','-p','no:cacheprovider','--basetemp=/tmp/usage-tests',
            '--junitxml=/results/exact-image-tests.xml'],'test-image',timeout=300)
        (OUT/'exact-image-tests.log').write_text(output.replace(password,'[SYNTHETIC-TEST-PASSWORD]'),encoding='utf-8')
        state['tests_passed']=True;save();print(output[-1000:],flush=True)
    finally:
        if created:
            m=json.loads(command([*DOCKER,'inspect',pg],'pg-ownership'))[0]
            assert m['Config']['Labels']['bmt.usage-deploy']=='20261027'
            command([*DOCKER,'stop',pg],'pg-stop')
        m=json.loads(command([*DOCKER,'network','inspect',network],'network-ownership'))[0]
        assert m['Labels']['bmt.usage-deploy']=='20261027'
        command([*DOCKER,'network','rm',network],'network-remove')


def connections():
    guarded()
    desired={'task':'studio-usage-20261027','base_image':state['base_image']}
    if LOCK.exists():assert json.loads(LOCK.read_text())==desired
    else:
        with LOCK.open('x') as stream:json.dump(desired,stream)
    policy=api('POST',f'https://cloudresourcemanager.googleapis.com/v1/projects/{PROJECT}:getIamPolicy',body={'options':{'requestedPolicyVersion':3}})
    member='serviceAccount:'+state['service_account']
    roles=['roles/run.viewer','roles/cloudsql.viewer','roles/monitoring.viewer','roles/logging.viewer','roles/bigquery.jobUser']
    new=[]
    for role in roles:
        if any(b['role']==role and member in b.get('members',[]) and not b.get('condition') for b in policy.get('bindings',[])):
            continue
        binding=next((b for b in policy['bindings'] if b['role']==role and not b.get('condition')),None)
        if binding is None:
            binding={'role':role,'members':[]};policy['bindings'].append(binding)
        binding['members'].append(member);new.append(role)
    if new:
        api('POST',f'https://cloudresourcemanager.googleapis.com/v1/projects/{PROJECT}:setIamPolicy',body={'policy':policy})
    dataset_url=f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}/datasets/bmt_usage_billing'
    dataset=api('GET',dataset_url,missing=True)
    if dataset is None:
        dataset=api('POST',f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}/datasets',body={
            'datasetReference':{'projectId':PROJECT,'datasetId':'bmt_usage_billing'},'location':'EU',
            'description':'Owner-authorized detailed Cloud Billing export for private BMT Studio usage and costs.',
            'labels':{'bmt-owner':CONFIG['owner'],'bmt-purpose':'usage-costs'},
            'access':[{'role':'OWNER','specialGroup':'projectOwners'},{'role':'READER','userByEmail':state['service_account']}]})
    else:
        assert dataset['location']=='EU' and dataset.get('labels',{}).get('bmt-owner')==CONFIG['owner']
        if not any(a.get('userByEmail')==state['service_account'] and a.get('role') in ('READER','OWNER') for a in dataset.get('access',[])):
            api('PATCH',dataset_url,body={'access':dataset.get('access',[])+[{'role':'READER','userByEmail':state['service_account']}]})
    account_id=state['billing_account'].rsplit('/',1)[-1].replace('-','_')
    state['billing_table']=PROJECT+'.bmt_usage_billing.gcp_billing_export_resource_v1_'+account_id
    state['connections_prepared']=True;save()
    receipt={'studio_identity':state['service_account'],'new_project_roles':new,'dataset':'bmt_usage_billing','location':'EU',
        'dataset_access':'existing project owners and Studio reader; provider adds its managed writer when export is enabled',
        'billing_export_activation':'Google Cloud console required; no documented API/CLI for export settings',
        'billing_rows_read':False,'game_api_worker_changed':False}
    write(OUT/'connections.json',receipt);print(json.dumps(receipt),flush=True)


def push():
    assert state.get('tests_passed') and state.get('connections_prepared')
    guarded()
    registry=REGION+'-docker.pkg.dev';remote=registry+'/'+PROJECT+'/'+BASE+'-images/studio:usage-20261027-'+hashlib.sha256(json.dumps(state['package_hashes'],sort_keys=True).encode()).hexdigest()[:12]
    auth=WORK/'docker-auth.private';auth.mkdir(exist_ok=True)
    try:
        token=gc('auth','print-access-token',label='push-token')
        command([*DOCKER,'--config',unix(auth),'login',registry,'--username=oauth2accesstoken','--password-stdin'],'registry-login',input_data=token)
        command([*DOCKER,'tag',state['local_image'],remote],'remote-tag')
        command([*DOCKER,'--config',unix(auth),'push',remote],'push',timeout=600)
        digests=json.loads(command([*DOCKER,'image','inspect',remote,'--format={{json .RepoDigests}}'],'image-digest'))
        state['image']=next(v for v in digests if v.startswith(registry+'/'+PROJECT+'/'));save()
    finally:
        # Delete only the two known task-owned credential files, never enumerate
        # and pass paths to a second shell for deletion.
        for name in ('config.json',):
            p=auth/name
            if p.exists():assert p.resolve().parent==auth.resolve();p.unlink()
    print(json.dumps({'image':state['image']}),flush=True)


def canary():
    guarded()
    env={'BMT_STUDIO_USAGE_PROJECT':PROJECT,'BMT_STUDIO_USAGE_REGION':REGION,
        'BMT_STUDIO_USAGE_RESOURCES':json.dumps(state['resources'],separators=(',',':')),
        'BMT_STUDIO_USAGE_BILLING_TABLE':state['billing_table'],'BMT_STUDIO_USAGE_BILLING_LOCATION':'EU'}
    state['usage_env']=env;state['tag']='uc-'+secrets.token_hex(3);save()
    value='^|^'+'|'.join(k+'='+v for k,v in env.items())
    gc('run','services','update',BASE+'-studio','--region='+REGION,'--image='+state['image'],
        '--update-env-vars='+value,'--no-traffic','--tag='+state['tag'],'--format=json',label='canary',timeout=300)
    live=describe(BASE+'-studio')
    old=state['before']['studio']['template'];new=copy.deepcopy(live['template'])
    assert new['containers'][0]['image']==state['image']
    new['containers'][0]['image']=old['containers'][0]['image']
    new['containers'][0]['env']=[v for v in new['containers'][0].get('env',[]) if v['name'] not in env]
    new.pop('revision',None);previous=copy.deepcopy(old);previous.pop('revision',None)
    assert new==previous,'Studio settings changed beyond image and approved usage environment'
    route=next(v for v in live['trafficStatuses'] if v.get('tag')==state['tag'])
    state.update(candidate_revision=route['revision'],candidate_url=route['uri']);save()
    assert any(v.get('percent')==100 and v['revision'].rsplit('/',1)[-1]==state['before']['studio']['latestReadyRevision'].rsplit('/',1)[-1] for v in live['trafficStatuses'])
    print(json.dumps({'candidate_revision':state['candidate_revision'],'existing_traffic_preserved':True,'private_url':route['uri']}),flush=True)


def probe(collect_only=False):
    assert state.get('candidate_revision')
    current=describe(BASE+'-studio')
    assert current['template']['containers'][0]['image']==state['image']
    # Deploy a uniquely named, short-lived operator job with the exact candidate
    # identity/env/secret/Cloud SQL bindings. It calls read-only functions, not
    # an owner HTTP route, and emits only approved aggregate observations.
    job=state['probe_job'] if collect_only else BASE+'-uc-probe-'+secrets.token_hex(3)
    state['probe_job']=job;save()
    template=current['template'];container=template['containers'][0]
    task={'serviceAccount':state['service_account'],'timeout':'180s','maxRetries':0,
        'containers':[{'image':state['image'],'command':['python'],'args':['/app/usage-live-probe.py'],
            'env':container.get('env',[]),'resources':{'limits':{'cpu':'1','memory':'768Mi'}},
            **({'volumeMounts':container['volumeMounts']} if container.get('volumeMounts') else {})}],
        **({'volumes':template['volumes']} if template.get('volumes') else {})}
    resource={'labels':{'bmt-owner':CONFIG['owner'],'bmt-task':'studio-usage-probe'},
        'template':{'taskCount':1,'parallelism':1,'template':task}}
    if not collect_only:
        operation=api('POST',f'https://run.googleapis.com/v2/projects/{PROJECT}/locations/{REGION}/jobs',
            params={'jobId':job},body=resource)
        wait_operation(operation)
    try:
        if not collect_only:
            gc('run','jobs','execute',job,'--region='+REGION,'--wait','--format=json',label='live-probe',timeout=240)
        for _ in range(6):
            started_filter=(' AND timestamp>="'+state['probe_execution_started_at']+'"') if state.get('probe_execution_started_at') else ''
            entries=api('POST','https://logging.googleapis.com/v2/entries:list',body={
                'resourceNames':['projects/'+PROJECT],
                'filter':'resource.type="cloud_run_job" AND resource.labels.job_name="'+job+'" AND jsonPayload.event="usage_deployment_probe"'+started_filter,
                'orderBy':'timestamp desc','pageSize':5})
            if entries.get('entries'):break
            time.sleep(2)
        if not entries.get('entries'):
            raise RuntimeError('Probe log not yet visible; retain job and inspect exact execution')
        result=entries['entries'][0]['jsonPayload']
        write(OUT/'live-probe-attempt.json',result)
        assert result['schema']=='bmt-studio-usage-costs-v1' and result['read_only'] and result['project']==PROJECT
        assert result['ville_account_found'],'Requested unique real Ville account was not found'
        assert result['activity']['status']=='observed','Actual bounded reporting source unavailable'
        by_key={r['key']:r for r in result['resources']}
        assert by_key['database_connections']['current'] is not None
        for suffix in ('api:cpu','worker:memory','db:disk'):
            row=next(r for key,r in by_key.items() if key.endswith(suffix))
            assert row['current'] is not None and row['limit'] is not None,suffix
        assert result['endpoint_rows']>0
        write(OUT/'live-probe.json',result)
        state['probe_passed']=True;save()
        print(json.dumps({'probe_passed':True,'resource_rows':len(result['resources']),
            'summary':result['summary'],'ville_account_found':True,'activity':result['activity'],
            'cost_status':result['costs']['status'],'endpoint_rows':result['endpoint_rows']}),flush=True)
    finally:
        # Preserve a failed probe for diagnosis. Delete only its owned job after
        # successful validation; the seven original job definitions are untouched.
        if state.get('probe_passed'):
            actual=describe(job,'jobs');assert actual.get('labels',{}).get('bmt-task')=='studio-usage-probe'
            gc('run','jobs','delete',job,'--region='+REGION,label='probe-cleanup')
            state['probe_job_removed']=True;save()


def billing_check():
    tables=api('GET',f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}/datasets/bmt_usage_billing/tables',params={'maxResults':100})
    assert not tables.get('nextPageToken')
    found=[v['tableReference']['tableId'] for v in tables.get('tables',[]) if v['tableReference']['tableId'].startswith('gcp_billing_export_resource_v1_')]
    dataset=api('GET',f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}/datasets/bmt_usage_billing')
    managed=any(v.get('userByEmail')=='billing-export-bigquery@system.gserviceaccount.com' for v in dataset.get('access',[]))
    result={'dataset':'bmt_usage_billing','location':dataset['location'],'managed_export_writer_present':managed,
        'detailed_table_count':len(found),'table_available':bool(found),'export_enabled_by_owner':True}
    if found:
        assert len(found)==1
        actual=PROJECT+'.bmt_usage_billing.'+found[0]
        state['actual_billing_table']=actual
        result['configured_table_matches']=actual==state['billing_table']
        metadata=api('GET',f'https://bigquery.googleapis.com/bigquery/v2/projects/{PROJECT}/datasets/bmt_usage_billing/tables/'+found[0])
        result['rows_present']=int(metadata.get('numRows','0'))>0
        result['partition_type']=metadata.get('timePartitioning',{}).get('type')
        result['partition_field']=metadata.get('timePartitioning',{}).get('field')
    state['billing_export_owner_confirmed']=True;state['billing_writer_present']=managed;save()
    write(OUT/'billing-connection.json',result);print(json.dumps(result),flush=True)


def private_checks(url):
    from urllib.parse import urlsplit
    parsed=urlsplit(url)
    assert parsed.scheme=='https' and parsed.hostname.endswith('.run.app')
    token=gc('auth','print-identity-token',label='identity-token')
    results={}
    for path,expected in (('/health',200),('/ready',200),('/admin',200),('/admin/assets/usage.js',200),
        ('/admin/assets/usage.css',200),('/v1/admin/auth/config',200),('/v1/admin/usage-costs',401),('/v1/auth/google/challenge',404)):
        response=requests.get(url+path,headers={'X-Serverless-Authorization':'Bearer '+token},verify=str(CA),timeout=(5,55))
        assert response.status_code==expected,(path,response.status_code)
        if path=='/admin':assert b'/admin/assets/usage.js' in response.content
        if path=='/v1/admin/auth/config':
            data=response.json()
            assert data.get('configured') is True and not data.get('legacy_enabled')
            assert data['reporting']['mode']=='shared_limited' and data['reporting']['max_days']==7
        results[path]=response.status_code
    unauth=requests.get(url+'/admin',verify=str(CA),timeout=(5,20))
    assert unauth.status_code==403
    results['anonymous_edge']=403
    return results


def promote():
    assert state.get('tests_passed') and state.get('probe_passed')
    checks=private_checks(state['candidate_url'])
    current=describe(BASE+'-api')
    assert current.get('latestReadyRevision')==state['before']['api'].get('latestReadyRevision')
    gc('run','services','update-traffic',BASE+'-studio','--region='+REGION,
        '--to-revisions='+state['candidate_revision'].rsplit('/',1)[-1]+'=100','--format=json',label='promote',timeout=180)
    state['promoted']=True;save();write(OUT/'canary-checks.json',checks)
    print(json.dumps({'promoted_revision':state['candidate_revision'],'checks':checks}),flush=True)


def finish():
    assert state.get('promoted')
    gc('run','services','update-traffic',BASE+'-studio','--region='+REGION,
        '--remove-tags='+state['tag'],'--format=json',label='remove-canary-tag')
    current=describe(BASE+'-studio');checks=private_checks(current['uri'])
    assert any(v.get('percent')==100 and v['revision'].rsplit('/',1)[-1]==state['candidate_revision'].rsplit('/',1)[-1] for v in current['trafficStatuses'])
    assert not any(v.get('tag')==state['tag'] for v in current['trafficStatuses'])
    assert definition(describe(BASE+'-api'))==definition(state['before']['api']),'Game API configuration changed during this task'
    assert definition(describe(BASE+'-worker','workerPools'))==definition(state['worker_before']),'Worker definition changed'
    for job in state['jobs_before']:
        live=describe(job['name'].rsplit('/',1)[-1],'jobs')
        assert definition(live)==definition(job),'Existing job definition changed: '+job['name'].rsplit('/',1)[-1]
    policy=json.loads(gc('run','services','get-iam-policy',BASE+'-studio','--region='+REGION,'--format=json',label='final-iam'))
    assert policy==state['studio_iam_before'],'Studio invoker policy changed'
    if LOCK.exists():
        assert json.loads(LOCK.read_text()).get('task')=='studio-usage-20261027'
        LOCK.unlink()
    state.update(complete=True,finished_at=datetime.now(timezone.utc).isoformat());save()
    receipt={'service':BASE+'-studio','revision':state['candidate_revision'],'image':state['image'],
        'private_checks':checks,'game_api_unchanged':True,'worker_unchanged':True,'existing_jobs_unchanged':True,
        'studio_invoker_iam_unchanged':True,'schema_migration':False,'probe_job_removed':state.get('probe_job_removed'),
        'billing_dataset':'bmt_usage_billing','billing_export_activation':'enabled by owner; provider writer verified; initial delivery pending' if state.get('billing_writer_present') else 'pending Google Cloud console action',
        'completed_at':state['finished_at']}
    write(OUT/'deployment.json',receipt);print(json.dumps(receipt),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=['inspect','build','test','connections','push','canary','probe','probe-result','billing-check','promote','finish'])
    args=parser.parse_args()
    {'inspect':inspect_live,'build':prepare_build,'test':test_image,'connections':connections,
        'push':push,'canary':canary,'probe-result':lambda:probe(collect_only=True),'billing-check':billing_check,
        **{k:globals().get(k) for k in ('probe','promote','finish')}}[args.stage]()
