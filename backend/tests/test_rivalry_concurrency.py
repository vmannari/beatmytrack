"""Concurrent capacity reservations in a disposable file-backed SQLite DB."""
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace

from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_domains import FakeVerifier
from test_rivalry import join, seed

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.security import current_player


def test_simultaneous_capacity_reservations(tmp_path):
    app = create_app(Settings(database_url=f"sqlite:///{(tmp_path/'rivals.sqlite').as_posix()}",
        object_dir=str(tmp_path/'objects'), rate_limit_per_minute=10000, write_limit_per_minute=10000),
        verifier=FakeVerifier())
    upgrade(app.state.engine)
    factory = app.state.session_factory
    with factory() as session:
        players = [Player(display_name=name) for name in ["Creator","Alice"] + [f"Entrant_{i}" for i in range(21)]]
        session.add_all(players)
        session.flush()
        ids = {player.display_name:player.id for player in players}
        session.commit()

    def authenticated(request: Request):
        with factory() as session:
            player = session.get(Player, request.headers.get("x-test-player",""))
            if player is None:
                raise HTTPException(401,"Test auth required")
            session.expunge(player)
            return player

    app.dependency_overrides[current_player] = authenticated
    try:
        with TestClient(app) as client:
            domain = SimpleNamespace(app=app,client=client,factory=factory,players=ids)
            seed(domain)
            join(domain)
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(lambda name:join(domain,name), [f"Entrant_{i}" for i in range(21)]))
            assert all(item["driver_count"] <= 20 for item in results)
            with factory() as session:
                groups = session.scalars(select(RivalryGroup)).all()
                assert sum(group.member_count for group in groups) == 22
                assert all(1 <= group.member_count <= 20 for group in groups)
                for group in groups:
                    actual = session.scalar(select(func.count()).select_from(RivalryMember).where(RivalryMember.group_id == group.id))
                    assert actual == group.member_count
    finally:
        app.state.engine.dispose()
