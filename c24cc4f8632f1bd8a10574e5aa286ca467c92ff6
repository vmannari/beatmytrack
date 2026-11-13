"""Finding and operation probes against invented, isolated local fixtures only."""
import importlib.util
import json
import sys
import time
from collections import Counter
from dataclasses import replace
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException
from sqlalchemy import event, select

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend/tests"))
from conftest import auth_app, auth_client, sign_in  # noqa: F401,E402
from test_studio_platform import platform  # noqa: F401,E402
from test_domains import domain, public_course, race, ticket, submit, headers  # noqa: F401,E402
from bmt_backend.commerce_models import Entitlements, Purchase  # noqa: E402
from bmt_backend.studio_finance import play_account  # noqa: E402
from bmt_backend.track_models import now  # noqa: E402
from bmt_backend.worker import process_one  # noqa: E402


def test_current_load_lab_submission_is_rejected_before_real_acceptance():
    import pytest
    from types import SimpleNamespace
    from bmt_backend.load_fixtures import golden_fixture, pack_replay
    from bmt_backend.replay_wire import unpack_replay
    from bmt_backend.verifier import GodotVerifier, VerificationError
    replay = unpack_replay(pack_replay(golden_fixture()["replay"]))
    assert "race_proof" not in replay
    verifier = GodotVerifier(SimpleNamespace(godot_bin="", game_project=str(ROOT/"game"),
        verifier_timeout_seconds=90, persistent_verifier=False))
    try:
        with pytest.raises(VerificationError, match="Race trajectory is required"):
            verifier.verify_run(None, replay, "compact", geometry={})
    finally:
        verifier.close()
    (OUT/"load-protocol-probe.json").write_text(json.dumps({"load_client_schema": replay["schema"],
        "race_proof_present": False, "current_real_adapter_result": "Race trajectory is required; update the client",
        "native_engine_calls": 0, "scope": "Direct current load encoder/decoder and actual acceptance adapter; no load generated"},indent=2)+"\n")


def test_provider_completion_failure_leaves_granted_purchase_without_durable_completion(platform):
    app, client, player, auth = platform
    app.state.settings = replace(app.state.settings, studio_play_package="com.example.audit")

    class Provider:
        def verify(self, _token):
            return {"obfuscatedExternalAccountId": play_account(player),
                "purchaseCompletionTime": datetime.fromtimestamp(now(), timezone.utc).isoformat(),
                "purchaseStateContext": {"purchaseState": "PURCHASED"},
                "productLineItem": [{"productId": "creator_slot_1", "productOfferDetails": {
                    "quantity": 1, "refundableQuantity": 1,
                    "consumptionState": "CONSUMPTION_STATE_YET_TO_BE_CONSUMED"}}]}

        def complete(self, *_args):
            raise HTTPException(503, "PLAY_COMPLETION_RETRY_REQUIRED")

    app.state.studio_play_provider = Provider()
    statuses = []
    for _ in range(2):
        response = client.post("/v1/billing/google-play/verify", headers=auth,
            json={"product_id": "creator_slot_1", "purchase_token": "invented-audit-token-no-provider-call"})
        assert response.status_code == 503
        statuses.append(response.status_code)
    with app.state.session_factory() as db:
        purchases = list(db.scalars(select(Purchase).where(Purchase.player_id == player)))
        assert len(purchases) == 1 and purchases[0].fulfilled_at is not None
        assert db.get(Entitlements, player).slots == 2
        assert "purchase_token" not in Purchase.__table__.columns
        assert not any("acknow" in c.name or "completion" in c.name for c in Purchase.__table__.columns)
    (OUT / "purchase-failure-probe.json").write_text(json.dumps({"http_statuses": statuses,
        "persisted_purchases": 1, "slots_after_two_failed_responses": 2,
        "initial_slots": 1, "duplicate_grant": False,
        "finding": "Fulfilment commits before provider completion; no durable completion work/token in Purchase",
        "scope": "Existing legacy-enabled test fixture, invented Google response; no external provider or money"}, indent=2)+"\n")


def test_retained_trajectory_incident_and_deletion_findings(auth_client, sign_in):
    source = OUT.parent / "security-second-review-2026-10-24/test_retained_risks.py"
    spec = importlib.util.spec_from_file_location("audit_retained_findings", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.test_sec01_nonphysical_current_trajectory_is_still_accepted()
    module.test_sec02_incident_claim_still_controls_clean_result()
    module.test_sec05_deletion_still_accepts_normal_bearer(auth_client, sign_in)


def test_authenticated_read_operation_counts(auth_app, auth_client, sign_in):
    rows = []

    def measure(name, operation):
        statements = []
        def record(_conn, _cursor, sql, *_args):
            statements.append(sql.lstrip().split(None, 1)[0].upper())
        event.listen(auth_app.state.engine, "before_cursor_execute", record)
        started = time.perf_counter()
        try:
            value = operation()
        finally:
            elapsed = (time.perf_counter()-started)*1000
            event.remove(auth_app.state.engine, "before_cursor_execute", record)
        rows.append({"operation": name, "top_level_sql_statements": len(statements),
            "statement_types": dict(Counter(statements)), "elapsed_local_ms": elapsed,
            "response_bytes_after_client_decoding": len(value.content) if hasattr(value, "content") else None,
            "http_status": value.status_code if hasattr(value, "status_code") else None})
        return value

    signed = measure("Google challenge + new fictional account login (two HTTP requests)",
        lambda: sign_in("audit-operation", analytics=False))
    auth = {"Authorization": "Bearer "+signed["access_token"]}
    for path in ("/v1/bootstrap", "/v1/me", "/v1/me/appearances", "/v1/store/products",
                 "/v1/me/entitlements", "/v1/news/friends"):
        response = measure(path, lambda p=path: auth_client.get(p, headers=auth))
        assert response.status_code == 200, response.text
    (OUT / "operation-probe-auth.json").write_text(json.dumps({"scope": "SQLite/TestClient, fictional identity verifier, cold leases; not cloud latency or provider login CPU",
        "qualification": "SQL counts exclude work performed inside database triggers and are not billed operations; no percentile claim from single calls",
        "operations": rows}, indent=2)+"\n")


def test_race_operation_counts(domain):
    version, board = public_course(domain)
    race(domain, version, player="Alice", frames=30)
    rows = []
    def measure(name, operation):
        statements = []
        def record(_conn, _cursor, sql, *_args):
            statements.append(sql.lstrip().split(None, 1)[0].upper())
        event.listen(domain.app.state.engine, "before_cursor_execute", record)
        started = time.perf_counter()
        try:
            value = operation()
        finally:
            event.remove(domain.app.state.engine, "before_cursor_execute", record)
        rows.append({"operation": name, "top_level_sql_statements": len(statements),
            "statement_types": dict(Counter(statements)), "elapsed_local_ms": (time.perf_counter()-started)*1000})
        return value
    issued = measure("ordinary ticket", lambda: ticket(domain, version, "Alice"))
    submitted = measure("ordinary upload", lambda: submit(domain, issued, "Alice", frames=40))
    assert measure("non-PB acceptance", lambda: process_one(domain.app))
    for name, path in (("run status", "/v1/runs/"+submitted["run_id"]), ("leaderboard top", "/v1/boards/"+board),
                 ("track document", "/v1/track-versions/"+version["version_id"]+"/document")):
        result = measure(name, lambda p=path: domain.client.get(p, headers=headers(domain,"Alice")))
        assert result.status_code == 200, result.text
    (OUT / "operation-probe-race.json").write_text(json.dumps({"scope": "SQLite, FakeVerifier and test player dependency override; excludes real auth and checker costs",
        "qualification": "Cold/warm state is fixture-specific; no trigger-internal statements, PostgreSQL plans or concurrent load",
        "operations": rows},indent=2)+"\n")
