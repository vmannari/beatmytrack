"""Bound requests before parsing; share rate budgets across API replicas."""

import asyncio
import hashlib
import json
import logging
import threading
import time
import uuid
import zlib
from collections import OrderedDict
from contextlib import AsyncExitStack, nullcontext
from functools import lru_cache

from fastapi import HTTPException
from fastapi.dependencies.utils import get_dependant, solve_dependencies
from fastapi.routing import APIRoute, iter_route_contexts
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool
from starlette.responses import JSONResponse
from starlette.routing import compile_path, get_route_path

from .client_address import ClientAddress
from .identity_models import RateBucket
from .json_data import parse_json as parse_body
from .observability import dependency_failure
from .security import digest

log = logging.getLogger("bmt.requests")


@lru_cache(maxsize=512)
def _template_pattern(path):
    return compile_path(path)[0]


async def upload_identity(scope):
    """Use the same authentication dependency, including explicit test overrides."""
    from fastapi import Depends, Request

    from .security import current_player

    def required(player=Depends(current_player)):
        return player

    async with AsyncExitStack() as stack:
        names = ("fastapi_inner_astack", "fastapi_function_astack")
        previous = {name: scope.get(name) for name in names}
        scope.update({name: stack for name in names})
        try:
            solved = await solve_dependencies(request=Request(scope),
                dependant=get_dependant(path=scope["path"], call=required),
                dependency_overrides_provider=scope["app"], async_exit_stack=stack, embed_body_fields=False)
            if solved.errors:
                raise HTTPException(401, "AUTH_REQUIRED")
        finally:
            for name, value in previous.items():
                if value is None:
                    scope.pop(name, None)
                else:
                    scope[name] = value
    # The endpoint rechecks revocation after body delivery without charging twice.
    scope["state"].pop("authenticated_player", None)


def requires_player(dependant):
    from .security import current_player
    return dependant.call is current_player or any(requires_player(child) for child in dependant.dependencies)


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
        self.telemetry_parsers = asyncio.Semaphore(1)
        self.discovery_parsers = asyncio.Semaphore(1)
        self.read_leases = OrderedDict()
        self.denied_peers = OrderedDict()
        self.denied_credentials = OrderedDict()
        # Admission hints only. Every authenticated request still checks the
        # database, revocation, expiry and its own player's budget.
        self.known_credentials = OrderedDict()
        self.client_address = ClientAddress(settings.trusted_proxy_networks)

    @staticmethod
    def route_context(scope):
        """Resolve only a declared template, including rejection before routing."""
        router = getattr(scope.get("app"), "router", None)
        partial = ("unmatched", None)
        path = get_route_path(scope)
        # FastAPI's effective contexts retain prefixes through included/nested
        # routers. Original APIRoute.path omits those prefixes in this version.
        for context in iter_route_contexts(getattr(router, "routes", ())):
            template = context.path
            if template is None or _template_pattern(template).match(path) is None:
                continue
            methods = getattr(context.original_route, "methods", None)
            if not methods or scope["method"] in methods:
                return template, context.original_route
            if partial[1] is None:
                partial = template, context.original_route
        return partial

    @staticmethod
    def route_template(scope):
        return RequestBoundary.route_context(scope)[0]

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
            if remaining < 0:
                return False
            if not remaining:
                batch = min(10, limit)
                if not await run_in_threadpool(check_budget, self.session_factory, peer, category, limit, batch):
                    lease[0] = -1
                    return False
                remaining = batch
            lease[0] = remaining - 1
            return True

    async def peer_budget(self, peer, category, limit):
        key = (peer, category, int(time.time()) // 60)
        if key in self.denied_peers:
            return False
        if category in ("read", "edge"):
            allowed = await self.read_budget(peer, limit, category)
        else:
            allowed = await run_in_threadpool(check_budget, self.session_factory, peer, category, limit)
        if not allowed:
            self.denied_peers[key] = True
            self.denied_peers.move_to_end(key)
            while len(self.denied_peers) > 4096:
                self.denied_peers.popitem(last=False)
        return allowed

    def known_credential(self, key):
        if self.known_credentials.get(key, 0) <= time.monotonic():
            self.known_credentials.pop(key, None)
            return False
        self.known_credentials.move_to_end(key)
        return True

    def remember_credential(self, key):
        self.known_credentials[key] = time.monotonic() + 60
        self.known_credentials.move_to_end(key)
        while len(self.known_credentials) > 4096:
            self.known_credentials.popitem(last=False)

    def deny_credential(self, key):
        self.denied_credentials[key] = True
        self.denied_credentials.move_to_end(key)
        while len(self.denied_credentials) > 4096:
            self.denied_credentials.popitem(last=False)

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
                player = current_player(request, HTTPAuthorizationCredentials(scheme="Bearer", credentials=pieces[1]), session)
                request.state.budget_player_id = player.id
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
        response_started = False
        acquired = False
        acquired_pool = None
        identity_admitted = False
        wire_bytes, decoded_bytes, response_bytes = 0, 0, 0

        async def response_send(message):
            nonlocal status, response_bytes, response_started
            if message["type"] == "http.response.start":
                response_started = True
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

        async def error(code, message, headers=None):
            return await JSONResponse({"detail": message, "request_id": request_id}, status_code=code, headers=headers)(
                scope, receive, response_send
            )

        async def database_error(exc):
            dependency_failure(log, exc, request_id, "database")
            probe = getattr(getattr(scope.get("app"), "state", None), "readiness", None)
            if probe is not None:
                probe.invalidate()
            return await error(503, "DATABASE_UNAVAILABLE")

        try:
            method = scope["method"]
            headers = dict(scope["headers"])
            health = scope["path"] in ("/health", "/ready", "/healthz", "/readyz")
            if health and method != "GET":
                return await error(405, "METHOD_NOT_ALLOWED")
            if health and (headers.get(b"content-length", b"0") != b"0" or b"transfer-encoding" in headers):
                return await error(400, "HEALTH_REQUEST_BODY_NOT_ALLOWED")
            token_auth = scope["path"] in ("/v1/auth/google/browser/poll", "/v1/auth/refresh")
            if not health:
                peer = self.client_address.resolve(scope)
                method = scope["method"]
                category = (
                    "auth_session" if token_auth else "auth"
                    if scope["path"].startswith("/v1/auth/")
                    else ("read" if method in ("GET", "HEAD") or scope["path"] in ("/v1/discovery/tracks", "/v1/discovery/random") else "write")
                )
                credential_key = hashlib.sha256(headers.get(b"authorization", b"")).hexdigest()
                provided = b"authorization" in headers and category in ("read", "write")
                denial_key = (peer, credential_key, category, int(time.time()) // 60)
                if provided and denial_key in self.denied_credentials:
                    return await error(429, "RATE_LIMITED")
                # The independent ingress/cold-credential gates run before SQL.
                # A cold VALID user must not inherit an exhausted anonymous quota
                # from a different caller behind the same carrier NAT.
                admission = "edge" if provided else category
                limit = {"auth": self.settings.auth_limit_per_minute,
                         "auth_session": self.settings.rate_limit_per_minute,
                         "read": self.settings.rate_limit_per_minute,
                         "write": self.settings.write_limit_per_minute,
                         "edge": self.settings.edge_limit_per_minute}[admission]
                try:
                    if not await self.peer_budget(peer, admission, limit):
                        return await error(429, "RATE_LIMITED")
                    if (provided and not self.known_credential(credential_key)
                            and not await self.peer_budget(peer, "credential_admission", self.settings.pre_auth_limit_per_minute)):
                        return await error(429, "RATE_LIMITED")
                except SQLAlchemyError as exc:
                    return await database_error(exc)
                if provided:
                    try:
                        if await run_in_threadpool(self.validated_identity_budget, scope, headers[b"authorization"]):
                            identity_admitted = True
                            self.remember_credential(credential_key)
                        else:
                            self.known_credentials.pop(credential_key, None)
                            anonymous_limit = self.settings.rate_limit_per_minute if category == "read" else self.settings.write_limit_per_minute
                            if not await self.peer_budget(peer, category, anonymous_limit):
                                self.deny_credential(denial_key)
                                return await error(429, "RATE_LIMITED")
                    except SQLAlchemyError as exc:
                        return await database_error(exc)
                    except HTTPException as denied:
                        # Keep a valid credential's NAT admission when only its
                        # player budget is exhausted; never cache it as an auth grant.
                        if denied.status_code == 429:
                            self.remember_credential(credential_key)
                        else:
                            self.known_credentials.pop(credential_key, None)
                        return await error(denied.status_code, denied.detail)
            path = scope["path"]
            _template, route = self.route_context(scope)
            if route is not None and route.methods and method not in route.methods:
                return await error(405, "METHOD_NOT_ALLOWED", {"Allow": ", ".join(sorted(route.methods))})
            # Small control writes historically send {} even without a Body
            # parameter. Unknown routes retain only that small allowance.
            body_allowed = ((isinstance(route, APIRoute) and route.body_field is not None)
                            or method in ("POST", "PUT", "PATCH", "DELETE"))
            limit = min(self.settings.max_body_bytes, 32768 if route is None and scope.get("app") is not None else
                        64*1024 if path == "/v1/telemetry/batches" else
                        8*1024*1024 if path in ("/v1/runs", "/v1/publications", "/v1/discovery/tracks", "/v1/discovery/random") else
                        600*1024 if path == "/v1/tracks" or path.endswith("/versions") else 32768)
            upload = body_allowed and limit > 32768
            length = headers.get(b"content-length")
            if length is not None:
                try:
                    declared = int(length)
                except ValueError:
                    return await error(400, "INVALID_CONTENT_LENGTH")
                if declared < 0 or declared > limit:
                    return await error(413, "PAYLOAD_TOO_LARGE")
                if declared and not body_allowed:
                    return await error(400, "REQUEST_BODY_NOT_ALLOWED")
            if not body_allowed and b"transfer-encoding" in headers:
                return await error(400, "REQUEST_BODY_NOT_ALLOWED")
            if upload and isinstance(route, APIRoute) and requires_player(route.dependant):
                if not identity_admitted:
                    try:
                        await upload_identity(scope)
                    except SQLAlchemyError as exc:
                        return await database_error(exc)
                    except HTTPException as denied:
                        return await error(denied.status_code, denied.detail, denied.headers)
                scope["state"].pop("authenticated_player", None)
            encoding = headers.get(b"content-encoding", b"identity")
            if encoding not in (b"identity", b"gzip"):
                return await error(415, "UNSUPPORTED_CONTENT_ENCODING")
            if upload:
                try:
                    acquired_pool = (self.telemetry_parsers if path == "/v1/telemetry/batches" else
                                     self.discovery_parsers if path in ("/v1/discovery/tracks", "/v1/discovery/random")
                                     else self.parsers)
                    await asyncio.wait_for(acquired_pool.acquire(), timeout=0.1)
                    acquired = True
                except (asyncio.TimeoutError, TimeoutError):
                    return await error(503, "REQUEST_VALIDATION_BUSY")
            inflater = zlib.decompressobj(16 + zlib.MAX_WBITS) if encoding == b"gzip" else None
            body = bytearray()
            wire_bytes = 0
            try:
                body_deadline = time.monotonic() + 30
                while True:
                    message = await asyncio.wait_for(receive(), max(0, body_deadline - time.monotonic()))
                    if message["type"] == "http.disconnect":
                        return
                    chunk = message.get("body", b"")
                    if chunk and not body_allowed:
                        return await error(400, "REQUEST_BODY_NOT_ALLOWED")
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
                    except SQLAlchemyError as exc:
                        return await database_error(exc)
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
        except Exception as exc:
            # Exception text/traceback can contain credentials or submitted
            # values. The structured logger keeps only its type and request ID.
            log.error("request_failed", extra={"request_id": request_id, "exception_type": type(exc).__name__})
            if response_started:
                raise
            return await error(500, "INTERNAL_ERROR")
        finally:
            # Include Pydantic validation, the endpoint, storage and response
            # serialization: releasing after json.loads did not bound live trees.
            scope.get("state", {}).pop("bounded_json", None)
            if acquired:
                acquired_pool.release()
            # Template paths only: never log ID tokens, credentials, raw paths or query strings.
            log.info(
                json.dumps(
                    {
                        "event": "http_request",
                        "request_id": request_id,
                        "method": scope["method"],
                        "route": self.route_template(scope),
                        "status": status,
                        "duration_ms": round((time.monotonic() - started) * 1000, 2),
                        "request_wire_bytes":wire_bytes,
                        "request_decoded_bytes":decoded_bytes,
                        "response_wire_bytes":response_bytes,
                    }
                )
            )
