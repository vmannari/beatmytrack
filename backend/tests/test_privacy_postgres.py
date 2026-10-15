"""Real owner locks and upload/deletion concurrency in an owned PostgreSQL schema."""
# ruff: noqa: F811
import threading
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy import func, select
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_privacy import auth, deletion_body, drain, seed

from bmt_backend.identity_models import Identity, Player
from bmt_backend.privacy_models import AccountDeletion
from bmt_backend.track_models import TrackVersion


def sign(app, client, subject):
    response = client.post("/v1/auth/google", json=google_request(app, client, subject))
    assert response.status_code == 200, response.text
    return response.json()


def test_concurrent_deletion_receipts_have_one_effect(postgres_auth):
    app, client = postgres_auth
    signed = sign(app, client, "deletion-concurrent")
    version, _board, _run, _old, _replay, manifest = seed(app, signed)
    body = deletion_body()
    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(lambda _: client.post("/v1/privacy/account-deletion", headers=auth(signed), json=body), range(4)))
    assert all(response.status_code == 202 for response in responses), [response.text for response in responses]
    with app.state.session_factory() as session:
        assert session.scalar(select(func.count()).select_from(AccountDeletion)) == 1
        assert session.scalar(select(func.count()).select_from(Identity)) == 0
    drain(app)
    with app.state.session_factory() as session:
        assert session.get(TrackVersion, version).manifest == manifest
        assert session.get(AccountDeletion, signed["player"]["id"]).completed_at


def test_upload_that_released_owner_lock_is_fenced_after_removal(postgres_auth):
    from fastapi import HTTPException
    app, client = postgres_auth
    signed = sign(app, client, "deletion-upload")
    released, resume = threading.Event(), threading.Event()

    def upload():
        with app.state.session_factory() as session:
            session.info["privacy_actor"] = signed["player"]["id"]
            session.scalar(select(Player).where(Player.id == signed["player"]["id"]).with_for_update())
            session.rollback()
            released.set()
            assert resume.wait(10)
            session.add(Identity(player_id=signed["player"]["id"], provider="google", subject="late-upload"))
            try:
                session.commit()
            except HTTPException:
                session.rollback()
                return "fenced"
            return "resurrected"

    with ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(upload)
        assert released.wait(10)
        assert client.post("/v1/privacy/account-deletion", headers=auth(signed), json=deletion_body()).status_code == 202
        resume.set()
        assert future.result(10) == "fenced"


def test_cleanup_cannot_recreate_deleted_product_profiles(postgres_auth):
    from dataclasses import replace

    from test_product_analytics import body, observed

    from bmt_backend.product_analytics import project_pending
    from bmt_backend.telemetry_models import ProductProfile
    from bmt_backend.track_models import now
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True)
    signed = sign(app, client, "deletion-projection")
    assert client.post("/v1/privacy/preferences", headers=auth(signed), json={"analytics_enabled": True}).status_code == 200
    assert client.post("/v1/telemetry/batches", headers=auth(signed), json=body([observed("menu_ready", at=now())])).status_code == 200
    assert client.post("/v1/privacy/account-deletion", headers=auth(signed), json=deletion_body()).status_code == 202
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = [pool.submit(project_pending, app.state.session_factory), pool.submit(drain, app)]
        for result in results:
            result.result(30)
    with app.state.session_factory() as session:
        assert session.get(ProductProfile, signed["player"]["id"]) is None
