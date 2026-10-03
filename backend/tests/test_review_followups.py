"""Failure regressions for review passes two and three; disposable databases only."""
import os
from dataclasses import replace

import pytest
from sqlalchemy import event, select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course
from test_track_lifecycle import save

from bmt_backend.contracts import build_contract
from bmt_backend.maintenance import retain
from bmt_backend.middleware import parse_body
from bmt_backend.operations import competition_health, heartbeat
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import TrackValidation, TrackVersion, now
from bmt_backend.track_validation import process_one
from bmt_backend.verifier import MAX_FRAMES, MAX_REQUEST_BYTES, _json_bytes, validate_replay

domain = domain_fixture


def test_rejected_revision_never_publishes_a_blob(domain):
    domain.app.state.settings = replace(domain.app.state.settings, max_queued_runs=1)
    first, body = save(domain)
    blobs = domain.app.state.blobs
    before = set(blobs.root.glob('*/*.json'))
    for changes, code in [({'authoring_id': 'mismatch'}, 422),
                          ({'expected_head_revision_id': 'new'}, 409), ({}, 429)]:
        response = domain.client.post('/v1/tracks', json={**body, **changes,
            'document': {**body['document'], 'padding': 'x' * 420000}}, headers=headers(domain))
        assert response.status_code == code, response.text
        assert set(blobs.root.glob('*/*.json')) == before
    duplicate = domain.client.post('/v1/tracks', json=body, headers=headers(domain))
    assert duplicate.status_code == 201 and duplicate.json()['version_id'] == first['version_id']


def test_expired_last_validation_lease_is_not_claimed_again(domain, monkeypatch):
    version, _ = save(domain)
    with domain.factory() as session:
        job = session.get(TrackValidation, version['version_id'])
        job.status, job.attempts, job.lease_until, job.lease_token = 'validating', 3, 0, 'lost-lease'
        session.commit()
    monkeypatch.setattr(domain.app.state.verifier, 'validate_track', lambda doc: pytest.fail('exhausted validation executed'))
    assert process_one(domain.app)
    with domain.factory() as session:
        job = session.get(TrackValidation, version['version_id'])
        assert job.status == 'failed' and job.attempts == 3 and job.lease_token is None
        assert job.failure_code == 'validator_unavailable'
    response = domain.client.post(f"/v1/me/track-versions/{version['version_id']}/retry-validation", headers=headers(domain))
    assert response.status_code == 200
    with domain.factory() as session:
        assert session.get(TrackValidation, version['version_id']).attempts == 0


@pytest.mark.parametrize('field', ['compiler_version', 'tick_rate', 'track_schema', 'vehicles'])
def test_health_checks_all_pinned_fields(domain, field):
    build = build_contract(domain.app.state.verifier.manifest())
    heartbeat(domain.app, 'mismatch', build={**build, field: {}})
    assert competition_health(domain.app)['status'] == 'worker_build_mismatch'
    heartbeat(domain.app, 'matching', build=build)
    assert competition_health(domain.app)['status'] == 'ready'


def test_health_rejects_python_verifier_contract_disagreement(domain):
    manifest = domain.app.state.verifier.manifest()
    old = {**manifest, 'rules_key': 'standing-5-road-gates-v16'}
    domain.app.state.verifier.manifest = lambda: old
    heartbeat(domain.app, 'same-old-verifier', build=build_contract(old))
    assert competition_health(domain.app)['status'] == 'api_contract_mismatch'
    assert domain.client.get('/healthz').status_code == 200


@pytest.mark.parametrize('field', ['compiler_version', 'vehicles'])
def test_matching_incomplete_builds_cannot_claim_ready(domain, field):
    manifest = domain.app.state.verifier.manifest()
    manifest[field] = None
    domain.app.state.verifier.manifest = lambda: manifest
    heartbeat(domain.app, 'incomplete', build=build_contract(manifest))
    assert competition_health(domain.app)['status'] == 'api_contract_mismatch'


def test_archive_cancels_pending_work_and_blocks_reinstall_restore(domain):
    version, body = save(domain)
    path = '/v1/me/drafts/track_lifecycle/archive'
    operation = headers(domain)
    first = domain.client.post(path, headers=operation)
    assert first.status_code == 200 and first.json()['shared_versions_retained']
    assert domain.client.post(path, headers=operation).json() == first.json()
    assert domain.client.get('/v1/me/tracks?heads=true', headers=headers(domain)).json()['items'] == []
    assert domain.client.post('/v1/tracks', json=body, headers=headers(domain)).status_code == 409
    assert domain.client.get(f"/v1/me/track-versions/{version['version_id']}/document", headers=headers(domain)).status_code == 200
    assert not process_one(domain.app)
    with domain.factory() as session:
        assert session.get(TrackValidation, version['version_id']).failure_code == 'draft_archived'


def test_conflict_recovery_proves_the_local_operation_and_the_current_head(domain):
    operation = headers(domain)
    body = {'name': 'Owner draft', 'authoring_id': 'own_overlap', 'defer_validation': True,
            'document': {'schema': 'creator-track-v5', 'id': 'own_overlap'}}
    version = domain.client.post('/v1/tracks', json=body, headers=operation).json()
    path = '/v1/me/drafts/own_overlap/head'
    response = domain.client.get(path, params={'upload_key': operation['Idempotency-Key']}, headers=headers(domain))
    assert response.json()['version_id'] == response.json()['acknowledged_upload_version_id'] == version['version_id']
    assert domain.client.get(path, params={'upload_key': 'unknown-operation'}, headers=headers(domain)).json()['acknowledged_upload_version_id'] is None
    assert domain.client.get(path, headers=headers(domain, 'Alice')).status_code == 404
    second = domain.client.post('/v1/tracks', json={**body, 'document': {**body['document'], 'edit': 'another device'}}, headers=headers(domain)).json()
    response = domain.client.get(path, params={'upload_key': operation['Idempotency-Key']}, headers=headers(domain)).json()
    assert response['version_id'] == second['version_id']
    assert response['acknowledged_upload_version_id'] == version['version_id']


def test_archive_before_inflight_create_fences_late_save_and_keeps_shared_links(domain):
    assert domain.client.post('/v1/me/drafts/late_save/archive', headers=headers(domain)).status_code == 200
    body = {'name': 'Late', 'document': {'schema': 'creator-track-v5', 'id': 'late_save'},
            'authoring_id': 'late_save', 'defer_validation': True}
    assert domain.client.post('/v1/tracks', json=body, headers=headers(domain)).status_code == 409
    published, _ = public_course(domain)
    with domain.factory() as session:
        track_id = session.get(TrackVersion, published['version_id']).track_id
        from bmt_backend.track_models import Track
        session.get(Track, track_id).authoring_id = 'shared_archive'
        session.commit()
    assert domain.client.post('/v1/me/drafts/shared_archive/archive', headers=headers(domain)).status_code == 200
    assert domain.client.get(f"/v1/track-versions/{published['version_id']}").status_code == 200
    assert domain.client.get(f"/v1/track-versions/{published['version_id']}/leaderboard").status_code == 200


def test_maximum_four_channel_replay_fits_both_json_boundaries():
    replay = {'schema': 'bmt-replay-v1', 'frames': [[0, 0, 0, 0]] * MAX_FRAMES}
    validate_replay(replay)
    body = canonical_json({'ticket_id': '0' * 36, 'replay': replay})
    assert parse_body(body)['replay']['frames'] == replay['frames']
    # A separate maximum-size JSON track plus the replay stays within the worker budget.
    document = {'points': [0] * 250000}
    assert len(canonical_json(document)) <= 524288
    assert _json_bytes({'document': document, 'replay': replay}, MAX_REQUEST_BYTES)


def test_retention_bounds_referenced_inspections_and_batches_queries(domain):
    blobs = domain.app.state.blobs
    old = now() - 100 * 86400
    version, _ = save(domain)
    with domain.factory() as session:
        template = session.get(TrackVersion, version['version_id'])
        for number in range(120):
            digest = blobs.put_json({'reference': number})
            os.utime(blobs._path(digest), (old, old))
            session.add(TrackVersion(track_id=template.track_id, number=number + 2,
                                    name='Retained', content_hash=digest, manifest={}))
        session.commit()
    orphan = blobs.put_json({'orphan': True})
    os.utime(blobs._path(orphan), (old, old))
    queries = []
    def capture(connection, cursor, statement, parameters, context, many):
        if 'content_hash IN' in statement or 'replay_hash IN' in statement:
            queries.append(statement)
    event.listen(domain.app.state.engine, 'before_cursor_execute', capture)
    try:
        cursor, found, inspected = None, 0, 0
        for _ in range(20):
            result = retain(domain.factory, blobs, object_cursor=cursor, scan_limit=17)
            assert result['objects_inspected'] <= 17
            assert len(queries) <= 2
            queries.clear()
            found += result['orphaned_objects']
            inspected += result['objects_inspected']
            cursor = result['next_object_cursor']
            if cursor is None: break
        assert cursor is None and found == 1 and inspected == 122
        with domain.factory() as session:
            assert len(session.scalars(select(TrackVersion)).all()) == 121
    finally:
        event.remove(domain.app.state.engine, 'before_cursor_execute', capture)
