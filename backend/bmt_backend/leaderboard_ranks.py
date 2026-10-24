"""Exact order statistics with fixed-domain prefix reads.

Time prefixes need at most 63 counters per population. Tie positions use a compressed UUID
radix tree: at most 36 ancestors, each with at most 16 UUID children. Its storage
is N..2N-1 nodes for N PBs, rather than one row for every UUID prefix.
"""
from sqlalchemy import and_, func, or_, select

from .economy_models import LeaderboardRankCount, LeaderboardTieNode
from .reward_ranks import TREE_SIZE


def prefix_nodes(end):
    """Fenwick nodes for integer times strictly below end, including extremes."""
    node = min(TREE_SIZE, max(0, end - 1))
    result = []
    while node:
        result.append(node)
        node -= node & -node
    return result


def time_counts_many(session, probes, *, artificial=False):
    """Return exact (faster, tied, slower) for each (board,ticks), in one read."""
    if not probes:
        return {}
    paths = {bid: (prefix_nodes(ticks), prefix_nodes(ticks + 1)) for bid, ticks in probes}
    rows = session.execute(select(LeaderboardRankCount.board_id, LeaderboardRankCount.node,
        LeaderboardRankCount.total).where(LeaderboardRankCount.population.in_(("public", "test") if artificial else ("public",)),
        or_(*(and_(LeaderboardRankCount.board_id == bid,
                   LeaderboardRankCount.node.in_({TREE_SIZE, *before, *through}))
              for bid, (before, through) in paths.items())))).all()
    values = {}
    for bid, node, total in rows:
        values[bid, node] = values.get((bid, node), 0) + total
    result = {}
    for bid, (before, through) in paths.items():
        faster = sum(values.get((bid, node), 0) for node in before)
        inclusive = sum(values.get((bid, node), 0) for node in through)
        result[bid] = (faster, inclusive - faster, values.get((bid, TREE_SIZE), 0) - inclusive)
    return result


def time_counts(session, board_id, ticks):
    return time_counts_many(session, [(board_id, ticks)])[board_id]


def tied_before(session, board_id, ticks, player_id, *, inclusive=False):
    # Exact-match prefix probes include only the player's ancestor path. Sum
    # left siblings; compressed edges on the path itself must not be counted.
    paths = [player_id[:length] for length in range(len(player_id) + 1)]
    nodes = LeaderboardTieNode
    result = session.scalar(select(func.coalesce(func.sum(nodes.total), 0)).where(
        nodes.board_id == board_id, nodes.time_ticks == ticks,
        nodes.parent.in_(paths), nodes.prefix < player_id,
        or_(nodes.leaf.is_(True), nodes.prefix.not_in(paths))))
    # A stale cursor may precede the tree's compressed root. The root itself is
    # a left subtree in that case; no matching parent-prefix probe reaches it.
    root = session.execute(select(nodes.prefix, nodes.total, nodes.leaf).where(nodes.board_id == board_id,
        nodes.time_ticks == ticks, nodes.parent.is_(None))).first()
    if root is not None and root.prefix < player_id and (root.leaf or root.prefix not in paths):
        result += root.total
    if inclusive:
        result += int(session.get(nodes, (board_id, ticks, player_id, True)) is not None)
    return int(result)
