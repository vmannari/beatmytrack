from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import select
from test_auth_postgres import postgres_auth  # noqa: F401

from bmt_backend.admin_models import AdminAudit
from bmt_backend.identity_models import Identity, Player, SessionFamily
from bmt_backend.track_models import Track, TrackVersion


@pytest.fixture
def console(auth_app, auth_client):
    auth_app.state.settings = replace(
        auth_app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40
    )
    with auth_app.state.session_factory() as db:
        player = Player(display_name="<script>name</script>")
        db.add(player)
        db.flush()
        db.add(Identity(player_id=player.id, provider="google", subject="private-provider-subject"))
        db.add(SessionFamily(player_id=player.id, expires_at=9999999999))
        track = Track(owner_id=player.id)
        db.add(track)
        db.flush()
        version = TrackVersion(
            track_id=track.id,
            number=1,
            name="Test circuit",
            content_hash="f" * 64,
            manifest={"laps": 5},
            state="published",
        )
        db.add(version)
        db.commit()
        ids = player.id, track.id, version.id
    return auth_client, auth_app, ids


def headers(role="owner"):
    return {"Authorization": "Bearer " + ("o" if role == "owner" else "a") * 40}


def payload(entity, action="player_restriction", **extra):
    return dict(
        command_id=str(uuid4()),
        entity_id=entity,
        action=action,
        expected=False,
        value=True,
        reason="Reviewed support evidence",
        acknowledged=True,
        **extra,
    )


def test_admin_denies_missing_and_game_credentials(console):
    client, _app, ids = console
    for endpoint in ("overview", "entities/players", "entities/players/" + ids[0]):
        assert client.get("/v1/admin/" + endpoint).status_code == 401
        assert (
            client.get("/v1/admin/" + endpoint, headers={"Authorization": "Bearer game-session"}).status_code
            == 401
        )
    assert client.post("/v1/admin/commands", json=payload(ids[0])).status_code == 401
    assert client.get("/admin").status_code == 200
    assert "frame-ancestors 'none'" in client.get("/admin").headers["content-security-policy"]
    assert client.get("/admin/assets/missing").status_code == 404


def test_queries_are_bounded_and_redacted(console):
    client, _app, ids = console
    result = client.get("/v1/admin/entities/players?q=name", headers=headers("analyst")).json()
    assert result["total"] == 1
    detail = client.get("/v1/admin/entities/players/" + ids[0], headers=headers()).json()
    assert detail["providers"] == ["google"]
    assert "private-provider-subject" not in str(detail)
    assert client.get("/v1/admin/entities/players?limit=101", headers=headers()).status_code == 422
    assert client.get("/v1/admin/entities/players?q=%25", headers=headers()).json()["total"] == 0
    assert client.get("/v1/admin/entities/players/" + str(uuid4()), headers=headers()).status_code == 404
    assert client.get("/v1/admin/overview?days=0", headers=headers()).status_code == 422
    assert client.get("/v1/admin/overview", headers=headers()).json()["players"] == 1


def test_analyst_cannot_mutate(console):
    client, app, ids = console
    assert (
        client.post("/v1/admin/commands", headers=headers("analyst"), json=payload(ids[0])).status_code == 403
    )
    with app.state.session_factory() as db:
        assert not db.get(Player, ids[0]).disabled
        assert not db.scalars(select(AdminAudit)).all()


def test_restriction_revokes_sessions_and_is_audited_once(console):
    client, app, ids = console
    body = payload(ids[0])
    first = client.post("/v1/admin/commands", headers=headers(), json=body)
    assert first.status_code == 200
    assert client.post("/v1/admin/commands", headers=headers(), json=body).json() == first.json()
    with app.state.session_factory() as db:
        assert db.get(Player, ids[0]).disabled
        assert db.scalar(select(SessionFamily)).revoked
        rows = db.scalars(select(AdminAudit)).all()
        assert (
            len(rows) == 1 and rows[0].before == {"disabled": False} and rows[0].after == {"disabled": True}
        )
    body["reason"] = "A different reason now"
    assert client.post("/v1/admin/commands", headers=headers(), json=body).status_code == 409
    assert client.post("/v1/admin/commands", headers=headers(), json=payload(ids[0])).status_code == 409


def test_visibility_preserves_published_document(console):
    client, app, ids = console
    assert (
        client.post(
            "/v1/admin/commands", headers=headers(), json=payload(ids[1], "track_visibility")
        ).status_code
        == 200
    )
    with app.state.session_factory() as db:
        assert db.get(Track, ids[1]).hidden
        version = db.get(TrackVersion, ids[2])
        assert version.state == "published" and version.content_hash == "f" * 64
    assert client.get("/v1/admin/entities/tracks", headers=headers()).json()["items"][0]["hidden"]


def test_reason_acknowledgement_and_revocation(console):
    client, app, ids = console
    body = payload(ids[0])
    body["acknowledged"] = False
    assert client.post("/v1/admin/commands", headers=headers(), json=body).status_code == 422
    body["acknowledged"] = True
    body["reason"] = " " * 20
    assert client.post("/v1/admin/commands", headers=headers(), json=body).status_code == 422
    app.state.settings = replace(app.state.settings, admin_owner_key="")
    assert client.get("/v1/admin/overview", headers=headers()).status_code == 401


@pytest.mark.postgres
def test_postgres_admin_daily_query_and_concurrent_command(postgres_auth):  # noqa: F811
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier

    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, admin_owner_key="o" * 40)
    with app.state.session_factory() as db:
        player = Player(display_name="Admin test racer")
        db.add(player)
        db.commit()
        player_id = player.id
    overview = client.get("/v1/admin/overview", headers=headers())
    assert overview.status_code == 200, overview.text
    body = payload(player_id)
    barrier = Barrier(2)

    def perform():
        barrier.wait(timeout=10)
        return client.post("/v1/admin/commands", headers=headers(), json=body)

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(perform) for _ in range(2)]
        responses = [future.result(timeout=20) for future in futures]
    assert [r.status_code for r in responses] == [200, 200]
    assert responses[0].json() == responses[1].json()
    with app.state.session_factory() as db:
        assert len(db.scalars(select(AdminAudit)).all()) == 1
