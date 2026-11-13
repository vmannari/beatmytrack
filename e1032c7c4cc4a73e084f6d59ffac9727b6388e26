"""On-demand local generation, fenced receipts, idle engines and worker isolation."""
import dataclasses
import json
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_auth_postgres import postgres_auth as postgres_fixture
from test_domains import FakeVerifier
from test_rivalry import seed
from test_test_drivers import KEY, auth, bot_login
from test_test_drivers import drivers as drivers_fixture

from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.test_driver_generator import publish_trajectory
from bmt_backend.track_models import OperationState, Run
from bmt_backend.verifier import _ENGINE_SLOT, GodotVerifier
from bmt_backend.worker import process_one
from bmt_backend.worker_app import create_worker_app

drivers = drivers_fixture
postgres_auth = postgres_fixture
HEADERS = {"X-Dev-Auth-Key": KEY}


@pytest.fixture
def batch(drivers):
    response = drivers.client.get("/v1/dev/test-drivers/batches/preview", headers=HEADERS)
    assert response.status_code == 200, response.text
    result = drivers.client.post("/v1/dev/test-drivers/batches", headers=HEADERS, json={"seed": 41, "count": 2,
        "vehicle_id": "compact", "clear_test_records": False, "inventory_digest": response.json()["inventory_digest"]})
    assert result.status_code == 200, result.text
    return drivers, result.json()["batch_id"]


def claim(drivers, batch_id, runner=None):
    return drivers.client.post(f"/v1/dev/test-drivers/batches/{batch_id}/claim", headers=HEADERS,
        json={"runner_id": runner or str(uuid.uuid4())})


def test_idle_worker_never_launches_artificial_work_even_with_development_enabled(batch, monkeypatch):
    d, batch_id = batch
    def forbidden(*args, **kwargs):
        raise AssertionError("Cloud worker must not generate artificial races")
    monkeypatch.setattr("bmt_backend.automatic_test_drivers.drive_idle", forbidden)
    monkeypatch.setattr("bmt_backend.test_population_batch.drive_idle", forbidden)
    d.app.state.driver_work = SimpleNamespace(poll=forbidden)
    for _ in range(3):
        assert not process_one(d.app)
    with d.factory() as db:
        assert db.scalar(select(Run.id)) is None
    assert d.client.get(f"/v1/dev/test-drivers/batches/{batch_id}", headers=HEADERS).json()["execution"] == "local_on_demand"


def test_claim_is_private_resumable_and_exclusive(batch):
    d, batch_id = batch;runner = str(uuid.uuid4())
    route = f"/v1/dev/test-drivers/batches/{batch_id}/claim"
    assert d.client.post(route, json={"runner_id": runner}).status_code == 401
    first = claim(d, batch_id, runner)
    assert first.status_code == 200, first.text
    work = first.json()["work"]
    assert claim(d, batch_id, runner).json()["work"]["job"]["lease_token"] == work["job"]["lease_token"]
    other = claim(d, batch_id).json()["work"]
    assert other["job"]["id"] != work["job"]["id"]
    with d.factory() as db:
        assert db.get(Player, work["job"]["player_id"]).is_test_driver
    d.app.state.settings = dataclasses.replace(d.app.state.settings, test_drivers_enabled=False)
    assert claim(d, batch_id, runner).status_code == 404


def test_expired_lease_cannot_overwrite_new_owner_and_failure_retries_are_bounded(batch):
    d, batch_id = batch;old = claim(d, batch_id).json()["work"]["job"]
    with d.factory() as db:
        row = db.get(OperationState, "test-pop-job:"+old["id"])
        row.details = {**row.details, "lease_until": 0};db.commit()
    runner = str(uuid.uuid4());replacement = claim(d, batch_id, runner).json()["work"]["job"]
    # Claims use stable ordering, so explicitly fence the old job regardless of
    # whether another waiting job was earlier in that order.
    route = f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{old['id']}/complete"
    assert d.client.post(route, headers=HEADERS, json={"lease_token": old["lease_token"], "failure": "timeout"}).status_code == 409
    with d.factory() as db:
        row = db.get(OperationState, "test-pop-job:"+replacement["id"])
        row.details = {**row.details, "attempt": 4};db.commit()
    route = f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{replacement['id']}/complete"
    reply = d.client.post(route, headers=HEADERS, json={"lease_token": replacement["lease_token"], "failure": "timeout"})
    assert reply.status_code == 200 and reply.json()["status"] == "uncompleted"


def test_normal_upload_receipt_is_required_and_batch_progress_follows_verification(batch):
    d, batch_id = batch;work = claim(d, batch_id).json()["work"];job = work["job"]
    route = f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{job['id']}/complete"
    body = {"lease_token": job["lease_token"], "run_id": str(uuid.uuid4())}
    assert d.client.post(route, headers=HEADERS, json=body).status_code == 409
    login = bot_login(d, {"subject": job["subject"], "display_name": job["subject"]})
    ticket = d.client.post("/v1/run-tickets", headers=auth(login), json={"version_id": job["version_id"],
        "vehicle_id": "compact", "test_population": True})
    assert ticket.status_code == 201, ticket.text
    uploaded = d.client.post("/v1/runs", headers=auth(login), json={"ticket_id": ticket.json()["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0,166,0]]*30}})
    assert uploaded.status_code == 202, uploaded.text
    body["run_id"] = uploaded.json()["run_id"]
    assert d.client.post(route, headers=HEADERS, json=body).json()["status"] == "submitted"
    assert d.client.post(route, headers=HEADERS, json=body).status_code == 200
    assert process_one(d.app)
    view = d.client.get(f"/v1/dev/test-drivers/batches/{batch_id}", headers=HEADERS).json()
    assert view["jobs"]["verified"] == 1


def test_real_player_upload_cannot_be_attached_to_an_artificial_job(batch):
    d,batch_id=batch;job=claim(d,batch_id).json()['work']['job']
    ticket=d.client.post('/v1/run-tickets',headers=auth(d.login),json={'version_id':job['version_id'],'vehicle_id':'compact'})
    assert ticket.status_code==201,ticket.text
    uploaded=d.client.post('/v1/runs',headers=auth(d.login),json={'ticket_id':ticket.json()['ticket_id'],
        'replay':{'schema':'bmt-replay-v1','frames':[[0,166,0]]*30}})
    assert uploaded.status_code==202,uploaded.text
    reply=d.client.post(f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{job['id']}/complete",headers=HEADERS,
        json={'lease_token':job['lease_token'],'run_id':uploaded.json()['run_id']})
    assert reply.status_code==409
    assert process_one(d.app)
    with d.factory() as db:
        assert db.get(Run,uploaded.json()['run_id']).status=='verified'
        assert db.get(OperationState,'test-pop-job:'+job['id']).details['status']=='generating'
        assert not db.get(Player,d.players['Creator']).is_test_driver


def test_worker_factory_owns_resources_without_http_or_staff_clients(tmp_path):
    app = create_worker_app(Settings(environment="test", workload_role="worker", database_url="sqlite://",
        object_dir=str(tmp_path/'objects')), verifier=SimpleNamespace())
    assert not hasattr(app, "routes") and not hasattr(app.state, "staff_identity_verifier")
    assert not hasattr(app.state, "studio_reporting") and not hasattr(app.state, "http_costs")
    assert app.state.engine._bmt_run_signals is app.state.run_signals
    app.state.engine.dispose()
    with pytest.raises(ValueError):
        create_worker_app(Settings(environment="test"))


def test_idle_retirement_preserves_contract_and_cannot_interrupt_a_busy_engine(monkeypatch):
    verifier = GodotVerifier(SimpleNamespace(godot_bin="fixture", game_project=".", verifier_timeout_seconds=90,
        persistent_verifier=True, verifier_idle_seconds=1))
    verifier._versions = {"immutable": "fixture"}
    verifier._service = object();verifier._last_engine_use = time.monotonic()-3
    closed = []
    def close():
        closed.append(True);verifier._service = None
    monkeypatch.setattr(verifier, "close", close)
    assert _ENGINE_SLOT.acquire(False)
    try:
        assert not verifier.retire_idle() and not closed
    finally:
        _ENGINE_SLOT.release()
    assert verifier.retire_idle() and closed == [True]
    assert verifier.manifest() == {"immutable": "fixture"}
    assert not verifier.retire_idle()


def test_complete_checkpoint_survives_later_failure_but_partial_output_does_not_poison_cache(tmp_path):
    source=tmp_path/'native.json';target=tmp_path/'cache'/'trajectory.json';target.parent.mkdir()
    source.write_text('{"rows":[')
    assert not publish_trajectory(source,target) and not target.exists()
    value={"version":"racing-trajectory-4","key":"a"*64,"rows":[[1,2,3]]}
    source.write_text(json.dumps(value));assert publish_trajectory(source,target)
    original=target.read_bytes();source.write_text('{"rows":[NaN],"key":"'+'a'*64+'"}')
    assert not publish_trajectory(source,target) and target.read_bytes() == original
    assert not list(target.parent.glob('*.tmp'))


def test_http_workload_loads_no_unmounted_route_tree(tmp_path):
    code="""import json,sys
from bmt_backend.app import create_app
from bmt_backend.config import Settings
a=create_app(Settings(environment='test',workload_role='api',database_url='sqlite://',object_dir=sys.argv[1]))
assert 'bmt_backend.studio_usage' not in sys.modules
assert 'bmt_backend.admin_commerce' not in sys.modules
assert '/v1/run-tickets' in a.openapi()['paths']
print(json.dumps({'paths':len(a.routes)}))
"""
    result=subprocess.run([sys.executable,'-c',code,str(tmp_path/'objects')],capture_output=True,text=True,timeout=30,check=False)
    assert result.returncode==0,result.stderr


@pytest.mark.parametrize("value", [-1,301,True,1.5])
def test_idle_retirement_setting_is_bounded(value):
    with pytest.raises(ValueError):
        Settings(verifier_idle_seconds=value)


def test_settings_validation_does_not_load_cloud_transports():
    code="""import sys
from bmt_backend.config import Settings
Settings()
assert 'google.auth' not in sys.modules
assert 'bmt_backend.studio_usage_cloud' not in sys.modules
"""
    result=subprocess.run([sys.executable,'-c',code],capture_output=True,text=True,timeout=20,check=False)
    assert result.returncode==0,result.stderr


def test_idle_heartbeats_stay_fresh_without_per_second_writes(auth_app,monkeypatch):
    from bmt_backend import operations
    clock=[0.0];writes=[]
    monkeypatch.setattr(operations.time,'monotonic',lambda:clock[0])
    monkeypatch.setattr(operations,'_write_heartbeat',lambda app,key,details:writes.append(dict(details)) or details.get('build'))
    for second in range(60):
        clock[0]=float(second)
        operations.heartbeat(auth_app,'idle-probe',phase='idle',coalesce=True)
    assert len(writes)==2
    clock[0]=60.0
    operations.heartbeat(auth_app,'idle-probe',phase='verifying',last_queue_wait_seconds=2,coalesce=True)
    assert len(writes)==3 and writes[-1]['phase']=='verifying'
    operations.heartbeat(auth_app,'idle-probe',lifecycle='draining',coalesce=True)
    assert len(writes)==4 and writes[-1]['lifecycle']=='draining'


def test_replaced_active_batch_fences_old_receipts(batch):
    d,batch_id=batch;job=claim(d,batch_id).json()['work']['job']
    with d.factory() as db:
        guard=db.get(OperationState,'test-population-active')
        guard.details={**guard.details,'batch_id':str(uuid.uuid4())};db.commit()
    route=f"/v1/dev/test-drivers/batches/{batch_id}/jobs/{job['id']}/complete"
    assert d.client.post(route,headers=HEADERS,json={'lease_token':job['lease_token'],'failure':'timeout'}).status_code==409
    assert claim(d,batch_id).status_code==409


def test_local_rivalry_plans_expose_only_existing_artificial_members(drivers):
    d=drivers
    group=d.client.post('/v1/rivalry/join',headers=auth(d.login),json={'vehicle_id':'compact',
        'test_population':True,'automatic_test_drivers':True}).json()
    route='/v1/dev/test-drivers/local-rivalries/'+group['group_id']+'/plan'
    assert d.client.get(route).status_code==401
    response=d.client.get(route,headers=HEADERS)
    assert response.status_code==200,response.text
    plan=response.json()
    assert len(plan['profiles'])==13 and 0<len(plan['jobs'])<=325
    assert all(0<=j['slot']<5 and j['subject'] in {p['subject'] for p in plan['profiles']} for j in plan['jobs'])
    assert len({j['id'] for j in plan['jobs']})==len(plan['jobs'])
    assert all(p['is_test_driver'] and p['player_id']!=d.players['Creator'] for p in plan['profiles'])
    assert all(j['group_id']==group['group_id'] for j in plan['jobs'])
    assert group['group_id'] in {g['group_id'] for g in d.client.get('/v1/dev/test-drivers/local-rivalries',headers=HEADERS).json()['groups']}
    real=d.client.post('/v1/rivalry/join',headers=auth(d.login),json={'vehicle_id':'compact'}).json()
    assert d.client.get('/v1/dev/test-drivers/local-rivalries/'+real['group_id']+'/plan',headers=HEADERS).status_code==404


class LocalAPI:
    """Use the actual HTTP protocol with an owned database and fake proof only."""
    url='http://localhost'
    non_improving_runs=False
    def __init__(self,d):
        self.d=d;self.tokens={};self.fail_ack=False;self.uploads=0
    def call(self,method,path,body=None,subject=None,idempotency=None,operator=False):
        headers=dict(HEADERS) if operator else {}
        if subject:
            if subject not in self.tokens:
                self.tokens[subject]=bot_login(self.d,{'subject':subject,'display_name':subject})
            headers.update(auth(self.tokens[subject]))
        if idempotency:headers['Idempotency-Key']=idempotency
        if path=='/runs':self.uploads+=1
        response=self.d.client.request(method,'/v1'+path,headers=headers,json=body)
        assert response.status_code<300,response.text
        if path.endswith('/complete') and self.fail_ack:
            self.fail_ack=False
            raise OSError('Simulated lost acknowledgement after commit')
        return response.json()


def test_local_pass_recovers_lost_ack_and_keeps_a_bounded_journal(batch,tmp_path,monkeypatch):
    from contextlib import contextmanager

    from bmt_backend import local_artificial_races as runner
    d,batch_id=batch;api=LocalAPI(d);api.fail_ack=True;calls=[]
    @contextmanager
    def engine(settings):yield d.app.state.verifier
    monkeypatch.setattr(runner,'controller_engine',engine)
    def recording(*args,**kwargs):
        calls.append(True)
        return {'replay':{'schema':'bmt-replay-v1','frames':[[0,166,0]]*30}}
    monkeypatch.setattr(runner,'recording',recording)
    path=tmp_path/'local'/'state.json'
    with pytest.raises(OSError,match='lost acknowledgement'):
        runner.run_pass(api,d.app.state.settings,path,batch_id)
    assert api.uploads==1 and len(calls)==1
    assert len(json.loads(path.read_text())['receipts'])==1
    # Same runner now receives a different job because the first receipt was
    # committed. Its previous race must never be generated/uploaded again.
    result=runner.run_pass(api,d.app.state.settings,path,batch_id)
    assert result['attempted']==1 and api.uploads==2 and len(calls)==2
    assert json.loads(path.read_text())['receipts']=={}
    assert KEY not in path.read_text()
    assert process_one(d.app) and process_one(d.app)


@pytest.mark.parametrize('accepted',[True,False])
def test_local_pass_recovers_upload_or_replaces_only_an_unsubmitted_expired_ticket(batch,tmp_path,monkeypatch,accepted):
    from contextlib import contextmanager

    from bmt_backend import local_artificial_races as runner
    from bmt_backend.track_models import RunTicket
    d,batch_id=batch;generated=[]
    class InterruptedAPI(LocalAPI):
        interrupt=True
        def call(self,method,path,*args,**kwargs):
            if path=='/runs' and self.interrupt:
                self.interrupt=False
                if accepted:super().call(method,path,*args,**kwargs)
                raise OSError('Simulated interrupted upload')
            return super().call(method,path,*args,**kwargs)
    api=InterruptedAPI(d)
    @contextmanager
    def engine(settings):yield d.app.state.verifier
    monkeypatch.setattr(runner,'controller_engine',engine)
    def recording(*args,**kwargs):
        generated.append(True)
        return {'replay':{'schema':'bmt-replay-v1','frames':[[0,166,0]]*30}}
    monkeypatch.setattr(runner,'recording',recording)
    path=tmp_path/'local'/'state.json'
    with pytest.raises(OSError,match='interrupted upload'):
        runner.run_pass(api,d.app.state.settings,path,batch_id)
    state=json.loads(path.read_text());receipt=next(iter(state['receipts'].values()))
    old_ticket=receipt['ticket']['ticket_id'];receipt['ticket']['expires_at']=0
    path.write_text(json.dumps(state))
    with d.factory() as db:
        db.get(RunTicket,old_ticket).expires_at=0;db.commit()
    result=runner.run_pass(api,d.app.state.settings,path,batch_id)
    assert result['results']==['submitted'] and api.uploads==1
    assert len(generated)==(1 if accepted else 2)
    with d.factory() as db:
        run=db.scalar(select(Run))
        assert (run.ticket_id==old_ticket)==accepted


@pytest.mark.postgres
def test_postgres_concurrent_claims_and_terminal_reconciliation_commit(postgres_auth):
    app,client=postgres_auth
    app.state.settings=dataclasses.replace(app.state.settings,environment='development',dev_auth_enabled=True,
        dev_auth_key=KEY,test_drivers_enabled=True,allow_sync_track_validation=True,write_limit_per_minute=1000)
    app.state.verifier=FakeVerifier()
    login=client.post('/v1/auth/developer',headers=HEADERS).json()
    d=SimpleNamespace(app=app,client=client,factory=app.state.session_factory,players={'Creator':login['player']['id']},login=login)
    seed(d)
    preview=client.get('/v1/dev/test-drivers/batches/preview',headers=HEADERS).json()
    batch=client.post('/v1/dev/test-drivers/batches',headers=HEADERS,json={'seed':41,'count':2,'vehicle_id':'compact',
        'clear_test_records':False,'inventory_digest':preview['inventory_digest']}).json()
    batch_id=batch['batch_id'];barrier=threading.Barrier(2)
    def concurrent_claim(_):
        barrier.wait(timeout=10)
        result=claim(d,batch_id)
        assert result.status_code==200,result.text
        return result.json()['work']['job']
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs=list(pool.map(concurrent_claim,range(2)))
    assert jobs[0]['id']!=jobs[1]['id'] and jobs[0]['lease_token']!=jobs[1]['lease_token']
    # Submit normal uploads, verify through the real worker state machine, then
    # force the no-work reconciliation branch and inspect its committed rows.
    api=LocalAPI(d)
    for job in jobs:
        ticket=api.call('POST','/run-tickets',{'version_id':job['version_id'],'vehicle_id':'compact','test_population':True},job['subject'])
        run=api.call('POST','/runs',{'ticket_id':ticket['ticket_id'],'replay':{'schema':'bmt-replay-v1','frames':[[0,166,0]]*30}},job['subject'])
        api.call('POST',f"/dev/test-drivers/batches/{batch_id}/jobs/{job['id']}/complete",{'lease_token':job['lease_token'],'run_id':run['run_id']},operator=True)
    assert process_one(app) and process_one(app)
    with d.factory() as db:
        for row in db.scalars(select(OperationState).where(OperationState.id.startswith('test-pop-job:'))):
            if row.details['id'] not in {job['id'] for job in jobs}:
                row.details={**row.details,'status':'uncompleted'}
        db.commit()
    assert claim(d,batch_id).json()['work'] is None
    with d.factory() as db:
        assert all(db.get(OperationState,'test-pop-job:'+job['id']).details['status']=='verified' for job in jobs)


@pytest.fixture
def postgres_admin(tmp_path,monkeypatch):
    import test_auth_postgres as fixtures
    create=fixtures.create_app
    def admin(settings,**kwargs):
        return create(dataclasses.replace(settings,workload_role='admin',studio_legacy_keys_enabled=True),**kwargs)
    monkeypatch.setattr(fixtures,'create_app',admin)
    yield from fixtures.postgres_auth.__wrapped__(tmp_path)


@pytest.mark.postgres
def test_original_studio_snapshot_assertions_under_explicit_admin(postgres_admin,monkeypatch):
    from test_studio import test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion
    test_postgres_snapshot_is_read_only_and_does_not_mix_worker_completion(postgres_admin,monkeypatch)
