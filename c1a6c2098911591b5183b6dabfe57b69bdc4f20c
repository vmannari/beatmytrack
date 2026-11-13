"""Optional hot completion reads; failures never hide the durable run status."""
import logging

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError

from .economy import PRICES
from .economy_models import CoinReward, CoinWallet, CosmeticUnlock

logger = logging.getLogger("bmt.completion")
TERMINAL = ("verified", "skipped", "rejected", "failed")


def enrich(session, runs, player_id, *, request=None):
    """Read exact hot receipts and one coherent wallet snapshot, without writes.

    Archived receipts deliberately use the existing independent recovery route.
    A batch shares its account payload once; only single-run reads may include
    a full authorized challenge view. Pending runs incur no enrichment reads.
    """
    terminal = [run for run in runs if run.status in TERMINAL]
    if not terminal:
        return {}, None
    values, wallet = {}, None
    try:
        with session.begin_nested():
            rewards = {row.run_id: row for row in session.scalars(select(CoinReward).where(
                CoinReward.player_id == player_id, CoinReward.run_id.in_([run.id for run in terminal])))}
            for run in terminal:
                receipt = rewards.get(run.id)
                # A concurrent archive can remove the hot row after the Run
                # snapshot was read. Absence never proves "no reward": let the
                # independent endpoint resolve current hot/archive provenance.
                reward = {"status": "credited", "amount": receipt.amount, "rows": receipt.rows} if receipt else None
                values[run.id] = {"version": 1, "reward": reward}
            if rewards:
                # One SQL statement binds balance/revision/ownership to the same
                # snapshot even if another device purchases between reads.
                rows = session.execute(select(CoinWallet.balance, CoinWallet.revision, CosmeticUnlock.item_id)
                    .outerjoin(CosmeticUnlock, CosmeticUnlock.player_id == CoinWallet.player_id)
                    .where(CoinWallet.player_id == player_id).order_by(CosmeticUnlock.item_id)).all()
                if rows:
                    wallet = {"schema": 1, "balance": rows[0][0], "revision": rows[0][1],
                              "owned": [row[2] for row in rows if row[2] is not None], "prices": PRICES}
    except (SQLAlchemyError, RuntimeError, ValueError):
        logger.warning("completion_receipt_unavailable")
        return {}, None
    if request is not None and len(terminal) == 1:
        from .challenge_models import ChallengeTicket
        from .challenges import result
        from .identity_models import Player
        run = terminal[0]
        try:
            with session.begin_nested():
                if session.get(ChallengeTicket, run.ticket_id) is not None:
                    # Use the current result route's ownership/content/block
                    # checks. Never expose a cached competition view here.
                    values[run.id]["challenge_result"] = result(
                        run.ticket_id, request, session, session.get(Player, player_id))
        except (HTTPException, SQLAlchemyError, RuntimeError, ValueError):
            values[run.id].pop("challenge_result", None)
            logger.warning("completion_challenge_unavailable")
    return values, wallet


def single(session, run, player_id, request=None):
    values, wallet = enrich(session, [run], player_id, request=request)
    value = values.get(run.id)
    if value is None:
        return {}
    return {"completion": {**value, **({"wallet": wallet} if wallet is not None else {})}}
