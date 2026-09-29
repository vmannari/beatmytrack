"""Immutable track uploads, verified publication, discovery and qualified ratings."""

from __future__ import annotations

import json
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from .db import get_session
from .identity_models import Player
from .security import current_player
from .track_models import (
    Board,
    PersonalBest,
    Rating,
    Track,
    TrackVersion,
    commit_response,
    now,
    replay_response,
)

router = APIRouter(tags=["tracks"])
DB = Annotated[Session, Depends(get_session)]
Auth = Annotated[Player, Depends(current_player)]
Key = Annotated[str, Header(alias="Idempotency-Key")]


class UploadTrack(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=1, max_length=80)
    document: dict

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
        "track_id": track.id,
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
        "manifest": version.manifest,
    }


def _payload(request: Request, session: Session, version: TrackVersion) -> dict:
    track = session.get(Track, version.track_id)
    owner = session.get(Player, track.owner_id)
    return track_payload(version, track, owner.display_name, request.app.state.settings.public_base_url)


def _validate_and_store(request: Request, payload: UploadTrack, player: Player) -> tuple[str, dict]:
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
    return request.app.state.blobs.put_json(payload.document), manifest


@router.post("/tracks", status_code=201)
def create_track(payload: UploadTrack, request: Request, session: DB, player: Auth, key: Key) -> dict:
    body = payload.model_dump()
    old = replay_response(session, player.id, "create_track", key, body)
    if old is not None:
        return old
    content_hash, manifest = _validate_and_store(request, payload, player)
    track = Track(owner_id=player.id)
    session.add(track)
    session.flush()
    version = TrackVersion(
        track_id=track.id, number=1, name=payload.name, content_hash=content_hash, manifest=manifest
    )
    session.add(version)
    session.flush()
    return commit_response(session, player.id, "create_track", key, body, _payload(request, session, version))


@router.post("/tracks/{track_id}/versions", status_code=201)
def create_version(
    track_id: str, payload: UploadTrack, request: Request, session: DB, player: Auth, key: Key
) -> dict:
    scope, body = f"version:{track_id}", payload.model_dump()
    old = replay_response(session, player.id, scope, key, body)
    if old is not None:
        return old
    track = session.scalar(
        select(Track).where(Track.id == track_id, Track.owner_id == player.id).with_for_update()
    )
    if track is None:
        raise HTTPException(404, "Track not found")
    content_hash, manifest = _validate_and_store(request, payload, player)
    number = (
        session.scalar(select(func.max(TrackVersion.number)).where(TrackVersion.track_id == track_id)) + 1
    )
    version = TrackVersion(
        track_id=track.id, number=number, name=payload.name, content_hash=content_hash, manifest=manifest
    )
    session.add(version)
    session.flush()
    return commit_response(session, player.id, scope, key, body, _payload(request, session, version))


@router.post("/track-versions/{version_id}/publish")
def publish(version_id: str, request: Request, session: DB, player: Auth, key: Key) -> dict:
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
        raise HTTPException(409, "Creator must complete a server-verified five-lap test before publishing")
    if session.get(Track, version.track_id).hidden:
        raise HTTPException(409, "Hidden track cannot be published")
    version.state = "published"
    version.published_at = version.published_at or now()
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


@router.get("/me/tracks")
def my_tracks(
    request: Request,
    session: DB,
    player: Auth,
    offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    versions = session.scalars(
        select(TrackVersion)
        .join(Track)
        .where(Track.owner_id == player.id)
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
) -> dict:
    # Only newest published version of each logical track enters discovery; older share links remain usable.
    newest = (
        select(TrackVersion.track_id, func.max(TrackVersion.number).label("number"))
        .where(TrackVersion.state == "published")
        .group_by(TrackVersion.track_id)
        .subquery()
    )
    statement = (
        select(TrackVersion, Track, Player.display_name)
        .select_from(TrackVersion)
        .join(Track, Track.id == TrackVersion.track_id)
        .join(Player, Player.id == Track.owner_id)
        .join(newest, (newest.c.track_id == Track.id) & (newest.c.number == TrackVersion.number))
        .where(Track.hidden.is_(False), Player.disabled.is_(False))
    )
    if q.strip():
        statement = statement.where(TrackVersion.name.icontains(q.strip(), autoescape=True))
    if creator.strip():
        statement = statement.where(Player.display_name.icontains(creator.strip(), autoescape=True))
    rows = session.execute(
        statement.order_by(TrackVersion.published_at.desc(), TrackVersion.id).offset(offset).limit(limit + 1)
    ).all()
    return {
        "items": [
            track_payload(v, t, p, request.app.state.settings.public_base_url) for v, t, p in rows[:limit]
        ],
        "next_offset": offset + limit if len(rows) > limit else None,
    }


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
def public_document(version_id: str, request: Request, session: DB) -> dict:
    return request.app.state.blobs.get_json(published_version(session, version_id).content_hash)


@router.get("/me/track-versions/{version_id}/document")
def private_document(version_id: str, request: Request, session: DB, player: Auth) -> dict:
    version = session.scalar(
        select(TrackVersion).join(Track).where(TrackVersion.id == version_id, Track.owner_id == player.id)
    )
    if version is None:
        raise HTTPException(404, "Track version not found")
    return request.app.state.blobs.get_json(version.content_hash)


@router.put("/track-versions/{version_id}/rating")
def rate(version_id: str, payload: Vote, session: DB, player: Auth, key: Key) -> dict:
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
        .where(Board.version_id == version_id, PersonalBest.player_id == player.id)
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
