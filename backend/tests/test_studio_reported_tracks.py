"""Report aggregation and owner-only deletion preserve evidence and old results."""
from uuid import uuid4

import pytest
from sqlalchemy import func, select
from test_studio import evidence as _evidence
from test_studio import headers

from bmt_backend.admin_models import AdminAudit
from bmt_backend.studio_case_models import StudioCase, StudioCaseEvent
from bmt_backend.track_models import PersonalBest, Run, Track, TrackVersion

evidence = _evidence


@pytest.fixture
def reported(evidence):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        track_id = session.get(TrackVersion, ids['version']).track_id
        cases = []
        for index, state in enumerate(['open', 'resolved', 'appealed']):
            case = StudioCase(track_id=track_id, player_id=ids['other'] if index == 2 else ids['player'],
                              title='Track report', status=state)
            session.add(case)
            session.flush()
            session.add(StudioCaseEvent(id=str(uuid4()), case_id=case.id, actor='player', kind='reported',
                request_hash='a'*64, detail={'reason': 'harassment', 'text': '<script>Unsafe track</script>',
                                             'version_id': ids['version']}, created_at=100+index))
            cases.append(case.id)
        staff = StudioCase(track_id=track_id, title='Staff case, not a report')
        session.add(staff)
        session.flush()
        session.add(StudioCaseEvent(id=str(uuid4()), case_id=staff.id, actor='owner', kind='created',
                                    request_hash='b'*64, detail={'text': 'Staff only'}))
        session.add(StudioCaseEvent(id=str(uuid4()), case_id=cases[0], actor='owner', kind='note', revision=1,
                                    request_hash='c'*64, detail={'text': 'Private staff-only analysis'}))
        session.commit()
        ids.update(track=track_id, reports=cases, staff=staff.id)
    return client, app, ids


def deletion(client, ids, credentials=None):
    data = client.get('/v1/admin/reported-tracks/'+ids['track'], headers=credentials or headers()).json()
    report = data['items'][0]
    return {'command_id': str(uuid4()), 'case_id': report['case_id'], 'expected_revision': report['revision'],
            'expected_state': data['track']['state_token'], 'reason': 'Reviewed player reports; remove this track.',
            'acknowledged': True}


def test_grouped_counts_and_report_details_are_private_and_not_note_counts(reported):
    client, _, ids = reported
    url = '/v1/admin/reported-tracks'
    assert client.get(url).status_code == 401
    for role in ('analyst', 'owner'):
        response = client.get(url, headers=headers(role))
        assert response.status_code == 200, response.text
        assert response.headers['cache-control'] == 'no-store'
        row, = response.json()['items']
        assert row['track_id'] == ids['track']
        assert (row['report_count'], row['reporters'], row['unresolved']) == (3, 2, 2)
        assert row['name'] == 'Newer version'
    data = client.get(url+'/'+ids['track']+'?limit=2', headers=headers()).json()
    assert len(data['items']) == 2 and data['has_more']
    assert data['track']['report_count'] == 3
    assert len(client.get(url+'/'+ids['track']+'?limit=2&offset=2', headers=headers()).json()['items']) == 1
    assert 'Private staff-only analysis' not in str(data)
    assert 'private-provider-subject' not in str(data)
    assert client.get(url+'?q=unmatched', headers=headers()).json()['items'] == []
    assert client.get(url+'?visibility=deleted', headers=headers()).json()['items'] == []


def test_delete_is_confirmed_idempotent_and_retains_results(reported):
    client, app, ids = reported
    url = '/v1/admin/reported-tracks/'+ids['track']+'/delete'
    body = deletion(client, ids)
    for auth in ({}, headers()):
        assert client.post(url, json=body, headers=auth).status_code in (401, 403)
    for change in ({'acknowledged': False}, {'reason': 'short'}):
        assert client.post(url, json={**body, **change}, headers=headers('owner')).status_code == 422
    with app.state.session_factory() as session:
        before = {model.__tablename__: session.scalar(select(func.count()).select_from(model))
                  for model in (TrackVersion, Run, PersonalBest)}
    result = client.post(url, json=body, headers=headers('owner'))
    assert result.status_code == 200, result.text
    assert client.post(url, json=body, headers=headers('owner')).json() == result.json()
    assert client.post(url, json={**body, 'reason': 'Different reason with the same command'},
                       headers=headers('owner')).status_code == 409
    assert client.get('/v1/track-versions/'+ids['version']).status_code == 404
    assert client.get('/v1/track-versions/'+ids['version']+'/document').status_code == 404
    assert client.get('/v1/admin/reported-tracks', headers=headers()).json()['items'] == []
    deleted = client.get('/v1/admin/reported-tracks?visibility=deleted', headers=headers()).json()['items']
    assert len(deleted) == 1 and deleted[0]['report_count'] == 3
    with app.state.session_factory() as session:
        assert session.get(Track, ids['track']).archived and session.get(Track, ids['track']).hidden
        assert {model.__tablename__: session.scalar(select(func.count()).select_from(model))
                for model in (TrackVersion, Run, PersonalBest)} == before
        assert session.scalar(select(func.count()).select_from(AdminAudit)) == 1
        audit = session.scalar(select(AdminAudit))
        assert audit.action == 'track_deletion' and audit.after['case_id'] == body['case_id']
    show = {'command_id': str(uuid4()), 'action': 'track_visibility', 'entity_id': ids['track'],
            'expected': True, 'value': False, 'reason': 'Attempt to reverse a deleted track', 'acknowledged': True}
    assert client.post('/v1/admin/commands', json=show, headers=headers('owner')).status_code == 409
    restore = {'command_id': str(uuid4()), 'expected_revision': 1, 'kind': 'restore', 'text': 'Attempt case restore'}
    assert client.post('/v1/admin/cases/'+body['case_id']+'/events', json=restore,
                       headers=headers('owner')).status_code == 409


@pytest.mark.parametrize('change', ['visibility', 'version', 'case'])
def test_delete_rejects_stale_review(reported, change):
    client, app, ids = reported
    body = deletion(client, ids)
    with app.state.session_factory() as session:
        if change == 'visibility':
            session.get(Track, ids['track']).hidden = True
        elif change == 'version':
            session.add(TrackVersion(track_id=ids['track'], number=3, name='Changed content',
                                    content_hash='d'*64, manifest={}, state='published'))
        else:
            session.get(StudioCase, body['case_id']).revision += 1
        session.commit()
    result = client.post('/v1/admin/reported-tracks/'+ids['track']+'/delete', json=body, headers=headers('owner'))
    assert result.status_code == 409, result.text
    with app.state.session_factory() as session:
        assert not session.get(Track, ids['track']).archived


def test_staff_case_cannot_substitute_for_a_player_report(reported):
    client, _, ids = reported
    body = {**deletion(client, ids), 'case_id': ids['staff']}
    assert client.post('/v1/admin/reported-tracks/'+ids['track']+'/delete', json=body,
                       headers=headers('owner')).status_code == 404


def test_old_archive_keeps_links_until_explicit_deletion(reported):
    client, app, ids = reported
    with app.state.session_factory() as session:
        session.get(Track, ids['track']).archived = True
        session.commit()
    assert client.get('/v1/track-versions/'+ids['version']).status_code == 200
    active = client.get('/v1/admin/reported-tracks', headers=headers()).json()['items']
    assert len(active) == 1 and not active[0]['deleted']
    result = client.post('/v1/admin/reported-tracks/'+ids['track']+'/delete',
                         json=deletion(client, ids), headers=headers('owner'))
    assert result.status_code == 200, result.text
    assert client.get('/v1/track-versions/'+ids['version']).status_code == 404


@pytest.fixture
def restricted_database(request):
    # Reuse the explicitly disposable PostgreSQL authority fixture only for
    # this test; ordinary local report tests use isolated SQLite databases.
    from test_cloud_setup import database
    yield from database.__wrapped__()


@pytest.mark.postgres
def test_restricted_admin_can_list_and_delete_reported_track(restricted_database, tmp_path):
    from fastapi.testclient import TestClient
    from sqlalchemy import event
    from sqlalchemy.engine import make_url
    from sqlalchemy.orm import Session
    from test_domains import FakeVerifier

    from bmt_backend import cloud_setup
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.database_privileges import verify_runtime
    from bmt_backend.db import make_engine
    from bmt_backend.identity_models import Player

    engine, schema, roles, url = restricted_database
    cloud_setup.setup(engine, uuid4().hex, roles, schema)
    peer = make_engine(make_url(url).set(username=roles['admin'], password='isolated-security-test-role')
                       .render_as_string(hide_password=False), schema=schema)
    failures = []
    @event.listens_for(peer, 'handle_error')
    def diagnose(context):
        detail = getattr(context.original_exception, 'diag', None)
        failures.append(getattr(detail, 'message_primary', 'Database operation failed'))
    try:
        verify_runtime(peer, Settings(workload_role='admin'))
        with Session(engine) as session:
            player = Player(display_name='Restricted admin fixture')
            session.add(player)
            session.flush()
            track = Track(owner_id=player.id)
            session.add(track)
            session.flush()
            session.add(TrackVersion(track_id=track.id, number=1, name='Restricted fixture track',
                                    content_hash='f'*64, manifest={}, state='published'))
            report = StudioCase(track_id=track.id, player_id=player.id, title='Track report')
            session.add(report)
            session.flush()
            session.add(StudioCaseEvent(id=str(uuid4()), case_id=report.id, actor='player', kind='reported',
                                       detail={'reason': 'track_issue', 'text': 'Please review this track'}, request_hash='e'*64))
            session.commit()
            identity = track.id
        app = create_app(Settings(workload_role='admin', studio_staff_audiences=('staff',),
            studio_staff_subjects='{"known":{"name":"Owner","role":"owner"}}',
            object_dir=str(tmp_path)), engine=peer, verifier=FakeVerifier())
        class StaffVerifier:
            def verify(self, token):
                assert token == 'staff'
                return {'sub': 'known', 'amr': ['mfa']}
        app.state.staff_identity_verifier = StaffVerifier()
        credentials = {'Authorization': 'Bearer staff'}
        with TestClient(app) as client:
            response = client.get('/v1/admin/reported-tracks', headers=credentials)
            assert response.status_code == 200, (response.text, failures)
            assert response.json()['items'][0]['report_count'] == 1
            body = deletion(client, {'track': identity}, credentials)
            response = client.post('/v1/admin/reported-tracks/'+identity+'/delete', json=body, headers=credentials)
            assert response.status_code == 200, response.text
            assert client.post('/v1/admin/reported-tracks/'+identity+'/delete', json=body,
                               headers=credentials).json() == response.json()
        with Session(engine) as session:
            assert session.get(Track, identity).archived
            assert session.scalar(select(func.count()).select_from(TrackVersion)) == 1
    finally:
        peer.dispose()
