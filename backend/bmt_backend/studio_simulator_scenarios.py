"""Normal Studio workflow scenarios for the development history simulator."""

from decimal import Decimal

from sqlalchemy import select

from .commerce import CATALOG, fulfill_verified, lock_entitlements
from .commerce_models import Purchase
from .economy import PRICES
from .economy_models import CoinWallet, CosmeticUnlock
from .studio_case_models import StudioCase, StudioCaseEvent
from .studio_experiments import assignment
from .studio_incidents import Observation, record
from .studio_platform_models import (
    StudioAssignment,
    StudioCaseTriage,
    StudioCoinEntry,
    StudioDelivery,
    StudioExperiment,
    StudioFinanceEvent,
    StudioIncident,
    StudioIncidentEvent,
    StudioRelease,
    StudioStaff,
)
from .track_models import OperationState, digest


def purchase_event(db, plan, event):
    """Exercise the existing development purchase fulfilment, no provider IO."""
    from .studio_simulator import identity, rng_for

    rng = rng_for(plan, "order", event["id"])
    state = rng.choices(("approved", "pending", "declined"), (82, 10, 8))[0]
    product = event["properties"]["product_id"]
    order = Purchase(
        id="simulation:" + digest(event["id"]),
        player_id=event["player_id"],
        provider="simulation",
        product_id=product,
        state=state,
        created_at=event["occurred_at"],
    )
    db.add(order)
    db.flush()
    if state == "approved":
        fulfill_verified(
            db, lock_entitlements(db, order.player_id), order, verified_at=event["occurred_at"] + 1
        )
        db.add(
            StudioFinanceEvent(
                id=identity(plan.dataset, "payment", event["id"]),
                provider="simulation",
                reference=digest(event["id"]),
                player_id=order.player_id,
                purchase_id=order.id,
                kind="purchase",
                basis="estimated",
                currency="EUR",
                amount_micros=int(Decimal(CATALOG[product]["price_eur"]) * 1000000),
                occurred_at=order.created_at,
                received_at=event["received_at"],
                dimensions={"product_id": product, "scenario_run": plan.dataset},
                payload_hash=digest(event),
            )
        )


def seed_workspaces(sim):
    from .studio_simulator import BUILDS, DAY, identity, rng_for

    p = sim.plan
    at = p.anchor
    source = "scenario-" + p.dataset
    with sim.factory() as db:
        journal = db.get(OperationState, sim.key)
        if journal.details.get("workspaces_done"):
            return
        for staff, name, role in [
            ("quality-lead", "Quality lead", "analyst"),
            ("live-ops", "Live operations", "owner"),
        ]:
            if db.get(StudioStaff, staff) is None:
                db.add(StudioStaff(id=staff, display_name=name, role=role))
        for build, name, stage, days in [
            (BUILDS[0], "Autumn baseline", "production", 59),
            (BUILDS[1], "Garage refresh rollout", "rolled_back", 8),
            (BUILDS[2], "Frame pacing recovery", "canary", 2),
        ]:
            if db.scalar(select(StudioRelease).where(StudioRelease.build_id == build)) is None:
                db.add(
                    StudioRelease(
                        id=identity(p.dataset, "release", build),
                        build_id=build,
                        name=name,
                        state=stage,
                        actor="live-ops",
                        notes="Development scenario history. Build label describes the observed presentation release; race contracts stay pinned.",
                        created_at=at - days * DAY,
                    )
                )
        db.commit()

    # The same incident detector creates opening/recovery events, with delivery disabled.
    definitions = [
        (
            "frame_pacing",
            "Slow frames on Galaxy A13",
            "warning",
            "0.59.1 has a higher slow-frame share on Galaxy A13 than the baseline.",
            "Compare 0.59.1 with 0.59.0, then inspect device and track reports.",
            "quality",
        ),
        (
            "score_delivery",
            "Score upload delays",
            "critical",
            "A temporary connectivity spike delayed score uploads.",
            "Inspect score-upload network failures and confirm recovery before clearing.",
            "system/network",
        ),
        (
            "store_delivery",
            "Purchase delivery needs investigation",
            "warning",
            "Some purchase requests remain pending after a network retry.",
            "Open the player case and inspect its purchase receipts before retrying.",
            "economy",
        ),
        (
            "discovery_timeout",
            "Discovery request timeouts",
            "warning",
            "Track discovery experienced a transient timeout spike.",
            "Confirm the discovery latency distribution and recovered request success.",
            "system/network",
        ),
    ]
    for step, seconds in enumerate((3600, 1200, 60)):
        signals = [
            {
                "key": k,
                "active": (index in (0, 2) or step == 0),
                "severity": severity,
                "title": title,
                "evidence": evidence,
                "next_step": action,
                "target": target,
            }
            for index, (k, title, severity, evidence, action, target) in enumerate(definitions)
        ]
        with sim.factory() as db:
            record(
                db,
                sim.settings,
                source,
                Observation(
                    id=identity(p.dataset, "observation", step), observed_at=at - seconds, signals=signals
                ),
                notify=False,
            )
    with sim.factory() as db:
        incidents = {
            r.signal: r for r in db.scalars(select(StudioIncident).where(StudioIncident.source == source))
        }
        for signal, state, assignee, reason in [
            (
                "store_delivery",
                "acknowledged",
                "live-ops",
                "Purchase receipt investigation is assigned to live operations.",
            ),
            (
                "discovery_timeout",
                "closed",
                "quality-lead",
                "Recovered request success and latency were reviewed.",
            ),
        ]:
            row = incidents[signal]
            row.state, row.assignee, row.revision = state, assignee, row.revision + 1
            if state == "closed":
                row.closed_at = at - 30
            db.add(
                StudioIncidentEvent(
                    id=identity(p.dataset, "response", signal),
                    incident_id=row.id,
                    actor=assignee,
                    kind="clear" if state == "closed" else "acknowledge",
                    revision=row.revision,
                    detail={"reason": reason},
                    request_hash=digest(reason),
                    created_at=at - 30,
                )
            )
        incident = incidents["store_delivery"]
        dead_id = digest({"dataset": p.dataset, "delivery": "dead"})
        if db.get(StudioDelivery, dead_id) is None:
            db.add(
                StudioDelivery(
                    id=dead_id,
                    incident_id=incident.id,
                    event_id=identity(p.dataset, "outbox-event"),
                    state="dead",
                    attempts=12,
                    payload={"scenario_run": p.dataset, "kind": "opened"},
                    last_error="HTTP_503",
                    created_at=at - 3000,
                )
            )
        db.flush()
        titles = [
            (
                "Score upload did not complete",
                "urgent",
                "frame_pacing",
                "Investigate the upload request IDs and the final accepted-result receipt.",
            ),
            (
                "Purchase pending after reconnect",
                "high",
                "store_delivery",
                "Compare the order state and the player entitlement delivery record.",
            ),
            (
                "Low frame rate after update",
                "high",
                "frame_pacing",
                "Compare device reports for Galaxy A13 between baseline and rollout.",
            ),
            (
                "Race ended during app backgrounding",
                "normal",
                None,
                "Review the reported exit reason and whether a terminal race package arrived.",
            ),
            (
                "Publishing slot not visible",
                "normal",
                None,
                "Inspect permanent publishing capacity and any pending purchase.",
            ),
            (
                "Controller setup question",
                "normal",
                None,
                "Player received the input settings instructions and confirmed the selected control mode.",
            ),
        ]
        for index in range(min(24, p.players)):
            title, priority, signal, note = titles[index % len(titles)]
            case_id = identity(p.dataset, "case", index)
            if db.get(StudioCase, case_id):
                continue
            created = at - (index % 6) * DAY - 3600
            case = StudioCase(
                id=case_id,
                player_id=p.person(index)["id"],
                title=title,
                status=("open", "investigating", "resolved")[index % 3],
                revision=1,
                created_at=created,
                updated_at=at - index * 300,
            )
            db.add(case)
            db.flush()
            db.add(
                StudioCaseEvent(
                    id=identity(p.dataset, "case-event", index),
                    case_id=case_id,
                    actor="live-ops",
                    kind="note",
                    revision=1,
                    detail={"text": note},
                    request_hash=digest(note),
                    created_at=at - index * 300,
                )
            )
            db.add(
                StudioCaseTriage(
                    case_id=case_id,
                    priority=priority,
                    assignee="quality-lead" if index % 2 else "live-ops",
                    due_at=at + DAY if index % 4 else at - 3600,
                    incident_id=incidents[signal].id if signal else None,
                )
            )
        db.commit()

    # Spend from actual canonical reward balances, never grant a magic starting balance.
    for index in range(p.players):
        person = p.person(index)
        if index % 3:
            continue
        with sim.factory() as db:
            wallet = db.scalar(
                select(CoinWallet).where(CoinWallet.player_id == person["id"]).with_for_update()
            )
            item = sorted(key for key in PRICES if key.startswith("livery/"))[index % 48]
            price = PRICES[item]
            if wallet is None or wallet.balance < price or db.get(CosmeticUnlock, (person["id"], item)):
                continue
            wallet.balance -= price
            wallet.revision += 1
            db.add(CosmeticUnlock(player_id=person["id"], item_id=item, price=price, created_at=at - 1800))
            reference = "purchase/" + identity(p.dataset, "cosmetic", index)
            db.add(
                StudioCoinEntry(
                    id=digest({"player": person["id"], "reference": reference}),
                    player_id=person["id"],
                    reference=reference,
                    kind="spent",
                    amount=-price,
                    created_at=at - 1800,
                    detail={"item_id": item, "price": price},
                )
            )
            db.commit()

    with sim.factory() as db:
        # Estimated scenario revenue is an explicit source, with ordinary account attribution.
        from sqlalchemy import func

        from .studio_platform_models import AnalysisDay

        daily = dict(
            db.execute(
                select(AnalysisDay.day, func.sum(AnalysisDay.counters["race_finished"].as_integer()))
                .where(AnalysisDay.player_id.in_([p.person(i)["id"] for i in range(p.players)]))
                .group_by(AnalysisDay.day)
            ).all()
        )
        for day in range(p.first_day, at // DAY + 1):
            rng = rng_for(p, "ad-report", day)
            reference = digest({"dataset": p.dataset, "ad-day": day})
            if db.scalar(
                select(StudioFinanceEvent.id).where(
                    StudioFinanceEvent.provider == "simulation", StudioFinanceEvent.reference == reference
                )
            ):
                continue
            impressions = int((daily.get(day) or 0) * 2)
            db.add(
                StudioFinanceEvent(
                    id=identity(p.dataset, "ad-report", day),
                    provider="simulation",
                    reference=reference,
                    kind="ad_earnings",
                    basis="estimated",
                    currency="EUR",
                    amount_micros=int(impressions * rng.uniform(3200, 5200)),
                    occurred_at=day * DAY,
                    received_at=min(at, day * DAY + DAY - 1),
                    dimensions={"report_date": day, "impressions": impressions, "scenario_run": p.dataset},
                    payload_hash=reference,
                )
            )
        experiment_id = identity(p.dataset, "experiment")
        experiment = db.get(StudioExperiment, experiment_id)
        if experiment is None:
            experiment = StudioExperiment(
                id=experiment_id,
                name="First-race guidance A/A",
                state="paused",
                primary_metric="return_on_target_day",
                followup_days=7,
                minimum_per_variant=50,
                allocation={"control": 5000, "guided": 5000},
                variants={
                    "control": {"onboarding_message": "Choose a track and complete your first race."},
                    "guided": {"onboarding_message": "Choose a track and complete your first race."},
                },
                salt=digest({"dataset": p.dataset, "experiment": "aa"}),
                actor="live-ops",
                created_at=p.first_day * DAY,
                started_at=p.first_day * DAY,
                stopped_at=at - DAY,
            )
            db.add(experiment)
            db.flush()
            for index in range(p.players):
                person = p.person(index)
                if person["signup"] * DAY > at - DAY:
                    continue
                db.add(
                    StudioAssignment(
                        experiment_id=experiment.id,
                        player_id=person["id"],
                        variant=assignment(experiment, person["id"]),
                        revision=0,
                        assigned_at=person["signup"] * DAY + 120,
                        exposed_at=person["signup"] * DAY + 125,
                        exposure_id=identity(p.dataset, "exposure", index),
                    )
                )
        row = db.get(OperationState, sim.key)
        row.details = {**row.details, "workspaces_done": True, "monitor_source": source}
        db.commit()
