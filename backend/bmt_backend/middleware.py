"""Bound requests before parsing; share rate budgets across API replicas."""

import json
import logging
import math
import time
import uuid

from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool
from starlette.responses import JSONResponse

from .identity_models import RateBucket
from .security import digest

log = logging.getLogger("bmt.requests")


def check_budget(factory, peer: str, category: str, limit: int) -> bool:
    current = int(time.time())
    key = digest(f"{peer}:{category}:{current // 60}")
    with factory() as session:
        insert = sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert
        statement = insert(RateBucket).values(key=key, count=1, expires_at=current + 120)
        statement = statement.on_conflict_do_update(
            index_elements=[RateBucket.key],
            set_={"count": RateBucket.count + 1},
            where=RateBucket.count < limit,
        ).returning(RateBucket.count)
        value = session.scalar(statement)
        session.commit()
        return value is not None


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


class RequestBoundary:
    def __init__(self, app, settings, session_factory):
        self.app, self.settings, self.session_factory = app, settings, session_factory

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        started = time.monotonic()
        request_id = str(uuid.uuid4())
        scope.setdefault("state", {})["request_id"] = request_id
        status = 500

        async def response_send(message):
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
                message["headers"] += [
                    (b"x-request-id", request_id.encode()),
                    (b"x-content-type-options", b"nosniff"),
                    (b"cache-control", b"no-store"),
                ]
            await send(message)

        async def error(code, message):
            return await JSONResponse({"detail": message, "request_id": request_id}, status_code=code)(
                scope, receive, response_send
            )

        try:
            if scope["path"] not in ("/healthz", "/readyz"):
                peer = (scope.get("client") or ("unknown", 0))[0]
                method = scope["method"]
                category = (
                    "auth"
                    if scope["path"].startswith("/v1/auth/")
                    else ("read" if method in ("GET", "HEAD") else "write")
                )
                limit = {
                    "auth": self.settings.auth_limit_per_minute,
                    "read": self.settings.rate_limit_per_minute,
                    "write": self.settings.write_limit_per_minute,
                }[category]
                try:
                    allowed = await run_in_threadpool(
                        check_budget, self.session_factory, peer, category, limit
                    )
                except SQLAlchemyError:
                    return await error(503, "DATABASE_UNAVAILABLE")
                if not allowed:
                    return await error(429, "RATE_LIMITED")
            headers = dict(scope["headers"])
            limit = (
                min(32768, self.settings.max_body_bytes)
                if scope["path"].startswith("/v1/auth/")
                else self.settings.max_body_bytes
            )
            if headers.get(b"content-encoding", b"identity") != b"identity":
                return await error(415, "COMPRESSED_REQUESTS_NOT_SUPPORTED")
            length = headers.get(b"content-length")
            if length is not None:
                try:
                    declared = int(length)
                except ValueError:
                    return await error(400, "INVALID_CONTENT_LENGTH")
                if declared < 0 or declared > limit:
                    return await error(413, "PAYLOAD_TOO_LARGE")
            body = bytearray()
            while True:
                message = await receive()
                if message["type"] == "http.disconnect":
                    return
                body.extend(message.get("body", b""))
                if len(body) > limit:
                    return await error(413, "PAYLOAD_TOO_LARGE")
                if not message.get("more_body", False):
                    break
            if body:
                if headers.get(b"content-type", b"").split(b";")[0].strip().lower() != b"application/json":
                    return await error(415, "JSON_REQUIRED")
                try:
                    parsed = json.loads(body, object_pairs_hook=strict_object, parse_constant=reject_constant)
                    pending = [(parsed, 0)]
                    while pending:
                        value, depth = pending.pop()
                        if depth > 32:
                            raise ValueError("JSON nesting limit")
                        if isinstance(value, dict):
                            pending.extend((v, depth + 1) for v in value.values())
                        elif isinstance(value, list):
                            pending.extend((v, depth + 1) for v in value)
                        elif isinstance(value, float) and not math.isfinite(value):
                            raise ValueError("Nonfinite JSON number")
                        elif isinstance(value, str):
                            value.encode("utf-8")
                except (ValueError, RecursionError, UnicodeDecodeError):
                    return await error(400, "INVALID_JSON")
                # FastAPI parses the bounded bytes for its typed request model next.
                # Release this validation tree before retaining another decoded replay.
                del parsed, pending, value
            sent = False

            async def buffered_receive():
                nonlocal sent
                if not sent:
                    sent = True
                    return {"type": "http.request", "body": bytes(body), "more_body": False}
                return await receive()

            await self.app(scope, buffered_receive, response_send)
        finally:
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
                    }
                )
            )
