"""Real HTTP, durable policy/assignment/observation and recovery contracts."""
from copy import deepcopy
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import func, select

from bmt_backend.game_config import activate_schedules
from bmt_backend.game_config_models import GameConfigDelivery
from bmt_backend.game_config_observations import project
from bmt_backend.game_config_policy import DEFAULTS, bucket
from bmt_backend.studio_platform_models import StudioAssignment
from bmt_backend.track_models import now

OWNER = {"Authorization": "Bearer " + "o" * 40}
ANALYST = {"Authorization": "Bearer " + "a" * 40}
CONTEXT = "?platform=android&build_id=config-test&capabilities=ad_policy_v1,menu_policy_v1"


@pytest.fixture
def configured(auth_app, auth_client, sign_in):
    auth_app.state.settings = replace(auth_app.state.settings, environment="test",
        admin_owner_key="o" * 40, admin_analyst_key="a" * 40, telemetry_enabled=True)
    signed = sign_in("config-player")
    return auth_app, auth_client, signed["player"]["id"], {"Authorization": "Bearer " + signed["access_token"]}


def command(revision=0, **extra):
    return dict(command_id=str(uuid4()), expected_revision=revision, reason="Exercise configuration contract", **extra)


def checked(response):
    assert response.status_code == 200, response.text
    return response.json()


def draft(client, policy=None, audiences=None):
    state = checked(client.get("/v1/admin/game-config", headers=OWNER))
    row = checked(client.post("/v1/admin/game-config/drafts", headers=OWNER,
        json=command(state["revision"], name="Test policy")))
    return checked(client.post("/v1/admin/game-config/drafts/" + row["id"] + "/edit", headers=OWNER,
        json=command(row["revision"], policy=policy or deepcopy(DEFAULTS), audiences=audiences or [])))


def publish(client, row, **extra):
    return checked(client.post("/v1/admin/game-config/drafts/" + row["id"] + "/publish", headers=OWNER,
        json=command(row["revision"], **extra)))


def test_safe_default_negotiation_privacy_and_conditional_response(configured):
    app, client, player, auth = configured
    assert checked(client.get("/v1/bootstrap"))["game_configuration_version"] == 1
    result = client.get("/v1/game-config" + CONTEXT, headers=auth)
    body = checked(result)
    assert body["scope"] == player and body["settings"] == DEFAULTS
    assert "sources" not in body and not body["settings"]["ads.permitted"]
    assert result.headers["cache-control"] == "private, no-store"
    assert client.get("/v1/game-config" + CONTEXT, headers={**auth, "If-None-Match": result.headers["etag"]}).status_code == 304
    assert client.get("/v1/game-config" + CONTEXT, headers={"Authorization": "Bearer invalid"}).status_code == 401
    assert checked(client.get("/v1/game-config" + CONTEXT))["scope"] == "guest"
    assert client.get("/v1/admin/game-config").status_code == 401
    assert client.post("/v1/admin/game-config/emergency", headers=ANALYST,
        json=command(restrictions={})).status_code == 403
    assert activate_schedules(app.state.session_factory) == 0


def test_draft_validation_publish_retry_and_stale_writer(configured):
    _, client, _, auth = configured
    policy = {**deepcopy(DEFAULTS), "ads.permitted": True, "ads.interstitial_enabled": True, "ads.trigger": "both", "ads.races": 4}
    row = draft(client, policy)
    url = "/v1/admin/game-config/drafts/" + row["id"]
    assert checked(client.post(url + "/validate", headers=ANALYST, json={}))['valid']
    body = command(row["revision"])
    first = checked(client.post(url + "/publish", headers=OWNER, json=body))
    assert checked(client.post(url + "/publish", headers=OWNER, json=body)) == first
    assert client.post(url + "/publish", headers=OWNER, json={**body, "reason": "Changed payload"}).status_code == 409
    assert client.post(url + "/publish", headers=OWNER, json=command(row["revision"])).status_code == 409
    assert checked(client.get("/v1/game-config" + CONTEXT, headers=auth))["settings"]["ads.races"] == 4
    assert not checked(client.get("/v1/game-config", headers=auth))["settings"]["ads.permitted"]
    invalid = {**policy, "physics.grip": 2}
    assert client.post(url + "/edit", headers=OWNER, json=command(row["revision"], policy=invalid)).status_code == 422
    assert client.post(url + "/edit", headers=OWNER, json=command(row["revision"], policy={**policy, "ads.races": True})).status_code == 422


def test_audience_overlap_and_preview_has_no_assignments(configured):
    app, client, player, _ = configured
    audience = {"name": "Android", "priority": 10, "conditions": {"platforms": ["android"]}, "settings": {"ads.races": 7}}
    row = draft(client, audiences=[audience])
    result = checked(client.post("/v1/admin/game-config/preview", headers=ANALYST,
        json={"draft_id": row["id"], "player_id": player}))
    assert result["settings"]["ads.races"] == 7 and result["sources"]["ads.races"] == "Android"
    duplicate = {**audience, "name": "Overlapping"}
    assert client.post("/v1/admin/game-config/drafts/" + row["id"] + "/edit", headers=OWNER,
        json=command(row["revision"], policy=DEFAULTS, audiences=[audience, duplicate])).status_code == 422
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(StudioAssignment)) == 0


def test_rollout_internal_hold_advance_and_restrictive_restore(configured):
    _, client, player, auth = configured
    row = draft(client, {**deepcopy(DEFAULTS), "ads.permitted": True, "ads.interstitial_enabled": True})
    first = publish(client, row, rollout=0, internal_players=[player])
    assert checked(client.get("/v1/game-config" + CONTEXT, headers=auth))["settings"]["ads.permitted"]
    assert not checked(client.get("/v1/game-config" + CONTEXT))["settings"]["ads.permitted"]
    paused = checked(client.post(f"/v1/admin/game-config/releases/{first['release']['generation']}/pause",
        headers=OWNER, json=command(first["revision"])))
    assert paused["release"]["state"] == "paused"
    advanced = checked(client.post(f"/v1/admin/game-config/releases/{first['release']['generation']}/advance",
        headers=OWNER, json=command(paused["revision"])))
    assert advanced["release"]["rollout"] == 500
    killed = checked(client.post("/v1/admin/game-config/emergency", headers=OWNER,
        json=command(advanced["revision"], restrictions={"ads.permitted": False})))
    restored = checked(client.post("/v1/admin/game-config/restore", headers=OWNER,
        json=command(killed["revision"], generation=first["release"]["generation"])))
    assert restored["release"]["generation"] > advanced["release"]["generation"]
    assert not checked(client.get("/v1/game-config" + CONTEXT, headers=auth))["settings"]["ads.permitted"]
    assert checked(client.get("/v1/game-config/emergency"))["restrictions"] == {"ads.permitted": False}


def test_schedule_revalidation(configured):
    app, client, _, _ = configured
    at = now() + 60
    row = draft(client)
    scheduled = publish(client, row, scheduled_at=at)
    assert scheduled["release"]["state"] == "scheduled"
    assert activate_schedules(app.state.session_factory, at=at - 1) == 0
    assert activate_schedules(app.state.session_factory, at=at) == 1
    assert checked(client.get("/v1/admin/game-config", headers=OWNER))["active"]["generation"] == scheduled["release"]["generation"]
    future = publish(client, draft(client), scheduled_at=at + 60)
    publish(client, draft(client, {**deepcopy(DEFAULTS), "ads.races": 8}))
    assert activate_schedules(app.state.session_factory, at=at + 60) == 1
    history = checked(client.get("/v1/admin/game-config", headers=OWNER))["history"]
    assert next(r for r in history if r["generation"] == future["release"]["generation"])["state"] == "blocked"


def test_configuration_ab_assignment_exposure_pause_and_comparative_results(configured):
    app, client, player, auth = configured
    publish(client, draft(client, {**deepcopy(DEFAULTS), "ads.permitted": True, "ads.interstitial_enabled": True}))
    generation = checked(client.get("/v1/admin/game-config", headers=OWNER))["active"]["generation"]
    experiment = checked(client.post("/v1/admin/experiments", headers=OWNER, json={"command_id": str(uuid4()),
        "name": "Ad spacing A/B", "reason": "Compare retention at fixed horizon", "allocation": {"control": 5000, "variant": 5000},
        "variants": {"control": {"ads.races": 3}, "variant": {"ads.races": 5}},
        "configuration": {"hypothesis": "Longer spacing improves returns", "layer": "ads", "control": "control",
            "enrollment": 10000, "audience": {"platforms": ["android"]}, "baseline_generation": generation}}))
    url = "/v1/admin/experiments/" + experiment["id"]
    active = checked(client.post(url + "/state", headers=OWNER, json={**command(), "state": "active"}))
    before = checked(client.get("/v1/game-config" + CONTEXT, headers=auth))
    assert before["assignment_refresh_required"] and not before["assignments"]
    bound = checked(client.post("/v1/experiments/assignments" + CONTEXT, headers=auth, json={}))['items'][0]
    assert checked(client.post("/v1/experiments/assignments" + CONTEXT, headers=auth, json={}))['items'][0] == bound
    resolved = checked(client.get("/v1/game-config" + CONTEXT, headers=auth))
    assert resolved["settings"]["ads.races"] == (3 if bound["variant"] == "control" else 5)
    with app.state.session_factory() as db:
        assignment = db.get(StudioAssignment, (experiment["id"], player))
        assert assignment.exposed_at is None
        props = {"config_generation": generation, "config_resolution": resolved["resolution_id"],
            "experiment_id": experiment["id"], "variant": bound["variant"], "experiment_revision": bound["revision"]}
        from types import SimpleNamespace
        exposed = SimpleNamespace(source="client", name="experiment_exposed", properties=props,
            player_id=player, occurred_at=now(), id=str(uuid4()))
        project(db, [exposed])
        assert assignment.exposed_at is not None
        project(db, [SimpleNamespace(**{**exposed.__dict__, "name": "ad_policy_decision",
            "properties": {**props, "ad_outcome": "shown"}})])
        project(db, [SimpleNamespace(**{**exposed.__dict__, "name": "config_applied", "platform": "android", "build_id": "config-test"})])
        db.commit()
        assert db.get(GameConfigDelivery, player).status == "applied"
    score = checked(client.get(url + "/scorecard", headers=ANALYST))
    assert sum(v["assigned"] for v in score["variants"]) == 1
    assert sum(v["exposed"] for v in score["variants"]) == 1
    assert sum(v["ad_observations"]["shown"] for v in score["variants"]) == 1
    assert score["winner"] is None and not score["enough_mature_players"]
    changed = draft(client, {**deepcopy(DEFAULTS), "ads.races": 8})
    assert client.post("/v1/admin/game-config/drafts/" + changed["id"] + "/publish", headers=OWNER,
        json=command(changed["revision"])).status_code == 409
    checked(client.post(url + "/state", headers=OWNER, json={**command(active["revision"]), "state": "paused"}))
    assert not checked(client.get("/v1/game-config" + CONTEXT, headers=auth))["assignments"]


def test_nested_bucket_is_stable():
    subjects = [str(uuid4()) for _ in range(100)]
    narrow = {s for s in subjects if bucket(s, "same release") < 500}
    wide = {s for s in subjects if bucket(s, "same release") < 2500}
    assert narrow <= wide


def test_private_resolution_protects_owned_access_without_creating_balances(configured):
    from bmt_backend.commerce_models import Entitlements
    app, client, player, auth = configured
    publish(client, draft(client, {**DEFAULTS, "ads.permitted": True, "ads.interstitial_enabled": True}))
    with app.state.session_factory() as db:
        assert db.get(Entitlements, player) is None
    checked(client.get("/v1/game-config"+CONTEXT, headers=auth))
    with app.state.session_factory() as db:
        assert db.get(Entitlements, player) is None
        db.add(Entitlements(player_id=player, forever=True))
        db.commit()
    owned = checked(client.get("/v1/game-config"+CONTEXT, headers=auth))
    assert not owned["settings"]["ads.interstitial_enabled"]
    assert "ad_free_entitlement" in owned["restrictions"]


def test_four_variants_require_measurement_and_one_exposure_boundary(configured):
    app, client, _, _ = configured
    payload = {"command_id": str(uuid4()), "name": "Four-arm A/A delivery check", "reason": "Validate assignment pipeline",
        "allocation": {k: 2500 for k in ("control", "b", "c", "d")},
        "variants": {k: {"ads.races": 3} for k in ("control", "b", "c", "d")},
        "configuration": {"baseline_generation": 0, "control": "control", "layer": "ads", "enrollment": 10000}}
    row = checked(client.post("/v1/admin/experiments", headers=OWNER, json=payload))
    app.state.settings = replace(app.state.settings, telemetry_enabled=False)
    assert client.post("/v1/admin/experiments/"+row["id"]+"/state", headers=OWNER,
        json={**command(), "state": "active"}).status_code == 409
    app.state.settings = replace(app.state.settings, telemetry_enabled=True)
    active = checked(client.post("/v1/admin/experiments/"+row["id"]+"/state", headers=OWNER,
        json={**command(), "state": "active"}))
    assert active["state"] == "active" and len(active["variants"]) == 4
    incompatible = {**payload, "command_id": str(uuid4()), "variants": {k: {"notice.message": "Welcome", "store_order": DEFAULTS["store_order"]} for k in payload["variants"]},
        "configuration": {"baseline_generation": 0, "control": "control", "layer": "presentation", "enrollment": 10000}}
    assert client.post("/v1/admin/experiments", headers=OWNER, json=incompatible).status_code == 422


def test_promotion_is_atomic_retry_safe_and_requires_reviewed_publication(configured):
    _, client, _, _ = configured
    payload = {"command_id": str(uuid4()), "name": "Ad spacing comparison", "reason": "Compare fixed horizon",
        "allocation": {"control": 5000, "variant": 5000},
        "variants": {"control": {"ads.races": 3}, "variant": {"ads.races": 7}},
        "configuration": {"baseline_generation": 0, "control": "control", "layer": "ads"}}
    row = checked(client.post("/v1/admin/experiments", headers=OWNER, json=payload))
    active = checked(client.post("/v1/admin/experiments/"+row["id"]+"/state", headers=OWNER,
        json={**command(), "state": "active"}))
    body = {**command(active["revision"]), "variant": "variant"}
    path = "/v1/admin/experiments/"+row["id"]+"/promote"
    promoted = checked(client.post(path, headers=OWNER, json=body))
    assert checked(client.post(path, headers=OWNER, json=body)) == promoted
    assert promoted["policy"]["ads.races"] == 7
    state = checked(client.get("/v1/admin/game-config", headers=OWNER))
    assert state["active"]["generation"] == 0 and state["active"]["policy"]["ads.races"] == 3
    assert checked(client.get("/v1/admin/experiments", headers=OWNER))["items"][0]["state"] == "paused"


def test_client_opt_out_and_unsupported_build_cannot_receive_variant(configured):
    _, client, _, auth = configured
    row = checked(client.post("/v1/admin/experiments", headers=OWNER, json={"command_id": str(uuid4()),
        "name": "Android ad comparison", "reason": "Restrict to implemented clients", "allocation": {"control": 5000, "variant": 5000},
        "variants": {"control": {"ads.races": 3}, "variant": {"ads.races": 7}},
        "configuration": {"baseline_generation": 0, "control": "control", "layer": "ads",
            "audience": {"platforms": ["android"], "builds": ["supported-build"]}}}))
    checked(client.post("/v1/admin/experiments/"+row["id"]+"/state", headers=OWNER,
        json={**command(), "state": "active"}))
    unsupported = checked(client.post("/v1/experiments/assignments"+CONTEXT, headers=auth, json={}))
    assert not unsupported["items"]
    query = "?platform=android&build_id=supported-build&capabilities=ad_policy_v1"
    checked(client.post("/v1/experiments/assignments"+query, headers=auth, json={}))
    assert checked(client.get("/v1/game-config"+query, headers=auth))["assignments"]
    assert not checked(client.get("/v1/game-config"+query+"&experiments_enabled=false", headers=auth))["assignments"]


def test_normal_product_events_keep_valid_configuration_attribution():
    from bmt_backend.telemetry import properties
    context = {"config_generation": 4, "config_resolution": "a"*64, "config_group": "ads",
        "experiment_id": str(uuid4()), "variant": "control", "experiment_revision": 1}
    assert properties("race_started", context) == context
    assert properties("offer_exposed", {"product_id": "ad_free_month", **context}) == {"product_id": "ad_free_month", **context}
    with pytest.raises(ValueError):
        properties("race_started", {**context, "config_generation": True})
    with pytest.raises(ValueError):
        properties("race_started", {k: v for k, v in context.items() if k != "variant"})


def test_public_configuration_and_assignments_survive_workload_separation(tmp_path):
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    for workload in ("api", "admin"):
        app = create_app(Settings(environment="production", workload_role=workload,
            database_url="sqlite://", object_dir=str(tmp_path / workload)))
        paths = app.openapi()["paths"]
        assert ("/v1/game-config" in paths) is (workload == "api")
        assert ("/v1/experiments/assignments" in paths) is (workload == "api")
        assert ("/v1/admin/game-config" in paths) is (workload == "admin")
        app.state.studio_reporting.close()
        app.state.engine.dispose()
