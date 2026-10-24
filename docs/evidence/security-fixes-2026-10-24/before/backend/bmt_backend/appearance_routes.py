"""Private garage recovery with per-car optimistic concurrency, outside race rules."""
from fastapi import APIRouter, HTTPException
from sqlalchemy import select, update

from .identity_models import Player
from .middleware import ParsedJSONRoute
from .tracks import DB, Auth
from .vehicle_appearance import Appearance, Cosmetic

router = APIRouter(route_class=ParsedJSONRoute, tags=["garage"])


class SaveAppearance(Cosmetic):
    appearance: Appearance
    previous: Appearance | None


def owner_for_write(session, player_id):
    # A no-op row UPDATE also serializes SQLite writers, where FOR UPDATE is
    # ignored. PostgreSQL holds the same row lock through the eventual commit.
    locked = session.execute(update(Player).where(
        Player.id == player_id, Player.deleted_at.is_(None), Player.disabled.is_(False),
    ).values(id=Player.id))
    if locked.rowcount != 1:
        raise HTTPException(401, "INVALID_SESSION")
    return session.scalar(select(Player).where(Player.id == player_id)
                          .execution_options(populate_existing=True))


@router.get("/me/appearances")
def get_appearances(session: DB, player: Auth):
    # This authenticated endpoint only exposes the current player's five cars.
    owner = session.scalar(select(Player).where(
        Player.id == player.id, Player.deleted_at.is_(None), Player.disabled.is_(False),
    ).execution_options(populate_existing=True))
    if owner is None:
        raise HTTPException(401, "INVALID_SESSION")
    return {"appearances": owner.vehicle_appearances}


@router.put("/me/appearances")
def save_appearance(payload: SaveAppearance, session: DB, player: Auth):
    value = payload.appearance.model_dump()
    previous = payload.previous.model_dump() if payload.previous is not None else None
    if previous is not None and previous["vehicle_id"] != value["vehicle_id"]:
        raise HTTPException(422, "APPEARANCE_VEHICLE_MISMATCH")
    owner = owner_for_write(session, player.id)
    current = owner.vehicle_appearances.get(value["vehicle_id"])
    # Repeating a committed write after a lost reply is an acknowledgement.
    if current != value and current != previous:
        raise HTTPException(409, "APPEARANCE_CHANGED")
    owner.vehicle_appearances = {**owner.vehicle_appearances, value["vehicle_id"]: value}
    session.commit()
    return value
