"""Publish is the sole authoring upload; validation runs outside DB locks.

Pending publication intents are not tracks. The catalogue, verified creator
proof and slot consumption appear atomically only after the pinned lap passes.
"""
from __future__ import annotations

import re
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, select, update
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .commerce import consume_publication_slot, lock_entitlements
from .db import get_session
from .identity_models import Identity, Player
from .middleware import ParsedJSONRoute
from .publication_models import PublicationIntent, PublicationUpload
from .publication_storage import reserve_upload
from .queueing import admit, check_capacity, record_claim
from .security import current_player
from .storage import canonical_json
from .track_models import (
    Board,
    QueuePlayer,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    commit_response,
    digest,
    new_id,
    now,
    replay_response,
)
from .tracks import UploadTrack, discovery_projection, track_payload
from .trajectory_verifier import validate_envelope
from .verifier import VerificationError, VerifierStopping
from .worker_lifecycle import aborting, stopping

router = APIRouter(route_class=ParsedJSONRoute, tags=["publication"])
DB = Annotated[Session, Depends(get_session)]
Auth = Annotated[Player, Depends(current_player)]
Key = Annotated[str, Header(alias="Idempotency-Key")]
CONTRACT_FIELDS = ("engine_version", "verifier_version", "physics_version", "rules_key", "compiler_version",
                   "track_schema", "replay_schema", "tick_rate", "track_content_hash", "config_hash")
RETRYABLE = {"validator_unavailable", "build_mismatch", "NO_PUBLISHING_SLOTS"}


class PublishDocument(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    name: str = Field(min_length=1, max_length=80)
    document: dict
    vehicle_id: str = Field(min_length=1, max_length=80)
    contract: dict
    replay: dict

    @field_validator("name")
    @classmethod
    def clean_name(cls, value):
        return UploadTrack.clean_name(value)


def payload(intent):
    return {"publication_id": intent.id, "state": intent.status,
            "failure_code": intent.failure_code, "detail": intent.detail,
            "retryable": intent.failure_code in RETRYABLE, "receipt": intent.receipt,
            "poll_after_ms": 2500 if intent.status in ("queued", "verifying") else 0}


def owned(session, player_id, publication_id, *, lock=False):
    query = select(PublicationIntent).where(PublicationIntent.id == publication_id,
        PublicationIntent.player_id == player_id)
    row = session.scalar(query.with_for_update() if lock else query)
    if row is None:
        raise HTTPException(404, "Publication not found")
    return row


@router.post("/publications", status_code=202)
def request_publication(body: PublishDocument, request: Request, session: DB, player: Auth, key: Key):
    if player.needs_username:
        raise HTTPException(409, "USERNAME_REQUIRED")
    if player.is_test_driver:
        raise HTTPException(403, "ARTIFICIAL_PUBLICATION_UNAVAILABLE")
    original = body.model_dump()
    # Permanent known identities survive age-based new-operation admission.
    # Validate the cheap header bound before the indexed lookup, and require
    # exact owner/body agreement before returning any existing effect.
    try:
        request_hash = digest(original)
    except (ValueError, RecursionError, UnicodeError):
        raise HTTPException(422, "Publication must be finite JSON") from None
    if not 8 <= len(key) <= 128 or any(ord(char) < 33 or ord(char) > 126 for char in key):
        raise HTTPException(422, "INVALID_IDEMPOTENCY_KEY")
    existing = session.scalar(select(PublicationIntent).where(PublicationIntent.player_id == player.id,
        PublicationIntent.operation_key == key))
    if existing:
        if existing.request_hash != request_hash:
            raise HTTPException(409, "Idempotency-Key already used for different content")
        return payload(existing)
    # Fresh operations retain the standard versioned format/expiry contract.
    replay_response(session, player.id, "publication", key, original)
    source_id = body.document.get("id")
    if (body.document.get("schema") != "creator-track-v5" or not isinstance(source_id, str)
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", source_id)):
        raise HTTPException(422, "INVALID_PUBLICATION_ENVELOPE")
    # Naming and creator ownership use exactly the existing immutable contract.
    clean = UploadTrack(name=body.name, document={**body.document, "creator": player.display_name})
    if (set(body.contract) != set(CONTRACT_FIELDS)
            or type(body.contract.get("tick_rate")) is not int or not 1 <= body.contract["tick_rate"] <= 1000
            or any(type(body.contract.get(field)) is not str or not 1 <= len(body.contract[field]) <= 160
                   for field in CONTRACT_FIELDS if field != "tick_rate")):
        raise HTTPException(422, "INVALID_PUBLICATION_CONTRACT")
    try:
        validate_envelope(body.replay)
        if set(body.replay) != {"schema", "input_count", "race_proof"}:
            raise VerificationError("Creator publication cannot include rewinds or ghosts")
        if len(canonical_json(clean.document)) > 524288 or len(canonical_json(body.replay)) > 2097152:
            raise HTTPException(413, "Publication document or trajectory exceeds limit")
    except (ValueError, RecursionError, UnicodeError) as exc:
        raise HTTPException(422, f"Invalid publication: {str(exc)[:160]}") from None
    check_capacity(session, player.id, request.app.state.settings.max_queued_runs)
    # Immutable objects are written before short transactional queue locks.
    player_id = player.id
    session.rollback()
    upload, existing = reserve_upload(session, request.app.state.settings, player_id, key,
                                     request_hash, clean.document, body.replay)
    if existing is not None:
        return payload(existing)
    token = upload.lease_token
    try:
        document_hash = request.app.state.blobs.put_json(clean.document)
        replay_hash = request.app.state.blobs.put_json(body.replay)
        if (document_hash, replay_hash) != (upload.content_hash, upload.replay_hash):
            raise HTTPException(503, "PUBLICATION_STORAGE_HASH_MISMATCH")
        lock_entitlements(session, player_id)
        existing = session.scalar(select(PublicationIntent).where(PublicationIntent.player_id == player_id,
            PublicationIntent.operation_key == key))
        if existing:
            return payload(existing)
        reservation = session.scalar(select(PublicationUpload).where(PublicationUpload.player_id == player_id,
            PublicationUpload.operation_key == key).with_for_update().execution_options(populate_existing=True))
        if (reservation is None or reservation.evidence_retired or reservation.lease_token != token
                or reservation.lease_until <= now()):
            raise HTTPException(503, "PUBLICATION_UPLOAD_BUSY")
        admit(session, player_id, request.app.state.settings.max_queued_runs)
        intent = PublicationIntent(player_id=player_id, operation_key=key, request_hash=request_hash,
            authoring_id=source_id, name=clean.name, content_hash=document_hash, replay_hash=replay_hash,
            vehicle_id=body.vehicle_id, contract=body.contract, evidence_bytes=reservation.evidence_bytes)
        session.add(intent)
        session.delete(reservation)
        session.commit()
        return payload(intent)
    except Exception:
        session.rollback()
        # Keep the charge and object references on every partial failure. Only
        # this writer's lease is released, so retry/crash recovery reuses it.
        try:
            with request.app.state.session_factory() as recovery:
                recovery.execute(update(PublicationUpload).where(PublicationUpload.player_id == player_id,
                    PublicationUpload.operation_key == key, PublicationUpload.lease_token == token)
                    .values(lease_until=0))
                recovery.commit()
        except SQLAlchemyError:
            pass  # A crashed/failed DB retains the bounded lease instead.
        raise


@router.get("/me/publications/{publication_id}")
def publication_status(publication_id: str, session: DB, player: Auth):
    # Metadata only: status reads never load blobs or invoke a verifier.
    return payload(owned(session, player.id, publication_id))


@router.post("/me/publications/{publication_id}/retry")
def retry_publication(publication_id: str, request: Request, session: DB, player: Auth, key: Key):
    body = {"publication_id": publication_id}
    old = replay_response(session, player.id, "publication-retry", key, body)
    if old is not None:
        return old
    lock_entitlements(session, player.id)
    old = replay_response(session, player.id, "publication-retry", key, body)
    if old is not None:
        return old
    intent = owned(session, player.id, publication_id, lock=True)
    if intent.status == "failed" and intent.failure_code in RETRYABLE:
        admit(session, player.id, request.app.state.settings.max_queued_runs)
        intent.status, intent.attempts, intent.lease_until, intent.lease_token = "queued", 0, 0, None
        intent.failure_code, intent.detail = None, None
        intent.finished_at = None
    return commit_response(session, player.id, "publication-retry", key, body, payload(intent))


def admin_payload(intent):
    return {**payload(intent), "player_id": intent.player_id, "name": intent.name,
            "created_at": intent.created_at, "finished_at": intent.finished_at, "attempts": intent.attempts,
            "vehicle_id": intent.vehicle_id, "contract": intent.contract,
            "source_document_hash": intent.content_hash, "source_trajectory_hash": intent.replay_hash}


@router.get("/admin/publications")
def admin_publications(request: Request, session: DB, limit: int = Query(50, ge=1, le=100),
                       offset: int = Query(0, ge=0, le=10000),
                       state: Literal["all", "queued", "verifying", "published", "failed"] = "all"):
    from .admin import access
    role = access(request)
    # One snapshot for operator counts/list; no blob or verifier access. The
    # global pending field is bounded by shared admission, failures cap at5000.
    session.rollback()
    if session.bind.dialect.name == "postgresql":
        from sqlalchemy import text
        session.connection(execution_options={"isolation_level": "REPEATABLE READ"})
        session.execute(text("SET TRANSACTION READ ONLY"))
    pending = session.scalar(select(func.count()).select_from(PublicationIntent)
        .where(PublicationIntent.status.in_(("queued", "verifying"))))
    recent_failures = select(PublicationIntent.id).where(PublicationIntent.status == "failed")
    failed = session.scalar(select(func.count()).select_from(recent_failures.limit(5001).subquery()))
    query = select(PublicationIntent)
    if state != "all":
        query = query.where(PublicationIntent.status == state)
    rows = session.scalars(query.order_by(PublicationIntent.created_at.desc(), PublicationIntent.id)
        .offset(offset).limit(limit+1)).all()
    return {"role": role, "items": [admin_payload(row) for row in rows[:limit]],
            "next_offset": offset+limit if len(rows) > limit else None,
            "counts": {"pending": pending, "failed": min(failed, 5000)}, "failed_count_capped": failed > 5000,
            "source": "Explicit publication processing; saved/editor drafts stay on devices"}


@router.get("/admin/publications/{publication_id}")
def admin_publication(publication_id: str, request: Request, session: DB):
    from .admin import access
    role = access(request)
    intent = session.get(PublicationIntent, publication_id)
    if intent is None:
        raise HTTPException(404, "Publication not found")
    result = admin_payload(intent)
    version_id = (intent.receipt or {}).get("version_id")
    version = session.get(TrackVersion, version_id) if version_id else None
    result["creator_run_id"] = version.creator_test_run_id if version else None
    return {"role": role, "publication": result}


def _check_contract(contract, manifest, vehicle):
    expected = {**manifest, "config_hash": manifest.get("vehicles", {}).get(vehicle, {}).get("config_hash")}
    if (manifest.get("laps") != 5 or manifest.get("tick_rate") != 120
            or vehicle not in manifest.get("vehicles", {})
            or any(contract.get(field) != expected.get(field) for field in CONTRACT_FIELDS)):
        raise PublicationFailure("build_mismatch", "The saved creator lap requires its original track and game build. Its local recording is preserved.")


class PublicationFailure(Exception):
    def __init__(self, code, detail):
        self.code, self.detail = code, detail
        super().__init__(detail)


def process_one(app):
    if stopping(app):
        return False
    token = new_id()
    with app.state.session_factory() as session:
        intent = session.scalar(select(PublicationIntent).join(Player)
            .outerjoin(QueuePlayer, QueuePlayer.player_id == PublicationIntent.player_id)
            .where(PublicationIntent.status.in_(("queued", "verifying")), PublicationIntent.lease_until <= now())
            .order_by(Player.is_test_driver, func.coalesce(QueuePlayer.last_claim_at, 0), PublicationIntent.created_at, PublicationIntent.id)
            .with_for_update(skip_locked=True, of=PublicationIntent).limit(1))
        if intent is None:
            return False
        if intent.attempts >= app.state.settings.max_job_attempts:
            intent.status, intent.failure_code, intent.detail = "failed", "validator_unavailable", "Publication verification exhausted its retries; retry when available."
            intent.lease_until, intent.lease_token = 0, None
            session.commit()
            return True
        record_claim(session, None, intent.player_id)
        intent.status, intent.lease_token = "verifying", token
        intent.lease_until = now() + app.state.settings.job_lease_seconds
        intent.attempts += 1
        snapshot = {field: getattr(intent, field) for field in ("id", "player_id", "content_hash", "replay_hash", "contract", "vehicle_id")}
        session.commit()
    manifest, result, failure, detail = None, None, None, None
    try:
        document = app.state.blobs.get_json(snapshot["content_hash"])
        replay = app.state.blobs.get_json(snapshot["replay_hash"])
        manifest = app.state.verifier.validate_track(document)
        _check_contract(snapshot["contract"], manifest, snapshot["vehicle_id"])
        # The actual verifier uses the same trajectory-only checker as races,
        # with one ordered creator lap and no score/ghost eligibility.
        result = app.state.verifier.verify_run(document, replay, snapshot["vehicle_id"], creator_test=True)
        _check_contract(snapshot["contract"], result.get("manifest", {}), snapshot["vehicle_id"])
        if (type(result.get("time_ticks")) is not int or result["time_ticks"] <= 0
                or result.get("lap_ticks") != [result["time_ticks"]]
                or result["time_ticks"] != replay["input_count"]):
            raise VerificationError("Creator trajectory does not complete the exact recorded lap")
    except VerifierStopping:
        return True
    except PublicationFailure as exc:
        failure, detail = exc.code, exc.detail
    except VerificationError as exc:
        failure, detail = "invalid_creator_proof", str(exc)[:500]
    except Exception:  # noqa: BLE001 - bounded durable infrastructure retry
        failure, detail = "validator_unavailable", "Publication verification is temporarily unavailable; the saved request can retry."
    if aborting(app):
        return True
    with app.state.session_factory() as session:
        # Same owner -> intent lock order as API admission and Retry.
        if session.bind.dialect.name == "sqlite":
            session.execute(update(Player).where(Player.id == snapshot["player_id"]).values(created_at=Player.created_at))
        session.scalar(select(Player).where(Player.id == snapshot["player_id"]).with_for_update())
        intent = session.scalar(select(PublicationIntent).where(PublicationIntent.id == snapshot["id"]).with_for_update())
        if intent is None or intent.status != "verifying" or intent.lease_token != token or intent.lease_until <= now():
            return True
        if failure is None:
            # Any rejection rolls back every track/proof/slot write, while the
            # intent's failure is retained in the outer transaction.
            try:
                with session.begin_nested():
                    intent.receipt = _commit_publication(app, session, intent, manifest, result, document)
            except HTTPException as exc:
                failure, detail = str(exc.detail), str(exc.detail)
        intent.failure_code, intent.detail, intent.lease_token = failure, detail, None
        if failure == "validator_unavailable" and intent.attempts < app.state.settings.max_job_attempts:
            intent.status, intent.lease_until = "queued", now() + min(60, 2 ** min(intent.attempts, 6))
        else:
            intent.status, intent.lease_until, intent.finished_at = ("failed" if failure else "published"), 0, now()
        session.commit()
    return True


def _commit_publication(app, session, intent, manifest, result, document):
    from .runs import board_manifest
    owner = session.get(Player, intent.player_id)
    if owner.disabled or owner.deleted_at is not None or owner.is_test_driver:
        raise HTTPException(403, "PUBLICATION_OWNER_UNAVAILABLE")
    entitlement = lock_entitlements(session, intent.player_id)
    track = session.scalar(select(Track).where(Track.owner_id == intent.player_id,
        Track.authoring_id == intent.authoring_id).with_for_update())
    if track is None:
        track = session.scalar(select(Track).join(TrackVersion).where(Track.owner_id == intent.player_id,
            Track.authoring_id.is_(None), TrackVersion.discovery["authoring_id"].as_string() == intent.authoring_id).limit(1))
    if track and (track.hidden or track.archived):
        raise HTTPException(409, "PUBLICATION_TRACK_UNAVAILABLE")
    if track is None:
        track = Track(owner_id=intent.player_id, authoring_id=intent.authoring_id)
        track.official = session.scalar(select(Identity.id).where(Identity.player_id == intent.player_id,
            Identity.provider == "development", Identity.subject == "developer")) is not None
        session.add(track)
        session.flush()
    elif track.authoring_id is None:
        track.authoring_id = intent.authoring_id
    version = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id,
        TrackVersion.content_hash == intent.content_hash, TrackVersion.name == intent.name).limit(1))
    if version and version.state == "published":
        return track_payload(version, track, owner.display_name, app.state.settings.public_base_url)
    if version is None:
        number = session.scalar(select(func.max(TrackVersion.number)).where(TrackVersion.track_id == track.id)) or 0
        version = TrackVersion(track_id=track.id, number=number+1, name=intent.name,
            content_hash=intent.content_hash, revision_key=digest({"name": intent.name, "hash": intent.content_hash}),
            manifest=manifest, discovery=discovery_projection(document), state="published", published_at=now())
        session.add(version)
        session.flush()
    else:
        version.manifest, version.discovery = manifest, discovery_projection(document)
        version.state, version.published_at = "published", now()
    consume_publication_slot(session, app.state.settings, entitlement, version, official=track.official)
    pinned = {**board_manifest(version, intent.vehicle_id), "purpose": "creator_test", "laps": 1}
    board_id = digest({"version_id": version.id, **pinned})
    board = session.get(Board, board_id)
    if board is None:
        board = Board(id=board_id, version_id=version.id, vehicle_id=intent.vehicle_id, manifest=pinned)
        session.add(board)
        session.flush()
    ticket = RunTicket(player_id=intent.player_id, board_id=board_id, expires_at=now())
    session.add(ticket)
    session.flush()
    run = Run(ticket_id=ticket.id, player_id=intent.player_id, board_id=board_id,
        replay_hash=intent.replay_hash, status="verified", time_ticks=result["time_ticks"],
        lap_ticks=result["lap_ticks"], finished_at=now())
    session.add(run)
    session.flush()
    version.creator_test_run_id = run.id
    if getattr(app.state.settings, "telemetry_enabled", False):
        from .telemetry import append_server_event
        dimensions = {"track_version": version.id, "biome": (version.discovery or {}).get("theme", "pine")}
        append_server_event(session, "creator_validated", run.id, intent.player_id, dimensions,
            occurred_at=run.finished_at, is_test_driver=False)
        append_server_event(session, "track_published", version.id, intent.player_id, dimensions,
            occurred_at=version.published_at, is_test_driver=False)
    session.flush()
    return track_payload(version, track, owner.display_name, app.state.settings.public_base_url)
