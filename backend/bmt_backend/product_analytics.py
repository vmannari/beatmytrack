"""Independent bounded projection and prepared product reads; never scans raw races."""

from collections import Counter
from datetime import datetime, timezone

from fastapi import APIRouter, Query, Request
from sqlalchemy import delete, false, func, select, text, tuple_, update

from . import network_health, race_statistics
from . import quality as client_quality
from .admin import Access, Window
from .admin_ranges import calendar_range
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .quality_models import QualityFact
from .telemetry import insert_for
from .telemetry_models import (
    ProductEvent,
    ProductMetric,
    ProductPlayerDay,
    ProductProfile,
    ProductPublication,
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
    """One separate-worker transaction, capped events and prepared-fact cleanup."""
    if not 1 <= limit <= 1000 or not 1 <= raw_days <= 30 or not 14 <= fact_days <= 366:
        raise ValueError("INVALID_PRODUCT_PROCESSOR_BUDGET")
    at = now() if at is None else at
    with factory() as session:
        if session.bind.dialect.name == "sqlite":
            session.execute(text("BEGIN IMMEDIATE"))
        state = session.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
        if state is None:
            raise RuntimeError("PRODUCT_MIGRATION_REQUIRED")
        events = session.scalars(select(ProductEvent).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(limit)).all()
        players = {event.player_id for event in events}
        references = players | {event.properties.get("owner_id") for event in events if event.properties.get("owner_id")}
        removed = set(session.scalars(select(Player.id).where(Player.id.in_(references), Player.deleted_at.is_not(None)))) if references else set()
        for event in events:
            if event.player_id in removed:
                if event.source == "client": state.pending_clients = max(0, state.pending_clients - 1)
                session.delete(event)
        events = [event for event in events if event.player_id not in removed]
        players -= removed
        client_quality.project(session, events, insert_for)
        race_statistics.project(session, events)
        network_health.project(session, events)
        profiles = {profile.player_id: profile for profile in session.scalars(
            select(ProductProfile).where(ProductProfile.player_id.in_(players)))} if players else {}
        missing_flags = {event.player_id for event in events if event.is_test_driver is None}
        flags = dict(session.execute(select(Player.id, Player.is_test_driver).where(Player.id.in_(missing_flags))).all()) if missing_flags else {}
        version_ids = {event.properties.get("track_version_id", event.properties.get("track_version"))
            for event in events if event.source == "server" and event.name in ("race_accepted", "track_published")}
        version_ids.discard(None)
        publications = {row.version_id: row for row in session.scalars(select(ProductPublication)
            .where(ProductPublication.version_id.in_(version_ids)))} if version_ids else {}
        new_activity = {(event.occurred_at // DAY, event.player_id) for event in events if event.name in ACTIVE}
        deltas = Counter()
        if new_activity:
            inserted = session.execute(insert_for(session, ProductPlayerDay).values([
                {"day": day, "player_id": player} for day, player in sorted(new_activity)])
                .on_conflict_do_nothing(index_elements=["day", "player_id"])
                .returning(ProductPlayerDay.day, ProductPlayerDay.player_id)).all()
            for day, _player in inserted:
                deltas[(day, "active_players", "")] += 1
        for event in events:
            if event.player_id not in profiles:
                profile = ProductProfile(player_id=event.player_id, milestones=[], projection={}, truncated=False, quality={}, truncations={})
                session.add(profile)
                profiles[event.player_id] = profile
            profile = profiles[event.player_id]
            if event.is_test_driver is None:
                event.is_test_driver = bool(flags.get(event.player_id, False))
            if event.name in ACTIVE:
                profile.first_activity_at = min(profile.first_activity_at or event.occurred_at, event.occurred_at)
            if event.name in MILESTONES:
                value = [event.name, event.occurred_at, event.session_id or "", event.monotonic_ms or 0, event.seq or 0]
                values = profile.milestones or []
                if value not in values:
                    profile.milestones, truncated = bounded_frontiers([*values, value])
                    truncations = dict(profile.truncations or {})
                    for prefix, steps, horizon in (("first_race", FIRST_RACE, DAY), ("creator", CREATOR, 7 * DAY), ("publication_request", PUBLICATION_REQUEST, 7 * DAY)):
                        if prefix in truncated:
                            truncations[prefix] = True
                        elif len(ordered_journey(profile.milestones, steps, horizon)) == len(steps):
                            truncations[prefix] = False
                    was_truncated = bool(profile.truncated)
                    profile.truncations = truncations
                    profile.truncated = any(truncations.values())
                    state.truncated_profiles += int(profile.truncated) - int(was_truncated)
            day, props = event.occurred_at // DAY, event.properties or {}
            if event.source == "server" and event.name in ("track_published", "race_accepted"):
                version = props.get("track_version_id", props.get("track_version"))
                owner = props.get("owner_id") or (event.player_id if event.name == "track_published" else None)
                if owner in removed:
                    owner = None
                published_at = props.get("published_at", event.occurred_at if event.name == "track_published" else None)
                if version and owner and published_at is not None and published_at >= (at // DAY - fact_days) * DAY:
                    publication = publications.get(version)
                    if publication is None:
                        publication = ProductPublication(version_id=version, owner_id=owner,
                            published_at=published_at, observed=False)
                        session.add(publication)
                        publications[version] = publication
                    before = bool(publication.first_external_at is not None
                        and publication.published_at <= publication.first_external_at <= publication.published_at + 7 * DAY)
                    was_observed = publication.observed
                    if event.name == "track_published":
                        publication.observed = True
                    elif event.player_id != publication.owner_id and event.occurred_at >= publication.published_at:
                        publication.first_external_at = min(publication.first_external_at or event.occurred_at, event.occurred_at)
                    after = bool(publication.first_external_at is not None
                        and publication.published_at <= publication.first_external_at <= publication.published_at + 7 * DAY)
                    publication_day = publication.published_at // DAY
                    if publication.observed and not was_observed:
                        deltas[(publication_day, "publication_versions", "")] += 1
                        deltas[(publication_day, "publication_external_7d", "")] += int(after)
                    elif publication.observed:
                        deltas[(publication_day, "publication_external_7d", "")] += int(after) - int(before)
            if event.name == "collection_summary":
                quality = dict(profile.quality or {})
                for key, value in props.items():
                    delta = max(0, value - quality.get(key, 0))
                    deltas[(day, "reported_" + key, "")] += delta
                    quality[key] = max(value, quality.get(key, 0))
                profile.quality = quality
            prefix = "server_event_" if event.source == "server" and event.name.startswith("challenge_") else "event_"
            deltas[(day, prefix + event.name, "")] += 1
            if event.source == "server" and event.name == "race_accepted":
                deltas[(day, "accepted_races", "")] += 1
            if event.source == "client" and event.name in ("car_exposed", "car_selected") and props.get("car_id"):
                deltas[(day, "car_exposures" if event.name == "car_exposed" else "car_selections", props["car_id"])] += 1
            if event.source == "client" and event.name in ("track_exposed", "track_selected") and props.get("biome"):
                deltas[(day, "biome_exposures" if event.name == "track_exposed" else "biome_selections", props["biome"])] += 1
            if event.source == "client" and event.name in ("offer_exposed", "purchase_requested") and props.get("product_id"):
                deltas[(day, "store_exposures" if event.name == "offer_exposed" else "store_requests", props["product_id"])] += 1
            event.processed_at = at
        needed = {(profile.first_activity_at // DAY + offset, profile.player_id)
            for profile in profiles.values() if profile.first_activity_at is not None
            and profile.first_activity_at // DAY >= at // DAY - fact_days for offset in (1, 7)}
        returns = set(session.execute(select(ProductPlayerDay.day, ProductPlayerDay.player_id)
            .where(tuple_(ProductPlayerDay.day, ProductPlayerDay.player_id).in_(needed)))) if needed else set()
        for profile in profiles.values():
            projection = journey_projection(profile)
            previous = profile.projection or {}
            if profile.first_activity_at is not None:
                cohort = profile.first_activity_at // DAY
                if cohort < at // DAY - fact_days:
                    projection.update({key: value for key, value in previous.items() if "|retention_" in key})
                else:
                    projection[f"{cohort}|retention_cohort_players|"] = 1
                    for offset in (1, 7):
                        if (cohort + offset, profile.player_id) in returns:
                            projection[f"{cohort}|retention_d{offset}_returned|"] = 1
            for key in set(previous) | set(projection):
                day, metric, dimension = key.split("|", 2)
                if int(day) >= at // DAY - fact_days:
                    deltas[(int(day), metric, dimension)] += projection.get(key, 0) - previous.get(key, 0)
            profile.projection = projection
        values = [{"day": day, "key": key, "dimension": dimension, "value": value}
            for (day, key, dimension), value in deltas.items() if value]
        if values:
            statement = insert_for(session, ProductMetric).values(values)
            session.execute(statement.on_conflict_do_update(index_elements=["day", "key", "dimension"],
                set_={"value": ProductMetric.value + statement.excluded.value}))
        session.flush()
        state.pending_clients = max(0, state.pending_clients - sum(event.source == "client" for event in events))
        pending_probe = (select(ProductEvent.id).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(PENDING_PROBE_LIMIT))
        state.pending_events = session.scalar(select(func.count()).select_from(pending_probe.subquery()))
        state.pending_capped = state.pending_events == PENDING_PROBE_LIMIT
        oldest = session.scalar(select(ProductEvent.received_at).where(ProductEvent.processed_at.is_(None))
            .order_by(ProductEvent.received_at, ProductEvent.id).limit(1))
        state.processed_through = min(at, oldest - 1) if oldest is not None else at
        state.observed_at = at
        state.retained_from_day = at // DAY - fact_days
        state.fact_days = fact_days
        state.processed_events += len(events)
        if events:
            observed_events = [event for event in events if event.name != "collection_rejected"]
            if observed_events:
                earliest = min(event.occurred_at for event in observed_events)
                state.collection_started_at = min(state.collection_started_at or earliest, earliest)
            latest = max(event.received_at for event in events)
            state.latest_receipt_at = max(state.latest_receipt_at or latest, latest)
        # Recent client receipt IDs outlive the maximum accepted client-event age;
        # old retransmission is then rejected by ingestion's occurrence bound.
        expired = session.scalars(select(ProductEvent.id).where(ProductEvent.source == "client",
            ProductEvent.processed_at.is_not(None), ProductEvent.received_at < at - (raw_days + 1) * DAY,
            ProductEvent.occurred_at < at - 7 * DAY).limit(limit)).all()
        if expired:
            session.execute(delete(ProductEvent).where(ProductEvent.id.in_(expired)))
        # Authoritative receipts retain a small permanent dedupe tombstone so
        # replaying a server outbox record cannot double a prepared metric.
        old_server = session.scalars(select(ProductEvent.id).where(ProductEvent.source == "server",
            ProductEvent.processed_at.is_not(None), ProductEvent.received_at < at - raw_days * DAY,
            ProductEvent.compacted == false()).limit(limit)).all()
        if old_server:
            session.execute(update(ProductEvent).where(ProductEvent.id.in_(old_server)).values(properties={}, compacted=True))
        for model, columns in ((ProductPlayerDay, (ProductPlayerDay.day, ProductPlayerDay.player_id)),
                (QualityFact, (QualityFact.day, QualityFact.kind, QualityFact.dimension)),
                (ProductMetric, (ProductMetric.day, ProductMetric.key, ProductMetric.dimension))):
            expired_keys = session.execute(select(*columns).where(model.day < at // DAY - fact_days)
                .order_by(*columns).limit(limit)).all()
            if expired_keys:
                session.execute(delete(model).where(tuple_(*columns).in_(expired_keys)))
        race_statistics.cleanup(session, at, limit, fact_days)
        network_health.cleanup(session, at, limit, fact_days)
        expired_publications = session.scalars(select(ProductPublication.version_id)
            .where(ProductPublication.published_at < (at // DAY - fact_days) * DAY).limit(limit)).all()
        if expired_publications:
            session.execute(delete(ProductPublication).where(ProductPublication.version_id.in_(expired_publications)))
        session.commit()
        return {"processed": len(events), "pending": state.pending_events, "processed_through": state.processed_through,
            "observed_at": at, "retired_client_events": len(expired), "compacted_server_receipts": len(old_server)}


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
                and observed(day + offset) and not state.pending_events)
            row[f"d{offset}"] = {"mature": mature, "eligible": cohort,
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
        and watermark is not None and (day + 8) * DAY <= min(at, watermark) and not state.pending_events]
    return {"schema": "bmt-product-analytics-v1", "as_of": at, "since": since, "until": until,
        "local_draft_metrics": {"available": False,
            "reason": "Draft editing, saves and creator tests stay on devices; only explicit publication requests are observed."},
        "days": last - start + 1, "weekly_since": weekly_start * DAY, "weekly_until": until,
        "coverage": {"collection_started_at": begun, "processed_through": watermark,
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
