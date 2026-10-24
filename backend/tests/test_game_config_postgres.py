"""Concurrent real PostgreSQL owner commands against an explicitly owned database."""
import os
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_game_config import OWNER, command, draft, publish

from bmt_backend.admin_models import AdminAudit
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.game_config_policy import DEFAULTS
from bmt_backend.migrate import upgrade


@pytest.fixture(scope="module")
def pg(tmp_path_factory):
    url = os.environ.get("BMT_CONFIG_TEST_PG_URL", "")
    if not url:
        pytest.skip("Requires this task's owned PostgreSQL fixture")
    from urllib.parse import urlparse
    parsed = urlparse(url.replace("postgresql+psycopg", "postgresql"))
    assert parsed.hostname == "127.0.0.1" and parsed.path == "/config_test"
    app = create_app(Settings(environment="test", database_url=url, studio_legacy_keys_enabled=True,
        object_dir=str(tmp_path_factory.mktemp("config-pg-objects")), admin_owner_key="o" * 40))
    upgrade(app.state.engine)
    with TestClient(app) as client:
        yield app, client
    app.state.engine.dispose()


@pytest.mark.postgres
def test_concurrent_duplicate_publication_commits_one_snapshot_and_audit(pg):
    app, client = pg
    row = draft(client, {**DEFAULTS, "ads.races": 4, "ads.active_seconds": 360})
    body = command(row["revision"])
    path = "/v1/admin/game-config/drafts/" + row["id"] + "/publish"
    with ThreadPoolExecutor(max_workers=8) as workers:
        replies = list(workers.map(lambda _: client.post(path, headers=OWNER, json=body), range(8)))
    assert all(r.status_code == 200 for r in replies), [r.text for r in replies]
    assert len({r.json()["release"]["generation"] for r in replies}) == 1
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(AdminAudit).where(AdminAudit.command_id == body["command_id"])) == 1


@pytest.mark.postgres
def test_concurrent_stale_draft_edit_accepts_exactly_one_writer(pg):
    _, client = pg
    row = draft(client)
    path = "/v1/admin/game-config/drafts/" + row["id"] + "/edit"
    values = [{**DEFAULTS, "ads.races": 5}, {**DEFAULTS, "ads.races": 7}]
    with ThreadPoolExecutor(max_workers=2) as workers:
        responses = list(workers.map(lambda policy: client.post(path, headers=OWNER,
            json=command(row["revision"], policy=policy)), values))
    assert sorted(r.status_code for r in responses) == [200, 409]
    saved = client.get("/v1/admin/game-config/drafts/"+row["id"], headers=OWNER).json()
    assert saved["policy"] in values and saved["revision"] == row["revision"] + 1


@pytest.mark.postgres
def test_readers_observe_complete_policy_groups_during_publication(pg):
    _, client = pg
    first = publish(client, draft(client, {**DEFAULTS, "ads.races": 3, "ads.active_seconds": 600}))
    second_draft = draft(client, {**DEFAULTS, "ads.races": 9, "ads.active_seconds": 1200})
    def read(_):
        value = client.get("/v1/game-config?capabilities=ad_policy_v1").json()["settings"]
        return value["ads.races"], value["ads.active_seconds"]
    with ThreadPoolExecutor(max_workers=4) as workers:
        futures = [workers.submit(read, n) for n in range(12)]
        changed = workers.submit(publish, client, second_draft)
        values = [item.result() for item in futures]
        assert changed.result()["release"]["generation"] > first["release"]["generation"]
    assert set(values) <= {(3, 600), (9, 1200)}
