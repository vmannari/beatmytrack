"""Bounded authenticated product ingestion; observations cannot grant game authority."""

import json
from typing import Annotated
from uuid import NAMESPACE_URL, UUID, uuid4, uuid5

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from . import quality
from .db import get_session
from .middleware import ParsedJSONRoute
from .security import current_player
from .telemetry_models import ProductEvent, ProductState
from .track_models import digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["product telemetry"])
DB = Annotated[object, Depends(get_session)]
Auth = Annotated[object, Depends(current_player)]
POLICY = "bmt-product-telemetry-v1"
SCHEMA = "bmt-product-events-v1"
MAX_EVENTS, MAX_BYTES = 50, 65536
MAX_AGE, FUTURE_ALLOWANCE = 7 * 86400, 300
CARS = {"compact", "pickup", "classic", "formula", "kart"}
BIOMES = {"pine", "desert", "night_city", "winter", "storm"}
PRODUCTS = {"creator_slot_1", "creator_slots_5", "creator_slots_10", "ad_free_month", "ad_free_forever"}
SERVER_NAMES = {"race_accepted", "creator_validated", "track_published", "challenge_created", "challenge_joined"}
TRACK_FIELDS = {"track_version_id", "ticket_id", "car_id", "biome", "mode", "position"}
ALLOWED = {
    "app_first_open": set(), "session_started": {"reason"}, "session_foregrounded": {"reason"},
    "session_backgrounded": {"foreground_ms"}, "session_heartbeat": {"foreground_ms"}, "menu_ready": set(),
    "track_exposed": TRACK_FIELDS, "track_selected": TRACK_FIELDS,
    "car_exposed": {"car_id", "position"}, "car_selected": {"car_id", "position"},
    "race_attempt": TRACK_FIELDS, "race_started": TRACK_FIELDS,
    "race_finished": TRACK_FIELDS | {"reason"}, "race_abandoned": TRACK_FIELDS | {"reason"},
    "race_retried": TRACK_FIELDS | {"reason"},
    "editor_opened": {"biome", "reason"}, "draft_saved": {"biome", "reason"},
    "publish_requested": {"biome", "reason"},
    "challenge_opened": {"challenge_id", "reason"}, "challenge_joined": {"challenge_id", "reason"},
    "challenge_created": {"challenge_id", "reason"}, "share_clicked": {"challenge_id", "reason"},
    "collection_summary": {"dropped_events", "rejected_events", "persistence_failures"},
    "store_opened": set(), "offer_exposed": {"product_id"}, "purchase_requested": {"product_id"},
}
ALLOWED.update(quality.FIELDS)
REASONS = {"launch", "resume", "inactivity", "finished", "restart", "exit", "background", "unknown",
    "save", "publish", "edit", "test", "open", "join", "create", "share"}


def insert_for(session, model):
    return (pg_insert if session.bind.dialect.name == "postgresql" else sqlite_insert)(model)


def uuid_value(value, *, version=None):
    if not isinstance(value, str) or len(value) != 36:
        raise ValueError("INVALID_EVENT")
    parsed = UUID(value)
    if version is not None and parsed.version != version:
        raise ValueError("INVALID_EVENT")
    return str(parsed)


def integer(value, low=0, high=86400000):
    if type(value) is not int or not low <= value <= high:
        raise ValueError("INVALID_EVENT")
    return value


def properties(name, value):
    if not isinstance(value, dict) or not set(value) <= ALLOWED[name]:
        raise ValueError("INVALID_EVENT")
    if name in ("offer_exposed", "purchase_requested") and "product_id" not in value:
        raise ValueError("INVALID_EVENT")
    if name in ("car_exposed", "car_selected") and "car_id" not in value:
        raise ValueError("INVALID_EVENT")
    result = {}
    for key, item in value.items():
        if name in quality.NAMES and key != "track_version_id":
            result[key] = item
            continue
        if key in ("track_version_id", "ticket_id", "challenge_id"):
            item = uuid_value(item)
        elif key == "car_id":
            if item not in CARS:
                raise ValueError("INVALID_EVENT")
        elif key == "product_id":
            if not isinstance(item, str) or item not in PRODUCTS:
                raise ValueError("INVALID_EVENT")
        elif key == "biome":
            if not isinstance(item, str) or item not in BIOMES:
                raise ValueError("INVALID_EVENT")
        elif key == "mode":
            if item not in ("free", "rivalry", "challenge", "creator"):
                raise ValueError("INVALID_EVENT")
        elif key == "position":
            item = integer(item, high=1000)
        elif key == "foreground_ms":
            item = integer(item)
        elif key in ("dropped_events", "rejected_events", "persistence_failures"):
            item = integer(item, high=1000000)
        elif key == "reason" and item not in REASONS:
            raise ValueError("INVALID_EVENT")
        result[key] = item
    return quality.validate(name, result) if name in quality.NAMES else result


class Batch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    schema_version: str = Field(alias="schema")
    purpose_policy: str
    build_id: str = Field(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9._:\-]+$")
    platform: str = Field(pattern=r"^(android|windows|linux|ios)$")
    clock_quality: str = Field("client_clock", pattern=r"^(server_estimate|client_clock)$")
    batch_id: str | None = None
    install_id: str | None = None
    events: list = Field(min_length=1, max_length=MAX_EVENTS)


def append_server_event(session, name, event_id, player_id, dimensions, *, occurred_at=None, is_test_driver=None):
    """Caller owns the authority transaction and feature gate; no game/query work."""
    if name not in SERVER_NAMES:
        raise ValueError("UNKNOWN_SERVER_PRODUCT_EVENT")
    event_key = str(uuid5(NAMESPACE_URL, "bmt-product-server-v1/" + name + "/" + str(event_id)))
    projected = {}
    for key in ("track_version", "track_version_id", "run_id", "ticket_id", "owner_id", "published_at", "car_id", "biome", "lap_count"):
        value = dimensions.get(key)
        if key in ("track_version", "track_version_id", "run_id", "ticket_id", "owner_id") and isinstance(value, str):
            try:
                projected[key] = uuid_value(value)
            except ValueError:
                pass
        elif ((key == "car_id" and isinstance(value, str) and value in CARS)
                or (key == "biome" and isinstance(value, str) and value in BIOMES)
                or (key == "lap_count" and type(value) is int and 0 <= value <= 20)
                or (key == "published_at" and type(value) is int and 0 <= value <= 4102444800)):
            projected[key] = value
    occurred = now() if occurred_at is None else occurred_at
    try:
        entity_id = uuid_value(str(event_id))
    except ValueError:
        entity_id = None
    value = {"id": event_key, "player_id": player_id, "is_test_driver": is_test_driver,
        "entity_id": entity_id,
        "source": "server", "name": name, "occurred_at": occurred, "received_at": now(),
        "properties": projected, "build_id": "", "platform": "", "clock_quality": "server", "payload_hash": ""}
    value["payload_hash"] = digest({key: value[key] for key in ("player_id", "name", "occurred_at", "properties")})
    session.execute(insert_for(session, ProductEvent).values(value).on_conflict_do_nothing(index_elements=["id"]))
    return event_key


@router.post("/v1/telemetry/batches")
def accept_batch(batch: Batch, request: Request, session: DB, player: Auth):
    if not request.app.state.settings.telemetry_enabled:
        raise HTTPException(503, "TELEMETRY_DISABLED")
    if batch.schema_version != SCHEMA or batch.purpose_policy != POLICY:
        raise HTTPException(422, "UNSUPPORTED_TELEMETRY_CONTRACT")
    if len(json.dumps(batch.model_dump(), separators=(",", ":")).encode()) > MAX_BYTES:
        raise HTTPException(413, "TELEMETRY_BATCH_TOO_LARGE")
    for optional in (batch.batch_id, batch.install_id):
        if optional is not None:
            try:
                uuid_value(optional, version=4)
            except ValueError:
                raise HTTPException(422, "INVALID_TELEMETRY_REFERENCE") from None
    at = now()
    parsed, acknowledgements = {}, []
    for index, raw in enumerate(batch.events):
        acknowledgement = {"index": index, "id": None, "status": "rejected", "reason": "INVALID_EVENT"}
        acknowledgements.append(acknowledgement)
        try:
            if not isinstance(raw, dict):
                raise TypeError("INVALID_EVENT")
            event_id = uuid_value(raw.get("id"), version=4)
            acknowledgement["id"] = event_id
            if set(raw) != {"id", "name", "occurred_at", "session_id", "seq", "monotonic_ms", "properties"}:
                raise ValueError("INVALID_EVENT")
            name = raw["name"]
            if not isinstance(name, str) or name not in ALLOWED:
                raise ValueError("INVALID_EVENT")
            if name in quality.NAMES and not request.app.state.settings.client_quality_enabled:
                raise ValueError("INVALID_EVENT")
            occurred = integer(raw["occurred_at"], high=4102444800)
            if occurred < at - MAX_AGE or occurred > at + FUTURE_ALLOWANCE:
                raise ValueError("CLOCK_OUTSIDE_WINDOW")
            event = {"id": event_id, "client_id": event_id, "entity_id": None, "player_id": player.id,
                "is_test_driver": bool(player.is_test_driver), "source": "client", "name": name,
                "occurred_at": occurred, "received_at": at,
                "session_id": uuid_value(raw["session_id"], version=4), "seq": integer(raw["seq"], high=2147483647),
                "install_id": batch.install_id,
                "monotonic_ms": integer(raw["monotonic_ms"], high=2147483647),
                "build_id": batch.build_id, "platform": batch.platform, "clock_quality": batch.clock_quality,
                "properties": properties(name, raw["properties"])}
            event["payload_hash"] = digest({key: value for key, value in event.items()
                if key not in ("received_at", "is_test_driver")})
            if event_id in parsed and parsed[event_id]["payload_hash"] != event["payload_hash"]:
                raise ValueError("ID_CONFLICT")
            parsed[event_id] = event
            acknowledgement.pop("reason")
            acknowledgement["status"] = "pending"
        except (ValueError, TypeError) as error:
            if str(error) in ("CLOCK_OUTSIDE_WINDOW", "ID_CONFLICT"):
                acknowledgement["reason"] = str(error)
            safe_id = acknowledgement["id"] or str(uuid5(NAMESPACE_URL, "rejected/" + str(uuid4())))
            if safe_id not in parsed:
                rejected = {"id": safe_id, "client_id": acknowledgement["id"], "entity_id": None, "player_id": player.id,
                    "is_test_driver": bool(player.is_test_driver), "source": "client",
                    "name": "collection_rejected", "occurred_at": at, "received_at": at,
                    "session_id": None, "seq": None, "monotonic_ms": None,
                    "install_id": batch.install_id,
                    "build_id": batch.build_id, "platform": batch.platform, "clock_quality": "server",
                    "properties": {"reason": acknowledgement["reason"]}}
                rejected["payload_hash"] = digest({key: rejected[key] for key in ("player_id", "name", "properties")})
                parsed[safe_id] = rejected
    if parsed:
        if session.bind.dialect.name == "sqlite":
            session.execute(text("BEGIN IMMEDIATE"))
        state = session.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
        existing = set(session.scalars(select(ProductEvent.id).where(ProductEvent.id.in_(parsed))))
        if state.pending_clients + len(set(parsed) - existing) > request.app.state.settings.telemetry_client_backlog:
            raise HTTPException(503, "TELEMETRY_BACKLOG_FULL")
        inserted = set(session.scalars(insert_for(session, ProductEvent).values(list(parsed.values()))
            .on_conflict_do_nothing(index_elements=["id"]).returning(ProductEvent.id)))
        state.pending_clients += len(inserted)
        state.pending_events += len(inserted)
        state.latest_receipt_at = max(state.latest_receipt_at or at, at)
        stored = {row.id: row for row in session.scalars(select(ProductEvent).where(ProductEvent.id.in_(parsed)))}
        seen = set()
        for acknowledgement in acknowledgements:
            if acknowledgement["status"] != "pending":
                continue
            event_id = acknowledgement["id"]
            row = stored[event_id]
            if row.player_id != player.id or row.payload_hash != parsed[event_id]["payload_hash"]:
                acknowledgement.update(status="rejected", reason="ID_CONFLICT")
            else:
                acknowledgement["status"] = "accepted" if event_id in inserted and event_id not in seen else "duplicate"
            seen.add(event_id)
    session.commit()  # No acknowledgement of acceptance precedes durable handling.
    return {"schema": "bmt-product-acks-v1", "events": acknowledgements}
