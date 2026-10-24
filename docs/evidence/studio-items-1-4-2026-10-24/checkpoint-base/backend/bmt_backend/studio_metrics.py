"""Reviewed definitions and full-scope prepared release comparisons."""

from fastapi import APIRouter, Query, Request
from sqlalchemy import BigInteger, case, cast, func, select

from .admin import Access, Window
from .admin_ranges import calendar_range
from .quality_models import QualityFact
from .race_statistics_models import RaceStatisticsDay as Race
from .studio_analysis import DAY
from .studio_platform_models import AnalysisDay, AnalysisState, StudioFinanceEvent
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
    request: Request,
    role: Access,
    window: Window,
    build_id: str = Query("", max_length=80),
    baseline: str = Query("", max_length=80),
    platform: str = Query("", max_length=12),
):
    first, until = window or calendar_range(7)
    conditions = [Race.day >= first // DAY, Race.day <= (until - 1) // DAY]
    if platform:
        conditions.append(Race.platform == platform)
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        builds = list(
            db.scalars(select(Race.build_id).where(*conditions).distinct().order_by(Race.build_id).limit(201))
        )

        def one(build):
            if not build:
                return None
            scope = [*conditions, Race.build_id == build]
            result = quality_totals(db, scope)
            result["build_id"] = build
            affected = [
                AnalysisDay.day >= first // DAY,
                AnalysisDay.day <= (until - 1) // DAY,
                AnalysisDay.build_id == build,
                AnalysisDay.counters["quality_attempts"].as_integer() > 0,
            ]
            if platform:
                affected.append(AnalysisDay.platform == platform)
            reporting, slow = db.execute(select(
                func.count(func.distinct(AnalysisDay.player_id)),
                func.count(func.distinct(case((AnalysisDay.counters["quality_slow_frames"].as_integer() > 0,
                                               AnalysisDay.player_id))))).where(*affected)).one()
            result["reporting_players"], result["affected_players"] = reporting, slow
            return result

        candidate, control = one(build_id), one(baseline)
        segment_fields = (Race.device_model, Race.os_version, Race.render_context_key)
        segments = (
            db.execute(
                select(
                    *segment_fields,
                    func.sum(Race.races).label("attempts"),
                    func.sum(
                        sum(
                            (cast(Race.frame_buckets[i].as_string(), BigInteger) for i in range(5, 8)),
                            start=0,
                        )
                    ).label("slow_frames"),
                )
                .where(*conditions, Race.build_id == build_id)
                .group_by(*segment_fields)
                .order_by(func.sum(Race.races).desc(), *segment_fields)
                .limit(21)
            ).all()
            if build_id
            else []
        )
        diagnostic = dict(
            db.execute(
                select(
                    *[
                        func.coalesce(func.sum(getattr(QualityFact, name)), 0).label(name)
                        for name in ("reports", "samples", "slow")
                    ]
                ).where(
                    QualityFact.kind == "quality_summary",
                    QualityFact.day >= first // DAY,
                    QualityFact.day <= (until - 1) // DAY,
                )
            )
            .mappings()
            .one()
        )
        return {
            "role": role,
            "since": first // DAY * DAY,
            "until": ((until - 1) // DAY + 1) * DAY,
            "as_of": now(),
            "builds": builds[:200],
            "builds_truncated": len(builds) > 200,
            "candidate": candidate,
            "baseline": control,
            "comparison": {
                "completion_change": candidate["completion"] - control["completion"],
                "descriptive_only": True,
            }
            if candidate
            and control
            and candidate["completion"] is not None
            and control["completion"] is not None
            else None,
            "segments": [
                dict(
                    zip(("device_model", "os_version", "render_context_key", "attempts", "slow_frames"), row)
                )
                for row in segments[:20]
            ],
            "segments_truncated": len(segments) > 20,
            "historical_diagnostic_totals": diagnostic,
            "coverage": "Full filtered SQL aggregates. Release comparisons describe reporting populations and are not causal. Affected-player coverage starts at analysis migration; no client crash-free denominator is inferred.",
        }
