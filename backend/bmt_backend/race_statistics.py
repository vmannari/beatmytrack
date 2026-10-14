"""Bounded race-end diagnostics and prepared device/OS heatmaps, never score proof."""
import heapq
import json
from collections import Counter
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy import delete, select, tuple_

from .admin import Access, Window
from .admin_ranges import calendar_range
from .race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
from .telemetry_models import ProductState
from .track_models import Board, RunTicket, TrackVersion, digest, now

router = APIRouter(tags=["race diagnostics"])
MAX_BYTES, MAX_CELLS, MAX_SEGMENTS, AGGREGATE_CELLS = 16384, 128, 32, 1024
REQUIRED = {"schema_version", "race_id", "outcome", "elapsed_ms", "device_class", "device_model", "os_version",
    "frame_buckets", "cells", "segments", "position_samples", "dropped_samples"}
REFERENCES = {"track_version_id", "ticket_id"}
OPTIONAL = REFERENCES | {"render_context", "render_context_changed"}
CONTEXT = ("track_version_id", "build_id", "platform", "device_class", "device_model", "os_version", "outcome")
DEVICE_CLASSES = {"android_arm64", "android_other", "desktop", "other"}
OUTCOMES = {"finished", "abandoned", "restarted"}
RENDERERS = {"gl_compatibility", "mobile", "forward_plus", "unknown"}
DETAILS = {"full", "simple", "unknown"}
VSYNC = {"disabled", "enabled", "adaptive", "mailbox", "unknown"}
RENDER_FIELDS = ("schema_version", "renderer", "car_detail", "viewport_width", "viewport_height",
                 "scale_percent", "frame_limit", "vsync", "refresh_hz")


def integer(value, low=0, high=1000000):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("INVALID_RACE_STATISTICS")
    return value


def text_value(value):
    if not isinstance(value, str) or not 1 <= len(value) <= 80 or any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError("INVALID_RACE_STATISTICS")
    return value


def uuid_value(value):
    if not isinstance(value, str) or len(value) != 36 or UUID(value).version != 4:
        raise ValueError("INVALID_RACE_STATISTICS")
    return str(UUID(value))


def render_context(value):
    if not isinstance(value, dict) or set(value) != set(RENDER_FIELDS):
        raise ValueError("INVALID_RENDER_CONTEXT")
    integer(value["schema_version"], low=1, high=1)
    for field, allowed in (("renderer", RENDERERS), ("car_detail", DETAILS), ("vsync", VSYNC)):
        if not isinstance(value[field], str) or value[field] not in allowed:
            raise ValueError("INVALID_RENDER_CONTEXT")
    for field, low, high in (("viewport_width", 0, 16384), ("viewport_height", 0, 16384),
            ("scale_percent", 1, 400), ("frame_limit", 0, 1000), ("refresh_hz", 0, 1000)):
        integer(value[field], low=low, high=high)
    return {field: value[field] for field in RENDER_FIELDS}


def validate(value):
    if not isinstance(value, dict) or not REQUIRED <= set(value) or not set(value) <= REQUIRED | OPTIONAL:
        raise ValueError("INVALID_RACE_STATISTICS")
    if value["schema_version"] not in (2, 3) or type(value["schema_version"]) is not int:
        raise ValueError("INVALID_RACE_STATISTICS")
    result = dict(value)
    if value["schema_version"] == 3:
        result["render_context"] = render_context(value.get("render_context"))
        if type(value.get("render_context_changed")) is not bool:
            raise ValueError("INVALID_RENDER_CONTEXT")
    elif set(value) & {"render_context", "render_context_changed"}:
        raise ValueError("INVALID_RACE_STATISTICS")
    for field in ("race_id", *REFERENCES):
        if field in result:
            result[field] = uuid_value(result[field])
    if result["outcome"] not in OUTCOMES or result["device_class"] not in DEVICE_CLASSES:
        raise ValueError("INVALID_RACE_STATISTICS")
    for field in ("device_model", "os_version"):
        result[field] = text_value(result[field])
    integer(result["elapsed_ms"], high=3600000)
    integer(result["position_samples"], high=3600)
    integer(result["dropped_samples"], high=3600)
    buckets = result["frame_buckets"]
    if not isinstance(buckets, list) or len(buckets) != 8 or sum(integer(n) for n in buckets) > 1000000:
        raise ValueError("INVALID_RACE_STATISTICS")
    seen = set()
    for field, limit, size in (("cells", MAX_CELLS, 4), ("segments", MAX_SEGMENTS, 3)):
        rows = result[field]
        if not isinstance(rows, list) or len(rows) > limit:
            raise ValueError("INVALID_RACE_STATISTICS")
        for row in rows:
            if not isinstance(row, list) or len(row) != size:
                raise ValueError("INVALID_RACE_STATISTICS")
            if field == "cells":
                integer(row[0], -5000, 5000); integer(row[1], -5000, 5000)
                key = field, row[0], row[1]
            else:
                integer(row[0], high=31); key = field, row[0]
            samples, slow = row[-2:]
            integer(samples, low=1, high=3600); integer(slow, high=samples)
            if key in seen:
                raise ValueError("INVALID_RACE_STATISTICS")
            seen.add(key)
    if sum(row[2] for row in result["cells"]) + result["dropped_samples"] != result["position_samples"]:
        raise ValueError("INVALID_RACE_STATISTICS")
    if sum(row[1] for row in result["segments"]) != result["position_samples"]:
        raise ValueError("INVALID_RACE_STATISTICS")
    if "track_version_id" not in result and (result["cells"] or result["segments"] or result["position_samples"]):
        raise ValueError("LOCAL_TRACK_DIAGNOSTICS_NOT_ALLOWED")
    if len(json.dumps(result, separators=(",", ":"), ensure_ascii=False).encode()) > MAX_BYTES:
        raise ValueError("RACE_STATISTICS_TOO_LARGE")
    return result


def admit(session, parsed, acknowledgements, insert_for):
    """Called under existing ingress transaction fence; only published versions leave catalog data."""
    candidates = {identity: event for identity, event in parsed.items() if event["name"] == "race_statistics"}
    if not candidates:
        return
    versions = {event["properties"].get("track_version_id") for event in candidates.values()} - {None}
    published = set(session.scalars(select(TrackVersion.id).where(TrackVersion.id.in_(versions), TrackVersion.state == "published"))) if versions else set()
    ticket_ids = {event["properties"].get("ticket_id") for event in candidates.values()} - {None}
    tickets = {row[0]: (row[1], row[2]) for row in session.execute(select(RunTicket.id, RunTicket.player_id, Board.version_id)
        .join(Board, Board.id == RunTicket.board_id).where(RunTicket.id.in_(ticket_ids)))} if ticket_ids else {}
    keys = {(event["player_id"], event["properties"]["race_id"]) for event in candidates.values()}
    existing = {(row.player_id, row.race_id): row for row in session.scalars(select(RaceStatisticsReceipt).where(
        tuple_(RaceStatisticsReceipt.player_id, RaceStatisticsReceipt.race_id).in_(keys)))}
    receipts = []
    for identity, event in candidates.items():
        props = event["properties"]; key = event["player_id"], props["race_id"]
        original = existing.get(key)
        reason = None
        if identity != props["race_id"]:
            reason = "RACE_ID_MISMATCH"
        elif props.get("track_version_id") and props["track_version_id"] not in published:
            reason = "PUBLISHED_TRACK_REQUIRED"
        elif props.get("ticket_id") and tickets.get(props["ticket_id"]) != (event["player_id"], props.get("track_version_id")):
            reason = "RACE_TICKET_MISMATCH"
        elif original and original.payload_hash != digest(props):
            reason = "ID_CONFLICT"
        if reason or original:
            parsed.pop(identity)
            for ack in acknowledgements:
                if ack["id"] == identity and ack["status"] == "pending":
                    ack["status"] = "rejected" if reason else "duplicate"
                    if reason: ack["reason"] = reason
        else:
            receipts.append({"player_id": event["player_id"], "race_id": props["race_id"], "event_id": identity,
                "payload_hash": digest(props), "received_at": event["received_at"]})
    if receipts:
        session.execute(insert_for(session, RaceStatisticsReceipt).values(receipts)
            .on_conflict_do_nothing(index_elements=["player_id", "race_id"]))


def project(session, events):
    """One aggregate row per day/context; no cell-by-cell SQL and no proof object reads."""
    grouped = {}
    for event in events:
        if event.name != "race_statistics" or event.source != "client":
            continue
        props = event.properties
        context = {"track_version_id": props.get("track_version_id", ""), "platform": event.platform,
            "build_id": event.build_id, **{name: props[name] for name in ("device_class", "device_model", "os_version", "outcome")}}
        if props["schema_version"] == 3:
            context.update(render_context=props["render_context"], render_context_key=digest(props["render_context"]),
                           render_context_changed=props["render_context_changed"])
        key = event.occurred_at // 86400, digest(context)
        grouped.setdefault(key, [context, []])[1].append((props, event.received_at))
    if not grouped:
        return
    rows = {(row.day, row.dimension): row for row in session.scalars(select(RaceStatisticsDay).where(
        tuple_(RaceStatisticsDay.day, RaceStatisticsDay.dimension).in_(grouped)).with_for_update())}
    for key, (context, packages) in grouped.items():
        row = rows.get(key)
        if row is None:
            row = RaceStatisticsDay(day=key[0], dimension=key[1], **context, races=0, elapsed_ms=0,
                latest_received_at=0,
                frame_buckets=[0] * 8, position_samples=0, dropped_samples=0, aggregate_dropped_samples=0, cells={}, segments={})
            session.add(row)
        bins, cells, segments = list(row.frame_buckets), dict(row.cells), dict(row.segments)
        for props, received_at in packages:
            row.races += 1; row.elapsed_ms += props["elapsed_ms"]
            row.latest_received_at = max(row.latest_received_at, received_at)
            bins = [a + b for a, b in zip(bins, props["frame_buckets"], strict=True)]
            row.position_samples += props["position_samples"]; row.dropped_samples += props["dropped_samples"]
            for x, y, samples, slow in props["cells"]:
                identity = f"{x}:{y}"
                if identity not in cells and len(cells) >= AGGREGATE_CELLS:
                    row.aggregate_dropped_samples += samples; continue
                prior = cells.get(identity, [0, 0]); cells[identity] = [prior[0] + samples, prior[1] + slow]
            for segment, samples, slow in props["segments"]:
                identity = str(segment); prior = segments.get(identity, [0, 0])
                segments[identity] = [prior[0] + samples, prior[1] + slow]
        row.frame_buckets, row.cells, row.segments = bins, cells, segments


def cleanup(session, at, limit, fact_days):
    for model, fields, predicate, ordering in (
        (RaceStatisticsReceipt, (RaceStatisticsReceipt.player_id, RaceStatisticsReceipt.race_id), RaceStatisticsReceipt.received_at < at - 8 * 86400,
            (RaceStatisticsReceipt.received_at, RaceStatisticsReceipt.player_id, RaceStatisticsReceipt.race_id)),
        (RaceStatisticsDay, (RaceStatisticsDay.day, RaceStatisticsDay.dimension), RaceStatisticsDay.day < at // 86400 - fact_days,
            (RaceStatisticsDay.day, RaceStatisticsDay.dimension)),
    ):
        keys = session.execute(select(*fields).where(predicate).order_by(*ordering).limit(limit)).all()
        if keys: session.execute(delete(model).where(tuple_(*fields).in_(keys)))


def preview(version):
    from .studio_catalogue import preview as stored_preview
    return stored_preview(version.discovery) if version else {"available": False, "points": []}


def merge_cells(cells, heap, incoming):
    """Stable bottom-hash selection keeps report memory at 1024 cells, including wide scopes."""
    omitted = 0
    for identity, pair in incoming.items():
        if identity not in cells:
            priority = int(digest(identity), 16)
            if len(cells) >= AGGREGATE_CELLS:
                if priority >= -heap[0][0]:
                    omitted += pair[0]
                    continue
                _, evicted = heapq.heappop(heap)
                omitted += cells.pop(evicted)[0]
            heapq.heappush(heap, (-priority, identity))
            cells[identity] = [0, 0]
        prior = cells[identity]
        cells[identity] = [prior[0] + pair[0], prior[1] + pair[1]]
    return omitted


@router.get("/v1/admin/race-statistics")
def report(request: Request, role: Access, window: Window, track_version_id: str = Query("", max_length=36),
           device_model: str = Query("", max_length=80), os_version: str = Query("", max_length=80),
           platform: str = Query("", max_length=12), build_id: str = Query("", max_length=80),
           outcome: str = Query("", max_length=16), renderer: str = Query("", max_length=20),
           car_detail: str = Query("", max_length=10), render_context_key: str = Query("", max_length=64),
           context_state: str = Query("", max_length=10), limit: int = Query(500, ge=1, le=1000)):
    if track_version_id:
        try: track_version_id = str(UUID(track_version_id))
        except ValueError: raise HTTPException(422, "INVALID_TRACK_VERSION") from None
    if platform and platform not in ("android", "windows", "linux", "ios") or outcome and outcome not in OUTCOMES:
        raise HTTPException(422, "INVALID_DIAGNOSTIC_FILTER")
    if (renderer and renderer not in RENDERERS or car_detail and car_detail not in DETAILS
            or context_state not in ("", "stable", "changed", "unknown")
            or render_context_key and (len(render_context_key) != 64 or any(c not in "0123456789abcdef" for c in render_context_key))):
        raise HTTPException(422, "INVALID_DIAGNOSTIC_FILTER")
    first, until = window or calendar_range(7)
    with request.app.state.session_factory() as session:
        conditions = [RaceStatisticsDay.day >= first // 86400, RaceStatisticsDay.day <= (until - 1) // 86400]
        for field, value in (("track_version_id", track_version_id), ("device_model", device_model), ("os_version", os_version),
                ("platform", platform), ("build_id", build_id), ("outcome", outcome)):
            if value: conditions.append(getattr(RaceStatisticsDay, field) == value)
        if renderer: conditions.append(RaceStatisticsDay.render_context["renderer"].as_string() == renderer)
        if car_detail: conditions.append(RaceStatisticsDay.render_context["car_detail"].as_string() == car_detail)
        if render_context_key: conditions.append(RaceStatisticsDay.render_context_key == render_context_key)
        if context_state:
            conditions.append(RaceStatisticsDay.render_context_changed.is_(None if context_state == "unknown" else context_state == "changed"))
        rows = session.scalars(select(RaceStatisticsDay).where(*conditions)
            .order_by(RaceStatisticsDay.day.desc(), RaceStatisticsDay.dimension).limit(limit + 1)).all()
        option_conditions = conditions[:2]
        if track_version_id: option_conditions.append(RaceStatisticsDay.track_version_id == track_version_id)
        options = session.execute(select(RaceStatisticsDay.platform, RaceStatisticsDay.device_model, RaceStatisticsDay.os_version,
            RaceStatisticsDay.build_id).where(*option_conditions).distinct().order_by(RaceStatisticsDay.device_model,
            RaceStatisticsDay.os_version, RaceStatisticsDay.platform, RaceStatisticsDay.build_id).limit(201)).all()
        render_options = session.execute(select(RaceStatisticsDay.render_context_key, RaceStatisticsDay.render_context)
            .where(*option_conditions, RaceStatisticsDay.render_context_key.is_not(None)).distinct()
            .order_by(RaceStatisticsDay.render_context_key).limit(201)).all()
        version = session.get(TrackVersion, track_version_id) if track_version_id else None
        latest_receipt = session.scalar(select(RaceStatisticsReceipt.received_at).order_by(RaceStatisticsReceipt.received_at.desc()).limit(1))
        state = session.get(ProductState, 1)
        bins, cells, cell_heap, segments, totals = [0] * 8, {}, [], Counter(), Counter()
        for row in rows[:limit]:
            bins = [a + b for a, b in zip(bins, row.frame_buckets, strict=True)]
            for name in ("races", "elapsed_ms", "position_samples", "dropped_samples", "aggregate_dropped_samples"):
                totals[name] += getattr(row, name)
            # Different versions do not share a spatial coordinate or route-segment contract.
            if track_version_id:
                totals["query_dropped_samples"] += merge_cells(cells, cell_heap, row.cells)
                for identity, pair in row.segments.items():
                    segments[identity] += pair[0]; segments[identity + "|slow"] += pair[1]
        visible_cells = sorted(cells.items(), key=lambda p: (-p[1][0], p[0]))
        return {"schema": "bmt-race-statistics-v2", "role": role, "as_of": now(),
            "resolution": "UTC calendar day; partial-day requests include their entire day buckets",
            "filters": {"track_version_id": track_version_id, "device_model": device_model, "os_version": os_version,
                "platform": platform, "build_id": build_id, "outcome": outcome, "renderer": renderer,
                "car_detail": car_detail, "render_context_key": render_context_key, "context_state": context_state},
            "options": [{"platform": p, "device_model": d, "os_version": o, "build_id": b} for p, d, o, b in options[:200]],
            "render_options": [{"key": key, "context": context} for key, context in render_options[:200]],
            "render_options_truncated": len(render_options) > 200,
            "render_context_coverage": {"known_races": sum(row.races for row in rows[:limit] if row.render_context_key),
                "unknown_races": sum(row.races for row in rows[:limit] if not row.render_context_key),
                "changed_races": sum(row.races for row in rows[:limit] if row.render_context_changed)},
            "options_truncated": len(options) > 200, "totals": dict(totals), "frame_buckets": bins,
            "cells": [{"x": int(identity.split(":")[0]), "y": int(identity.split(":")[1]), "samples": pair[0],
                "slow": pair[1]} for identity, pair in visible_cells],
            "segments": [{"index": int(identity), "samples": samples, "slow": segments[identity + "|slow"]}
                for identity, samples in sorted(segments.items()) if "|" not in identity],
            "track": {"version_id": version.id, "name": version.name, "preview": preview(version)} if version and version.state == "published" else None,
            "groups": len(rows[:limit]), "truncated": len(rows) > limit or totals.get("query_dropped_samples", 0) > 0,
            "collection": {"enabled": request.app.state.settings.client_quality_enabled, "required_client_schema": 2,
                "preferred_client_schema": 3,
                "accepted_client_schemas": [2, 3],
                "latest_race_receipt_at": latest_receipt,
                "scope_latest_receipt_at": max((row.latest_received_at for row in rows[:limit]), default=None),
                "processor_observed_at": state.observed_at if state else None, "pending_events": state.pending_events if state else None,
                "latest_receipt_at": state.latest_receipt_at if state else None, "guest_available": False},
            "coverage": "One bounded package per signed-in timed race, including abandoned/restarted attempts. Client-observed frames and 1 Hz positions; no score eligibility is inferred. Local unpublished geometry is excluded. Missing device/OS values remain explicitly reported, never guessed."}
