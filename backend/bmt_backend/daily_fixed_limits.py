"""Daily publication owns cutoffs; ordinary reads never select them again."""
from sqlalchemy import func, select

from .contracts import build_contract, current_manifest
from .daily_elimination import POLICY, cutoffs
from .discovery_models import TrackOfDay
from .histogram_population import HistogramPopulation
from .runs import board_manifest, comparison_statements
from .track_models import LapBestState, TrackVersion, digest


class LimitsPending(RuntimeError):
    """The existing accepted-lap backfill must finish before publication."""


def selection_for_version(day, version_id):
    """Resolve an immutable same-track build variant without changing old limits."""
    limits = day.lap_limits if isinstance(day.lap_limits, dict) else {}
    if version_id == day.version_id:
        return limits
    variant = limits.get("build_variant")
    if isinstance(variant, dict) and variant.get("version_id") == version_id:
        selection = variant.get("limits")
        return selection if isinstance(selection, dict) else None
    return None


def displayed_version(day):
    limits = day.lap_limits if isinstance(day.lap_limits, dict) else {}
    variant = limits.get("build_variant")
    if isinstance(variant, dict) and isinstance(variant.get("limits"), dict):
        version_id = variant.get("version_id")
        if isinstance(version_id, str) and version_id:
            return version_id
    return day.version_id


def publish_build_variant(session, day_number, version, active_manifest, stamp, *, allow_artificial=False):
    """Add one compatible build for the same day without modifying old targets.

    The caller commits the locked transaction. Empty populations and unfinished
    backfills cannot publish a partially playable variant.
    """
    day = session.scalar(select(TrackOfDay).where(TrackOfDay.day == day_number).with_for_update())
    if stamp // 86400 != day_number:
        raise ValueError("A build variant can only be published for the current UTC day")
    if day is None or not isinstance(day.lap_limits, dict) or not day.lap_limits:
        raise LimitsPending("The original daily event has not published")
    existing = day.lap_limits.get("build_variant")
    if existing:
        if existing.get("version_id") != version.id:
            raise ValueError("A different build variant is already fixed for this day")
        return False
    original = session.get(TrackVersion, day.version_id)
    head = session.scalar(select(TrackVersion.id).where(TrackVersion.track_id == day.track_id,
        TrackVersion.state == "published").order_by(TrackVersion.number.desc()).limit(1))
    if (original is None or version.id == original.id or version.track_id != day.track_id
            or version.id != head or version.state != "published" or version.content_hash != original.content_hash
            or build_contract(current_manifest(version.manifest)) != build_contract(active_manifest)
            or any(version.manifest.get(key) != original.manifest.get(key)
                   for key in ("compiler_version", "track_content_hash", "route_length"))):
        raise ValueError("Build variant must be the same track and geometry on the active verifier")
    artificial = bool(day.lap_limits.get("include_artificial"))
    if artificial and not allow_artificial:
        raise LimitsPending("The published test population is no longer enabled")
    selection = prepare(session, version, day.day, stamp, include_artificial=artificial)
    if not selection["vehicles"] or any(not v["cutoffs"] for v in selection["vehicles"].values()):
        raise LimitsPending("Every car needs a verified flying lap before publication")
    day.lap_limits = {**day.lap_limits, "build_variant": {"version_id": version.id, "limits": selection}}
    session.flush()
    from .daily_snapshot_preparation import schedule
    schedule(session, day, stamp, include_artificial=allow_artificial)
    return True


def lap_population(session, version, vehicle, manifest, include_artificial):
    public = digest({"version_id": version.id, **manifest})
    artificial = digest({"version_id": version.id, **manifest, "test_population": True})
    boards = [public, artificial] if include_artificial else [public]
    if session.scalar(select(LapBestState.board_id).where(
            LapBestState.board_id.in_(boards), LapBestState.complete.is_(False)).limit(1)):
        raise LimitsPending("Accepted flying-lap backfill is incomplete")
    _, laps = comparison_statements(session, boards, public, artificial, include_artificial)
    frequencies = session.execute(select(laps.c.time_ticks, func.count()).group_by(
        laps.c.time_ticks).order_by(laps.c.time_ticks)).all()
    return HistogramPopulation.from_frequencies(frequencies)


def prepare(session, version, day, stamp, *, include_artificial=False):
    vehicles = {}
    for vehicle in sorted(current_manifest(version.manifest).get("vehicles", {})):
        manifest = board_manifest(version, vehicle)
        population = lap_population(session, version, vehicle, manifest, include_artificial)
        limits = cutoffs(population)
        values = {"manifest": manifest, "population": population.cumulative[-1], "cutoffs": limits,
                  "status": "ready" if limits else "NO_FLYING_LAP_TIMES"}
        values["generation"] = digest([day, version.id, vehicle, include_artificial, values])
        vehicles[vehicle] = values
    return {"policy": POLICY, "set_at": stamp, "include_artificial": include_artificial, "vehicles": vehicles}
