"""Report provenance, exact navigation contracts and bounded ranking operations."""
# Imported pytest fixtures intentionally share their parameter names.
# ruff: noqa: F811

import csv
import io
import json
from uuid import uuid4

import pytest
from sqlalchemy import event, func, select
from test_studio import evidence  # noqa: F401
from test_studio_platform import ANALYST, OWNER, platform  # noqa: F401
from test_studio_reporting import reports  # noqa: F401

from bmt_backend.admin_models import AdminAudit
from bmt_backend.race_statistics_models import RaceStatisticsDay
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisState
from bmt_backend.studio_ranking import record_worker_heartbeat
from bmt_backend.studio_watchdog import queue_signals
from bmt_backend.track_models import Run, now
from bmt_backend.world_ranking_models import (
    Circuit,
    RankingBranch,
    RankingControl,
    RankingCorrection,
    RankingPlayer,
    RankingSnapshot,
)


@pytest.mark.parametrize('view', ['dimensions', 'activity', 'retention', 'journey', 'engagement'])
def test_export_uses_only_guarded_reporting_storage_and_carries_its_scope(reports, view):
    app, client, _engine = reports
    primary = []
    event.listen(app.state.engine, 'before_cursor_execute', lambda _c, _u, statement, *_: primary.append(statement))
    response = client.get('/v1/admin/exports/activity.csv', params={'view': view}, headers=OWNER)
    assert response.status_code == 200, response.text
    rows = list(csv.DictReader(io.StringIO(response.text)))
    assert rows and rows[0]['query_semantics'] == 'new_query_at_download'
    assert rows[0]['report'] == view and rows[0]['timezone'] == 'UTC'
    assert 'processed_through' in rows[0] and json.loads(rows[0]['scope'])['population'] == 'all'
    assert not any('studio_analysis' in q or 'race_statistics_days' in q for q in primary)
    if view in ('activity', 'dimensions'):
        assert sum(int(r.get('starts') or r.get('race_starts') or 0) for r in rows) == 3
    with app.state.studio_reporting.snapshot(app.state.session_factory):
        assert client.get('/v1/admin/exports/activity.csv', params={'view': view}, headers=OWNER).status_code == 503


def test_unconfigured_exports_fail_closed_without_primary_fact_reads(auth_app, auth_client):
    from dataclasses import replace
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key='o'*40)
    for path in ('exports/activity.csv', 'exports/releases.csv', 'analysis/releases'):
        response = auth_client.get('/v1/admin/'+path, headers=OWNER)
        assert response.status_code == 503 and 'BMT_STUDIO_ANALYSIS_DATABASE_URL' in response.json()['detail']


@pytest.mark.parametrize('route,filters', [
    ('players/'+str(uuid4()), {'all': '1'}), ('races/'+str(uuid4()), {'time_field': 'finished_at'}),
    ('system/jobs', {'kind': 'ranking', 'state': 'failed'}),
    ('cases', {'status': 'appealed'}), ('quality', {'device_model': 'Test device', 'os_version': '14'}),
    ('studio', {'tab': 'config', 'view': 'draft', 'draft': str(uuid4())}),
])
def test_saved_location_round_trip_rename_delete_and_actor_fences(platform, route, filters):
    _app, client, _player, _auth = platform
    body = {'command_id': str(uuid4()), 'id': str(uuid4()), 'expected_revision': 0,
            'name': 'Exact investigation', 'route': route, 'filters': filters}
    saved = client.post('/v1/admin/saved-views', headers=OWNER, json=body)
    assert saved.status_code == 200, saved.text
    assert saved.json()['route'] == route and saved.json()['filters'] == filters
    assert client.get('/v1/admin/saved-views', headers=OWNER).json()['items'][0]['route'] == route
    rename = {**body, 'command_id': str(uuid4()), 'expected_revision': 1, 'name': 'Renamed'}
    assert client.post('/v1/admin/saved-views', headers=OWNER, json=rename).json()['revision'] == 2
    deletion = {'command_id': str(uuid4()), 'expected_revision': 2}
    endpoint = '/v1/admin/saved-views/'+body['id']+'/delete'
    assert client.post(endpoint, headers=ANALYST, json=deletion).status_code == 404
    assert client.post(endpoint, headers=OWNER, json={**deletion, 'expected_revision': 1}).status_code == 409
    for _ in range(2):
        assert client.post(endpoint, headers=OWNER, json=deletion).json()['deleted']
    assert not client.get('/v1/admin/saved-views', headers=OWNER).json()['items']


@pytest.mark.parametrize('route', ['https://example.org', '../system', 'players/../system', 'system/unknown'])
def test_saved_location_rejects_unsupported_paths(platform, route):
    _app, client, _player, _auth = platform
    response = client.post('/v1/admin/saved-views', headers=OWNER, json={
        'command_id': str(uuid4()), 'id': str(uuid4()), 'expected_revision': 0,
        'name': 'Unsafe location', 'route': route, 'filters': {}})
    assert response.status_code == 422


def test_calendar_gap_coverage_never_invents_precollection_zero(platform):
    app, client, player, _auth = platform
    at = now()
    day = at//86400
    with app.state.session_factory() as db:
        state = db.get(AnalysisState, 1)
        state.started_at, state.processed_through, state.latest_client_at = (day-2)*86400, at, at
        db.add(AnalysisDay(day=day, player_id=player, dimension='gap-fixture', build_id='fixture',
                           counters={'active': 1}, first_at=at, last_at=at))
        db.commit()
    data = client.get('/v1/admin/analysis/behaviour', headers=OWNER,
                      params={'since': (day-3)*86400, 'until': at+1}).json()
    by_day = {r['day']: r for r in data['daily']}
    assert by_day[day-3]['coverage_state'] == 'unobserved' and by_day[day-3]['players'] is None
    assert by_day[day-1]['coverage_state'] == 'observed' and by_day[day-1]['players'] == 0
    assert by_day[day]['coverage_state'] == 'partial' and by_day[day]['players'] == 1
    with app.state.session_factory() as db:
        db.get(AnalysisState, 1).latest_client_at = None
        db.commit()
    unknown = client.get('/v1/admin/analysis/behaviour', headers=OWNER).json()
    assert not unknown['coverage']['available']
    assert all(row['coverage_state'] == 'unobserved' for row in unknown['daily'])


def test_terminal_time_drilldown_reconciles_late_verification(evidence):
    client, app, ids = evidence
    at = now()
    with app.state.session_factory() as db:
        run = db.get(Run, ids['run'])
        run.created_at, run.finished_at = at-3600, at-1
        db.commit()
    scope = {'state': 'verified', 'since': at-300, 'until': at+1}
    pulse = client.get('/v1/admin/overview', headers=OWNER).json()
    assert pulse['states']['verified'] == 1
    assert not client.get('/v1/admin/entities/races', headers=OWNER, params=scope).json()['items']
    rows = client.get('/v1/admin/entities/races', headers=OWNER, params={**scope, 'time_field':'finished_at'}).json()['items']
    assert len(rows) == 1 and rows[0]['id'] == ids['run']


def test_release_comparison_and_export_are_isolated_and_coverage_is_honest(reports):
    from sqlalchemy.orm import Session
    app, client, engine = reports
    at = now()
    with Session(engine) as db:
        for build, slow in [('a', 100), ('b', 500)]:
            db.add(RaceStatisticsDay(day=at//86400, dimension=build, track_version_id='track-one',
                build_id=build, platform='android', device_class='phone', device_model='Phone A', os_version='14',
                outcome='finished', races=40, frame_buckets=[10000-slow,0,0,0,0,slow,0,0], latest_received_at=at))
        db.commit()
    queries = []
    event.listen(app.state.engine, 'before_cursor_execute', lambda _c, _u, statement, *_: queries.append(statement))
    params = {'build_id':'a', 'baseline':'b', 'device_model':'Phone A', 'os_version':'14', 'track_version_id':'track-one'}
    response = client.get('/v1/admin/analysis/releases', headers=OWNER, params=params)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data['candidate']['reporting_players'] is None
    assert data['candidate']['sample_sufficient'] and data['comparison']['slow_frame_change'] == pytest.approx(-.04)
    segment = data['segments'][0]
    assert segment['frames'] == 10000 and segment['baseline_frames'] == 10000 and segment['slow_change'] == pytest.approx(-.04)
    exported = client.get('/v1/admin/exports/releases.csv', headers=OWNER, params=params)
    assert exported.status_code == 200
    rows = list(csv.DictReader(io.StringIO(exported.text)))
    assert int(rows[0]['frames']) == data['candidate']['frames'] and rows[0]['reporting_players'] == ''
    assert not any('race_statistics_days' in q or 'studio_analysis' in q for q in queries)
    missing = client.get('/v1/admin/analysis/releases', headers=OWNER, params={**params,'baseline':'missing'}).json()
    assert missing['baseline']['reporting_players'] is None and not missing['baseline']['sample_sufficient']


def seed_ranking(app, player):
    at = now()
    week = (at//604800)*604800-2*604800
    with app.state.session_factory() as db:
        circuit = Circuit(week_start=week, contract_key='x'*64, policy='test', tracks=[])
        branch = RankingBranch(next_week=at, mode='active')
        db.add_all([circuit, branch])
        db.flush()
        snapshot = RankingSnapshot(branch_id=branch.id, circuit_id=circuit.id, week_start=week,
                                   state='published', published_at=at, field_size=100, ranked_count=80)
        db.add(snapshot)
        db.flush()
        circuit.original_snapshot = snapshot.id
        db.add(RankingControl(id=1, launch_week=week, published_id=snapshot.id, running_branch=branch.id))
        db.add(RankingPlayer(player_id=player))
        db.commit()
        return circuit.id, snapshot.id


def test_ranking_inspection_preview_and_queue_monitoring_do_not_settle(platform):
    app, client, player, _auth = platform
    circuit, snapshot = seed_ranking(app, player)
    record_worker_heartbeat(app.state.session_factory)
    with app.state.session_factory() as db:
        original_audits = db.scalar(select(func.count()).select_from(AdminAudit))
    data = client.get('/v1/admin/studio/ranking', headers=ANALYST).json()
    assert data['published_snapshot'] == snapshot and data['worker_last_seen_at'] and not data['pending']
    body = {'command_id': str(uuid4()), 'expected_snapshot':snapshot, 'circuit_id':circuit,
            'player_id':player, 'void_week':False, 'reason':'Owned test exclusion'}
    assert client.post('/v1/admin/studio/ranking/correction-preview', headers=ANALYST, json=body).status_code == 403
    response = client.post('/v1/admin/studio/ranking/correction-preview', headers=OWNER, json=body)
    assert response.status_code == 200, response.text
    assert response.json()['kind'] == 'exclude_player'
    assert client.post('/v1/admin/studio/ranking/correction-preview', headers=OWNER,
                       json={**body, 'expected_snapshot':snapshot+1}).status_code == 409
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(RankingCorrection)) == 0
        assert db.scalar(select(func.count()).select_from(AdminAudit)) == original_audits
    jobs = client.get('/v1/admin/jobs', headers=OWNER).json()
    assert {'ranking','achievement_competition','achievement_rarity','achievement_record','creator_achievement'} <= {r['kind'] for r in jobs['summary']}
    jobs['ranking'].update(pending=True, worker_last_seen_at=now()-200, progress_at=now()-200)
    signals = {s.key:s.active for s in queue_signals(jobs,at=now())}
    assert signals['ranking_worker'] is True and signals['pipeline_achievement_rarity'] is False


def test_correction_history_retains_named_audit_actor_and_replay_fence(platform):
    from bmt_backend.admin import access
    from bmt_backend.studio_access import StaffRole
    app, client, player, _auth = platform
    circuit, snapshot = seed_ranking(app, player)
    app.dependency_overrides[access] = lambda: StaffRole('owner','staff-fixture','Fixture staff')
    body = {'command_id': str(uuid4()), 'expected_snapshot':snapshot, 'circuit_id':circuit,
            'player_id':player, 'void_week':False, 'reason':'Owned correction lifecycle'}
    first = client.post('/v1/admin/ranking/corrections', headers=OWNER, json=body)
    assert first.status_code == 200, first.text
    assert client.post('/v1/admin/ranking/corrections', headers=OWNER, json=body).json() == first.json()
    data = client.get('/v1/admin/studio/ranking', headers=OWNER).json()
    assert data['mode'] == 'rebuild' and data['oldest_at'] is None
    assert data['history'][0]['actor'] == 'staff-fixture' and data['history'][0]['player_id'] == player
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(RankingCorrection)) == 1


def test_new_queue_counts_are_bounded_and_rarity_age_is_unknown(platform):
    from bmt_backend.achievement_models import AchievementState
    app, client, _player, _auth = platform
    with app.state.session_factory() as db:
        db.execute(AchievementState.__table__.insert(), [
            {'player_id': f'pending-{i:05}', 'scope':'all', 'rarity_pending':True} for i in range(10001)])
        db.commit()
    data = client.get('/v1/admin/jobs', headers=OWNER).json()
    rarity = next(r for r in data['summary'] if r['kind'] == 'achievement_rarity')
    assert rarity['pending'] == 10000 and rarity['pending_capped'] and not rarity['failed_capped']
    assert rarity['oldest_at'] is None and not rarity['age_known']
    signals = {s.key:s.active for s in queue_signals(data,at=now())}
    assert signals['pipeline_achievement_rarity'] is None
