from concurrent.futures import ThreadPoolExecutor

from alembic import command
from sqlalchemy import text
from test_daily_standings import auth, auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend import daily_fixed_limits, daily_standings, track_of_day
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import TrackVersion

daily = daily_fixture


def get_limits(d, *, day=None, headers=None):
    return d.client.get("/v1/track-of-the-day/limits", params={"day": d.day if day is None else day,
        "version_id": d.version.id, "vehicle_id": "compact"}, headers=headers or {})


def test_cutoffs_persist_across_improvements_refreshes_and_restart_until_next_day(daily, monkeypatch):
    d = daily
    finish(d, 120, "Alice")
    finish(d, 100, "Bob")
    feature(d)
    original_loader = daily_fixed_limits.lap_population
    computations = []

    def counted(*args):
        computations.append(args[2])
        return original_loader(*args)

    monkeypatch.setattr(daily_fixed_limits, "lap_population", counted)
    assert track_of_day.step(d.factory, clock=d.day*86400+10)
    first = get_limits(d).json()
    assert computations == ["compact"]
    assert [row["lap_ticks"] for row in first["cutoffs"]] == [24, 24, 20, 20, 20, 20, 20, 20, 20]
    finish(d, 50, "Bob")
    d.app.state.engine.dispose()  # New pooled connections must use the durable publication.
    assert not track_of_day.step(d.factory, clock=d.day*86400+80000)
    for headers in ({}, auth(d, "Alice"), auth(d, "Bob")):
        later = get_limits(d, headers=headers).json()
        assert later["cutoffs"] == first["cutoffs"] and later["generation"] == first["generation"]
        assert later["limits_set_at"] == d.day*86400+10
    assert computations == ["compact"]
    with d.factory() as db:
        db.add(TrackOfDay(day=d.day+1, policy="track-of-day-v1", track_id=d.version.track_id,
            version_id=d.version.id, reason="top", selected_at=(d.day+1)*86400))
        db.commit()
    assert track_of_day.step(d.factory, clock=(d.day+1)*86400+10)
    monkeypatch.setattr(daily_standings, "now", lambda: (d.day+1)*86400+100)
    tomorrow = get_limits(d, day=d.day+1).json()
    assert tomorrow["generation"] != first["generation"]
    assert tomorrow["cutoffs"][-1]["lap_ticks"] == 10
    assert computations == ["compact", "compact"]
    assert get_limits(d).status_code == 409


def test_new_daily_track_is_published_with_limits_already_selected(daily):
    d = daily
    finish(d, 120, "Alice")
    settle_for_diagnostics(d.factory)
    assert track_of_day.step(d.factory)
    with d.factory() as db:
        chosen = db.get(TrackOfDay, d.day)
        assert chosen.version_id == d.version.id
        assert chosen.lap_limits["vehicles"]["compact"]["population"] == 1
        assert all(row["lap_ticks"] == 24 for row in chosen.lap_limits["vehicles"]["compact"]["cutoffs"])
    assert d.client.get("/v1/track-of-the-day").status_code == 200
    assert get_limits(d).status_code == 200


def test_concurrent_publishers_select_limits_only_once(daily, monkeypatch):
    d = daily
    feature(d)
    computations = []

    def population(*args):
        computations.append(args[2])
        return HistogramPopulation.from_rows([("one", 1200), ("two", 2400)])

    monkeypatch.setattr(daily_fixed_limits, "lap_population", population)
    with ThreadPoolExecutor(max_workers=4) as workers:
        results = list(workers.map(lambda _: track_of_day.step(d.factory, clock=d.day*86400+10), range(4)))
    assert results.count(True) == 1 and computations == ["compact"]
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day).lap_limits["vehicles"]["compact"]["cutoffs"][0]["lap_ticks"] == 2400


def test_all_car_limits_are_selected_before_any_player_reads_them(daily, monkeypatch):
    d = daily
    feature(d)
    with d.factory() as db:
        version = db.get(TrackVersion, d.version.id)
        version.manifest = {**version.manifest, "vehicles": {**version.manifest["vehicles"],
            "pickup": {"handling_version": "pickup-test", "config_hash": "pickup-config"}}}
        db.commit()
    computed = []

    def population(session, version, vehicle, manifest, artificial):
        computed.append(vehicle)
        return HistogramPopulation.from_rows([("one", 1200 if vehicle == "compact" else 2400)])

    monkeypatch.setattr(daily_fixed_limits, "lap_population", population)
    assert track_of_day.step(d.factory)
    assert computed == ["compact", "pickup"]
    for vehicle, expected in (("compact", 1200), ("pickup", 2400)):
        response = d.client.get("/v1/track-of-the-day/limits", params={
            "day": d.day, "version_id": d.version.id, "vehicle_id": vehicle})
        assert response.status_code == 200, response.text
        assert all(row["lap_ticks"] == expected for row in response.json()["cutoffs"])
    assert computed == ["compact", "pickup"]


def test_reads_never_initialise_limits_and_empty_population_stays_fixed(daily, monkeypatch):
    d = daily
    feature(d)
    assert get_limits(d).status_code == 503
    assert d.client.get("/v1/track-of-the-day").status_code == 503
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day).lap_limits == {}
    monkeypatch.setattr(daily_fixed_limits, "lap_population", lambda *args: HistogramPopulation.from_rows([]))
    assert track_of_day.step(d.factory, clock=d.day*86400+10)
    monkeypatch.setattr(daily_fixed_limits, "lap_population", lambda *args: HistogramPopulation.from_rows([("new", 100)]))
    assert not track_of_day.step(d.factory, clock=d.day*86400+20)
    assert get_limits(d).json()["detail"] == "NO_FLYING_LAP_TIMES"


def test_pending_lap_backfill_does_not_publish_partial_limits(daily, monkeypatch):
    d = daily
    feature(d)

    def pending(*args):
        raise daily_fixed_limits.LimitsPending("fixture")

    monkeypatch.setattr(daily_fixed_limits, "lap_population", pending)
    assert not track_of_day.step(d.factory)
    assert get_limits(d).status_code == 503
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day).lap_limits == {}


def test_migration_retains_existing_daily_selection(daily):
    d = daily
    feature(d)
    command.downgrade(configuration(d.app.state.engine), "0071_track_of_day_bests")
    with d.app.state.engine.connect() as connection:
        assert connection.scalar(text("SELECT version_id FROM track_of_days WHERE day=:day"), {"day": d.day}) == d.version.id
    upgrade(d.app.state.engine)
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day).version_id == d.version.id
        assert db.get(TrackOfDay, d.day).lap_limits == {}
