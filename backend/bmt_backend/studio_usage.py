"""Usage, costs and resource headroom. Original all-player Studio totals remain intact."""
import re
from collections import defaultdict
from decimal import Decimal

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import BigInteger, case, cast, func, select, text
from sqlalchemy.exc import SQLAlchemyError

from .admin import Access, Window
from .admin_ranges import calendar_range
from .identity_models import Player, RateBucket
from .security import digest
from .studio_platform_models import AnalysisDay, AnalysisState
from .studio_queries import read_snapshot
from .studio_usage_cloud import UsageCloud, inventory, number, summarize
from .telemetry_models import ProductState
from .telemetry_queue_models import TelemetryControl, TelemetryCredit
from .track_models import QueueCapacity, QueueLimit, now
from .usernames import username_key

router = APIRouter(tags=["Studio usage and costs"])
STALE_SECONDS = 600


def headroom(key, label, current, limit, *, unit="count", peak=None, observed_at=None,
             source="application", note="", at=None, lower=False, peak_required=False, peak_kind="exact", proven_peak=None):
    at = now() if at is None else at
    current, limit, peak, proven_peak = number(current), number(limit), number(peak), number(proven_peak)
    fresh = observed_at is not None and -60 <= at - observed_at <= STALE_SECONDS
    assessed = max((v for v in (current, peak, proven_peak) if v is not None), default=None)
    ratio = assessed / limit if fresh and limit and assessed is not None else None
    state = ("critical" if ratio is not None and ratio >= .9 else "warning" if ratio is not None and ratio >= .75
        else "unknown" if ratio is None or (peak_required and (peak is None or lower)) else "normal")
    current_ratio = current / limit if fresh and limit and current is not None else None
    proven = max((v for v in (current, proven_peak) if v is not None), default=None)
    proven_ratio = proven / limit if fresh and limit and proven is not None else None
    # A histogram's upper edge is not an observed maximum. Crossing a
    # threshold only with that edge calls for verification, not a critical alert.
    bound_only = (peak_kind == "upper_bound" and ((state == "critical"
        and (proven_ratio is None or proven_ratio < .9)) or (state == "warning"
        and (proven_ratio is None or proven_ratio < .75))))
    if bound_only:
        state = "warning"
    reason = ("stale" if observed_at is not None and not fresh else "no_samples" if current is None
        else "limit_unverified" if not limit else "verify_peak" if bound_only
        else "current_pressure" if current_ratio is not None and current_ratio >= .75
        else "sampled_peak" if state in ("warning", "critical") else "observed")
    return {"key": key, "label": label, "current": current, "peak": peak, "limit": limit,
        "unit": unit, "status": state, "used_percent": round(100 * ratio, 2) if ratio is not None else None,
        "current_percent": round(100 * current_ratio, 2) if current_ratio is not None else None,
        "reason": reason, "peak_kind": "lower_bound" if lower else peak_kind, "proven_peak": proven_peak,
        "remaining": max(0, limit - current) if fresh and limit is not None and current is not None else None,
        "peak_is_lower_bound": lower, "observed_at": observed_at, "source": source, "note": note,
        "fresh": fresh, "thresholds": {"warning_percent": 75, "critical_percent": 90}}


def local_capacity(app, at):
    rows, sources = [], []
    settings = app.state.settings
    try:
        with app.state.session_factory() as session:
            read_snapshot(session)
            if session.bind.dialect.name == "postgresql":
                session.execute(text("SET LOCAL statement_timeout='1000ms'"))
                used, maximum, reserved = session.execute(text("SELECT (SELECT count(*) FROM pg_stat_activity),"
                    "current_setting('max_connections')::int,current_setting('superuser_reserved_connections')::int"
                    "+COALESCE(current_setting('reserved_connections',true),'0')::int"
                )).one()
                rows.append(headroom("database_connections", "Database connections", used, maximum - reserved,
                    observed_at=at, source="PostgreSQL", at=at,
                    note="Cluster-wide connections against non-superuser slots; includes this observation. Additional role/pool limits can bind first."))
            capacity = session.get(QueueCapacity, 1)
            queue_limit = session.get(QueueLimit, 1)
            rows.append(headroom("verification_queue", "Verification queue reservations", capacity.pending if capacity else None,
                queue_limit.capacity if queue_limit else settings.max_queued_runs, observed_at=at, at=at,
                note="Shared admission slots for pending race, validation and publication work."))
            control = session.get(TelemetryControl, 1)
            used, maximum = session.execute(select(func.sum(TelemetryCredit.capacity - TelemetryCredit.free),
                func.sum(TelemetryCredit.capacity))).one()
            rows.append(headroom("telemetry_queue", "Telemetry intake credits", used,
                maximum if maximum is not None else control.capacity if control else settings.telemetry_client_backlog,
                observed_at=at, at=at, note="Reserved intake capacity; delayed projections and erasure can retain credits."))
        sources.append({"source": "Application limits", "status": "observed", "observed_at": at})
    except SQLAlchemyError:
        sources.append({"source": "Application limits", "status": "unavailable"})
        for key, label, maximum in (("verification_queue", "Verification queue reservations", settings.max_queued_runs),
                                   ("telemetry_queue", "Telemetry intake credits", settings.telemetry_client_backlog)):
            rows.append(headroom(key, label, None, maximum, at=at))
    pool = app.state.engine.pool
    if hasattr(pool, "checkedout") and hasattr(pool, "size"):
        overflow = getattr(pool, "_max_overflow", settings.database_pool_overflow)
        rows.append(headroom("studio_pool", "Studio process database pool", pool.checkedout(),
            pool.size() + overflow if overflow >= 0 else None, observed_at=at, at=at,
            note="This Studio process only; API and worker pools have separate limits."))
    return rows, sources


def matches(series, name, kind):
    labels = series.get("resource", {}).get("labels", {})
    return (labels.get("database_id", "").split(":")[-1] == name if kind == "instances" else
            labels.get("worker_pool_name" if kind == "workerPools" else "job_name" if kind == "jobs" else "service_name") == name)


def cloud_capacity(cloud, settings, at):
    rows, traffic = [], []
    metrics = cloud.get("metrics", {})
    configs = {(r["kind"], r["name"]): r for r in cloud.get("resources", [])}
    for kind, names in inventory(settings).items():
        for name in names:
            config = configs.get((kind, name), {})
            sql = kind == "instances"
            for key, title in (("sql_cpu" if sql else "cpu", "CPU"), ("sql_memory" if sql else "memory", "Memory")):
                summary = summarize([s for s in metrics.get(key, []) if matches(s, name, kind)])
                rows.append(headroom(name + ":" + key, name + " / " + title, summary["current"], 1,
                    unit="ratio", peak=summary["peak"], observed_at=summary["observed_at"], at=at,
                    source="Cloud Monitoring", lower=summary.get("peak_is_lower_bound", False), peak_required=True,
                    peak_kind=summary.get("peak_kind", "unavailable"),
                    proven_peak=summary.get("proven_peak"),
                    note="Latest sampled utilization; peak over the last hour. Distribution peaks use conservative bucket bounds when exact maxima are absent."
                        + (" Configured container allocations: " + str(config["allocations"]) if config.get("allocations") else "")))
                allocations = config.get("allocations", [])
                memory = allocations[0].get("memory", "") if len(allocations) == 1 and key == "memory" else ""
                match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)(Ki|Mi|Gi)", memory)
                if match:
                    allocated = float(match[1]) * {"Ki": 1024, "Mi": 1024**2, "Gi": 1024**3}[match[2]]
                    rows[-1].update(allocated_bytes=allocated,
                        remaining_bytes=rows[-1]["remaining"] * allocated if rows[-1]["remaining"] is not None else None)
            if sql:
                used = summarize([s for s in metrics.get("sql_disk", []) if matches(s, name, kind)], additive=True)
                maximum = summarize([s for s in metrics.get("sql_disk_limit", []) if matches(s, name, kind)])
                cap = maximum["current"]
                observed = min(used["observed_at"], maximum["observed_at"]) if used["observed_at"] and maximum["observed_at"] else None
                rows.append(headroom(name + ":disk", name + " / Allocated database disk", used["current"], cap,
                    unit="bytes", peak=used["peak"], observed_at=observed, at=at, source="Cloud Monitoring",
                    note="Automatic growth " + ("enabled" if config.get("disk_autogrow") else "disabled or unobserved") +
                        "; current allocation is not a guaranteed future maximum."))
                if config.get("disk_autogrow"):
                    limit = number(config.get("disk_max_gib"))
                    rows.append(headroom(name + ":disk_max", name + " / Configured disk growth ceiling", used["current"],
                        limit * 1024**3 if limit else None, unit="bytes", peak=used["peak"], observed_at=used["observed_at"],
                        at=at, source="Cloud SQL configuration", note="Zero/unset growth ceiling means no configured cap; provider tier limits still apply."))
            elif kind != "jobs":
                summary = summarize([s for s in metrics.get("instances", []) if matches(s, name, kind)], additive=True)
                manual = kind == "workerPools"
                cap = None if manual else config.get("instance_limit")
                rows.append(headroom(name + ":instances", name + (" / Manual worker allocation" if manual else " / Instance scaling ceiling"),
                    summary["current"], cap, peak=summary["peak"], observed_at=summary["observed_at"], at=at,
                    source="Cloud Run configuration + Monitoring", peak_required=True,
                    note="Manual worker target: " + str(config.get("manual_instances", "unknown")) + ". Workers do not automatically scale; instance count alone cannot establish throughput headroom. Inspect CPU, memory and queue pressure." if manual else
                        "Configured scaling ceiling; transient platform overshoot is possible. A traffic split without a service-wide cap remains unknown."))
                scaling = rows[-1]
                if cap and scaling["fresh"] and scaling["current"] is not None:
                    scaling.update(status="configured", reason="scaling_ceiling" if scaling["current"] >= cap else "scaling_configuration")
                    scaling["note"] += " Instance allocation is not load. At the ceiling there is no configured scale-out room; inspect CPU, concurrency and errors before concluding overload."
                if manual:
                    scaling["reason"] = "manual_allocation"
                if not manual:
                    summary = summarize([s for s in metrics.get("concurrency", []) if matches(s, name, kind)])
                    rows.append(headroom(name + ":concurrency", name + " / Requests per instance", summary["current"],
                        config.get("concurrency_limit"), peak=summary["peak"], observed_at=summary["observed_at"], at=at,
                        lower=summary.get("peak_is_lower_bound", False), source="Cloud Run configuration + Monitoring", peak_required=True,
                        peak_kind=summary.get("peak_kind", "unavailable"),
                        proven_peak=summary.get("proven_peak"),
                        note="Configured revision concurrency; not a promise of sustainable application throughput."))
                for key in (("sent_bytes", "billable_seconds") if manual else ("requests", "sent_bytes", "billable_seconds")):
                    summary = summarize([s for s in metrics.get(key, []) if matches(s, name, kind)], additive=True)
                    traffic.append({"resource": name, "metric": key, "value": summary.get("total"),
                        "observed_at": summary["observed_at"], "window_seconds": 3600})
    # Daily-sampled quota limits are joined only on exact provider dimensions.
    # Ratev2 supplies a named window; legacy per-minute usage cannot safely be
    # compared with an arbitrary daily/per-user provider limit.
    for prefix, usage_key, limit_key in (("allocation", "quota_usage", "quota_limit"),
                                         ("rate", "quota_rate_usage", "quota_rate_limit")):
        def dimension(series):
            r, m = series.get("resource", {}).get("labels", {}), series.get("metric", {}).get("labels", {})
            return (r.get("project_id"), r.get("service"), r.get("location"), m.get("quota_metric"),
                    m.get("limit_name"), m.get("window_size"))
        usages = defaultdict(list)
        for s in metrics.get(usage_key, []):
            usages[dimension(s)].append(s)
        limits = metrics.get(limit_key, [])
        for index, s in enumerate(limits[:200]):
            dim = dimension(s)
            if dim[1] not in ("run.googleapis.com", "sqladmin.googleapis.com", "storage.googleapis.com", "bigquery.googleapis.com", "logging.googleapis.com"):
                continue
            matching = usages.get(dim, [])
            if not matching and prefix == "allocation" and sum(dimension(v)[:4] == dim[:4] for v in limits) == 1:
                matching = [v for k, values in usages.items() if k[:4] == dim[:4] for v in values]
            summary, limit = summarize(matching, additive=True), summarize([s])
            if limit["observed_at"] is None or at - limit["observed_at"] > 172800:
                maximum = None
            else:
                maximum = limit["current"]
            rows.append(headroom("quota:" + prefix + ":" + str(index), (dim[1] or "Provider") + " / "
                + (dim[4] or dim[3] or "Quota") + " / " + (dim[2] or "global"), summary["current"], maximum,
                peak=summary["peak"], observed_at=summary["observed_at"], source="Cloud Monitoring quota", at=at,
                note="Exact quota dimensions; " + ("window " + str(dim[5]) if dim[5] else "allocation")
                    + ". A missing matching usage series is unknown."))
    return rows, traffic


def ville_activity(app, first, until, at):
    result = {"name": "Ville", "active_players": None, "status": "unavailable", "requests": None,
              "all_observed_requests": None, "active_days": None, "player_id": None}
    # Identity metadata uses the original administrative connection. Analytical
    # facts always use the existing bounded reporting reader and erasure fence.
    try:
        with app.state.session_factory() as db:
            read_snapshot(db)
            statement = select(Player.id).where(Player.deleted_at.is_(None), Player.disabled.is_(False),
                Player.is_test_driver.is_(False), Player.needs_username.is_(False))
            configured = app.state.settings.studio_usage_player_id
            statement = statement.where(Player.id == configured) if configured else statement.where(Player.username_key == username_key("Ville"))
            player = db.scalar(statement)
        if not player:
            return {**result, "status": "account_not_found", "coverage": "No matching real account; no fallback to other players."}
        result["player_id"] = player
        with app.state.studio_reporting.snapshot(app.state.session_factory, window=(first, until)) as (db, source):
            state, product = db.get(AnalysisState, 1), db.get(ProductState, 1)
            if not state or state.processed_through is None or at // 86400 - (product.fact_days if product else 180) > first // 86400:
                return {**result, "status": "coverage_unavailable"}
            requests = cast(AnalysisDay.counters["network_attempts"].as_string(), BigInteger)
            active = cast(AnalysisDay.counters["active"].as_string(), BigInteger) > 0
            conditions = [AnalysisDay.day >= first // 86400, AnalysisDay.day < (until + 86399) // 86400]
            totals = db.execute(select(func.coalesce(func.sum(requests), 0),
                func.coalesce(func.sum(case((AnalysisDay.player_id == player, requests), else_=0)), 0),
                func.count(func.distinct(case(((AnalysisDay.player_id == player) & active, AnalysisDay.day)))))
                .where(*conditions)).one()
            result.update(status="observed", active_players=int(totals[2] > 0), active_days=totals[2],
                requests=int(totals[1]), all_observed_requests=int(totals[0]), processed_through=state.processed_through,
                fresh=-60 <= at - state.processed_through <= STALE_SECONDS, source=source.get("source"),
                collection_started_at=state.started_at, full_window_observed=state.started_at <= first,
                binding="configured stable ID" if configured else "unique claimed username Ville",
                coverage="Signed-in client network reports only. Guests, missing reports and background work are outside this denominator. Ville is the only eligible active player for the cost figure.")
    except (SQLAlchemyError, HTTPException):
        result["status"] = "reporting_unavailable"
    return result


def cost_summary(cloud, activity, settings, at):
    billing = cloud.get("billing", {"status": "unavailable", "rows": []})
    totals, services, daily, resources = [defaultdict(lambda: [Decimal(0), Decimal(0)]) for _ in range(4)]
    allocated, eligible_totals = defaultdict(Decimal), defaultdict(Decimal)
    api_names = [n for n in inventory(settings).get("services", []) if n.endswith("-api")]
    request_based = {r["name"] for r in cloud.get("resources", []) if r.get("request_based") is True}
    total_requests = activity.get("all_observed_requests")
    requests = activity.get("requests")
    share = (Decimal(requests) / Decimal(total_requests) if total_requests and requests is not None
        and 0 <= requests <= total_requests and activity.get("status") == "observed"
        and activity.get("fresh") and activity.get("full_window_observed") else None)
    for row in billing.get("rows", []):
        currency = row["currency"]
        gross = Decimal(str(row.get("gross", row["net"])))
        credits = Decimal(str(row.get("credits", Decimal(str(row["net"])) - gross)))
        net = gross + credits
        for target, key in ((totals, currency), (services, (row["service"], currency)),
                            (daily, (row["day"], currency)),
                            (resources, (row["service"], row.get("resource") or row.get("global_resource") or "Unidentified resource", currency))):
            target[key][0] += gross
            target[key][1] += credits
        # A named detailed-export resource and verified request billing are
        # required. Idle/minimum-instance and all SQL/storage/worker charges stay
        # unallocated. This is a request-share estimate, not per-player CPU proof.
        sku = row.get("sku", "").lower()
        eligible = len(api_names) == 1 and api_names[0] in request_based and row["service"] == "Cloud Run" and any(
            resource == api_names[0] or resource.endswith("/services/" + api_names[0])
            or "/services/" + api_names[0] + "/revisions/" in resource
            for resource in (row.get("resource", ""), row.get("global_resource", "")))
        if (eligible and row.get("cost_type", "regular") == "regular"
                and any(v in sku for v in ("request", "cpu", "memory"))
                and not any(v in sku for v in ("idle", "minimum", "instance-based"))):
            eligible_totals[currency] += net
            if share is not None:
                allocated[currency] += net * share
    active = activity.get("active_players") == 1
    def amounts(values):
        gross, credits = values
        return {"gross": float(gross), "credits": float(credits), "net": float(gross + credits)}
    exports = [r["exported_at"] for r in billing.get("rows", []) if r.get("exported_at")]
    through = [r["usage_through"] for r in billing.get("rows", []) if r.get("usage_through")]
    return {"status": billing.get("status"), "reason": billing.get("reason"),
        "totals": [{"currency": c, **amounts(n)} for c, n in sorted(totals.items())],
        "services": [{"service": s, "currency": c, **amounts(n)} for (s, c), n in sorted(services.items())],
        "resources": [{"service": s, "resource": r, "currency": c, **amounts(n)} for (s, r, c), n in sorted(resources.items())],
        "daily": [{"day": d, "currency": c, **amounts(n)} for (d, c), n in sorted(daily.items())],
        "ville_estimates": [{"currency": c, "per_active_player": float(n) if active else None,
            "unallocated": float(sum(totals[c]) - n), "eligible_api_net": float(eligible_totals[c]),
            "model": "client_request_share_scenario", "confidence": "low"} for c, n in sorted(allocated.items())],
        "request_share": float(share) if share is not None else None, "observed_at": billing.get("observed_at"),
        "last_export_at": max(exports) if exports else None, "usage_through": max(through) if through else None,
        "measured_cost_per_active_player": None, "forecast": None,
        "forecast_reason": "A final bill cannot be forecast reliably from a new or incomplete export. Credits, late charges, fixed capacity and future traffic can change it.",
        "method": "A low-confidence planning scenario, not measured player cost: Ville's share of signed-in client request attempts multiplied by identifiable request-billed API charges in the selected dates. Attempts can fail before reaching the server; endpoints differ in CPU cost, billing delivery lags activity, and current billing configuration does not prove its history. This assumes equal cost per reported attempt and representative client coverage. Idle, worker, database, storage, taxes and unidentified charges remain unallocated.",
        "coverage": billing.get("coverage", "Connect a detailed Cloud Billing export to measure charges. No price assumptions or currency conversions are applied.")}


@router.get("/v1/admin/usage-costs")
def usage_costs(request: Request, role: Access, window: Window, days: int = Query(7, ge=1, le=90)):
    app, at = request.app, now()
    first, requested_until = window or calendar_range(days)
    # Per-player analytical facts are calendar-day facts, not exact intraday logs.
    if first % 86400:
        raise HTTPException(422, "USAGE_REQUIRES_UTC_CALENDAR_DATES")
    # Studio saved locations retain the observation timestamp. Reopening a
    # historical location still selects that full UTC calendar date, matching
    # the analytical facts and the date-only controls.
    until = min(((requested_until - 1) // 86400 + 1) * 86400, at + 1)
    if first >= until:
        raise HTTPException(422, "USAGE_RANGE_HAS_NO_OBSERVED_TIME")
    app.state.studio_reporting.validate_window((first, until))
    provider = getattr(app.state, "studio_usage_cloud", None)
    if provider is None:
        # Constructed once at app creation in normal operation; injection is used
        # only by owned fixtures and operator read-only previews.
        provider = app.state.studio_usage_cloud = UsageCloud(app.state.settings)
    cloud = provider.collect(first, until)
    local, sources = local_capacity(app, at)
    remote, traffic = cloud_capacity(cloud, app.state.settings, at)
    activity = ville_activity(app, first, until, at)
    rows = local + remote
    if not inventory(app.state.settings):
        rows.append(headroom("cloud_coverage", "Cloud CPU, memory, scaling and provider quotas", None, None, at=at,
            source="Google Cloud", note="No cloud inventory is connected. Configure explicit project/resource names and read access."))
    if activity.get("player_id"):
        try:
            with app.state.session_factory() as db:
                read_snapshot(db)
                for key, label, maximum in (("player_read", "Ville / Read request budget", app.state.settings.rate_limit_per_minute),
                                            ("player_write", "Ville / Write request budget", app.state.settings.write_limit_per_minute)):
                    bucket = db.get(RateBucket, digest(f"{activity['player_id']}:{key}:{at // 60}"))
                    rows.append(headroom("ville:" + key, label, bucket.count if bucket else 0, None,
                        observed_at=at, at=at, note="Current UTC minute; reserved leases can exceed actual calls. This Studio runtime configures "
                            + str(maximum) + " per minute, but the deployed API's policy must be verified before its remaining budget can be established."))
        except SQLAlchemyError:
            sources.append({"source": "Ville request budgets", "status": "unavailable"})
    for row in rows:
        row["group"] = ("quotas" if row["key"].startswith("quota:") else "scheduled" if any(row["key"].startswith(n + ":")
            for n in inventory(app.state.settings).get("jobs", [])) else "application" if ":" not in row["key"] or row["key"].startswith("ville:") else "cloud")
    rows.sort(key=lambda r: ({"critical": 0, "warning": 1, "configured": 2, "unknown": 3, "normal": 4}[r["status"]],
                             -(r["used_percent"] or 0), r["label"]))
    return {"schema": "bmt-studio-usage-costs-v1", "read_only": True, "role": role, "as_of": at,
        "since": first, "until": until, "capacity_window_seconds": 3600, "resources": rows,
        "summary": {s: sum(r["status"] == s for r in rows) for s in ("critical", "warning", "unknown", "normal", "configured")},
        "activity": activity, "costs": cost_summary(cloud, activity, app.state.settings, at), "traffic": traffic,
        "endpoints": cloud.get("endpoints", {"status":"unavailable","rows":[]}),
        "sources": sources + cloud.get("sources", []), "cloud_status": cloud.get("status"),
        "project": app.state.settings.studio_usage_project or None,
        "limits": ["Warnings start at 75%; critical at 90%. These are operational indicators, not measured throughput guarantees.",
            "Capacity uses current observations and the last hour of sampled peaks; selected dates apply to costs and Ville activity.",
            "Missing or stale usage/limits are unknown. Cloud metrics can lag. Quotas shown are provider-published matching series, not an exhaustive inventory of every service limit.",
            "Global request/worker/resource totals include other players and artificial drivers. Only the cost-per-active-player figure is restricted to Ville.",
            "Billing is delayed and can change. Full per-player CPU/database/storage attribution is unavailable."]}
