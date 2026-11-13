"""Bounded worker-local memoization of already evaluated percentile rewards.

Only committed checks are shared. Database revisions invalidate population/time
changes across processes; a faster submitted time always gets an exact query.
No cache writes, new locks or population scans are added to the database.
"""
from collections import OrderedDict
from threading import Lock
from weakref import WeakKeyDictionary

from sqlalchemy import event, select
from sqlalchemy.orm import Session

from .economy_models import RewardRankCount
from .reward_ranks import TIERS, TREE_SIZE, prefix_nodes
from .track_models import Board

LIMIT = 8192
_caches = WeakKeyDictionary()
_lock = Lock()
_PENDING = "bmt_reward_rank_checks"


def percentile_amount(session, player_id, board_id, metric, ticks, revisions, earned):
    nodes = prefix_nodes(ticks)
    engine = session.get_bind()
    key = (player_id, board_id, metric)
    with _lock:
        cache = _caches.get(engine)
        old = cache.get(key) if cache is not None else None
        if old is not None and old[0] == revisions and ticks >= old[1] and earned >= old[2]:
            cache.move_to_end(key)
            return 0  # No higher tier can be earned by this slower candidate.

    # Capture counters and their generation in one SQL snapshot. A concurrent
    # commit between the earlier milestone query and this query is harmless.
    rows = session.execute(select(RewardRankCount.node, RewardRankCount.total,
                                  Board.stats_revision, Board.lap_revision)
        .join(Board, Board.id == RewardRankCount.board_id)
        .where(RewardRankCount.board_id == board_id, RewardRankCount.metric == metric,
               RewardRankCount.node.in_([TREE_SIZE, *nodes]))).all()
    values = {node: total for node, total, _, _ in rows}
    population = values.get(TREE_SIZE, 0)
    rank = sum(values.get(node, 0) for node in nodes) + 1
    amount = next((amount for limit, amount in TIERS
                   if population and rank * 100 <= population * limit), 0)
    # Nested transactions can roll back independently. Their checks are cheap to
    # repeat, and never become shared cache entries.
    if rows and not session.in_nested_transaction():
        transaction = session.get_transaction()
        pending = session.info.get(_PENDING)
        if pending is None or pending[0] is not transaction:
            pending = (transaction, engine, {})
            session.info[_PENDING] = pending
        pending[2][key] = (tuple(rows[0][2:]), ticks, amount)
    return amount


@event.listens_for(Session, "after_commit")
def _publish(session):
    if session.in_nested_transaction():
        return
    pending = session.info.pop(_PENDING, None)
    if pending is None or pending[0] is not session.get_transaction():
        return
    with _lock:
        cache = _caches.setdefault(pending[1], OrderedDict())
        for key, value in pending[2].items():
            old = cache.get(key)
            if old is None or old[0] != value[0] or old[1] > value[1]:
                cache[key] = value
            cache.move_to_end(key)
        while len(cache) > LIMIT:
            cache.popitem(last=False)


@event.listens_for(Session, "after_rollback")
def _discard(session):
    if not session.in_nested_transaction():
        session.info.pop(_PENDING, None)
