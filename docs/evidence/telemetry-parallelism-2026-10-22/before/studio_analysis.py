"""Atomic bounded analytical projection and full-scope SQL cohort reporting."""

from collections import Counter
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import BigInteger, Integer, case, cast, delete, func, select, tuple_

from .admin import Access, Window
from .admin_ranges import calendar_range
from .studio_platform_models import AnalysisDay, AnalysisPerson, AnalysisSession, AnalysisState
from .studio_queries import read_snapshot
from .telemetry_models import ProductState
from .track_models import digest, now

router = APIRouter(tags=["Studio analysis"])
DAY = 86400
COUNTERS = (
    "active",
    "race_started",
    "race_finished",
    "race_abandoned",
    "race_retried",
    "race_accepted",
    "foreground_ms",
    "quality_attempts",
    "quality_finished",
    "quality_abandoned",
    "quality_restarted",
    "quality_frames",
    "quality_slow_frames",
    "network_attempts",
    "network_successes",
    "store_opened",
    "offer_exposed",
    "purchase_requested",
    "publish_requested",
    "track_published",
)


def project(session, events, profiles, active_names):
    """Shares the durable product transaction and its receipt deduplication.

    No additional transaction, raw copy, per-event lookup or foreground HTTP.
    Existing historical totals are neither reset nor retrospectively segmented.
    """
    state = session.get(AnalysisState, 1)
    if state is None:
        raise RuntimeError("STUDIO_ANALYSIS_MIGRATION_REQUIRED")
    grouped, contexts, session_groups = {}, {}, {}
    active_events, client_first = {}, {}
    for event in events:
        props = event.properties or {}
        context = {
            "build_id": event.build_id or "",
            "platform": event.platform or "",
            "mode": str(props.get("mode", ""))[:24],
            "artificial": bool(event.is_test_driver),
            "device_model": str(props.get("device_model", ""))[:80],
            "os_version": str(props.get("os_version", ""))[:80],
            "renderer": (props.get("render_context") or {}).get("renderer", ""),
        }
        key = event.occurred_at // DAY, event.player_id, digest(context)
        contexts[key] = context
        entry = grouped.setdefault(
            key, {"counts": Counter(), "first": event.occurred_at, "last": event.occurred_at}
        )
        entry["first"], entry["last"] = (
            min(entry["first"], event.occurred_at),
            max(entry["last"], event.occurred_at),
        )
        counts = entry["counts"]
        if event.name in active_names:
            counts["active"] += 1
            prior = active_events.get(event.player_id)
            if prior is None or (event.occurred_at, event.id) < (prior.occurred_at, prior.id):
                active_events[event.player_id] = event
        if event.name in COUNTERS:
            counts[event.name] += 1
        if event.source == "client" and event.name in ("session_heartbeat", "session_backgrounded"):
            counts["foreground_ms"] += props.get("foreground_ms", 0)
        if event.name == "race_statistics" and event.source == "client":
            counts["quality_attempts"] += 1
            counts["quality_" + props["outcome"]] += 1
            counts["quality_frames"] += sum(props["frame_buckets"])
            counts["quality_slow_frames"] += sum(props["frame_buckets"][5:])
        if event.name == "network_summary" and event.source == "client":
            counts["network_attempts"] += props["attempts"]
            counts["network_successes"] += props["successes"]
        if event.source == "client":
            client_first[event.player_id] = min(
                client_first.get(event.player_id, event.occurred_at), event.occurred_at
            )
            state.latest_client_at = max(state.latest_client_at or 0, event.received_at)
            if event.session_id:
                session_groups.setdefault((event.player_id, event.session_id), []).append(event)
    days = (
        {
            (r.day, r.player_id, r.dimension): r
            for r in session.scalars(
                select(AnalysisDay).where(
                    tuple_(AnalysisDay.day, AnalysisDay.player_id, AnalysisDay.dimension).in_(grouped)
                )
            )
        }
        if grouped
        else {}
    )
    for key, values in grouped.items():
        row = days.get(key)
        if row is None:
            row = AnalysisDay(
                day=key[0],
                player_id=key[1],
                dimension=key[2],
                **contexts[key],
                counters={},
                first_at=values["first"],
                last_at=values["last"],
            )
            session.add(row)
        merged = Counter(row.counters)
        merged.update(values["counts"])
        row.counters = dict(merged)
        row.first_at, row.last_at = min(row.first_at, values["first"]), max(row.last_at, values["last"])
    people = (
        {
            r.player_id: r
            for r in session.scalars(select(AnalysisPerson).where(AnalysisPerson.player_id.in_(profiles)))
        }
        if profiles
        else {}
    )
    from .product_analytics import DAY as PRODUCT_DAY
    from .product_analytics import FIRST_RACE, ordered_journey

    for identity, event in active_events.items():
        row = people.get(identity)
        if row is None:
            row = AnalysisPerson(
                player_id=identity,
                first_at=event.occurred_at,
                first_build=event.build_id or "",
                first_platform=event.platform or "",
                first_mode=str((event.properties or {}).get("mode", ""))[:24],
                artificial=bool(event.is_test_driver),
                journey={},
            )
            session.add(row)
            people[identity] = row
        elif event.occurred_at < row.first_at:
            row.first_at, row.first_build, row.first_platform = (
                event.occurred_at,
                event.build_id or "",
                event.platform or "",
            )
            row.first_mode = str((event.properties or {}).get("mode", ""))[:24]
    for identity, row in people.items():
        if identity in client_first:
            row.first_client_at = min(row.first_client_at or client_first[identity], client_first[identity])
        profile = profiles.get(identity)
        if profile:
            frontier = ordered_journey(profile.milestones or [], FIRST_RACE, PRODUCT_DAY)
            row.journey = {
                "anchor": frontier[0][1] if frontier else None,
                "steps": len(frontier),
                "truncated": bool((profile.truncations or {}).get("first_race")),
            }
    sessions = (
        {
            (r.player_id, r.session_id): r
            for r in session.scalars(
                select(AnalysisSession).where(
                    tuple_(AnalysisSession.player_id, AnalysisSession.session_id).in_(session_groups)
                )
            )
        }
        if session_groups
        else {}
    )
    for key, entries in session_groups.items():
        first = min(entries, key=lambda e: (e.occurred_at, e.id))
        row = sessions.get(key)
        if row is None:
            row = AnalysisSession(
                player_id=key[0],
                session_id=key[1],
                first_at=first.occurred_at,
                last_at=first.occurred_at,
                build_id=first.build_id,
                platform=first.platform,
                foreground_ms=0,
                starts=0,
                finishes=0,
            )
            session.add(row)
        row.first_at = min(row.first_at, first.occurred_at)
        row.last_at = max(row.last_at, *(e.occurred_at for e in entries))
        row.foreground_ms += sum(
            (e.properties or {}).get("foreground_ms", 0)
            for e in entries
            if e.name in ("session_heartbeat", "session_backgrounded")
        )
        row.starts += sum(e.name == "race_started" for e in entries)
        row.finishes += sum(e.name == "race_finished" for e in entries)


def cleanup(session, at, limit, fact_days):
    for model, keys, timestamp in (
        (AnalysisDay, (AnalysisDay.day, AnalysisDay.player_id, AnalysisDay.dimension), AnalysisDay.day),
        (AnalysisSession, (AnalysisSession.player_id, AnalysisSession.session_id), AnalysisSession.last_at),
    ):
        floor = at // DAY - fact_days if model is AnalysisDay else at - fact_days * DAY
        expired = session.execute(select(*keys).where(timestamp < floor).order_by(*keys).limit(limit)).all()
        if expired:
            session.execute(delete(model).where(tuple_(*keys).in_(expired)))
    expired_people = session.scalars(
        select(AnalysisPerson.player_id)
        .where(
            AnalysisPerson.first_at < (at // DAY - fact_days) * DAY,
            ~select(AnalysisDay.player_id).where(AnalysisDay.player_id == AnalysisPerson.player_id).exists(),
        )
        .order_by(AnalysisPerson.player_id)
        .limit(limit)
    ).all()
    if expired_people:
        session.execute(delete(AnalysisPerson).where(AnalysisPerson.player_id.in_(expired_people)))


def sums(model, names=COUNTERS):
    return [
        func.coalesce(func.sum(cast(model.counters[name].as_string(), BigInteger)), 0).label(name)
        for name in names
    ]


def population_conditions(settings, model, population):
    if population not in ("all", "real", "artificial"):
        raise HTTPException(422, "INVALID_ANALYSIS_POPULATION")
    if population != "all" and not settings.studio_business_cohorts:
        raise HTTPException(409, "SEPARATE_BUSINESS_COHORTS_NOT_ENABLED")
    return [] if population == "all" else [model.artificial.is_(population == "artificial")]


def interval(window):
    requested = window or calendar_range(7)
    return requested, (requested[0] // DAY * DAY, ((requested[1] - 1) // DAY + 1) * DAY)


@router.get("/v1/admin/analysis/behaviour")
def behaviour(
    request: Request,
    role: Access,
    window: Window,
    build_id: str = Query("", max_length=80),
    platform: str = Query("", max_length=12),
    mode: str = Query("", max_length=24),
    population: str = "all",
    view: Literal["activity", "retention", "journey", "engagement", "all"] = "activity",
):
    requested, (first, until) = interval(window)
    at = now()
    with request.app.state.session_factory() as session:
        read_snapshot(session)
        state, product = session.get(AnalysisState, 1), session.get(ProductState, 1)
        retained_floor = at // DAY - (product.fact_days if product else 180)
        conditions = [AnalysisDay.day >= first // DAY, AnalysisDay.day < until // DAY]
        conditions += population_conditions(request.app.state.settings, AnalysisDay, population)
        for field, value in (("build_id", build_id), ("platform", platform), ("mode", mode)):
            if value:
                conditions.append(getattr(AnalysisDay, field) == value)
        counts, players, daily = None, None, []
        engagement, retention, first_race = None, [], None
        active = AnalysisDay.counters["active"].as_integer() > 0
        if view in ("activity", "all"):
            aggregate = dict(session.execute(select(
                func.count(func.distinct(case((active, AnalysisDay.player_id)))).label("active_players"),
                *sums(AnalysisDay)).where(*conditions)).mappings().one())
            players = aggregate.pop("active_players")
            counts = aggregate
            daily = session.execute(select(AnalysisDay.day,
                func.count(func.distinct(case((active, AnalysisDay.player_id)))),
                *sums(AnalysisDay, ("foreground_ms", "race_started", "race_finished", "race_accepted")))
                .where(*conditions).group_by(AnalysisDay.day).order_by(AnalysisDay.day)).all()
        options = session.execute(
            select(AnalysisDay.build_id, AnalysisDay.platform, AnalysisDay.mode)
            .where(AnalysisDay.day >= first // DAY, AnalysisDay.day < until // DAY)
            .distinct()
            .order_by(AnalysisDay.build_id, AnalysisDay.platform, AnalysisDay.mode)
            .limit(201)
        ).all()
        cohorts = [AnalysisPerson.first_at >= first, AnalysisPerson.first_at < until]
        cohorts += population_conditions(request.app.state.settings, AnalysisPerson, population)
        if build_id:
            cohorts.append(AnalysisPerson.first_build == build_id)
        if platform:
            cohorts.append(AnalysisPerson.first_platform == platform)
        session_conditions = [AnalysisSession.first_at >= first, AnalysisSession.first_at < until]
        if build_id:
            session_conditions.append(AnalysisSession.build_id == build_id)
        if platform:
            session_conditions.append(AnalysisSession.platform == platform)
        # Session population is joined to the same immutable first-observation classification.
        session_conditions += population_conditions(request.app.state.settings, AnalysisPerson, population)
        if view in ("engagement", "all"):
            engagement = dict(
                session.execute(
                    select(
                        func.count().label("sessions"),
                        func.coalesce(func.sum(AnalysisSession.foreground_ms), 0).label("foreground_ms"),
                        func.count(case((AnalysisSession.foreground_ms > 0, 1))).label("sessions_with_duration"),
                    )
                    .select_from(AnalysisSession)
                    .join(AnalysisPerson, AnalysisPerson.player_id == AnalysisSession.player_id)
                    .where(*session_conditions)
                )
                .mappings()
                .one()
            )
        cohort_day = cast(func.floor(AnalysisPerson.first_at / DAY), Integer)
        sizes, returns = {}, {offset: {} for offset in (1, 7, 30)}
        if view in ("retention", "all"):
            sizes = dict(session.execute(select(cohort_day, func.count()).where(*cohorts).group_by(cohort_day)).all())
            offset_day = AnalysisDay.day - cohort_day
            returned = session.execute(select(cohort_day, offset_day,
                func.count(func.distinct(AnalysisPerson.player_id))).join(AnalysisDay,
                    (AnalysisDay.player_id == AnalysisPerson.player_id)
                    & AnalysisDay.day.in_([cohort_day + offset for offset in (1, 7, 30)]))
                .where(*cohorts, AnalysisDay.counters["active"].as_integer() > 0)
                .group_by(cohort_day, offset_day)).all()
            for day, offset, count in returned:
                returns[int(offset)][day] = count
        watermark = state.processed_through if state else None
        retention = []
        for day, size in sorted(sizes.items()):
            item = {
                "day": datetime.fromtimestamp(day * DAY, timezone.utc).date().isoformat(),
                "players": size,
            }
            for offset in (1, 7, 30):
                mature = bool(
                    watermark
                    and day >= retained_floor
                    and day + offset >= retained_floor
                    and (day + offset + 1) * DAY <= min(at, watermark)
                )
                item["d" + str(offset)] = {
                    "eligible": size,
                    "returned": returns[offset].get(day, 0) if mature else None,
                    "mature": mature,
                    "finalised": mature and (day + offset + 8) * DAY <= at,
                }
            retention.append(item)
        if view in ("journey", "all"):
            from .product_analytics import FIRST_RACE
            anchor = AnalysisPerson.journey["anchor"].as_integer()
            eligible = [*cohorts, anchor >= max(first, state.started_at if state else first), anchor < until,
                anchor + DAY + 600 <= min(at, watermark or 0)]
            totals = session.execute(select(func.count(),
                func.count(case((AnalysisPerson.journey["truncated"].as_boolean().is_(True), 1))),
                *[func.count(case((AnalysisPerson.journey["steps"].as_integer() > index, 1)))
                  for index in range(len(FIRST_RACE))]).select_from(AnalysisPerson).where(*eligible)).one()
            first_race = {"eligible": totals[0], "truncated_profiles": totals[1],
                "steps": [{"name": name, "players": None if totals[1] else totals[index + 2]}
                          for index, name in enumerate(FIRST_RACE)]}
        return {
            "schema": "bmt-studio-behaviour-v1",
            "role": role,
            "as_of": at,
            "requested_since": requested[0],
            "requested_until": requested[1],
            "since": first,
            "until": until,
            "filters": {"build_id": build_id, "platform": platform, "mode": mode, "population": population},
            "options": [{"build_id": b, "platform": p, "mode": m} for b, p, m in options[:200]],
            "options_truncated": len(options) > 200,
            "active_players": players,
            "counters": counts,
            "daily": [
                {
                    "day": day,
                    "players": n,
                    "foreground_ms": duration,
                    "starts": starts,
                    "finishes": finishes,
                    "accepted": accepted,
                }
                for day, n, duration, starts, finishes, accepted in daily
            ],
            "view": view,
            "engagement": engagement,
            "retention": retention,
            "first_race": first_race,
            "business_cohorts_enabled": request.app.state.settings.studio_business_cohorts,
            "coverage": {
                "collection_enabled": request.app.state.settings.telemetry_enabled,
                "started_at": state.started_at if state else None,
                "processed_through": watermark,
                "retained_from": retained_floor * DAY,
                "latest_client_at": state.latest_client_at if state else None,
                "pending_events": product.pending_events if product else None,
                "available": bool(
                    state
                    and state.latest_client_at
                    and until > max(state.started_at, retained_floor * DAY)
                    and first <= min(at, watermark or 0)
                ),
                "definition": "Analysis v1 starts at migration; first observed qualifying activity is not installation or a new account. No historical dimensions are reconstructed.",
                "cohort_scope": "First-observation build/platform and selected population; mode filters activity only.",
                "foreground": "Sum of client-reported foreground intervals; missing final intervals and concurrent devices affect coverage.",
                "retention": "Exact UTC D1/D7/D30, any return build; follow-up is provisional for seven additional days.",
                "guest": "Unavailable; no guest/account linking",
                "totals": "Full filtered SQL aggregates; detail option limits do not truncate metrics",
            },
        }
