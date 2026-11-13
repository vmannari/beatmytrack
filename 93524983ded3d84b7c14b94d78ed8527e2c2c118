from copy import deepcopy
from dataclasses import replace

import pytest
from sqlalchemy import delete, select
from test_daily_build_variant import new_version
from test_daily_standings import auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend import daily_fixed_limits, track_of_day
from bmt_backend.daily_snapshot_preparation import schedule
from bmt_backend.discovery_models import TrackOfDay, TrackOfDayHistory
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.histogram_snapshots import refresh_one
from bmt_backend.identity_models import Player
from bmt_backend.track_models import HistogramDemand, HistogramSnapshot, Track, TrackVersion

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


def test_maintenance_preserves_clean_worker_backoff_while_renewing_interest(daily):
    d = daily
    original = prepare(d)
    stamp = d.day*86400+1200
    key = (d.version.id, "compact", False)
    with d.factory() as db:
        db.get(HistogramDemand, key).requested_until = stamp+100
        db.commit()
    assert refresh_one(d.app, clock=stamp, active_only=True)
    with d.factory() as db:
        snapshot = db.get(HistogramSnapshot, key)
        assert snapshot.generation and not snapshot.dirty and not snapshot.invalidated
        assert snapshot.next_refresh_at == stamp+60
        generation, payload = snapshot.generation, deepcopy(snapshot.payload)
    # The real worker postpones a clean snapshot without changing its expired
    # next_refresh_at. Maintenance must not undo that deliberate 60-second wait.
    assert refresh_one(d.app, clock=stamp+60, active_only=True)
    assert not track_of_day.step(d.factory, clock=stamp+90)
    assert not refresh_one(d.app, clock=stamp+90, active_only=True)
    with d.factory() as db:
        demand = db.get(HistogramDemand, key)
        assert demand.due_at == stamp+120
        assert demand.requested_until == stamp+690
        snapshot = db.get(HistogramSnapshot, key)
        assert snapshot.generation == generation and snapshot.payload == payload
        assert snapshot.next_refresh_at == stamp+60
        assert db.get(TrackOfDay, d.day).lap_limits == original
    assert not track_of_day.step(d.factory, clock=stamp+105)
    with d.factory() as db:
        demand = db.get(HistogramDemand, key)
        assert demand.due_at == stamp+120 and demand.requested_until == stamp+690


@pytest.mark.parametrize(("generation", "invalidated", "dirty", "expected_offset"), [
    ("", False, False, None),
    ("retained", True, False, None),
    ("retained", False, True, -10),
])
def test_maintenance_still_advances_missing_invalidated_and_dirty_work(
        daily, generation, invalidated, dirty, expected_offset):
    d = daily
    prepare(d)
    stamp = d.day*86400+1200
    key = (d.version.id, "compact", False)
    with d.factory() as db:
        demand = db.get(HistogramDemand, key)
        demand.due_at, demand.requested_until = stamp+120, stamp+600
        snapshot = db.get(HistogramSnapshot, key)
        snapshot.generation, snapshot.invalidated, snapshot.dirty = generation, invalidated, dirty
        snapshot.next_refresh_at = stamp-10
        snapshot.lease_token, snapshot.lease_until = "owned", stamp+240
        db.commit()
    assert not track_of_day.step(d.factory, clock=stamp)
    with d.factory() as db:
        demand = db.get(HistogramDemand, key)
        assert demand.due_at == (0 if expected_offset is None else stamp+expected_offset)
        assert demand.requested_until == stamp+600
        snapshot = db.get(HistogramSnapshot, key)
        assert snapshot.lease_token == "owned" and snapshot.lease_until == stamp+240


def test_build_variant_publication_and_maintenance_prepare_both_pinned_versions(daily, monkeypatch):
    d = daily
    original = prepare(d)
    stamp = d.day*86400+1200
    with d.factory() as db:
        variant = new_version(db, db.get(TrackVersion, d.version.id))
        variant_id = variant.id
        monkeypatch.setattr(daily_fixed_limits, "lap_population",
            lambda *args: HistogramPopulation.from_rows([("variant-fixture", 99)]))
        assert daily_fixed_limits.publish_build_variant(db, d.day, variant, variant.manifest, stamp)
        db.commit()
    expected = {(d.version.id, "compact", False), (variant_id, "compact", False)}
    with d.factory() as db:
        demands = list(db.scalars(select(HistogramDemand)))
        assert {(row.version_id, row.vehicle_id, row.include_artificial) for row in demands} == expected
        assert all(row.due_at == 0 for row in demands)
        chosen = db.get(TrackOfDay, d.day)
        limits = deepcopy(chosen.lap_limits)
        assert {key: value for key, value in limits.items() if key != "build_variant"} == original
        db.execute(delete(HistogramDemand))
        db.commit()
    assert not track_of_day.step(d.factory, clock=stamp+30)
    with d.factory() as db:
        demands = list(db.scalars(select(HistogramDemand)))
        assert {(row.version_id, row.vehicle_id, row.include_artificial) for row in demands} == expected
        assert all(row.requested_until == stamp+630 for row in demands)
        assert db.get(TrackOfDay, d.day).lap_limits == limits


def test_fresh_day_publication_queues_snapshot_before_any_reader(daily):
    d = daily
    finish(d, 120, "Alice")
    finish(d, 100, "Bob")
    settle_for_diagnostics(d.factory)
    stamp = d.day*86400+1200
    with d.factory() as db:
        assert db.get(TrackOfDay, d.day) is None
        assert list(db.scalars(select(HistogramDemand))) == []
    assert track_of_day.step(d.factory, clock=stamp)
    with d.factory() as db:
        chosen = db.get(TrackOfDay, d.day)
        assert chosen.version_id == d.version.id and chosen.selected_at == stamp
        assert chosen.lap_limits["vehicles"]["compact"]["population"] == 2
        assert db.get(TrackOfDayHistory, d.version.track_id).first_day == d.day
        demands = list(db.scalars(select(HistogramDemand)))
        assert len(demands) == 1
        assert (demands[0].version_id, demands[0].vehicle_id, demands[0].include_artificial) == (
            d.version.id, "compact", False)
        assert demands[0].due_at == 0 and demands[0].requested_until == stamp+600
    assert refresh_one(d.app, clock=stamp+1, active_only=True)
    result = d.client.get("/v1/track-of-the-day/lap-standings", params={
        "day": d.day, "version_id": d.version.id, "vehicle_id": "compact"})
    assert result.status_code == 200 and result.json()["population"] == 2


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
