"""Bounded additive erasure, independent of the original persistent plan stages."""

from sqlalchemy import select

from .studio_platform_models import (
    AnalysisDay,
    AnalysisPerson,
    AnalysisSession,
    StudioAssignment,
    StudioCoinEntry,
    StudioFinanceEvent,
)
from .telemetry_models import ProductState


def erase_studio_private(db, player_id):
    db.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
    for model in (AnalysisDay, AnalysisSession, AnalysisPerson, StudioAssignment, StudioCoinEntry):
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
