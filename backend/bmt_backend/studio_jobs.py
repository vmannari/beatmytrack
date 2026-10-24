"""Union of bounded queue candidates with complete per-kind summaries."""

import base64
import json

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import Integer, String, case, cast, func, literal, or_, select

from .achievement_models import (
    AchievementCompetition,
    AchievementRecord,
    AchievementState,
    CreatorAchievementEvent,
)
from .admin import Access
from .news_models import NewsDemand
from .privacy_models import AccountDeletion
from .publication_models import PublicationIntent
from .studio_platform_models import StudioDelivery
from .studio_queries import read_snapshot
from .telemetry_models import ProductEvent, ProductState
from .track_models import HistogramSnapshot, Run, TrackValidation, now
from .world_ranking_models import RankingBranch, RankingControl

router = APIRouter(tags=["Studio worker queues"])


@router.get("/v1/admin/jobs")
def jobs(
    request: Request,
    role: Access,
    state: str = "pending",
    kind: str = "",
    limit: int = Query(50, ge=1, le=100),
    before: int | None = Query(None, ge=0),
    cursor: str = Query("", max_length=800),
):
    if state not in ("pending", "failed", "all"):
        raise HTTPException(422, "INVALID_JOB_STATE")
    at = now()
    specs = (
        (
            "race",
            Run,
            Run.id,
            Run.created_at,
            Run.status.in_(("queued", "verifying")),
            Run.status == "failed",
        ),
        (
            "publication",
            PublicationIntent,
            PublicationIntent.id,
            PublicationIntent.created_at,
            PublicationIntent.status.in_(("queued", "verifying")),
            PublicationIntent.status == "failed",
        ),
        (
            "validation",
            TrackValidation,
            TrackValidation.version_id,
            TrackValidation.created_at,
            TrackValidation.status.in_(("queued", "verifying")),
            TrackValidation.status == "failed",
        ),
        (
            "erasure",
            AccountDeletion,
            AccountDeletion.player_id,
            AccountDeletion.requested_at,
            AccountDeletion.completed_at.is_(None),
            False,
        ),
        (
            "histogram",
            HistogramSnapshot,
            HistogramSnapshot.version_id
            + "~"
            + HistogramSnapshot.vehicle_id
            + "~"
            + cast(cast(HistogramSnapshot.include_artificial, Integer), String),
            HistogramSnapshot.next_refresh_at,
            HistogramSnapshot.dirty.is_(True),
            False,
        ),
        (
            "news",
            NewsDemand,
            NewsDemand.player_id,
            NewsDemand.requested_day * 86400,
            NewsDemand.pending.is_(True),
            False,
        ),
        (
            "notification",
            StudioDelivery,
            StudioDelivery.id,
            StudioDelivery.created_at,
            StudioDelivery.state == "pending",
            StudioDelivery.state == "dead",
        ),
        ("ranking", RankingBranch, cast(RankingBranch.id, String),
         case((RankingBranch.mode == 'rebuild', 0), else_=RankingBranch.next_week + 604800),
         (RankingBranch.id == select(RankingControl.running_branch).where(RankingControl.id == 1).scalar_subquery())
         & ((RankingBranch.phase != 'idle') | (RankingBranch.mode == 'rebuild') | (RankingBranch.next_week + 604800 <= at)),
         (RankingBranch.id == select(RankingControl.running_branch).where(RankingControl.id == 1).scalar_subquery())
         & (RankingBranch.failure != '')),
        ("achievement_competition", AchievementCompetition, AchievementCompetition.kind + '~' + AchievementCompetition.id,
         AchievementCompetition.due_at, AchievementCompetition.done.is_(False) & (AchievementCompetition.due_at <= at), False),
        ("achievement_record", AchievementRecord, AchievementRecord.board_id, AchievementRecord.due_at,
         AchievementRecord.due_at <= at, False),
        ("achievement_rarity", AchievementState, AchievementState.player_id + '~' + AchievementState.scope,
         literal(0), AchievementState.rarity_pending.is_(True), False),
        ("creator_achievement", CreatorAchievementEvent, CreatorAchievementEvent.id, CreatorAchievementEvent.stamp,
         literal(True), False),
    )
    if kind and kind not in {row[0] for row in specs}:
        raise HTTPException(422, "INVALID_JOB_KIND")
    anchor = None
    if cursor:
        try:
            anchor = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)))
            if (
                set(anchor) != {"scope", "at", "kind", "id"}
                or anchor["scope"] != [state, kind]
                or type(anchor["at"]) is not int
                or not isinstance(anchor["id"], str)
                or anchor["kind"] not in {r[0] for r in specs}
            ):
                raise ValueError()
        except (ValueError, TypeError, KeyError):
            raise HTTPException(422, "INVALID_JOB_CURSOR") from None
    summaries, items = [], []
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        for label, model, identity, created, pending, failed in specs:
            if kind and label != kind:
                continue
            bounded = label in ('ranking', 'achievement_competition', 'achievement_record', 'achievement_rarity', 'creator_achievement')
            if bounded:
                count = db.scalar(select(func.count()).select_from(select(identity).where(pending).limit(10001).subquery()))
                oldest = db.scalar(select(created).where(pending).order_by(created).limit(1))
                failed_count = db.scalar(select(func.count()).select_from(select(identity).where(failed).limit(10001).subquery()))
                summary = (min(count, 10000), oldest)
            else:
                summary = db.execute(select(func.count(), func.min(created)).select_from(model).where(pending)).one()
                failed_count = db.scalar(select(func.count()).select_from(model).where(failed))
            summaries.append(
                {
                    "kind": label,
                    "pending": summary[0],
                    "oldest_at": summary[1] or None,
                    "failed": min(failed_count, 10000) if bounded else failed_count,
                    "capped": bounded and (count > 10000 or failed_count > 10000),
                    "pending_capped": bounded and count > 10000,
                    "failed_capped": bounded and failed_count > 10000,
                    "age_known": bool(summary[1]) or not summary[0],
                }
            )
            conditions = [pending] if state == "pending" else [failed] if state == "failed" else []
            if before is not None:
                conditions.append(created < before)
            if anchor:
                after_tie = identity > anchor["id"] if label == anchor["kind"] else label > anchor["kind"]
                conditions.append(or_(created > anchor["at"], (created == anchor["at"]) & after_tie))
            # Stable grouped summaries are complete; record preview deliberately bounded.
            rows = db.execute(
                select(
                    identity,
                    created,
                    getattr(model, "status", getattr(model, "state", getattr(model, "phase", created))).label("status"),
                )
                .where(*conditions)
                .order_by(created, identity)
                .limit(limit + 1)
            ).all()
            for id_, timestamp, status in rows:
                items.append(
                    {
                        "kind": label,
                        "id": id_,
                        "created_at": timestamp,
                        "status": status
                        if isinstance(status, str)
                        else "pending"
                        if state == "pending"
                        else "retained",
                    }
                )
        product = db.get(ProductState, 1)
        from .studio_ranking import ranking_status
        ranking = ranking_status(db, request.app.state.settings)
        ordered = sorted(items, key=lambda x: (x["created_at"], x["kind"], x["id"]))
        next_cursor = None
        if len(ordered) > limit:
            last = ordered[limit - 1]
            next_cursor = (
                base64.urlsafe_b64encode(
                    json.dumps(
                        {
                            "scope": [state, kind],
                            "at": last["created_at"],
                            "kind": last["kind"],
                            "id": last["id"],
                        },
                        separators=(",", ":"),
                    ).encode()
                )
                .decode()
                .rstrip("=")
            )
        return {
            "role": role,
            "as_of": now(),
            "summary": summaries,
            "ranking": ranking,
            "projection": {
                "pending": product.pending_events,
                "capped": product.pending_capped,
                "processed_through": product.processed_through,
                "pending_clients": product.pending_clients,
                "oldest_receipt_at": db.scalar(
                    select(ProductEvent.received_at)
                    .where(ProductEvent.processed_at.is_(None))
                    .order_by(ProductEvent.received_at, ProductEvent.id)
                    .limit(1)
                ),
            }
            if product
            else None,
            "items": ordered[:limit],
            "next_cursor": next_cursor,
            "truncated": len(items) > limit,
            "scope": "Current per-kind queue counts and oldest-first records. New ranking/achievement counts are bounded at 10,000 and labelled if capped. Rarity enqueue time is unavailable; news uses the requested UTC day. Ranking uses the week-close schedule. No worker lease credentials are exposed.",
        }
