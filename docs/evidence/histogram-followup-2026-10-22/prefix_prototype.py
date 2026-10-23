"""Offline prototype only: reward and comparison eligibility are not identical."""
from itertools import pairwise

from sqlalchemy import select

from bmt_backend.economy_models import RewardRankCount
from bmt_backend.reward_ranks import TREE_SIZE, prefix_nodes


def histogram_counts(session, board_id, metric, boundaries):
    paths = [([] if boundary <= 1 else [TREE_SIZE] if boundary >= TREE_SIZE else prefix_nodes(boundary))
             for boundary in boundaries]
    nodes = sorted({node for path in paths for node in path})
    values = dict(session.execute(select(RewardRankCount.node, RewardRankCount.total).where(
        RewardRankCount.board_id == board_id, RewardRankCount.metric == metric,
        RewardRankCount.node.in_(nodes))).all()) if nodes else {}
    prefixes = [sum(values.get(node, 0) for node in path) for path in paths]
    return [right-left for left, right in pairwise(prefixes)]
