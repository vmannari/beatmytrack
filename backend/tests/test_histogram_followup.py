"""Bounded cache/storage, private validators, demand and reserved refresh turns."""
import pytest
from alembic import command
from sqlalchemy import delete, event, select
from test_compact_histograms import compact_threshold, route
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, race

from bmt_backend import board_cache, runs, worker
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.histogram_snapshots import load_snapshot, refresh_all_for_diagnostics, refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import HistogramDemand, HistogramSnapshot, LapBestState, PersonalBest

domain = domain_fixture


def test_packed_immutable_counts_and_large_integer_populations():
    field = HistogramPopulation.from_frequencies([(1, 500000000), (216000, 5000000000)])
    assert field.cumulative[-1] == 5500000000
    assert list(field.counts) == [500000000, 5000000000]
    assert field.ticks.readonly and field.cumulative.readonly
    assert isinstance(field.ticks.obj, bytes) and isinstance(field.cumulative.obj, bytes)
    assert field.ticks.nbytes + field.cumulative.nbytes == 32
    with pytest.raises(TypeError):
        field.cumulative[1] = 0
    payload = field.snapshot_payload("board", "race")
    assert payload["counts"] == []
    assert payload["cumulative"][-1] == 5500000000
    restored = HistogramPopulation(None, payload["ticks"], payload["counts"], payload["cumulative"], payload["histogram"])
    assert list(restored.counts) == list(field.counts)


def test_cache_retains_more_than_four_tracks_within_weight_budget(domain):
    version, _ = public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    with domain.factory() as session:
        for number in range(12):
            row = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
            row.generation = "cache-generation-" + str(number)
            session.commit()
            load_snapshot(session, version["version_id"], "compact", False)
    cache = board_cache._caches[domain.app.state.engine]["histogram-snapshots"]
    assert len(cache) >= 12
    assert sum(field.cache_weight for fields in cache.values() for field in fields) <= 128*1024*1024


def test_both_personal_markers_share_one_bounded_query(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    statements = []
    def record(_conn, _cursor, sql, *_):
        statements.append(sql)
    with domain.factory() as session:
        event.listen(domain.app.state.engine, "before_cursor_execute", record)
        try:
            values = runs.comparison_own_times(session, board_ids=[board], public_id=board, test_id="absent",
                include_artificial=False, player_id=domain.players["Alice"], metrics=["race", "best_lap"])
        finally:
            event.remove(domain.app.state.engine, "before_cursor_execute", record)
    assert values == {"race":100, "best_lap":20}
    assert len(statements) == 1 and "UNION ALL" in statements[0]
    assert "personal_bests.player_id =" in statements[0] and "lap_personal_bests.player_id =" in statements[0]


def test_conditional_responses_are_private_and_skip_histogram_work(domain, monkeypatch):
    version, board = public_course(domain)
    refresh_all_for_diagnostics(domain.app)
    first = domain.client.get(route(version), headers=headers(domain))
    assert first.status_code == 200 and "private" in first.headers["cache-control"]
    tag = first.headers["etag"]
    def forbidden(*_args, **_kwargs):
        raise AssertionError("304 built a response histogram")
    monkeypatch.setattr(runs, "population_comparison", forbidden)
    repeated = domain.client.get(route(version), headers={**headers(domain), "If-None-Match":'"other", W/'+tag})
    assert repeated.status_code == 304 and repeated.content == b""
    assert repeated.headers["vary"] == "Authorization"
    monkeypatch.undo()
    for url, who in ((route(version), "Alice"), (route(version)+"&race_ticks=101", "Creator"),
                     (route(version)+"&bins=30", "Creator"),
                     (route(version)+"&race_from_ticks=10&race_to_ticks=1000", "Creator")):
        response = domain.client.get(url, headers={**headers(domain, who), "If-None-Match":tag})
        assert response.status_code == 200 and response.headers["etag"] != tag
    public_url = f"/v1/boards/{board}/histogram"
    public = domain.client.get(public_url)
    assert public.status_code == 200
    assert domain.client.get(public_url, headers={"If-None-Match":public.headers["etag"]}).status_code == 304
    with domain.factory() as session:
        session.get(Player, domain.players["Creator"]).disabled = True
        session.commit()
    assert domain.client.get(route(version), headers={**headers(domain), "If-None-Match":tag}).status_code != 304


def test_live_pb_and_visibility_fence_old_validators(domain, monkeypatch):
    compact_threshold(monkeypatch)
    version, _ = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    refresh_all_for_diagnostics(domain.app)
    first = domain.client.get(route(version), headers=headers(domain, "Alice"))
    race(domain, version, "Alice", frames=10)
    changed = domain.client.get(route(version), headers={**headers(domain, "Alice"), "If-None-Match":first.headers["etag"]})
    assert changed.status_code == 200 and changed.json()["race"]["own_best_ticks"] == 50
    with domain.factory() as session:
        session.get(Player, domain.players["Bob"]).disabled = True
        session.commit()
    hidden = domain.client.get(route(version), headers={**headers(domain, "Alice"), "If-None-Match":changed.headers["etag"]})
    assert hidden.status_code == 503


def test_interest_is_coalesced_and_only_requested_fields_refresh(domain):
    version, _ = public_course(domain)
    assert not refresh_one(domain.app, active_only=True)
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 503
    with domain.factory() as session:
        interest = session.get(HistogramDemand, (version["version_id"], "compact", False))
        assert interest is not None
        expiry = interest.requested_until
    for _ in range(3):
        domain.client.get(route(version), headers=headers(domain))
    with domain.factory() as session:
        assert session.get(HistogramDemand, (version["version_id"], "compact", False)).requested_until == expiry
    assert refresh_one(domain.app, active_only=True)
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 200
    with domain.factory() as session:
        row = session.get(HistogramSnapshot, (version["version_id"], "compact", False))
        generation, due = row.generation, row.next_refresh_at
        interest = session.get(HistogramDemand, (version["version_id"], "compact", False))
        interest.requested_until = due+600
        session.commit()
    # Unchanged requested fields advance their demand rather than spinning.
    assert refresh_one(domain.app, clock=due, active_only=True)
    assert not refresh_one(domain.app, clock=due, active_only=True)
    with domain.factory() as session:
        assert session.get(HistogramSnapshot, (version["version_id"], "compact", False)).generation == generation


def test_continuous_foreground_work_gets_reserved_histogram_turn(domain, monkeypatch):
    version, board = public_course(domain)
    with domain.factory() as session:
        session.get(LapBestState, board).complete = False
        session.commit()
    domain.client.get(route(version), headers=headers(domain))
    monkeypatch.setattr(worker, "process_one", lambda *_args, **_kwargs: True)
    for _ in range(16):
        assert worker.process_worker_job(domain.app)
    with domain.factory() as session:
        assert session.get(LapBestState, board).complete
    for _ in range(16):
        assert worker.process_worker_job(domain.app)
    with domain.factory() as session:
        assert session.get(HistogramSnapshot, (version["version_id"], "compact", False)).generation


def test_demand_migration_roundtrip_preserves_results(domain):
    version, _ = public_course(domain)
    with domain.factory() as session:
        before = session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks)).all()
    command.downgrade(configuration(domain.app.state.engine), "0051_telemetry_parallel")
    upgrade(domain.app.state.engine)
    with domain.factory() as session:
        assert session.execute(select(PersonalBest.player_id, PersonalBest.time_ticks)).all() == before
        assert session.execute(select(HistogramDemand)).all() == []
    assert domain.client.get(route(version), headers=headers(domain)).status_code == 503


def test_expired_interest_is_retired_in_bounded_chunks(domain):
    version, _ = public_course(domain)
    with domain.factory() as session:
        session.add_all(HistogramDemand(version_id=version["version_id"], vehicle_id=str(i), include_artificial=False,
            due_at=0, requested_until=0) for i in range(220))
        session.commit()
    refresh_one(domain.app, clock=100, active_only=True)
    with domain.factory() as session:
        assert len(session.scalars(select(HistogramDemand)).all()) == 120
        session.execute(delete(HistogramDemand))
        session.commit()
