"""Immutable track uploads, verified publication, discovery and qualified ratings."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session, aliased

from .contracts import current_manifest
from .cursors import decode_cursor, encode_cursor
from .db import get_session
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .security import bearer, current_player
from .storage import canonical_json
from .track_models import (
    Board,
    PersonalBest,
    Rating,
    Run,
    Track,
    TrackValidation,
    TrackVersion,
    commit_response,
    now,
    replay_response,
)

router = APIRouter(route_class=ParsedJSONRoute, tags=["tracks"])
DB = Annotated[Session, Depends(get_session)]
Auth = Annotated[Player, Depends(current_player)]
Key = Annotated[str, Header(alias="Idempotency-Key")]


class TrackContent(BaseModel):
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
        **(version.discovery or {}),
        "track_id": track.id,
        "authoring_id": track.authoring_id or (version.discovery or {}).get("authoring_id"),
        "version_id": version.id,
        "version": version.number,
        "name": version.name,
        "creator_id": track.owner_id,
        "creator": creator,
        "redacted_track_hash": version.redacted_track_hash,
        "canonical_track_hash": version.manifest.get("track_content_hash") if version.redacted_track_hash else None,
        "state": version.state,
        "hidden": track.hidden,
        "content_hash": version.content_hash,
        "created_at": version.created_at,
        "published_at": version.published_at,
        "rating_count": version.rating_count,
        "rating_average": round(version.rating_sum / version.rating_count, 3)
        if version.rating_count
        else None,
        "share_url": f"{base_url.rstrip('/')}/t/{version.id}",
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


@router.post("/tracks", include_in_schema=False)
@router.post("/tracks/{track_id}/versions", include_in_schema=False)
@router.post("/me/track-versions/{version_id}/retry-validation", include_in_schema=False)
@router.post("/track-versions/{version_id}/publish", include_in_schema=False)
@router.post("/me/drafts/{authoring_id}/archive", include_in_schema=False)
@router.get("/me/drafts/{authoring_id}/head", include_in_schema=False)
def retired_authoring(player: Auth):
    raise HTTPException(410, "LOCAL_DRAFTS_ONLY: keep drafts on this device; use an explicit verified publication request")


def discovery_projection(document: dict) -> dict:
    points = document.get("points", [])
    if not isinstance(points, list):
        points = []
    count = min(96, len(points))
    return {"theme": document.get("theme", "pine"), "authoring_id": document.get("id"),
            "points": [points[i * len(points) // count] for i in range(count)]}


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
    credentials=Depends(bearer),
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
    from .community import blocked_ids
    if credentials:
        viewer = current_player(request, credentials, session)
        statement = statement.where(Track.owner_id.not_in(blocked_ids(session, viewer.id)))
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


def _check_viewer(request, session, version, credentials):
    track = session.get(Track, version.track_id)
    if track.hidden:
        from .studio_case_models import StudioQuarantine
        if session.get(StudioQuarantine, track.id) is not None:
            raise HTTPException(404, "Published track version not found")
    if credentials:
        from .community import check_creator
        viewer = current_player(request, credentials, session)
        check_creator(session, viewer.id, session.get(Track, version.track_id).owner_id)


@router.get("/track-versions/{version_id}")
def public_version(version_id: str, request: Request, session: DB, credentials=Depends(bearer)) -> dict:
    version = published_version(session, version_id)
    _check_viewer(request, session, version, credentials)
    return _payload(request, session, version)


@router.get("/track-versions/{version_id}/document")
def public_document(version_id: str, request: Request, session: DB, credentials=Depends(bearer)) -> Response:
    version = published_version(session, version_id) # Always recheck account visibility.
    _check_viewer(request, session, version, credentials)
    owner = session.get(Player, session.get(Track, version.track_id).owner_id)
    if owner.deleted_at is not None and version.redacted_track_hash is None:
        raise HTTPException(503, "AUTHOR_REDACTION_PENDING")
    etag = '"' + version.content_hash + '"'
    headers = {"ETag": etag, "Cache-Control": "private, max-age=0, must-revalidate", "Vary": "Authorization"}
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers=headers)
    content_hash = version.content_hash
    session.commit()
    body = request.app.state.immutable_payloads.get(("track", content_hash),
        lambda: canonical_json(request.app.state.blobs.get_json(content_hash)))
    return Response(body, media_type="application/json", headers=headers)


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
