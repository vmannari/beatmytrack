"""Stale batch continuation retains canonical fences and all prior history."""
import copy
import dataclasses
import importlib.util
import json
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import event, select
from sqlalchemy.orm import Session
from test_auth_postgres import postgres_auth as postgres_fixture
from test_backend_resource_optimisation import HEADERS, KEY, claim
from test_backend_resource_optimisation import batch as batch_fixture
from test_domains import FakeVerifier
from test_resource_native import native as native_fixture
from test_rivalry import seed
from test_test_drivers import auth
from test_test_drivers import drivers as drivers_fixture

from bmt_backend.identity_models import Identity, Player
from bmt_backend.test_driver_models import TestDriverProfile as DriverProfile
from bmt_backend.test_population_batch import ACTIVE
from bmt_backend.track_models import Board, OperationState, PersonalBest, Run, RunTicket, TrackVersion
from bmt_backend.worker import process_one

drivers=drivers_fixture
batch=batch_fixture
postgres_auth=postgres_fixture
native=native_fixture


def prepare(d,batch_id):
    return d.client.post('/v1/dev/test-drivers/batches/'+batch_id+'/prepare-local',headers=HEADERS)


def obsolete(d,batch_id):
    with d.factory() as db:
        row=db.get(OperationState,'test-pop-batch:'+batch_id)
        row.details={**row.details,'manifest':{**row.details['manifest'],'physics_version':'arcade-planar-0.53',
            'rules_key':'standing-5-road-gates-v20','compiler_version':'old-compiler'}}
        db.commit()


def operations(d):
    with d.factory() as db:
        return {r.id:copy.deepcopy(r.details) for r in db.scalars(select(OperationState))}


def history(d):
    with d.factory() as db:
        return {model.__tablename__:json.dumps([dict(row) for row in db.execute(select(model.__table__)).mappings()],
            sort_keys=True,default=str) for model in (Player,Identity,DriverProfile,Board,RunTicket,Run,PersonalBest)}


def test_matching_batch_preparation_is_a_noop(batch):
    d,batch_id=batch;before=operations(d)
    result=prepare(d,batch_id)
    assert result.status_code==200,result.text
    assert result.json()['batch']['batch_id']==batch_id and not result.json()['continued']
    assert operations(d)==before


def test_stale_plan_continues_without_clearing_results_players_or_old_jobs(batch):
    d,batch_id=batch;first=claim(d,batch_id).json()['work']['job']
    ticket=d.client.post('/v1/run-tickets',headers=auth(d.login),json={'version_id':first['version_id'],'vehicle_id':'compact'})
    assert ticket.status_code==201,ticket.text
    result=d.client.post('/v1/runs',headers=auth(d.login),json={'ticket_id':ticket.json()['ticket_id'],
        'replay':{'schema':'bmt-replay-v1','frames':[[0,166,0]]*30}})
    assert result.status_code==202 and process_one(d.app)
    obsolete(d,batch_id);before=operations(d);protected=history(d)
    assert claim(d,batch_id).status_code==409  # Keep the original build fence.
    result=prepare(d,batch_id)
    assert result.status_code==200,result.text
    view=result.json()['batch'];replacement=view['batch_id']
    assert replacement!=batch_id and result.json()['continued']
    assert view['cleared_test_records']==0 and view['protected_real_records']==1
    assert view['driver_count']==2 and view['jobs']=={'waiting':view['expected_jobs']}
    assert history(d)==protected
    after=operations(d)
    for key,value in before.items():
        if key.startswith('test-pop-job:'):assert after[key]==value
    old=after['test-pop-batch:'+batch_id];new=after['test-pop-batch:'+replacement]
    assert old['status']=='superseded' and old['continued_as']==replacement
    assert new['continued_from']==batch_id and new['player_ids']==old['player_ids']
    assert new['manifest']==d.app.state.verifier.manifest() and not new['request']['clear_test_records']
    assert all(j['version_id'] in {t['version_id'] for t in new['tracks']} and j['player_id'] in old['player_ids']
        for key,j in after.items() if key.startswith('test-pop-job:') and j['batch_id']==replacement)
    route=f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{first['id']}/complete"
    assert d.client.post(route,headers=HEADERS,json={'lease_token':first['lease_token'],'failure':'timeout'}).status_code==409
    assert prepare(d,batch_id).json()['batch']['batch_id']==replacement
    assert operations(d)==after
    assert claim(d,replacement).status_code==200


def test_missing_current_catalog_preserves_old_plan(batch):
    d,batch_id=batch;obsolete(d,batch_id)
    with d.factory() as db:
        for v in db.scalars(select(TrackVersion)):
            v.manifest={**v.manifest,'physics_version':'arcade-planar-0.53'}
        db.commit()
    before=operations(d);protected=history(d)
    assert prepare(d,batch_id).status_code==409
    assert operations(d)==before and history(d)==protected


def test_disabled_artificial_profile_never_reappears(batch):
    d,batch_id=batch;obsolete(d,batch_id)
    with d.factory() as db:
        player_id=db.get(OperationState,'test-pop-batch:'+batch_id).details['player_ids'][0]
        db.get(Player,player_id).disabled=True;db.commit()
    before=operations(d)
    assert prepare(d,batch_id).status_code==409 and operations(d)==before


def test_prepare_keeps_operator_and_development_gates(batch):
    d,batch_id=batch;obsolete(d,batch_id);before=operations(d)
    route='/v1/dev/test-drivers/batches/'+batch_id+'/prepare-local'
    assert d.client.post(route).status_code==401
    d.app.state.settings=dataclasses.replace(d.app.state.settings,test_drivers_enabled=False)
    assert d.client.post(route,headers=HEADERS).status_code==404 and operations(d)==before


def test_old_id_does_not_redirect_to_an_unrelated_active_batch(batch):
    d,batch_id=batch;obsolete(d,batch_id)
    replacement=prepare(d,batch_id).json()['batch']['batch_id']
    with d.factory() as db:
        guard=db.get(OperationState,ACTIVE);guard.details={**guard.details,'batch_id':str(uuid.uuid4())};db.commit()
    before=operations(d)
    assert prepare(d,batch_id).status_code==409 and prepare(d,replacement).status_code==409
    assert operations(d)==before


def test_failed_continuation_commit_rolls_back_every_new_job_and_guard(batch):
    d,batch_id=batch;obsolete(d,batch_id);before=operations(d)
    def fail(session):
        if any(isinstance(row,OperationState) and row.id==ACTIVE and row.details['batch_id']!=batch_id for row in session.dirty):
            raise RuntimeError('Owned fixture commit interruption')
    event.listen(Session,'before_commit',fail)
    try:
        assert prepare(d,batch_id).status_code==500
    finally:event.remove(Session,'before_commit',fail)
    assert operations(d)==before


@pytest.mark.postgres
def test_postgres_concurrent_continuations_commit_exactly_one_replacement(postgres_auth):
    app,client=postgres_auth
    app.state.settings=dataclasses.replace(app.state.settings,environment='development',dev_auth_enabled=True,
        dev_auth_key=KEY,test_drivers_enabled=True,allow_sync_track_validation=True,write_limit_per_minute=1000)
    app.state.verifier=FakeVerifier()
    login=client.post('/v1/auth/developer',headers=HEADERS).json()
    d=SimpleNamespace(app=app,client=client,factory=app.state.session_factory,players={'Creator':login['player']['id']},login=login)
    seed(d)
    preview=client.get('/v1/dev/test-drivers/batches/preview',headers=HEADERS).json()
    result=client.post('/v1/dev/test-drivers/batches',headers=HEADERS,json={'seed':41,'count':2,'vehicle_id':'compact',
        'clear_test_records':False,'inventory_digest':preview['inventory_digest']})
    assert result.status_code==200,result.text
    batch_id=result.json()['batch_id'];obsolete(d,batch_id);protected=history(d);barrier=threading.Barrier(2)
    def run(_):
        barrier.wait(timeout=10);response=prepare(d,batch_id)
        assert response.status_code==200,response.text
        return response.json()['batch']
    with ThreadPoolExecutor(max_workers=2) as pool:views=list(pool.map(run,range(2)))
    assert views[0]['batch_id']==views[1]['batch_id']!=batch_id
    with d.factory() as db:
        rows=db.scalars(select(OperationState).where(OperationState.id.startswith('test-pop-job:'),
            OperationState.details['batch_id'].as_string()==views[0]['batch_id'])).all()
        assert len(rows)==views[0]['expected_jobs']
    assert history(d)==protected


@pytest.mark.parametrize('prepare_only',[True,False])
def test_local_launcher_uses_continued_id_and_preserves_old_journal(tmp_path,monkeypatch,prepare_only):
    script=Path(__file__).resolve().parents[1]/'deploy/local_artificial.py'
    spec=importlib.util.spec_from_file_location('batch_recovery_launcher',script)
    launcher=importlib.util.module_from_spec(spec);spec.loader.exec_module(launcher)
    monkeypatch.setattr(launcher,'ROOT',tmp_path)
    config=tmp_path/'.tools/gcp-staging/config.json';config.parent.mkdir(parents=True)
    config.write_text(json.dumps({'project':'beat-my-track','region':'europe-west1','owner':'abcd1234',
        'gcloud':['fixture-gcloud'],'docker':['fixture-docker']}))
    old,new=str(uuid.uuid4()),str(uuid.uuid4())
    old_state=tmp_path/'.tools/artificial-races/batches'/old/'state.json';old_state.parent.mkdir(parents=True)
    old_state.write_text('{"unresolved_receipt":"original"}');original=old_state.read_bytes()
    origin='https://bmt-stg-abcd1234-api-fixture-ew.a.run.app'
    image='europe-west1-docker.pkg.dev/beat-my-track/images/backend@sha256:'+'a'*64
    commands=[]
    def command(args,**kwargs):
        commands.append(args)
        if args[0]=='fixture-gcloud':
            value={'status':{'url':origin},'spec':{'template':{'spec':{'containers':[{'env':[{'name':'BMT_DEV_AUTH_KEY','value':'test-only'}]}]}}}} if 'services' in args else {
                'spec':{'template':{'spec':{'containers':[{'image':image}]}}}}
            return SimpleNamespace(returncode=0,stdout=json.dumps(value),stderr='')
        return SimpleNamespace(returncode=0,stdout='',stderr='')
    monkeypatch.setattr(launcher.subprocess,'run',command)
    monkeypatch.setattr(launcher.requests,'get',lambda *args,**kwargs:SimpleNamespace(status_code=200,
        json=lambda:{'batch':{'batch_id':old,'complete':False}}))
    def request(url,**kwargs):
        assert url==origin+'/v1/dev/test-drivers/batches/'+old+'/prepare-local'
        assert kwargs['headers']=={'X-Dev-Auth-Key':'test-only'}
        return SimpleNamespace(status_code=200,json=lambda:{'continued':True,'batch':{'batch_id':new,'complete':False,
            'driver_count':100,'track_count':30,'expected_jobs':3000}})
    monkeypatch.setattr(launcher.requests,'post',request)
    launcher.run(SimpleNamespace(batch=None,rivalry=None,list_rivalries=False,inspect=False,cpus=1,max_jobs=1,prepare_only=prepare_only))
    assert old_state.read_bytes()==original
    docker=[args for args in commands if args[0]=='fixture-docker' and 'run' in args]
    if prepare_only:assert not docker
    else:
        args=docker[0]
        assert args[args.index('--batch')+1]==new
        assert args[args.index('--state')+1]=='/local/batches/'+new+'/state.json'
        assert not list((tmp_path/'.tools/artificial-races').rglob('*.private.env'))


@pytest.mark.godot
def test_continued_native_batch_uploads_new_revision_and_verifies_independently(native,tmp_path):
    from fastapi.testclient import TestClient
    from test_backend_resource_optimisation import LocalAPI

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.local_artificial_races import run_pass
    from bmt_backend.migrate import upgrade
    from bmt_backend.official_tracks import seed_documents
    engine,document=native
    settings=Settings(environment='development',dev_auth_enabled=True,dev_auth_key=KEY,test_drivers_enabled=True,
        database_url='sqlite:///'+(tmp_path/'native.sqlite').as_posix(),object_dir=str(tmp_path/'objects'),
        godot_bin=engine.godot_bin,game_project=engine.game_project,persistent_verifier=True,
        auth_limit_per_minute=1000,write_limit_per_minute=1000)
    app=create_app(settings);upgrade(app.state.engine)
    try:
        with TestClient(app) as client:
            client.post('/v1/auth/developer',headers=HEADERS).raise_for_status()
            seed_documents(app.state.session_factory,app.state.blobs,app.state.verifier,[document])
            d=SimpleNamespace(app=app,client=client,factory=app.state.session_factory)
            preview=client.get('/v1/dev/test-drivers/batches/preview',headers=HEADERS).json()
            batch_id=client.post('/v1/dev/test-drivers/batches',headers=HEADERS,json={'seed':41,'count':1,
                'clear_test_records':False,'inventory_digest':preview['inventory_digest']}).json()['batch_id']
            with d.factory() as db:
                old=db.get(TrackVersion,preview['tracks'][0]['version_id'])
                fresh=TrackVersion(track_id=old.track_id,number=old.number+1,name=old.name,content_hash=old.content_hash,
                    manifest=copy.deepcopy(old.manifest),state='published',discovery=old.discovery)
                db.add(fresh);db.flush();new_version=fresh.id
                old.manifest={**old.manifest,'physics_version':'arcade-planar-0.53'};db.commit()
            obsolete(d,batch_id)
            replacement=prepare(d,batch_id).json()['batch']['batch_id']
            assert replacement!=batch_id
            result=run_pass(LocalAPI(d),settings,tmp_path/'local'/'state.json',replacement)
            assert result['results']==['submitted'] and process_one(app)
            view=client.get('/v1/dev/test-drivers/batches/'+replacement,headers=HEADERS).json()
            assert view['complete'] and view['jobs']=={'verified':1} and view['tracks'][0]['version_id']==new_version
            with d.factory() as db:
                run=db.scalar(select(Run));assert db.get(Board,run.board_id).version_id==new_version
            assert client.get('/v1/track-versions/'+new_version+'/leaderboard?vehicle_id=compact').json()['population']==0
    finally:
        app.state.verifier.close();app.state.engine.dispose()
