"""Bound requests before parsing; share rate budgets across API replicas."""

import asyncio
import json
import logging
import math
import threading
import time
import uuid
import zlib
from collections import OrderedDict
from contextlib import nullcontext

from fastapi import HTTPException
from fastapi.routing import APIRoute
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool
from starlette.responses import JSONResponse

from .identity_models import RateBucket
from .security import digest

log = logging.getLogger("bmt.requests")


def check_budget(factory, peer: str, category: str, limit: int, amount: int = 1, *, session=None) -> bool:
    if amount > limit:
        return False
    current = int(time.time())
    key = digest(f"{peer}:{category}:{current // 60}")
    with nullcontext(session) if session is not None else factory() as budget_session:
        insert = sqlite_insert if budget_session.bind.dialect.name == "sqlite" else pg_insert
        statement = insert(RateBucket).values(key=key, count=amount, expires_at=current + 120)
        statement = statement.on_conflict_do_update(
            index_elements=[RateBucket.key],
            set_={"count": RateBucket.count + amount},
            where=RateBucket.count <= limit - amount,
        ).returning(RateBucket.count)
        value = budget_session.scalar(statement)
        budget_session.commit()
        return value is not None


class IdentityBudgets:
    """Small conservative leases shared in the DB, including across token rotation."""
    def __init__(self, factory):
        self.factory, self.leases, self.lock = factory, OrderedDict(), threading.Lock()

    def allow(self, player, category, limit, cost=1, *, session=None):
        key = (player, category, int(time.time()) // 60)
        with self.lock:
            lease = self.leases.setdefault(key, [0, threading.Lock()])
            self.leases.move_to_end(key)
            while len(self.leases) > 4096:
                self.leases.popitem(last=False)
        with lease[1]:
            remaining = lease[0]
            if remaining < cost:
                batch = min(max(10, cost), limit)
                if not check_budget(self.factory, player, category, limit, batch, session=session):
                    # Spend the final partial lease without increasing the hard limit.
                    if not check_budget(self.factory, player, category, limit, cost, session=session):
                        return False
                    batch = cost
                remaining += batch
            lease[0] = remaining - cost
            return True


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        key.encode("utf-8")  # Escaped lone surrogates are not valid Unicode data.
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("Nonfinite JSON value")


def parse_body(body):
    parsed = json.loads(body, object_pairs_hook=strict_object, parse_constant=reject_constant)
    pending = [(parsed, 0)]
    visited = 0
    maximum_nodes = 1200000 # Includes a full 216,000-frame four-channel replay.
    while pending:
        value, depth = pending.pop()
        visited += 1
        if depth > 32:
            raise ValueError("JSON nesting limit")
        if isinstance(value, dict):
            if visited + len(pending) + len(value) > maximum_nodes: raise ValueError("JSON node limit")
            pending.extend((v, depth + 1) for v in value.values())
        elif isinstance(value, list):
            if visited + len(pending) + len(value) > maximum_nodes: raise ValueError("JSON node limit")
            pending.extend((v, depth + 1) for v in value)
        elif isinstance(value, float) and not math.isfinite(value):
            raise ValueError("Nonfinite JSON number")
        elif isinstance(value, str):
            value.encode("utf-8")
    return parsed


class ParsedJSONRoute(APIRoute):
    def get_route_handler(self):
        handler = super().get_route_handler()

        async def bounded_handler(request):
            if "bounded_json" in request.scope.get("state", {}):
                # FastAPI reuses the strictly validated tree without a second loop-blocking decode.
                request._json = request.scope["state"]["bounded_json"]
            return await handler(request)

        return bounded_handler


class RequestBoundary:
    def __init__(self, app, settings, session_factory):
        self.app, self.settings, self.session_factory = app, settings, session_factory
        self.parsers = asyncio.Semaphore(settings.upload_concurrency)
        self.read_leases = OrderedDict()

    async def read_budget(self, peer, limit, category="read"):
        # Reserve small chunks in PostgreSQL, so replicas still share a hard ceiling.
        # Unused reservations are conservative; they never permit excess requests.
        key = (peer, category, int(time.time()) // 60)
        # Separate peers do not wait for each other's cold database reservation.
        lease = self.read_leases.setdefault(key, [0, asyncio.Lock()])
        self.read_leases.move_to_end(key)
        while len(self.read_leases) > 2048: self.read_leases.popitem(last=False)
        async with lease[1]:
            remaining = lease[0]
            if not remaining:
                batch = min(10, limit)
                if not await run_in_threadpool(check_budget, self.session_factory, peer, category, limit, batch):
                    return False
                remaining = batch
            lease[0] = remaining - 1
            return True

    def validated_identity_budget(self, scope, header):
        from fastapi import Request
        from fastapi.security import HTTPAuthorizationCredentials

        from .security import current_player

        try:
            pieces = header.decode("ascii").split()
        except UnicodeError:
            return False
        if len(pieces) != 2 or pieces[0].lower() != "bearer" or not 32 <= len(pieces[1]) <= 256:
            return False
        request = Request(scope)
        with self.session_factory() as session:
            try:
                current_player(request, HTTPAuthorizationCredentials(scheme="Bearer", credentials=pieces[1]), session)
            except HTTPException as error:
                if error.status_code == 401:
                    return False
                raise
        if scope["method"] not in ("GET", "HEAD"):
            # Revalidate after potentially slow body delivery; budget is already charged.
            scope["state"].pop("authenticated_player", None)
        return True

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        started = time.monotonic()
        request_id = str(uuid.uuid4())
        scope.setdefault("state", {})["request_id"] = request_id
        status = 500
        acquired = False
        wire_bytes, decoded_bytes, response_bytes = 0, 0, 0

        async def response_send(message):
            nonlocal status, response_bytes
            if message["type"] == "http.response.start":
                status = message["status"]
                message["headers"] += [
                    (b"x-request-id", request_id.encode()),
                    (b"x-content-type-options", b"nosniff"),
                ]
                if not any(name.lower() == b"x-server-time" for name, _ in message["headers"]):
                    message["headers"].append((b"x-server-time", str(int(time.time())).encode()))
                if not any(name.lower() == b"cache-control" for name, _ in message["headers"]):
                    message["headers"].append((b"cache-control", b"no-store"))
                if status in (429, 503):
                    message["headers"].append((b"retry-after", b"60" if status == 429 else b"5"))
            elif message["type"] == "http.response.body":
                response_bytes += len(message.get("body",b""))
            await send(message)

        async def error(code, message):
            return await JSONResponse({"detail": message, "request_id": request_id}, status_code=code)(
                scope, receive, response_send
            )

        try:
            method = scope["method"]
            headers = dict(scope["headers"])
            health = scope["path"] in ("/healthz", "/readyz")
            if health and method != "GET":
                return await error(405, "METHOD_NOT_ALLOWED")
            if health and (headers.get(b"content-length", b"0") != b"0" or b"transfer-encoding" in headers):
                return await error(400, "HEALTH_REQUEST_BODY_NOT_ALLOWED")
            token_auth = scope["path"] in ("/v1/auth/google/browser/poll", "/v1/auth/refresh")
            if not health:
                peer = (scope.get("client") or ("unknown", 0))[0]
                method = scope["method"]
                category = (
                    "auth_session" if token_auth else "auth"
                    if scope["path"].startswith("/v1/auth/")
                    else ("read" if method in ("GET", "HEAD") else "write")
                )
                # Carrier NATs share only a generous abuse ceiling. Authenticated
                # players spend their own budget after session validation.
                if b"authorization" in headers and category in ("read", "write"):
                    # A supplied header is not an identity. Public and protected
                    # traffic receive the larger NAT budget only after validation.
                    try:
                        if await run_in_threadpool(self.validated_identity_budget, scope, headers[b"authorization"]):
                            category = "edge"
                    except SQLAlchemyError:
                        return await error(503, "DATABASE_UNAVAILABLE")
                    except HTTPException as denied:
                        return await error(denied.status_code, denied.detail)
                limit = {
                    "auth": self.settings.auth_limit_per_minute,
                    "auth_session": self.settings.rate_limit_per_minute,
                    "read": self.settings.rate_limit_per_minute,
                    "write": self.settings.write_limit_per_minute,
                    "edge": self.settings.edge_limit_per_minute,
                }[category]
                try:
                    allowed = await self.read_budget(peer, limit, category) if category in ("read", "edge") else await run_in_threadpool(check_budget, self.session_factory, peer, category, limit)
                except SQLAlchemyError:
                    return await error(503, "DATABASE_UNAVAILABLE")
                if not allowed:
                    return await error(429, "RATE_LIMITED")
            path = scope["path"]
            limit = min(self.settings.max_body_bytes, 8*1024*1024 if path == "/v1/runs" else
                        600*1024 if path == "/v1/tracks" or path.endswith("/versions") else 32768)
            upload = method in ("POST", "PUT", "PATCH") and limit > 32768
            encoding = headers.get(b"content-encoding", b"identity")
            if encoding not in (b"identity", b"gzip"):
                return await error(415, "UNSUPPORTED_CONTENT_ENCODING")
            if upload:
                try:
                    await asyncio.wait_for(self.parsers.acquire(), timeout=0.1)
                    acquired = True
                except (asyncio.TimeoutError, TimeoutError):
                    return await error(503, "REQUEST_VALIDATION_BUSY")
            inflater = zlib.decompressobj(16 + zlib.MAX_WBITS) if encoding == b"gzip" else None
            length = headers.get(b"content-length")
            if length is not None:
                try:
                    declared = int(length)
                except ValueError:
                    return await error(400, "INVALID_CONTENT_LENGTH")
                if declared < 0 or declared > limit:
                    return await error(413, "PAYLOAD_TOO_LARGE")
            body = bytearray()
            wire_bytes = 0
            try:
                body_deadline = time.monotonic() + 30
                while True:
                    message = await asyncio.wait_for(receive(), max(0, body_deadline - time.monotonic()))
                    if message["type"] == "http.disconnect":
                        return
                    chunk = message.get("body", b"")
                    wire_bytes += len(chunk)
                    if wire_bytes > limit:
                        return await error(413, "PAYLOAD_TOO_LARGE")
                    if inflater is not None:
                        try:
                            chunk = inflater.decompress(chunk, limit-len(body)+1)
                        except zlib.error:
                            return await error(400, "INVALID_GZIP")
                    body.extend(chunk)
                    if health and body:
                        return await error(400, "HEALTH_REQUEST_BODY_NOT_ALLOWED")
                    if len(body) > limit:
                        return await error(413, "PAYLOAD_TOO_LARGE")
                    if not message.get("more_body", False):
                        break
            except (asyncio.TimeoutError, TimeoutError):
                return await error(408, "REQUEST_BODY_TIMEOUT")
            if inflater is not None and (not inflater.eof or inflater.unused_data or inflater.unconsumed_tail):
                return await error(400, "INVALID_GZIP")
            decoded_bytes = len(body)
            if body:
                if headers.get(b"content-type", b"").split(b";")[0].strip().lower() != b"application/json":
                    return await error(415, "JSON_REQUIRED")
                try:
                    parsed = await run_in_threadpool(parse_body, body)
                except (asyncio.TimeoutError, TimeoutError):
                    return await error(503, "REQUEST_VALIDATION_BUSY")
                except (ValueError, RecursionError, UnicodeDecodeError):
                    return await error(400, "INVALID_JSON")
                scope["state"]["bounded_json"] = parsed
                if token_auth:
                    token = parsed.get("token" if scope["path"].endswith("/poll") else "refresh_token", "") if isinstance(parsed, dict) else ""
                    try:
                        allowed = await run_in_threadpool(check_budget, self.session_factory, digest(str(token)), scope["path"], 60)
                    except SQLAlchemyError:
                        return await error(503, "DATABASE_UNAVAILABLE")
                    if not allowed:
                        return await error(429, "RATE_LIMITED")
            sent = False

            async def buffered_receive():
                nonlocal sent
                if not sent:
                    sent = True
                    return {"type": "http.request", "body": bytes(body), "more_body": False}
                return await receive()

            await self.app(scope, buffered_receive, response_send)
        finally:
            # Include Pydantic validation, the endpoint, storage and response
            # serialization: releasing after json.loads did not bound live trees.
            scope.get("state", {}).pop("bounded_json", None)
            if acquired:
                self.parsers.release()
            route = scope.get("route")
            # Template paths only: never log ID tokens, credentials, raw paths or query strings.
            log.info(
                json.dumps(
                    {
                        "event": "http_request",
                        "request_id": request_id,
                        "method": scope["method"],
                        "route": getattr(route, "path", "unmatched"),
                        "status": status,
                        "duration_ms": round((time.monotonic() - started) * 1000, 2),
                        "request_wire_bytes":wire_bytes,
                        "request_decoded_bytes":decoded_bytes,
                        "response_wire_bytes":response_bytes,
                    }
                )
            )
