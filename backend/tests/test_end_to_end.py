"""Exercise real HTTP contracts, persistence and real canonical replay verification."""

import json
import os
import secrets
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.worker import process_one

REPO = Path(__file__).resolve().parents[2]


@pytest.fixture(params=["sqlite", "postgres"])
def integration_database(request):
    if request.param == "sqlite":
        yield None
        return
    url = os.environ.get("BMT_TEST_DATABASE_URL")
    local = REPO / ".tools/backend-postgres.env"
    if not url and local.is_file():
        url = next(
            (
                line.split("=", 1)[1]
                for line in local.read_text().splitlines()
                if line.startswith("BMT_TEST_DATABASE_URL=")
            ),
            None,
        )
    if not url:
        pytest.skip("Disposable PostgreSQL database not configured")
    schema = "test_integration_" + uuid.uuid4().hex
    admin = create_engine(url, connect_args={"connect_timeout": 5})
    with admin.begin() as connection:
        connection.exec_driver_sql(f"CREATE SCHEMA {schema}")
    engine = create_engine(url, connect_args={"connect_timeout": 5, "options": f"-c search_path={schema}"})
    try:
        yield engine
    finally:
        engine.dispose()
        with admin.begin() as connection:
            connection.exec_driver_sql(f"DROP SCHEMA {schema} CASCADE")
        admin.dispose()


@pytest.mark.godot
def test_two_player_publish_share_race_rate_leaderboard(tmp_path, integration_database):
    binary = os.environ.get("BMT_GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not Path(binary).is_file():
        pytest.skip("Exact Godot binary not configured")
    app = create_app(
        Settings(
            environment="development",
            dev_auth_enabled=True,
            dev_auth_key="test-key-" * 8,
            database_url=f"sqlite:///{(tmp_path / 'integration.sqlite').as_posix()}",
            object_dir=str(tmp_path / "objects"),
            godot_bin=binary,
            game_project=str(REPO / "game"),
        ),
        engine=integration_database,
    )
    upgrade(app.state.engine)
    fixture = json.loads((REPO / "backend/tests/fixtures/verified_oval.json").read_text())
    with TestClient(app) as client:

        def login(subject):
            response = client.post(
                "/v1/auth/development",
                headers={"X-Dev-Auth-Key": "test-key-" * 8},
                json={"subject": subject, "display_name": subject},
            )
            assert response.status_code == 200, response.text
            return response.json()

        def write(path, body, token, key=None):
            return client.post(
                path,
                json=body,
                headers={
                    "Authorization": "Bearer " + token["access_token"],
                    "Idempotency-Key": key or str(uuid.uuid4()),
                },
            )

        creator, racer = login("creator"), login("racer")
        uploaded = write("/v1/tracks", {"name": "Verified oval", "document": fixture["document"]}, creator)
        assert uploaded.status_code == 201, uploaded.text
        version = uploaded.json()["version_id"]
        assert client.get(f"/v1/track-versions/{version}").status_code == 404
        assert write(f"/v1/track-versions/{version}/publish", {}, creator).status_code == 409

        def race(player, replay):
            ticket = write("/v1/run-tickets", {"version_id": version, "vehicle_id": "compact"}, player)
            assert ticket.status_code == 201, ticket.text
            submission = {"ticket_id": ticket.json()["ticket_id"], "replay": replay}
            key = secrets.token_hex(16)
            run = write("/v1/runs", submission, player, key)
            assert run.status_code == 202, run.text
            assert write("/v1/runs", submission, player, key).json()["run_id"] == run.json()["run_id"]
            assert process_one(app)
            result = client.get(
                "/v1/runs/" + run.json()["run_id"],
                headers={"Authorization": "Bearer " + player["access_token"]},
            )
            return result.json(), ticket.json()["board_id"]

        creator_run, board = race(creator, fixture["replay"])
        assert creator_run["status"] == "verified", creator_run
        assert write(f"/v1/track-versions/{version}/publish", {}, creator).status_code == 200
        assert client.get(f"/v1/track-versions/{version}/document").json() == {
            **fixture["document"],
            "creator": creator["player"]["display_name"],
        }
        assert client.get("/v1/tracks", params={"q": "oval"}).json()["items"][0]["version_id"] == version
        racer_run, same_board = race(racer, fixture["replay"])
        assert racer_run["status"] == "verified" and same_board == board
        assert racer_run["time_ticks"] == creator_run["time_ticks"] == 12757
        rating = client.put(
            f"/v1/track-versions/{version}/rating",
            json={"score": 5},
            headers={
                "Authorization": "Bearer " + racer["access_token"],
                "Idempotency-Key": str(uuid.uuid4()),
            },
        )
        assert rating.status_code == 200, rating.text
        top = client.get(f"/v1/boards/{board}").json()
        assert top["population"] == 2 and [row["rank"] for row in top["items"]] == [1, 1]
        histogram = client.get(f"/v1/boards/{board}/histogram").json()
        assert sum(row["count"] for row in histogram["bins"]) == histogram["population"] == 2
        ghost = client.get(
            f"/v1/boards/{board}/ghosts/{racer['player']['id']}",
            headers={"Authorization": "Bearer " + racer["access_token"]},
        )
        assert ghost.json()["replay"] == fixture["replay"]
        rejected, _ = race(racer, {"schema": "bmt-replay-v1", "frames": [[0, 0, 0]]})
        assert rejected["status"] == "rejected"
        assert client.get(f"/v1/boards/{board}").json()["population"] == 2
    app.state.engine.dispose()
