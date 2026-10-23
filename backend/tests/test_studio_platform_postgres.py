"""Run the same platform contracts on actual PostgreSQL JSON, locks and migrations."""

# ruff: noqa: F811
import json
from dataclasses import replace

import pytest
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_studio_platform import (  # noqa: F401
    test_bounded_projection_deduplication_and_full_range_metadata,
    test_case_owner_priority_and_due_date_use_audited_revision_commands,
    test_exhausted_notification_retry_is_owner_only_and_idempotent,
    test_existing_wallet_opening_balance_is_not_earnings,
    test_experiments_assignment_exposure_srm_and_reversible_activation,
    test_external_monitor_is_the_single_notification_authority,
    test_financial_provider_restatement_is_an_immutable_delta_not_double_revenue,
    test_full_scope_quality_and_network_totals_ignore_detail_prefix,
    test_incident_occurrence_idempotency_unknown_recovery_and_operator_cas,
    test_journey_refreshes_when_only_inactive_milestone_arrives,
    test_named_staff_roles_audit_and_revocation,
    test_new_private_facts_are_erased_in_bounded_batches_without_changing_plan,
    test_queue_paging_has_no_duplicates_and_full_summaries,
    test_saved_view_is_actor_scoped_retry_safe_and_csv_neutralises_formulas,
    test_signed_outbox_retries_same_identity_and_finalises_once,
    test_verified_play_purchase_binding_and_replay_never_double_grant,
    test_watchdog_notifies_when_monitored_api_is_offline,
)

pytestmark = pytest.mark.postgres


@pytest.fixture
def platform(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(
        app.state.settings,
        admin_owner_key="o" * 40,
        admin_analyst_key="a" * 40,
        telemetry_enabled=True,
        client_quality_enabled=True,
        studio_monitor_source_tokens=json.dumps({"fixture": "m" * 40}),
    )
    response = client.post("/v1/auth/google", json=google_request(app, client, "studio-platform"))
    assert response.status_code == 200, response.text
    signed = response.json()
    auth = {"Authorization": "Bearer " + signed["access_token"]}
    assert (
        client.post("/v1/privacy/preferences", headers=auth, json={"analytics_enabled": True}).status_code
        == 200
    )
    return app, client, signed["player"]["id"], auth


def test_concurrent_detector_and_acknowledgement_create_one_occurrence(platform):
    from concurrent.futures import ThreadPoolExecutor
    from uuid import uuid4

    from test_studio_platform import MONITOR, OWNER, observation

    from bmt_backend.track_models import now

    _app, client, _player, _auth = platform
    at = now() - 10

    def send(_):
        return client.post(
            "/v1/monitor/fixture/observations", headers=MONITOR, json=observation(at, True)
        ).status_code

    with ThreadPoolExecutor(max_workers=4) as pool:
        assert list(pool.map(send, range(4))) == [200] * 4
    rows = client.get("/v1/admin/incidents", headers=OWNER).json()["items"]
    assert len(rows) == 1
    body = {
        "command_id": str(uuid4()),
        "expected_revision": 0,
        "action": "acknowledge",
        "reason": "Concurrent fixture response",
    }
    url = "/v1/admin/incidents/" + rows[0]["id"] + "/commands"
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert (
            list(pool.map(lambda _: client.post(url, headers=OWNER, json=body).status_code, range(4)))
            == [200] * 4
        )
    detail = client.get("/v1/admin/incidents/" + rows[0]["id"], headers=OWNER).json()
    assert detail["item"]["revision"] == 1 and sum(e["kind"] == "acknowledge" for e in detail["history"]) == 1


def test_projection_batch_has_bounded_sql_work(platform, record_property):
    import time
    from uuid import uuid4

    from sqlalchemy import event, func, select
    from test_studio_platform import event as observed

    from bmt_backend.product_analytics import project_pending
    from bmt_backend.studio_platform_models import AnalysisDay
    from bmt_backend.track_models import now

    app, _client, _player, _auth = platform
    with app.state.session_factory() as db:
        db.add_all(
            [observed(str(uuid4()), "session_started", now(), is_test_driver=False) for _ in range(500)]
        )
        db.commit()
    calls = []

    def statement(*_args):
        calls.append(1)

    event.listen(app.state.engine, "before_cursor_execute", statement)
    at = time.perf_counter()
    try:
        result = project_pending(app.state.session_factory)
    finally:
        event.remove(app.state.engine, "before_cursor_execute", statement)
    elapsed = (time.perf_counter() - at) * 1000
    record_property("projection_500_sql", len(calls))
    record_property("projection_500_ms", round(elapsed, 2))
    assert result["processed"] == 500 and len(calls) < 60
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(AnalysisDay)) == 500
