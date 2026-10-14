"""Published content and redacted player context for the Studio investigation desk.

Catalogue reads use stored discovery projections. They never fetch documents or
generate geometry. Lists are bounded; race counts describe server submissions,
not client starts, and absent observation coverage remains unknown.
"""

import math
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select, text
from sqlalchemy.orm import aliased

from .admin import Access, Window, record
from .admin_ranges import calendar_range
from .commerce import access_values, catalog_products, entitlement_payload, simulator_allowed
from .commerce_models import Entitlements, PublicationSlot, Purchase
from .identity_models import Identity, Player
from .middleware import ParsedJSONRoute
from .quality_models import QualityFact
from .resume_models import ResumeWallet
from .studio import MANIFEST_FIELDS
from .studio_case_models import StudioCase, StudioCaseEvent
from .telemetry_models import ProductPlayerDay, ProductProfile, ProductState
from .track_models import Board, PersonalBest, Run, Track, TrackVersion, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["Studio catalogue"])


def snapshot(session):
    if session.bind.dialect.name == "postgresql":
        session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
    elif session.bind.dialect.name == "sqlite":
        session.execute(text("BEGIN"))


def response(data):
    return JSONResponse(data, headers={"Cache-Control": "no-store"})


def preview(discovery):
    """Defend old projections without loading their source document."""
    data = discovery if isinstance(discovery, dict) else {}
    points = data.get("points", [])
    if not isinstance(points, list):
        points = []
    count = min(96, len(points))
    valid = []
    for index in range(count):
        point = points[index * len(points) // count]
        if (isinstance(point, list) and len(point) >= 2 and all(type(n) in (int, float)
                and math.isfinite(n) and abs(n) <= 100000 for n in point[:2])):
            valid.append(point[:2])
    return {"theme": data.get("theme") if isinstance(data.get("theme"), str) and len(data["theme"]) <= 40 else None,
        "points": valid, "available": len(valid) >= 2,
        "source": "stored_discovery_projection", "point_limit": 96}


def track_record(version, track, creator):
    return {"id": version.id, "track_id": track.id, "number": version.number,
        "name": version.name, "creator_id": creator.id, "creator_name": creator.display_name,
        "creator_is_test_driver": creator.is_test_driver, "official": track.official,
        "hidden": track.hidden, "archived": track.archived, "created_at": version.created_at,
        "published_at": version.published_at, "rating_count": version.rating_count,
        "rating_average": round(version.rating_sum / version.rating_count, 3) if version.rating_count else None,
        "verified_finishers": version.verified_finishers, "preview": preview(version.discovery)}


def observations(session, ids, window):
    """Read only prepared discovery facts, restricted to this published page."""
    state = session.get(ProductState, 1)
    first, until = window
    rows = session.scalars(select(QualityFact).where(QualityFact.kind == "discovery",
        QualityFact.day >= first // 86400, QualityFact.day <= (until - 1) // 86400,
        QualityFact.context["track_version_id"].as_string().in_(ids))
        .order_by(QualityFact.day.desc(), QualityFact.dimension).limit(1001)).all() if ids else []
    counts = {}
    for row in rows[:1000]:
        identity = row.context.get("track_version_id")
        item = counts.setdefault(identity, {"exposures": 0, "selections": 0})
        item["exposures"] += row.reports
        item["selections"] += row.samples
    return counts, {"collection_started_at": state.collection_started_at if state else None,
        "processed_through": state.processed_through if state else None,
        "pending_events": state.pending_events if state else None,
        "fact_rows_truncated": len(rows) > 1000,
        "since": first, "until": until,
        "definition": "Prepared signed-in card exposure and selection observations. UTC day buckets; missing observations are unknown. Selection is not a race start."}


@router.get("/v1/admin/catalogue/tracks")
def tracks(request: Request, role: Access, window: Window,
    q: str = Query("", max_length=100), theme: str = Query("", max_length=40),
    visibility: Literal["all", "visible", "hidden", "archived"] = "all",
    origin: Literal["all", "official", "community"] = "all",
    creator_id: UUID | None = None, min_rating: float = Query(0, ge=0, le=5),
    min_finishers: int = Query(0, ge=0, le=1000000000),
    versions: Literal["latest", "all"] = "latest",
    sort: Literal["published", "name", "creator", "rating", "finishers"] = "published",
    direction: Literal["asc", "desc"] = "desc", offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(25, ge=1, le=100), anchor: int | None = Query(None, ge=0)):
    anchor = now() if anchor is None else anchor
    if anchor > now():
        raise HTTPException(422, "INVALID_CATALOGUE_ANCHOR")
    with request.app.state.session_factory() as session:
        snapshot(session)
        conditions = [TrackVersion.state == "published", TrackVersion.created_at <= anchor]
        if versions == "latest":
            newer = aliased(TrackVersion)
            conditions.append(~select(newer.id).where(newer.track_id == TrackVersion.track_id,
                newer.state == "published", newer.created_at <= anchor,
                newer.number > TrackVersion.number).exists())
        if q:
            conditions.append(or_(*(field.icontains(q, autoescape=True) for field in
                (TrackVersion.name, TrackVersion.id, Track.id, Player.display_name,
                 TrackVersion.discovery["theme"].as_string()))))
        if theme:
            conditions.append(TrackVersion.discovery["theme"].as_string() == theme)
        if visibility == "visible":
            conditions.extend((Track.hidden.is_(False), Track.archived.is_(False)))
        elif visibility == "hidden":
            conditions.append(Track.hidden.is_(True))
        elif visibility == "archived":
            conditions.append(Track.archived.is_(True))
        if origin != "all":
            conditions.append(Track.official == (origin == "official"))
        if creator_id:
            conditions.append(Track.owner_id == str(creator_id))
        rating = TrackVersion.rating_sum * 1.0 / func.nullif(TrackVersion.rating_count, 0)
        if min_rating:
            conditions.append(rating >= min_rating)
        if min_finishers:
            conditions.append(TrackVersion.verified_finishers >= min_finishers)
        query = select(TrackVersion, Track, Player).join(Track, Track.id == TrackVersion.track_id).join(
            Player, Player.id == Track.owner_id).where(*conditions)
        count_query = select(func.count()).select_from(query.subquery())
        order = {"published": TrackVersion.published_at, "name": func.lower(TrackVersion.name),
            "creator": func.lower(Player.display_name), "rating": rating,
            "finishers": TrackVersion.verified_finishers}[sort]
        ordering = order.asc() if direction == "asc" else order.desc()
        if sort in ("rating", "published"):
            ordering = ordering.nulls_last()
        rows = session.execute(query.order_by(ordering,
            TrackVersion.id.asc() if direction == "asc" else TrackVersion.id.desc()).offset(offset).limit(limit)).all()
        facts, coverage = observations(session, [version.id for version, _track, _player in rows],
            window or calendar_range(7))
        items = []
        for version, track, player in rows:
            item = track_record(version, track, player)
            item["discovery"] = facts.get(version.id)
            items.append(item)
        total = session.scalar(count_query)
        return response({"role": role, "items": items, "total": total, "offset": offset, "limit": limit,
            "summary": {"published_versions": total, "scope": "Matching published immutable versions"},
            "coverage": coverage, "as_of": now(), "anchor": anchor, "read_only": True,
            "paging": "Creation-time anchor excludes later inserts; rating, visibility and publication changes are current and can reorder pages.",
            "catalogue_policy": "Published content only. Local drafts are not a server monitoring source."})


def accepted_seconds(run, board):
    rate = (board.manifest or {}).get("tick_rate") if board else None
    return run.time_ticks / rate if run.status == "verified" and type(run.time_ticks) is int and run.time_ticks > 0 \
        and type(rate) is int and 0 < rate <= 1000 else None


@router.get("/v1/admin/catalogue/tracks/{version_id}")
def track(version_id: UUID, request: Request, role: Access, window: Window):
    with request.app.state.session_factory() as session:
        snapshot(session)
        version = session.get(TrackVersion, str(version_id))
        if version is None or version.state != "published":
            raise HTTPException(404, "PUBLISHED_VERSION_NOT_FOUND")
        parent, player = session.get(Track, version.track_id), None
        player = session.get(Player, parent.owner_id)
        result = track_record(version, parent, player)
        result.update(content_hash=version.content_hash,
            manifest={key: version.manifest.get(key) for key in MANIFEST_FIELDS if key in version.manifest},
            creator_test_run_id=version.creator_test_run_id)
        facts, coverage = observations(session, [version.id], window or calendar_range(7))
        result["discovery"] = facts.get(version.id)
        runs = session.execute(select(Run, Board, Player).join(Board, Board.id == Run.board_id).join(
            Player, Player.id == Run.player_id).where(Board.version_id == version.id)
            .order_by(Run.created_at.desc(), Run.id).limit(20)).all()
        cases = session.scalars(select(StudioCase).where(StudioCase.track_id == parent.id)
            .order_by(StudioCase.updated_at.desc(), StudioCase.id).limit(11)).all()
        versions = session.execute(select(TrackVersion.id, TrackVersion.number, TrackVersion.published_at)
            .where(TrackVersion.track_id == parent.id, TrackVersion.state == "published")
            .order_by(TrackVersion.number.desc()).limit(21)).all()
        return response({"role": role, "track": result,
            "recent_races": [{"id": run.id, "player_id": racer.id, "player_name": racer.display_name,
                "is_test_driver": racer.is_test_driver, "status": run.status, "created_at": run.created_at,
                "vehicle_id": board.vehicle_id, "accepted_seconds": accepted_seconds(run, board),
                "failure_code": run.failure_code} for run, board, racer in runs],
            "cases": [case_record(case) for case in cases[:10]], "cases_truncated": len(cases) > 10,
            "versions": [{"id": identity, "number": number, "published_at": published}
                for identity, number, published in versions[:20]], "versions_truncated": len(versions) > 20,
            "coverage": coverage, "as_of": now(), "read_only": True})


def case_record(case):
    return {key: getattr(case, key) for key in ("id", "title", "status", "revision", "created_at", "updated_at")}


def player_counts(session, ids):
    if not ids:
        return {}, {}, {}, {}, {}
    race = {identity: {"submissions": count, "verified_submissions": accepted, "last_submission_at": latest}
        for identity, count, accepted, latest in session.execute(select(Run.player_id, func.count(),
            func.count().filter(Run.status == "verified"), func.max(Run.created_at))
            .where(Run.player_id.in_(ids)).group_by(Run.player_id))}
    bests = dict(session.execute(select(PersonalBest.player_id, func.count())
        .where(PersonalBest.player_id.in_(ids)).group_by(PersonalBest.player_id)).all())
    publications = dict(session.execute(select(Track.owner_id, func.count()).join(
        TrackVersion, TrackVersion.track_id == Track.id).where(Track.owner_id.in_(ids),
            TrackVersion.state == "published").group_by(Track.owner_id)).all())
    cases = dict(session.execute(select(StudioCase.player_id, func.count()).where(
        StudioCase.player_id.in_(ids), StudioCase.status != "resolved").group_by(StudioCase.player_id)).all())
    active = dict(session.execute(select(ProductPlayerDay.player_id, func.max(ProductPlayerDay.day)).where(
        ProductPlayerDay.player_id.in_(ids)).group_by(ProductPlayerDay.player_id)).all())
    return race, bests, publications, cases, active


@router.get("/v1/admin/catalogue/players")
def players(request: Request, role: Access, q: str = Query("", max_length=100),
    state: Literal["all", "active", "disabled", "username_pending"] = "all",
    population: Literal["all", "real", "artificial"] = "all", provider: str = Query("", max_length=32),
    sort: Literal["created", "name"] = "created", direction: Literal["asc", "desc"] = "desc",
    offset: int = Query(0, ge=0, le=10000), limit: int = Query(25, ge=1, le=100),
    anchor: int | None = Query(None, ge=0)):
    anchor = now() if anchor is None else anchor
    if anchor > now():
        raise HTTPException(422, "INVALID_CATALOGUE_ANCHOR")
    with request.app.state.session_factory() as session:
        snapshot(session)
        conditions = [Player.created_at <= anchor]
        if q:
            conditions.append(or_(Player.id.icontains(q, autoescape=True), Player.display_name.icontains(q, autoescape=True)))
        if state in ("active", "disabled"):
            conditions.append(Player.disabled == (state == "disabled"))
        elif state == "username_pending":
            conditions.append(Player.needs_username.is_(True))
        if population != "all":
            conditions.append(Player.is_test_driver == (population == "artificial"))
        if provider:
            conditions.append(select(Identity.id).where(Identity.player_id == Player.id,
                Identity.provider == provider).exists())
        query = select(Player).where(*conditions)
        order = Player.created_at if sort == "created" else func.lower(Player.display_name)
        rows = session.scalars(query.order_by(order.asc() if direction == "asc" else order.desc(),
            Player.id.asc() if direction == "asc" else Player.id.desc()).offset(offset).limit(limit)).all()
        ids = [player.id for player in rows]
        race, bests, publications, cases, active = player_counts(session, ids)
        providers = {}
        for identity, login in session.execute(select(Identity.player_id, Identity.provider).where(Identity.player_id.in_(ids))):
            providers.setdefault(identity, set()).add(login)
        items = [{"id": player.id, "display_name": player.display_name, "is_test_driver": player.is_test_driver,
            "disabled": player.disabled, "needs_username": player.needs_username, "created_at": player.created_at,
            "country_code": player.country_code or None, "providers": sorted(providers.get(player.id, [])),
            "races": race.get(player.id, {"submissions": 0, "verified_submissions": 0, "last_submission_at": None}),
            "personal_bests": bests.get(player.id, 0), "published_versions": publications.get(player.id, 0),
            "open_cases": cases.get(player.id, 0), "last_observed_activity_day": active.get(player.id)} for player in rows]
        summary = session.execute(select(func.count(), func.count().filter(Player.is_test_driver.is_(True)),
            func.count().filter(Player.disabled.is_(True))).where(*conditions)).one()
        return response({"role": role, "items": items, "total": summary[0], "offset": offset, "limit": limit,
            "summary": {"accounts": summary[0], "artificial": summary[1], "restricted": summary[2]},
            "as_of": now(), "anchor": anchor,
            "paging": "Creation-time anchor excludes later inserts; account names and restrictions are current and can reorder pages.",
            "coverage": "Server race counts include artificial drivers. Last observed activity is a retained signed-in UTC day, not precise last-online time. Guest, email, recovery proof, revenue and device identity are unavailable."})


@router.get("/v1/admin/catalogue/players/{player_id}")
def player(player_id: UUID, request: Request, role: Access):
    with request.app.state.session_factory() as session:
        snapshot(session)
        identity = str(player_id)
        account = session.get(Player, identity)
        if account is None:
            raise HTTPException(404, "PLAYER_NOT_FOUND")
        access = support_context(session, account, request.app.state.settings, role)
        race, bests, publications, cases, active = player_counts(session, [identity])
        rows = session.scalars(select(StudioCase).where(StudioCase.player_id == identity)
            .order_by(StudioCase.updated_at.desc(), StudioCase.id).limit(11)).all()
        events = session.execute(select(StudioCaseEvent, StudioCase).join(StudioCase,
            StudioCase.id == StudioCaseEvent.case_id).where(StudioCase.player_id == identity)
            .order_by(StudioCaseEvent.created_at.desc(), StudioCaseEvent.id).limit(21)).all()
        profile = session.get(ProductProfile, identity)
        return response({"role": role, "support": access,
            "activity": {**race.get(identity, {"submissions": 0, "verified_submissions": 0, "last_submission_at": None}),
                "personal_bests": bests.get(identity, 0), "published_versions": publications.get(identity, 0),
                "open_cases": cases.get(identity, 0), "last_observed_activity_day": active.get(identity)},
            "cases": [case_record(row) for row in rows[:10]], "cases_truncated": len(rows) > 10,
            "case_activity": [{"id": event.id, "case_id": case.id, "title": case.title,
                "kind": event.kind, "created_at": event.created_at, "revision": event.revision}
                for event, case in events[:20]], "case_activity_truncated": len(events) > 20,
            "observed_journey": {"first_activity_at": profile.first_activity_at,
                "milestones": [{"name": milestone[0], "at": milestone[1]} for milestone in
                    (profile.milestones or [])[:128] if isinstance(milestone, list) and len(milestone) >= 2],
                "truncated": profile.truncated} if profile else None,
            "as_of": now(), "coverage": {"financial_revenue": "unavailable", "verified_recovery": "unavailable",
                "compensation": "unavailable", "client_device_identity": "unavailable",
                "guest_linkage": "unavailable", "individual_staff_identity": "credential role only"}})


def support_context(session, player, settings, role):
    """Reuse existing domain policies inside the same read-only snapshot."""
    owned = session.get(Entitlements, player.id)
    wallet = session.get(ResumeWallet, player.id)
    values = access_values(owned)
    effective = owned or Entitlements(player_id=player.id, **values)
    eligible = simulator_allowed(session, settings, player.id) and not player.disabled
    return {"player": {**record("players", player), "country_code": player.country_code,
            "providers": sorted(set(session.scalars(select(Identity.provider).where(Identity.player_id == player.id))))},
        "access": values, "initialized": owned is not None,
        "effective": entitlement_payload(session, settings, effective),
        "resumes": {"banked": wallet.balance if wallet else 0,
            "daily_free_available": not wallet or wallet.free_day < now() // 86400},
        "consumed_publication_slots": session.scalar(select(func.count()).select_from(PublicationSlot)
            .where(PublicationSlot.player_id == player.id)),
        "pending_purchases": session.scalar(select(func.count()).select_from(Purchase)
            .where(Purchase.player_id == player.id, Purchase.state == "pending")),
        "products": catalog_products(session), "as_of": now(),
        "development_controls": {"editable": role == "owner" and eligible,
            "configured": settings.purchase_simulation_enabled and settings.environment == "development"
                and settings.dev_auth_enabled, "eligible": bool(eligible), "role": role}}
