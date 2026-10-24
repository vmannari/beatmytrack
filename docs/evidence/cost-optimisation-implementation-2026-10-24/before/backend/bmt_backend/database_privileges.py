"""Explicit per-workload PostgreSQL grants; runtime users never own schema objects."""

import argparse
import os
import re

from sqlalchemy import inspect, text

DEFAULT_ROLES = {"api": "bmt_api", "worker": "bmt_worker", "admin": "bmt_admin"}
# Reviewed schema surface. Future tables receive no automatic runtime grants.
DOMAIN_TABLES = frozenset(
    [
        "account_deletions",
        "achievement_cohort",
        "achievement_competitions",
        "achievement_counts",
        "achievement_facts",
        "achievement_records",
        "achievement_states",
        "board_time_counts",
        "boards",
        "challenge_members",
        "challenge_stage_members",
        "challenge_stage_tickets",
        "challenge_stages",
        "challenge_tickets",
        "challenges",
        "coin_milestones",
        "coin_rewards",
        "coin_wallets",
        "community_acceptances",
        "cosmetic_unlocks",
        "creator_achievement_events",
        "creator_achievement_partitions",
        "deletion_blobs",
        "discovery_bootstrap",
        "discovery_activity",
        "discovery_days",
        "discovery_boundaries",
        "discovery_changes",
        "discovery_collections",
        "discovery_drivers",
        "discovery_entries",
        "discovery_guards",
        "discovery_heads",
        "discovery_members",
        "discovery_owner_jobs",
        "discovery_partitions",
        "discovery_sessions",
        "discovery_storage",
        "discovery_storage_bootstrap",
        "domain_idempotency",
        "entitlements",
        "game_config_deliveries",
        "histogram_demand",
        "histogram_snapshots",
        "lap_best_state",
        "lap_personal_bests",
        "leaderboard_rank_counts",
        "leaderboard_tie_nodes",
        "leaderboard_tie_work",
        "network_health_days",
        "news_bands",
        "news_demand",
        "news_friends",
        "news_items",
        "news_publications",
        "news_track_racers",
        "news_track_reach",
        "news_watches",
        "object_pins",
        "operation_state",
        "personal_bests",
        "player_blocks",
        "players",
        "product_events",
        "product_metrics",
        "product_player_days",
        "product_profiles",
        "product_publications",
        "product_state",
        "publication_intents",
        "publication_slots",
        "publication_uploads",
        "purchases",
        "quality_facts",
        "queue_limits",
        "queue_players",
        "queue_reservations",
        "race_statistics_days",
        "race_statistics_receipts",
        "rate_buckets",
        "ratings",
        "resume_grants",
        "resume_races",
        "resume_receipts",
        "resume_wallets",
        "reward_rank_counts",
        "rivalry_archived_bests",
        "rivalry_bests",
        "rivalry_groups",
        "rivalry_members",
        "rivalry_tickets",
        "rivalry_week_plans",
        "run_tickets",
        "runs",
        "studio_analysis_days",
        "studio_analysis_people",
        "studio_analysis_sessions",
        "studio_analysis_state",
        "studio_assignments",
        "studio_case_events",
        "studio_cases",
        "studio_coin_entries",
        "studio_finance_events",
        "telemetry_actors",
        "telemetry_control",
        "telemetry_credits",
        "telemetry_erasure",
        "telemetry_finishes",
        "telemetry_intake",
        "telemetry_metric_folds",
        "telemetry_metric_partials",
        "telemetry_rollups",
        "telemetry_shared",
        "telemetry_shared_intake",
        "telemetry_work",
        "test_driver_profiles",
        "track_validations",
        "track_versions",
        "tracks",
        "version_finishers",
        "world_circuit_entries",
        "world_circuits",
        "world_ranking_archives",
        "world_ranking_awards",
        "world_ranking_branches",
        "world_ranking_careers",
        "world_ranking_control",
        "world_ranking_players",
        "world_ranking_snapshots",
        "world_ranking_standings",
        "world_work_inputs",
        "world_work_places",
        "world_work_standings",
        "world_work_weekly",
    ]
)
AUTH_TABLES = frozenset(
    ["browser_logins", "identities", "login_challenges", "session_families", "session_tokens"]
)
ADMIN_TABLES = frozenset(
    [
        "game_config_control",
        "game_config_drafts",
        "game_config_releases",
        "product_controls",
        "studio_case_triage",
        "studio_deliveries",
        "studio_experiments",
        "studio_incident_events",
        "studio_incidents",
        "studio_observations",
        "studio_quarantines",
        "studio_releases",
        "studio_saved_views",
        "studio_signals",
        "studio_staff",
        "world_ranking_corrections",
    ]
)
ADMIN_READS = frozenset(
    {
        "studio_experiments",
        "game_config_control",
        "game_config_releases",
        "product_controls",
        "world_ranking_corrections",
    }
)


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", value):
        raise ValueError("Invalid database privilege identifier")
    return '"' + value + '"'


def verify_runtime(engine, settings):
    """Fail closed if an old owner credential reaches a production workload."""
    if (
        settings.environment != "production"
        or engine.dialect.name != "postgresql"
        or settings.workload_role not in DEFAULT_ROLES
    ):
        return
    with engine.connect() as db:
        unsafe = db.scalar(
            text("""SELECT r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR
            r.rolreplication OR r.rolbypassrls OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_auth_members WHERE member=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname=current_schema() AND nspowner=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname=current_schema() AND c.relowner=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname=current_schema() AND p.proowner=r.oid)
            FROM pg_catalog.pg_roles r WHERE rolname=current_user""")
        )
        if unsafe is not False:
            raise RuntimeError(
                "Production runtime database credentials must not own objects or inherit privileged authority"
            )
        forbidden = [("admin_audit", "UPDATE"), ("admin_audit", "DELETE")]
        if settings.workload_role != "admin":
            forbidden.append(("studio_staff", "SELECT"))
        if settings.workload_role != "api":
            forbidden.append(("session_tokens", "SELECT"))
        for table, privilege in forbidden:
            # Includes column grants: table-level REVOKE alone is insufficient.
            allowed = db.scalar(
                text("SELECT has_any_column_privilege(current_user,:table,:privilege)")
                if privilege != "DELETE"
                else text("SELECT has_table_privilege(current_user,:table,:privilege)"),
                {"table": table, "privilege": privilege},
            )
            if allowed:
                raise RuntimeError("Production database grants exceed this workload's authority")
        table, privilege = {
            "api": ("session_tokens", "SELECT"),
            "worker": ("runs", "UPDATE"),
            "admin": ("studio_staff", "UPDATE"),
        }[settings.workload_role]
        if not db.scalar(
            text("SELECT has_table_privilege(current_user,:table,:privilege)"),
            {"table": table, "privilege": privilege},
        ):
            raise RuntimeError("Production database credentials do not match the workload")


def provision_roles(connection, credentials):
    """Privileged bootstrap only. Passwords are bound values, never SQL text/logs."""
    if len(credentials) != 3 or len(set(credentials.values())) != 3:
        raise ValueError("Three distinct workload passwords are required")
    for role, secret in credentials.items():
        identifier(role)
        if not isinstance(secret, str) or not re.fullmatch(r"[A-Za-z0-9_-]{32,128}", secret):
            raise ValueError("Workload passwords must be 32-128 URL-safe characters")
    connection.execute(
        text("""CREATE OR REPLACE FUNCTION pg_temp.bmt_provision_runtime(n text, secret text)
        RETURNS void LANGUAGE plpgsql AS $$
        DECLARE r record;
        BEGIN
          SELECT * INTO r FROM pg_catalog.pg_roles WHERE rolname=n;
          IF FOUND THEN
            IF r.rolsuper OR r.rolreplication OR r.rolbypassrls THEN
              RAISE EXCEPTION 'Refusing an inherently privileged runtime role';
            END IF;
            EXECUTE pg_catalog.format('ALTER ROLE %I LOGIN NOCREATEDB NOCREATEROLE PASSWORD %L', n, secret);
          ELSE
            EXECUTE pg_catalog.format('CREATE ROLE %I LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L', n, secret);
          END IF;
          IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='cloudsqlsuperuser') THEN
            EXECUTE pg_catalog.format('REVOKE cloudsqlsuperuser FROM %I', n);
          END IF;
        END $$""")
    )
    connection.execute(text("REVOKE ALL ON FUNCTION pg_temp.bmt_provision_runtime(text,text) FROM PUBLIC"))
    for role, secret in credentials.items():
        connection.execute(
            text("SELECT pg_temp.bmt_provision_runtime(:role,:secret)"), {"role": role, "secret": secret}
        )


def configure(engine, *, schema="public", roles=None):
    """Run after every migration, from a separate owner/migrator connection."""
    roles = dict(DEFAULT_ROLES if roles is None else roles)
    if set(roles) != set(DEFAULT_ROLES) or len(set(roles.values())) != 3:
        raise ValueError("API, worker and admin need distinct database roles")
    qschema = identifier(schema)
    for role in roles.values():
        identifier(role)
    if engine.dialect.name != "postgresql":
        raise ValueError("Workload grants require PostgreSQL")
    with engine.begin() as connection:
        actual = set(inspect(connection).get_table_names(schema=schema))
        known = (
            DOMAIN_TABLES
            | AUTH_TABLES
            | ADMIN_TABLES
            | {"admin_audit", "alembic_version", "bmt_staging_guard"}
        )
        if actual - known:
            raise RuntimeError("New schema tables require an explicit workload privilege review")
        columns = {
            table: ",".join(
                identifier(c["name"]) for c in inspect(connection).get_columns(table, schema=schema)
            )
            for table in sorted(actual)
        }
        for role in roles.values():
            flags = connection.execute(
                text("""SELECT oid,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls
                FROM pg_catalog.pg_roles WHERE rolname=:role"""),
                {"role": role},
            ).one_or_none()
            if flags is None or any(flags[1:]):
                raise RuntimeError("Runtime roles must be nonprivileged login users")
            if connection.scalar(
                text("SELECT 1 FROM pg_catalog.pg_auth_members WHERE member=:oid LIMIT 1"), {"oid": flags[0]}
            ):
                raise RuntimeError("Runtime roles cannot inherit other role authority")
            if connection.scalar(
                text("""SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
                ON n.oid=c.relnamespace WHERE n.nspname=:schema AND c.relowner=:oid LIMIT 1"""),
                {"schema": schema, "oid": flags[0]},
            ):
                raise RuntimeError("Runtime roles must not own database objects")
            if connection.scalar(
                text("SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname=:schema AND nspowner=:oid"),
                {"schema": schema, "oid": flags[0]},
            ):
                raise RuntimeError("Runtime roles must not own the application schema")
            if connection.scalar(
                text("""SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n
                ON n.oid=p.pronamespace WHERE n.nspname=:schema AND p.proowner=:oid LIMIT 1"""),
                {"schema": schema, "oid": flags[0]},
            ):
                raise RuntimeError("Runtime roles must not own database functions")
            quoted = identifier(role)
            connection.execute(text(f"REVOKE ALL ON SCHEMA {qschema} FROM {quoted}"))
            connection.execute(text(f"GRANT USAGE ON SCHEMA {qschema} TO {quoted}"))
            connection.execute(text(f"REVOKE ALL ON ALL TABLES IN SCHEMA {qschema} FROM {quoted}"))
            for table, names in columns.items():
                connection.execute(
                    text(
                        f"REVOKE SELECT({names}),INSERT({names}),UPDATE({names}),REFERENCES({names}) "
                        f"ON {qschema}.{identifier(table)} FROM {quoted}"
                    )
                )
            connection.execute(text(f"REVOKE ALL ON ALL SEQUENCES IN SCHEMA {qschema} FROM {quoted}"))
            connection.execute(text(f"REVOKE ALL ON ALL FUNCTIONS IN SCHEMA {qschema} FROM {quoted}"))
            connection.execute(
                text(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE ALL ON TABLES FROM {quoted}")
            )
            connection.execute(
                text(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE ALL ON SEQUENCES FROM {quoted}")
            )
            connection.execute(
                text(
                    f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE EXECUTE ON FUNCTIONS FROM {quoted}"
                )
            )
        connection.execute(text(f"REVOKE CREATE ON SCHEMA {qschema} FROM PUBLIC"))
        connection.execute(text(f"REVOKE ALL ON ALL TABLES IN SCHEMA {qschema} FROM PUBLIC"))
        for table, names in columns.items():
            connection.execute(
                text(
                    f"REVOKE SELECT({names}),INSERT({names}),UPDATE({names}),REFERENCES({names}) "
                    f"ON {qschema}.{identifier(table)} FROM PUBLIC"
                )
            )
        connection.execute(text(f"REVOKE ALL ON ALL SEQUENCES IN SCHEMA {qschema} FROM PUBLIC"))
        connection.execute(text(f"REVOKE ALL ON ALL FUNCTIONS IN SCHEMA {qschema} FROM PUBLIC"))
        connection.execute(
            text(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE ALL ON TABLES FROM PUBLIC")
        )
        connection.execute(
            text(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE ALL ON SEQUENCES FROM PUBLIC")
        )
        connection.execute(
            text(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {qschema} REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC")
        )

        def grant(role, privilege, names):
            for name in sorted(set(names) & actual):
                connection.execute(
                    text(f"GRANT {privilege} ON {qschema}.{identifier(name)} TO {identifier(roles[role])}")
                )

        for role in roles:
            grant(role, "SELECT,INSERT,UPDATE,DELETE", DOMAIN_TABLES)
            grant(role, "SELECT", {"alembic_version"})
            connection.execute(text(f"GRANT SELECT ON {qschema}.queue_capacity TO {identifier(roles[role])}"))
            connection.execute(
                text(f"GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA {qschema} TO {identifier(roles[role])}")
            )
            # Existing non-definer projection helpers run with the caller's own grants.
            functions = connection.execute(
                text("""SELECT p.oid::regprocedure::text FROM pg_catalog.pg_proc p
                JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
                WHERE n.nspname=:schema AND NOT p.prosecdef"""),
                {"schema": schema},
            ).scalars()
            for function in functions:
                connection.execute(text(f"GRANT EXECUTE ON FUNCTION {function} TO {identifier(roles[role])}"))
        grant("api", "SELECT,INSERT,UPDATE,DELETE", AUTH_TABLES)
        grant("api", "SELECT", ADMIN_READS)
        grant("worker", "SELECT", ADMIN_READS)
        # The worker activates already-published schedules. It may change only
        # activation metadata and append history, never edit policy or old audit.
        worker = identifier(roles["worker"])
        connection.execute(
            text(f"GRANT UPDATE(revision,active_generation) ON {qschema}.game_config_control TO {worker}")
        )
        connection.execute(text(f"GRANT UPDATE(state) ON {qschema}.game_config_releases TO {worker}"))
        grant("worker", "INSERT", {"admin_audit"})
        grant("admin", "SELECT,INSERT,UPDATE,DELETE", ADMIN_TABLES)
        grant("admin", "SELECT,INSERT", {"admin_audit"})
        # Support can identify providers and revoke sessions, without reading game-token hashes.
        connection.execute(
            text(
                f"GRANT SELECT(id,player_id,provider) ON {qschema}.identities TO {identifier(roles['admin'])}"
            )
        )
        connection.execute(
            text(
                f"GRANT SELECT,UPDATE(revoked) ON {qschema}.session_families TO {identifier(roles['admin'])}"
            )
        )
        connection.execute(
            text(
                f"GRANT EXECUTE ON FUNCTION {qschema}.bmt_redact_removed_audit(text) TO {identifier(roles['worker'])}"
            )
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--migrate", action="store_true")
    parser.add_argument("--provision", action="store_true")
    args = parser.parse_args()
    from .config import Settings
    from .db import make_engine
    from .migrate import upgrade

    settings = Settings.from_env()
    if settings.workload_role != "migrator":
        parser.error("Privilege setup requires the migrator workload and its dedicated credential")
    engine = make_engine(settings.database_url, settings)
    try:
        if args.provision:
            credentials = {
                DEFAULT_ROLES[role]: os.environ.get("BMT_" + role.upper() + "_DB_PASSWORD", "")
                for role in DEFAULT_ROLES
            }
            with engine.begin() as connection:
                provision_roles(connection, credentials)
        if args.migrate:
            upgrade(engine)
        configure(engine)
    finally:
        engine.dispose()
    print("Migrated schema and applied separate workload grants")


if __name__ == "__main__":
    main()
