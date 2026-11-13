"""Every shared/synced priced cosmetic needs permanent server-owned authority."""

from fastapi import HTTPException
from sqlalchemy import select

from .economy_models import CosmeticUnlock


def required_items(appearance):
    value = appearance.model_dump() if hasattr(appearance, "model_dump") else appearance
    items = set()
    pattern = value["livery"]["pattern"]
    if pattern != "plain":
        items.add("livery/" + pattern)
    vehicle = "compact" if value["vehicle_id"] == "super_rally" else value["vehicle_id"]
    if vehicle in ("compact", "kart", "hovercraft", "forklift", "electric"):
        for category in ("hood", "aero", "rims", "body"):
            option = value["customisation"][category]
            if option != "stock":
                items.add("kit/" + vehicle + "/" + category + "/" + option)
    return items


def require_owned(session, player_id, appearance):
    """Caller holds the player's write lock, including for equal-value retries."""
    needed = required_items(appearance)
    if not needed:
        return
    owned = set(
        session.scalars(
            select(CosmeticUnlock.item_id).where(
                CosmeticUnlock.player_id == player_id, CosmeticUnlock.item_id.in_(needed)
            )
        )
    )
    if needed - owned:
        raise HTTPException(403, "COSMETIC_NOT_OWNED")
