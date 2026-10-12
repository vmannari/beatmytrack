"""Case concurrency/auth and competition inspection use real sources, never proof replay."""
# ruff: noqa: F811
from uuid import uuid4

from sqlalchemy import func, select
from test_studio import evidence, headers  # noqa: F401

from bmt_backend.challenge_models import Challenge, ChallengeMember
from bmt_backend.studio_case_models import StudioCaseEvent


def test_case_auth_retry_revision_workflow_and_credentials(evidence, auth_client, auth_app):
    client, _app, ids = evidence
    created = {"command_id": str(uuid4()), "title": "Race upload issue", "player_id": ids["player"]}
    assert client.post('/v1/admin/cases', json=created).status_code == 401
    assert client.post('/v1/admin/cases', headers=headers(), json=created).status_code == 403
    response = client.post('/v1/admin/cases', headers=headers('owner'), json=created)
    assert response.status_code == 200, response.text
    case = response.json()
    assert client.post('/v1/admin/cases', headers=headers('owner'), json=created).json()['id'] == case['id']
    endpoint = '/v1/admin/cases/' + case['id'] + '/events'
    event = {"command_id": str(uuid4()), "expected_revision": 0, "kind": "note", "text": "Stored result is pending"}
    assert client.post(endpoint, headers=headers(), json=event).status_code == 403
    assert client.post(endpoint, headers=headers('owner'), json=event).json()['revision'] == 1
    assert client.post(endpoint, headers=headers('owner'), json=event).json()['revision'] == 1
    assert client.post(endpoint, headers=headers('owner'), json={**event, 'command_id': str(uuid4())}).status_code == 409
    assert client.post(endpoint, headers=headers('owner'), json={**event, 'expected_revision': 1,
        'command_id': str(uuid4()), 'text': 'Bearer SECRET'}).status_code == 422
    transition = {"command_id": str(uuid4()), "expected_revision": 1, "kind": "transition", "text": "Checked pinned source", "status": "resolved"}
    assert client.post(endpoint, headers=headers('owner'), json=transition).json()['status'] == 'resolved'
    transition.update(command_id=str(uuid4()), expected_revision=2, status='appealed', text='New evidence supplied')
    assert client.post(endpoint, headers=headers('owner'), json=transition).json()['status'] == 'appealed'
    report = client.get('/v1/admin/cases/' + case['id'], headers=headers()).json()
    assert len(report['events']) == 4 and report['coverage']['production_compensation'] == 'unavailable'
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(StudioCaseEvent)) == 4


def test_challenge_exact_target_best_and_bad_source_remain_distinct(evidence):
    client, app, ids = evidence
    from bmt_backend.track_models import Run
    with app.state.session_factory() as session:
        run = session.get(Run, ids['run'])
        challenge = Challenge(code='AUDIT001', creator_id=ids['player'], board_id=run.board_id,
            mode='duel', target_run_id=run.id, target_ticks=run.time_ticks, ends_at=2000001000)
        session.add(challenge); session.flush()
        session.add(ChallengeMember(challenge_id=challenge.id, player_id=ids['player'], run_id=run.id, time_ticks=run.time_ticks))
        session.commit(); identity = challenge.id
    endpoint = '/v1/admin/competitions/challenge/' + identity
    assert client.get(endpoint).status_code == 401
    report = client.get(endpoint, headers=headers()).json()
    assert report['results'][0]['rank'] == 1
    assert report['results'][0]['seconds'] == 100
    assert report['target']['problems'] == []
    assert report['results'][0]['evidence_route'].endswith(ids['run'])
    with app.state.session_factory() as session:
        session.get(Run, ids['run']).status = 'queued'; session.commit()
    report = client.get(endpoint, headers=headers()).json()
    assert report['results'][0]['rank'] is None
    assert report['results'][0]['rank_from_stored_bests'] == 1
    assert 'SOURCE_NOT_VERIFIED' in report['results'][0]['problems']
    assert report['target']['problems'] == ['SOURCE_NOT_VERIFIED']


def test_inspection_never_reads_objects_or_runs_verification(evidence):
    client, _app, _ids = evidence
    # Existing evidence fixture raises on any blob/verifier read.
    assert client.get('/v1/admin/competitions?kind=rivalry', headers=headers()).status_code == 200
    assert client.get('/v1/admin/competitions?kind=challenge', headers=headers()).status_code == 200
    assert client.get('/v1/admin/competitions?kind=unknown', headers=headers()).status_code == 422
    assert client.get('/v1/admin/cases', headers=headers()).status_code == 200
