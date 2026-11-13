from copy import deepcopy
from dataclasses import replace

from sqlalchemy import delete, select
from test_daily_standings import auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend import track_of_day
from bmt_backend.daily_snapshot_preparation import schedule
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.histogram_snapshots import refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.track_models import HistogramDemand, HistogramSnapshot, Track

daily = daily_fixture


def prepare(d):
    finish(d, 120, "Alice")
    finish(d, 100, "Bob")
    feature(d)
    assert track_of_day.step(d.factory)
    with d.factory() as db:
        chosen = db.get(TrackOfDay, d.day)
        return deepcopy(chosen.lap_limits)


def test_first_reader_gets_a_worker_prepared_snapshot_without_demand_get(daily):
    d = daily
    limits = prepare(d)
    with d.factory() as db:
        demands = list(db.scalars(select(HistogramDemand)))
        assert [(row.version_id, row.vehicle_id, row.include_artificial) for row in demands] == [
            (d.version.id, "compact", False)]
        assert demands[0].due_at == 0
        snapshot = db.get(HistogramSnapshot, (d.version.id, "compact", False))
        assert snapshot.generation == ""
    assert refresh_one(d.app, active_only=True)
    result = d.client.get("/v1/track-of-the-day/lap-standings", params={
        "day": d.day, "version_id": d.version.id, "vehicle_id": "compact"})
    assert result.status_code == 200, result.text
    assert result.json()["population"] == 2
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day).lap_limits == limits


def test_maintenance_renews_interest_without_changing_limits_or_snapshot(daily):
    d = daily
    original = prepare(d)
    stamp = d.day*86400+1200
    with d.factory() as db:
        demand = db.get(HistogramDemand, (d.version.id, "compact", False))
        demand.requested_until = stamp-1
        demand.due_at = 12
        snapshot = db.get(HistogramSnapshot, (d.version.id, "compact", False))
        snapshot.generation = "retained"
        snapshot.invalidated = False
        snapshot.next_refresh_at = stamp+50
        snapshot.payload = {"preserved": True}
        snapshot.lease_token = "owned"
        snapshot.lease_until = stamp+200
        db.commit()
    assert not track_of_day.step(d.factory, clock=stamp)
    with d.factory() as db:
        demand = db.get(HistogramDemand, (d.version.id, "compact", False))
        assert demand.due_at == 12 and demand.requested_until == stamp+600
        snapshot = db.get(HistogramSnapshot, (d.version.id, "compact", False))
        assert snapshot.generation == "retained" and snapshot.payload == {"preserved": True}
        assert snapshot.lease_token == "owned" and snapshot.lease_until == stamp+200
        assert db.get(TrackOfDay, d.day).lap_limits == original
    assert not track_of_day.step(d.factory, clock=stamp+30)
    with d.factory() as db:
        assert db.get(HistogramDemand, (d.version.id, "compact", False)).requested_until == stamp+600


def test_population_day_visibility_and_atomic_rollback_fences(daily):
    d = daily
    prepare(d)
    stamp = d.day*86400+600
    with d.factory() as db:
        db.execute(delete(HistogramDemand))
        chosen = db.get(TrackOfDay, d.day)
        chosen.lap_limits = {**chosen.lap_limits, "include_artificial": True}
        assert db.get(HistogramSnapshot, (d.version.id, "compact", True)) is not None
        db.commit()
    with d.factory() as db:
        chosen = db.get(TrackOfDay, d.day)
        schedule(db, chosen, stamp, include_artificial=True)
        assert list(db.scalars(select(HistogramDemand.include_artificial))) == [True]
        db.rollback()
    with d.factory() as db:
        assert list(db.scalars(select(HistogramDemand))) == []
        chosen = db.get(TrackOfDay, d.day)
        schedule(db, chosen, stamp+86400, include_artificial=True)
        assert list(db.scalars(select(HistogramDemand))) == []
        track = db.get(Track, d.version.track_id)
        track.hidden = True
        db.flush()
        schedule(db, chosen, stamp, include_artificial=True)
        assert list(db.scalars(select(HistogramDemand))) == []
        track.hidden = False
        owner = db.get(Player, track.owner_id)
        owner.disabled = True
        db.flush()
        schedule(db, chosen, stamp, include_artificial=True)
        assert list(db.scalars(select(HistogramDemand))) == []
        owner.disabled = False
        db.flush()
        schedule(db, chosen, (d.day+1)*86400-30, include_artificial=False)
        demands = list(db.scalars(select(HistogramDemand)))
        assert len(demands) == 1 and not demands[0].include_artificial
        assert demands[0].requested_until == (d.day+1)*86400


def test_prewarming_never_enables_disabled_artificial_worker_population(daily):
    d = daily
    prepare(d)
    with d.factory() as db:
        db.execute(delete(HistogramDemand))
        chosen = db.get(TrackOfDay, d.day)
        chosen.lap_limits = {**chosen.lap_limits, "include_artificial": True}
        assert db.get(HistogramSnapshot, (d.version.id, "compact", True)) is not None
        schedule(db, chosen, d.day*86400+120, include_artificial=True)
        db.commit()
    d.app.state.settings = replace(d.app.state.settings, test_drivers_enabled=False)
    # The existing worker owns this independent permission fence.
    assert refresh_one(d.app, clock=d.day*86400+121, active_only=True)
    with d.factory() as db:
        assert db.get(HistogramSnapshot, (d.version.id, "compact", True)).generation == ""
        assert db.get(HistogramDemand, (d.version.id, "compact", True)) is None
