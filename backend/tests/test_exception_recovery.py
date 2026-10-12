"""Recovery must preserve identities, exact proof, wallet authority and lease fences."""
import json
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select
from sqlalchemy.exc import OperationalError
from test_auth_postgres import google_request
from test_auth_postgres import postgres_auth as postgres_auth_fixture
from test_domains import FakeVerifier, headers, public_course, submit, ticket
from test_domains import domain as domain_fixture

from bmt_backend.app import create_app
from bmt_backend.identity_models import SessionFamily, SessionToken
from bmt_backend.job_contracts import capability_matches
from bmt_backend.maintenance import retain
from bmt_backend.resume_models import ResumeRace, ResumeReceipt
from bmt_backend.resumes import grant_verified
from bmt_backend.track_models import PersonalBest, Run, RunTicket, now
from bmt_backend.worker import process_one

domain = domain_fixture
postgres_auth = postgres_auth_fixture


def test_refresh_lost_response_recovers_same_credentials_without_plaintext_storage(auth_app, auth_client, sign_in):
    signed = sign_in()
    body = {"refresh_token": signed["refresh_token"], "refresh_request_id": "a" * 48}
    first = auth_client.post("/v1/auth/refresh", json=body)
    assert first.status_code == 200
    fresh = create_app(auth_app.state.settings, engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier)
    with TestClient(fresh) as peer:
        recovered = peer.post("/v1/auth/refresh", json=body)
    assert recovered.status_code == 200
    for field in ("access_token", "refresh_token"):
        assert recovered.json()[field] == first.json()[field]
    with auth_app.state.session_factory() as session:
        rows = list(session.scalars(select(SessionToken)))
        assert len(rows) == 2
        assert not session.scalar(select(SessionFamily)).revoked
        stored = json.dumps([{c.name: getattr(r, c.name) for c in SessionToken.__table__.columns} for r in rows])
        for secret in (body["refresh_token"], body["refresh_request_id"],
                       first.json()["access_token"], first.json()["refresh_token"]):
            assert secret not in stored


def test_refresh_another_operation_still_revokes_family(auth_client, sign_in):
    signed = sign_in()
    first = auth_client.post("/v1/auth/refresh", json={"refresh_token": signed["refresh_token"], "refresh_request_id": "a" * 48})
    stolen = auth_client.post("/v1/auth/refresh", json={"refresh_token": signed["refresh_token"], "refresh_request_id": "b" * 48})
    assert stolen.status_code == 401
    assert stolen.json()["detail"] == "REFRESH_REUSE_DETECTED"
    assert auth_client.get("/v1/me", headers={"Authorization": "Bearer " + first.json()["access_token"]}).status_code == 401


def test_sqlite_concurrent_same_refresh_operation_has_one_replacement(auth_app, auth_client, sign_in):
    signed = sign_in()
    body = {"refresh_token": signed["refresh_token"], "refresh_request_id": "e" * 48}
    with ThreadPoolExecutor(max_workers=8) as pool:
        replies = list(pool.map(lambda _: auth_client.post("/v1/auth/refresh", json=body), range(8)))
    assert all(r.status_code == 200 for r in replies)
    assert len({r.json()["refresh_token"] for r in replies}) == 1
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(SessionToken)) == 2


def test_refresh_recovery_is_bounded_and_does_not_revoke_newer_valid_session(auth_app, auth_client, sign_in):
    signed = sign_in()
    body = {"refresh_token": signed["refresh_token"], "refresh_request_id": "c" * 48}
    first = auth_client.post("/v1/auth/refresh", json=body).json()
    with auth_app.state.session_factory() as session:
        old = session.scalar(select(SessionToken).where(SessionToken.consumed.is_(True)))
        old.rotated_at = now() - auth_app.state.settings.refresh_recovery_seconds - 1
        session.commit()
    assert auth_client.post("/v1/auth/refresh", json=body).status_code == 401
    assert auth_client.get("/v1/me", headers={"Authorization": "Bearer " + first["access_token"]}).status_code == 200


def test_garbage_header_cannot_bypass_public_budget_but_valid_users_have_independent_budgets(auth_app, sign_in):
    a, b = sign_in("budget-a"), sign_in("budget-b")
    settings = replace(auth_app.state.settings, rate_limit_per_minute=2, edge_limit_per_minute=100)
    peer = create_app(settings, engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier)
    with TestClient(peer) as client:
        assert [client.get("/v1/bootstrap").status_code for _ in range(3)] == [200, 200, 429]
        assert client.get("/v1/bootstrap", headers={"Authorization": "garbage"}).status_code == 429
        for account in (a, b):
            h = {"Authorization": "Bearer " + account["access_token"]}
            assert [client.get("/v1/bootstrap", headers=h).status_code for _ in range(3)] == [200, 200, 429]


def test_all_responses_have_server_time_and_legacy_fleet_floor(auth_app):
    peer = create_app(replace(auth_app.state.settings, transport_profile="legacy"),
                      engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier)
    with TestClient(peer) as client:
        response = client.get("/v1/bootstrap")
        assert abs(int(response.headers["x-server-time"]) - now()) <= 2
        assert response.json()["upload_encodings"] == ["identity"]
        assert response.json()["refresh_recovery_seconds"] == 0
        assert response.json()["resume_recovery"] is False
        assert client.get("/v1/me").headers["x-server-time"]


def resume_operation(domain, *, bank=0):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    if bank:
        with domain.factory() as session:
            grant_verified(session, domain.players["Alice"], "award", "recovery-fixture", bank)
            session.commit()
    beginning_key, consume_key = "recover-begin-key", "recover-consume-key"
    beginning = domain.client.post("/v1/resume-races", json={"ticket_id": issued["ticket_id"]},
                                   headers=headers(domain, "Alice", beginning_key)).json()
    selection = {"ordinal": 1, "input_offset": 10, "from_tick": 10, "to_tick": 0, "recovery": "v1"}
    response = domain.client.post("/v1/resume-races/" + beginning["race_id"] + "/resumes", json=selection,
                                  headers=headers(domain, "Alice", consume_key))
    assert response.status_code == 200
    recovery = {"begin_key": beginning_key, "consume_key": consume_key, "race_id": beginning["race_id"],
                "ticket_id": issued["ticket_id"], "selection": selection}
    return issued, response.json(), recovery


@pytest.mark.parametrize("bank", [0, 2])
def test_unknown_resume_abandon_returns_resource_once_and_permanently_closes_attempt(domain, bank):
    issued, consumed, recovery = resume_operation(domain, bank=bank)
    body = {**recovery, "action": "abandon"}
    for _ in range(3):
        response = domain.client.post("/v1/resume-recovery", json=body, headers=headers(domain, "Alice"))
        assert response.status_code == 200
        assert response.json()["state"] == "abandoned"
        assert response.json()["wallet"]["balance"] == bank
        assert response.json()["wallet"]["free"] == 1
    submitted = domain.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"],
        "replay": {"schema": "bmt-replay-v2", "frames": [[0, 255, 0]] * 20,
                   "rewinds": [{**{k: recovery["selection"][k] for k in ("input_offset", "from_tick", "to_tick")},
                                "receipt_id": consumed["receipt_id"]}]}},
        headers=headers(domain, "Alice"))
    assert submitted.status_code == 409
    assert submitted.json()["detail"] == "RACE_ABANDONED"
    late = domain.client.post("/v1/resume-races/" + recovery["race_id"] + "/resumes",
                              json=recovery["selection"], headers=headers(domain, "Alice", recovery["consume_key"]))
    assert late.status_code == 409


def test_confirmed_resume_is_not_refunded_and_cross_account_recovery_is_denied(domain):
    _, _, recovery = resume_operation(domain, bank=2)
    assert domain.client.post("/v1/resume-recovery", json={**recovery, "action": "confirm"},
                              headers=headers(domain, "Alice")).status_code == 200
    assert domain.client.post("/v1/resume-recovery", json={**recovery, "action": "abandon"},
                              headers=headers(domain, "Bob")).status_code == 404
    cancelled = domain.client.post("/v1/resume-recovery", json={**recovery, "action": "abandon"},
                                   headers=headers(domain, "Alice")).json()
    assert cancelled["wallet"]["balance"] == 1


def test_expired_daily_allowance_never_rolls_into_banked_credit(domain):
    _, consumed, recovery = resume_operation(domain)
    with domain.factory() as session:
        session.get(ResumeReceipt, consumed["receipt_id"]).created_at -= 86400
        session.commit()
    result = domain.client.post("/v1/resume-recovery", json={**recovery, "action": "abandon"},
                                headers=headers(domain, "Alice")).json()
    assert result["wallet"]["balance"] == 0 and result["wallet"]["free"] == 0


def test_accepted_replay_cannot_refund_or_abandon_authorized_resume(domain):
    issued, consumed, recovery = resume_operation(domain, bank=1)
    replay = {"schema": "bmt-replay-v2", "frames": [[0, 255, 0]] * 20,
              "rewinds": [{"receipt_id": consumed["receipt_id"], **{k: recovery["selection"][k]
                           for k in ("input_offset", "from_tick", "to_tick")}}]}
    accepted = domain.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"], "replay": replay},
                                  headers=headers(domain, "Alice"))
    assert accepted.status_code == 202
    assert domain.client.post("/v1/resume-recovery", json={**recovery, "action": "abandon"},
                              headers=headers(domain, "Alice")).status_code == 409


def test_recovery_does_not_create_a_charge_for_undelivered_consume(domain):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    beginning = domain.client.post("/v1/resume-races", json={"ticket_id": issued["ticket_id"]},
                                   headers=headers(domain, "Alice", "never-charge-begin")).json()
    body = {"begin_key": "never-charge-begin", "consume_key": "never-delivered-consume",
            "race_id": beginning["race_id"], "ticket_id": issued["ticket_id"], "action": "abandon",
            "selection": {"ordinal": 1, "input_offset": 10, "from_tick": 10, "to_tick": 0, "recovery": "v1"}}
    assert domain.client.post("/v1/resume-recovery", json=body, headers=headers(domain, "Alice")).status_code == 200
    with domain.factory() as session:
        assert session.scalar(select(func.count()).select_from(ResumeReceipt)) == 0
        assert session.get(ResumeRace, beginning["race_id"]).abandoned


def test_old_unsettled_receipt_is_safely_closed_before_retention_prunes_it(domain):
    _, consumed, recovery = resume_operation(domain, bank=1)
    with domain.factory() as session:
        expired = now() - 100 * 86400
        session.get(ResumeRace, recovery["race_id"]).expires_at = expired
        session.get(RunTicket, recovery["ticket_id"]).expires_at = expired
        session.get(ResumeReceipt, consumed["receipt_id"]).created_at -= 100 * 86400
        session.commit()
    retain(domain.factory, domain.app.state.blobs, apply=True, online=True)
    with domain.factory() as session:
        assert session.get(ResumeReceipt, consumed["receipt_id"]) is None


def test_incompatible_worker_skips_without_attempt_and_original_cohort_can_verify(domain):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    queued = submit(domain, issued, "Alice")
    good = domain.app.state.verifier
    class OtherBuild(FakeVerifier):
        def manifest(self):
            return {**super().manifest(), "physics_version": "another-build"}
        def verify_run(self, *args, **kwargs):
            pytest.fail("An incompatible worker executed the recording")
    domain.app.state.verifier = OtherBuild()
    assert not process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, queued["run_id"])
        assert run.status == "queued" and run.attempts == 0
    assert not capability_matches(issued["manifest"], domain.app.state.verifier.manifest())
    domain.app.state.verifier = good
    assert process_one(domain.app)
    assert domain.client.get("/v1/runs/" + queued["run_id"], headers=headers(domain, "Alice")).json()["status"] == "verified"


def test_server_metadata_value_error_is_infrastructure_and_can_recover_after_repair(domain):
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    with domain.factory() as session:
        row = session.get(Run, queued["run_id"])
        original = row.replay_hash
        row.replay_hash = "z" * 64
        session.commit()
    assert process_one(domain.app)
    with domain.factory() as session:
        row = session.get(Run, queued["run_id"])
        assert row.status == "queued" and row.failure_code == "verifier_unavailable"
        row.replay_hash, row.lease_until = original, 0
        session.commit()
    assert process_one(domain.app)
    with domain.factory() as session:
        assert session.get(Run, queued["run_id"]).status == "verified"


def test_computed_result_retries_finalization_without_reverification_or_lease_wait(domain, monkeypatch):
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    count = [0]
    actual = domain.app.state.verifier.verify_run
    def counted(*args, **kwargs):
        count[0] += 1
        return actual(*args, **kwargs)
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", counted)
    def fault(_c, _cur, sql, parameters, _ctx, _many):
        if sql.startswith("UPDATE runs SET") and "verified" in str(parameters):
            raise OperationalError("synthetic finalization", {}, Exception("unavailable"), hide_parameters=True)
    event.listen(domain.app.state.engine, "before_cursor_execute", fault)
    try:
        with pytest.raises(OperationalError): process_one(domain.app)
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", fault)
    assert process_one(domain.app)
    assert count == [1]
    with domain.factory() as session:
        assert session.get(Run, queued["run_id"]).status == "verified"
        assert session.scalar(select(PersonalBest).where(PersonalBest.run_id == queued["run_id"])) is not None


def test_concurrent_postgres_abandonment_returns_exactly_one_credit(domain):
    if not domain.postgres: pytest.skip("PostgreSQL row-lock acceptance")
    _, _, recovery = resume_operation(domain, bank=1)
    def request(_):
        return domain.client.post("/v1/resume-recovery", json={**recovery, "action": "abandon"},
                                  headers=headers(domain, "Alice")).json()
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(request, range(8)))
    assert all(r["wallet"]["balance"] == 1 for r in results)


@pytest.mark.postgres
def test_postgres_concurrent_refresh_recovery_has_one_replacement(postgres_auth):
    app, client = postgres_auth
    signed = client.post("/v1/auth/google", json=google_request(app, client, "recover-concurrent")).json()
    body = {"refresh_token": signed["refresh_token"], "refresh_request_id": "d" * 48}
    with ThreadPoolExecutor(max_workers=8) as pool:
        replies = list(pool.map(lambda _: client.post("/v1/auth/refresh", json=body), range(8)))
    assert all(r.status_code == 200 for r in replies)
    assert len({r.json()["refresh_token"] for r in replies}) == 1
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(SessionToken)) == 2
        assert not session.scalar(select(SessionFamily)).revoked


def test_postgres_submit_and_abandon_are_mutually_exclusive(domain):
    if not domain.postgres:
        pytest.skip("PostgreSQL row locks")
    issued, consumed, recovery = resume_operation(domain, bank=1)
    body = {"ticket_id": issued["ticket_id"], "replay": {"schema": "bmt-replay-v2",
        "frames": [[0, 255, 0]] * 20, "rewinds": [{"receipt_id": consumed["receipt_id"],
         **{k: recovery["selection"][k] for k in ("input_offset", "from_tick", "to_tick")}}]}}
    with ThreadPoolExecutor(max_workers=2) as pool:
        saved = pool.submit(domain.client.post, "/v1/runs", json=body, headers=headers(domain, "Alice"))
        cancelled = pool.submit(domain.client.post, "/v1/resume-recovery",
                                json={**recovery, "action": "abandon"}, headers=headers(domain, "Alice"))
        save_status, cancel_status = saved.result().status_code, cancelled.result().status_code
    assert (save_status, cancel_status) in ((202, 409), (409, 200))


def test_incompatible_capacity_timeout_preserves_retryable_original_recording(domain):
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice")
    good = domain.app.state.verifier
    class Wrong(FakeVerifier):
        def manifest(self):
            return {**super().manifest(), "physics_version": "unsupported"}
    domain.app.state.verifier = Wrong()
    with domain.factory() as session:
        session.get(Run, queued["run_id"]).created_at -= domain.app.state.settings.worker_contract_wait_seconds + 1
        session.commit()
    assert process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, queued["run_id"])
        assert run.status == "failed" and run.failure_code == "build_unavailable" and run.attempts == 0
        assert domain.app.state.blobs.get_json(run.replay_hash)["frames"]
    domain.app.state.verifier = good
    retried = domain.client.post("/v1/runs/" + queued["run_id"] + "/retry",
                                 headers=headers(domain, "Alice"), json={})
    assert retried.status_code == 200
    assert process_one(domain.app)
