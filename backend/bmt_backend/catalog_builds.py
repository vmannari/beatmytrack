"""Operator-only build refresh of published heads; historical revisions stay exact."""
from copy import deepcopy
from uuid import UUID, uuid5

from sqlalchemy import func, select

from .contracts import build_contract, current_manifest
from .identity_models import Player
from .track_models import Track, TrackVersion, digest, now

LIMIT = 100


def published_heads(session):
    ranked = select(TrackVersion.id.label("id"), func.row_number().over(
        partition_by=TrackVersion.track_id, order_by=TrackVersion.number.desc()).label("position"))
    ranked = ranked.where(TrackVersion.state == "published").subquery()
    rows = session.scalars(select(TrackVersion).join(ranked, ranked.c.id == TrackVersion.id)
        .join(Track, Track.id == TrackVersion.track_id).join(Player, Player.id == Track.owner_id)
        .where(ranked.c.position == 1, Track.hidden.is_(False), Track.archived.is_(False),
               Player.disabled.is_(False), Player.deleted_at.is_(None))
        .order_by(TrackVersion.track_id).limit(LIMIT+1)).all()
    if len(rows) > LIMIT:
        raise RuntimeError("Published catalogue exceeds the bounded deployment review")
    return rows


def check_catalog(session, active):
    """A healthy global manifest is insufficient if real tracks cannot issue tickets."""
    heads = published_heads(session)
    incompatible = [row.id for row in heads
                    if build_contract(current_manifest(row.manifest)) != build_contract(active)]
    if incompatible:
        raise RuntimeError(f"{len(incompatible)} published track contracts need validated build revisions")
    return {"published_tracks":len(heads), "compatible_tracks":len(heads), "vehicles":sorted(active["vehicles"])}


def plan_refresh(session, blobs, verifier):
    active = verifier.manifest()
    plan = []
    for head in published_heads(session):
        if build_contract(current_manifest(head.manifest)) == build_contract(active):
            continue
        document = blobs.get_json(head.content_hash)
        if digest(document) != head.content_hash:
            raise RuntimeError("Published source document failed integrity")
        manifest = verifier.validate_track(document)
        if build_contract(manifest) != build_contract(active):
            raise RuntimeError("Track validation returned another verifier build")
        if (head.manifest.get("compiler_version") != manifest.get("compiler_version")
                or head.manifest.get("track_content_hash") != manifest.get("track_content_hash")
                or head.manifest.get("route_length") != manifest.get("route_length")):
            raise RuntimeError("Track geometry changed; review a separate compiler/content release")
        plan.append({"source_id":head.id, "track_id":head.track_id, "number":head.number,
                     "content_hash":head.content_hash, "old_manifest":deepcopy(head.manifest),
                     "manifest":manifest})
    return plan


def apply_refresh(session, plan):
    """Caller commits once, after every source/head has passed its locked recheck."""
    inserted = []
    for item in sorted(plan, key=lambda value:value["track_id"]):
        track = session.scalar(select(Track).where(Track.id == item["track_id"]).with_for_update())
        if track is None or track.hidden or track.archived:
            raise RuntimeError("Published track visibility changed during deployment")
        owner = session.get(Player, track.owner_id)
        if owner is None or owner.disabled or owner.deleted_at is not None:
            raise RuntimeError("Published owner eligibility changed during deployment")
        head = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id,
            TrackVersion.state == "published").order_by(TrackVersion.number.desc()).limit(1))
        if (head is None or head.id != item["source_id"] or head.number != item["number"]
                or head.content_hash != item["content_hash"] or head.manifest != item["old_manifest"]):
            raise RuntimeError("Published head changed during deployment; prepare a fresh plan")
        manifest = deepcopy(item["manifest"])
        identity = str(uuid5(UUID(head.id), "canonical-transfer-v1:"+digest(manifest)))
        at = max(now(),head.created_at+1,(head.published_at or 0)+1)
        session.add(TrackVersion(id=identity,track_id=head.track_id,number=head.number+1,name=head.name,
            content_hash=head.content_hash,manifest=manifest,discovery=deepcopy(head.discovery),state="published",
            created_at=at,published_at=at,revision_key=digest({"source_version":head.id,"manifest":manifest}),
            creator_test_run_id=None,rating_sum=0,rating_count=0,verified_finishers=0))
        inserted.append(identity)
    session.flush()
    return inserted
