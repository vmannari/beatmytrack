"""Bounded private-state erasure; existing account deletion owns the transaction."""
from sqlalchemy import delete, select, tuple_

from .discovery_models import (
    DiscoveryBoundary,
    DiscoveryChange,
    DiscoveryCollection,
    DiscoveryDriver,
    DiscoveryEntry,
    DiscoveryHead,
    DiscoveryMember,
    DiscoveryOwnerJob,
    DiscoveryPartition,
    DiscoverySession,
)
from .discovery_v3 import digest
from .track_models import now


def erase_private(db, player_id, limit=100):
    actor = digest("player:" + player_id)
    view_ids = select(DiscoverySession.id).where(DiscoverySession.scope == actor)
    boundaries = list(db.scalars(select(DiscoveryBoundary.id).where(
        DiscoveryBoundary.session_id.in_(view_ids)).limit(limit)))
    if boundaries:
        db.execute(delete(DiscoveryBoundary).where(DiscoveryBoundary.id.in_(boundaries)))
        return False
    views = list(db.scalars(view_ids.limit(limit)))
    if views:
        db.execute(delete(DiscoverySession).where(DiscoverySession.id.in_(views)))
        return False
    collection = db.scalar(select(DiscoveryCollection.id).where(DiscoveryCollection.scope == actor).limit(1))
    if collection:
        members = list(db.execute(select(DiscoveryMember.kind, DiscoveryMember.track_id)
            .where(DiscoveryMember.collection_id == collection).limit(limit)))
        if members:
            db.execute(delete(DiscoveryMember).where(DiscoveryMember.collection_id == collection,
                tuple_(DiscoveryMember.kind, DiscoveryMember.track_id).in_([tuple(r) for r in members])))
        else:
            db.execute(delete(DiscoveryCollection).where(DiscoveryCollection.id == collection))
        return False
    # Lock affected partitions in the same order as all projection writers.
    drivers = list(db.scalars(select(DiscoveryDriver).where(DiscoveryDriver.player_id == player_id).limit(limit)))
    if drivers:
        list(db.scalars(select(DiscoveryPartition).where(DiscoveryPartition.id.in_({r.partition for r in drivers}))
            .order_by(DiscoveryPartition.id).with_for_update()))
        keys = [(r.track_id,r.player_id) for r in drivers]
        drivers = list(db.scalars(select(DiscoveryDriver).where(
            tuple_(DiscoveryDriver.track_id,DiscoveryDriver.player_id).in_(keys))
            .execution_options(populate_existing=True)))
        for row in drivers:
            current = db.get(DiscoveryHead, row.track_id)
            if row.counted and current:
                current.popularity = max(0, current.popularity - 1)
                current.due_at = now()
            db.delete(row)
        return False
    for model in (DiscoveryChange, DiscoveryOwnerJob):
        rows = list(db.scalars(select(model).where(model.player_id == player_id).limit(limit)))
        if rows:
            for row in rows:
                db.delete(row)
            return False
    entries = list(db.scalars(select(DiscoveryEntry).where(DiscoveryEntry.owner_id == player_id,
        DiscoveryEntry.creator != "Removed account").limit(limit)))
    if entries:
        for row in entries:
            row.creator, row.creator_key, row.visible = "Removed account", "removed account", False
        return False
    return True
