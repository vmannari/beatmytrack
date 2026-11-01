"""Daily publication owns cutoffs; ordinary reads never select them again."""
from sqlalchemy import func, select

from .contracts import current_manifest
from .daily_elimination import POLICY, cutoffs
from .histogram_population import HistogramPopulation
from .runs import board_manifest, comparison_statements
from .track_models import LapBestState, digest


class LimitsPending(RuntimeError):
    """The existing accepted-lap backfill must finish before publication."""


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
