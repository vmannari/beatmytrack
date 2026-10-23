"""Population-independent comparison payloads and bounded personal overlays."""
import json
import random

import pytest
from sqlalchemy import Column, Integer, MetaData, String, Table, create_engine, event, select
from sqlalchemy.orm import Session
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race

from bmt_backend import board_cache, histogram_population, histogram_snapshots, runs
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.track_models import HistogramSnapshot

domain = domain_fixture


def route(version):
    return f"/v1/track-versions/{version['version_id']}/results-comparison?vehicle_id=compact"


def test_ten_million_weighted_results_need_three_tick_entries(monkeypatch):
    field = HistogramPopulation.from_frequencies([(100, 9500000), (101, 499999), (216000, 1)])
    calls = []
    original = histogram_population.bisect_left

    def searched(values, boundary):
        calls.append(boundary)
        return original(values, boundary)

    monkeypatch.setattr(histogram_population, "bisect_left", searched)
    grid = field.histogram("board", "race", 30, *field.frame(None, None, None))
    assert sum(row["count"] for row in grid["bins"]) == 10000000
    assert len(calls) == len(grid["bins"]) + 1
    assert field.own is None and len(field.ticks) == 3
    assert field.position(101, None)["position"] == 9500001
    assert field.position(100, 100)["position"] == 1


def test_frequency_bins_and_exact_small_overlays_match_reference():
    rng = random.Random(22102026)
    for size in range(100):
        values = {str(i): rng.randrange(1, 200) for i in range(size)}
        field = HistogramPopulation.from_rows(values.items())
        for candidate in (None, 1, 100, 250):
            start, end = field.frame(candidate, 20, 220)
            grid = field.histogram("board", "race", 30, start, end)
            assert sum(row["count"] for row in grid["bins"]) == size
            for row in grid["bins"]:
                assert row["count"] == sum(row["from_ticks"] <= tick < row["to_ticks_exclusive"]
                                           for tick in values.values())
            own = values.get("0")
            result = field.position(candidate or own, own)
            opponents = [tick for key, tick in values.items() if key != "0"]
            if not opponents or candidate is None and own is None:
                assert result is None
            else:
                assert result["position"] == 1 + sum(tick < (candidate or own) for tick in opponents)


def test_sql_generation_does_not_fetch_driver_rows_above_real_cap(monkeypatch):
    engine = create_engine("sqlite://")
    table = Table("owned_histogram_source", MetaData(), Column("player_id", String, primary_key=True),
                  Column("time_ticks", Integer))
    table.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(table.insert(), [{"player_id": str(i), "time_ticks": 100 + i % 3}
                                            for i in range(histogram_population.SNAPSHOT_OWN_LIMIT + 1)])
    source = select(table).subquery()
    monkeypatch.setattr(runs, "comparison_statements", lambda *_args: (source, source))
    statements = []

    def record(_conn, _cursor, sql, *_args):
        statements.append(sql)

    event.listen(engine, "before_cursor_execute", record)
    try:
        with Session(engine) as session:
            fields = runs.comparison_populations(session, ["public", "test"], "public", "test", True)
            assert all(field.own is None and len(field.ticks) == 3 for field in fields)
            assert all(field.cumulative[-1] == 4097 for field in fields)
        assert len(statements) == 2 and all("GROUP BY" in sql for sql in statements)
    finally:
        engine.dispose()


def compact_threshold(monkeypatch):
    # Exercise the production branch with three real verified drivers; existing
    # assertions for small frozen fields run unchanged in their original suites.
    monkeypatch.setattr(runs, "SNAPSHOT_OWN_LIMIT", 2)
    monkeypatch.setattr(histogram_snapshots, "SNAPSHOT_OWN_LIMIT", 2)


def test_large_snapshot_uses_indexed_markers_and_no_player_map(domain, monkeypatch):
    compact_threshold(monkeypatch)
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=12)
    histogram_snapshots.refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        stored = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        assert stored.payload["format"] == 3
        assert stored.payload["race"]["own"] == {}
        assert stored.payload["best_lap"]["own"] == {}
        assert stored.payload["race"]["own_mode"] == "indexed"
        assert stored.population == 3
    first = domain.client.get(route(version), headers=headers(domain, "Alice")).json()
    assert first["race"]["own_best_ticks"] == 100
    assert first["race"]["comparison_approximate"] is True
    assert sum(row["count"] for row in first["race"]["bins"]) == 3
    race(domain, version, "Alice", frames=10)
    second = domain.client.get(route(version) + "&race_ticks=75", headers=headers(domain, "Alice")).json()
    assert second["race"]["own_best_ticks"] == 50
    assert second["race"]["population"] == 3
    assert 1 <= second["race"]["comparison"]["position"] <= 3
    assert abs(second["race"]["comparison"]["position"] - 2) <= 1
    # A compact map must not mix another driver's personal marker into a cache.
    bob = domain.client.get(route(version), headers=headers(domain, "Bob")).json()
    assert bob["race"]["own_best_ticks"] == 60
    assert bob["race"]["bins"] == first["race"]["bins"]


@pytest.mark.parametrize("legacy", [False, True])
def test_ten_million_snapshot_cache_is_shared_and_legacy_map_not_selected(domain, legacy):
    version, _ = public_course(domain)
    field = HistogramPopulation.from_frequencies([(100, 9500000), (101, 499999), (216000, 1)])
    grid = field.histogram("board", "race", 16, *field.frame(None, None, None))
    metric = {"ticks": list(field.ticks), "counts": list(field.counts), "cumulative": list(field.cumulative),
              "histogram": grid, "own": {"legacy-private-id": 100} if legacy else None}
    with domain.factory() as session:
        stored = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        stored.generation = "owned-scale-generation"
        stored.population = 10000000
        stored.invalidated = False
        stored.payload = {"race": metric, "best_lap": metric, **({} if legacy else {"format": 2})}
        session.commit()
    statements = []

    def record(_conn, _cursor, sql, *_args):
        statements.append(sql)

    with board_cache._lock:
        board_cache._caches.pop(domain.app.state.engine, None)
    event.listen(domain.app.state.engine, "before_cursor_execute", record)
    try:
        for _ in range(2):
            with domain.factory() as session:
                _, _, fields = histogram_snapshots.load_snapshot(session, version["version_id"], "compact", False)
                assert fields[0].own is fields[1].own is None
                assert fields[0].cumulative[-1] == 10000000
    finally:
        event.remove(domain.app.state.engine, "before_cursor_execute", record)
    payload_reads = [sql for sql in statements if "JSON" in sql.upper() or " -> " in sql]
    assert len(payload_reads) == 1
    assert all("SELECT histogram_snapshots.payload \n" not in sql for sql in statements)


def test_personal_queries_filter_driver_before_deduplication(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    with domain.factory() as session:
        race_query, lap_query = runs.comparison_statements(session, [board], board, "absent", False,
                                                         domain.players["Alice"])
        assert len(session.execute(select(race_query)).all()) == 1
        assert len(session.execute(select(lap_query)).all()) == 1
        sql = str(select(lap_query).compile(compile_kwargs={"literal_binds": True}))
        assert "lap_personal_bests.player_id = '" + domain.players["Alice"] in sql


def test_approximation_never_changes_exact_snapshot_counts():
    field = HistogramPopulation.from_frequencies([(100, 3), (200, 1)])
    before = json.dumps(field.histogram("board", "race", 16, 1, 201), sort_keys=True)
    for candidate, own in ((1, 300), (300, 1), (100, 100), (200, None)):
        result = field.position(candidate, own)
        assert 1 <= result["position"] <= result["population"]
    assert json.dumps(field.histogram("board", "race", 16, 1, 201), sort_keys=True) == before
