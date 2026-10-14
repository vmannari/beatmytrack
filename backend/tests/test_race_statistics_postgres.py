"""Production row locks preserve one race observation through retries and projection."""
# ruff: noqa: F811
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

from sqlalchemy import func, select
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_product_analytics import body, observed
from test_race_statistics import package, render_setup

from bmt_backend.product_analytics import project_pending
from bmt_backend.race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
from bmt_backend.track_models import now


def test_postgres_one_race_package_parallel_retry_and_projection(postgres_auth):
    app,client=postgres_auth
    app.state.settings=replace(app.state.settings,telemetry_enabled=True,client_quality_enabled=True)
    signed=client.post('/v1/auth/google',json=google_request(app,client,'statistics-racer')).json()
    headers={'Authorization':'Bearer '+signed['access_token']};value=package()
    event=observed('race_statistics',at=now(),properties=value,id=value['race_id'])
    with ThreadPoolExecutor(max_workers=4) as pool:
        responses=list(pool.map(lambda _:client.post('/v1/telemetry/batches',headers=headers,json=body([event])),range(4)))
    assert sorted(response.json()['events'][0]['status'] for response in responses)==['accepted','duplicate','duplicate','duplicate']
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda _:project_pending(app.state.session_factory),range(4)))
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(RaceStatisticsReceipt))==1
        fact=session.scalar(select(RaceStatisticsDay));assert fact.races==1 and fact.frame_buckets[2]==90


def test_postgres_render_context_json_filters_and_distinct_options(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True, client_quality_enabled=True,
        admin_analyst_key="a" * 40)
    signed = client.post('/v1/auth/google', json=google_request(app, client, 'render-statistics-racer')).json()
    headers = {'Authorization': 'Bearer ' + signed['access_token']}
    for renderer in ('mobile', 'gl_compatibility'):
        value = package(schema_version=3, render_context=render_setup(renderer=renderer), render_context_changed=False)
        event = observed('race_statistics', at=now(), properties=value, id=value['race_id'])
        response = client.post('/v1/telemetry/batches', headers=headers, json=body([event]))
        assert response.json()['events'][0]['status'] == 'accepted'
    project_pending(app.state.session_factory)
    report = client.get('/v1/admin/race-statistics?renderer=mobile&context_state=stable',
        headers={'Authorization': 'Bearer ' + 'a' * 40})
    assert report.status_code == 200 and report.json()['totals']['races'] == 1
    assert len(report.json()['render_options']) == 2
