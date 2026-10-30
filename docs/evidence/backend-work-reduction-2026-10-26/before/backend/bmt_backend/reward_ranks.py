"""Exact reward ranks with bounded index reads, independent of board population.

Fenwick nodes cover the positive PostgreSQL INTEGER tick domain, including older
boards. A root and at most 30 prefix nodes suffice for one rank query. Counters
are BIGINT; a board may contain more drivers than the tick domain contains times.
The migration owns transactional maintenance and seeds existing PBs once.
"""
from sqlalchemy import select

from .economy_models import RewardRankCount

TREE_SIZE = 1 << 31
TIERS = ((1, 500), (10, 200), (25, 100), (50, 50))


def prefix_nodes(ticks):
    """Nodes whose disjoint ranges contain precisely the strictly faster ticks."""
    if type(ticks) is not int or not 0 < ticks < TREE_SIZE:
        raise ValueError("Reward ticks must be a positive INTEGER")
    node, result = ticks - 1, []
    while node:
        result.append(node)
        node -= node & -node
    return result


def percentile_amount(session, board_id, metric, ticks):
    nodes = prefix_nodes(ticks)
    values = dict(session.execute(select(RewardRankCount.node, RewardRankCount.total).where(
        RewardRankCount.board_id == board_id, RewardRankCount.metric == metric,
        RewardRankCount.node.in_([TREE_SIZE, *nodes]))).all())
    population = values.get(TREE_SIZE, 0)
    rank = sum(values.get(node, 0) for node in nodes) + 1
    # Integer comparison preserves exact threshold boundaries and shared ties.
    return next((amount for limit, amount in TIERS
                 if population and rank * 100 <= population * limit), 0)
