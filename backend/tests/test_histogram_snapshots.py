"""Durability, throttling and safety of background comparison snapshots."""
from sqlalchemy import event, select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race, submit, ticket

from bmt_backend import board_cache, runs
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.histogram_snapshots import refresh_all_for_diagnostics, refresh_interval, refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.track_models import Board, HistogramSnapshot, OperationState, PersonalBest, Run

domain = domain_fixture


def route(version):
    return f"/v1/track-versions/{version['version_id']}/results-comparison?vehicle_id=compact"


def snapshot(domain, version):
    with domain.factory() as session:
        return session.get(HistogramSnapshot, (version["version_id"], "compact", False))


def test_population_controls_refresh_interval():
    assert refresh_interval(10) == 90
    assert refresh_interval(1000) == 900
    assert refresh_interval(100000) == 3600
    assert refresh_interval(0) == 60


def test_gets_serve_durable_grid_without_generation(domain, monkeypatch):
    version, _ = public_course(domain)
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 503
    race(domain, version, "Alice", frames=20)
    refresh_all_for_diagnostics(domain.app)
    def forbidden(*args, **kwargs):
        raise AssertionError("GET attempted histogram generation")
    monkeypatch.setattr(runs, "comparison_populations", forbidden)
    monkeypatch.setattr(HistogramPopulation, "histogram", forbidden)
    creator = domain.client.get(route(version), headers=headers(domain)).json()
    assert creator["race"]["own_best_ticks"] == 300
    for _ in range(3):
        assert domain.client.get(route(version), headers=headers(domain)).json() == creator
    alice = domain.client.get(route(version), headers=headers(domain, "Alice")).json()
    assert alice["race"]["own_best_ticks"] == 100
    assert alice["race"]["comparison"]["position"] == 1
    assert creator["race"]["comparison"]["position"] == 2
    assert creator["race"]["bins"] == alice["race"]["bins"]
    # Simulate a cold API process: durable data still serves without rebuilding.
    with board_cache._lock:
        board_cache._caches.pop(domain.app.state.engine, None)
    statements = []
    def record(_conn, _cursor, sql, *_):
        statements.append(sql)
    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        assert domain.client.get(route(version), headers=headers(domain)).json() == creator
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    assert not any("FROM runs" in sql or "FROM personal_bests" in sql for sql in statements)


def test_new_times_wait_for_due_refresh(domain):
    version, _ = public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    before = domain.client.get(route(version), headers=headers(domain)).json()
    due = snapshot(domain, version).next_refresh_at
    race(domain, version, "Alice", frames=20)
    for _ in range(3):
        assert domain.client.get(route(version), headers=headers(domain)).json() == before
    assert not refresh_one(domain.app, clock=due-1)
    assert refresh_one(domain.app, clock=due)
    after = domain.client.get(route(version), headers=headers(domain)).json()
    assert after["race"]["population"] == after["best_lap"]["population"] == 2
    assert after["stats_revision"] > before["stats_revision"]
    assert snapshot(domain, version).next_refresh_at > due


def test_unchanged_due_snapshot_never_rebuilds(domain, monkeypatch):
    version, _ = public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    before = snapshot(domain, version)
    def forbidden(*args, **kwargs):
        raise AssertionError("Unchanged population rebuilt")
    monkeypatch.setattr(runs, "comparison_populations", forbidden)
    assert not refresh_one(domain.app, clock=before.next_refresh_at)
    after = snapshot(domain, version)
    assert after.generation == before.generation and after.updated_at == before.updated_at
    assert after.next_refresh_at == before.next_refresh_at and not after.dirty


def test_lap_only_improvement_is_dirty_without_race_pb_change(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    slower = race(domain, version, "Alice", frames=25)
    refresh_all_for_diagnostics(domain.app)
    before = domain.client.get(route(version), headers=headers(domain, "Alice")).json()
    due = snapshot(domain, version).next_refresh_at
    with domain.factory() as session:
        revision = session.get(Board, board).stats_revision
        session.get(Run, slower["run_id"]).lap_ticks = [1, 5, 30, 30, 30]
        session.commit()
        assert session.get(Board, board).stats_revision == revision
    assert domain.client.get(route(version), headers=headers(domain, "Alice")).json() == before
    assert refresh_one(domain.app, clock=due)
    after = domain.client.get(route(version), headers=headers(domain, "Alice")).json()
    assert after["race"]["own_best_ticks"] == before["race"]["own_best_ticks"]
    assert after["best_lap"]["own_best_ticks"] == 5


def test_visibility_invalidates_but_artificial_reset_leaves_public_unchanged(domain):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        session.get(Player, domain.players["Alice"]).disabled = True
        session.commit()
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 503
    refresh_all_for_diagnostics(domain.app)
    assert domain.client.get(route(version), headers=headers(domain)).json()["race"]["population"] == 1
    generation = snapshot(domain, version).generation
    with domain.factory() as session:
        session.add(OperationState(id="test-pop-batch:snapshot-reset", details={"vehicle_id":"compact",
            "request":{"clear_test_records":True}, "created_at":100, "tracks":[{"version_id":version["version_id"]}]}))
        session.commit()
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 200
    refresh_all_for_diagnostics(domain.app)
    assert snapshot(domain, version).generation == generation
    with domain.factory() as session:
        row = session.get(OperationState, "test-pop-batch:snapshot-reset")
        row.details = {**row.details, "progress":50}
        session.commit()
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 200
    assert snapshot(domain, version).generation == generation


def test_active_refresh_lease_prevents_another_builder(domain):
    version, _ = public_course(domain)
    with domain.factory() as session:
        row = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        row.lease_until = 2000
        session.commit()
    assert not refresh_one(domain.app, clock=1999)
    assert refresh_one(domain.app, clock=2000)


def test_snapshot_overlay_does_not_mutate_shared_counts(domain):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    refresh_all_for_diagnostics(domain.app)
    baseline = domain.client.get(route(version), headers=headers(domain)).json()
    candidate = domain.client.get(route(version)+"&race_ticks=50&lap_ticks=5", headers=headers(domain)).json()
    assert candidate["race"]["population"] == candidate["best_lap"]["population"] == 2
    assert candidate["race"]["comparison"]["position"] == 1
    assert domain.client.get(route(version), headers=headers(domain)).json() == baseline


def test_migration_backfills_snapshots_without_rewriting_results(domain):
    from alembic import command

    from bmt_backend.migrate import configuration, upgrade
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    with domain.factory() as session:
        records = session.execute(select(Run.id, Run.status, Run.lap_ticks)).all()
        pbs = session.execute(select(PersonalBest.board_id, PersonalBest.player_id, PersonalBest.time_ticks)).all()
    command.downgrade(configuration(domain.app.state.engine), "0021_challenge_attempts")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert session.execute(select(Run.id, Run.status, Run.lap_ticks)).all() == records
        assert session.execute(select(PersonalBest.board_id, PersonalBest.player_id, PersonalBest.time_ticks)).all() == pbs
    assert snapshot(domain, version).generation == ""
    refresh_all_for_diagnostics(domain.app)
    assert domain.client.get(route(version), headers=headers(domain)).json()["race"]["population"] == 2


def test_visibility_change_during_refresh_never_publishes_old_population(domain, monkeypatch):
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    original = runs.comparison_populations
    def invalidate_after_read(*args, **kwargs):
        value = original(*args, **kwargs)
        with domain.factory() as session:
            session.get(Player, domain.players["Alice"]).disabled = True
            session.commit()
        return value
    monkeypatch.setattr(runs, "comparison_populations", invalidate_after_read)
    assert refresh_one(domain.app)
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 503
    monkeypatch.setattr(runs, "comparison_populations", original)
    assert refresh_one(domain.app)
    assert domain.client.get(route(version), headers=headers(domain)).json()["race"]["population"] == 1


def test_service_worker_verifies_player_before_idle_histogram(domain):
    from bmt_backend.worker import process_worker_job
    version, _ = public_course(domain)
    queued = submit(domain, ticket(domain, version, "Alice"), "Alice", frames=20)
    assert process_worker_job(domain.app)
    with domain.factory() as session:
        assert session.get(Run, queued["run_id"]).status == "verified"
    assert snapshot(domain, version).generation == ""
    assert process_worker_job(domain.app)
    assert snapshot(domain, version).generation != ""
