"""Bounded shader preparation diagnostics; no source text or device identifier."""
import re

from fastapi import APIRouter, Query, Request
from sqlalchemy import select

from .admin import Access, Window
from .admin_ranges import calendar_range
from .studio_queries import read_snapshot
from .telemetry_models import ProductEvent
from .track_models import now

router = APIRouter(tags=["shader preparation"])

FIELDS = {"schema_version", "context", "biome", "renderer", "car", "simple", "graphics", "status", "observed",
          "missing", "dropped", "late_compile_us", "misses"}
PHASES = {"loading", "countdown", "driving", "results"}
HEX = re.compile(r"[a-f0-9]{64}\Z")


def validate(value):
    def check(condition):
        if not condition:
            raise ValueError("INVALID_EVENT")

    def integer(number, maximum):
        return type(number) is int and 0 <= number <= maximum

    def digest(text):
        return isinstance(text, str) and HEX.fullmatch(text) is not None

    check(isinstance(value, dict) and set(value) == FIELDS)
    check(type(value["schema_version"]) is int and value["schema_version"] == 1)
    check(digest(value["context"]))
    check(isinstance(value["biome"], str) and value["biome"] in {"pine", "winter", "desert", "storm", "night_city", "unknown"})
    check(value["renderer"] == "gl_compatibility" and value["status"] in ("matched", "unprofiled"))
    check(value["car"] in ("compact", "pickup", "classic", "formula", "kart", "electric", "forklift", "hovercraft", "super_rally", "unknown"))
    check(type(value["simple"]) is bool)
    settings = value["graphics"]
    check(isinstance(settings, dict) and set(settings) == {"shadow_quality", "render_resolution", "anti_aliasing"})
    check(settings["shadow_quality"] in ("auto", "off", "low", "medium", "high"))
    check(settings["render_resolution"] in ("auto", "50", "67", "75", "100"))
    check(settings["anti_aliasing"] in ("auto", "off", "fxaa", "msaa_2x", "msaa_4x"))
    for field in ("observed", "missing", "dropped", "late_compile_us"):
        check(integer(value[field], 3600000000 if field == "late_compile_us" else 1000000 if field == "dropped" else 4096))
    check(value["missing"] <= value["observed"])
    check(isinstance(value["misses"], list) and len(value["misses"]) <= min(16, value["missing"]))
    seen = set()
    for row in value["misses"]:
        check(isinstance(row, dict) and set(row) == {"key", "shader", "variant", "specialization", "reason", "phase", "compile_phase", "compile_us"})
        check(digest(row["key"]) and row["key"] not in seen)
        check(digest(row["shader"]) and integer(row["variant"], 255))
        check(row["reason"] in ("unlisted", "late_compile"))
        check(isinstance(row["specialization"], str) and re.fullmatch(r"[a-f0-9]{16}", row["specialization"]) is not None)
        check(isinstance(row["phase"], str) and row["phase"] in PHASES)
        check(isinstance(row["compile_phase"], str) and row["compile_phase"] in PHASES | {"cached", "outside"})
        check(integer(row["compile_us"], 60000000))
        seen.add(row["key"])
    return value


@router.get("/v1/admin/shader-profiles")
def report(request: Request, role: Access, window: Window,
           biome: str = Query("", max_length=24), context: str = Query("", max_length=64),
           limit: int = Query(100, ge=1, le=500)):
    first, until = window or calendar_range(7)
    with request.app.state.session_factory() as session:
        read_snapshot(session)
        candidates = session.scalars(select(ProductEvent).where(
            ProductEvent.source == "client", ProductEvent.name == "shader_profile",
            ProductEvent.occurred_at >= first, ProductEvent.occurred_at < until,
            ProductEvent.received_at >= now()-request.app.state.settings.telemetry_raw_days*86400)
            .order_by(ProductEvent.occurred_at.desc(), ProductEvent.id.desc()).limit(1001)).all()
        # Filter only this bounded indexed window; no unbounded raw-event scan.
        selected = [event for event in candidates[:1000]
                    if (not biome or event.properties.get("biome") == biome)
                    and (not context or event.properties.get("context") == context)]
        return {"items": [{"occurred_at": event.occurred_at, "build_id": event.build_id,
                           "platform": event.platform, **event.properties} for event in selected[:limit]],
                "truncated": len(candidates) > 1000 or len(selected) > limit,
                "candidates": min(len(candidates), 1000), "role": role,
                "coverage": "Opt-in supported-engine reports only; bounded recent raw receipts, not fleet-wide absence proof."}
