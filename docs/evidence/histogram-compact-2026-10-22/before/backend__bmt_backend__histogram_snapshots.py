"""Throttled durable histogram refreshes, performed by the idle worker."""
import logging
import math
from types import MappingProxyType

from sqlalchemy import or_, select, update

from .board_cache import cached
from .histogram_population import HistogramPopulation
from .track_models import Board, HistogramSnapshot, TrackVersion, digest, new_id, now

logger = logging.getLogger("bmt.histograms")


def refresh_interval(population, base=900):
    # 1,000 drivers: 15 minutes by default. Smaller fields refresh sooner;
    # large fields reach an hour. Never rebuild in response to a GET.
    return max(60, min(3600, math.ceil(base * math.sqrt(max(1, population) / 1000))))


def snapshot_key(version_id, vehicle_id, include_artificial):
    return {"version_id": version_id, "vehicle_id": vehicle_id, "include_artificial": include_artificial}


def load_snapshot(session, version_id, vehicle_id, include_artificial):
    key = snapshot_key(version_id, vehicle_id, include_artificial)
    metadata = session.execute(select(HistogramSnapshot.generation, HistogramSnapshot.source_revision,
                                     HistogramSnapshot.invalidated).filter_by(**key)).first()
    if metadata is None or not metadata.generation or metadata.invalidated:
        return None
    def load():
        payload = session.scalar(select(HistogramSnapshot.payload).filter_by(**key))
        return tuple(HistogramPopulation(MappingProxyType(payload[metric]["own"]),
            tuple(payload[metric]["ticks"]), tuple(payload[metric]["counts"]), tuple(payload[metric]["cumulative"]),
            payload[metric]["histogram"]) for metric in ("race", "best_lap"))
    populations = cached(session, ("durable", version_id, vehicle_id, include_artificial, metadata.generation), load,
                         namespace="histogram-snapshots", max_entries=4, max_weight=128*1024*1024,
                         weight=lambda fields: sum(len(field.own)*180+len(field.ticks)*96 for field in fields))
    return metadata.generation, metadata.source_revision, populations


def refresh_one(app, *, clock=None):
    from .runs import board_manifest, comparison_populations
    clock = now() if clock is None else clock
    token = new_id()
    with app.state.session_factory() as session:
        query = select(HistogramSnapshot).join(TrackVersion, TrackVersion.id == HistogramSnapshot.version_id).where(
            TrackVersion.state == "published", HistogramSnapshot.next_refresh_at <= clock,
            HistogramSnapshot.lease_until <= clock, or_(HistogramSnapshot.dirty.is_(True), HistogramSnapshot.invalidated.is_(True)))
        if not app.state.settings.test_drivers_enabled:
            query = query.where(HistogramSnapshot.include_artificial.is_(False))
        row = session.scalar(query.order_by(HistogramSnapshot.next_refresh_at, HistogramSnapshot.version_id,
            HistogramSnapshot.vehicle_id, HistogramSnapshot.include_artificial).with_for_update(skip_locked=True, of=HistogramSnapshot).limit(1))
        if row is None:
            return False
        key = snapshot_key(row.version_id, row.vehicle_id, row.include_artificial)
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
            revisions = session.execute(select(Board.id, Board.stats_revision, Board.lap_revision).where(
                Board.id.in_(board_ids)).order_by(Board.id)).all()
            revision = sum(stats + laps for _, stats, laps in revisions)
            fingerprint = digest([list(row) for row in revisions])
            payload = None
            if not previous_generation or invalidated or source != fingerprint:
                races, laps = comparison_populations(session, board_ids, public_id, test_id, key["include_artificial"])
                board_id = digest({"version_id": version.id, **pinned, "comparison_population":"all"})
                payload = {}
                for metric, field in (("race", races), ("best_lap", laps)):
                    start, end = field.frame(None, None, None)
                    payload[metric] = {"own": dict(field.own), "ticks": field.ticks, "counts":field.counts,
                        "cumulative":field.cumulative, "histogram": field.histogram(board_id, metric, 16, start, end)}
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
            current = session.scalar(select(HistogramSnapshot).filter_by(**key).with_for_update())
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
                session.commit()
        return True
    except Exception:
        with app.state.session_factory() as session:
            session.execute(update(HistogramSnapshot).filter_by(**key).where(HistogramSnapshot.lease_token == token).values(
                lease_token=None, lease_until=0, next_refresh_at=clock+30))
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
