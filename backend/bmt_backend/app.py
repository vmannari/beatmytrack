from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from . import auth
from .config import Settings
from .db import make_engine, make_session_factory
from .middleware import RequestBoundary
from .observability import configure_logging
from .security import GoogleIdentityVerifier
from .storage import LocalBlobStore


def create_app(settings: Settings | None = None, *, engine=None, verifier=None, identity_verifier=None):
    from . import admin, browser_auth, resumes, runs, tracks
    from .verifier import GodotVerifier

    settings = settings or Settings.from_env()
    configure_logging()
    app = FastAPI(title="Beat my track API", version="0.1.0", docs_url="/docs", redoc_url=None)
    app.state.settings = settings
    app.state.engine = engine if engine is not None else make_engine(settings.database_url)
    app.state.session_factory = make_session_factory(app.state.engine)
    app.state.blobs = LocalBlobStore(settings.object_dir)
    app.state.verifier = verifier if verifier is not None else GodotVerifier(settings)
    app.state.identity_verifier = identity_verifier or GoogleIdentityVerifier(settings.google_client_ids)
    app.add_middleware(RequestBoundary, settings=settings, session_factory=app.state.session_factory)
    app.include_router(admin.router)
    app.include_router(auth.router, prefix="/v1")
    app.include_router(browser_auth.router, prefix="/v1")
    app.include_router(tracks.router, prefix="/v1")
    app.include_router(runs.router, prefix="/v1")
    app.include_router(resumes.router, prefix="/v1")

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

    @app.get("/healthz", tags=["operations"])
    def health():
        return {"status": "ok"}

    @app.get("/readyz", tags=["operations"])
    def ready():
        try:
            with app.state.engine.connect() as connection:
                revision = connection.execute(text("SELECT version_num FROM alembic_version")).scalar()
                if revision != "0007_admin_audit":
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
            "track_schema": "creator-track-v5",
            "replay_schema": "bmt-replay-v1",
            "supported_replay_schemas": ["bmt-replay-v1", "bmt-replay-v2"],
            "rewind_policy": "rewind-1",
            "verification": "canonical-replay",
            "max_request_bytes": settings.max_body_bytes,
        }

    return app
