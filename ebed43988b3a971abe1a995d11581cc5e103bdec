"""Isolate exact, population-dependent Studio reports from gameplay storage."""

import logging
import threading
import time
from contextlib import contextmanager

from fastapi import HTTPException
from sqlalchemy import create_engine, event, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .observability import dependency_failure
from .studio_queries import read_snapshot


class ReportDeadline(TimeoutError):
    pass


LIMITED_DAYS = 7
LIMITED_BUDGET_MS = 1500
LIMITED_LOCK = 0x424D545354554449


def reporting_policy(settings):
    limited = settings.studio_analysis_mode == "shared_limited"
    return {"mode": settings.studio_analysis_mode, "max_days": LIMITED_DAYS if limited else 90,
            "default_days": 7, "manual_refresh": True,
            "sql_budget_ms": min(settings.studio_analysis_statement_timeout_ms, LIMITED_BUDGET_MS)
                if limited else settings.studio_analysis_statement_timeout_ms}


def unavailable(code):
    return HTTPException(503, code, headers={"Retry-After": "5"})


class StudioReporting:
    """An explicit reader mode; replica isolation remains the default.

    Exact distinct users across arbitrary windows cannot be obtained by summing
    daily counts. These analyses retain their SQL semantics on a dedicated hot
    standby, with a total SQL deadline and a request-start primary WAL fence.
    """

    def __init__(self, settings, *, engine=None):
        self.settings = settings
        self.limited = settings.studio_analysis_mode == "shared_limited"
        self.budget_ms = reporting_policy(settings)["sql_budget_ms"]
        self._slot = threading.BoundedSemaphore(1)
        self._closed = False
        self._injected = engine is not None
        if self._injected and settings.environment != "test":
            raise ValueError("Studio analysis engine injection requires the test environment")
        self._owned = engine is None
        self.engine = engine
        if engine is None and settings.studio_analysis_database_url:
            self.engine = create_engine(
                settings.studio_analysis_database_url,
                hide_parameters=True,
                pool_pre_ping=True,
                pool_size=1,
                max_overflow=0,
                pool_timeout=0.1,
                connect_args={
                    "connect_timeout": 3,
                    "options": (
                        "-c default_transaction_read_only=on "
                        f"-c statement_timeout={self.budget_ms} "
                        + ("-c lock_timeout=200 -c idle_in_transaction_session_timeout=3000 "
                           "-c work_mem=1MB -c max_parallel_workers_per_gather=0 -c jit=off"
                           if self.limited else "-c lock_timeout=1000 -c idle_in_transaction_session_timeout=10000")
                    ),
                },
            )
        if self.engine is not None:
            event.listen(self.engine, "before_cursor_execute", self._budget)

    @staticmethod
    def _remaining(deadline):
        remaining = int((deadline - time.monotonic()) * 1000)
        if remaining < 1:
            raise ReportDeadline("Studio analysis deadline elapsed")
        return remaining

    @staticmethod
    def _budget(connection, cursor, _statement, _parameters, _context, _many):
        deadline = connection.info.get("bmt_studio_report_deadline")
        if deadline is None:
            return
        remaining = StudioReporting._remaining(deadline)
        if connection.dialect.name == "postgresql":
            # Direct DBAPI execution avoids recursively invoking this listener.
            # LOCAL restores the ordinary pool connection's settings on rollback.
            cursor.execute(f"SET LOCAL statement_timeout = {remaining}")

    def _fence(self, primary_factory, deadline):
        if self._injected:
            return None
        with primary_factory() as primary:
            # One fixed-size metadata read, never analytical facts on primary.
            primary.connection()  # Include bounded pool checkout in the budget.
            remaining = self._remaining(deadline)
            primary.execute(text(f"SET LOCAL statement_timeout = {remaining}"))
            # Insert position also covers acknowledged asynchronous commits
            # whose WAL has not reached the writer/replica yet.
            return dict(primary.execute(text(
                "SELECT pg_current_wal_insert_lsn()::text AS lsn, "
                "(pg_control_system()).system_identifier::text AS cluster_id, "
                "current_database() AS database, current_schema() AS schema"
            )).mappings().one())

    def _replica(self, connection, fence, *, deadline=None):
        if self._injected:
            return {"source": "explicit_test_engine", "last_replayed_transaction_at": None,
                    "last_replayed_transaction_age_seconds": None}
        wait_until = min(deadline, time.monotonic() + 0.25) if deadline else None
        while True:
            row = connection.execute(text(
                "SELECT pg_is_in_recovery() AS standby, "
                "current_setting('transaction_read_only')::boolean AS read_only, "
                "(pg_control_system()).system_identifier::text AS cluster_id, "
                "current_database() AS database, current_schema() AS schema, "
                "EXTRACT(EPOCH FROM pg_last_xact_replay_timestamp()) AS replayed_at, "
                "EXTRACT(EPOCH FROM clock_timestamp()) AS observed_at, "
                "pg_last_wal_replay_lsn() >= CAST(:fence AS pg_lsn) AS fenced"
            ), {"fence": fence["lsn"]}).mappings().one()
            if not row["standby"] or not row["read_only"]:
                raise unavailable("STUDIO_ANALYSIS_REQUIRES_READ_ONLY_REPLICA")
            if any(row[key] != fence[key] for key in ("cluster_id", "database", "schema")):
                raise unavailable("STUDIO_ANALYSIS_REPLICA_IDENTITY_MISMATCH")
            if row["fenced"]:
                break
            if wait_until is None or time.monotonic() >= wait_until:
                raise unavailable("STUDIO_ANALYSIS_REPLICA_CATCHING_UP")
            connection.rollback()
            time.sleep(min(0.02, max(0, wait_until - time.monotonic())))
        # A matching request-start WAL fence proves completeness even when no
        # transactions have committed recently. Transaction age is coverage
        # metadata; treating it as replication lag would reject idle replicas.
        replayed = row["replayed_at"]
        age = max(0.0, float(row["observed_at"] - replayed)) if replayed is not None else None
        return {"source": "read_only_replica",
                "last_replayed_transaction_at": int(replayed) if replayed is not None else None,
                "last_replayed_transaction_age_seconds": round(age, 3) if age is not None else None,
                "request_start_fence_applied": True}

    def _shared_primary(self, connection, fence):
        row = connection.execute(text(
            "SELECT pg_is_in_recovery() AS standby, "
            "current_setting('transaction_read_only')::boolean AS read_only, "
            "(pg_control_system()).system_identifier::text AS cluster_id, "
            "current_database() AS database, current_schema() AS schema, current_user AS reader, "
            "(SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls "
            "FROM pg_roles WHERE rolname=current_user) AS privileged, "
            "EXISTS(SELECT 1 FROM pg_auth_members WHERE member=(SELECT oid FROM pg_roles "
            "WHERE rolname=current_user)) AS inherited_role, "
            "EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname=current_schema() AND c.relkind IN ('r','p','v','m','f') "
            "AND has_table_privilege(current_user,c.oid,'INSERT,UPDATE,DELETE,TRUNCATE')) AS can_write, "
            "has_schema_privilege(current_user,current_schema(),'CREATE') AS can_create"
        )).mappings().one()
        if (row["standby"] or not row["read_only"] or row["reader"] != "bmt_studio_report"
                or row["privileged"] or row["inherited_role"] or row["can_write"] or row["can_create"]):
            raise unavailable("STUDIO_LIMITED_REPORTING_READER_NOT_READ_ONLY")
        if any(row[key] != fence[key] for key in ("cluster_id", "database", "schema")):
            raise unavailable("STUDIO_ANALYSIS_REPLICA_IDENTITY_MISMATCH")
        if not connection.scalar(text("SELECT pg_try_advisory_xact_lock(:key)"), {"key": LIMITED_LOCK}):
            raise unavailable("STUDIO_ANALYSIS_BUSY")
        return {"source": "limited_shared_primary", "max_days": LIMITED_DAYS,
                "sql_budget_ms": self.budget_ms, "read_only": True,
                "request_start_snapshot": True, "concurrent_reports": 1}

    def validate_window(self, window):
        if self.limited and (window is None or window[1] <= window[0]
                            or window[1] - window[0] > LIMITED_DAYS * 86400):
            raise HTTPException(422, "LIMITED_REPORTING_RANGE: choose at most 7 UTC calendar days")

    @contextmanager
    def snapshot(self, primary_factory, *, request_id="", window=None):
        self.validate_window(window)
        if self.engine is None:
            raise unavailable(
                "STUDIO_ANALYSIS_REPLICA_NOT_CONFIGURED: configure "
                "BMT_STUDIO_ANALYSIS_DATABASE_URL with a dedicated PostgreSQL hot standby"
            )
        if not self._slot.acquire(blocking=False):
            raise unavailable("STUDIO_ANALYSIS_BUSY")
        deadline = time.monotonic() + self.budget_ms / 1000
        try:
            fence = self._fence(primary_factory, deadline)
            with self.engine.connect() as connection:
                connection.info["bmt_studio_report_deadline"] = deadline
                try:
                    if self.limited:
                        # The primary snapshot opens after the request's metadata
                        # read, so acknowledged erasures are visible without a
                        # replay wait. The lock lasts for this exact snapshot.
                        connection.rollback()
                        with Session(bind=connection, expire_on_commit=False) as session:
                            read_snapshot(session)
                            metadata = self._shared_primary(connection, fence) if not self._injected else {
                                "source": "explicit_test_engine", "mode": "shared_limited"}
                            yield session, metadata
                            self._remaining(deadline)
                        return
                    metadata = self._replica(connection, fence, deadline=deadline)
                    # The WAL fence must be satisfied BEFORE opening the report
                    # snapshot. A snapshot opened before catch-up could retain
                    # a contribution erased before this request began.
                    connection.rollback()
                    with Session(bind=connection, expire_on_commit=False) as session:
                        read_snapshot(session)
                        if not self._injected and not session.scalar(text("SELECT pg_is_in_recovery()")):
                            raise unavailable("STUDIO_ANALYSIS_REQUIRES_READ_ONLY_REPLICA")
                        yield session, metadata
                        self._remaining(deadline)
                finally:
                    if not connection.closed:
                        connection.info.pop("bmt_studio_report_deadline", None)
        except ReportDeadline:
            raise unavailable("STUDIO_ANALYSIS_TIMEOUT") from None
        except SQLAlchemyError as error:
            dependency_failure(logging.getLogger("bmt.studio_analysis"), error, request_id, "studio_analysis")
            cancelled = getattr(getattr(error, "orig", None), "sqlstate", None) == "57014"
            code = "STUDIO_ANALYSIS_TIMEOUT" if cancelled else "STUDIO_ANALYSIS_UNAVAILABLE"
            raise unavailable(code) from None
        finally:
            self._slot.release()

    def close(self):
        if self.engine is not None and not self._closed:
            self._closed = True
            event.remove(self.engine, "before_cursor_execute", self._budget)
            if self._owned:
                self.engine.dispose()
