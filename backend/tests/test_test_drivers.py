"""Development identity isolation, canonical submissions and scheduler recovery."""

import dataclasses
import json
import uuid
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from test_domains import FakeVerifier
from test_rivalry import add_finishes, seed

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry import eligible_versions, skill_score
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.test_driver_models import TestDriverProfile as DriverProfile
from bmt_backend.test_drivers import profile
from bmt_backend.test_population_tool import acquire_plan_lock, atomic_save, schedule, tick
from bmt_backend.track_models import Board, PersonalBest, now
from bmt_backend.worker import process_one

KEY = "artificial-drivers-test-only-" * 3


@pytest.fixture
def drivers(tmp_path):
    settings = Settings(
        environment="development",
        dev_auth_enabled=True,
        dev_auth_key=KEY,
        test_drivers_enabled=True,
        database_url=f"sqlite:///{(tmp_path / 'drivers.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"),
        auth_limit_per_minute=1000,
        write_limit_per_minute=1000,
    )
    app = create_app(settings, verifier=FakeVerifier())
    upgrade(app.state.engine)
    with TestClient(app) as client:
        login = client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": KEY}).json()
        result = SimpleNamespace(
            app=app,
            client=client,
            factory=app.state.session_factory,
            players={"Creator": login["player"]["id"]},
            login=login,
        )
        seed(result)
        yield result
    app.state.engine.dispose()


def auth(login, operator=False):
    return {
        "Authorization": "Bearer " + login["access_token"],
        "Idempotency-Key": str(uuid.uuid4()),
        **({"X-Dev-Auth-Key": KEY} if operator else {}),
    }


def fleet(drivers, count=13, seed_value=27, low=0.42, high=0.58):
    r = drivers.client.post(
        "/v1/dev/test-drivers/fleets",
        json={"seed": seed_value, "count": count, "skill_min": low, "skill_max": high},
        headers={"X-Dev-Auth-Key": KEY},
    )
    assert r.status_code == 200, r.text
    return r.json()


def bot_login(drivers, p):
    r = drivers.client.post(
        "/v1/auth/development",
        json={"subject": p["subject"], "display_name": p["display_name"]},
        headers={"X-Dev-Auth-Key": KEY},
    )
    assert r.status_code == 200, r.text
    return r.json()


def group(drivers, test=True, login=None):
    r = drivers.client.post(
        "/v1/rivalry/join",
        json={"vehicle_id": "compact", "test_population": test},
        headers=auth(login or drivers.login),
    )
    assert r.status_code == 200, r.text
    return r.json()


def test_explicit_gate_and_disabled_existing_sessions(drivers):
    with pytest.raises(ValueError):
        Settings(test_drivers_enabled=True)
    with pytest.raises(ValueError):
        Settings(environment="development", test_drivers_enabled=True)
    p = fleet(drivers)["profiles"][0]
    login = bot_login(drivers, p)
    assert login["player"]["is_test_driver"] is True
    assert drivers.client.get("/v1/bootstrap").json()["test_drivers"] is True
    assert (
        drivers.client.get(
            "/v1/dev/test-drivers/fleets/test-fleet-27", headers={"X-Dev-Auth-Key": "wrong"}
        ).status_code
        == 401
    )
    drivers.app.state.settings = dataclasses.replace(drivers.app.state.settings, test_drivers_enabled=False)
    assert drivers.client.get("/v1/me", headers=auth(login)).status_code == 401
    assert (
        drivers.client.post("/v1/auth/refresh", json={"refresh_token": login["refresh_token"]}).status_code
        == 401
    )
    assert (
        drivers.client.get(
            "/v1/dev/test-drivers/fleets/test-fleet-27", headers={"X-Dev-Auth-Key": KEY}
        ).status_code
        == 404
    )
    assert (
        drivers.client.get(
            "/v1/rivalry/current?vehicle_id=compact&test_population=true", headers=auth(drivers.login)
        ).status_code
        == 404
    )
    assert drivers.client.get("/v1/me", headers=auth(drivers.login)).status_code == 200


def test_persistent_profiles_fleet_bounds_and_identity_reservation(drivers):
    first = fleet(drivers, 150, 88, 0.0, 1.0)
    assert first == fleet(drivers, 150, 88, 0.0, 1.0)
    skills = [p["traits"]["skill"] for p in first["profiles"]]
    assert skills == sorted(skills) and skills[0] < 0.01 and skills[-1] > 0.99
    assert len({p["traits"]["seed"] for p in first["profiles"]}) == 150
    assert len({p["traits"]["utc_hour"] for p in first["profiles"]}) > 20
    changed = drivers.client.post(
        "/v1/dev/test-drivers/fleets", json={"seed": 88, "count": 151}, headers={"X-Dev-Auth-Key": KEY}
    )
    assert changed.status_code == 409
    with drivers.factory() as s:
        assert len(s.scalars(select(DriverProfile)).all()) == 150
    reserved = drivers.client.post(
        "/v1/auth/development",
        json={"subject": "bmt-test-900-1", "display_name": "Pretend"},
        headers={"X-Dev-Auth-Key": KEY},
    )
    assert reserved.status_code == 403


def test_test_group_isolated_fill_and_normal_scope_rejected(drivers):
    f = fleet(drivers)
    real, test = group(drivers, False), group(drivers)
    assert real["group_id"] != test["group_id"] and test["test_population"]
    for _ in range(2):
        response = drivers.client.post(
            f"/v1/dev/test-drivers/fleets/{f['fleet']}/fill",
            json={"group_id": test["group_id"], "total_drivers": 14},
            headers=auth(drivers.login, True),
        )
        assert response.status_code == 200, response.text
        assert response.json()["driver_count"] == 14
        assert sum(p["is_test_driver"] for p in response.json()["standings"]) == 13
    with drivers.factory() as s:
        assert s.get(RivalryGroup, test["group_id"]).member_count == 14
        assert (
            len(s.scalars(select(RivalryMember).where(RivalryMember.group_id == test["group_id"])).all())
            == 14
        )
    denied = drivers.client.post(
        f"/v1/dev/test-drivers/fleets/{f['fleet']}/fill",
        json={"group_id": real["group_id"]},
        headers=auth(drivers.login, True),
    )
    assert denied.status_code == 403
    bot = bot_login(drivers, f["profiles"][0])
    assert (
        drivers.client.post("/v1/rivalry/join", json={"vehicle_id": "compact"}, headers=auth(bot)).status_code
        == 403
    )
    version_id = real["tracks"][0]["entry"]["version_id"]
    assert (
        drivers.client.post(
            "/v1/run-tickets", json={"version_id": version_id, "vehicle_id": "compact"}, headers=auth(bot)
        ).status_code
        == 403
    )
    assert (
        drivers.client.put(
            f"/v1/track-versions/{version_id}/rating", json={"score": 5}, headers=auth(bot)
        ).status_code
        == 403
    )
    assert drivers.client.get(f"/v1/boards/{test['tracks'][0]['board_id']}").status_code == 404
    current = drivers.client.get("/v1/rivalry/current?vehicle_id=compact", headers=auth(drivers.login)).json()
    assert current["group_id"] == real["group_id"] and not current["test_population"]


def test_weekly_scores_require_verified_upload_and_public_board_stays_empty(drivers):
    f, test = fleet(drivers), group(drivers)
    drivers.client.post(
        f"/v1/dev/test-drivers/fleets/{f['fleet']}/fill",
        json={"group_id": test["group_id"]},
        headers=auth(drivers.login, True),
    )
    bot = bot_login(drivers, f["profiles"][0])
    r = drivers.client.post(f"/v1/rivalry/{test['group_id']}/tickets", json={"slot": 0}, headers=auth(bot))
    assert r.status_code == 201
    ticket = r.json()
    assert ticket["manifest"]["test_population"] is True and ticket["manifest"]["laps"] == 5
    body = {
        "ticket_id": ticket["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 166, 0]] * 30},
    }
    h = auth(bot)
    first = drivers.client.post("/v1/runs", json=body, headers=h)
    assert first.status_code == 202
    assert first.json() == drivers.client.post("/v1/runs", json=body, headers=h).json()
    assert (
        drivers.client.get(f"/v1/rivalry/{test['group_id']}", headers=auth(drivers.login)).json()[
            "standings"
        ][0]["points"]
        == 0
    )
    assert process_one(drivers.app)
    result = drivers.client.get(f"/v1/rivalry/tickets/{ticket['ticket_id']}/result", headers=auth(bot)).json()
    assert result["status"] == "verified" and result["outcome"]["points_delta"] == 30
    with drivers.factory() as s:
        assert len(s.scalars(select(PersonalBest)).all()) == 1
        assert s.get(Board, ticket["board_id"]).manifest["test_population"] is True
    public = drivers.client.get(
        f"/v1/track-versions/{ticket['version_id']}/leaderboard?vehicle_id=compact"
    ).json()
    assert public["population"] == 0
    human_ticket = drivers.client.post(
        "/v1/run-tickets",
        json={"version_id": ticket["version_id"], "vehicle_id": "compact", "test_population": True},
        headers=auth(drivers.login),
    ).json()
    drivers.client.post(
        "/v1/runs", json={**body, "ticket_id": human_ticket["ticket_id"]}, headers=auth(drivers.login)
    )
    assert process_one(drivers.app)
    assert (
        drivers.client.get(
            f"/v1/track-versions/{ticket['version_id']}/rating", headers=auth(drivers.login)
        ).json()["eligible"]
        is False
    )


def test_artificial_legacy_pbs_do_not_inflate_popularity_or_skill(drivers):
    versions = seed(drivers, 3, official=False)
    players = add_finishes(drivers, versions[0], 101)
    for version in versions[1:]:
        add_finishes(drivers, version, 101, same_players=players)
    active = drivers.app.state.verifier.manifest()
    with drivers.factory() as s:
        for pid in players:
            s.get(Player, pid).is_test_driver = True
        s.commit()
        assert all(v.id not in versions for v in eligible_versions(s, active, "compact"))
        assert skill_score(s, players[0], "compact", active, now()) is None
        board = s.scalar(select(Board).where(Board.version_id == versions[0]))
    assert drivers.client.get(f"/v1/boards/{board.id}").json()["population"] == 0


def test_schedule_is_seeded_varied_bounded_and_immediate_first_attempt():
    start, end = 1790553600, 1790553600 + 604800
    schedules = []
    for i in range(150):
        traits = profile(88, i, 150, 0.0, 1.0)[2]
        a = schedule(traits, start, end)
        assert a == schedule(traits, start, end) and 1 <= len(a) <= 5
        assert all(start <= stamp < end for stamp in a)
        assert schedule(traits, start, end, True)[0] == start
        schedules.append(tuple(a))
    assert len(set(schedules)) > 140


def test_large_test_field_uses_verified_percentiles_for_matching(drivers):
    profiles = fleet(drivers, 150, 88, 0.0, 1.0)["profiles"]
    ids = [p["player_id"] for p in profiles]
    versions = seed(drivers, 3)
    for version in versions:
        add_finishes(drivers, version, 150, same_players=ids)
    active = drivers.app.state.verifier.manifest()
    with drivers.factory() as s:
        for board in s.scalars(select(Board).where(Board.version_id.in_(versions))):
            board.manifest = {**board.manifest, "test_population": True}
        s.commit()
        assert skill_score(s, ids[0], "compact", active, now(), True) == 1000
        assert skill_score(s, ids[149], "compact", active, now(), True) == 0
        assert skill_score(s, ids[75], "compact", active, now(), True) == 497
        assert skill_score(s, ids[0], "compact", active, now()) is None
    fastest = group(drivers, login=bot_login(drivers, profiles[0]))
    neighbor = group(drivers, login=bot_login(drivers, profiles[1]))
    middle = group(drivers, login=bot_login(drivers, profiles[75]))
    assert fastest["group_id"] == neighbor["group_id"] and not fastest["placement"]
    assert fastest["group_id"] != middle["group_id"]


def test_scheduler_recovers_upload_after_crash_and_does_not_duplicate(tmp_path, monkeypatch):
    import bmt_backend.test_population_tool as tool

    verifier = FakeVerifier()
    manifest = verifier.manifest()
    p = {"subject": "bmt-test-1-0", "traits": profile(1, 0, 1, 0.5, 0.5)[2]}
    job = {
        "id": "a" * 64,
        "subject": p["subject"],
        "slot": 0,
        "version_id": "v",
        "content_hash": "x",
        "attempt": 0,
        "due": 0,
        "group_id": "g",
        "status": "waiting",
        "ticket": {"ticket_id": "t", "expires_at": 9999},
    }
    plan = {
        "manifest": manifest,
        "profiles": [p],
        "jobs": [job],
        "mode": "fill",
        "ends_at": 9999,
        "vehicle_id": "compact",
        "pace_scales": {},
    }
    path = tmp_path / "plan.json"
    atomic_save(path, plan)
    monkeypatch.setattr(
        tool,
        "recording",
        lambda *a: {
            "replay": {"schema": "bmt-replay-v1", "frames": [[0, 166, 0]]},
            "time_ticks": 5,
            "mistakes": 0,
        },
    )

    class FakeAPI:
        def __init__(self):
            self.crash = True
            self.writes = set()

        def call(self, method, route, body=None, subject=None, idempotency=None, operator=False):
            if route.startswith("/dev/"):
                return {"manifest": manifest, "server_now": 100}
            if route == "/runs":
                self.writes.add(idempotency)
                if self.crash:
                    self.crash = False
                    raise RuntimeError("Connection lost after committed upload")
                return {"run_id": "r"}
            if route == "/runs/r":
                return {"status": "verified", "time_ticks": 5, "failure_code": None}
            raise AssertionError(route)

    api = FakeAPI()
    with pytest.raises(RuntimeError):
        tick(api, plan, None, path)
    recovered = json.loads(path.read_text())
    tick(api, recovered, None, path)
    tick(api, recovered, None, path)
    assert len(api.writes) == 1 and recovered["jobs"][0]["status"] == "verified"


def test_plan_lock_prevents_concurrent_writers_and_releases_on_close(tmp_path):
    path = tmp_path / "population.json"
    first = acquire_plan_lock(path)
    try:
        with pytest.raises(RuntimeError, match="Another scheduler"):
            acquire_plan_lock(path)
    finally:
        first.close()
    acquire_plan_lock(path).close()


def test_versioned_profile_golden_fixture():
    fixture = json.loads((Path(__file__).parent / "fixtures/test_driver_profile_v1.json").read_text())
    subject, name, traits = profile(**fixture["parameters"])
    assert (subject, name, traits) == (fixture["subject"], fixture["display_name"], fixture["traits"])


def test_pace_calibration_drives_inputs_instead_of_rewriting_result(tmp_path, monkeypatch):
    import bmt_backend.test_population_tool as tool
    from bmt_backend.track_models import digest

    manifest = FakeVerifier().manifest()
    document = {"name": "Test circuit"}
    p = {"traits": profile(27, 6, 13, 0.42, 0.58)[2]}
    job = {"id": "b" * 64, "slot": 0, "attempt": 0, "version_id": "v", "content_hash": digest(document)}
    plan = {"manifest": manifest, "vehicle_id": "compact", "pace_scales": {}, "pace_reference": {"v": 10000}}
    scales = []

    def drive(settings, doc, vehicle, traits, attempt, scale):
        scales.append(scale)
        return {
            "manifest": manifest,
            "time_ticks": round(13000 / scale),
            "replay": {"frames": [[0, 166, 0]], "schema": "bmt-replay-v1"},
            "mistakes": 0,
        }

    class ReadAPI:
        def call(self, *args):
            return document

    monkeypatch.setattr(tool, "generate", drive)
    r = tool.recording(ReadAPI(), plan, job, p, None, tmp_path / "plan.json")
    assert len(scales) == 7 and abs(r["time_ticks"] - 10000) <= 200
    assert r["time_ticks"] == round(13000 / scales[-1])
    assert plan["calibration"]["v"]["relative_error"] < 0.02
