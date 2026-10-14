"""Read-only Studio coverage and bounded evidence from authoritative race records."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import func, select, text

from .admin import Access, Window
from .admin_ranges import calendar_range
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .resume_models import ResumeRace, ResumeReceipt
from .runs import PINNED_FIELDS
from .track_models import Board, PersonalBest, Run, RunTicket, TrackVersion, digest, now

router = APIRouter(route_class=ParsedJSONRoute, tags=["administration"])
RECEIPT_LIMIT = 100
MANIFEST_FIELDS = (*PINNED_FIELDS, "track_content_hash", "vehicle_id", "handling_version", "config_hash", "purpose")
SOURCES = (
    ("race_evidence", "Race evidence", "supported", "Server tickets, submitted results, terminal verification outcomes and pinned contracts.", ["BMT-003", "BMT-034"]),
    ("track_versions", "Immutable track versions", "supported", "Stored version identity, content hash, car and rules; published content remains immutable.", ["BMT-030"]),
    ("player_support", "Player support", "partial", "Account state, purchases, entitlements, resumes and submitted-race history; no client play-session timeline.", ["BMT-050", "BMT-051"]),
    ("race_bundle", "Race evidence bundle", "partial", "Checksummed JSON snapshot of redacted server records; no full replay, client diagnostics or expiring hosted bundle.", ["BMT-052"]),
    ("competition_health", "Verification health", "supported", "Current worker compatibility, queue age, recent server outcomes and configured backup marker.", ["BMT-071", "BMT-074"]),
    ("operational_counts", "Operational counts", "supported", "Registered accounts and received submissions by UTC window; these are not foreground activity or retention.", ["BMT-020"]),
    ("behaviour", "Observed product activity", "partial", "Prepared signed-in activity, ordered first-race and creator cohorts, exact-day retention and observed selections. Guest coverage and historical pre-collection activity are unavailable.", ["BMT-010", "BMT-013", "BMT-022", "BMT-023"]),
    ("client_quality", "Client quality", "unavailable", "No backend crash, ANR, build/device frame summaries or Play vitals feed.", ["BMT-070"]),
    ("provider_commerce", "Verified provider commerce", "unavailable", "Development purchases exist; live Play verification, signed ad rewards, revenue and reconciliation feeds are not configured.", ["BMT-040", "BMT-041", "BMT-043", "BMT-048"]),
    ("remote_config", "Remote configuration and experiments", "unavailable", "Pinned race manifests exist; no mutable configuration registry, activation, exposure or rollback service.", ["BMT-060", "BMT-063", "BMT-064"]),
    ("staff_identity", "Individual staff identity", "unavailable", "Existing access uses separate owner/analyst credentials; individual staff SSO and MFA are not implemented.", ["BMT-080"]),
)


@router.get("/v1/admin/studio/capabilities")
def capabilities(request: Request, role: Access):
    enabled = getattr(request.app.state.settings, "telemetry_enabled", False)
    sources = [
        {"key": key, "title": title, "status": status, "description": description,
         "requirement_ids": ids} for key, title, status, description, ids in SOURCES
    ]
    if not enabled:
        for source in sources:
            if source["key"] == "behaviour":
                source.update(status="unavailable", description="Product telemetry is disabled on this backend. No observed activity is implied by registered accounts or submitted attempts.")
    if request.app.state.settings.client_quality_enabled:
        for source in sources:
            if source["key"] == "client_quality":
                source.update(status="partial", description="One bounded statistics package per signed-in timed race; actual device/OS filters, sampled track/segment presence and frame buckets. Old streamed race summaries are retired. Crash stacks, Play vitals and consented enhanced captures remain unavailable.")
    sources.extend([
        {"key": "competition_inspection", "title": "Competition provenance", "status": "partial",
            "description": "Bounded rivalry/challenge roster, pinned contracts, accepted-run checks, ranks/points and exact target; archived runs and reward delivery may be unavailable.", "requirement_ids": ["BMT-034"]},
        {"key": "case_workflow", "title": "Support and moderation cases", "status": "partial",
            "description": "Append-only notes/issues, case transitions, signed-in reports and appeals, audited track quarantine. Expiring scopes, verified recovery and production compensation are unavailable.", "requirement_ids": ["BMT-033", "BMT-050", "BMT-054", "BMT-056"]},
    ])
    return {
        "schema": "bmt-studio-capabilities-v1", "as_of": now(),
        "environment": request.app.state.settings.environment, "role": role, "read_only": True,
        "sources": sources,
        "limitations": [
            "Capabilities describe this application implementation, not a live check of external providers.",
            "Stored submissions do not establish race starts, quits, foreground playtime or voluntary returns.",
            "Observed analytics begins with collected evidence; guest activity and pre-collection behaviour are not reconstructed.",
            "A backup marker does not establish a successful restore or a recovery-time guarantee.",
            "This Studio inspection does not change game records or execute verification.",
        ],
    }


def pinned_manifest(board):
    value = board.manifest if board and isinstance(board.manifest, dict) else {}
    # Project only known scalar contract fields; never copy arbitrary stored metadata.
    return {key: value[key] for key in MANIFEST_FIELDS if key in value and type(value[key]) in (str, int)}


@router.get("/v1/admin/studio/context")
def studio_context(request: Request, role: Access, window: Window, days: int = Query(7, ge=1, le=90)):
    first, until = window or calendar_range(days)
    return {"role": role, "environment": request.app.state.settings.environment,
        "since": first, "until": until, "as_of": now()}


def race_evidence(session, run_id):
    run = session.get(Run, run_id)
    if run is None:
        raise HTTPException(404, "RACE_NOT_FOUND")
    player = session.get(Player, run.player_id)
    board = session.get(Board, run.board_id)
    version = session.get(TrackVersion, board.version_id) if board else None
    ticket = session.get(RunTicket, run.ticket_id)
    if ticket and (ticket.player_id != run.player_id or ticket.board_id != run.board_id):
        ticket = None
    manifest = pinned_manifest(board)
    tick_hz = manifest.get("tick_rate")
    if type(tick_hz) is not int or not 0 < tick_hz <= 1000:
        tick_hz = None
    accepted = run.status == "verified"
    time_ticks = run.time_ticks if accepted and type(run.time_ticks) is int and run.time_ticks > 0 else None
    lap_ticks = run.lap_ticks if accepted and isinstance(run.lap_ticks, list) else None
    if lap_ticks is not None and (len(lap_ticks) > 20 or any(type(t) is not int or t <= 0 for t in lap_ticks)):
        lap_ticks = None
    conditions = (ResumeRace.ticket_id == run.ticket_id, ResumeRace.player_id == run.player_id)
    total = session.scalar(select(func.count()).select_from(ResumeReceipt).join(ResumeRace).where(*conditions))
    receipts = session.scalars(select(ResumeReceipt).join(ResumeRace).where(*conditions)
        .order_by(ResumeReceipt.ordinal, ResumeReceipt.id).limit(RECEIPT_LIMIT)).all()
    lifecycle = []
    if ticket:
        lifecycle.append({"event": "ticket_issued", "at": ticket.created_at,
            "description": "Server issued a race contract; this does not prove a client race started."})
    lifecycle.append({"event": "submission_received", "at": run.created_at,
        "description": "Server persisted the submitted race evidence."})
    if run.finished_at is not None and run.status in ("verified", "rejected", "failed"):
        lifecycle.append({"event": "verification_" + run.status, "at": run.finished_at,
            "description": "Terminal server verification outcome; this timestamp is not the driving finish time."})
    lifecycle.sort(key=lambda event: event["at"])
    result = {
        "schema": "bmt-studio-race-evidence-v1", "as_of": now(),
        "run": {"id": run.id, "status": run.status, "created_at": run.created_at,
            "verification_terminal_at": run.finished_at, "attempts": run.attempts,
            "failure_code": run.failure_code, "replay_hash": run.replay_hash, "ghost_hash": run.ghost_hash},
        "player": {"id": player.id, "display_name": player.display_name, "disabled": player.disabled,
            "is_test_driver": player.is_test_driver} if player else None,
        "ticket": {"id": ticket.id, "issued_at": ticket.created_at, "expires_at": ticket.expires_at} if ticket else None,
        "contract": {"board_id": board.id, "track_id": version.track_id if version else None,
            "version_id": board.version_id, "version_number": version.number if version else None,
            "track_name": version.name if version else None, "content_hash": version.content_hash if version else None,
            "vehicle_id": board.vehicle_id, "manifest": manifest} if board else None,
        "timing": {"accepted": accepted, "tick_hz": tick_hz, "time_ticks": time_ticks, "lap_ticks": lap_ticks,
            "time_seconds": time_ticks / tick_hz if time_ticks and tick_hz else None,
            "lap_seconds": [t / tick_hz for t in lap_ticks] if lap_ticks is not None and tick_hz else None},
        "personal_best": {"current": session.scalar(select(func.count()).select_from(PersonalBest)
            .where(PersonalBest.run_id == run.id, PersonalBest.player_id == run.player_id, PersonalBest.board_id == run.board_id)) > 0},
        "lifecycle": lifecycle,
        "resumes": {"total": total, "limit": RECEIPT_LIMIT, "items": [
            {key: getattr(receipt, key) for key in ("id", "race_id", "ordinal", "source", "from_tick", "to_tick", "settled", "refunded", "created_at")}
            for receipt in receipts]},
        "coverage": [
            {"key": "pinned_contract", "status": "partial", "description": "Known scalar pinned contract fields are projected; arbitrary stored metadata and full proof bytes are omitted."},
            {"key": "ticket", "status": "supported" if ticket else "unavailable", "description": "Linked issuance and expiry." if ticket else "Ticket link is missing or inconsistent."},
            {"key": "track_version", "status": "supported" if version else "unavailable", "description": "Original immutable version." if version else "Pinned track-version record is unavailable."},
            {"key": "tick_rate", "status": "supported" if tick_hz else "unavailable", "description": "Time conversion uses only this race's pinned tick rate." if tick_hz else "Pinned tick rate is unavailable; seconds are not inferred."},
            {"key": "client_sessions", "status": "unavailable", "description": "Foreground play sessions and monotonic client event spans are not collected."},
            {"key": "client_diagnostics", "status": "unavailable", "description": "Build/device/ABI, crash evidence and frame-quality summaries are not recorded on this run."},
            {"key": "request_trace", "status": "unavailable", "description": "Request IDs exist in server logs but no submission trace correlation is persisted on this run."},
            {"key": "remote_config", "status": "unavailable", "description": "The pinned car config hash is not a remote-config exposure record."},
            {"key": "verification_history", "status": "partial", "description": "Current outcome and attempt count are stored; per-attempt phase timestamps and executed validator versions are not retained."},
            {"key": "bundle_expiry", "status": "unavailable", "description": "This is a local JSON download protected by current admin access; downloaded copies do not expire."},
        ],
    }
    result["checksum_algorithm"] = "sha256-canonical-json"
    result["checksum"] = digest(result)
    return result


@router.get("/v1/admin/studio/races/{run_id}")
def race(run_id: UUID, request: Request, role: Access, download: bool = False):
    with request.app.state.session_factory() as session:
        # An evidence bundle must not join multiple worker states across its reads.
        if session.bind.dialect.name == "postgresql":
            session.connection(execution_options={"isolation_level": "REPEATABLE READ"})
            session.execute(text("SET TRANSACTION READ ONLY"))
        elif session.bind.dialect.name == "sqlite":
            session.connection().exec_driver_sql("BEGIN")
        data = race_evidence(session, str(run_id))
    headers = {"Cache-Control": "no-store"}
    if download:
        headers["Content-Disposition"] = f'attachment; filename="race-{run_id}-evidence.json"'
    return JSONResponse(data, headers=headers)
