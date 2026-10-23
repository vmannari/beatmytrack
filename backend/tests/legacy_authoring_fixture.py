"""Explicit historical inventory fixtures, never imported by the shipping backend."""

from __future__ import annotations

import json
import re
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from bmt_backend.db import get_session
from bmt_backend.identity_models import Identity, Player
from bmt_backend.middleware import ParsedJSONRoute
from bmt_backend.queueing import admit, check_capacity
from bmt_backend.security import current_player
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import (
    IdempotencyRecord,
    Track,
    TrackValidation,
    TrackVersion,
    commit_response,
    digest,
    now,
    replay_response,
)
from bmt_backend.tracks import _payload, discovery_projection

router = APIRouter(route_class=ParsedJSONRoute, tags=["tracks"])
DB = Annotated[Session, Depends(get_session)]
Auth = Annotated[Player, Depends(current_player)]
Key = Annotated[str, Header(alias="Idempotency-Key")]




class UploadTrack(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=80)
    document: dict
    authoring_id: str | None = Field(default=None, max_length=80)
    defer_validation: bool = False
    expected_head_revision_id: str | None = Field(default=None, max_length=36)

    @field_validator("name")
    @classmethod
    def clean_name(cls, name: str) -> str:
        name = name.strip()
        if not name or any(ord(char) < 32 or ord(char) == 127 for char in name):
            raise ValueError("Track name must be nonempty and contain no control characters")
        return name


def _legacy_authoring(request: Request) -> None:
    if request.app.state.settings.local_drafts_only:
        raise HTTPException(410, "LOCAL_DRAFTS_ONLY: keep drafts on this device; use an explicit verified publication request")


def _validate_revision(request: Request, payload: UploadTrack, player: Player) -> tuple[str, dict]:
    if player.needs_username:
        raise HTTPException(409, "USERNAME_REQUIRED")
    # Authenticated ownership is authoritative, including the downloadable document.
    payload.document = {**payload.document, "creator": player.display_name}
    try:
        encoded = json.dumps(
            payload.document, allow_nan=False, ensure_ascii=False, separators=(",", ":")
        ).encode()
    except (ValueError, RecursionError, UnicodeError):
        raise HTTPException(422, "Track document must be finite JSON") from None
    if len(encoded) > 524288:
        raise HTTPException(413, "Track document exceeds 512 KiB")
    try:
        manifest = request.app.state.verifier.validate_track(payload.document)
    except ValueError as exc:
        raise HTTPException(422, f"Invalid track: {exc}") from None
    except RuntimeError:
        raise HTTPException(503, "Track validator temporarily unavailable") from None
    if (
        manifest.get("laps") != 5
        or manifest.get("tick_rate") != 120
        or not manifest.get("track_content_hash")
    ):
        raise HTTPException(503, "Track validator returned an unsupported manifest")
    document_hash = digest(payload.document)
    from bmt_backend.verifier import GodotVerifier
    if isinstance(request.app.state.verifier,GodotVerifier):
        from bmt_backend.trajectory_verifier import prepared_geometry
        prepared_geometry(request.app,document_hash,payload.document)
    return document_hash, manifest


@router.post("/tracks", status_code=201)
def create_track(payload: UploadTrack, request: Request, session: DB, player: Auth, key: Key) -> dict:
    _legacy_authoring(request)
    body = payload.model_dump(exclude_unset=True)
    old = replay_response(session, player.id, "create_track", key, body)
    if old is not None:
        return old
    source_id = payload.authoring_id or payload.document.get("id")
    if payload.authoring_id and payload.document.get("id") != payload.authoring_id:
        raise HTTPException(422, "AUTHORING_ID_MISMATCH")
    if source_id is not None and (not isinstance(source_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", source_id)):
        raise HTTPException(422, "INVALID_AUTHORING_ID")
    content_hash, manifest = _prepare_revision(request, payload, player)
    prepared_track = _recover_track(request, session, player.id, source_id) if source_id else None
    with session.no_autoflush:
        if prepared_track is not None:
            existing_revision = _check_revision(session, prepared_track, payload)
            if existing_revision is not None:
                return commit_response(session, player.id, "create_track", key, body, _payload(request, session, existing_revision))
        if payload.defer_validation:
            check_capacity(session, player.id, request.app.state.settings.max_queued_runs)
    prepared_id = prepared_track.id if prepared_track is not None else None
    owner_id = player.id
    session.rollback()
    if request.app.state.blobs.put_json(payload.document) != content_hash:
        raise HTTPException(503, "Track storage hash mismatch")
    session.scalar(select(Player).where(Player.id == owner_id).with_for_update())
    old = replay_response(session, player.id, "create_track", key, body)
    if old is not None:
        return old
    track = session.get(Track, prepared_id) if prepared_id else None
    if track is not None and source_id and track.authoring_id is None:
        track.authoring_id = source_id
    if track is None and source_id:
        track = session.scalar(select(Track).where(Track.owner_id == owner_id, Track.authoring_id == source_id))
    if track is None:
        track = Track(owner_id=player.id, authoring_id=source_id)
        session.add(track)
        session.flush()
    if session.scalar(select(Identity.player_id).where(Identity.player_id == player.id,
            Identity.provider == "development", Identity.subject == "developer")) is not None:
        track.official = True
    version = _save_revision(session, track, payload, content_hash, manifest, request.app.state.settings.max_queued_runs, request.app.state.blobs)
    return commit_response(session, player.id, "create_track", key, body, _payload(request, session, version))


def _prepare_revision(request: Request, payload: UploadTrack, player: Player) -> tuple[str, dict]:
    from bmt_backend.community import require_terms
    with request.app.state.session_factory() as safety_session:
        require_terms(safety_session, player.id)
    if not request.app.state.settings.allow_sync_track_validation:
        payload.defer_validation = True
    if not payload.defer_validation:
        return _validate_revision(request, payload, player)
    if player.needs_username:
        raise HTTPException(409, "USERNAME_REQUIRED")
    if payload.document.get("schema") != "creator-track-v5" or not isinstance(payload.document.get("id"), str):
        raise HTTPException(422, "INVALID_DRAFT_ENVELOPE")
    payload.document = {**payload.document, "creator": player.display_name}
    try:
        size = len(canonical_json(payload.document))
    except (ValueError, RecursionError, UnicodeError):
        raise HTTPException(422, "Track document must be finite JSON") from None
    if size > 524288:
        raise HTTPException(413, "Track document exceeds 512 KiB")
    return digest(payload.document), {}


def _recover_track(request: Request, session: Session, owner_id: str, source_id: str) -> Track | None:
    track = session.scalar(select(Track).where(Track.owner_id == owner_id, Track.authoring_id == source_id))
    if track is not None:
        return track
    # Adopt the stable ID embedded in legacy owned documents, never a display name.
    # Immutable versions, links, ratings and boards remain on their existing IDs.
    candidate = session.scalar(select(Track).join(TrackVersion).where(Track.owner_id == owner_id,
        Track.authoring_id.is_(None), TrackVersion.discovery["authoring_id"].as_string() == source_id).limit(1))
    if candidate is not None:
        candidate.authoring_id = source_id
        return candidate
    rows = session.execute(select(Track.id, TrackVersion.content_hash).join(TrackVersion)
        .where(Track.owner_id == owner_id, Track.authoring_id.is_(None),
            or_(TrackVersion.discovery.is_(None), TrackVersion.discovery["authoring_id"].as_string().is_(None)))
        .order_by(Track.created_at, Track.id, TrackVersion.number).limit(101)).all()
    if len(rows) > 100:
        raise HTTPException(503, "LEGACY_DRAFT_BACKFILL_REQUIRED")
    session.rollback()
    for candidate_id, content_hash in rows:
        document = request.app.state.blobs.get_json(content_hash)
        if document.get("id") == source_id:
            candidate = session.get(Track, candidate_id)
            candidate.authoring_id = source_id
            return candidate
    return None


def _save_revision(session: Session, track: Track, payload: UploadTrack, content_hash: str, manifest: dict, capacity: int, blobs) -> TrackVersion:
    if track.archived:
        raise HTTPException(409, "DRAFT_ARCHIVED: save as a new track to continue")
    existing = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id,
        TrackVersion.content_hash == content_hash, TrackVersion.name == payload.name)
        .order_by(TrackVersion.number.desc()).limit(1))
    if existing is not None:
        return existing
    head = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id)
        .order_by(TrackVersion.number.desc()).limit(1))
    expected = payload.expected_head_revision_id
    conflict = head is not None if expected == "new" else (head is None or head.id != expected)
    if expected and conflict:
        raise HTTPException(409, "REVISION_CONFLICT: the remote draft changed; both snapshots are preserved")
    if payload.defer_validation:
        pending = session.scalar(select(func.count()).select_from(TrackValidation).join(TrackVersion).join(Track)
            .where(Track.owner_id == track.owner_id, TrackValidation.status.in_(("queued", "validating"))))
        if pending >= 32:
            raise HTTPException(429, "Track validation capacity reached; your local draft can safely retry")
    if payload.defer_validation:
        check_capacity(session, track.owner_id, capacity)
    if payload.defer_validation:
        admit(session, track.owner_id, capacity)
    projection = discovery_projection(payload.document)
    version = TrackVersion(track_id=track.id, number=head.number + 1 if head else 1,
        name=payload.name, content_hash=content_hash, revision_key=digest({"name": payload.name, "hash": content_hash}), manifest=manifest,
        discovery=projection, state="validating" if payload.defer_validation else "draft")
    session.add(version)
    session.flush()
    if payload.defer_validation:
        session.add(TrackValidation(version_id=version.id))
    return version


def _check_revision(session, track, payload):
    if track.archived:
        raise HTTPException(409, "DRAFT_ARCHIVED: save as a new track to continue")
    # A retry of the identical immutable revision is harmless even if its old
    # expected head has since advanced; the final transaction rechecks identity.
    existing = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id,
        TrackVersion.content_hash == digest(payload.document), TrackVersion.name == payload.name)
        .order_by(TrackVersion.number.desc()).limit(1))
    if existing is not None:
        return existing
    head = session.scalar(select(TrackVersion).where(TrackVersion.track_id == track.id)
        .order_by(TrackVersion.number.desc()).limit(1))
    expected = payload.expected_head_revision_id
    conflict = head is not None if expected == "new" else head is None or head.id != expected
    if expected and conflict:
        raise HTTPException(409, "REVISION_CONFLICT: the remote draft changed; both snapshots are preserved")


@router.post("/tracks/{track_id}/versions", status_code=201)
def create_version(
    track_id: str, payload: UploadTrack, request: Request, session: DB, player: Auth, key: Key
) -> dict:
    _legacy_authoring(request)
    scope, body = f"version:{track_id}", payload.model_dump(exclude_unset=True)
    old = replay_response(session, player.id, scope, key, body)
    if old is not None:
        return old
    track = session.scalar(
        select(Track).where(Track.id == track_id, Track.owner_id == player.id)
    )
    if track is None:
        raise HTTPException(404, "Track not found")
    content_hash, manifest = _prepare_revision(request, payload, player)
    existing_revision = _check_revision(session, track, payload)
    if existing_revision is not None:
        return commit_response(session, player.id, scope, key, body, _payload(request, session, existing_revision))
    if payload.defer_validation:
        check_capacity(session, player.id, request.app.state.settings.max_queued_runs)
    owner_id = player.id
    session.rollback()
    if request.app.state.blobs.put_json(payload.document) != content_hash:
        raise HTTPException(503, "Track storage hash mismatch")
    session.scalar(select(Player).where(Player.id == owner_id).with_for_update())
    track = session.scalar(select(Track).where(Track.id == track_id, Track.owner_id == player.id).with_for_update())
    if track is None: raise HTTPException(404, "Track not found")
    old = replay_response(session, player.id, scope, key, body)
    if old is not None: return old
    version = _save_revision(session, track, payload, content_hash, manifest, request.app.state.settings.max_queued_runs, request.app.state.blobs)
    return commit_response(session, player.id, scope, key, body, _payload(request, session, version))


@router.post("/me/track-versions/{version_id}/retry-validation")
def retry_validation(version_id: str, request: Request, session: DB, player: Auth, key: Key) -> dict:
    _legacy_authoring(request)
    scope = f"retry_validation:{version_id}"
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    version = session.scalar(select(TrackVersion).join(Track)
        .where(TrackVersion.id == version_id, Track.owner_id == player.id).with_for_update())
    job = session.get(TrackValidation, version_id) if version else None
    if job is None:
        raise HTTPException(404, "Validation not found")
    if job.status == "failed" and job.failure_code == "validator_unavailable":
        admit(session, player.id, request.app.state.settings.max_queued_runs)
        job.status, job.attempts, job.lease_until, job.lease_token = "queued", 0, 0, None
    return commit_response(session, player.id, scope, key, {}, {"version_id": version_id, "status": job.status})


@router.post("/track-versions/{version_id}/publish")
def publish(version_id: str, request: Request, session: DB, player: Auth, key: Key) -> dict:
    _legacy_authoring(request)
    from bmt_backend.commerce import consume_publication_slot, lock_entitlements
    entitlement = lock_entitlements(session, player.id)
    from bmt_backend.community import require_terms
    require_terms(session, player.id)
    scope = f"publish:{version_id}"
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    version = session.scalar(
        select(TrackVersion)
        .join(Track)
        .where(TrackVersion.id == version_id, Track.owner_id == player.id)
        .with_for_update()
    )
    if version is None:
        raise HTTPException(404, "Track version not found")
    if version.state not in ("tested", "published") or not version.creator_test_run_id:
        raise HTTPException(409, "Creator test has not passed server verification. Complete a new test drive or retry after verification finishes")
    if session.get(Track, version.track_id).hidden:
        raise HTTPException(409, "Hidden track cannot be published")
    if session.get(Track, version.track_id).archived and version.state != "published":
        raise HTTPException(409, "DRAFT_ARCHIVED")
    consume_publication_slot(session, request.app.state.settings, entitlement, version,
        official=session.get(Track, version.track_id).official)
    first_publication = version.state != "published"
    version.state = "published"
    version.published_at = version.published_at or now()
    if first_publication:
        from bmt_backend.news import capture_publication
        capture_publication(session, version, session.get(Track, version.track_id), player)
    if first_publication and getattr(request.app.state.settings, "telemetry_enabled", False):
        from bmt_backend.telemetry import append_server_event
        dimensions = {"track_version": version.id}
        discovery = version.discovery or {}
        biome = discovery.get("theme", discovery.get("biome"))
        if biome:
            dimensions["biome"] = biome
        append_server_event(session, "track_published", version.id, player.id, dimensions,
                            occurred_at=version.published_at, is_test_driver=player.is_test_driver)
    session.flush()
    return commit_response(session, player.id, scope, key, {}, _payload(request, session, version))


@router.post("/me/drafts/{authoring_id}/archive")
def archive_draft(authoring_id: str, request: Request, session: DB, player: Auth, key: Key) -> dict:
    _legacy_authoring(request)
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", authoring_id):
        raise HTTPException(422, "INVALID_AUTHORING_ID")
    scope = f"archive_draft:{authoring_id}"
    session.rollback()
    session.scalar(select(Player).where(Player.id == player.id).with_for_update())
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    track = _recover_track(request, session, player.id, authoring_id)
    if track is None:
        track = Track(owner_id=player.id, authoring_id=authoring_id)
        session.add(track)
        session.flush()
    track.archived = True
    # Fence pending validation without touching published links or race records.
    session.execute(update(TrackValidation).where(
        TrackValidation.version_id.in_(select(TrackVersion.id).where(TrackVersion.track_id == track.id)),
        TrackValidation.status.in_(("queued", "validating")),
    ).values(status="failed", failure_code="draft_archived", detail="Draft archived by its owner",
             lease_token=None, lease_until=0))
    return commit_response(session, player.id, scope, key, {},
                           {"authoring_id": authoring_id, "archived": True, "shared_versions_retained": True})


@router.get("/me/drafts/{authoring_id}/head")
def draft_head(authoring_id: str, request: Request, session: DB, player: Auth,
               upload_key: str = Query("", max_length=128)) -> dict:
    _legacy_authoring(request)
    version = session.scalar(select(TrackVersion).join(Track).where(
        Track.owner_id == player.id, Track.authoring_id == authoring_id, Track.archived.is_(False),
    ).order_by(TrackVersion.number.desc()).limit(1))
    if version is None:
        raise HTTPException(404, "Draft not found")
    operation = session.get(IdempotencyRecord, (player.id, "create_track", upload_key)) if upload_key else None
    return {**_payload(request, session, version),
            "acknowledged_upload_version_id": operation.response.get("version_id") if operation else None}


def install(app):
    """Historical inventory fixture only; never installed by create_app."""
    if app.state.settings.environment != "test":
        raise ValueError("Historical authoring fixtures require a disposable test service")
    previous = len(app.router.routes)
    app.include_router(router, prefix="/v1")
    app.router.routes[:] = app.router.routes[previous:] + app.router.routes[:previous]


def process_one(app):
    from legacy_validation_fixture import process_one as validation_one

    from bmt_backend.worker import process_one as race_one
    return race_one(app) or validation_one(app)
