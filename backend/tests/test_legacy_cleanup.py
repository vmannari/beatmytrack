"""Upgrade boundaries preserve accepted results and reject retired contracts."""
from dataclasses import replace

import pytest
from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, submit, ticket

from bmt_backend.config import Settings
from bmt_backend.track_models import Run, RunTicket, now

domain = domain_fixture


def test_pre_update_submission_is_recovered_without_reencoding_or_reissuing(domain):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    path = f"/v1/run-tickets/{issued['ticket_id']}/submission"
    assert domain.client.get(path, headers=headers(domain, "Alice")).json() == {"run": None}
    assert domain.client.get(path, headers=headers(domain, "Bob")).status_code == 404
    assert domain.client.get(path).status_code == 401
    accepted = submit(domain, issued, "Alice")
    with domain.factory() as db:
        before = db.get(Run, accepted["run_id"])
        immutable_hash = before.replay_hash
        db.get(RunTicket, issued["ticket_id"]).expires_at = now() - 1
        count = db.scalar(select(func.count()).select_from(Run))
        db.commit()
    for _ in range(2):
        response = domain.client.get(path, headers=headers(domain, "Alice"))
        assert response.status_code == 200, response.text
        assert response.json()["run"]["run_id"] == accepted["run_id"]
        assert response.json()["run"]["ticket_id"] == issued["ticket_id"]
    with domain.factory() as db:
        assert db.scalar(select(func.count()).select_from(Run)) == count
        assert db.get(Run, accepted["run_id"]).replay_hash == immutable_hash
    assert domain.client.get(path, headers=headers(domain, "Bob")).status_code == 404
    assert domain.client.get("/v1/run-tickets/missing/submission", headers=headers(domain)).status_code == 404


def test_retired_transport_configuration_is_rejected():
    with pytest.raises(ValueError):
        Settings(transport_profile="legacy")
    assert Settings().transport_profile == "compact"


def test_shared_studio_credentials_are_explicit_and_nonproduction(auth_app, auth_client):
    assert not Settings().studio_legacy_keys_enabled
    for values in ({"studio_legacy_keys_enabled": True}, {"admin_owner_key": "o" * 40},
                   {"admin_analyst_key": "a" * 40}):
        with pytest.raises(ValueError, match="named staff|legacy administrator"):
            Settings(environment="production", **values)
    auth_app.state.settings = replace(auth_app.state.settings, environment="test", admin_owner_key="o" * 40,
                                      studio_legacy_keys_enabled=False)
    owner = {"Authorization": "Bearer " + "o" * 40}
    assert auth_client.get("/v1/admin/competition-health", headers=owner).status_code == 401
    auth_app.state.settings = replace(auth_app.state.settings, studio_legacy_keys_enabled=True)
    assert auth_client.get("/v1/admin/competition-health", headers=owner).status_code == 200
