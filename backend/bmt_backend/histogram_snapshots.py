"""Throttled durable histogram refreshes, performed by the idle worker."""
import logging
import math
from types import MappingProxyType

from sqlalchemy import delete, or_, select, tuple_, update
from sqlalchemy.orm import defer

from .board_cache import cached
from .histogram_population import SNAPSHOT_OWN_LIMIT, HistogramPopulation
from .track_models import (
    Board,
    HistogramDemand,
    HistogramSnapshot,
    LapBestState,
    TrackVersion,
    digest,
    new_id,
    now,
)

logger = logging.getLogger("bmt.histograms")


def refresh_interval(population, base=900):
    # 1,000 drivers: 15 minutes by default. Smaller fields refresh sooner;
    # large fields reach an hour. Never rebuild in response to a GET.
    return max(60, min(3600, math.ceil(base * math.sqrt(max(1, population) / 1000))))


def snapshot_key(version_id, vehicle_id, include_artificial):
    return {"version_id": version_id, "vehicle_id": vehicle_id, "include_artificial": include_artificial}


def load_snapshot(session, version_id, vehicle_id, include_artificial, *, metadata_out=None):
    key = snapshot_key(version_id, vehicle_id, include_artificial)
    metadata = session.execute(select(HistogramSnapshot.generation, HistogramSnapshot.source_revision,
                                     HistogramSnapshot.invalidated, HistogramSnapshot.population,
                                     HistogramSnapshot.updated_at, HistogramSnapshot.next_refresh_at).filter_by(**key)).first()
    if metadata is None or not metadata.generation or metadata.invalidated:
        return None
    if metadata_out is not None:
        metadata_out.update(generated_at=metadata.updated_at, expires_at=metadata.next_refresh_at)
    def load():
        query = select(HistogramSnapshot.payload).filter_by(**key).where(
            HistogramSnapshot.generation == metadata.generation, HistogramSnapshot.invalidated.is_(False))
        if metadata.population <= SNAPSHOT_OWN_LIMIT:
            payload = session.scalar(query)
        else:
            # Also upgrades old population-sized payloads without downloading
            # their legacy own maps. The worker writes compact JSON next time.
            names = ("ticks", "counts", "cumulative", "histogram")
            row = session.execute(query.with_only_columns(*(
                HistogramSnapshot.payload[metric][name]
                for metric in ("race", "best_lap") for name in names))).first()
            payload = ({metric: dict(zip(names, row[index*4:(index+1)*4]))
                        for index, metric in enumerate(("race", "best_lap"))} if row is not None else None)
        if payload is None:
            return None
        return tuple(HistogramPopulation(MappingProxyType(payload[metric]["own"])
            if payload[metric].get("own") is not None and payload[metric].get("own_mode") != "indexed" else None,
            tuple(payload[metric]["ticks"]), tuple(payload[metric]["counts"]), tuple(payload[metric]["cumulative"]),
            payload[metric]["histogram"]) for metric in ("race", "best_lap"))
    populations = cached(session, ("durable", version_id, vehicle_id, include_artificial, metadata.generation), load,
                         namespace="histogram-snapshots", max_entries=128, max_weight=128*1024*1024,
                         weight=lambda fields: sum(field.cache_weight for field in fields) if fields is not None else 0)
    if populations is None:
        return None
    return metadata.generation, metadata.source_revision, populations


def refresh_one(app, *, clock=None, active_only=False):
    from .runs import board_manifest, comparison_populations
    clock = now() if clock is None else clock
    token = new_id()
    with app.state.session_factory() as session:
        if active_only and getattr(app.state, "histogram_demand_cleanup_at", 0) <= clock:
            app.state.histogram_demand_cleanup_at = clock+60
            expired = select(HistogramDemand.version_id, HistogramDemand.vehicle_id, HistogramDemand.include_artificial).where(
                HistogramDemand.requested_until < clock).order_by(HistogramDemand.requested_until).limit(100)
            retired = session.execute(delete(HistogramDemand).where(tuple_(HistogramDemand.version_id, HistogramDemand.vehicle_id,
                HistogramDemand.include_artificial).in_(expired)), execution_options={"synchronize_session":False})
            session.commit()
            if retired.rowcount:
                return True
        demand = None
        if active_only:
            # Claim the head of the interest index first. A join with expiry or
            # lease filters before LIMIT could scan every expired/busy track.
            demand = session.scalar(select(HistogramDemand).where(HistogramDemand.due_at <= clock).order_by(
                HistogramDemand.due_at, HistogramDemand.version_id, HistogramDemand.vehicle_id,
                HistogramDemand.include_artificial).with_for_update(skip_locked=True).limit(1))
            if demand is None:
                return False
            if demand.requested_until < clock or (demand.include_artificial and not app.state.settings.test_drivers_enabled):
                session.delete(demand)
                session.commit()
                return True
        query = select(HistogramSnapshot).options(defer(HistogramSnapshot.payload)).join(
            TrackVersion, TrackVersion.id == HistogramSnapshot.version_id).where(
            TrackVersion.state == "published", HistogramSnapshot.next_refresh_at <= clock,
            HistogramSnapshot.lease_until <= clock)
        if active_only:
            query = query.where(HistogramSnapshot.version_id == demand.version_id,
                HistogramSnapshot.vehicle_id == demand.vehicle_id, HistogramSnapshot.include_artificial == demand.include_artificial)
            order = ()
        else:
            query = query.where(or_(HistogramSnapshot.dirty.is_(True), HistogramSnapshot.invalidated.is_(True)))
            order = (HistogramSnapshot.next_refresh_at, HistogramSnapshot.version_id,
                     HistogramSnapshot.vehicle_id, HistogramSnapshot.include_artificial)
        if not app.state.settings.test_drivers_enabled:
            query = query.where(HistogramSnapshot.include_artificial.is_(False))
        row = session.scalar(query.order_by(*order).with_for_update(skip_locked=True, of=HistogramSnapshot).limit(1))
        if row is None:
            if demand is not None:
                demand.due_at = clock+30
                session.commit()
                return True
            return False
        key = snapshot_key(row.version_id, row.vehicle_id, row.include_artificial)
        if active_only and not row.dirty and not row.invalidated:
            session.execute(update(HistogramDemand).filter_by(**key).values(due_at=clock+60))
            session.commit()
            return True
        # A lease survives worker death; conditional finalization fences old workers.
        claimed = session.execute(update(HistogramSnapshot).filter_by(**key).where(
            HistogramSnapshot.lease_until <= clock).values(lease_token=token, lease_until=clock+240))
        if claimed.rowcount != 1:
            session.rollback()
            return False
        source, previous_generation, invalidated, population = row.source_fingerprint, row.generation, row.invalidated, row.population
        session.commit()
    try:
        with app.state.session_factory() as session:
            if app.state.engine.dialect.name == "postgresql":
                session.connection(execution_options={"isolation_level":"REPEATABLE READ"})
            version = session.get(TrackVersion, key["version_id"])
            version_digest = digest(version.manifest)
            pinned = board_manifest(version, key["vehicle_id"])
            public_id = digest({"version_id": version.id, **pinned})
            test_id = digest({"version_id": version.id, **pinned, "test_population": True})
            board_ids = [public_id, test_id] if key["include_artificial"] else [public_id]
            if active_only and session.scalar(select(LapBestState.board_id).where(
                    LapBestState.board_id.in_(board_ids), LapBestState.complete.is_(False)).limit(1)):
                # Release the read connection before bounded prerequisite work.
                # This lookup uses at most two board PKs, never a catalog scan.
                session.close()
                from .lap_bests import backfill_one
                backfill_one(app.state.session_factory, board_ids=board_ids)
                with app.state.session_factory() as progress:
                    changed = progress.execute(update(HistogramSnapshot).filter_by(**key).where(
                        HistogramSnapshot.lease_token == token).values(lease_token=None, lease_until=0,
                            next_refresh_at=clock, dirty=True))
                    if changed.rowcount:
                        progress.execute(update(HistogramDemand).filter_by(**key).values(due_at=clock))
                    progress.commit()
                return True
            revisions = session.execute(select(Board.id, Board.stats_revision, Board.lap_revision).where(
                Board.id.in_(board_ids)).order_by(Board.id)).all()
            revision = sum(stats + laps for _, stats, laps in revisions)
            fingerprint = digest([list(row) for row in revisions])
            payload = None
            if not previous_generation or invalidated or source != fingerprint:
                races, laps = comparison_populations(session, board_ids, public_id, test_id, key["include_artificial"])
                board_id = digest({"version_id": version.id, **pinned, "comparison_population":"all"})
                payload = {"format": 3}
                for metric, field in (("race", races), ("best_lap", laps)):
                    payload[metric] = field.snapshot_payload(board_id, metric)
                population = races.cumulative[-1]
        with app.state.session_factory() as session:
            values = {"lease_token":None, "lease_until":0,
                      "next_refresh_at":clock+refresh_interval(population, app.state.settings.histogram_refresh_seconds)}
            if payload is not None:
                values.update(payload=payload, generation=new_id(), source_revision=revision,
                              source_fingerprint=fingerprint, population=population, updated_at=clock, invalidated=False)
            # Hold the snapshot row while checking invalidation in a fresh READ
            # COMMITTED statement. Administrative invalidation during generation
            # causes a retry rather than clearing its safety flag with old data.
            current = session.scalar(select(HistogramSnapshot).options(defer(HistogramSnapshot.payload))
                .filter_by(**key).with_for_update())
            if current.lease_token == token:
                latest = session.execute(select(Board.id, Board.stats_revision, Board.lap_revision).where(
                    Board.id.in_(board_ids)).order_by(Board.id)).all()
                changed = digest([list(row) for row in latest]) != fingerprint
                manifest_changed = digest(session.scalar(select(TrackVersion.manifest).where(TrackVersion.id == key["version_id"]))) != version_digest
                values["dirty"] = changed or manifest_changed
                if (current.invalidated and changed) or manifest_changed:
                    values = {"lease_token":None,"lease_until":0,"next_refresh_at":clock,"dirty":True}
                session.execute(update(HistogramSnapshot).filter_by(**key).where(
                    HistogramSnapshot.lease_token == token).values(**values))
                session.execute(update(HistogramDemand).filter_by(**key).values(due_at=values["next_refresh_at"]))
                session.commit()
        return True
    except Exception:
        with app.state.session_factory() as session:
            changed = session.execute(update(HistogramSnapshot).filter_by(**key).where(HistogramSnapshot.lease_token == token).values(
                lease_token=None, lease_until=0, next_refresh_at=clock+30))
            if changed.rowcount:
                session.execute(update(HistogramDemand).filter_by(**key).values(due_at=clock+30))
            session.commit()
        logger.exception("histogram_refresh_failed", extra={"version_id":key["version_id"], "vehicle_id":key["vehicle_id"]})
        return False


def refresh_all_for_diagnostics(app, *, clock=None):
    """Explicit offline/test refresh; never called from a request or normal race."""
    from .lap_bests import backfill_all_for_diagnostics
    backfill_all_for_diagnostics(app.state.session_factory)
    clock = now() if clock is None else clock
    with app.state.session_factory() as session:
        session.execute(update(HistogramSnapshot).values(next_refresh_at=clock, dirty=True))
        session.commit()
    count = 0
    while refresh_one(app, clock=clock):
        count += 1
    return count
