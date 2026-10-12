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
        environment="development", allow_sync_track_validation=True,
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
        Settings(environment="development", allow_sync_track_validation=True, test_drivers_enabled=True)
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


def test_all_track_history_has_200_distinct_drivers_per_track(tmp_path):
    from bmt_backend.test_population_tool import prepare

    class PopulationAPI:
        url = "https://test.invalid"

        def call(self, method, route, body=None, **kwargs):
            if route == "/dev/test-drivers/fleets":
                return {"fleet": "test-fleet-200", "profiles": [
                    {"subject": profile(200, i, 200, 0.0, 1.0)[0],
                     "traits": profile(200, i, 200, 0.0, 1.0)[2]} for i in range(200)]}
            return {"manifest": {}, "server_now": now(), "tracks": [
                {"version_id": str(i), "content_hash": str(i)} for i in range(27)]}

    args = SimpleNamespace(state=tmp_path / "all.json", command="fleet", count=200,
                           seed=200, vehicle="compact", instant=True,
                           pace_reference=None, all_tracks=True)
    plan = prepare(PopulationAPI(), args)
    assert len(plan["jobs"]) == 5400
    for version in range(27):
        jobs = [j for j in plan["jobs"] if j["version_id"] == str(version)]
        assert len({j["subject"] for j in jobs}) == 200
        assert all(j["group_id"] is None for j in jobs)


def test_best_lap_histogram_includes_all_test_drivers_and_respects_record_reset(drivers):
    from bmt_backend.runs import board_manifest
    from bmt_backend.track_models import OperationState, Run, RunTicket, TrackVersion, digest
    version_id = group(drivers)["tracks"][0]["entry"]["version_id"]
    with drivers.factory() as session:
        pinned = {**board_manifest(session.get(TrackVersion, version_id), "compact"), "test_population": True}
        board_id = digest({"version_id": version_id, **pinned})
        ids = []
        for index in range(100):
            player = Player(display_name=f"Lap driver {index}", is_test_driver=True)
            session.add(player)
            session.flush()
            issued = RunTicket(player_id=player.id, board_id=board_id, expires_at=now()+7200)
            session.add(issued)
            session.flush()
            run = Run(ticket_id=issued.id, player_id=player.id, board_id=board_id, replay_hash="0"*64,
                      status="verified", time_ticks=10000+index*5, lap_ticks=[1, 2000+index, 2100, 2200, 2300],
                      created_at=100, finished_at=101)
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board_id, player_id=player.id, run_id=run.id, time_ticks=run.time_ticks))
            ids.append(player.id)
        # Raw pre-reset history remains stored, but cannot revive its retired PB.
        issued = RunTicket(player_id=ids[0], board_id=board_id, expires_at=now()+7200)
        session.add(issued)
        session.flush()
        session.add(Run(ticket_id=issued.id, player_id=ids[0], board_id=board_id, replay_hash="0"*64,
                        status="verified", time_ticks=10, lap_ticks=[1, 2, 2, 2, 3], created_at=1, finished_at=2))
        session.add(OperationState(id="test-pop-batch:lap-reset", details={"vehicle_id":"compact",
                    "request":{"clear_test_records":True}, "created_at":50, "tracks":[{"version_id":version_id}]}))
        session.commit()
    route = f"/v1/dev/test-drivers/track-versions/{version_id}/histogram?vehicle_id=compact&metric=best_lap&bins=8"
    assert drivers.client.get(route).status_code == 401
    response = drivers.client.get(route, headers=auth(drivers.login))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["metric"] == "best_lap" and data["test_population"] is True
    assert data["population"] == sum(b["count"] for b in data["bins"]) == 100
    assert data["minimum_ticks"] == 2000 and data["maximum_ticks"] == 2099
    assert len(data["bins"]) <= 8
    assert drivers.client.get(f"/v1/boards/{board_id}/histogram?metric=best_lap").status_code == 404
    # Merge real public PBs and test-board PBs, counting a real driver present
    # in both only once and choosing their better comparable race/lap.
    with drivers.factory() as session:
        manifest = board_manifest(session.get(TrackVersion,version_id),"compact")
        public_id = digest({"version_id":version_id,**manifest})
        if session.get(Board,public_id) is None:
            session.add(Board(id=public_id,version_id=version_id,vehicle_id="compact",manifest=manifest))
            session.flush()
        other = Player(display_name="Real comparison driver")
        session.add(other)
        session.flush()
        def add_record(player_id, target_board, ticks, splits):
            ticket = RunTicket(player_id=player_id,board_id=target_board,expires_at=now()+7200)
            session.add(ticket)
            session.flush()
            run = Run(ticket_id=ticket.id,player_id=player_id,board_id=target_board,replay_hash="0"*64,
                      status="verified",time_ticks=ticks,lap_ticks=splits,finished_at=now())
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=target_board,player_id=player_id,run_id=run.id,time_ticks=ticks))
        human = drivers.login["player"]["id"]
        add_record(human,public_id,10500,[2300,1900,2100,2100,2100])
        add_record(human,board_id,9900,[2100,1800,2000,2000,2000])
        add_record(other.id,public_id,10400,[2300,1950,2050,2050,2050])
        session.commit()
    from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics
    refresh_all_for_diagnostics(drivers.app)
    comparison_route = f"/v1/track-versions/{version_id}/results-comparison?vehicle_id=compact&race_ticks=9500&lap_ticks=1900"
    assert drivers.client.get(comparison_route).status_code == 401
    response = drivers.client.get(comparison_route,headers=auth(drivers.login))
    assert response.status_code == 200,response.text
    comparison = response.json()
    assert comparison["population_scope"] == "all"
    for metric in ("race","best_lap"):
        assert comparison[metric]["board_id"] == comparison["board_id"]
        assert comparison[metric]["population"] == 102
        assert sum(bin["count"] for bin in comparison[metric]["bins"]) == 102
        assert comparison[metric]["comparison"]["position"] == 1
        assert comparison[metric]["comparison"]["population"] == 102
    assert comparison["race"]["own_best_ticks"] == 9900
    assert comparison["best_lap"]["own_best_ticks"] == 1800
    assert drivers.client.get(f"/v1/boards/{public_id}").json()["population"] == 2
    drivers.app.state.settings = dataclasses.replace(drivers.app.state.settings, test_drivers_enabled=False)
    assert drivers.client.get(route, headers=auth(drivers.login)).status_code == 404
    refresh_all_for_diagnostics(drivers.app)
    remaining = drivers.client.get(comparison_route,headers=auth(drivers.login)).json()
    assert remaining["population_scope"] == "all" and remaining["race"]["population"] == remaining["best_lap"]["population"] == 2


def test_test_histogram_uses_verified_test_counts_and_stays_private(drivers):
    from bmt_backend.runs import board_manifest
    from bmt_backend.track_models import BoardTimeCount, TrackVersion, digest
    version_id = group(drivers)["tracks"][0]["entry"]["version_id"]
    with drivers.factory() as session:
        pinned = {**board_manifest(session.get(TrackVersion, version_id), "compact"),
                  "test_population": True}
        board_id = digest({"version_id": version_id, **pinned})
        assert session.get(Board, board_id).manifest["test_population"] is True
        session.add(BoardTimeCount(board_id=board_id, time_ticks=5000, all_count=200, public_count=0))
        session.commit()
    route = f"/v1/dev/test-drivers/track-versions/{version_id}/histogram?vehicle_id=compact"
    assert drivers.client.get(route).status_code == 401
    result = drivers.client.get(route, headers=auth(drivers.login))
    assert result.status_code == 200, result.text
    assert result.json()["population"] == 200
    assert sum(b["count"] for b in result.json()["bins"]) == 200
    assert result.json()["test_population"] is True
    assert drivers.client.get(f"/v1/boards/{board_id}/histogram").status_code == 404


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


def test_failed_fast_drive_retries_real_slower_inputs(tmp_path, monkeypatch):
    import bmt_backend.test_population_tool as tool
    from bmt_backend.track_models import digest
    document = {"name": "Tight circuit"}
    manifest = FakeVerifier().manifest()
    profile_data = {"traits": profile(27, 6, 13, 0.42, 0.58)[2]}
    job = {"id": "c" * 64, "slot": 0, "attempt": 0, "version_id": "v", "content_hash": digest(document)}
    plan = {"manifest": manifest, "vehicle_id": "compact", "pace_scales": {}}
    scales = []

    def drive(settings, doc, vehicle, traits, attempt, scale):
        scales.append(scale)
        if scale > 0.7:
            raise tool.DriverDidNotFinish("stalled")
        return {"manifest": manifest, "time_ticks": 12345,
                "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]}, "mistakes": 0}

    class ReadAPI:
        def call(self, *args):
            return document

    monkeypatch.setattr(tool, "generate", drive)
    result = tool.recording(ReadAPI(), plan, job, profile_data, None, tmp_path / "plan.json")
    assert scales == [1.0, 0.85, 0.7]
    assert job["driven_pace_scale"] == 0.7
    assert result["time_ticks"] == 12345
