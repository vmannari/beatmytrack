"""Bounded additive erasure, independent of the original persistent plan stages."""

from sqlalchemy import select

from .game_config_models import GameConfigDelivery
from .studio_platform_models import (
    AnalysisDay,
    AnalysisPerson,
    AnalysisSession,
    StudioAssignment,
    StudioCoinEntry,
    StudioFinanceEvent,
)
from .telemetry_models import ProductLossSource


def erase_studio_private(db, player_id):
    from .telemetry_erasure import erase_publications, fence_private
    fence_private(db, player_id)
    if erase_publications(db, player_id):
        return True
    for model in (ProductLossSource, AnalysisDay, AnalysisSession, AnalysisPerson, StudioAssignment, StudioCoinEntry, GameConfigDelivery):
        rows = db.scalars(select(model).where(model.player_id == player_id).limit(100)).all()
        if rows:
            for row in rows:
                db.delete(row)
            return True
    rows = db.scalars(
        select(StudioFinanceEvent).where(StudioFinanceEvent.player_id == player_id).limit(100)
    ).all()
    if rows:
        for row in rows:
            row.player_id = None
        return True
    return False
