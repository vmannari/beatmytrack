"""Backlogs drain in bounded transactions without revisiting retained cohorts."""
# ruff: noqa: F811
from uuid import uuid4

import pytest
from alembic import command
from sqlalchemy import event, func, or_, select, text
from test_auth_postgres import postgres_auth  # noqa: F401

from bmt_backend.identity_models import LoginChallenge, Player, RateBucket, SessionFamily, SessionToken
from bmt_backend.maintenance import cleanup, cleanup_batches
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.network_models import NetworkHealthDay
from bmt_backend.race_statistics_models import RaceStatisticsDay, RaceStatisticsReceipt
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisPerson
from bmt_backend.telemetry_processing import maintenance
from bmt_backend.telemetry_queue import activate, partition
from bmt_backend.telemetry_queue_models import TelemetryActor
from bmt_backend.track_models import now


@pytest.fixture(params=["sqlite", "postgres"])
def retention_app(request):
    if request.param == "postgres":
        return request.getfixturevalue("postgres_auth")[0]
    return request.getfixturevalue("auth_app")


def prepare(app):
    with app.state.session_factory() as db:
        activate(db)
        db.commit()


@pytest.mark.parametrize("model", [RaceStatisticsReceipt, RaceStatisticsDay, NetworkHealthDay])
def test_isolated_expired_diagnostic_backlog_drains_without_a_minute_pause(retention_app, model):
    prepare(retention_app)
    stamp = now()
    with retention_app.state.session_factory() as db:
        for index in range(7):
            if model is RaceStatisticsReceipt:
                row = model(player_id=str(uuid4()), race_id=str(uuid4()), event_id=str(uuid4()),
                            payload_hash="f" * 64, received_at=stamp - 9 * 86400)
            else:
                values = {"day": stamp // 86400 - 181, "dimension": str(index), "build_id": "",
                          "platform": "android", "device_model": "", "os_version": ""}
                if model is RaceStatisticsDay:
                    values.update(device_class="phone", outcome="finished")
                else:
                    values["category"] = "telemetry"
                row = model(**values)
            db.add(row)
        db.commit()
    for remaining in (4, 1, 0):
        result = maintenance(retention_app.state.session_factory, at=stamp, limit=3)
        assert result["more"] is True
        with retention_app.state.session_factory() as db:
            assert db.scalar(select(func.count()).select_from(model)) == remaining
    assert not maintenance(retention_app.state.session_factory, at=stamp, limit=3).get("more")


def test_legacy_people_are_upgraded_once_and_current_old_cohorts_are_not_swept(retention_app):
    prepare(retention_app)
    stamp, identities = now(), [str(uuid4()) for _ in range(35)]
    with retention_app.state.session_factory() as db:
        db.add_all([AnalysisPerson(player_id=identity, first_at=stamp - 181 * 86400)
                    for identity in identities])
        db.add_all([AnalysisDay(day=stamp // 86400, player_id=identity, dimension="current", counters={},
                               first_at=stamp, last_at=stamp) for identity in identities])
        db.commit()
    for _ in range(3):
        assert maintenance(retention_app.state.session_factory, at=stamp, limit=16)["more"]
    with retention_app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(AnalysisPerson).where(
            AnalysisPerson.last_day == stamp // 86400)) == 35
    statements = []

    def record(_connection, _cursor, statement, _parameters, _context, _executemany):
        if "FROM studio_analysis_people" in statement:
            statements.append(statement)

    event.listen(retention_app.state.engine, "before_cursor_execute", record)
    try:
        for offset in (1, 62, 123):
            assert not maintenance(retention_app.state.session_factory, at=stamp + offset).get("more")
    finally:
        event.remove(retention_app.state.engine, "before_cursor_execute", record)
    # The existence probe can inspect the expiry index; no person page is read.
    assert statements and all("EXISTS" in statement for statement in statements)
    with retention_app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(AnalysisPerson)) == 35


def test_due_people_recheck_retained_days_and_preserve_exact_floor(retention_app):
    prepare(retention_app)
    stamp, floor = now(), now() // 86400 - 180
    stale, current, boundary = (str(uuid4()) for _ in range(3))
    with retention_app.state.session_factory() as db:
        db.add_all([AnalysisPerson(player_id=identity, first_at=(floor - 10) * 86400,
                                   last_day=day) for identity, day in
                    ((stale, floor - 1), (current, floor - 1), (boundary, floor))])
        db.add(AnalysisDay(day=floor + 1, player_id=current, dimension="late", counters={},
                           first_at=(floor + 1) * 86400, last_at=(floor + 1) * 86400))
        db.commit()
    maintenance(retention_app.state.session_factory, at=stamp)
    with retention_app.state.session_factory() as db:
        assert db.get(AnalysisPerson, stale) is None
        assert db.get(AnalysisPerson, current).last_day == floor + 1
        assert db.get(AnalysisPerson, boundary) is not None


def test_expiry_migration_preserves_cohorts_and_upgrades_rows_lazily(retention_app):
    app, identity, stamp = retention_app, str(uuid4()), now()
    command.downgrade(configuration(app.state.engine), "0055_bounded_rank_reads")
    with app.state.engine.begin() as connection:
        connection.execute(text("INSERT INTO studio_analysis_people "
            "(player_id,first_at,first_build,first_platform,first_mode,artificial,journey) "
            "VALUES (:identity,:stamp,'old','android','ordinary',false,'{}')"),
            {"identity": identity, "stamp": stamp})
    upgrade(app.state.engine)
    with app.state.session_factory() as db:
        row = db.get(AnalysisPerson, identity)
        assert row.first_at == stamp and row.first_build == "old" and row.last_day is None
    prepare(app)
    maintenance(app.state.session_factory, at=stamp)
    with app.state.session_factory() as db:
        row = db.get(AnalysisPerson, identity)
        assert row.first_at == stamp and row.first_build == "old" and row.last_day == stamp // 86400


def test_identity_cleanup_bounds_each_class_and_rotation_history(retention_app):
    factory, stamp = retention_app.state.session_factory, now()
    with factory() as db:
        player = Player(display_name="Bounded cleanup")
        db.add(player)
        db.flush()
        family = SessionFamily(player_id=player.id, expires_at=stamp - 1)
        live = SessionFamily(player_id=player.id, expires_at=stamp + 86400)
        db.add_all([family, live])
        db.flush()
        family_id, live_id, player_id = family.id, live.id, player.id
        for index in range(7):
            db.add(SessionToken(family_id=family_id, access_hash=f"expired-access-{index}",
                                refresh_hash=f"expired-refresh-{index}", access_expires_at=stamp - 1))
            db.add(LoginChallenge(nonce_hash=str(index), expires_at=stamp - 1))
            db.add(RateBucket(key=str(index), expires_at=stamp - 1))
        db.add(SessionToken(family_id=live_id, access_hash="live-access", refresh_hash="live-refresh",
                            access_expires_at=stamp + 100))
        db.commit()
    for remaining in (4, 1, 0):
        result = cleanup(factory, batch_limit=3)
        assert result["session_tokens"] <= 3 and result["login_challenges"] <= 3 and result["rate_buckets"] <= 3
        assert result["more"]
        with factory() as db:
            assert db.scalar(select(func.count()).select_from(SessionToken).where(
                SessionToken.family_id == family_id)) == remaining
            assert (db.get(SessionFamily, family_id) is not None) == bool(remaining)
            assert db.get(SessionFamily, live_id) is not None and db.get(Player, player_id) is not None
    assert cleanup(factory, batch_limit=3)["more"] is False


@pytest.mark.parametrize("budget", [0, 1001, True, 1.0])
def test_cleanup_rejects_an_unbounded_budget(auth_app, budget):
    with pytest.raises(ValueError, match="INVALID_IDENTITY_CLEANUP_BUDGET"):
        cleanup(auth_app.state.session_factory, batch_limit=budget)


def test_identity_cli_budget_reports_backlog_and_stops_when_empty(auth_app):
    factory = auth_app.state.session_factory
    with factory() as db:
        db.add_all([LoginChallenge(nonce_hash=str(index), expires_at=now() - 1) for index in range(7)])
        db.commit()
    first = cleanup_batches(factory, batches=2, batch_limit=3)
    assert first["login_challenges"] == 6 and first["more"] and first["budget_exhausted"]
    second = cleanup_batches(factory, batches=100, batch_limit=3)
    assert second["login_challenges"] == 1 and second["batches"] == 2
    assert not second["more"] and not second["budget_exhausted"]


@pytest.mark.postgres
def test_identity_cleanup_skips_locked_family_but_reports_its_backlog(postgres_auth):
    app, _client = postgres_auth
    factory = app.state.session_factory
    with factory() as db:
        player = Player(display_name="Locked expiry")
        db.add(player)
        db.flush()
        family = SessionFamily(player_id=player.id, expires_at=now() - 1)
        db.add(family)
        db.commit()
        identity = family.id
    with factory() as owner:
        owner.scalar(select(SessionFamily).where(SessionFamily.id == identity).with_for_update())
        result = cleanup(factory)
        assert result["session_families"] == 0 and result["more"]
    assert cleanup(factory)["session_families"] == 1


@pytest.mark.postgres
def test_person_expiry_skips_an_owned_actor_and_retries_after_release(postgres_auth):
    app, _client = postgres_auth
    prepare(app)
    factory, identity, stamp = app.state.session_factory, str(uuid4()), now()
    with factory() as db:
        db.add(AnalysisPerson(player_id=identity, first_at=stamp - 181 * 86400,
                              last_day=stamp // 86400 - 181))
        db.commit()
    with factory() as owner:
        owner.scalar(select(TelemetryActor).where(TelemetryActor.id == partition(identity)).with_for_update())
        assert maintenance(factory, at=stamp)["more"]
        with factory() as db:
            assert db.get(AnalysisPerson, identity) is not None
    maintenance(factory, at=stamp)
    with factory() as db:
        assert db.get(AnalysisPerson, identity) is None


@pytest.mark.postgres
def test_current_only_person_expiry_uses_two_indexed_existence_probes(postgres_auth):
    app, _client = postgres_auth
    stamp, factory = now(), app.state.session_factory
    with factory() as db:
        db.execute(AnalysisPerson.__table__.insert(), [
            {"player_id": str(uuid4()), "first_at": stamp - 181 * 86400, "last_day": stamp // 86400}
            for _ in range(10000)])
        db.commit()
        db.execute(text("ANALYZE studio_analysis_people"))
        query = select(or_(select(AnalysisPerson.player_id).where(AnalysisPerson.last_day.is_(None)).exists(),
                           select(AnalysisPerson.player_id).where(AnalysisPerson.last_day < stamp // 86400 - 180).exists()))
        sql = str(query.compile(app.state.engine, compile_kwargs={"literal_binds": True}))
        plan = db.execute(text("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql)).scalar_one()[0]["Plan"]

        def nodes(node):
            yield node
            for child in node.get("Plans", []):
                yield from nodes(child)

        accesses = [node for node in nodes(plan) if node.get("Relation Name") == "studio_analysis_people"]
        assert len(accesses) == 2
        assert all(node.get("Index Name") == "ix_analysis_person_expiry" for node in accesses)
        assert all(node["Actual Rows"] == 0 for node in accesses)
