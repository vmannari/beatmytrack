"""Read-only account balances for the final deletion warning; never grants access."""

from sqlalchemy import func, select

from .commerce import simulator_allowed
from .commerce_models import Entitlements, Purchase
from .economy_models import CoinWallet, CosmeticUnlock
from .identity_models import Player
from .resume_models import ResumeWallet
from .track_models import now


def deletion_preview(session, settings, player_id):
    simulated = simulator_allowed(session, settings, player_id)
    pending = select(func.count()).select_from(Purchase).where(
        Purchase.player_id == player_id, Purchase.state == "pending")
    if not simulated:
        pending = pending.where(Purchase.provider != "simulation")
    unlocks = select(func.count()).select_from(CosmeticUnlock).where(
        CosmeticUnlock.player_id == player_id).scalar_subquery()
    row = session.execute(select(
        Entitlements.slots, Entitlements.simulated_slots,
        Entitlements.ad_free_until, Entitlements.simulated_ad_free_until,
        Entitlements.forever, Entitlements.simulated_forever,
        CoinWallet.balance, ResumeWallet.balance, unlocks, pending.scalar_subquery(),
    ).select_from(Player)
        .outerjoin(Entitlements, Entitlements.player_id == Player.id)
        .outerjoin(CoinWallet, CoinWallet.player_id == Player.id)
        .outerjoin(ResumeWallet, ResumeWallet.player_id == Player.id)
        .where(Player.id == player_id)).one()
    slots, test_slots, until, test_until, forever, test_forever, coins, resumes, cosmetics, orders = row
    timestamp = now()
    expiry = max(until or 0, (test_until or 0) if simulated else 0)
    unlimited = bool(forever or (simulated and test_forever))
    return {
        "schema_version": 1, "player_id": player_id, "server_now": timestamp,
        # Missing rows have the same initial slot as the ordinary entitlement reader,
        # without creating a wallet or mutating the account merely to show a warning.
        "publishing_slots": (slots if slots is not None else 1) + ((test_slots or 0) if simulated else 0),
        "coins": coins or 0, "banked_resumes": resumes or 0,
        "cosmetic_unlocks": cosmetics, "pending_purchases": orders,
        "ad_free": unlimited or expiry > timestamp,
        "ad_free_until": expiry, "ad_free_forever": unlimited,
    }
