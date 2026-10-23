"""Independent bounded projection and prepared product reads; never scans raw races."""

from datetime import datetime, timezone

from fastapi import APIRouter, Query, Request
from sqlalchemy import func, select, text

from .admin import Access, Window
from .admin_ranges import calendar_range
from .middleware import ParsedJSONRoute
from .telemetry_models import (
    ProductMetric,
    ProductPlayerDay,
    ProductState,
)
from .track_models import now

router = APIRouter(route_class=ParsedJSONRoute, tags=["product analytics"])
DAY = 86400
MILESTONE_LIMIT = 128
ACTIVE = {"session_started", "session_foregrounded", "session_heartbeat", "menu_ready", "race_started",
    "editor_opened", "race_accepted", "creator_validated", "track_published"}
FIRST_RACE = ("app_first_open", "menu_ready", "race_attempt", "race_started", "race_finished", "second_voluntary_race")
CREATOR = ("editor_opened", "draft_saved", "publish_requested", "track_published")
PUBLICATION_REQUEST = ("publish_requested", "track_published")
MILESTONES = set(FIRST_RACE[:-1] + CREATOR)
PENDING_PROBE_LIMIT = 5000


def milestone(value):
    return list(value) if len(value) == 5 else [value[0], value[1], "", 0, 0]


def order(value):
    return value[1], value[3], value[4], value[2]


def after(value, prior, *, strict=False):
    if value[1] != prior[1]:
        return value[1] > prior[1]
    if value[2] and value[2] == prior[2]:
        return (value[3], value[4]) > (prior[3], prior[4]) if strict else (value[3], value[4]) >= (prior[3], prior[4])
    return not strict


def ordered_journey(values, steps, horizon):
    anchors = [value for value in values if value[0] == steps[0]]
    if not anchors:
        return []
    start = min(anchors, key=order)
    prior, result = start, []
    for name in steps:
        if name == "second_voluntary_race":
            candidates = [value for value in values if value[0] == "race_started" and after(value, prior, strict=True)
                and value[1] <= prior[1] + 600]
        else:
            candidates = [value for value in values if value[0] == name and after(value, prior)
                and value[1] <= start[1] + horizon]
        if not candidates:
            break
        prior = min(candidates, key=order)
        result.append(prior)
    return result


def bounded_frontiers(values):
    """Keep earliest relevant per-step frontiers rather than all later replays."""
    values = [milestone(value) for value in values]
    result, truncated = [], set()
    protected, selected_by_prefix = set(), {}
    for prefix, steps, horizon in (("first_race", FIRST_RACE, DAY), ("creator", CREATOR, 7 * DAY), ("publication_request", PUBLICATION_REQUEST, 7 * DAY)):
        anchors = [value[1] for value in values if value[0] == steps[0]]
        anchor = min(anchors) if anchors else None
        frontier = ordered_journey(values, steps, horizon)
        # Keep every already proved ordered step, including completed mature
        # journeys, before allocating space to alternate incomplete candidates.
        protected.update(tuple(value) for value in frontier)
        selected_by_prefix[prefix] = set()
        # Once the ordered journey is proved, repeats carry no new funnel fact.
        if len(frontier) == len(steps):
            result.extend(frontier)
            selected_by_prefix[prefix].update(tuple(value) for value in frontier)
            continue
        if steps == FIRST_RACE and len(frontier) == len(steps) - 1:
            result.extend(frontier)
            selected_by_prefix[prefix].update(tuple(value) for value in frontier)
            continue
        for name in steps:
            if name == "second_voluntary_race":
                continue
            candidates = sorted({tuple(value) for value in values if value[0] == name
                and (anchor is None or anchor <= value[1] <= anchor + horizon)}, key=order)
            cap = 1 if name == steps[0] else 18
            selected = candidates[:cap]
            if prefix == "first_race" and name == "race_started" and len(candidates) > cap:
                selected = candidates[:1] + candidates[-(cap - 1):]
            result.extend(list(value) for value in selected)
            selected_by_prefix[prefix].update(selected)
            if len(candidates) > cap:
                truncated.add(prefix)
    retained = protected | {tuple(value) for value in result}
    if len(retained) > MILESTONE_LIMIT:
        # Three overlapping journeys can have different earliest anchors. The
        # union has a hard bound; losing alternatives creates explicit scoped
        # uncertainty, never loss of a proved conversion or a false zero.
        alternatives = sorted(retained-protected, key=order)
        retained = protected | set(alternatives[:max(0, MILESTONE_LIMIT-len(protected))])
        for prefix, selected in selected_by_prefix.items():
            if selected-retained:
                truncated.add(prefix)
    return sorted([list(value) for value in retained], key=order), truncated


def bounded_milestones(values):
    result, truncated = bounded_frontiers(values)
    if all(len(value) == 2 for value in values):
        result = [value[:2] for value in result]
    return result, bool(truncated)


def journey_projection(profile):
    """Ordered first-observed journeys; late arrivals restate only this projection."""
    result = {}
    milestones = [milestone(value) for value in profile.milestones or []]
    for prefix, steps, horizon in (("first_race", FIRST_RACE, DAY), ("creator", CREATOR, 7 * DAY), ("publication_request", PUBLICATION_REQUEST, 7 * DAY)):
        frontier = ordered_journey(milestones, steps, horizon)
        if not frontier:
            continue
        start = frontier[0][1]
        for name, _value in zip(steps, frontier, strict=False):
            result[f"{start // DAY}|{prefix}_{name}|"] = 1
        if (profile.truncations or {}).get(prefix):
            result[f"{start // DAY}|{prefix}_truncated_profiles|"] = 1
    return result


def project_pending(factory, *, limit=500, at=None, raw_days=7, fact_days=180):
    """Complete one bounded diagnostic pass using the same v2 service stages."""
    from .telemetry_processing import diagnostic_pass
    return diagnostic_pass(factory, limit=limit, at=at, raw_days=raw_days, fact_days=fact_days)


def prepared_report(session, since, until, at):
    start, last = since // DAY, (until - 1) // DAY
    state = session.get(ProductState, 1)
    begun = state.collection_started_at if state else None
    watermark = state.processed_through if state else None
    retained_floor = state.retained_from_day if state and state.retained_from_day is not None else 0
    rows = session.scalars(select(ProductMetric).where(ProductMetric.day >= start,
        ProductMetric.day >= retained_floor, ProductMetric.day <= min(last, at // DAY)).limit(12000)).all()
    values = {(row.day, row.key, row.dimension): row.value for row in rows}
    collected_day = None if begun is None else begun // DAY
    def observed(day):
        return (collected_day is not None and watermark is not None
            and max(collected_day, retained_floor) <= day <= min(at // DAY, watermark // DAY))
    def count(day, key, dimension=""):
        return values.get((day, key, dimension), 0) if observed(day) else None
    scope_observed = any(observed(day) for day in range(start, last + 1))
    daily = [{"day": datetime.fromtimestamp(day * DAY, timezone.utc).date().isoformat(),
        "active_players": count(day, "active_players"), "accepted_races": count(day, "accepted_races"),
        "observed_race_finishes": count(day, "event_race_finished"),
        "current_partial": (day + 1) * DAY > at, "observed": observed(day)} for day in range(start, last + 1)]
    weekly_start = last - 6
    def distinct(first, final):
        visible_last = min(at // DAY, watermark // DAY) if watermark is not None else -1
        if begun is None or final < max(collected_day, retained_floor) or first > visible_last:
            return None
        return session.scalar(select(func.count(func.distinct(ProductPlayerDay.player_id)))
            .where(ProductPlayerDay.day >= max(first, retained_floor), ProductPlayerDay.day <= min(final, visible_last)))
    retention = []
    for day in range(start, last + 1):
        cohort = count(day, "retention_cohort_players")
        if cohort in (None, 0):
            continue
        row = {"cohort_day": datetime.fromtimestamp(day * DAY, timezone.utc).date().isoformat(), "cohort_players": cohort}
        for offset in (1, 7):
            mature = (watermark is not None and (day + offset + 1) * DAY <= min(at, watermark)
                and observed(day + offset))
            row[f"d{offset}"] = {"mature": mature,
                "eligible": cohort,
                "returned": count(day, f"retention_d{offset}_returned") if mature else None}
        retention.append(row)
    funnels = {}
    for prefix, steps, horizon in (("first_race", FIRST_RACE, 1), ("creator", CREATOR, 7), ("publication_request", PUBLICATION_REQUEST, 7)):
        mature_days = [day for day in range(start, last + 1) if observed(day)
            and watermark is not None and (day + horizon + 1) * DAY + (600 if prefix == "first_race" else 0) <= min(at, watermark)]
        counts = [{"name": name, "count": sum(values.get((day, prefix + "_" + name, ""), 0)
            for day in mature_days) if scope_observed and mature_days
                and not sum(values.get((day, prefix + "_truncated_profiles", ""), 0) for day in mature_days) else None} for name in steps]
        funnels[prefix] = {"cohort_players": counts[0]["count"], "steps": counts, "mature": bool(mature_days),
            "mature_cohort_days": len(mature_days), "followup_days": horizon,
            "truncated_cohort_players": sum(values.get((day, prefix + "_truncated_profiles", ""), 0) for day in mature_days),
            "second_race_followup_seconds": 600 if prefix == "first_race" else None}
    preferences = {}
    for prefix, plural in (("car", "cars"), ("biome", "biomes")):
        dimensions = sorted({row.dimension for row in rows if row.key in (prefix + "_exposures", prefix + "_selections")})
        preferences[plural] = [{"id": dimension, "exposures": sum(values.get((day, prefix + "_exposures", dimension), 0)
            for day in range(start, last + 1)), "selections": sum(values.get((day, prefix + "_selections", dimension), 0)
            for day in range(start, last + 1))} for dimension in dimensions]
    store_ids = sorted({row.dimension for row in rows if row.key in ("store_exposures", "store_requests")})
    mature_publication_days = [day for day in range(start, last + 1) if observed(day)
        and watermark is not None and (day + 8) * DAY <= min(at, watermark)]
    return {"schema": "bmt-product-analytics-v1", "as_of": at, "since": since, "until": until,
        "resolution": "UTC calendar-day facts; partial-day requests include their entire day buckets",
        "effective_since": start * DAY, "effective_until": (last + 1) * DAY,
        "late_arrival_policy": "Follow-up maturity is provisional for seven additional days; accepted late observations can restate cohorts.",
        "local_draft_metrics": {"available": False,
            "reason": "Draft editing, saves and creator tests stay on devices; only explicit publication requests are observed."},
        "days": last - start + 1, "weekly_since": weekly_start * DAY, "weekly_until": until,
        "coverage": {"collection_started_at": begun, "processed_through": watermark,
            "processing_protocol": 2,
            "coverage_basis": "Committed intake and fold barrier is a completeness lower bound; newer contributions and late arrivals remain provisional",
            "counts_include_provisional_tail": True,
            "latest_receipt_at": state.latest_receipt_at if state else None,
            "pending_events": state.pending_events if state else 0, "pending_events_capped": bool(state and state.pending_capped),
            "processor_observed_at": state.observed_at if state else None,
            "truncated_profiles": state.truncated_profiles if state else 0,
            "retained_from": retained_floor * DAY if state and state.retained_from_day is not None else None,
            "fact_retention_days": state.fact_days if state else 180,
            "scope": "Signed-in players only, including artificial players; qualified foreground observations and authoritative accepted results/publications.",
            "limitations": ["Guest coverage is unavailable; no guest/account linking is performed.",
                "Client finishes are observations; only server race_accepted facts increment accepted races.",
                "Counts are prepared snapshots; processor lag and the current partial day remain visible.",
                "First-race cohorts wait 24 hours plus 10 minutes for a second start; creator cohorts wait seven days. Profiles retain at most 128 ordered milestones; unresolved overflow is scoped to its cohort.",
                f"Raw observations are bounded; retained facts cover {state.fact_days if state else 180} days. Earlier or unavailable coverage is not zero.",
                "Event counts describe observed offers/actions; exposure comparisons do not establish causal preference.",
                "Loss counters are client-reported per-player maxima; shared installations/account changes can overlap these reports."]},
        "daily": daily, "weekly_active_players": distinct(weekly_start, last),
        "period_active_players": distinct(start, last), "funnels": funnels,
        "retention": retention, "preferences": preferences,
        "store": {"opened": sum(values.get((day, "event_store_opened", ""), 0) for day in range(start, last + 1))
            if scope_observed else None,
            "offers": [{"id": sku, "exposures": sum(values.get((day, "store_exposures", sku), 0) for day in range(start, last + 1)),
                "requests": sum(values.get((day, "store_requests", sku), 0) for day in range(start, last + 1))} for sku in store_ids],
            "fulfilled": None},
        "creator_value": {"published_versions": sum(values.get((day, "publication_versions", ""), 0) for day in range(start, last + 1))
            if scope_observed else None,
            "mature_published_versions": sum(values.get((day, "publication_versions", ""), 0) for day in mature_publication_days)
            if scope_observed else None,
            "external_racer_7d_versions": sum(values.get((day, "publication_external_7d", ""), 0) for day in mature_publication_days)
            if scope_observed else None, "cohort_followup_days": 7},
        "quality": {key: sum(values.get((day, "reported_" + key, ""), 0) for day in range(start, last + 1))
            if scope_observed else None for key in ("dropped_events", "rejected_events", "persistence_failures")},
        "challenges": {key: sum(values.get((day, "event_" + key, ""), 0) for day in range(start, last + 1))
            if scope_observed else None for key in ("challenge_opened", "challenge_joined", "challenge_created", "share_clicked")}}


@router.get("/v1/admin/product-analytics")
def analytics(request: Request, role: Access, window: Window, days: int = Query(7, ge=1, le=90)):
    since, until = window or calendar_range(days)
    with request.app.state.session_factory() as session:
        if session.bind.dialect.name == "postgresql":
            session.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY"))
        elif session.bind.dialect.name == "sqlite":
            session.execute(text("BEGIN"))
        result = prepared_report(session, since, until, now())
        result.update(role=role, environment=request.app.state.settings.environment,
            telemetry_enabled=request.app.state.settings.telemetry_enabled)
        result["funnels"]["creator"]["historical_only"] = True
        result["funnels"]["creator"]["coverage_note"] = "Local draft edits/saves/tests are no longer collected. Use the explicit publication-request journey; historical creator facts retain their original definition."
        return result
