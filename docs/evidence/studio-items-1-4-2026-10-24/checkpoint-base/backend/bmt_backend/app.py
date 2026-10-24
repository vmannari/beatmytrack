import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError
from starlette.concurrency import run_in_threadpool
from starlette.middleware.gzip import GZipMiddleware

from . import auth
from .config import Settings
from .db import make_engine, make_session_factory
from .middleware import IdentityBudgets, RequestBoundary
from .observability import configure_logging, dependency_failure
from .readiness import DependencyFailure, ReadinessProbe
from .security import GoogleIdentityVerifier
from .storage import make_blob_store


def create_app(settings: Settings | None = None, *, engine=None, verifier=None, identity_verifier=None,
               analysis_engine=None):
    from . import (
        achievements,
        admin,
        admin_commerce,
        admin_player_grants,
        admin_purchase_controls,
        admin_support,
        appearance_routes,
        browser_auth,
        challenges,
        commerce,
        community,
        discovery,
        discovery_v3,
        economy,
        game_config,
        network_health,
        news,
        privacy,
        privacy_pages,
        product_analytics,
        publications,
        quality,
        race_statistics,
        resumes,
        rivalry,
        runs,
        studio,
        studio_alarms,
        studio_analysis,
        studio_cases,
        studio_catalogue,
        studio_competitions,
        studio_experiments,
        studio_finance,
        studio_governance,
        studio_incidents,
        studio_jobs,
        studio_metrics,
        studio_rivalry,
        telemetry,
        test_drivers,
        test_population_batch,
        track_links,
        tracks,
        world_ranking,
    )
    from .verifier import GodotVerifier

    settings = settings or Settings.from_env()
    configure_logging()
    @asynccontextmanager
    async def lifespan(application):
        application.state.readiness.open()
        application.state.run_signals.open()
        # Warm the pinned, immutable contract before accepting concurrent races.
        # Auth-only isolated tests may omit an engine; deployed APIs configure it.
        adapter = application.state.verifier
        try:
            if isinstance(adapter, GodotVerifier) and settings.godot_bin:
                await run_in_threadpool(adapter.manifest)
            yield
        finally:
            await run_in_threadpool(application.state.studio_reporting.close)
            await run_in_threadpool(application.state.run_signals.close)
            try:
                await application.state.readiness.close()
            finally:
                try:
                    if hasattr(application.state.blobs, "close"):
                        await run_in_threadpool(application.state.blobs.close)
                finally:
                    try:
                        if hasattr(application.state.erasure_journal, "close"):
                            await run_in_threadpool(application.state.erasure_journal.close)
                    finally:
                        if hasattr(adapter, "close"):
                            await run_in_threadpool(adapter.close)

    app = FastAPI(title="Beat my track API", version="0.1.0", docs_url="/docs", redoc_url=None, lifespan=lifespan)
    app.state.settings = settings
    app.state.engine = engine if engine is not None else make_engine(settings.database_url, settings)
    from .database_privileges import verify_runtime
    verify_runtime(app.state.engine,settings)
    app.state.session_factory = make_session_factory(app.state.engine)
    from .studio_reporting import StudioReporting
    app.state.studio_reporting = StudioReporting(settings, engine=analysis_engine)
    from .run_signals import RunSignals
    app.state.run_signals = RunSignals(app.state.engine, capacity=settings.run_wait_capacity)
    app.state.engine._bmt_run_signals = app.state.run_signals
    app.state.identity_budgets = IdentityBudgets(app.state.session_factory)
    app.state.blobs = make_blob_store(settings, app.state.session_factory)
    from .erasure_journal import make_journal
    app.state.erasure_journal = make_journal(settings)
    app.state.verifier = verifier if verifier is not None else GodotVerifier(settings)
    app.state.identity_verifier = identity_verifier or GoogleIdentityVerifier(settings.google_client_ids)
    app.state.staff_identity_verifier = GoogleIdentityVerifier(settings.studio_staff_audiences)
    app.state.readiness = ReadinessProbe(app)
    app.state.worker_heartbeat_memory = __import__("collections").OrderedDict()
    app.state.worker_heartbeat_lock = __import__("threading").RLock()
    app.add_middleware(GZipMiddleware, minimum_size=1024, compresslevel=3)
    app.add_middleware(RequestBoundary, settings=settings, session_factory=app.state.session_factory)
    from .workloads import administration_enabled
    if administration_enabled(settings):
        app.include_router(admin.router)
        app.include_router(admin_commerce.router)
        app.include_router(admin_purchase_controls.router)
        app.include_router(admin_player_grants.router)
        app.include_router(admin_support.router)
        app.include_router(studio.router)
        app.include_router(studio_analysis.router)
        app.include_router(studio_metrics.router)
        app.include_router(studio_jobs.router)
        app.include_router(studio_incidents.router)
        app.include_router(studio_finance.router)
        app.include_router(studio_experiments.router)
        app.include_router(game_config.router)
        app.include_router(studio_governance.router)
        app.include_router(studio_alarms.router)
        app.include_router(studio_cases.router)
        app.include_router(studio_competitions.router)
        app.include_router(studio_rivalry.router)
        app.include_router(studio_catalogue.router)
        app.include_router(publications.admin_router, prefix="/v1")
    app.state.discovery_memory = __import__("collections").OrderedDict()
    app.state.discovery_lock = __import__("threading").RLock()
    if settings.workload_role != "admin":
        app.include_router(game_config.public_router)
        app.include_router(telemetry.router)
        app.include_router(community.router)
        app.include_router(privacy.router)
        app.include_router(privacy_pages.router)
        app.include_router(product_analytics.router)
        app.include_router(quality.router)
        app.include_router(network_health.router)
        app.include_router(news.router, prefix="/v1")
        app.include_router(race_statistics.router)
        app.include_router(auth.router, prefix="/v1")
        app.include_router(browser_auth.router, prefix="/v1")
        app.include_router(tracks.router, prefix="/v1")
        app.include_router(discovery.router, prefix="/v1")
        app.include_router(discovery_v3.router)
        app.include_router(runs.router, prefix="/v1")
        app.include_router(economy.router, prefix="/v1")
        app.include_router(achievements.router, prefix="/v1")
        app.include_router(resumes.router, prefix="/v1")
        app.include_router(commerce.router, prefix="/v1")
        app.include_router(publications.router, prefix="/v1")
        app.include_router(rivalry.router, prefix="/v1")
        app.include_router(appearance_routes.router, prefix="/v1")
        app.include_router(challenges.router, prefix="/v1")
        app.include_router(world_ranking.router)
        app.include_router(challenges.preview_router)
        app.include_router(track_links.router)
        app.include_router(test_drivers.router, prefix="/v1")
        app.include_router(test_population_batch.router, prefix="/v1")

    @app.exception_handler(RequestValidationError)
    async def invalid_request(request: Request, _error):
        # Pydantic error details contain input values, including authentication credentials.
        return JSONResponse(
            {"detail": "INVALID_INPUT", "request_id": request.state.request_id}, status_code=422
        )

    @app.exception_handler(SQLAlchemyError)
    async def unavailable(request: Request, _error):
        from .queueing import capacity_error
        if capacity_error(_error):
            return JSONResponse({"detail": "Verification capacity reached; retry this saved attempt later",
                                 "request_id": request.state.request_id}, status_code=429)
        dependency_failure(logging.getLogger("bmt.api"), _error, request.state.request_id, "database")
        app.state.readiness.invalidate()
        return JSONResponse(
            {"detail": "DATABASE_UNAVAILABLE", "request_id": request.state.request_id}, status_code=503
        )

    @app.exception_handler(OSError)
    async def storage_unavailable(request: Request, _error):
        dependency_failure(logging.getLogger("bmt.api"), _error, request.state.request_id, "storage")
        app.state.readiness.invalidate(storage=True)
        return JSONResponse({"detail":"STORAGE_UNAVAILABLE","request_id":request.state.request_id},status_code=503)

    # Cloud Run reserves some paths ending in z at its public frontend.
    @app.get("/health", tags=["operations"])
    @app.get("/healthz", tags=["operations"], include_in_schema=False)
    async def health():
        return {"status": "ok"}

    @app.get("/ready", tags=["operations"])
    @app.get("/readyz", tags=["operations"], include_in_schema=False)
    async def ready():
        try:
            return await app.state.readiness.check()
        except DependencyFailure as error:
            raise HTTPException(503, error.code) from None

    @app.get("/v1/bootstrap", tags=["compatibility"])
    def bootstrap():
        return {
            "service": "beat-my-track",
            "api_version": "v1",
            "game_configuration_version": 1,
            "garage_news_version": 1,
            "auth": "google",
            "privacy": {"schema_version": 1, "policy_url": settings.public_base_url.rstrip("/") + "/privacy",
                "deletion_url": settings.public_base_url.rstrip("/") + "/account-deletion",
                "policy_version": "bmt-privacy-v1", "tracks_retained": True, "standings_retained": True},
            "community_safety_version": 1,
            "community_terms_version": community.TERMS_VERSION,
            "community_rules_url": settings.public_base_url.rstrip("/") + "/community-rules",
            "google_configured": bool(settings.google_client_ids),
            "google_browser_configured": bool(settings.google_web_client_id),
            "development_auth": settings.dev_auth_enabled,
            "test_drivers": settings.test_drivers_enabled,
            "test_driver_upload_recovery": settings.test_drivers_enabled,
            "purchase_simulation": settings.purchase_simulation_enabled,
            "entitlements_version": 1,
            "store_catalog_version": 1,
            "admin_console_configured": administration_enabled(settings) and bool(
                settings.studio_staff_audiences or settings.admin_owner_key or settings.admin_analyst_key),
            "product_telemetry": {
                "enabled": getattr(settings, "telemetry_enabled", False),
                "schema_version": 1,
                "max_events": 50,
                "max_batch_bytes": 65536,
                "flush_seconds": 60,
                "idle_flush_seconds": 300,
                "response_limit_bytes": 16384,
                "guest_coverage": False,
                "quality_schema_version": 2 if settings.client_quality_enabled else 0,
                "quality_schema_versions": [2, 3] if settings.client_quality_enabled else [],
                "network_schema_version": 1 if settings.client_quality_enabled else 0,
            },
            "track_schema": "creator-track-v5",
            "publication_workflow_version": 2,
            "local_drafts_only": settings.local_drafts_only,
            "replay_schema": "bmt-replay-v1",
            "supported_replay_schemas": ["bmt-replay-v1", "bmt-replay-v2", "bmt-trajectory-v1"],
            "trajectory_schema": "bmt-trajectory-v1",
            "rewind_policy": "rewind-1",
            "verification": "trajectory-v1",
            "trajectory_verification": True,
            "submission_recovery_version": 1,
            "race_incident_rewards_version": 1,
            "challenge_discovery_version": 1,
            "challenge_series_version": 1,
            "world_ranking_version": 1, "world_ranking_launch_week": settings.world_ranking_launch_week,
            "lightweight_race_proofs": True,
            "track_lifecycle_version": 1,
            "discovery_paging_version": 3,
            "max_request_bytes": settings.max_body_bytes,
            "upload_encodings": ["identity", "gzip"],
            "replay_wire_schema": "bmt-packed-input-v1",
            "batch_run_status": True,
            "run_wait_ms": 2000,
            "refresh_recovery_seconds": settings.refresh_recovery_seconds,
            "resume_recovery": True,
            "server_now": __import__("time").time_ns() // 1_000_000_000,
            "idempotency_key_schema": "v2.timestamp.random",
            "idempotency_retry_days": 90,
        }

    return app


def create_admin_app():
    """Bind only on a private/IAM-protected listener with dedicated credentials."""
    settings = Settings.from_env()
    if settings.workload_role != "admin":
        raise ValueError("Administrative factory requires BMT_WORKLOAD_ROLE=admin")
    if settings.environment == "production" and not settings.studio_staff_audiences:
        raise ValueError("Administrative service requires configured named staff sign-in")
    return create_app(settings)
