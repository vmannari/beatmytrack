"""Owner-locked evidence budgets; external storage never occupies the owner lock."""
from fastapi import HTTPException
from sqlalchemy import func, select

from .commerce import lock_entitlements
from .publication_models import PublicationIntent, PublicationUpload
from .storage import canonical_json
from .track_models import digest, new_id, now


def reserve_upload(session, settings, player_id, key, request_hash, document, replay):
    lock_entitlements(session, player_id)
    upload = session.get(PublicationUpload, (player_id, key))
    if upload is not None:
        if upload.request_hash != request_hash:
            raise HTTPException(409, "Idempotency-Key already used for different content")
        if upload.evidence_retired:
            raise HTTPException(410, "PUBLICATION_UPLOAD_EXPIRED")
        # Preserve the original server-owned creator snapshot across profile changes.
        document["creator"] = upload.creator_name
    intent = session.scalar(select(PublicationIntent).where(PublicationIntent.player_id == player_id,
        PublicationIntent.operation_key == key))
    if intent is not None:
        if intent.request_hash != request_hash:
            raise HTTPException(409, "Idempotency-Key already used for different content")
        session.rollback()
        return None, intent
    if upload is not None and upload.lease_until > now():
        # Identical concurrent deliveries share one charge and immutable object
        # hashes. The owner lock at finalization still permits exactly one effect.
        session.commit()
        return upload, None
    if upload is None:
        size = len(canonical_json(document)) + len(canonical_json(replay))
        intent_bytes, intent_count = session.execute(select(func.coalesce(func.sum(PublicationIntent.evidence_bytes), 0),
            func.count()).where(PublicationIntent.player_id == player_id,
            PublicationIntent.evidence_retired.is_(False), PublicationIntent.status != "published")).one()
        upload_bytes, upload_count = session.execute(select(func.coalesce(func.sum(PublicationUpload.evidence_bytes), 0),
            func.count()).where(PublicationUpload.player_id == player_id,
            PublicationUpload.evidence_retired.is_(False))).one()
        if (intent_bytes + upload_bytes + size > settings.publication_evidence_bytes
                or intent_count + upload_count >= settings.publication_evidence_count):
            raise HTTPException(429, "PUBLICATION_EVIDENCE_LIMIT")
        upload = PublicationUpload(player_id=player_id, operation_key=key, request_hash=request_hash,
            content_hash=digest(document), replay_hash=digest(replay), creator_name=document["creator"],
            evidence_bytes=size, lease_until=0, lease_token="")
        session.add(upload)
    upload.lease_token = new_id()
    upload.lease_until = now() + max(600, settings.job_lease_seconds + 60)
    session.commit()
    return upload, None


def retired_candidates(session, cutoff):
    intents = session.scalars(select(PublicationIntent).where(PublicationIntent.status == "failed",
        PublicationIntent.evidence_retired.is_(False), PublicationIntent.finished_at < cutoff,
        ~PublicationIntent.failure_code.in_(("validator_unavailable", "build_mismatch", "NO_PUBLISHING_SLOTS")))
        .order_by(PublicationIntent.finished_at, PublicationIntent.id).limit(1000)
        .with_for_update(skip_locked=True)).all()
    uploads = session.scalars(select(PublicationUpload).where(PublicationUpload.evidence_retired.is_(False),
        PublicationUpload.created_at < cutoff, PublicationUpload.lease_until <= now())
        .order_by(PublicationUpload.created_at, PublicationUpload.player_id).limit(1000)
        .with_for_update(skip_locked=True)).all()
    return intents, uploads


def retire_evidence(intents, uploads):
    # Identities/hashes remain as small permanent tombstones; the same nonce can
    # never recreate an old failed publication or an expired incomplete upload.
    for row in (*intents, *uploads):
        row.evidence_retired = True
        row.evidence_bytes = 0
    for row in intents:
        row.contract = {}
