"""Persistent calendar, metric draw, future edits, rollover and retry contracts."""
# ruff: noqa: F811
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_domains import FakeVerifier
from test_rivalry import join, rivalry_domain, seed  # noqa: F401
from test_studio import headers

from bmt_backend.admin_models import AdminAudit
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry import week_window
from bmt_backend.rivalry_models import RivalryGroup, RivalryWeekPlan
from bmt_backend.rivalry_planning import (
    WEEK,
    ensure_vehicle,
    maintain,
    metric,
    plan_contract,
    weighted_tracks,
)
from bmt_backend.track_models import OperationState, Track, TrackVersion, now


@pytest.fixture
def planned(rivalry_domain):
    domain = rivalry_domain
    domain.app.state.settings = replace(domain.app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40)
    versions = seed(domain, 30)
    with domain.factory() as db:
        for i, vid in enumerate(versions):
            version = db.get(TrackVersion, vid)
            version.discovery = {**version.discovery, "theme": ["pine", "desert", "winter", "night", "storm"][i % 5]}
        db.commit()
    return domain, versions


def prepare(domain):
    result = domain.client.post("/v1/admin/rivalry-plans/prepare", headers=headers("owner"),
        json={"command_id": str(uuid4()), "reason": "Plan upcoming weekly events"})
    assert result.status_code == 200, result.text
    return result.json()


def calendar(domain):
    result = domain.client.get("/v1/admin/rivalry-plans", headers=headers())
    assert result.status_code == 200, result.text
    return result.json()


def edit(domain, week, versions):
    body = {"command_id": str(uuid4()), "expected_revision": week["revision"],
            "version_ids": versions, "reason": "Owner curated weekly line-up"}
    path = "/v1/admin/rivalry-plans/" + week["id"]
    preview = domain.client.post(path + "/preview", headers=headers("owner"), json=body)
    assert preview.status_code == 200, preview.text
    body.update({k: preview.json()[k] for k in ("preview_at", "preview_hash")})
    return path, body


def test_worker_fills_four_future_weeks_idempotently_and_reads_do_not_write(planned):
    domain, _ = planned
    assert calendar(domain)["ready_weeks"] == 0
    with domain.factory() as db:
        assert db.scalar(select(func.count()).select_from(RivalryWeekPlan)) == 0
    maintain(domain.app)
    data = calendar(domain)
    start = week_window(now())[0]
    assert data["ready_weeks"] == 4
    assert [w["week_start"] for w in data["weeks"]] == [start + n * WEEK for n in range(1, 5)]
    assert all(w["editable"] for w in data["weeks"])
    assert not data["current"]["editable"]
    chosen = [t["track_id"] for w in [data["current"], *data["weeks"]] for t in w["tracks"]]
    assert len(set(chosen)) == 25  # Enough unused eligible tracks: no calendar repeats.
    assert prepare(domain)["plans_changed"] == 0
    assert calendar(domain)["weeks"] == data["weeks"]


def test_future_override_survives_planner_and_becomes_raced_lineup_at_rollover(planned, monkeypatch):
    domain, versions = planned
    prepare(domain)
    original_group = join(domain)
    week = calendar(domain)["weeks"][0]
    path, body = edit(domain, week, versions[:5])
    response = domain.client.post(path + "/commands", headers=headers("owner"), json=body)
    assert response.status_code == 200, response.text
    assert response.json()["source"] == "manual" and response.json()["revision"] == 1
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).json() == response.json()
    prepare(domain)
    assert [t["version_id"] for t in calendar(domain)["weeks"][0]["tracks"]] == versions[:5]
    with domain.factory() as db:
        saved = db.get(RivalryGroup, original_group["group_id"])
        assert [t["version_id"] for t in saved.tracks] == [t["entry"]["version_id"] for t in original_group["tracks"]]
        assert db.scalar(select(func.count()).select_from(AdminAudit).where(AdminAudit.action == "rivalry_plan_edit")) == 1
    for module in ("rivalry", "rivalry_planning", "studio_rivalry"):
        monkeypatch.setattr("bmt_backend." + module + ".now", lambda: week["week_start"])
    next_group = join(domain)
    assert next_group["group_id"] != original_group["group_id"]
    assert [t["entry"]["version_id"] for t in next_group["tracks"]] == versions[:5]
    rolled = calendar(domain)
    assert not rolled["current"]["editable"]
    assert prepare(domain)["plans_changed"] == 1
    assert calendar(domain)["ready_weeks"] == 4
    # Committed commands remain replayable after the preview expires/week starts.
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).json() == response.json()
    locked_body = {k: v for k, v in body.items() if k not in ("preview_at", "preview_hash")}
    locked_body.update(command_id=str(uuid4()), expected_revision=1)
    assert domain.client.post(path + "/preview", headers=headers("owner"), json=locked_body).json()["detail"] == "RIVALRY_WEEK_LOCKED"


def test_permissions_preview_validation_stale_changes_and_atomic_rollback(planned, monkeypatch):
    domain, versions = planned
    assert domain.client.get("/v1/admin/rivalry-plans").status_code == 401
    assert domain.client.post("/v1/admin/rivalry-plans/prepare", headers=headers(),
        json={"command_id": str(uuid4()), "reason": "Inspect planning"}).status_code == 403
    prepare(domain)
    week = calendar(domain)["weeks"][1]
    path, body = edit(domain, week, versions[5:10])
    assert domain.client.post(path + "/preview", headers=headers(), json={k:v for k,v in body.items()
        if k not in ("preview_at", "preview_hash")}).status_code == 403
    assert domain.client.post(path + "/commands", headers=headers(), json=body).status_code == 403
    assert domain.client.post(path + "/commands", headers=headers("owner"),
        json={**body, "preview_hash": "0" * 64}).json()["detail"] == "PREVIEW_CHANGED_REFRESH_REQUIRED"
    assert domain.client.post(path + "/commands", headers=headers("owner"),
        json={**body, "preview_at": now() - 301}).json()["detail"] == "PREVIEW_EXPIRED"
    with monkeypatch.context() as patch:
        def fail(*args):
            raise RuntimeError("Injected audit write failure")
        patch.setattr("bmt_backend.studio_rivalry.audit", fail)
        assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).status_code == 500
    assert calendar(domain)["weeks"][1]["revision"] == week["revision"]
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).status_code == 200
    assert domain.client.post(path + "/commands", headers=headers("owner"),
        json={**body, "reason": "Different request reuse"}).json()["detail"] == "COMMAND_ID_REUSED"
    assert domain.client.post(path + "/commands", headers=headers("owner"),
        json={**body, "command_id": str(uuid4())}).json()["detail"] == "PLAN_CHANGED_REFRESH_REQUIRED"
    duplicate = {k:v for k,v in body.items() if k not in ("preview_at", "preview_hash")}
    duplicate.update(command_id=str(uuid4()), expected_revision=1, version_ids=[versions[0]] * 5)
    assert domain.client.post(path + "/preview", headers=headers("owner"), json=duplicate).status_code == 422
    duplicate["reason"] = "   "
    assert domain.client.post(path + "/preview", headers=headers("owner"), json=duplicate).status_code == 422


def test_ineligible_future_tracks_repaired_without_overwriting_other_choices(planned):
    domain, versions = planned
    prepare(domain)
    week = calendar(domain)["weeks"][0]
    path, body = edit(domain, week, versions[:5])
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).status_code == 200
    with domain.factory() as db:
        v = db.get(TrackVersion, versions[0])
        db.get(Track, v.track_id).hidden = True
        db.commit()
    data = calendar(domain)
    assert data["ready_weeks"] < 4
    assert versions[0] in data["weeks"][0]["unavailable_version_ids"]
    prepare(domain)
    repaired = calendar(domain)["weeks"][0]
    ids = [t["version_id"] for t in repaired["tracks"]]
    assert versions[0] not in ids and set(versions[1:5]).issubset(ids)
    assert ids[1:] == versions[1:5]
    assert repaired["source"] == "repaired" and repaired["revision"] == 2
    assert calendar(domain)["ready_weeks"] == 4


def test_exact_eligibility_search_and_shortfalls_stay_visible(rivalry_domain):
    domain = rivalry_domain
    domain.app.state.settings = replace(domain.app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40)
    versions = seed(domain, 4)
    assert prepare(domain)["plans_changed"] == 0
    assert calendar(domain)["ready_weeks"] == 0
    found = domain.client.get("/v1/admin/rivalry-plans/candidates?q=Circuit", headers=headers()).json()
    assert len(found["items"]) == 4
    assert domain.client.get("/v1/admin/rivalry-plans/candidates?q=%25", headers=headers()).json()["items"] == []
    with domain.factory() as db:
        v = db.get(TrackVersion, versions[0])
        db.get(Track, v.track_id).archived = True
        db.commit()
    assert len(domain.client.get("/v1/admin/rivalry-plans/candidates", headers=headers()).json()["items"]) == 3
    assert domain.client.get("/v1/admin/rivalry-plans?vehicle_id=unknown", headers=headers()).status_code == 422


def test_week_boundary_closes_preview_and_write_race(planned, monkeypatch):
    domain, versions = planned
    prepare(domain)
    week = calendar(domain)["weeks"][0]
    path, body = edit(domain, week, versions[:5])
    monkeypatch.setattr("bmt_backend.studio_rivalry.now", lambda: week["week_start"])
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).json()["detail"] == "RIVALRY_WEEK_LOCKED"
    # The final UPDATE independently checks time after the preview validation.
    # Create a legitimate preview close to the boundary, then advance during save.
    monkeypatch.setattr("bmt_backend.studio_rivalry.now", lambda: week["week_start"] - 2)
    path, body = edit(domain, week, versions[:5])
    moments = iter([week["week_start"] - 1, week["week_start"]])
    monkeypatch.setattr("bmt_backend.studio_rivalry.now", lambda: next(moments))
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).json()["detail"] == "PLAN_CHANGED_OR_WEEK_LOCKED"
    with domain.factory() as db:
        assert db.get(RivalryWeekPlan, week["id"]).revision == 0


def test_build_change_fences_old_preview_and_keeps_old_plans(planned, monkeypatch):
    domain, versions = planned
    prepare(domain)
    week = calendar(domain)["weeks"][0]
    path, body = edit(domain, week, versions[:5])
    old = domain.app.state.verifier.manifest()
    active = {**old, "physics_version": "physics-next"}
    monkeypatch.setattr(domain.app.state.verifier, "manifest", lambda: active)
    assert domain.client.post(path + "/commands", headers=headers("owner"), json=body).json()["detail"] == "RIVALRY_BUILD_CHANGED"
    assert calendar(domain)["ready_weeks"] == 0
    with domain.factory() as db:
        for vid in versions:
            version = db.get(TrackVersion, vid)
            # Fixture-only compatible content; shipping revisions stay immutable.
            version.manifest = {**version.manifest, "physics_version": "physics-next"}
        db.commit()
    assert prepare(domain)["plans_changed"] == 5
    with domain.factory() as db:
        assert db.scalar(select(func.count()).select_from(RivalryWeekPlan)) == 10
        assert db.get(RivalryWeekPlan, week["id"]).contract_key == plan_contract(old, "compact")


def test_worker_global_interval_and_error_do_not_block_races(planned, monkeypatch):
    domain, _ = planned
    maintain(domain.app)
    domain.app.state.rivalry_planning_next_check = 0
    with monkeypatch.context() as patch:
        def must_not_plan(*args, **kwargs):
            raise AssertionError("Global interval should prevent a second planner")
        patch.setattr("bmt_backend.rivalry_planning.ensure_vehicle", must_not_plan)
        maintain(domain.app)
    with domain.factory() as db:
        row = db.get(OperationState, "rivalry-planning")
        row.updated_at = 0
        db.commit()
    domain.app.state.rivalry_planning_next_check = 0
    with monkeypatch.context() as patch:
        def failed(*args, **kwargs):
            raise RuntimeError("Injected planner outage")
        patch.setattr("bmt_backend.rivalry_planning.ensure_vehicle", failed)
        maintain(domain.app)  # An unavailable planner does not fail an existing race job.
    assert join(domain)["driver_count"] == 1


def test_draw_uses_metrics_variety_and_seed_without_repetition():
    rows = [SimpleNamespace(id=str(i), track_id=str(i), name="Track " + str(i),
        discovery={"theme": "pine" if i < 10 else "winter"},
        rating_sum=49 if i == 0 else 41, rating_count=10,
        verified_finishers=10000 if i == 0 else 0) for i in range(20)]
    used = Counter()
    first = weighted_tracks(rows, "repeatable", used)
    assert weighted_tracks(rows, "repeatable", used) == first
    assert len({t["track_id"] for t in first}) == 5
    used.update(t["track_id"] for t in first)
    assert not {t["track_id"] for t in weighted_tracks(rows, "another", used)}.intersection(used)
    counts = Counter(t["track_id"] for i in range(400) for t in weighted_tracks(rows, str(i), Counter()))
    assert counts["0"] > sum(counts[str(i)] for i in range(1, 10)) / 9 * 1.5
    assert len({t["theme"] for t in first}) == 2
    assert metric(rows[0])["rating_average"] == 4.9


def test_concurrent_planners_and_commands_have_one_winner(tmp_path):
    app = create_app(Settings(environment="test", studio_legacy_keys_enabled=True, database_url=f"sqlite:///{(tmp_path/'plans.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"), admin_owner_key="o" * 40, admin_analyst_key="a" * 40,
        rate_limit_per_minute=10000, write_limit_per_minute=10000), verifier=FakeVerifier())
    upgrade(app.state.engine)
    try:
        with TestClient(app) as client:
            with app.state.session_factory() as db:
                creator = Player(display_name="Creator")
                db.add(creator); db.commit()
                pid = creator.id
            domain = SimpleNamespace(app=app, factory=app.state.session_factory, client=client, players={"Creator":pid})
            versions = seed(domain, 15)
            def plan(_):
                with app.state.session_factory() as db:
                    changes = ensure_vehicle(db, app.state.verifier.manifest(), "compact", now())
                    db.commit()
                    return changes
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(plan, range(8)))
            assert sum(results) == 5
            week = calendar(domain)["weeks"][0]
            path, body = edit(domain, week, versions[:5])
            def execute(data):
                return client.post(path + "/commands", headers=headers("owner"), json=data)
            with ThreadPoolExecutor(max_workers=8) as pool:
                replies = list(pool.map(execute, [body] * 8))
            assert all(r.status_code == 200 for r in replies)
            assert all(r.json() == replies[0].json() for r in replies)
            week = calendar(domain)["weeks"][1]
            path, first = edit(domain, week, versions[:5])
            _, second = edit(domain, week, versions[5:10])
            with ThreadPoolExecutor(max_workers=2) as pool:
                replies = list(pool.map(execute, [first, second]))
            assert sorted(r.status_code for r in replies) == [200, 409]
            with app.state.session_factory() as db:
                assert db.scalar(select(func.count()).select_from(AdminAudit)) == 2
            saved_calendar = calendar(domain)
            restarted = create_app(app.state.settings, verifier=FakeVerifier())
            try:
                with TestClient(restarted) as new_client:
                    loaded = new_client.get("/v1/admin/rivalry-plans", headers=headers()).json()
                    assert loaded["weeks"] == saved_calendar["weeks"]
                    assert loaded["history"] == saved_calendar["history"]
            finally:
                restarted.state.engine.dispose()
    finally:
        app.state.engine.dispose()
