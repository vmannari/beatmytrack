"""Transactional pending creator effects, separate from race acceptance locks.

The permanent CoinReward receipt fences race intake. Only unapplied effects are
retained here, committed/deleted atomically with the creator projection. Intake
and reduction share partition KEY SHARE locks; erasure alone takes FOR UPDATE.
Reducer NO KEY UPDATE locks exclude other reducers without blocking intake.
"""
from collections import defaultdict

from sqlalchemy import case, delete, literal, select, text, update

from .achievement_models import CreatorAchievementEvent as Event
from .achievement_models import CreatorAchievementPartition as Partition
from .identity_models import Player

PARTITIONS = 16
BATCH = 100


def partition_for(creator_id):
    return sum(creator_id.encode()) % PARTITIONS


def enqueue(session, run, creator_id):
    from .achievements import insert
    partition = partition_for(creator_id)
    session.scalar(select(Partition).where(Partition.id == partition).with_for_update(read=True, key_share=True))
    values = {"id": run.id, "partition": partition, "creator_id": creator_id, "stamp": run.finished_at, "reach": 0}
    columns = Event.__table__.c
    source = select(*(literal(value, type_=columns[key].type) for key, value in values.items())).where(
        select(Player.id).where(Player.id == creator_id, Player.disabled.is_(False),
            Player.deleted_at.is_(None), Player.is_test_driver.is_(False)).exists())
    session.execute(insert(session, Event).from_select(list(values), source).on_conflict_do_nothing())
    from .run_signals import wake_after_commit
    wake_after_commit(session)


def capture_reach(session, run_id, creator_id, value):
    # Same transaction as enqueue: a reach change cannot create a second play.
    session.execute(update(Event).where(Event.id == run_id, Event.creator_id == creator_id).values(reach=value))


def process_one(app):
    from .achievements import bump, save, state
    cursor = getattr(app.state, "creator_achievement_partition", 0)
    with app.state.session_factory() as session:
        partition = session.scalar(select(Partition).where(select(Event.id).where(
            Event.partition == Partition.id).exists()).order_by(
                case((Partition.id >= cursor, 0), else_=1), Partition.id)
            .limit(1).with_for_update(skip_locked=True, key_share=True))
        if partition is None:
            return False
        app.state.creator_achievement_partition = (partition.id + 1) % PARTITIONS
        if session.bind.dialect.name == "postgresql":
            # A concurrent first publication can still own an uncommitted unique
            # state insert. Keep that rare wait bounded; rollback retains effects.
            session.execute(text("SET LOCAL lock_timeout = '250ms'"))
        events = session.scalars(select(Event).where(Event.partition == partition.id)
            .order_by(Event.stamp, Event.id).limit(BATCH)).all()
        creators = defaultdict(list)
        for effect in events:
            creators[effect.creator_id].append(effect)
        applied = []
        for creator_id, contributions in creators.items():
            player = session.get(Player, creator_id)
            if player is not None and player.deleted_at is None:
                # Eligibility was attested at intake. A later suspension/test
                # identity change must not erase already accepted contributions;
                # account erasure is the permanent cancellation fence.
                row = state(session, creator_id, "creator", skip_locked=True, accepted_creator=True)
                if row is None:
                    continue  # Busy projection: retain every contribution.
                # Preserve threshold timestamps/revisions with one state UPDATE
                # per creator, including batches containing many distinct owners.
                with session.no_autoflush:
                    for effect in contributions:
                        metrics = dict(row.metrics)
                        bump(metrics, "creator_plays")
                        save(session, row, metrics, effect.stamp, flush=False)
                        if effect.reach > metrics.get("creator_reach", 0):
                            save(session, row, {**metrics, "creator_reach": effect.reach}, effect.stamp, flush=False)
            applied.extend(effect.id for effect in contributions)
        session.execute(delete(Event).where(Event.id.in_(applied)))
        session.commit()
        return bool(applied)


def erase_pending(session, creator_id):
    # After the account is fenced, no late enqueue/reducer can cross this lock.
    # Bounded chunks avoid turning deletion of a prolific creator into a sweep.
    session.scalar(select(Partition).where(Partition.id == partition_for(creator_id)).with_for_update())
    ids = list(session.scalars(select(Event.id).where(Event.creator_id == creator_id)
        .order_by(Event.stamp, Event.id).limit(BATCH)))
    if ids:
        session.execute(delete(Event).where(Event.id.in_(ids)))
    return len(ids) < BATCH
