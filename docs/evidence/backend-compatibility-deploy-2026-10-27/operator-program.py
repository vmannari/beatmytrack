"""Owner-authorized complete compatibility rollout, including immutable track heads."""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT/"docs/evidence/backend-compatibility-deploy-2026-10-27"
OUT.mkdir(parents=True,exist_ok=True)
spec = importlib.util.spec_from_file_location("full_release_utilities",ROOT/"build/full-backend-deploy-2026-10-26/deploy.py")
d = importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
d.WORK,d.OUT,d.STATE = WORK,OUT,WORK/"state.private.json"
d.state = json.loads(d.STATE.read_text()) if d.STATE.exists() else {}
d.service = d.staging.Staging(d.config,WORK,d.Runner())
state,service = d.state,d.service
DOCKER,config = d.DOCKER,d.config
write,save,command,unix = d.write,d.save,d.command,d.unix
TAG = "compat-20261027"
LOCK = ROOT/".tools/gcp-staging"/("rendered-"+config["owner"])/"update.lock"


def inspect_live():
    d.inspect_live()
    expected = json.loads((WORK/"manifest-inspection.json").read_text())["current_game"]
    state["expected_manifest"] = expected;save()
    write(OUT/"manifest-before.json",json.loads((WORK/"manifest-inspection.json").read_text()))


def prepare():
    frozen = WORK/"frozen"
    stage_spec = importlib.util.spec_from_file_location("compatibility_stage",frozen/"backend/deploy/stage_verifier.py")
    stage = importlib.util.module_from_spec(stage_spec);stage_spec.loader.exec_module(stage)
    if not (frozen/"canonical/game").exists():
        stage.stage(frozen,frozen/"canonical/game")
    latest_fixture = json.loads((ROOT/"backend/tests/fixtures/verified_oval.json").read_text())
    assert latest_fixture["expected_manifest"]["vehicles"] == state["expected_manifest"]["vehicles"]
    write(frozen/"backend/tests/fixtures/verified_oval.json",latest_fixture)
    fixture = json.loads((frozen/"backend/tests/fixtures/verified_oval.json").read_text())
    fixture["expected_manifest"]["rules_key"] = state["expected_manifest"]["rules_key"]
    assert fixture["expected_manifest"]["vehicles"] == state["expected_manifest"]["vehicles"]
    write(WORK/"release-fixture.json",fixture)
    state["frozen_hashes"] = d.hashes(frozen)
    state["source_hash"] = hashlib.sha256(json.dumps(state["frozen_hashes"],sort_keys=True).encode()).hexdigest()
    state["local_tag"] = "bmt-compat-20261027:"+state["source_hash"][:16]
    save();write(OUT/"frozen-source.json",{"source_hash":state["source_hash"],"files":state["frozen_hashes"],
        "isolation":"Previously deployed stable package plus four reviewed backend files and the complete validated physics0.75/electric18 canonical bundle; unfinished concurrent Studio edits excluded"})
    print(json.dumps({"source_hash":state["source_hash"],"files":len(state["frozen_hashes"])}),flush=True)


def build():
    assert d.hashes(WORK/"frozen") == state["frozen_hashes"]
    install = '''import hashlib,json,shutil
from pathlib import Path
p=Path('/app/bmt_backend');g=Path('/opt/bmt/game')
assert p==Path('/app/bmt_backend') and g==Path('/opt/bmt/game')
shutil.rmtree(p);shutil.copytree('/tmp/compat-package',p)
shutil.rmtree(g);shutil.copytree('/tmp/compat-canonical',g)
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0070_reward_cache_revisions'
a=create_app(Settings(environment='test',database_url='sqlite://'));upgrade(a.state.engine);a.state.engine.dispose();a.state.verifier.close()
Path('/app/compat-package-proof.json').write_text(json.dumps({p.relative_to('/app/bmt_backend').as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('/app/bmt_backend').rglob('*') if p.is_file() and '__pycache__' not in p.parts}))
'''
    native = '''import json
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier
v=GodotVerifier(Settings.from_env())
try:
 expected=json.loads(Path('/opt/bmt/acceptance/game-manifest.json').read_text())
 assert v.manifest()==expected
 race=json.loads(Path('/opt/bmt/acceptance/electric-race.json').read_text())['result']
 proof=json.loads(Path('/opt/bmt/acceptance/electric-proof.json').read_text())
 result=v.verify_canonical_diagnostic(race['document'],race['replay'],'electric',capture_ghost=False)
 assert result['time_ticks']==race['time_ticks']==proof['time_ticks'] and result['lap_ticks']==proof['lap_ticks']
 assert result['manifest']['vehicles']==expected['vehicles']
 print('ELECTRIC_NATIVE: '+str(result['time_ticks'])+' ticks, five laps, exact seven-car manifest')
finally:v.close()
'''
    (WORK/"install.py").write_text(install,encoding="utf-8",newline="\n")
    (WORK/"native.py").write_text(native,encoding="utf-8",newline="\n")
    write(WORK/"game-manifest.json",state["expected_manifest"])
    dockerfile = f'''FROM {state['parents'][service.n['api']]}
USER root
ENV PYTHONPATH=/app
COPY frozen/backend/bmt_backend /tmp/compat-package
COPY frozen/canonical/game /tmp/compat-canonical
COPY release-fixture.json /opt/bmt/acceptance/verified_oval.json
COPY electric-race.json /opt/bmt/acceptance/electric-race.json
COPY game-manifest.json /opt/bmt/acceptance/game-manifest.json
COPY current-native-proof.json /opt/bmt/acceptance/electric-proof.json
COPY install.py /tmp/compat-install.py
COPY native.py /tmp/compat-native.py
RUN chmod -R u+w /opt/bmt && python /tmp/compat-install.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && python /tmp/compat-native.py && chmod -R a-w /opt/bmt
USER 10001:10001
'''
    (WORK/"Dockerfile").write_text(dockerfile,encoding="utf-8",newline="\n")
    context = WORK/("image-"+state["source_hash"][:12]);context.mkdir(exist_ok=True)
    for source,target in ((WORK/"frozen/backend/bmt_backend",context/"frozen/backend/bmt_backend"),
                          (WORK/"frozen/canonical/game",context/"frozen/canonical/game")):
        if not target.exists():
            shutil.copytree(source,target,ignore=shutil.ignore_patterns('__pycache__','.godot'))
        assert d.hashes(source)==d.hashes(target)
    for name in ('Dockerfile','install.py','native.py','release-fixture.json','electric-race.json','game-manifest.json','current-native-proof.json'):
        shutil.copyfile(WORK/name,context/name)
    command([*DOCKER,"build","--network=none","--pull=false","-f",unix(context/"Dockerfile"),"-t",state["local_tag"],unix(context)],"build",timeout=900)
    proof = json.loads(command([*DOCKER,"run","--rm","--network=none","--entrypoint","cat",state["local_tag"],"/app/compat-package-proof.json"],"package-proof"))
    assert proof == d.hashes(WORK/"frozen/backend/bmt_backend")
    state["image_id"] = command([*DOCKER,"image","inspect",state["local_tag"],"--format={{.Id}}"],"image-id")
    state["built"] = True;save();write(OUT/"package-proof.json",proof)
    print(json.dumps({"image_id":state["image_id"],"package_files":len(proof),"seven_car_native_parity":True,
                      "electric_replay":state["expected_manifest"]["vehicles"]["electric"]}),flush=True)


def test_image():
    assert state.get("built")
    network,pg = "bmt-compat-20261027","bmt-compat-20261027-pg"
    password = os.urandom(24).hex();label="bmt.compatibility=20261027"
    (WORK/"pg.private.env").write_text("POSTGRES_PASSWORD="+password+"\nPOSTGRES_DB=compat_fixture\n")
    url="postgresql+psycopg://postgres:"+password+"@"+pg+":5432/compat_fixture"
    (WORK/"tests.private.env").write_text("PYTHONPATH=/app:/test-work/backend/tests\nBMT_TEST_DATABASE_URL="+url+"\n")
    command([*DOCKER,"network","create","--internal","--label",label,network],"test-network")
    created=False
    try:
        command([*DOCKER,"run","-d","--rm","--name",pg,"--network",network,"--label",label,"--env-file",unix(WORK/"pg.private.env"),"--tmpfs","/var/lib/postgresql/data:rw","postgres:17-bookworm"],"test-pg")
        created=True
        for _ in range(80):
            if subprocess.run([*DOCKER,"exec",pg,"pg_isready","-U","postgres"],capture_output=True).returncode==0:break
            time.sleep(.25)
        else:raise RuntimeError('Disposable PostgreSQL startup timed out')
        args=[*DOCKER,"run","--rm","--network",network,"--label",label,"--env-file",unix(WORK/"tests.private.env"),
              "--mount","type=bind,src="+unix(WORK/"frozen/backend")+",dst=/test-work/backend,readonly",
              "--mount","type=bind,src="+unix(OUT)+",dst=/results","--workdir","/test-work/backend","--entrypoint","python",state["local_tag"],"-m","pytest",
              "tests/test_catalog_builds.py","tests/test_backend_reuse.py","tests/test_results_deployment.py","tests/test_trajectory_integrity.py",
              "-q","--tb=short","-p","no:cacheprovider","--basetemp=/tmp/compat-tests","--junitxml=/results/exact-image-tests.xml"]
        value=subprocess.run(args,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=1200)
        output=(value.stdout+value.stderr).replace(password,"[DISPOSABLE-TEST-PASSWORD]")
        (OUT/"exact-image-tests.log").write_text(output,encoding="utf-8")
        state["tests_exit"]=value.returncode;save();print(output[-6000:],flush=True)
        assert value.returncode==0,'Review exact-image compatibility failures'
        state["release_gate_passed"]=True;save()
    finally:
        if created:
            meta=json.loads(command([*DOCKER,"inspect",pg],"test-inspect"))[0];assert meta["Config"]["Labels"]["bmt.compatibility"]=="20261027"
            command([*DOCKER,"stop",pg],"test-stop")
        meta=json.loads(command([*DOCKER,"network","inspect",network],"test-net-inspect"))[0];assert meta["Labels"]["bmt.compatibility"]=="20261027"
        command([*DOCKER,"network","rm",network],"test-net-remove")


def push():
    assert state.get("release_gate_passed") and state.get("tests_exit")==0
    expected={"task":"backend-compatibility-20261027","source_hash":state["source_hash"]}
    if LOCK.exists():assert json.loads(LOCK.read_text())==expected,'Another deployment owns the lock'
    else:
        with LOCK.open('x') as stream:json.dump(expected,stream)
    for name in state['targets']:d.guarded(name)
    registry=config['region']+'-docker.pkg.dev'
    remote=registry+'/'+config['project']+'/'+service.n['repo']+'/backend:compat-20261027-'+state['source_hash'][:12]
    auth=WORK/'push-auth.private';auth.mkdir()
    try:
        token=service.call('auth','print-access-token')
        command([*DOCKER,'--config',unix(auth),'login',registry,'--username=oauth2accesstoken','--password-stdin'],'registry-login',input_data=token)
        command([*DOCKER,'tag',state['local_tag'],remote],'tag')
        command([*DOCKER,'--config',unix(auth),'push',remote],'push',timeout=900)
        state['image']=next(v for v in json.loads(command([*DOCKER,'image','inspect',remote,'--format={{json .RepoDigests}}'],'digest')) if v.startswith(registry+'/'));save()
    finally:
        assert auth.resolve().parent==WORK.resolve() and not auth.is_symlink();shutil.rmtree(auth)
    print(json.dumps({'image':state['image']}),flush=True)


def check_sources():
    for file in (WORK/'frozen/canonical/game').rglob('*'):
        if not file.is_file() or file.name=='project.godot' or '.godot' in file.parts:continue
        source=ROOT/'game'/file.relative_to(WORK/'frozen/canonical/game')
        assert source.read_bytes()==file.read_bytes(),'Current canonical source changed after validation: '+str(source.relative_to(ROOT))


def prepare_maintenance():
    check_sources()
    d.prepare_maintenance()


def catalogue(apply=False):
    assert state.get('image') and state.get('release_gate_passed')
    if apply:assert state.get('backup_id') and state.get('worker_stopped')
    job='bmt-stg-'+config['owner'][:8]+'-catalog'
    if not state.get('catalogue_job_updated'):
        d.update_image(job);state['catalogue_job_updated']=True;save()
    code='''import json
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.storage import make_blob_store
from bmt_backend.verifier import GodotVerifier
from bmt_backend.catalog_builds import plan_refresh,apply_refresh,check_catalog,published_heads
s=Settings.from_env();e=make_engine(s.database_url,s);factory=make_session_factory(e);blobs=make_blob_store(s,factory);v=GodotVerifier(s)
try:
 # Native validation runs outside a SQL transaction; keep normal runtime limits.
 with factory(bind=e.execution_options(isolation_level='AUTOCOMMIT')) as session:
  before=len(published_heads(session));plan=plan_refresh(session,blobs,v)
 inserted=[]
 if __APPLY__:
  with factory() as session:
   inserted=apply_refresh(session,plan);session.commit()
   compatibility=check_catalog(session,v.manifest())
 result={'published_tracks':before,'matching_revisions_needed':len(plan),'inserted_versions':len(inserted),
  'original_documents_and_historical_versions_preserved':True,'active_manifest':v.manifest()}
 if __APPLY__:result['compatibility']=compatibility
 print('RELEASE_RESULT='+json.dumps(result))
finally:v.close();e.dispose()
'''.replace('__APPLY__',str(apply))
    result=d.execute('catalogue-apply' if apply else 'catalogue-preview',code,job=job,timeout=900)
    assert result['active_manifest']==state['expected_manifest'] and result['published_tracks']==30
    if apply:
        assert result['inserted_versions']==state['catalogue_preview']['matching_revisions_needed']
        assert result['compatibility']['compatible_tracks']==30
        state['catalogue_applied']=True
    else:state['catalogue_preview']=result
    save();print(json.dumps({k:v for k,v in result.items() if k!='active_manifest'}),flush=True)


def quiesce():
    check_sources()
    assert state.get('catalogue_preview') and state.get('maintenance_image') and not state.get('maintenance_started')
    for name,kind in state['targets'].items():
        allowed=[state['parents'][name]]
        if kind=='api':allowed.append(state['maintenance_image'])
        if kind=='job' and name.endswith('-catalog'):allowed.append(state['image'])
        resource=d.guarded(name,allowed)
        if kind=='job':assert resource.get('status',{}).get('latestCreatedExecution',{}).get('completionStatus') in (None,'EXECUTION_SUCCEEDED','EXECUTION_FAILED','EXECUTION_CANCELLED')
    routes=dict(state.get('maintenance_routes',{}))
    for name in (service.n['admin'],service.n['api']):
        before=service.describe('api',name);tag=TAG+'-maint'
        assert all(not row.get('tag') or row['tag']==tag for row in before['status']['traffic'])
        if not any(row.get('tag')==tag for row in before['status']['traffic']):
            service.call('run','services','update',name,'--region='+config['region'],'--image='+state['maintenance_image'],'--no-traffic','--tag='+tag,'--format=json')
        current=service.describe('api',name);route=next(row for row in current['status']['traffic'] if row.get('tag')==tag)
        response=d.http(route['url'],'/v1/bootstrap',private=name==service.n['admin'])
        assert response.status_code==503 and response.json()['detail']=='DEPLOYMENT_MAINTENANCE'
        service.call('run','services','update-traffic',name,'--region='+config['region'],'--to-revisions='+route['revisionName']+'=100','--format=json')
        routes[name]={'revision':route['revisionName'],'tag':tag};state['maintenance_routes']=routes;save()
    state['maintenance_started']=datetime.now(timezone.utc).isoformat();save()
    print(json.dumps({'maintenance_started':state['maintenance_started'],'drain_seconds':90}),flush=True)


def snapshot():
    shutil.copyfile(ROOT/'build/full-backend-deploy-2026-10-26/aggregate_counts.py',WORK/'aggregate_counts.py')
    d.aggregate_snapshot()


def operator_jobs():
    assert state.get('backup_id') and state.get('worker_stopped')
    d.update_image(service.n['migrate'])
    state['operator_jobs_updated']=True;save()
    print(json.dumps({'operator_image_updated':True,'schema_migration_required':False}),flush=True)


def data_phase():
    assert state.get('maintenance_started')
    if not state.get('worker_stopped'):
        while (datetime.now(timezone.utc)-datetime.fromisoformat(state['maintenance_started'])).total_seconds()<90:
            time.sleep(2)
        d.stop_worker()
    if not state.get('data_before'):snapshot()
    if not state.get('backup_id'):d.backup()
    if not state.get('operator_jobs_updated'):operator_jobs()
    if not state.get('catalogue_applied'):catalogue(True)
    if not state.get('data_preserved'):preserved_counts()


def preserved_counts():
    code='''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
before=__BEFORE__
protected=['players','identities','session_families','session_tokens','runs','personal_bests','lap_personal_bests','coin_wallets','coin_rewards','coin_milestones','purchases','challenges','rivalry_groups','rivalry_members','rivalry_bests','tracks']
with e.connect() as c:
 counts={name:c.scalar(text('SELECT count(*) FROM "'+name+'"')) for name in protected if name in before['tables']}
 assert all(value==before['tables'][name] for name,value in counts.items())
 count=c.scalar(text('SELECT count(*) FROM track_versions'))
 assert count==before['tables']['track_versions']+__ADDED__
 result={'protected_table_counts_unchanged':counts,'new_version_rows':__ADDED__,'private_rows_or_hashes_exported':False}
print('RELEASE_RESULT='+json.dumps(result));e.dispose()
'''.replace('__BEFORE__',repr(state['data_before'])).replace('__ADDED__',str(state['catalogue_preview']['matching_revisions_needed']))
    d.execute('protected-counts-after',code,job=service.n['migrate'])
    state['data_preserved']=True;save();print(json.dumps({'old_history_counts_unchanged':True,'new_immutable_revisions':state['catalogue_preview']['matching_revisions_needed']}),flush=True)


def verify_manifest(origin):
    response=d.http(origin,'/v1/manifest');assert response.status_code==200
    assert response.json()==state['expected_manifest'],'Live manifest differs from the validated current game'


def canary():
    check_sources();assert state.get('catalogue_applied') and state.get('data_preserved')
    routes={}
    for name in (service.n['api'],service.n['admin']):
        tag=TAG+'-new';d.update_image(name,no_traffic=True,tag=tag)
        resource=service.describe('api',name);route=next(row for row in resource['status']['traffic'] if row.get('tag')==tag)
        assert route.get('percent',0)==0
        result=d.verify_api(route['url']) if name==service.n['api'] else d.verify_admin(route['url'])
        if name==service.n['api']:verify_manifest(route['url'])
        write(OUT/('canary-api.json' if name==service.n['api'] else 'canary-studio.json'),result)
        routes[name]={'revision':route['revisionName'],'url':route['url'],'tag':tag};state['canaries']=routes;save()
    state['canary_passed']=True;save();print(json.dumps({'canaries_passed':True,'current_game_manifest_exact':True}),flush=True)


def prepromotion_smoke():
    assert state.get('matching_worker_ready')
    code='''import json,os,time
from sqlalchemy import select
from bmt_backend.config import Settings
from bmt_backend.cloud_smoke import check
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.verifier import GodotVerifier
from bmt_backend.rivalry import eligible_query,week_window
from bmt_backend.rivalry_planning import plan_contract
from bmt_backend.rivalry_models import RivalryWeekPlan
from bmt_backend.track_models import now
s=Settings.from_env();r=check(s,os.environ['BMT_STAGING_OWNER'])
e=make_engine(s.database_url,s);factory=make_session_factory(e);v=GodotVerifier(s)
try:
 active=v.manifest()
 for attempt in range(60):
  with factory() as session:
   eligibility={vehicle:len(session.scalars(eligible_query(active,vehicle).limit(6)).all()) for vehicle in active['vehicles']}
   plans={vehicle:session.scalar(select(RivalryWeekPlan).where(RivalryWeekPlan.week_start==week_window(now())[0],RivalryWeekPlan.contract_key==plan_contract(active,vehicle))) for vehicle in active['vehicles']}
   ready={vehicle:len(plan.tracks) if plan else 0 for vehicle,plan in plans.items()}
   if min(eligibility.values())>=5 and all(count==5 for count in ready.values()):break
  time.sleep(2)
 else:raise RuntimeError('Current-build Weekly Rivalry calendar is not ready')
 r['weekly_rivalry']={'compatible_vehicles':len(ready),'current_week_tracks_per_vehicle':ready,'eligible_candidates_capped_at_six':eligibility}
 print('RELEASE_RESULT='+json.dumps(r))
finally:v.close();e.dispose()
'''
    result=d.execute('live-catalogue-replay-smoke',code,timeout=360)
    assert result['status']=='passed' and result['catalogue']['compatible_tracks']==30
    state['smoke_passed']=True;save();print(json.dumps(result),flush=True)


def promote():
    check_sources();assert state.get('smoke_passed')
    d.promote();verify_manifest(state['url'])


def public_contracts():
    import requests
    response=requests.post(state['url']+'/v1/discovery/v3/tracks',json={'query':{'sort':'name'}},timeout=(5,30))
    contracts=[]
    for _ in range(20):
        response.raise_for_status();page=response.json()
        for item in page['items']:
            value=requests.get(state['url']+'/v1/track-versions/'+item['version_id'],timeout=(5,30));value.raise_for_status()
            data=value.json();manifest=data['manifest']
            for key,expected in state['expected_manifest'].items():assert manifest[key]==expected
            contracts.append({'version_id':item['version_id'],'manifest':manifest})
        if not page.get('next_cursor'):break
        response=requests.post(state['url']+'/v1/discovery/v3/tracks',json={'cursor':page['next_cursor']},timeout=(5,30))
    assert len(contracts)==30 and len({row['version_id'] for row in contracts})==30
    write(WORK/'live-contracts.json',contracts);write(OUT/'published-contracts-after.json',contracts)
    state['public_contracts_passed']=True;save();print(json.dumps({'live_tracks':30,'compatible_vehicle_contracts':30*7}),flush=True)


def native_client():
    assert state.get('public_contracts_passed')
    check_sources()
    environment={**os.environ,'BMT_LIVE_CONTRACTS':str(WORK/'live-contracts.json'),
                 'BMT_CONTRACT_PROBE_ROOT':str(WORK/'native-probe')}
    result=subprocess.run(['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe',
        '--headless','--path',str(ROOT/'game'),'--script','res://tests/test_backend_live_contracts.gd'],
        env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
    output=result.stdout+result.stderr
    (OUT/'native-client.log').write_text(output,encoding='utf-8')
    assert result.returncode==0 and 'LIVE_CONTRACTS: 210 checks, 0 failures' in output and 'SCRIPT ERROR' not in output,output[-3000:]
    state['native_client_passed']=True;save()
    print(json.dumps({'actual_game_ticket_validation':210,'failures':0,'authenticated_races_created':0}),flush=True)


def finish():
    assert all(state.get(key) for key in ('promoted','smoke_passed','authority_passed','discovery_passed','public_contracts_passed','native_client_passed'))
    check_sources();final={}
    for name,kind in state['targets'].items():
        if kind=='api':
            resource=service.describe('api',name)
            tags={row['tag'] for row in resource['status']['traffic'] if row.get('tag')}
            assert tags<={TAG+'-maint',TAG+'-candidate',TAG+'-new'}
            if tags:service.call('run','services','update-traffic',name,'--region='+config['region'],'--remove-tags='+','.join(sorted(tags)),'--format=json')
        current=d.guarded(name,[state['image']])
        if kind=='api':assert any(row.get('revisionName')==state['canaries'][name]['revision'] and row.get('percent')==100 for row in current['status']['traffic']) and not any(row.get('tag') for row in current['status']['traffic'])
        if kind=='worker':assert int(current['metadata']['annotations']['run.googleapis.com/manualInstanceCount'])==state['worker_instances_before']
        final[name]={'kind':kind,'image':state['image'],'revision':current.get('status',{}).get('latestReadyRevisionName'),'runtime_preserved':True}
    verify_manifest(state['url']);write(OUT/'final-targets.json',final);write(OUT/'final-api.json',d.verify_api(state['url']))
    directory=ROOT/'.tools/gcp-staging'/('rendered-'+config['owner'])
    for filename in ('deployment.json','image.json','test-population.json'):
        path=directory/filename
        if not path.exists():continue
        previous=json.loads(path.read_text());shutil.copyfile(path,WORK/(filename+'.before.private.json'))
        value={**previous,'image':state['image']}
        if filename in ('deployment.json','image.json'):value['source_hash']=state['source_hash']
        write(path,value)
    assert json.loads(LOCK.read_text())=={'task':'backend-compatibility-20261027','source_hash':state['source_hash']};LOCK.unlink()
    state['complete']=True;state['completed_utc']=datetime.now(timezone.utc).isoformat();save()
    write(OUT/'rollout.json',{key:state[key] for key in ('image','image_id','source_hash','expected_manifest','url','backup_id','schema_before','maintenance_started','maintenance_ended','completed_utc','canaries','complete')})
    print(json.dumps({'complete':True,'targets':len(final),'manifest_matches_game':True,'public_track_contracts':210}),flush=True)


def service_phase():
    assert state.get('data_preserved') and state.get('catalogue_applied')
    for flag,name,action in (
        ('canary_passed','canary',canary),
        ('matching_worker_ready','start-targets',d.start_targets),
        ('smoke_passed','prepromotion-smoke',prepromotion_smoke),
        ('promoted','promote',promote),
        ('public_contracts_passed','public-contracts',public_contracts),
        ('native_client_passed','native-client',native_client),
        ('authority_passed','authority',d.authority),
        ('discovery_passed','discovery',d.discovery),
        ('complete','finish',finish)):
        if state.get(flag):continue
        print('STAGE='+name,flush=True);action()


def main():
    actions={'inspect':inspect_live,'prepare':prepare,'build':build,'test':test_image,'push':push,
             'prepare-maintenance':prepare_maintenance,'preview':lambda:catalogue(False),'catalogue':lambda:catalogue(True),
             'quiesce':quiesce,'data-phase':data_phase,'stop-worker':d.stop_worker,'snapshot':snapshot,'backup':d.backup,'operator-jobs':operator_jobs,'preserved-counts':preserved_counts,
             'canary':canary,'service-phase':service_phase,'start-targets':d.start_targets,'smoke':prepromotion_smoke,'promote':promote,
             'authority':d.authority,'discovery':d.discovery,'public-contracts':public_contracts,'native-client':native_client,'finish':finish}
    p=argparse.ArgumentParser();p.add_argument('stage',choices=actions);actions[p.parse_args().stage]()


if __name__=='__main__':main()
