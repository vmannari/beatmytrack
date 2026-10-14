"""Immutable track uploads, verified publication, discovery and qualified ratings."""

from __future__ import annotations

import json
import re
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session, aliased

from .contracts import current_manifest
from .cursors import decode_cursor, encode_cursor
from .db import get_session
from .identity_models import Identity, Player
from .middleware import ParsedJSONRoute
from .queueing import admit, check_capacity
from .security import current_player
from .storage import canonical_json
from .track_models import (
    Board,
    IdempotencyRecord,
    PersonalBest,
    Rating,
    Run,
    Track,
    TrackValidation,
    TrackVersion,
    commit_response,
    digest,
    now,
    replay_response,
)

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


class Vote(BaseModel):
    model_config = ConfigDict(extra="forbid")
    score: int = Field(strict=True, ge=1, le=5)


def track_payload(version: TrackVersion, track: Track, creator: str, base_url: str) -> dict:
    return {
        **(version.discovery or {}),
        "track_id": track.id,
        "authoring_id": track.authoring_id or (version.discovery or {}).get("authoring_id"),
        "version_id": version.id,
        "version": version.number,
        "name": version.name,
        "creator_id": track.owner_id,
        "creator": creator,
        "state": version.state,
        "hidden": track.hidden,
        "content_hash": version.content_hash,
        "created_at": version.created_at,
        "published_at": version.published_at,
        "rating_count": version.rating_count,
        "rating_average": round(version.rating_sum / version.rating_count, 3)
        if version.rating_count
        else None,
        "share_url": f"{base_url.rstrip('/')}/v1/track-versions/{version.id}",
        "manifest": current_manifest(version.manifest),
    }


def _payload(request: Request, session: Session, version: TrackVersion) -> dict:
    track = session.get(Track, version.track_id)
    owner = session.get(Player, track.owner_id)
    return track_payload(version, track, owner.display_name, request.app.state.settings.public_base_url)


def discovery_payload(request: Request, version: TrackVersion, track: Track, creator: str) -> dict:
    result = track_payload(version, track, creator, request.app.state.settings.public_base_url)
    result.pop("manifest")
    # Legacy projections are repaired by maintenance, never by catalog reads.
    result.update(version.discovery or {"theme": "pine", "points": []})
    return result


def discovery_projection(document: dict) -> dict:
    points = document.get("points", [])
    if not isinstance(points, list):
        points = []
    count = min(96, len(points))
    return {"theme": document.get("theme", "pine"), "authoring_id": document.get("id"),
            "points": [points[i * len(points) // count] for i in range(count)]}


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
    from .verifier import GodotVerifier
    if isinstance(request.app.state.verifier,GodotVerifier):
        from .trajectory_verifier import prepared_geometry
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


@router.get("/me/track-versions/{version_id}")
def revision_status(version_id: str, request: Request, session: DB, player: Auth) -> dict:
    version = session.scalar(select(TrackVersion).join(Track)
        .where(TrackVersion.id == version_id, Track.owner_id == player.id))
    if version is None:
        raise HTTPException(404, "Track version not found")
    job = session.get(TrackValidation, version.id)
    proof = session.scalar(select(Run).join(Board).where(Board.version_id == version.id,
        Run.player_id == player.id, Board.manifest["purpose"].as_string() == "creator_test")
        .order_by(Run.created_at.desc(), Run.id).limit(1))
    return {**_payload(request, session, version),
        "validation": {"status": job.status, "failure_code": job.failure_code, "detail": job.detail,
            "retryable": job.failure_code == "validator_unavailable"} if job else {"status": "validated"},
        "proof": {"run_id": proof.id, "status": proof.status, "failure_code": proof.failure_code,
            "retryable": proof.status == "failed" and proof.failure_code in ("verifier_unavailable", "build_mismatch")} if proof else None}


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
    from .commerce import consume_publication_slot, lock_entitlements
    entitlement = lock_entitlements(session, player.id)
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
    if first_publication and getattr(request.app.state.settings, "telemetry_enabled", False):
        from .telemetry import append_server_event
        dimensions = {"track_version": version.id}
        discovery = version.discovery or {}
        biome = discovery.get("theme", discovery.get("biome"))
        if biome:
            dimensions["biome"] = biome
        append_server_event(session, "track_published", version.id, player.id, dimensions,
                            occurred_at=version.published_at, is_test_driver=player.is_test_driver)
    session.flush()
    return commit_response(session, player.id, scope, key, {}, _payload(request, session, version))


@router.post("/tracks/{track_id}/hide")
def hide(track_id: str, session: DB, player: Auth, key: Key) -> dict:
    scope = f"hide:{track_id}"
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    track = session.scalar(
        select(Track).where(Track.id == track_id, Track.owner_id == player.id).with_for_update()
    )
    if track is None:
        raise HTTPException(404, "Track not found")
    track.hidden = True
    # Retention is intentional: shared URLs, immutable course data and existing PBs survive hiding.
    return commit_response(
        session, player.id, scope, key, {}, {"track_id": track.id, "hidden": True, "records_retained": True}
    )


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


@router.get("/me/tracks")
def my_tracks(
    request: Request,
    session: DB,
    player: Auth,
    offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(20, ge=1, le=100),
    heads: bool = False,
) -> dict:
    latest_query = select(TrackVersion.track_id, func.max(TrackVersion.number).label("number"))
    if request.app.state.settings.local_drafts_only:
        latest_query = latest_query.where(TrackVersion.state == "published")
    latest = latest_query.group_by(TrackVersion.track_id).subquery()
    query = select(TrackVersion).join(Track).where(Track.owner_id == player.id)
    if request.app.state.settings.local_drafts_only:
        query = query.where(TrackVersion.state == "published")
    if heads:
        query = query.where(Track.archived.is_(False))
        query = query.join(latest, (latest.c.track_id == TrackVersion.track_id) & (latest.c.number == TrackVersion.number))
    versions = session.scalars(
        query
        .order_by(TrackVersion.created_at.desc(), TrackVersion.id)
        .offset(offset)
        .limit(limit + 1)
    ).all()
    return {
        "items": [_payload(request, session, row) for row in versions[:limit]],
        "next_offset": offset + limit if len(versions) > limit else None,
    }


@router.get("/tracks")
def discover(
    request: Request,
    session: DB,
    q: str = Query("", max_length=80),
    creator: str = Query("", max_length=80),
    offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(20, ge=1, le=100),
    cursor: str = Query("", max_length=400),
    theme: str = Query("", max_length=40),
    minimum_rating: float = Query(0, ge=0, le=5),
    search: str = Query("", max_length=80),
) -> dict:
    position = decode_cursor(cursor) if cursor else {"snapshot": now()}
    if type(position.get("snapshot")) is not int or position["snapshot"] < 0:
        raise HTTPException(422, "INVALID_CURSOR")
    # Only newest published version of each logical track enters discovery; older share links remain usable.
    newer = aliased(TrackVersion)
    statement = (
        select(TrackVersion, Track, Player.display_name)
        .select_from(TrackVersion)
        .join(Track, Track.id == TrackVersion.track_id)
        .join(Player, Player.id == Track.owner_id)
        .where(TrackVersion.state == "published", TrackVersion.published_at <= position["snapshot"],
            ~select(newer.id).where(newer.track_id == Track.id, newer.state == "published",
                newer.published_at <= position["snapshot"], newer.number > TrackVersion.number).exists(),
            Track.hidden.is_(False), Player.disabled.is_(False))
    )
    if q.strip():
        statement = statement.where(TrackVersion.name.icontains(q.strip(), autoescape=True))
    if creator.strip():
        statement = statement.where(Player.display_name.icontains(creator.strip(), autoescape=True))
    if search.strip():
        statement = statement.where(or_(TrackVersion.name.icontains(search.strip(), autoescape=True), Player.display_name.icontains(search.strip(), autoescape=True)))
    if theme:
        statement = statement.where(TrackVersion.discovery["theme"].as_string() == theme)
    if minimum_rating:
        statement = statement.where(TrackVersion.rating_count > 0, TrackVersion.rating_sum >= minimum_rating * TrackVersion.rating_count)
    if cursor and "time" in position:
        if type(position["time"]) is not int or not isinstance(position.get("id"), str) or len(position["id"]) != 36:
            raise HTTPException(422, "INVALID_CURSOR")
        statement = statement.where((TrackVersion.published_at < position["time"]) | ((TrackVersion.published_at == position["time"]) & (TrackVersion.id > position["id"])))
        offset = 0
    rows = session.execute(
        statement.order_by(TrackVersion.published_at.desc(), TrackVersion.id).offset(offset).limit(limit + 1)
    ).all()
    items = [discovery_payload(request, v, t, p) for v, t, p in rows[:limit]]
    next_cursor = encode_cursor({"snapshot": position["snapshot"], "time": rows[limit-1][0].published_at, "id": rows[limit-1][0].id}) if len(rows) > limit else None
    session.commit()
    return {"items": items, "next_offset": offset + limit if len(rows) > limit else None, "next_cursor": next_cursor}


def published_version(session: Session, version_id: str) -> TrackVersion:
    version = session.scalar(
        select(TrackVersion)
        .join(Track)
        .join(Player, Player.id == Track.owner_id)
        .where(TrackVersion.id == version_id, TrackVersion.state == "published", Player.disabled.is_(False))
    )
    if version is None:
        raise HTTPException(404, "Published track version not found")
    return version


@router.get("/track-versions/{version_id}")
def public_version(version_id: str, request: Request, session: DB) -> dict:
    return _payload(request, session, published_version(session, version_id))


@router.get("/track-versions/{version_id}/document")
def public_document(version_id: str, request: Request, session: DB) -> Response:
    version = published_version(session, version_id) # Always recheck account visibility.
    etag = '"' + version.content_hash + '"'
    headers = {"ETag": etag, "Cache-Control": "public, max-age=0, must-revalidate"}
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers=headers)
    content_hash = version.content_hash
    session.commit()
    document = request.app.state.blobs.get_json(content_hash)
    return Response(canonical_json(document), media_type="application/json", headers=headers)


@router.get("/track-versions/{version_id}/rating")
def own_rating(version_id: str, session: DB, player: Auth) -> dict:
    version = published_version(session, version_id)
    rating = session.get(Rating, (version_id, player.id))
    eligible = not player.is_test_driver and session.get(Track, version.track_id).owner_id != player.id and bool(session.scalar(
        select(PersonalBest.player_id).join(Board).where(
            Board.version_id == version_id, PersonalBest.player_id == player.id,
            Board.manifest["test_population"].as_boolean().is_not(True)
        ).limit(1)
    ))
    return {"score": rating.score if rating else 0, "eligible": eligible}


@router.get("/me/track-versions/{version_id}/document")
def private_document(version_id: str, request: Request, session: DB, player: Auth) -> Response:
    version = session.scalar(
        select(TrackVersion).join(Track).where(TrackVersion.id == version_id, Track.owner_id == player.id)
    )
    if version is None:
        raise HTTPException(404, "Track version not found")
    content_hash = version.content_hash
    session.commit()
    return Response(canonical_json(request.app.state.blobs.get_json(content_hash)), media_type="application/json")


@router.put("/track-versions/{version_id}/rating")
def rate(version_id: str, payload: Vote, session: DB, player: Auth, key: Key) -> dict:
    if player.is_test_driver:
        raise HTTPException(403, "Test drivers cannot rate tracks")
    scope, body = f"rating:{version_id}", payload.model_dump()
    old = replay_response(session, player.id, scope, key, body)
    if old is not None:
        return old
    version = session.scalar(
        select(TrackVersion)
        .where(TrackVersion.id == version_id, TrackVersion.state == "published")
        .with_for_update()
    )
    if version is None:
        raise HTTPException(404, "Published track version not found")
    if session.get(Track, version.track_id).owner_id == player.id:
        raise HTTPException(403, "Creators cannot rate their own track")
    if not session.scalar(
        select(PersonalBest.player_id)
        .join(Board)
        .where(Board.version_id == version_id, PersonalBest.player_id == player.id,
               Board.manifest["test_population"].as_boolean().is_not(True))
        .limit(1)
    ):
        raise HTTPException(403, "Complete a verified race on this version before rating")
    rating = session.get(Rating, (version_id, player.id))
    difference = payload.score - (rating.score if rating else 0)
    increment = 0 if rating else 1
    if rating:
        rating.score, rating.updated_at = payload.score, now()
    else:
        session.add(Rating(version_id=version_id, player_id=player.id, score=payload.score))
    # PostgreSQL row lock serializes votes; SQL arithmetic also prevents stale aggregate overwrites.
    session.execute(
        update(TrackVersion)
        .where(TrackVersion.id == version_id)
        .values(
            rating_sum=TrackVersion.rating_sum + difference,
            rating_count=TrackVersion.rating_count + increment,
        )
    )
    session.flush()
    session.refresh(version)
    result = {
        "version_id": version_id,
        "score": payload.score,
        "rating_count": version.rating_count,
        "rating_average": version.rating_sum / version.rating_count,
    }
    return commit_response(session, player.id, scope, key, body, result)
