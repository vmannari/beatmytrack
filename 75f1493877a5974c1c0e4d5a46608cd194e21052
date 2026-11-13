"""Preserved telemetry calculations under independent player/entity ownership."""
from collections import Counter

from sqlalchemy import select, tuple_

from .identity_models import Player
from .product_analytics import (
    ACTIVE,
    CREATOR,
    DAY,
    FIRST_RACE,
    MILESTONES,
    PUBLICATION_REQUEST,
    bounded_frontiers,
    journey_projection,
    ordered_journey,
)
from .telemetry_models import ProductLossSource, ProductPlayerDay, ProductProfile, ProductPublication
from .telemetry_queue import defer, finish, insert_for, write_metrics


def project_actor(session, events, owner, at, fact_days):
    players = {event.player_id for event in events}
    references = players | {event.properties.get("owner_id") for event in events if event.properties.get("owner_id")}
    removed = set(session.scalars(select(Player.id).where(Player.id.in_(references), Player.deleted_at.is_not(None)))) if references else set()
    erased = [event for event in events if event.player_id in removed]
    finish(session, erased, at, processed=False)
    events = [event for event in events if event.player_id not in removed]
    players -= removed
    profiles = {profile.player_id: profile for profile in session.scalars(
        select(ProductProfile).where(ProductProfile.player_id.in_(players)))} if players else {}
    missing_flags = {event.player_id for event in events if event.is_test_driver is None}
    flags = dict(session.execute(select(Player.id, Player.is_test_driver).where(Player.id.in_(missing_flags))).all()) if missing_flags else {}
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
                owner.truncated += int(profile.truncated) - int(was_truncated)
        day, props = event.occurred_at // DAY, event.properties or {}
        if event.name == "collection_summary":
            quality = dict(profile.quality or {})
            source_id = props.get("counter_id") or event.install_id or ""
            source = session.get(ProductLossSource, (event.player_id, source_id))
            if source is None:
                # Old projections kept a single maximum with no source identity.
                # Claim that legacy baseline once; do not re-add historic totals.
                baseline = {}
                if "counter_id" not in props and not quality.get("sources_initialized"):
                    baseline = {key: quality[key] for key in
                        ("dropped_events", "rejected_events", "persistence_failures") if key in quality}
                    quality["sources_initialized"] = True
                source = ProductLossSource(player_id=event.player_id, source_id=source_id, counters=baseline)
                session.add(source)
            counters = dict(source.counters or {})
            for key, value in props.items():
                if key == "counter_id":
                    continue
                delta = max(0, value - counters.get(key, 0))
                deltas[(day, "reported_" + key, "")] += delta
                counters[key] = max(value, counters.get(key, 0))
            source.counters = counters
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
        event.actor_at = at
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
    write_metrics(session, owner.id, owner.revision, deltas)
    from . import studio_analysis
    studio_analysis.project(session, events, profiles, ACTIVE, state=owner)
    from .game_config_observations import project as project_configuration
    project_configuration(session, events)
    observed = [event for event in events if event.name != "collection_rejected"]
    if observed:
        earliest = min(event.occurred_at for event in observed)
        owner.first_activity = min(owner.first_activity if owner.first_activity is not None else earliest, earliest)
    immediate = defer(session, events, removed)
    finish(session, immediate, at)


def project_publications(session, events, owner, at, fact_days):
    references = {e.player_id for e in events} | {e.properties.get("owner_id") for e in events}
    removed = set(session.scalars(select(Player.id).where(Player.id.in_(references), Player.deleted_at.is_not(None))))
    ids = {e.properties.get("track_version_id", e.properties.get("track_version")) for e in events}
    publications = {r.version_id: r for r in session.scalars(select(ProductPublication).where(ProductPublication.version_id.in_(ids)))}
    deltas = Counter()
    for event in events:
        props = event.properties or {}
        version = props.get("track_version_id", props.get("track_version"))
        creator = props.get("owner_id") or (event.player_id if event.name == "track_published" else None)
        if creator in removed:
            creator = None
        published_at = props.get("published_at", event.occurred_at if event.name == "track_published" else None)
        if version and creator and published_at is not None and published_at >= (at // DAY - fact_days) * DAY:
            publication = publications.get(version)
            if publication is None:
                publication = ProductPublication(version_id=version, owner_id=creator,
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
    write_metrics(session, 256 + owner.id, owner.revision, deltas)
