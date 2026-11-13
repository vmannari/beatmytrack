"""Keep the current Daily's bounded snapshot work ahead of the first reader."""
from sqlalchemy import case, select

from .daily_elimination import POLICY
from .discovery_projection import insert
from .identity_models import Player
from .track_models import HistogramDemand, HistogramSnapshot, Track, TrackVersion


def schedule(session, day, stamp, *, include_artificial=False):
    """Queue only published Daily selections; the existing worker still builds them.

    Called by publication/maintenance inside its transaction, never by a read.
    No scoring, cutoff, lease, snapshot-payload or refresh-interval changes.
    """
    if day.day != stamp // 86400 or not isinstance(day.lap_limits, dict):
        return
    selections = [(day.version_id, day.lap_limits)]
    variant = day.lap_limits.get("build_variant")
    if isinstance(variant, dict) and isinstance(variant.get("limits"), dict):
        selections.append((variant.get("version_id"), variant["limits"]))
    until = min((day.day+1)*86400, stamp+600)
    for version_id, selection in selections:
        if not version_id or selection.get("policy") != POLICY:
            continue
        # At most the original and one compatible build, with the enabled cars
        # from the immutable published limits. Hidden/removed owners stay cold.
        vehicles = [vehicle for vehicle, values in selection.get("vehicles", {}).items()
                    if isinstance(values, dict) and values.get("cutoffs")]
        if not vehicles:
            continue
        artificial = bool(selection.get("include_artificial")) and include_artificial
        rows = session.execute(select(HistogramSnapshot.vehicle_id, HistogramSnapshot.generation,
                HistogramSnapshot.invalidated, HistogramSnapshot.next_refresh_at)
            .join(TrackVersion, TrackVersion.id == HistogramSnapshot.version_id)
            .join(Track, Track.id == TrackVersion.track_id)
            .join(Player, Player.id == Track.owner_id)
            .where(HistogramSnapshot.version_id == version_id,
                HistogramSnapshot.vehicle_id.in_(vehicles),
                HistogramSnapshot.include_artificial.is_(artificial),
                TrackVersion.state == "published", Track.id == day.track_id,
                Track.hidden.is_(False), Player.disabled.is_(False),
                Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))
        for vehicle, generation, invalidated, refresh_at in rows:
            due = 0 if not generation or invalidated else refresh_at
            key = {"version_id": version_id, "vehicle_id": vehicle, "include_artificial": artificial}
            statement = insert(session, HistogramDemand).values(**key, due_at=due, requested_until=until)
            # A worker may already own the refresh. Preserve earlier interest
            # and renew only near expiry; repeated maintenance is not a hot loop.
            statement = statement.on_conflict_do_update(index_elements=list(key), set_={
                "due_at": case((HistogramDemand.due_at < due, HistogramDemand.due_at), else_=due),
                "requested_until": case((HistogramDemand.requested_until > until,
                                           HistogramDemand.requested_until), else_=until)},
                where=(HistogramDemand.requested_until < min(until, stamp+300))
                    | (HistogramDemand.due_at > due))
            session.execute(statement)
