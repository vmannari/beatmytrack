"""Client-observed request health, bounded prepared facts and selected correlation hints."""
from collections import Counter
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import delete, select, tuple_

from .admin import Access, Window
from .admin_ranges import calendar_range
from .network_models import NetworkHealthDay
from .telemetry_models import ProductEvent, ProductState
from .track_models import digest, now

router = APIRouter(tags=["client network health"])
NAMES = {"network_summary", "network_failure"}
CATEGORIES = ("bootstrap", "authentication", "profile", "discovery", "track_document", "race_ticket",
    "score_upload", "run_status", "resume", "publication", "competition", "comparison", "ghost", "rating", "commerce", "other")
ERRORS = ("none", "cancelled", "dns", "connect", "tls", "timeout", "connection", "body_limit", "redirect",
    "invalid_response", "encoding", "local", "http_4xx", "throttled", "http_5xx", "http_other")
METHODS = ("GET", "POST", "PATCH", "DELETE", "HEAD", "PUT", "OPTIONS", "OTHER")
LIMITS = (25, 50, 100, 250, 500, 1000, 5000, None)
AGE_LIMITS = (1, 5, 15, 60, 300, 3600, 86400, None)
MAX_ATTEMPTS, MAX_MS, MAX_BYTES, MAX_AGE = 1000000, 86400000, 8388608, 7776000
ARRAYS = {"latency_buckets": 8, "queue_buckets": 8, "http_buckets": 8, "status_buckets": 7,
    "error_buckets": 16, "method_buckets": 8, "upload_age_buckets": 8}
COUNTERS = ("attempts", "successes", "cancelled", "retries", "throttled", "upload_age_samples",
    "dropped_observations", "dropped_failures", "request_body_bytes", "response_body_bytes",
    "total_ms", "queue_ms", "encode_ms", "http_ms", "decode_ms")
SUMMARY_FIELDS = {"schema_version", "category", "device_model", "os_version", *COUNTERS, *ARRAYS}
FAILURE_FIELDS = {"schema_version", "category", "device_model", "os_version", "method", "error_type", "http_status", "total_ms",
    "queue_ms", "encode_ms", "http_ms", "decode_ms", "retry_index", "upload_age_seconds"}
FIELDS = {"network_summary": SUMMARY_FIELDS, "network_failure": FAILURE_FIELDS | {"request_id"}}


def integer(value, low=0, high=MAX_ATTEMPTS):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("INVALID_NETWORK_OBSERVATION")
    return value


def validate(name, value):
    if not isinstance(value, dict) or value.get("category") not in CATEGORIES:
        raise ValueError("INVALID_NETWORK_OBSERVATION")
    integer(value.get("schema_version"), low=1, high=1)
    for field in ("device_model", "os_version"):
        text = value.get(field)
        if not isinstance(text, str) or not 1 <= len(text) <= 80 or any(ord(c) < 32 or ord(c) == 127 for c in text):
            raise ValueError("INVALID_NETWORK_OBSERVATION")
    if name == "network_failure":
        if not FAILURE_FIELDS <= set(value) or not set(value) <= FIELDS[name]:
            raise ValueError("INVALID_NETWORK_OBSERVATION")
        if value["method"] not in METHODS or value["error_type"] not in ERRORS[2:]:
            raise ValueError("INVALID_NETWORK_OBSERVATION")
        for field in ("http_status", "retry_index", "upload_age_seconds", "total_ms", "queue_ms", "encode_ms", "http_ms", "decode_ms"):
            integer(value[field], low=-1 if field == "upload_age_seconds" else 0,
                high=MAX_AGE if field == "upload_age_seconds" else 999 if field == "http_status" else 1000 if field == "retry_index" else MAX_MS)
        if "request_id" in value:
            reference = value["request_id"]
            if not isinstance(reference, str) or len(reference) != 36 or UUID(reference).version != 4:
                raise ValueError("INVALID_NETWORK_OBSERVATION")
            value = {**value, "request_id": str(UUID(reference))}
        if any(value[field] > value["total_ms"] for field in ("queue_ms", "encode_ms", "http_ms", "decode_ms")):
            raise ValueError("INVALID_NETWORK_OBSERVATION")
        return value
    if name != "network_summary" or set(value) != SUMMARY_FIELDS:
        raise ValueError("INVALID_NETWORK_OBSERVATION")
    for field in ("device_model", "os_version"):
        text = value[field]
        if not isinstance(text, str) or not 1 <= len(text) <= 80 or any(ord(c) < 32 or ord(c) == 127 for c in text):
            raise ValueError("INVALID_NETWORK_OBSERVATION")
    for field in COUNTERS:
        maximum = MAX_ATTEMPTS * (MAX_BYTES if field.endswith("_bytes") else MAX_MS) if field.endswith(("_bytes", "_ms")) else MAX_ATTEMPTS
        integer(value[field], high=maximum)
    attempts = integer(value["attempts"], low=1)
    for field in COUNTERS:
        if field.endswith(("_bytes", "_ms")) and value[field] > attempts * (MAX_BYTES if field.endswith("_bytes") else MAX_MS):
            raise ValueError("INVALID_NETWORK_OBSERVATION")
    for field, size in ARRAYS.items():
        values = value[field]
        if not isinstance(values, list) or len(values) != size:
            raise ValueError("INVALID_NETWORK_OBSERVATION")
        if sum(integer(count) for count in values) != (value["upload_age_samples"] if field == "upload_age_buckets" else attempts):
            raise ValueError("INVALID_NETWORK_OBSERVATION")
    if (value["successes"] != value["error_buckets"][0] or value["cancelled"] != value["error_buckets"][1]
            or value["throttled"] != value["status_buckets"][4] or value["retries"] > attempts
            or value["upload_age_samples"] > attempts
            or value["category"] != "score_upload" and value["upload_age_samples"] != 0):
        raise ValueError("INVALID_NETWORK_OBSERVATION")
    if any(value[field] > value["total_ms"] for field in ("queue_ms", "encode_ms", "http_ms", "decode_ms")):
        raise ValueError("INVALID_NETWORK_OBSERVATION")
    for field, bins in (("total_ms", "latency_buckets"), ("queue_ms", "queue_buckets"), ("http_ms", "http_buckets")):
        minimum = sum(count * (0 if index == 0 else LIMITS[index - 1] + 1) for index, count in enumerate(value[bins]))
        maximum = sum(count * (LIMITS[index] if LIMITS[index] is not None else MAX_MS) for index, count in enumerate(value[bins]))
        if not minimum <= value[field] <= maximum:
            raise ValueError("INVALID_NETWORK_OBSERVATION")
    return value


def project(session, events):
    grouped = {}
    for event in events:
        if event.source != "client" or event.name != "network_summary":
            continue
        props = event.properties
        context = {"platform": event.platform, "build_id": event.build_id,
            **{field: props[field] for field in ("category", "device_model", "os_version")}}
        key = event.occurred_at // 86400, digest(context)
        grouped.setdefault(key, (context, []))[1].append((props, event.received_at))
    if not grouped:
        return
    rows = {(row.day, row.dimension): row for row in session.scalars(select(NetworkHealthDay).where(
        tuple_(NetworkHealthDay.day, NetworkHealthDay.dimension).in_(grouped)).with_for_update())}
    for key, (context, reports) in grouped.items():
        row = rows.get(key)
        if row is None:
            row = NetworkHealthDay(day=key[0], dimension=key[1], **context, counters={}, buckets={}, latest_received_at=0)
            session.add(row)
        counters = Counter(row.counters)
        buckets = {field: list(row.buckets.get(field, [0] * size)) for field, size in ARRAYS.items()}
        for props, received_at in reports:
            counters.update({field: props[field] for field in COUNTERS})
            for field in ARRAYS:
                buckets[field] = [left + right for left, right in zip(buckets[field], props[field], strict=True)]
            row.latest_received_at = max(row.latest_received_at, received_at)
        row.counters, row.buckets = dict(counters), buckets


def cleanup(session, at, limit, fact_days):
    keys = session.execute(select(NetworkHealthDay.day, NetworkHealthDay.dimension)
        .where(NetworkHealthDay.day < at // 86400 - fact_days).order_by(NetworkHealthDay.day, NetworkHealthDay.dimension).limit(limit)).all()
    if keys:
        session.execute(delete(NetworkHealthDay).where(tuple_(NetworkHealthDay.day, NetworkHealthDay.dimension).in_(keys)))


@router.get("/v1/admin/network-health")
def report(request: Request, role: Access, window: Window, platform: str = Query("", max_length=12),
           build_id: str = Query("", max_length=80), category: str = Query("", max_length=24),
           device_model: str = Query("", max_length=80), os_version: str = Query("", max_length=80),
           limit: int = Query(500, ge=1, le=1000)):
    if platform and platform not in ("android", "windows", "linux", "ios") or category and category not in CATEGORIES:
        raise HTTPException(422, "INVALID_NETWORK_FILTER")
    first, until = window or calendar_range(7)
    with request.app.state.session_factory() as session:
        state = session.get(ProductState, 1)
        retained_day = now() // 86400 - (state.fact_days if state else 180)
        conditions = [NetworkHealthDay.day >= max(first // 86400, retained_day), NetworkHealthDay.day <= (until - 1) // 86400]
        for field, value in (("platform", platform), ("build_id", build_id), ("category", category), ("device_model", device_model), ("os_version", os_version)):
            if value: conditions.append(getattr(NetworkHealthDay, field) == value)
        rows = session.scalars(select(NetworkHealthDay).where(*conditions)
            .order_by(NetworkHealthDay.day.desc(), NetworkHealthDay.dimension).limit(limit + 1)).all()
        # Raw selected failures stay in the existing client-receipt retention.
        # This partial-index scan reads at most201 candidates, never a raw backlog.
        candidates = session.scalars(select(ProductEvent).where(ProductEvent.source == "client", ProductEvent.name == "network_failure",
            ProductEvent.occurred_at >= first, ProductEvent.occurred_at < until,
            ProductEvent.received_at >= now() - request.app.state.settings.telemetry_raw_days * 86400)
            .order_by(ProductEvent.occurred_at.desc(), ProductEvent.id.desc()).limit(201)).all()
        failures = [{"occurred_at": event.occurred_at, "build_id": event.build_id, "platform": event.platform,
            **event.properties} for event in candidates[:200]
            if (not platform or event.platform == platform) and (not build_id or event.build_id == build_id)
            and (not category or event.properties["category"] == category)
            and (not device_model or event.properties["device_model"] == device_model)
            and (not os_version or event.properties["os_version"] == os_version)]
        totals, buckets = Counter(), {field: [0] * size for field, size in ARRAYS.items()}
        for row in rows[:limit]:
            totals.update(row.counters)
            for field in ARRAYS: buckets[field] = [a + b for a, b in zip(buckets[field], row.buckets[field], strict=True)]
        return {"schema": "bmt-network-health-v1", "role": role, "filters": {"platform": platform, "build_id": build_id,
            "category": category, "device_model": device_model, "os_version": os_version}, "totals": dict(totals), "buckets": buckets,
            "items": [{"day": row.day, "platform": row.platform, "build_id": row.build_id, "category": row.category,
                "device_model": row.device_model, "os_version": row.os_version, "counters": row.counters, "buckets": row.buckets} for row in rows[:limit]],
            "failures": failures[:50], "truncated": len(rows) > limit, "failure_candidates_truncated": len(candidates) > 200,
            "failure_samples_truncated": len(failures) > 50,
            "latency_bucket_upper_ms": LIMITS, "categories": CATEGORIES,
            "upload_age_bucket_upper_seconds": AGE_LIMITS, "error_types": ERRORS, "methods": METHODS,
            "collection": {"enabled": request.app.state.settings.telemetry_enabled and request.app.state.settings.client_quality_enabled,
                "guest_available": False, "latest_summary_at": max((row.latest_received_at for row in rows[:limit]), default=None),
                "processor_observed_at": state.observed_at if state else None},
            "coverage": "Signed-in client-observed transmissions, not logical actions or service uptime. Total includes measured client queue/preparation, HTTP completion interval and decode; HTTP time includes callback scheduling, not server CPU. Request bytes are encoded body bytes; response bytes are returned decoded body bytes, excluding headers/TLS. Upload age requires a stored server-time anchor; legacy/unanchored uploads are unavailable. Selected request IDs are unverified client correlation hints; confirm them in server logs. Summaries use UTC day buckets; selected failures use exact event time."}
