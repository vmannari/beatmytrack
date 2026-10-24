"""Reviewed definitions and full-scope prepared release comparisons."""

from fastapi import APIRouter, Query, Request
from sqlalchemy import BigInteger, case, cast, func, select

from .admin import Access, Window
from .race_statistics_models import RaceStatisticsDay as Race
from .studio_platform_models import AnalysisState, StudioFinanceEvent
from .studio_queries import read_snapshot
from .telemetry_models import ProductState
from .track_models import now

router = APIRouter(tags=["Studio metric definitions"])
DEFINITIONS = (
    (
        "active_players",
        "Distinct players with qualifying activity",
        "players",
        "None",
        "prepared activity",
        "Observed signed-in players including artificial drivers",
    ),
    (
        "retention_d1_d7_d30",
        "Exact UTC day return",
        "fraction",
        "First-observed cohort with complete follow-up",
        "analysis v1 days",
        "First-observation build/platform; any return build",
    ),
    (
        "foreground_ms",
        "Observed foreground intervals",
        "milliseconds",
        "Observed sessions",
        "client interval reports",
        "Signed-in opted-in clients; not proven play time",
    ),
    (
        "completion",
        "Observed race completion",
        "fraction",
        "Submitted race-statistics packages",
        "prepared race packages",
        "Clients that submitted a package; missing exits excluded",
    ),
    (
        "slow_frames",
        "Frames over 34 ms",
        "fraction",
        "Reported frame samples",
        "race package frame buckets 5–7",
        "Reporting clients; weighted by frame count",
    ),
    (
        "process_exits",
        "Prior Android process exits",
        "events",
        "No crash-free-user denominator available",
        "OS exit summaries",
        "Reporting Android API30+ processes; no Play Vitals source",
    ),
    (
        "verified_results",
        "Authoritative accepted races",
        "races",
        "Submitted results",
        "run verification",
        "All player types; never inferred from client finish",
    ),
    (
        "revenue",
        "Provider-reported monetary amounts",
        "currency micros",
        "By currency and accounting basis separately",
        "verified provider imports",
        "No exchange conversion or catalogue price inference",
    ),
    (
        "coins",
        "Noncash earned/spent Coins",
        "Coins",
        "Ledger entries since activation",
        "atomic wallet mutations",
        "Registered non-artificial players; opening balance is not earnings",
    ),
)


@router.get("/v1/admin/metrics")
def registry(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        state, product = db.get(AnalysisState, 1), db.get(ProductState, 1)
        latest_money = db.scalar(select(func.max(StudioFinanceEvent.received_at)))
        return {
            "role": role,
            "as_of": now(),
            "timezone": "UTC",
            "definition_version": 1,
            "items": [
                dict(
                    zip(("id", "definition", "unit", "denominator", "source", "population"), row),
                    grain="UTC calendar days; operational queues are current snapshots",
                    owner="Game analytics / operations",
                    late_arrivals="Accepted client observations can restate seven days",
                    maturity="Retention waits complete target day; funnels wait their declared horizon",
                    authority=(
                        "authoritative server result"
                        if row[0] == "verified_results"
                        else "authoritative noncash wallet"
                        if row[0] == "coins"
                        else "provider reported, basis retained"
                        if row[0] == "revenue"
                        else "observed client evidence"
                    ),
                    consent=(
                        "Essential transaction records under existing policy"
                        if row[0] in ("verified_results", "coins", "revenue")
                        else "Signed-in analytics opt-in; guests unavailable"
                    ),
                    completeness="Use the relevant feed's coverage, retention and watermark; absence is not a healthy or zero population.",
                )
                for row in DEFINITIONS
            ],
            "coverage": {
                "analysis_started_at": state.started_at if state else None,
                "processed_through": state.processed_through if state else None,
                "latest_client_at": state.latest_client_at if state else None,
                "pending": product.pending_events if product else None,
                "latest_finance_import": latest_money,
                "play_configured": bool(request.app.state.settings.studio_play_package),
                "admob_configured": bool(request.app.state.settings.studio_admob_account),
                "guest_linking": False,
                "play_vitals": False,
                "crash_stacks": False,
            },
        }


def quality_totals(db, conditions):
    fields = [
        func.coalesce(func.sum(Race.races), 0).label("attempts"),
        func.coalesce(func.sum(case((Race.outcome == "finished", Race.races), else_=0)), 0).label("finished"),
    ]
    fields += [
        func.coalesce(func.sum(cast(Race.frame_buckets[i].as_string(), BigInteger)), 0).label("b" + str(i))
        for i in range(8)
    ]
    values = dict(db.execute(select(*fields).where(*conditions)).mappings().one())
    values["frames"] = sum(values.pop("b" + str(i)) for i in range(5))
    values["slow_frames"] = sum(values.pop("b" + str(i)) for i in range(5, 8))
    values["frames"] += values["slow_frames"]
    values["completion"] = values["finished"] / values["attempts"] if values["attempts"] else None
    values["slow_fraction"] = values["slow_frames"] / values["frames"] if values["frames"] else None
    return values


@router.get("/v1/admin/analysis/releases")
def compare(
    request: Request, role: Access, window: Window,
    build_id: str = Query("", max_length=80), baseline: str = Query("", max_length=80),
    platform: str = Query("", max_length=12), device_model: str = Query("", max_length=80),
    os_version: str = Query("", max_length=80), track_version_id: str = Query("", max_length=36),
    render_context_key: str = Query("", max_length=64),
):
    from .studio_release_reports import release_report
    return release_report(request, role, window, build_id, baseline, platform, device_model,
                          os_version, track_version_id, render_context_key)
