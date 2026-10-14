"""One package per attempt; published-only spatial data; bounded prepared reads."""
# ruff: noqa: F811
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_product_analytics import AT, body, observed, product, send  # noqa: F401

from bmt_backend.product_analytics import project_pending
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.race_statistics import AGGREGATE_CELLS, merge_cells
from bmt_backend.race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
from bmt_backend.track_models import Board, RunTicket, Track, TrackVersion


def package(version=None, **changes):
    value={"schema_version":2,"race_id":str(uuid4()),"outcome":"finished","elapsed_ms":120000,
        "device_class":"android_arm64","device_model":"Phone M","os_version":"Android 15",
        "frame_buckets":[0,0,90,0,0,10,0,0],"cells":[],"segments":[],"position_samples":0,"dropped_samples":0}
    if version:value.update(track_version_id=version,cells=[[0,0,20,3],[1,0,10,1]],segments=[[0,30,4]],position_samples=30)
    return {**value,**changes}


def seed(product):
    app,_client,_headers,player=product
    app.state.settings=replace(app.state.settings,client_quality_enabled=True)
    with app.state.session_factory() as session:
        track=Track(owner_id=player);session.add(track);session.flush()
        version=TrackVersion(track_id=track.id,number=1,name='Published diagnostic loop',content_hash='a'*64,
            manifest={'laps':5,'tick_rate':120},state='published',discovery={'theme':'pine','points':[[0,0],[60,0],[60,60],[0,0]]})
        draft=TrackVersion(track_id=track.id,number=2,name='Private draft',content_hash='b'*64,manifest={},state='draft')
        session.add_all((version,draft));session.commit();return version.id,draft.id


def event(value):
    return observed('race_statistics',properties=value,id=value['race_id'])


def test_race_package_exactly_once_device_os_and_route_filters(product):
    app,client,_auth,_player=product;version,_draft=seed(product)
    first=package(version)
    assert send(product,[event(first)]).json()['events'][0]['status']=='accepted'
    assert send(product,[event(first)]).json()['events'][0]['status']=='duplicate'
    assert send(product,[event({**first,'elapsed_ms':120001})]).json()['events'][0]['reason']=='ID_CONFLICT'
    second=package(version,device_model='Phone N',os_version='Android 14',outcome='restarted')
    assert send(product,[event(second)]).json()['events'][0]['status']=='accepted'
    project_pending(app.state.session_factory,at=AT);project_pending(app.state.session_factory,at=AT)
    headers={'Authorization':'Bearer '+'a'*40}
    url=f'/v1/admin/race-statistics?since={AT-3600}&until={AT+1}&track_version_id={version}'
    assert client.get(url).status_code==401
    report=client.get(url,headers=headers).json()
    assert report['totals']['races']==2 and report['totals']['position_samples']==60
    assert report['frame_buckets'][2]==180 and len(report['options'])==2
    assert report['track']['preview']['available'] and report['cells'][0]['samples']==40
    unscoped=client.get(f'/v1/admin/race-statistics?since={AT-3600}&until={AT+1}',headers=headers).json()
    assert unscoped['totals']['races']==2 and not unscoped['cells'] and not unscoped['segments']
    scoped=client.get(url+'&device_model=Phone%20N&os_version=Android%2014',headers=headers).json()
    assert scoped['totals']['races']==1 and scoped['filters']['os_version']=='Android 14'
    assert client.get(url+'&os_version=Android%2013',headers=headers).json()['totals']=={}
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(RaceStatisticsReceipt))==2
        assert session.scalar(select(func.count()).select_from(RaceStatisticsDay))==2


@pytest.mark.parametrize('change',[
    {'frame_buckets':[True,0,0,0,0,0,0,0]}, {'frame_buckets':[1000001,0,0,0,0,0,0,0]},
    {'device_model':'private\nidentifier'}, {'os_version':'X'*81}, {'elapsed_ms':3600001},
    {'cells':[[0,0,1,2]],'segments':[[0,1,0]],'position_samples':1},
    {'cells':[[0,0,1,0],[0,0,1,0]],'segments':[[0,2,0]],'position_samples':2},
    {'cells':[[0,0,1,0]],'segments':[[32,1,0]],'position_samples':1},
    {'input_capture':[1,2,3]}, {'paint_dirt':1},
])
def test_race_package_rejects_unbounded_and_private_payloads(product,change):
    version,_draft=seed(product)
    assert send(product,[event(package(version,**change))]).json()['events'][0]['status']=='rejected'


def test_local_draft_spatial_data_rejected_but_generic_local_frame_summary_allowed(product):
    app,_client,_auth,_player=product;_version,draft=seed(product)
    assert send(product,[event(package(draft))]).json()['events'][0]['reason']=='PUBLISHED_TRACK_REQUIRED'
    assert send(product,[event(package())]).json()['events'][0]['status']=='accepted'
    bad=package(cells=[[0,0,1,0]],segments=[[0,1,0]],position_samples=1)
    assert send(product,[event(bad)]).json()['events'][0]['status']=='rejected'
    project_pending(app.state.session_factory,at=AT)
    with app.state.session_factory() as session:
        fact=session.scalar(select(RaceStatisticsDay));assert fact.track_version_id=='' and not fact.cells


def test_batched_race_identity_mismatch_has_no_receipt_or_fact(product):
    app,_client,_auth,_player=product;version,_draft=seed(product)
    value=package(version);observation=event(value);observation['id']=str(uuid4())
    assert send(product,[observation]).json()['events'][0]['reason']=='RACE_ID_MISMATCH'
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(RaceStatisticsReceipt))==0


def test_race_ticket_must_belong_to_actor_and_published_version(product):
    app,_client,_auth,player=product;version,_draft=seed(product)
    with app.state.session_factory() as session:
        board=Board(id='d'*64,version_id=version,vehicle_id='compact',manifest={})
        session.add(board);session.flush()
        ticket=RunTicket(player_id=player,board_id=board.id,expires_at=AT+3600)
        session.add(ticket);session.commit();ticket_id=ticket.id
    assert send(product,[event(package(version,ticket_id=ticket_id))]).json()['events'][0]['status']=='accepted'
    for value in (package(version,ticket_id=str(uuid4())), package(ticket_id=ticket_id)):
        assert send(product,[event(value)]).json()['events'][0]['reason']=='RACE_TICKET_MISMATCH'
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(RaceStatisticsReceipt))==1


def test_wide_device_scope_merge_is_bounded_and_preserves_selected_counts():
    # A wide filter can span many prepared rows; never build an unbounded cell union.
    first={f'{i}:0':[2,1] for i in range(AGGREGATE_CELLS)}
    second={f'{i}:0':[3,2] for i in range(AGGREGATE_CELLS//2,AGGREGATE_CELLS*2)}
    cells,heap={},[]
    omitted=merge_cells(cells,heap,first)+merge_cells(cells,heap,second)
    assert len(cells)==len(heap)==AGGREGATE_CELLS
    assert sum(pair[0] for pair in cells.values())+omitted==sum(pair[0] for pair in first.values())+sum(pair[0] for pair in second.values())
    for identity,pair in cells.items():
        assert pair==[first.get(identity,[0,0])[n]+second.get(identity,[0,0])[n] for n in range(2)]
    reverse,reverse_heap={},[]
    merge_cells(reverse,reverse_heap,second);merge_cells(reverse,reverse_heap,first)
    assert reverse==cells


def render_setup(**changes):
    return {"schema_version": 1, "renderer": "gl_compatibility", "car_detail": "full",
        "viewport_width": 1280, "viewport_height": 720, "scale_percent": 100,
        "frame_limit": 0, "vsync": "enabled", "refresh_hz": 60, **changes}


def test_render_context_ingest_dedupe_projection_and_scoped_reports(product):
    app, client, _auth, _player = product
    version, _draft = seed(product)
    first = package(version, schema_version=3, render_context=render_setup(), render_context_changed=False)
    for value in (first, package(version, schema_version=3,
            render_context=render_setup(renderer="mobile", car_detail="simple", viewport_width=1920,
                viewport_height=1080, scale_percent=75, frame_limit=60), render_context_changed=True), package(version)):
        assert send(product, [event(value)]).json()["events"][0]["status"] == "accepted"
    assert send(product, [event(first)]).json()["events"][0]["status"] == "duplicate"
    changed = {**first, "render_context": render_setup(frame_limit=120)}
    assert send(product, [event(changed)]).json()["events"][0]["reason"] == "ID_CONFLICT"
    project_pending(app.state.session_factory, at=AT)
    headers = {"Authorization": "Bearer " + "a" * 40}
    url = f"/v1/admin/race-statistics?since={AT-3600}&until={AT+1}&track_version_id={version}"
    result = client.get(url, headers=headers).json()
    assert result["totals"]["races"] == 3 and len(result["render_options"]) == 2
    assert result["render_context_coverage"] == {"known_races": 2, "unknown_races": 1, "changed_races": 1}
    assert result["collection"]["accepted_client_schemas"] == [2, 3]
    key = next(row["key"] for row in result["render_options"] if row["context"]["renderer"] == "mobile")
    for query in ("renderer=mobile", "car_detail=simple", "render_context_key=" + key, "context_state=changed"):
        filtered = client.get(url + "&" + query, headers=headers).json()
        assert filtered["totals"]["races"] == 1 and filtered["frame_buckets"][2] == 90
    legacy = client.get(url + "&context_state=unknown", headers=headers).json()
    assert legacy["totals"]["races"] == 1 and legacy["render_context_coverage"]["known_races"] == 0
    for query in ("renderer=private-driver", "car_detail=custom", "context_state=other", "render_context_key=nope"):
        assert client.get(url + "&" + query, headers=headers).status_code == 422
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(RaceStatisticsDay)) == 3


@pytest.mark.parametrize("changes", [
    {"schema_version": True}, {"renderer": "unbounded-device-name"}, {"car_detail": "custom"},
    {"viewport_width": 16385}, {"viewport_height": -1}, {"scale_percent": 0},
    {"frame_limit": True}, {"refresh_hz": 1001}, {"vsync": "auto"}, {"hardware_serial": "private"},
])
def test_render_context_rejects_invalid_dimensions_and_private_fields(product, changes):
    seed(product)
    value = package(schema_version=3, render_context=render_setup(**changes), render_context_changed=False)
    assert send(product, [event(value)]).json()["events"][0]["status"] == "rejected"


def test_render_schema_is_explicit_and_legacy_cannot_claim_context(product):
    seed(product)
    values = (package(schema_version=3), package(schema_version=3, render_context=render_setup(), render_context_changed=1),
        package(render_context=render_setup(), render_context_changed=False), package(schema_version=4))
    for value in values:
        assert send(product, [event(value)]).json()["events"][0]["status"] == "rejected"


def test_render_context_migration_preserves_historical_unknowns(tmp_path):
    from alembic import command
    from sqlalchemy import create_engine, text

    from bmt_backend.migrate import configuration, upgrade

    engine = create_engine("sqlite:///" + str(tmp_path / "migration.sqlite"))
    try:
        command.upgrade(configuration(engine), "0030_studio_catalogue")
        with engine.begin() as connection:
            connection.execute(text("""INSERT INTO race_statistics_days
                (day,dimension,track_version_id,build_id,platform,device_class,device_model,os_version,outcome,
                races,elapsed_ms,latest_received_at,position_samples,dropped_samples,aggregate_dropped_samples,
                frame_buckets,cells,segments) VALUES
                (1,'legacy','','old','android','android_arm64','Old phone','Old OS','finished',
                7,7000,1,0,0,0,'[0,0,7,0,0,0,0,0]','{}','{}')"""))
        upgrade(engine)
        upgrade(engine)
        with engine.connect() as connection:
            row = connection.execute(text("SELECT races,frame_buckets,render_context_key,render_context,render_context_changed FROM race_statistics_days")).one()
            assert row.races == 7 and row.frame_buckets == "[0,0,7,0,0,0,0,0]"
            assert row.render_context_key is row.render_context is row.render_context_changed is None
    finally:
        engine.dispose()


def test_operator_queue_counts_explicit_publication_work_and_oldest_age(product, monkeypatch):
    app,client,_auth,player=product
    monkeypatch.setattr('bmt_backend.operations.now',lambda:AT)
    with app.state.session_factory() as session:
        for offset,state in ((150,'queued'),(250,'verifying'),(300,'failed')):
            session.add(PublicationIntent(player_id=player,operation_key='owned-queue-fixture-'+str(offset),
                request_hash='a'*64,authoring_id='local-fixture',name='Explicit publication fixture',
                content_hash='b'*64,replay_hash='c'*64,vehicle_id='compact',contract={},status=state,
                created_at=AT-offset))
        session.commit()
    headers={'Authorization':'Bearer '+'a'*40}
    health=client.get('/v1/admin/competition-health',headers=headers).json()
    assert health['queue_depth']==health['pending_publications']==2 and health['pending_races']==0
    assert health['oldest_age_seconds']==250 and health['estimated_wait_seconds'] is None
    overview=client.get('/v1/admin/overview',headers=headers).json()
    assert overview['publications']=={'pending':2,'failed':1,'failed_count_capped':False}
