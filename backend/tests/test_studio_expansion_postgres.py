"""Race case edits and project diagnostic facts in an isolated PostgreSQL schema."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

from sqlalchemy import func, select
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_product_analytics import body, observed
from test_studio import headers

from bmt_backend.product_analytics import project_pending
from bmt_backend.quality_models import QualityFact
from bmt_backend.studio_case_models import StudioCaseEvent
from bmt_backend.track_models import now


def test_postgres_case_revision_and_permanent_commands_are_atomic(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings,admin_owner_key='o'*40,admin_analyst_key='a'*40)
    create = {'command_id':str(uuid4()),'title':'Concurrent support case'}
    with ThreadPoolExecutor(max_workers=4) as pool:
        results=list(pool.map(lambda _:client.post('/v1/admin/cases',headers=headers('owner'),json=create),range(4)))
    assert [result.status_code for result in results] == [200]*4
    assert len({result.json()['id'] for result in results}) == 1
    identity=results[0].json()['id'];endpoint='/v1/admin/cases/'+identity+'/events'
    def edit(_):
        return client.post(endpoint,headers=headers('owner'),json={'command_id':str(uuid4()),'expected_revision':0,'kind':'note','text':'Investigate durable upload'})
    with ThreadPoolExecutor(max_workers=4) as pool: responses=list(pool.map(edit,range(4)))
    assert sorted(response.status_code for response in responses) == [200,409,409,409]
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(StudioCaseEvent)) == 2


def test_postgres_quality_duplicate_upload_and_parallel_projection_are_one_effect(postgres_auth):
    app,client=postgres_auth
    app.state.settings=replace(app.state.settings,telemetry_enabled=True,client_quality_enabled=True)
    signed=client.post('/v1/auth/google',json=google_request(app,client,'quality-racer')).json()
    auth={'Authorization':'Bearer '+signed['access_token']}
    props={'device_class':'android_arm64','scene':'race','samples':100,'slow':10,**{f'b{i}':90 if i==2 else 10 if i==5 else 0 for i in range(8)}}
    observation=observed('quality_summary',at=now(),properties=props)
    def ingest(_):return client.post('/v1/telemetry/batches',headers=auth,json=body([observation]))
    with ThreadPoolExecutor(max_workers=4) as pool: responses=list(pool.map(ingest,range(4)))
    assert all(response.status_code==200 for response in responses)
    assert sorted(response.json()['events'][0]['status'] for response in responses)==['accepted','duplicate','duplicate','duplicate']
    with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(lambda _:project_pending(app.state.session_factory),range(4)))
    with app.state.session_factory() as session:
        fact=session.scalar(select(QualityFact))
        assert fact.reports==1 and fact.samples==100 and fact.slow==10
