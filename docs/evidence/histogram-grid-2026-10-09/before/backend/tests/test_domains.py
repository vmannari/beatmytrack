"""Domain contracts; canonical-engine integration is tested separately."""

from __future__ import annotations

import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.security import current_player
from bmt_backend.track_models import PersonalBest, Run, RunTicket, TrackVersion, now
from bmt_backend.verifier import VerificationError
from bmt_backend.worker import process_one


class FakeVerifier:
    def manifest(self):
        return {
            "engine_version": "test-engine",
            "verifier_version": "canonical-verifier-1",
            "rules_key": "rules-v10",
            "physics_version": "physics-test",
            "compiler_version": "compiler-test",
            "track_schema": "creator-track-v5",
            "replay_schema": "bmt-replay-v1",
            "tick_rate": 120,
            "laps": 5,
            "max_frames": 216000,
            "vehicles": {"compact": {"handling_version": "handling-test", "config_hash": "abc"}},
        }

    def validate_track(self, document):
        if document.get("invalid"):
            raise VerificationError("Invalid test track")
        return {
            **self.manifest(),
            "track_content_hash": str(document.get("shape", "oval")),
            "route_length": 220.0,
        }

    def verify_run(self, document, replay, vehicle_id, *, creator_test=False):
        if replay["frames"][0][0] == -127:
            raise VerificationError("Incomplete race")
        if replay["frames"][0][0] == -126:
            raise RuntimeError("Verifier unavailable")
        return {
            "time_ticks": len(replay["frames"]) * (1 if creator_test else 5),
            "lap_ticks": [len(replay["frames"])] * (1 if creator_test else 5),
            "manifest": self.validate_track(document),
        }


@pytest.fixture(params=["sqlite", "postgres"])
def domain(tmp_path, request):
    database_url = "sqlite://"
    engine, admin_engine, schema = None, None, None
    if request.param == "postgres":
        database_url = os.environ.get("BMT_TEST_DATABASE_URL")
        local_settings = Path(__file__).resolve().parents[2] / ".tools" / "backend-postgres.env"
        if not database_url and local_settings.is_file():
            for line in local_settings.read_text().splitlines():
                if line.startswith("BMT_TEST_DATABASE_URL="):
                    database_url = line.split("=", 1)[1].strip()
        if not database_url:
            pytest.skip("Set BMT_TEST_DATABASE_URL to a disposable PostgreSQL database")
        schema = "test_domains_" + uuid.uuid4().hex
        admin_engine = create_engine(database_url, connect_args={"connect_timeout": 5})
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(f"CREATE SCHEMA {schema}")
        engine = create_engine(
            database_url,
            connect_args={
                "connect_timeout": 5,
                "options": f"-c search_path={schema} -c statement_timeout=15000",
            },
        )
    settings = Settings(
        environment="test", allow_sync_track_validation=True,
        database_url=database_url,
        object_dir=str(tmp_path / "objects"),
        rate_limit_per_minute=10000,
        write_limit_per_minute=10000,
    )
    app = create_app(settings, verifier=FakeVerifier(), engine=engine)
    upgrade(app.state.engine)
    factory = app.state.session_factory
    players = {}
    with factory() as session:
        for name in ("Creator", "Alice", "Bob", "Carol"):
            player = Player(display_name=name)
            session.add(player)
            session.flush()
            players[name] = player.id
        session.commit()

    def fake_player(request: Request):
        with factory() as session:
            player = session.get(Player, request.headers.get("x-test-player", ""))
            if player is None or player.disabled:
                raise HTTPException(401, "Test auth required")
            session.expunge(player)
            return player

    app.dependency_overrides[current_player] = fake_player
    with TestClient(app) as client:
        yield SimpleNamespace(
            app=app, client=client, factory=factory, players=players, postgres=request.param == "postgres"
        )
    app.state.engine.dispose()
    if admin_engine:
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(f"DROP SCHEMA {schema} CASCADE")
        admin_engine.dispose()


def headers(domain, player="Creator", key=None):
    return {"x-test-player": domain.players[player], "Idempotency-Key": key or str(uuid.uuid4())}


def upload(domain, player="Creator", key=None, document=None):
    result = domain.client.post(
        "/v1/tracks",
        json={"name": "Loop", "document": document or {"shape": "oval"}},
        headers=headers(domain, player, key),
    )
    assert result.status_code == 201, result.text
    return result.json()


def ticket(domain, version, player="Creator"):
    response = domain.client.post(
        "/v1/run-tickets",
        json={"version_id": version["version_id"], "vehicle_id": "compact"},
        headers=headers(domain, player),
    )
    assert response.status_code == 201, response.text
    return response.json()


def submit(domain, issued, player="Creator", frames=20, steering=0, key=None):
    response = domain.client.post(
        "/v1/runs",
        json={
            "ticket_id": issued["ticket_id"],
            "replay": {"schema": "bmt-replay-v1", "frames": [[steering, 255, 0]] * frames},
        },
        headers=headers(domain, player, key),
    )
    assert response.status_code == 202, response.text
    return response.json()


def race(domain, version, player="Creator", frames=20):
    issued = ticket(domain, version, player)
    submitted = submit(domain, issued, player, frames)
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/runs/{submitted['run_id']}", headers=headers(domain, player)).json()
    assert result["status"] == "verified", result
    return result


def publish(domain, version):
    response = domain.client.post(
        f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain)
    )
    assert response.status_code == 200, response.text
    return response.json()


def public_course(domain):
    version = upload(domain)
    result = race(domain, version, frames=60)
    publish(domain, version)
    return version, result["board_id"]


def test_upload_is_idempotent_and_documents_are_immutable(domain):
    version = upload(domain, key="same-upload")
    assert upload(domain, key="same-upload") == version
    conflict = domain.client.post(
        "/v1/tracks",
        json={"name": "Changed", "document": {"shape": "oval"}},
        headers=headers(domain, key="same-upload"),
    )
    assert conflict.status_code == 409
    race(domain, version)
    publish(domain, version)
    changed = domain.client.post(
        f"/v1/tracks/{version['track_id']}/versions",
        json={"name": "Loop 2", "document": {"shape": "figure8"}},
        headers=headers(domain),
    )
    assert changed.status_code == 201
    assert changed.json()["version"] == 2
    assert changed.json()["content_hash"] != version["content_hash"]
    assert domain.client.get(f"/v1/track-versions/{version['version_id']}/document").json() == {
        "shape": "oval",
        "creator": "Creator",
    }
    assert (
        domain.client.put(f"/v1/track-versions/{version['version_id']}", json={"document": {}}).status_code
        == 405
    )


def test_private_drafts_require_ownership_and_verified_creator_test(domain):
    version = upload(domain)
    assert domain.client.get(f"/v1/track-versions/{version['version_id']}").status_code == 404
    assert (
        domain.client.get(
            f"/v1/me/track-versions/{version['version_id']}/document", headers=headers(domain, "Alice")
        ).status_code
        == 404
    )
    assert (
        domain.client.post(
            f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain)
        ).status_code
        == 409
    )
    assert (
        domain.client.post(
            "/v1/run-tickets",
            json={"version_id": version["version_id"], "vehicle_id": "compact"},
            headers=headers(domain, "Alice"),
        ).status_code
        == 404
    )
    race(domain, version)
    assert publish(domain, version)["state"] == "published"
    assert (
        domain.client.post(
            f"/v1/track-versions/{version['version_id']}/publish", headers=headers(domain, "Alice")
        ).status_code
        == 404
    )


def test_hide_preserves_records_and_share_links(domain):
    version, board = public_course(domain)
    assert (
        domain.client.get("/v1/tracks", params={"q": "loop", "creator": "creat"}).json()["items"][0][
            "version_id"
        ]
        == version["version_id"]
    )
    assert domain.client.get("/v1/tracks", params={"q": "%"}).json()["items"] == []
    assert (
        domain.client.post(
            f"/v1/tracks/{version['track_id']}/hide", headers=headers(domain, "Alice")
        ).status_code
        == 404
    )
    assert (
        domain.client.post(f"/v1/tracks/{version['track_id']}/hide", headers=headers(domain)).status_code
        == 200
    )
    assert domain.client.get("/v1/tracks").json()["items"] == []
    assert domain.client.get(f"/v1/track-versions/{version['version_id']}/document").status_code == 200
    assert domain.client.get(f"/v1/boards/{board}").json()["population"] == 1


def test_ratings_require_completion_disallow_self_and_replace_vote(domain):
    version, _ = public_course(domain)
    path = f"/v1/track-versions/{version['version_id']}/rating"
    assert domain.client.put(path, json={"score": 5}, headers=headers(domain)).status_code == 403
    assert domain.client.put(path, json={"score": 5}, headers=headers(domain, "Alice")).status_code == 403
    race(domain, version, "Alice")
    first = domain.client.put(path, json={"score": 5}, headers=headers(domain, "Alice", "first-vote"))
    assert first.json()["rating_count"] == 1
    assert (
        domain.client.put(path, json={"score": 5}, headers=headers(domain, "Alice", "first-vote")).json()
        == first.json()
    )
    assert (
        domain.client.put(path, json={"score": 3}, headers=headers(domain, "Alice", "first-vote")).status_code
        == 409
    )
    changed = domain.client.put(path, json={"score": 3}, headers=headers(domain, "Alice"))
    assert changed.json()["rating_count"] == 1
    assert changed.json()["rating_average"] == 3
    race(domain, version, "Bob")
    second = domain.client.put(path, json={"score": 5}, headers=headers(domain, "Bob"))
    assert second.json()["rating_count"] == 2
    assert second.json()["rating_average"] == 4
    assert domain.client.put(path, json={"score": True}, headers=headers(domain, "Bob")).status_code == 422


def test_best_lap_histogram_counts_each_driver_once_across_verified_attempts(domain):
    version, board = public_course(domain)
    alice = race(domain, version, "Alice", frames=20)
    slower = race(domain, version, "Alice", frames=25)
    race(domain, version, "Bob", frames=30)
    with domain.factory() as session:
        # Deliberately fast standing starts must never become flying-lap PBs.
        session.get(Run, alice["run_id"]).lap_ticks = [1, 24, 25, 25, 25]
        session.get(Run, slower["run_id"]).lap_ticks = [1, 19, 35, 35, 35]
        session.commit()
    path = f"/v1/boards/{board}/histogram"
    result = domain.client.get(path, params={"metric": "best_lap", "bins": 8})
    assert result.status_code == 200, result.text
    data = result.json()
    assert data["metric"] == "best_lap" and data["population"] == 3
    assert data["minimum_ticks"] == 19 and data["maximum_ticks"] == 60
    assert sum(b["count"] for b in data["bins"]) == 3
    with domain.factory() as session:
        session.get(Run, slower["run_id"]).lap_ticks = [1, 18, 36, 35, 35]
        session.commit()
    assert domain.client.get(path, params={"metric": "best_lap"}).json()["minimum_ticks"] == 18
    assert domain.client.get(path, params={"metric": "unknown"}).status_code == 422
    with domain.factory() as session:
        session.get(Run, slower["run_id"]).status = "failed"
        session.get(Player, domain.players["Bob"]).disabled = True
        session.commit()
    data = domain.client.get(path, params={"metric": "best_lap"}).json()
    assert data["population"] == 2 and data["minimum_ticks"] == 24


def test_results_comparison_uses_one_population_and_replaces_own_result(domain):
    version, _ = public_course(domain)
    path = f"/v1/track-versions/{version['version_id']}/results-comparison"
    params = {"vehicle_id":"compact", "race_ticks":350, "lap_ticks":70}
    assert domain.client.get(path, params=params).status_code == 401
    solo = domain.client.get(path, params=params, headers=headers(domain)).json()
    assert solo["race"]["comparison"] is None and solo["best_lap"]["comparison"] is None
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    response = domain.client.get(path, params=params, headers=headers(domain))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["population_scope"] == "all"
    for metric in ("race", "best_lap"):
        assert data[metric]["board_id"] == data["board_id"]
        assert sum(b["count"] for b in data[metric]["bins"]) == data[metric]["population"] == 3
        assert data[metric]["comparison"]["position"] == 3  # Existing faster self-PB excluded.
        assert data[metric]["comparison"]["population"] == 3
    assert data["race"]["own_best_ticks"] == 300
    assert data["best_lap"]["own_best_ticks"] == 60
    assert domain.client.get(path, params={**params,"race_ticks":0}, headers=headers(domain)).status_code == 422


def test_results_comparison_has_exact_top_percentile_with_ties(domain):
    from bmt_backend.runs import comparison_position
    from bmt_backend.track_models import BoardTimeCount
    _version, board = public_course(domain)
    with domain.factory() as session:
        session.add(BoardTimeCount(board_id=board,time_ticks=100,public_count=10,all_count=10))
        session.add(BoardTimeCount(board_id=board,time_ticks=200,public_count=989,all_count=989))
        session.commit()
        entries = select(BoardTimeCount.time_ticks,BoardTimeCount.public_count.label("count")).where(
            BoardTimeCount.board_id == board).subquery()
        compare = comparison_position(entries,session,200,300)
        assert compare == {"position":11,"population":1000,"top_percent":2,"candidate_ticks":200}
        compare = comparison_position(entries,session,100,None)
        assert compare["position"] == 1 and compare["population"] == 1001 and compare["top_percent"] == 1


def test_pb_ties_histogram_neighbours_and_ghost_share_population(domain):
    version, board = public_course(domain)
    alice = race(domain, version, "Alice", frames=20)
    race(domain, version, "Alice", frames=25)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=20)
    top = domain.client.get(f"/v1/boards/{board}").json()
    assert top["population"] == 3
    assert [item["rank"] for item in top["items"]] == [1, 1, 3]
    assert (
        next(item for item in top["items"] if item["player_id"] == domain.players["Alice"])["run_id"]
        == alice["run_id"]
    )
    histogram = domain.client.get(f"/v1/boards/{board}/histogram", params={"bins": 3}).json()
    assert sum(item["count"] for item in histogram["bins"]) == histogram["population"] == 3
    assert [item["count"] for item in histogram["bins"]] == [2, 0, 1]
    around = domain.client.get(f"/v1/boards/{board}/around-me", headers=headers(domain, "Alice")).json()
    assert around["population"] == 3
    assert around["player"]["rank"] == 1
    assert around["faster_than_percent"] == 50
    assert (
        domain.client.get(f"/v1/boards/{board}/around-me", headers=headers(domain, "Carol")).json()["player"]
        is None
    )
    path = f"/v1/boards/{board}/ghosts/{domain.players['Alice']}"
    assert domain.client.get(path).status_code == 401
    assert domain.client.get(path, headers=headers(domain, "Bob")).status_code == 404
    ghost = domain.client.get(path, headers=headers(domain, "Alice")).json()
    assert ghost["run_id"] == alice["run_id"]
    assert len(ghost["replay"]["frames"]) == 20


def test_submission_ticket_binding_expiry_idempotency_and_conflict(domain):
    version, _ = public_course(domain)
    issued = ticket(domain, version, "Alice")
    body = {
        "ticket_id": issued["ticket_id"],
        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20},
    }
    assert domain.client.post("/v1/runs", json=body, headers=headers(domain, "Bob")).status_code == 404
    first = domain.client.post("/v1/runs", json=body, headers=headers(domain, "Alice", "submit-one"))
    assert first.status_code == 202
    assert (
        domain.client.post("/v1/runs", json=body, headers=headers(domain, "Alice", "submit-one")).json()
        == first.json()
    )
    assert (
        domain.client.post("/v1/runs", json=body, headers=headers(domain, "Alice")).json()["run_id"]
        == first.json()["run_id"]
    )
    body["replay"]["frames"].append([0, 255, 0])
    assert domain.client.post("/v1/runs", json=body, headers=headers(domain, "Alice")).status_code == 409
    expired = ticket(domain, version, "Alice")
    with domain.factory() as session:
        session.get(RunTicket, expired["ticket_id"]).expires_at = now() - 1
        session.commit()
    body["ticket_id"] = expired["ticket_id"]
    assert domain.client.post("/v1/runs", json=body, headers=headers(domain, "Alice")).status_code == 410


@pytest.mark.parametrize(
    "replay",
    [
        {"schema": "bmt-replay-v1", "frames": []},
        {"schema": "bmt-replay-v1", "frames": [[0, True, 0]]},
        {"schema": "bmt-replay-v1", "frames": [[128, 255, 0]]},
        {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]], "time_ticks": 1},
    ],
)
def test_replay_has_only_bounded_quantized_inputs(domain, replay):
    version = upload(domain)
    issued = ticket(domain, version)
    assert (
        domain.client.post(
            "/v1/runs", json={"ticket_id": issued["ticket_id"], "replay": replay}, headers=headers(domain)
        ).status_code
        == 422
    )


def test_rejected_replay_never_publishes_track_or_pb(domain):
    version = upload(domain)
    submitted = submit(domain, ticket(domain, version), steering=-127)
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/runs/{submitted['run_id']}", headers=headers(domain)).json()
    assert result["status"] == "rejected"
    with domain.factory() as session:
        assert session.get(TrackVersion, version["version_id"]).state == "draft"
        assert session.scalar(select(PersonalBest)) is None
    assert (
        domain.client.get(f"/v1/runs/{submitted['run_id']}", headers=headers(domain, "Alice")).status_code
        == 404
    )


def test_infrastructure_retry_is_durable_and_bounded(domain):
    version = upload(domain)
    submitted = submit(domain, ticket(domain, version), steering=-126)
    for attempt in range(3):
        with domain.factory() as session:
            session.get(Run, submitted["run_id"]).lease_until = 0
            session.commit()
        assert process_one(domain.app)
        with domain.factory() as session:
            run = session.get(Run, submitted["run_id"])
            assert run.attempts == attempt + 1
            assert run.status == ("failed" if attempt == 2 else "queued")
    assert not process_one(domain.app)


def test_crashed_worker_lease_can_be_reclaimed(domain):
    version = upload(domain)
    submitted = submit(domain, ticket(domain, version))
    with domain.factory() as session:
        run = session.get(Run, submitted["run_id"])
        run.status, run.lease_token, run.lease_until, run.attempts = "verifying", "old-worker", now() - 5, 1
        session.commit()
    assert process_one(domain.app)
    with domain.factory() as session:
        run = session.get(Run, submitted["run_id"])
        assert run.status == "verified"
        assert run.attempts == 2


def test_lost_lease_fences_stale_verification(domain):
    version = upload(domain)
    submitted = submit(domain, ticket(domain, version))
    original = domain.app.state.verifier.verify_run

    def steal_lease(*args):
        with domain.factory() as session:
            run = session.get(Run, submitted["run_id"])
            run.lease_token = "new-worker"
            session.commit()
        return original(*args)

    domain.app.state.verifier.verify_run = steal_lease
    assert process_one(domain.app)
    with domain.factory() as session:
        assert session.scalar(select(PersonalBest)) is None
        assert session.get(Run, submitted["run_id"]).status == "verifying"


def test_disabled_players_removed_from_every_board_projection(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    with domain.factory() as session:
        session.get(Player, domain.players["Alice"]).disabled = True
        session.commit()
    top = domain.client.get(f"/v1/boards/{board}").json()
    assert top["population"] == 2
    assert [item["rank"] for item in top["items"]] == [1, 2]
    assert domain.client.get(f"/v1/boards/{board}/histogram").json()["population"] == 2
    assert (
        domain.client.get(f"/v1/boards/{board}/around-me", headers=headers(domain, "Bob")).json()[
            "population"
        ]
        == 2
    )
    assert (
        domain.client.get(
            f"/v1/boards/{board}/ghosts/{domain.players['Alice']}", headers=headers(domain, "Bob")
        ).status_code
        == 404
    )


def test_unknown_vehicle_and_changed_runtime_manifest_rejected(domain):
    version = upload(domain)
    assert (
        domain.client.post(
            "/v1/run-tickets",
            json={"version_id": version["version_id"], "vehicle_id": "cheat-car"},
            headers=headers(domain),
        ).status_code
        == 422
    )
    original = domain.app.state.verifier.manifest()
    domain.app.state.verifier.manifest = lambda: {**original, "physics_version": "changed"}
    assert (
        domain.client.post(
            "/v1/run-tickets",
            json={"version_id": version["version_id"], "vehicle_id": "compact"},
            headers=headers(domain),
        ).status_code
        == 409
    )


def test_checkpoint_rules_upgrade_keeps_track_and_historical_board(domain, monkeypatch):
    from bmt_backend import runs

    previous, current = runs.CHECKPOINT_RULES_TRANSITION
    base = domain.app.state.verifier.manifest()
    domain.app.state.verifier.manifest = lambda: {**base, "rules_key": previous}
    # Establish the historical state using the previous ticket policy.
    with monkeypatch.context() as old_policy:
        old_policy.setattr(runs, "current_manifest", lambda value: value)
        version, old_board_id = public_course(domain)
    with domain.factory() as session:
        original = dict(session.get(TrackVersion, version["version_id"]).manifest)
    domain.app.state.verifier.manifest = lambda: {**base, "rules_key": current}
    issued = ticket(domain, version, "Alice")
    assert issued["manifest"]["rules_key"] == current
    assert issued["board_id"] != old_board_id
    submitted = submit(domain, issued, "Alice")
    assert process_one(domain.app)
    result = domain.client.get(
        f"/v1/runs/{submitted['run_id']}", headers=headers(domain, "Alice")
    ).json()
    assert result["status"] == "verified", result
    board = domain.client.get(f"/v1/track-versions/{version['version_id']}/leaderboard").json()
    assert board["board_id"] == issued["board_id"] and board["population"] == 1
    historical = domain.client.get(f"/v1/boards/{old_board_id}").json()
    assert historical["manifest"]["rules_key"] == previous and historical["population"] == 1
    with domain.factory() as session:
        assert session.get(TrackVersion, version["version_id"]).manifest == original
    domain.app.state.verifier.manifest = lambda: {
        **base, "rules_key": current, "physics_version": "changed"
    }
    rejected = domain.client.post(
        "/v1/run-tickets",
        json={"version_id": version["version_id"], "vehicle_id": "compact"},
        headers=headers(domain),
    )
    assert rejected.status_code == 409


def test_concurrent_postgres_votes_do_not_lose_aggregate_updates(domain):
    if not domain.postgres:
        pytest.skip("Concurrency contract requires PostgreSQL row locks")
    version, _ = public_course(domain)
    for name in ("Alice", "Bob", "Carol"):
        race(domain, version, name)

    def vote(name):
        return domain.client.put(
            f"/v1/track-versions/{version['version_id']}/rating",
            json={"score": 4},
            headers=headers(domain, name),
        )

    with ThreadPoolExecutor(max_workers=3) as pool:
        responses = list(pool.map(vote, ("Alice", "Bob", "Carol")))
    assert all(response.status_code == 200 for response in responses), [
        response.text for response in responses
    ]
    summary = domain.client.get(f"/v1/track-versions/{version['version_id']}").json()
    assert summary["rating_count"] == 3
    assert summary["rating_average"] == 4


def test_concurrent_postgres_workers_claim_distinct_jobs_and_keep_best(domain):
    if not domain.postgres:
        pytest.skip("Concurrency contract requires PostgreSQL SKIP LOCKED")
    version, board = public_course(domain)
    runs = [
        submit(domain, ticket(domain, version, "Alice"), "Alice", frames=count) for count in (29, 20, 25, 23)
    ]
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert all(pool.map(lambda _: process_one(domain.app), range(4)))
    with domain.factory() as session:
        assert all(session.get(Run, run["run_id"]).status == "verified" for run in runs)
        assert all(session.get(Run, run["run_id"]).attempts == 1 for run in runs)
        best = session.get(PersonalBest, (board, domain.players["Alice"]))
        assert best.time_ticks == 100
        assert best.run_id == runs[1]["run_id"]


def test_concurrent_postgres_same_upload_key_creates_only_one_version(domain):
    if not domain.postgres:
        pytest.skip("Concurrency contract requires PostgreSQL uniqueness")
    with ThreadPoolExecutor(max_workers=4) as pool:
        versions = list(pool.map(lambda _: upload(domain, key="concurrent-upload"), range(4)))
    assert len({version["version_id"] for version in versions}) == 1
    with domain.factory() as session:
        assert len(session.scalars(select(TrackVersion)).all()) == 1


def test_postgres_histogram_uses_one_snapshot_during_new_verified_result(domain):
    if not domain.postgres:
        pytest.skip("Snapshot contract requires PostgreSQL REPEATABLE READ")
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    submit(domain, ticket(domain, version, "Bob"), "Bob", frames=40)
    fired = False

    def finish_race_after_count(connection, cursor, statement, parameters, context, executemany):
        nonlocal fired
        if not fired and "min(" in statement.lower() and "board_time_counts" in statement:
            fired = True
            assert process_one(domain.app)

    event.listen(domain.app.state.engine, "after_cursor_execute", finish_race_after_count)
    try:
        result = domain.client.get(f"/v1/boards/{board}/histogram").json()
    finally:
        event.remove(domain.app.state.engine, "after_cursor_execute", finish_race_after_count)
    assert fired
    assert result["population"] == 2
    assert sum(item["count"] for item in result["bins"]) == 2
    assert domain.client.get(f"/v1/boards/{board}").json()["population"] == 3


def test_concurrent_postgres_submissions_cannot_exceed_player_queue_budget(domain):
    if not domain.postgres:
        pytest.skip("Queue admission contract requires PostgreSQL row locks")
    version, _ = public_course(domain)
    tickets = [ticket(domain, version, "Alice") for _ in range(9)]

    def attempt(issued):
        import time
        auth = headers(domain, "Alice")
        for retry in range(10):
            response = domain.client.post("/v1/runs", json={"ticket_id": issued["ticket_id"],
                "replay": {"schema": "bmt-replay-v1", "frames": [[0,255,0]]*20}}, headers=auth)
            if response.status_code != 503 or response.json().get("detail") != "REQUEST_VALIDATION_BUSY":
                return response
            time.sleep(.1)
        return response

    with ThreadPoolExecutor(max_workers=9) as pool:
        responses = list(pool.map(attempt, tickets))
    assert sorted(response.status_code for response in responses) == [202] * 8 + [429], [
        response.text for response in responses
    ]


def test_uploaded_document_cannot_spoof_creator(domain):
    version = upload(domain, document={"shape": "oval", "creator": "Alice"})
    assert version["creator"] == "Creator"
    assert version["creator_id"] == domain.players["Creator"]
    stored = domain.app.state.blobs.get_json(version["content_hash"])
    assert stored["creator"] == "Creator"
    denied = domain.client.post(
        f"/v1/tracks/{version['track_id']}/versions",
        json={"name": "Hijack", "document": {"shape": "oval", "creator": "Creator"}},
        headers=headers(domain, "Alice"),
    )
    assert denied.status_code == 404


def test_creator_practice_unlocks_publish_without_leaderboard_score(domain):
    version = upload(domain)
    response = domain.client.post("/v1/run-tickets", json={
        "version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"
    }, headers=headers(domain))
    assert response.status_code == 201, response.text
    issued = response.json()
    assert issued["manifest"]["laps"] == 1
    submitted = submit(domain, issued)
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/runs/{submitted['run_id']}", headers=headers(domain)).json()
    assert result["status"] == "verified"
    assert len(result["lap_ticks"]) == 1
    with domain.factory() as session:
        assert session.scalar(select(PersonalBest).where(PersonalBest.board_id == issued["board_id"])) is None
    publish(domain, version)
    assert domain.client.get(f"/v1/boards/{issued['board_id']}").status_code == 404
    assert ticket(domain, version)["manifest"]["laps"] == 5
    response = domain.client.post("/v1/run-tickets", json={
        "version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"
    }, headers=headers(domain, "Alice"))
    assert response.status_code == 403


def test_recorded_practice_through_real_publish_worker(domain):
    import json

    from bmt_backend.verifier import GodotVerifier
    root = Path(__file__).resolve().parents[2]
    proof_path = root / "build/creator-practice-proof.json"
    if not proof_path.exists():
        pytest.skip("Run TestPractice first")
    binary = os.environ.get("BMT_GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).exists():
        pytest.skip("Pinned Godot unavailable")
    domain.app.state.verifier = GodotVerifier(SimpleNamespace(
        godot_bin=binary, game_project=root / "game", verifier_timeout_seconds=90))
    proof = json.loads(proof_path.read_text())
    version = upload(domain, document=proof["document"])
    issued = domain.client.post("/v1/run-tickets", json={
        "version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test"
    }, headers=headers(domain))
    assert issued.status_code == 201, issued.text
    submitted = domain.client.post("/v1/runs", json={
        "ticket_id": issued.json()["ticket_id"], "replay": proof["replay"]
    }, headers=headers(domain))
    assert submitted.status_code == 202, submitted.text
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/runs/{submitted.json()['run_id']}", headers=headers(domain)).json()
    assert result["status"] == "verified", result
    publish(domain, version)
    board = domain.client.get(f"/v1/track-versions/{version['version_id']}/leaderboard").json()
    assert board["population"] == 0
