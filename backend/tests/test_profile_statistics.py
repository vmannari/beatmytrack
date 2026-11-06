"""Private profile counts distinguish repeated finishes, drivers and failures."""
# ruff: noqa: F811 -- pytest fixtures are imported for discovery.
from sqlalchemy import event, select
from test_domains import domain, headers, publish, race, upload  # noqa: F401

from bmt_backend.identity_models import Player
from bmt_backend.profile_statistics import car_history, track_races
from bmt_backend.track_models import Board, Run, TrackVersion


def course(d):
    version = upload(d)
    race(d, version, frames=100)
    publish(d, version)
    return version


def test_profile_is_private_and_counts_races_not_personal_bests(domain):
    d = domain
    version = course(d)
    race(d, version, "Alice", frames=50)
    race(d, version, "Alice", frames=40)
    race(d, version, "Bob", frames=30)
    assert d.client.get("/v1/me/profile-statistics").status_code == 401
    response = d.client.get("/v1/me/profile-statistics", headers=headers(d, "Alice"))
    assert response.status_code == 200, response.text
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json()["cars"]["compact"] == {"races": 2, "distance_m": 2200}
    assert response.json()["cars"]["electric"] == {"races": 0, "distance_m": 0}
    bob = d.client.get("/v1/me/profile-statistics", headers=headers(d, "Bob"))
    assert bob.json()["cars"]["compact"]["races"] == 1
    listed = d.client.get("/v1/me/tracks?heads=true&profile_stats=true", headers=headers(d))
    assert listed.status_code == 200, listed.text
    # The legacy fixture's creator qualifying run is itself an ordinary
    # five-lap verified run, so it also belongs in the published-version count.
    assert listed.json()["items"][0]["verified_races"] == 4


def test_profile_reads_are_aggregated_and_do_not_mutate(domain):
    d = domain
    version = course(d)
    race(d, version, "Alice", frames=50)
    statements = []

    def record(_conn, _cursor, statement, _parameters, _context, _many):
        statements.append(statement.lower())

    event.listen(d.app.state.engine, "before_cursor_execute", record)
    try:
        with d.factory() as session:
            assert car_history(session, d.players["Alice"])["cars"]["compact"]["races"] == 1
            assert track_races(session, [version["version_id"]])[version["version_id"]] == 2
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", record)
    assert len(statements) == 2
    assert all(sql.lstrip().startswith("select") and "group by" in sql for sql in statements)


def test_missing_distance_is_unknown_and_failed_runs_do_not_count(domain):
    d = domain
    version = course(d)
    race(d, version, "Alice", frames=50)
    with d.factory() as session:
        row = session.get(TrackVersion, version["version_id"])
        row.manifest = {key: value for key, value in row.manifest.items() if key != "route_length"}
        session.commit()
        assert car_history(session, d.players["Alice"])["cars"]["compact"] == {"races": 1, "distance_m": None}
        for run in session.scalars(select(Run).where(Run.player_id == d.players["Alice"])):
            run.status = "rejected"
        session.commit()
        assert car_history(session, d.players["Alice"])["cars"]["compact"]["races"] == 0
        assert track_races(session, [version["version_id"]])[version["version_id"]] == 1


def test_artificial_disabled_and_nonordinary_runs_are_not_public_plays(domain):
    d = domain
    version = course(d)
    race(d, version, "Alice", frames=50)
    race(d, version, "Bob", frames=40)
    with d.factory() as session:
        session.get(Player, d.players["Bob"]).is_test_driver = True
        session.get(Player, d.players["Creator"]).disabled = True
        session.commit()
        assert track_races(session, [version["version_id"]])[version["version_id"]] == 1
        boards = session.scalars(select(Board).where(Board.version_id == version["version_id"])).all()
        for board in boards:
            board.manifest = {**board.manifest, "purpose": "creator_test"}
        session.commit()
        assert track_races(session, [version["version_id"]])[version["version_id"]] == 0
        assert car_history(session, d.players["Alice"])["totals"]["races"] == 0
