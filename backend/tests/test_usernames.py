"""Unique mutable names; immutable UUID ownership and safe schema upgrade."""

import uuid

import pytest
from alembic import command
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import IntegrityError

from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import Track


def headers(login):
    return {"Authorization": "Bearer " + login["access_token"]}


@pytest.mark.parametrize("duplicate", ["ALICE", " Alice ", "\uff21lice"])
def test_names_are_unique_across_normalized_variants(auth_client, sign_in, duplicate):
    alice, bob = sign_in("alice"), sign_in("bob")
    response = auth_client.patch("/v1/me", headers=headers(bob), json={"display_name": duplicate})
    assert response.status_code == 409 and response.json()["detail"] == "USERNAME_TAKEN"
    assert auth_client.get("/v1/me", headers=headers(bob)).json()["display_name"] == "bob"
    assert (
        auth_client.patch("/v1/me", headers=headers(alice), json={"display_name": "ALICE"}).status_code == 200
    )


def test_spaces_reserved_name_and_rename_keep_uuid_and_tracks(auth_app, auth_client, sign_in):
    alice, bob = sign_in("alice", display_name="Fast Racer"), sign_in("bob")
    pid = alice["player"]["id"]
    with auth_app.state.session_factory() as session:
        track = Track(owner_id=pid)
        session.add(track)
        session.commit()
        tid = track.id
    for name in ["fast   racer", "Beat My Track", "BEAT MY TRACK"]:
        assert (
            auth_client.patch("/v1/me", headers=headers(bob), json={"display_name": name}).status_code == 409
        )
    renamed = auth_client.patch("/v1/me", headers=headers(alice), json={"display_name": "New racer"})
    assert renamed.status_code == 200 and renamed.json()["id"] == pid
    assert sign_in("alice")["player"]["display_name"] == "New racer"
    with auth_app.state.session_factory() as session:
        assert session.get(Track, tid).owner_id == pid
    refreshed = auth_client.post("/v1/auth/refresh", json={"refresh_token": alice["refresh_token"]})
    assert refreshed.status_code == 200 and refreshed.json()["player"]["id"] == pid


def test_database_unique_constraint_and_pending_names(auth_app):
    with auth_app.state.session_factory() as session:
        session.add_all(
            [
                Player(display_name="Racer", needs_username=True),
                Player(display_name="Racer", needs_username=True),
            ]
        )
        session.commit()
        assert all(p.username_key is None for p in session.scalars(select(Player)))
        session.add(Player(display_name="Claimed"))
        session.commit()
        session.add(Player(display_name="CLAIMED"))
        with pytest.raises(IntegrityError):
            session.commit()
        session.rollback()


def old_database(tmp_path, names):
    engine = create_engine(f"sqlite:///{tmp_path / 'old.db'}")
    command.upgrade(configuration(engine), "0004_developer_name")
    with engine.begin() as connection:
        for name in names:
            connection.execute(
                text(
                    "INSERT INTO players (id,display_name,needs_username,disabled,created_at) VALUES (:id,:name,false,false,1)"
                ),
                {"id": str(uuid.uuid4()), "name": name},
            )
    return engine


def test_migration_preserves_existing_uuid_and_claims(tmp_path):
    engine = old_database(tmp_path, ["Alice", "Bob"])
    with engine.connect() as connection:
        before = connection.execute(text("SELECT id,display_name FROM players ORDER BY id")).all()
    upgrade(engine)
    with engine.connect() as connection:
        assert connection.execute(text("SELECT id,display_name FROM players ORDER BY id")).all() == before
        assert set(connection.execute(text("SELECT username_key FROM players")).scalars()) == {"alice", "bob"}
    engine.dispose()


def test_migration_rejects_duplicates_without_renaming(tmp_path):
    engine = old_database(tmp_path, ["Alice", "ALICE"])
    with pytest.raises(RuntimeError, match="Duplicate racing names"):
        upgrade(engine)
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT version_num FROM alembic_version")) == "0004_developer_name"
        assert set(connection.execute(text("SELECT display_name FROM players")).scalars()) == {
            "Alice",
            "ALICE",
        }
    engine.dispose()


def test_new_google_identity_cannot_take_existing_name(auth_app, auth_client, sign_in):
    sign_in("owner", display_name="Claimed Name")
    challenge = auth_client.post("/v1/auth/google/challenge").json()
    token = "duplicate-identity-test-token-12345"
    auth_app.state.identity_verifier.claims[token] = {
        "sub": "another-google-user",
        "nonce": challenge["nonce"],
    }
    reply = auth_client.post(
        "/v1/auth/google",
        json={"id_token": token, "challenge_id": challenge["challenge_id"], "display_name": "CLAIMED NAME"},
    )
    assert reply.status_code == 409 and reply.json()["detail"] == "USERNAME_TAKEN"
    with auth_app.state.session_factory() as session:
        assert len(session.scalars(select(Player)).all()) == 1
