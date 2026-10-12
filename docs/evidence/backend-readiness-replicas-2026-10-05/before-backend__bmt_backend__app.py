from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool
from starlette.middleware.gzip import GZipMiddleware

from . import auth
from .config import Settings
from .db import make_engine, make_session_factory
from .middleware import IdentityBudgets, RequestBoundary
from .migrate import SCHEMA_HEAD
from .observability import configure_logging
from .security import GoogleIdentityVerifier
from .storage import make_blob_store


def create_app(settings: Settings | None = None, *, engine=None, verifier=None, identity_verifier=None):
    from . import admin, browser_auth, resumes, rivalry, runs, test_drivers, tracks
    from .verifier import GodotVerifier

    settings = settings or Settings.from_env()
    configure_logging()
    @asynccontextmanager
    async def lifespan(application):
        # Warm the pinned, immutable contract before accepting concurrent races.
        # Auth-only isolated tests may omit an engine; deployed APIs configure it.
        adapter = application.state.verifier
        if isinstance(adapter, GodotVerifier) and settings.godot_bin:
            await run_in_threadpool(adapter.manifest)
        try:
            yield
        finally:
            if hasattr(adapter, "close"):
                await run_in_threadpool(adapter.close)

    app = FastAPI(title="Beat my track API", version="0.1.0", docs_url="/docs", redoc_url=None, lifespan=lifespan)
    app.state.settings = settings
    app.state.engine = engine if engine is not None else make_engine(settings.database_url, settings)
    app.state.session_factory = make_session_factory(app.state.engine)
    app.state.identity_budgets = IdentityBudgets(app.state.session_factory)
    app.state.blobs = make_blob_store(settings, app.state.session_factory)
    app.state.verifier = verifier if verifier is not None else GodotVerifier(settings)
    app.state.identity_verifier = identity_verifier or GoogleIdentityVerifier(settings.google_client_ids)
    app.add_middleware(GZipMiddleware, minimum_size=1024, compresslevel=3)
    app.add_middleware(RequestBoundary, settings=settings, session_factory=app.state.session_factory)
    app.include_router(admin.router)
    app.include_router(auth.router, prefix="/v1")
    app.include_router(browser_auth.router, prefix="/v1")
    app.include_router(tracks.router, prefix="/v1")
    app.include_router(runs.router, prefix="/v1")
    app.include_router(resumes.router, prefix="/v1")
    app.include_router(rivalry.router, prefix="/v1")
    app.include_router(test_drivers.router, prefix="/v1")

    @app.exception_handler(RequestValidationError)
    async def invalid_request(request: Request, _error):
        # Pydantic error details contain input values, including authentication credentials.
        return JSONResponse(
            {"detail": "INVALID_INPUT", "request_id": request.state.request_id}, status_code=422
        )

    @app.exception_handler(SQLAlchemyError)
    async def unavailable(request: Request, _error):
        return JSONResponse(
            {"detail": "DATABASE_UNAVAILABLE", "request_id": request.state.request_id}, status_code=503
        )

    @app.exception_handler(OSError)
    async def storage_unavailable(request: Request, _error):
        return JSONResponse({"detail":"STORAGE_UNAVAILABLE","request_id":request.state.request_id},status_code=503)

    @app.get("/healthz", tags=["operations"])
    def health():
        return {"status": "ok"}

    @app.get("/readyz", tags=["operations"])
    def ready():
        try:
            with app.state.engine.connect() as connection:
                revision = connection.execute(text("SELECT version_num FROM alembic_version")).scalar()
                if revision != SCHEMA_HEAD:
                    raise HTTPException(503, "SCHEMA_NOT_READY")
            app.state.blobs.get_json(app.state.blobs.put_json({"storage_probe": "bmt-v1"}))
        except (SQLAlchemyError, OSError) as exc:
            raise HTTPException(503, "DEPENDENCY_UNAVAILABLE") from exc
        return {"status": "ready", "schema": revision}

    @app.get("/v1/bootstrap", tags=["compatibility"])
    def bootstrap():
        return {
            "service": "beat-my-track",
            "api_version": "v1",
            "auth": "google",
            "google_configured": bool(settings.google_client_ids),
            "google_browser_configured": bool(settings.google_web_client_id),
            "development_auth": settings.dev_auth_enabled,
            "test_drivers": settings.test_drivers_enabled,
            "track_schema": "creator-track-v5",
            "replay_schema": "bmt-replay-v1",
            "supported_replay_schemas": ["bmt-replay-v1", "bmt-replay-v2"],
            "rewind_policy": "rewind-1",
            "verification": "canonical-replay",
            "track_lifecycle_version": 1,
            "max_request_bytes": settings.max_body_bytes,
            "upload_encodings": ["identity", "gzip"],
            "replay_wire_schema": "bmt-packed-input-v1",
            "batch_run_status": True,
            "idempotency_key_schema": "v2.timestamp.random",
            "idempotency_retry_days": 90,
        }

    return app
