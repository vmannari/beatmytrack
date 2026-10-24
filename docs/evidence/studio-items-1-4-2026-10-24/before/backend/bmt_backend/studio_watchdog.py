"""Independent durable watchdog. Run on a separate host from the monitored API.

Configuration is environment-only; no administrator credential enters its journal.
STUDIO_WATCHDOG_URL, STUDIO_WATCHDOG_DB (sqlite:///absolute/path),
STUDIO_WATCHDOG_SOURCE, STUDIO_WATCHDOG_TOKEN and optional
STUDIO_WATCHDOG_ADMIN_TOKEN. Notification destination uses normal Studio settings.
"""

import argparse
import os
import time
from urllib.parse import urlsplit
from uuid import uuid4

import requests
from sqlalchemy import delete, select

from .config import Settings
from .db import make_engine, make_session_factory
from .migrate import upgrade
from .studio_incidents import Observation, Signal, deliver_one, record
from .studio_platform_models import StudioObservation, StudioSignal
from .track_models import now


def probe(base, *, transport=requests.get):
    try:
        response = transport(base + "/ready", timeout=8, allow_redirects=False)
        ready = response.status_code == 200
        response.close()
        evidence = (
            "API dependency readiness passed"
            if ready
            else "Dependency readiness returned HTTP " + str(response.status_code)
        )
    except requests.RequestException:
        ready, evidence = False, "API readiness request timed out or failed to connect"
    return Signal(
        key="api_readiness",
        active=not ready,
        severity="critical",
        title="Game API is unavailable",
        evidence=evidence,
        next_step="Inspect the API revision, database connectivity and storage dependency; verify recovery with readiness.",
        target="system",
    )


def cycle(factory, settings, base, source, token, admin_token="", *, get=requests.get, post=requests.post):
    # Operator notification pauses survive API outages in this independent store.
    try:
        response = get(
            base + "/v1/monitor/" + source + "/control",
            headers={"Authorization": "Bearer " + token},
            timeout=5,
            allow_redirects=False,
        )
        controls = response.json() if response.status_code == 200 else None
        response.close()
        if controls:
            with factory() as db:
                for item in controls["items"]:
                    row = db.get(StudioSignal, (source, item["key"]))
                    if row:
                        row.suppressed_until, row.suppression_reason = (
                            item["suppressed_until"],
                            item["reason"],
                        )
                db.commit()
    except (requests.RequestException, ValueError, KeyError):
        pass
    signals = [probe(base, transport=get)]
    if admin_token and signals[0].active is False:
        try:
            response = get(
                base + "/v1/admin/competition-health",
                headers={"Authorization": "Bearer " + admin_token},
                timeout=8,
                allow_redirects=False,
            )
            value = response.json() if response.status_code == 200 else {}
            response.close()
            known = value.get("status") is not None
            signals.append(
                Signal(
                    key="health_collection",
                    active=not known,
                    severity="warning",
                    title="Worker health evidence unavailable",
                    evidence="Administrative health probe " + ("passed" if known else "failed"),
                    next_step="Check watchdog credential and API health access.",
                    target="system",
                )
            )
            for key, active, title, evidence in (
                (
                    "workers_unavailable",
                    value.get("status") != "ready",
                    "Compatible verifier unavailable",
                    str(value.get("available_workers", "Unknown")) + " compatible workers",
                ),
                (
                    "queue_delay",
                    value.get("oldest_age_seconds", 0) >= 120,
                    "Players are waiting for results",
                    str(value.get("oldest_age_seconds", "Unknown")) + " seconds oldest queue age",
                ),
                (
                    "recent_failures",
                    value.get("failed_last_5_minutes", 0) >= 3
                    and (value.get("infrastructure_failure_rate_last_5_minutes") or 0) >= 0.05,
                    "Recent infrastructure failures",
                    str(value.get("failed_last_5_minutes", "Unknown")) + " failed races in five minutes",
                ),
            ):
                signals.append(
                    Signal(
                        key=key,
                        active=active if known else None,
                        severity="warning",
                        title=title,
                        evidence=evidence,
                        next_step="Inspect the pending queue, compatible worker revisions and failed result evidence.",
                        target="system/jobs",
                    )
                )
        except (requests.RequestException, ValueError):
            signals.append(
                Signal(
                    key="health_collection",
                    active=True,
                    severity="warning",
                    title="Worker health evidence unavailable",
                    evidence="Administrative health probe failed",
                    next_step="Check watchdog credential and API health access.",
                    target="system",
                )
            )
    if admin_token and signals[0].active is False:
        try:
            response = get(
                base + "/v1/admin/jobs?limit=1",
                headers={"Authorization": "Bearer " + admin_token},
                timeout=8,
                allow_redirects=False,
            )
            queues = response.json() if response.status_code == 200 else None
            response.close()
            if queues is None:
                raise ValueError("QUEUE_COLLECTION_UNAVAILABLE")
            signals.extend(queue_signals(queues, at=now()))
            signals.append(
                Signal(
                    key="queue_collection",
                    active=False,
                    severity="warning",
                    title="Worker queue evidence unavailable",
                    evidence="All-worker queue collection passed",
                    next_step="Inspect dedicated monitor read access.",
                    target="system/jobs",
                )
            )
        except (requests.RequestException, ValueError, KeyError, TypeError):
            signals.append(
                Signal(
                    key="queue_collection",
                    active=True,
                    severity="warning",
                    title="Worker queue evidence unavailable",
                    evidence="All-worker queue collection failed",
                    next_step="Inspect dedicated monitor read access.",
                    target="system/jobs",
                )
            )
    body = Observation(
        id=str(uuid4()),
        observed_at=now(),
        signals=signals,
        notifies_externally=bool(settings.studio_monitor_webhook_url),
    )
    with factory() as db:
        record(db, settings, source, body)
    # The separate host can notify while the game API or its database is offline.
    deliver_one(factory, settings, transport=post)
    synced = 0
    with factory() as db:
        pending = db.scalars(
            select(StudioObservation)
            .where(StudioObservation.source == source, StudioObservation.received_at > 0)
            .order_by(StudioObservation.observed_at, StudioObservation.id)
            .limit(20)
        ).all()
        payloads = [(row.id, row.values) for row in pending]
    for identity, data in payloads:
        try:
            response = post(
                base + "/v1/monitor/" + source + "/observations",
                json=data,
                headers={"Authorization": "Bearer " + token},
                timeout=8,
                allow_redirects=False,
            )
            success = response.status_code == 200
            response.close()
        except requests.RequestException:
            break
        if not success:
            break
        with factory() as db:
            row = db.get(StudioObservation, identity)
            row.received_at = 0  # Durable synchronization acknowledgement, no change to observed time.
            db.commit()
        synced += 1
    with factory() as db:
        expired = db.scalars(
            select(StudioObservation.id)
            .where(StudioObservation.received_at == 0, StudioObservation.observed_at < now() - 30 * 86400)
            .order_by(StudioObservation.observed_at)
            .limit(100)
        ).all()
        if expired:
            db.execute(delete(StudioObservation).where(StudioObservation.id.in_(expired)))
        db.commit()
    return {"readiness_failed": signals[0].active, "synced": synced}


def queue_signals(value, *, at):
    limits = {
        "race": 120,
        "publication": 120,
        "validation": 120,
        "erasure": 900,
        "histogram": 180,
        "news": None,
        "notification": 300,
    }
    summaries = {row["kind"]: row for row in value["summary"]}
    if set(summaries) != set(limits):
        raise ValueError("INCOMPLETE_QUEUE_COVERAGE")
    result = []
    for kind, threshold in limits.items():
        row = summaries[kind]
        pending = row["pending"]
        oldest = row["oldest_at"]
        known = type(pending) is int and pending >= 0 and (pending == 0 or bool(oldest and threshold))
        age = max(0, at - oldest) if oldest and threshold else None
        result.append(
            Signal(
                key="pipeline_" + kind,
                active=(bool(pending) and age >= threshold)
                if known and pending
                else False
                if known
                else None,
                severity="warning",
                title=kind.title() + " pipeline is delayed",
                evidence=str(pending)
                + " pending; "
                + (
                    str(age) + "seconds scheduled/queue age"
                    if age is not None
                    else "exact queue age unavailable"
                ),
                next_step="Inspect the pipeline queue and restore its dedicated worker; retain accepted records and audit evidence.",
                target="system/jobs",
            )
        )
    projection = value.get("projection") or {}
    oldest = projection.get("oldest_receipt_at")
    result.append(
        Signal(
            key="pipeline_reporting",
            active=at - oldest >= 300 if oldest else False,
            severity="warning",
            title="Activity reporting is delayed",
            evidence="Oldest unprocessed receipt: " + (str(at - oldest) + "seconds" if oldest else "none"),
            next_step="Restore bounded product projection and inspect its watermark before interpreting analytical changes.",
            target="product",
        )
    )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    base = os.environ["STUDIO_WATCHDOG_URL"].rstrip("/")
    url = urlsplit(base)
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
        raise ValueError("Watchdog requires an explicit HTTPS origin")
    source, token = os.environ["STUDIO_WATCHDOG_SOURCE"], os.environ["STUDIO_WATCHDOG_TOKEN"]
    if len(token) < 32 or not source or len(source) > 64:
        raise ValueError("Dedicated monitor source and token required")
    settings = Settings.from_env()
    # Deliberately refuse the API's database URL; outage independence requires another store.
    database = os.environ["STUDIO_WATCHDOG_DB"]
    if database == settings.database_url:
        raise ValueError("Use an independent watchdog database")
    engine = make_engine(database, settings)
    upgrade(engine)
    factory = make_session_factory(engine)
    try:
        while True:
            cycle(factory, settings, base, source, token, os.environ.get("STUDIO_WATCHDOG_ADMIN_TOKEN", ""))
            if args.once:
                break
            time.sleep(settings.studio_monitor_poll_seconds)
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
