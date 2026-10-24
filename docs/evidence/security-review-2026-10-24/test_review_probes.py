"""Local review reproductions. Passing findings tests CONFIRM the stated risk."""
import copy
import json
from pathlib import Path
import sys
from dataclasses import replace
from types import SimpleNamespace
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'backend'))
sys.path.insert(0, str(ROOT / 'backend/tests'))

from conftest import auth_app, auth_client, sign_in  # noqa: E402,F401
from test_rivalry_appearance import appearance  # noqa: E402
from bmt_backend.economy import PRICES  # noqa: E402
from bmt_backend.trajectory_verifier import check  # noqa: E402
from bmt_backend.verifier import GodotVerifier  # noqa: E402


def square():
    # Deliberately synthetic descriptor: isolates the deployed acceptance predicate.
    # One move per tick starts at 60m/s with instantaneous 90-degree corners.
    geometry = {'manifest': {'rules_key': 'standing-5-road-gates-v23'},
        'start': [-11., -11., 0], 'creator_start': [-11., -11., 0],
        'extent': [30, 30], 'maximum_speed': {'compact': 120},
        'gates': [[1, 0, -10, 0, 1, 10, -2, 2, 0],
                  [0, 1, -10, 1, 0, -10, -2, 2, 0],
                  [-1, 0, -10, 0, 1, -10, -2, 2, 0],
                  [0, -1, -10, 1, 0, 10, -2, 2, 0]]}
    samples = [[0, -11., -11., 0]]
    tick, x, y = 0, -11., -11.
    for _lap in range(5):
        for dx, dy in ((.5, 0), (0, .5), (-.5, 0), (0, -.5)):
            for _ in range(44):
                tick += 1
                x, y = x + dx, y + dy
                samples.append([tick, x, y, 0])
    # The fifth lap crosses its final gate one tick before the last square corner.
    return geometry, {'schema': 'bmt-race-path-v1', 'samples': samples[:-1]}, tick - 1


def test_finding_s01_nonphysical_path_and_zero_controls_are_accepted():
    geometry, proof, ticks = square()
    settings = SimpleNamespace(godot_bin='', game_project=str(ROOT / 'game'),
                               verifier_timeout_seconds=90, persistent_verifier=False)
    verifier = GodotVerifier(settings)
    try:
        light = {'schema': 'bmt-trajectory-v1', 'input_count': ticks, 'race_proof': proof}
        legacy = {'schema': 'bmt-replay-v1', 'frames': [[0, 0, 0]] * ticks, 'race_proof': proof}
        first = verifier.verify_run(None, light, 'compact', geometry=geometry)
        second = verifier.verify_run(None, legacy, 'compact', geometry=geometry)
        assert first['verification_method'] == 'trajectory-v1'
        assert first['time_ticks'] == second['time_ticks'] == 879
        assert len(first['lap_ticks']) == 5
    finally:
        verifier.close()


def test_finding_s02_incident_free_is_controlled_by_the_submitter():
    geometry, proof, ticks = square()
    baseline = check(geometry, proof, ticks, 'compact')
    modified = copy.deepcopy(proof)
    modified['incidents'] = {'schema': 'bmt-race-incidents-v1', 'ticks': ticks,
                             'collision_count': 0, 'off_track': False}
    claimed_clean = check(geometry, modified, ticks, 'compact')
    assert baseline['incident_free'] is False
    assert claimed_clean['incident_free'] is True
    assert baseline['time_ticks'] == claimed_clean['time_ticks']


@pytest.mark.parametrize('path', ['/v1/me/appearances', '/v1/rivalry/appearance'])
def test_finding_s03_unowned_coin_cosmetics_can_be_saved(auth_client, sign_in, path):
    signed = sign_in(analytics=False)
    headers = {'Authorization': 'Bearer ' + signed['access_token']}
    wallet = auth_client.get('/v1/economy', headers=headers).json()
    assert wallet['balance'] == 0 and wallet['owned'] == []
    value = appearance()
    value['customisation']['body'] = 'wide'
    assert PRICES['kit/compact/body/wide'] == 750
    body = {'appearance': value, 'previous': None} if '/me/' in path else value
    accepted = auth_client.put(path, headers=headers, json=body)
    assert accepted.status_code == 200, accepted.text
    restored = auth_client.get('/v1/me/appearances', headers=headers).json()
    assert restored['appearances']['compact']['customisation']['body'] == 'wide'
    after = auth_client.get('/v1/economy', headers=headers).json()
    assert after['balance'] == 0 and after['owned'] == []


def test_finding_s04_production_temporary_ad_credit_has_no_provider_proof(auth_client, sign_in):
    signed = sign_in(analytics=False)
    headers = {'Authorization': 'Bearer ' + signed['access_token']}
    wallet = auth_client.get('/v1/resumes', headers=headers).json()
    assert wallet['ads_available'] is False and wallet['ad_preview_available'] is True
    race = auth_client.post('/v1/resume-races', headers={**headers, 'Idempotency-Key': str(uuid4())}, json={})
    assert race.status_code == 201, race.text
    path = '/v1/resume-races/' + race.json()['race_id'] + '/resumes'
    for ordinal in (1, 2, 3):
        reply = auth_client.post(path, headers={**headers, 'Idempotency-Key': str(uuid4())},
            json={'ordinal': ordinal, 'input_offset': ordinal * 120, 'from_tick': 120, 'to_tick': 0})
        assert reply.status_code == 200, reply.text
    assert reply.json()['wallet']['balance'] == 0 and reply.json()['used'] == 3


def test_finding_s05_normal_bearer_can_permanently_delete_without_recent_google_proof(auth_client, sign_in):
    signed = sign_in(analytics=False)
    headers = {'Authorization': 'Bearer ' + signed['access_token']}
    result = auth_client.post('/v1/privacy/account-deletion', headers=headers,
        json={'confirmation': 'DELETE', 'request_id': str(uuid4())})
    assert result.status_code == 202, result.text
    assert auth_client.get('/v1/me', headers=headers).status_code == 401


def test_control_admin_rejects_game_credential(auth_client, sign_in):
    signed = sign_in(analytics=False)
    for headers in ({}, {'Authorization': 'Bearer ' + signed['access_token']}):
        assert auth_client.get('/v1/admin/overview', headers=headers).status_code == 401


def test_finding_s07_default_legacy_owner_key_does_not_require_mfa(auth_app, auth_client):
    fixture_key = 'isolated-review-owner-key-' * 3
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key=fixture_key)
    assert auth_app.state.settings.environment == 'production'
    assert auth_app.state.settings.studio_staff_require_mfa is True
    response = auth_client.get('/v1/admin/overview',
        headers={'Authorization': 'Bearer ' + fixture_key})
    assert response.status_code == 200 and response.json()['role'] == 'owner'


@pytest.mark.parametrize('path', ['/v1/admin/publications',
                                 '/v1/admin/publications/00000000-0000-0000-0000-000000000001'])
def test_control_manually_guarded_publication_admin_routes(auth_client, sign_in, path):
    signed = sign_in(analytics=False)
    for headers in ({}, {'Authorization': 'Bearer ' + signed['access_token']}):
        assert auth_client.get(path, headers=headers).status_code == 401


def test_control_appearance_rejects_other_owner_and_unknown_item(auth_client, sign_in):
    first = sign_in('First', analytics=False)
    second = sign_in('Second', analytics=False)
    h1 = {'Authorization': 'Bearer ' + first['access_token']}
    h2 = {'Authorization': 'Bearer ' + second['access_token']}
    value = appearance()
    assert auth_client.put('/v1/me/appearances', headers=h1,
        json={'appearance': value, 'previous': None}).status_code == 200
    assert auth_client.get('/v1/me/appearances', headers=h2).json() == {'appearances': {}}
    value['customisation']['body'] = 'unknown'
    assert auth_client.put('/v1/me/appearances', headers=h2,
        json={'appearance': value, 'previous': None}).status_code == 422


@pytest.mark.parametrize('body', [b'{"a":1,"a":2}', b'{"x":NaN}', b'{"x":Infinity}',
                                  b'{"x":"\\ud800"}', b'[' * 40 + b'0' + b']' * 40])
def test_control_malformed_json_rejected_at_ingress(auth_client, body):
    result = auth_client.post('/v1/auth/google/challenge', content=body,
                             headers={'Content-Type': 'application/json'})
    assert result.status_code == 400, result.text
