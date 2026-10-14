"""Bounded scalar diagnostic observations; never race proof or compensation authority."""
from collections import Counter

from fastapi import APIRouter, Query, Request
from sqlalchemy import select

from .admin import Access, Window
from .admin_ranges import calendar_range
from .quality_models import QualityFact
from .track_models import Track, TrackVersion, digest

router = APIRouter(tags=["client quality"])
BUCKET_UPPER_MS = (8, 12, 17, 25, 34, 50, 100, None)
NAMES = {"quality_summary", "segment_summary", "process_exit"}
NUMBERS = {"samples", "slow", "segment", "cell_x", "cell_y", "exit_reason", *("b" + str(i) for i in range(8))}
FIELDS = {"quality_summary": {"device_class", "scene", "samples", "slow", *("b" + str(i) for i in range(8))},
    "segment_summary": {"track_version_id", "segment", "cell_x", "cell_y", "samples", "slow"},
    "process_exit": {"exit_reason", "device_class"}}


def validate(name, props):
    if name == "segment_summary" or name == "quality_summary" and props.get("scene") == "race":
        raise ValueError("RACE_PACKAGE_REQUIRED")
    if set(props) != FIELDS[name]:
        raise ValueError("INVALID_EVENT")
    for key, value in props.items():
        if key in NUMBERS:
            low, high = (-5000, 5000) if key in ("cell_x", "cell_y") else (0, 1000000)
            if type(value) is not int or not low <= value <= high:
                raise ValueError("INVALID_EVENT")
        elif key == "device_class" and value not in ("android_arm64", "android_other", "desktop", "other") or key == "scene" and value not in ("race", "menu", "editor"):
            raise ValueError("INVALID_EVENT")
    if name == "quality_summary" and (sum(props["b" + str(i)] for i in range(8)) != props["samples"]
            or props["slow"] != sum(props["b" + str(i)] for i in (5, 6, 7))):
        raise ValueError("INVALID_EVENT")
    if name == "segment_summary" and (props["segment"] > 31 or props["slow"] > props["samples"]):
        raise ValueError("INVALID_EVENT")
    if name == "process_exit" and props["exit_reason"] not in (4, 5, 6):
        raise ValueError("INVALID_EVENT")
    return props


def project(session, events, insert_for):
    counters, contexts = {}, {}
    for event in events:
        discovery = event.name in ("track_exposed", "track_selected") and event.properties.get("track_version_id")
        if (event.name not in NAMES and not discovery) or event.source != "client":
            continue
        props = event.properties
        context = {"track_version_id": props["track_version_id"]} if discovery else {
            "build_id": event.build_id, "platform": event.platform, **{k: v for k, v in props.items() if k not in
                {"samples", "slow", *("b" + str(i) for i in range(8))}}}
        identity = event.occurred_at // 86400, "discovery" if discovery else event.name, digest(context)
        contexts[identity] = context
        values = counters.setdefault(identity, Counter())
        values["reports"] += int(event.name != "track_selected")
        for field in ("samples", "slow", *("b" + str(i) for i in range(8))):
            values[field] += int(event.name == "track_selected") if discovery and field == "samples" else props.get(field, 0)
    if counters:
        statement = insert_for(session, QualityFact).values([{ "day": day, "kind": kind, "dimension": dimension,
            "context": contexts[identity], **dict(values)} for identity, values in counters.items()
            for day, kind, dimension in (identity,)])
        session.execute(statement.on_conflict_do_update(index_elements=["day", "kind", "dimension"], set_={
            field: getattr(QualityFact, field) + getattr(statement.excluded, field)
            for field in ("reports", "samples", "slow", *("b" + str(i) for i in range(8)))}))


@router.get("/v1/admin/quality")
def report(request: Request, role: Access, window: Window, kind: str = "quality_summary",
           limit: int = Query(1000, ge=1, le=1000)):
    if kind not in NAMES | {"discovery"}:
        from fastapi import HTTPException
        raise HTTPException(422, "INVALID_DIAGNOSTIC_KIND")
    first, until = window or calendar_range(7)
    with request.app.state.session_factory() as session:
        rows = session.scalars(select(QualityFact).where(QualityFact.kind == kind,
            QualityFact.day >= first // 86400, QualityFact.day <= (until - 1) // 86400)
            .order_by(QualityFact.day.desc(), QualityFact.dimension).limit(limit + 1)).all()
        return {"items": [{"day": row.day, "context": row.context, **{field: getattr(row, field)
            for field in ("reports", "samples", "slow", *("b" + str(i) for i in range(8)))}}
            for row in rows[:limit]], "truncated": len(rows) > limit, "role": role,
            "bucket_upper_ms": BUCKET_UPPER_MS,
            "resolution": "UTC calendar day; partial-day requests include their entire day buckets",
            "coverage": {"enabled": request.app.state.settings.client_quality_enabled,
                "guest": "unavailable", "crash_stack": "unavailable", "play_vitals": "unavailable",
                "spatial": "Client 1 Hz observations in 20 m cells; sampled presence, never verified race evidence.",
                "sampling": "Historical schema-1 segment facts only. Current race capture is one schema-2 package with at most 128 cells and 32 segments; use /race-statistics for current device/OS evidence.",
                "exit": "Android API 30+ OS process exits; previous process, not proven current-player crash/ANR.",
                "capture": "Fixed counters only; no arbitrary logs, coordinates, credentials or control-input captures."}}


@router.get("/v1/admin/creator-health")
def creator_health(request: Request, role: Access, limit: int = Query(100, ge=1, le=100)):
    with request.app.state.session_factory() as session:
        rows = session.execute(select(TrackVersion, Track).join(Track)
            .where(TrackVersion.state == "published")
            .order_by(TrackVersion.created_at.desc(), TrackVersion.id).limit(limit + 1)).all()
        return {"items": [{"version_id": version.id, "track_id": track.id, "creator_id": track.owner_id,
            "name": version.name, "state": version.state, "created_at": version.created_at,
            "published_at": version.published_at, "hidden": track.hidden, "archived": track.archived}
            for version, track in rows[:limit]], "truncated": len(rows) > limit, "role": role,
            "coverage": "Latest 100 immutable versions and publication states. Local unsaved drafts, editor crashes and validation phase timings are unavailable."}
