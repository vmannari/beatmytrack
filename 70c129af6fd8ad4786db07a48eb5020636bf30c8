"""Private read models for recorded, verified ordinary races; no score writes."""
from math import isfinite

from sqlalchemy import func, select

from .identity_models import Player
from .track_models import Board, Run, TrackVersion

CARS = ("compact", "kart", "forklift", "electric", "hovercraft", "super_rally")


def ordinary(manifest):
    return (not manifest.get("purpose") and not manifest.get("test_population")
            and manifest.get("laps", 5) == 5)


def car_history(session, player_id):
    # Group in SQL through the existing player/board indexes. Neither replay
    # blobs nor one Python object per race is loaded into the API process.
    counts = (select(Run.board_id, func.count().label("races"))
              .where(Run.player_id == player_id, Run.status == "verified")
              .group_by(Run.board_id).subquery())
    rows = session.execute(select(Board.vehicle_id, Board.manifest, TrackVersion.track_id,
                                  TrackVersion.manifest, counts.c.races)
                           .join(counts, counts.c.board_id == Board.id)
                           .join(TrackVersion, TrackVersion.id == Board.version_id))
    cars = {car: {"races": 0, "distance_m": 0} for car in CARS}
    tracks = set()
    for vehicle, board, track, version, races in rows:
        if vehicle not in cars or not ordinary(board):
            continue
        item = cars[vehicle]
        tracks.add(track)
        item["races"] += races
        length = version.get("route_length")
        if type(length) not in (float, int) or not isfinite(length) or not 0 < length <= 100000:
            item["distance_m"] = None
        elif item["distance_m"] is not None:
            item["distance_m"] += round(length * 5) * races
    totals = {"races": sum(item["races"] for item in cars.values()),
              "distance_m": (sum(item["distance_m"] for item in cars.values())
                             if all(item["distance_m"] is not None for item in cars.values()) else None),
              "tracks": len(tracks), "cars": sum(item["races"] > 0 for item in cars.values())}
    return {"schema": 1, "cars": cars, "totals": totals,
            "scope": "recorded_verified_ordinary_races"}


def track_races(session, version_ids):
    """Actual finishes, including repeat drivers, on these published versions."""
    result = {identity: 0 for identity in version_ids}
    if not result:
        return result
    counts = (select(Run.board_id, func.count().label("races"))
                           .join(Board, Run.board_id == Board.id)
                           .join(Player, Player.id == Run.player_id)
                           .where(Board.version_id.in_(version_ids), Run.status == "verified",
                                  Player.disabled.is_(False), Player.is_test_driver.is_(False))
                           .group_by(Run.board_id).subquery())
    rows = session.execute(select(Board.version_id, Board.manifest, counts.c.races)
                           .join(counts, counts.c.board_id == Board.id))
    for version, manifest, count in rows:
        if ordinary(manifest):
            result[version] += count
    return result
