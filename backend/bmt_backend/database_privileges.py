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
        "object_garbage_candidates",
        "object_partitions",
        "object_packs",
        "packed_objects",
        "private_archive_keys",
        "cost_archive_chunks",
        "coin_archive_metrics",
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
CRUD = ("SELECT", "INSERT", "UPDATE", "DELETE")
COLUMN_PRIVILEGES = ("SELECT", "INSERT", "UPDATE", "REFERENCES")
KNOWN_RELATIONS = DOMAIN_TABLES | AUTH_TABLES | ADMIN_TABLES | {
    "admin_audit", "alembic_version", "bmt_staging_guard", "queue_capacity"
}
HELPERS = {
    ("bmt_finish_delta", "text, text, integer, integer"): "void",
    ("bmt_tick_delta", "text, integer, integer, integer"): "void",
    ("bmt_queue_reserve", "text, text, text"): "void",
    ("bmt_reward_rank_delta", "text, text, integer, integer, integer"): "void",
    ("bmt_leaderboard_time", "text, text, integer, integer, integer"): "void",
    ("bmt_leaderboard_tie", "text, integer, text, integer"): "void",
    ("discovery_short_grams", "text"): "text[]",
}
TRIGGERS = frozenset([
    "bmt_histogram_board", "bmt_histogram_dirty", "bmt_histogram_invalidate",
    "bmt_histogram_reset", "bmt_histogram_version", "bmt_lap_capture",
    "bmt_lap_pb_eligible", "bmt_lap_pb_revision", "bmt_lap_player_reclassify",
    "bmt_lap_state_board", "bmt_lap_state_cutoff", "bmt_lap_state_reset",
    "bmt_leaderboard_pb", "bmt_leaderboard_player", "bmt_pb_projection",
    "bmt_pb_revision", "bmt_player_board_revision", "bmt_queue_delta",
    "bmt_reward_rank_pb", "bmt_reward_rank_player", "discovery_players_update",
    "discovery_runs_insert", "discovery_runs_update", "discovery_track_versions_delete",
    "discovery_track_versions_insert", "discovery_track_versions_update",
    "discovery_tracks_delete", "discovery_tracks_insert", "discovery_tracks_update",
])


def relation_policy(workload):
    """One source for provisioning and effective table/column verification."""
    policy = {}

    def grant(tables, privileges):
        for table in tables:
            policy.setdefault(table, {}).update(dict.fromkeys(privileges))

    grant(DOMAIN_TABLES, CRUD)
    grant({"alembic_version", "queue_capacity"}, ("SELECT",))
    if workload == "api":
        grant(AUTH_TABLES, CRUD)
        grant(ADMIN_READS, ("SELECT",))
    elif workload == "worker":
        grant(ADMIN_READS, ("SELECT",))
        grant({"admin_audit"}, ("INSERT",))
        policy["game_config_control"]["UPDATE"] = {"revision", "active_generation"}
        policy["game_config_releases"]["UPDATE"] = {"state"}
    elif workload == "admin":
        grant(ADMIN_TABLES, CRUD)
        grant({"admin_audit"}, ("SELECT", "INSERT"))
        policy["identities"] = {"SELECT": {"id", "player_id", "provider"}}
        policy["session_families"] = {"SELECT": None, "UPDATE": {"revoked"}}
    else:
        raise ValueError("Unknown runtime workload")
    return policy


def reviewed_function(row):
    signature = row["proname"], row["args"]
    if row["prosecdef"]:
        return (signature == ("bmt_redact_removed_audit", "text") and row["returns"] == "void"
                and row["proconfig"] == ["search_path=pg_catalog"])
    return (row["extension"] == "pg_trgm"
            or HELPERS.get(signature) == row["returns"]
            or (row["proname"] in TRIGGERS and not row["args"] and row["returns"] == "trigger"))


def function_allowed(row, workload, schema):
    return (reviewed_function(row) and (row["schema"] == schema or row["extension"] == "pg_trgm")
            and (not row["prosecdef"] or workload == "worker"))


def functions(connection):
    return connection.execute(text("""SELECT p.oid,p.proname,n.nspname AS schema,
        oidvectortypes(p.proargtypes) AS args,p.prorettype::regtype::text AS returns,
        p.prosecdef,p.proconfig,e.extname AS extension,
        has_function_privilege(p.oid,'EXECUTE') AS executable,
        has_function_privilege(p.oid,'EXECUTE WITH GRANT OPTION') AS delegable
        FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
        LEFT JOIN pg_catalog.pg_depend d ON d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e'
        LEFT JOIN pg_catalog.pg_extension e ON e.oid=d.refobjid
        WHERE n.nspname !~ '^pg_' AND n.nspname<>'information_schema'""")).mappings().all()


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(r"[a-z][a-z0-9_]{0,62}", value):
        raise ValueError("Invalid database privilege identifier")
    return '"' + value + '"'


def verify_runtime(engine, settings):
    """Read-only, effective permission checks, including PUBLIC and column ACLs."""
    if (
        settings.environment != "production"
        or engine.dialect.name != "postgresql"
        or settings.workload_role not in DEFAULT_ROLES
    ):
        return
    workload = settings.workload_role
    policy = relation_policy(workload)
    with engine.connect() as db:
        schema = db.scalar(text("SELECT current_schema()"))
        unsafe = db.scalar(
            text("""SELECT r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR
            r.rolreplication OR r.rolbypassrls OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_auth_members WHERE member=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname !~ '^pg_' AND nspname<>'information_schema' AND nspowner=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname !~ '^pg_' AND n.nspname<>'information_schema' AND c.relowner=r.oid) OR EXISTS
            (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
             WHERE n.nspname !~ '^pg_' AND n.nspname<>'information_schema' AND p.proowner=r.oid)
            FROM pg_catalog.pg_roles r WHERE rolname=current_user""")
        )
        if unsafe is not False:
            raise RuntimeError(
                "Production runtime database credentials must not own objects or inherit privileged authority"
            )
        if not schema or db.scalar(text("""SELECT has_database_privilege(current_database(),'CREATE') OR EXISTS
            (SELECT 1 FROM pg_namespace WHERE nspname !~ '^pg_' AND nspname<>'information_schema'
             AND (has_schema_privilege(oid,'CREATE') OR has_schema_privilege(oid,'USAGE WITH GRANT OPTION')))""")):
            raise RuntimeError("Production runtime cannot create database/schema objects or delegate access")
        privileges = (*CRUD, "REFERENCES", "TRIGGER", "TRUNCATE")
        if db.dialect.server_version_info >= (17,):
            privileges += ("MAINTAIN",)
        # Constant privilege names only; object names/columns arrive as catalog data.
        values = ",".join("('" + p + "')" for p in privileges)
        relations = db.execute(text(f"""SELECT c.oid,c.relname,n.nspname AS schema,
            ARRAY(SELECT p FROM (VALUES {values}) AS v(p) WHERE has_table_privilege(c.oid,p)) AS privileges,
            ARRAY(SELECT p FROM (VALUES {values}) AS v(p) WHERE has_table_privilege(c.oid,p||' WITH GRANT OPTION')) AS delegable
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE c.relkind IN ('r','p','v','m','f') AND n.nspname !~ '^pg_' AND n.nspname<>'information_schema'""")).mappings().all()
        for row in relations:
            expected = policy.get(row["relname"], {}) if row["schema"] == schema else {}
            if (row["schema"] == schema and row["relname"] not in KNOWN_RELATIONS
                    or row["delegable"]
                    or set(row["privileges"]) != {p for p, columns in expected.items() if columns is None}):
                raise RuntimeError("Production database grants exceed or differ from the workload policy")
        columns = db.execute(text("""SELECT c.relname,n.nspname AS schema,a.attname,
            ARRAY(SELECT p FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES']) p
                WHERE has_column_privilege(c.oid,a.attnum,p)) AS privileges,
            ARRAY(SELECT p FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES']) p
                WHERE has_column_privilege(c.oid,a.attnum,p||' WITH GRANT OPTION')) AS delegable
            FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE a.attnum>0 AND NOT a.attisdropped AND c.relkind IN ('r','p','v','m','f')
            AND n.nspname !~ '^pg_' AND n.nspname<>'information_schema'""")).mappings().all()
        for row in columns:
            expected = policy.get(row["relname"], {}) if row["schema"] == schema else {}
            allowed = {p for p, names in expected.items() if p in COLUMN_PRIVILEGES
                       and (names is None or row["attname"] in names)}
            if row["delegable"] or set(row["privileges"]) != allowed:
                raise RuntimeError("Production database column grants differ from the workload policy")
        sequences = db.execute(text("""SELECT c.oid,n.nspname AS schema,
            EXISTS(SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid=d.refobjid
                WHERE d.classid='pg_class'::regclass AND d.objid=c.oid AND d.deptype IN ('a','i')
                AND t.relnamespace=c.relnamespace) AS attached,
            has_sequence_privilege(c.oid,'USAGE') AS usage,has_sequence_privilege(c.oid,'SELECT') AS reading,
            has_sequence_privilege(c.oid,'UPDATE') AS writing,
            has_sequence_privilege(c.oid,'USAGE WITH GRANT OPTION') OR
            has_sequence_privilege(c.oid,'SELECT WITH GRANT OPTION') OR
            has_sequence_privilege(c.oid,'UPDATE WITH GRANT OPTION') AS delegable
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE c.relkind='S' AND n.nspname !~ '^pg_' AND n.nspname<>'information_schema'""")).mappings().all()
        for row in sequences:
            allowed = row["schema"] == schema and row["attached"]
            if row["delegable"] or row["writing"] or row["usage"] != allowed or row["reading"] != allowed:
                raise RuntimeError("Production database sequence grants differ from the workload policy")
        for row in functions(db):
            if row["delegable"] or row["executable"] != function_allowed(row, workload, schema):
                raise RuntimeError("Production database function grants differ from the workload policy")
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
        inspector = inspect(connection)
        actual = (set(inspector.get_table_names(schema=schema))
                  | set(inspector.get_view_names(schema=schema))
                  | set(inspector.get_materialized_view_names(schema=schema)))
        if actual - KNOWN_RELATIONS:
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

        reviewed = [row for row in functions(connection) if row["schema"] == schema]
        if any(not reviewed_function(row) for row in reviewed):
            raise RuntimeError("New database functions require an explicit workload privilege review")
        sequences = connection.execute(text("""SELECT c.relname,EXISTS
            (SELECT 1 FROM pg_depend d JOIN pg_class t ON t.oid=d.refobjid
             WHERE d.classid='pg_class'::regclass AND d.objid=c.oid AND d.deptype IN ('a','i')
             AND t.relnamespace=c.relnamespace) AS attached
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE c.relkind='S' AND n.nspname=:schema"""), {"schema": schema}).mappings().all()
        if any(not row["attached"] for row in sequences):
            raise RuntimeError("New database sequences require an explicit workload privilege review")
        for workload, name in roles.items():
            quoted = identifier(name)
            for table, privileges in relation_policy(workload).items():
                if table not in actual:
                    continue
                for privilege, names in privileges.items():
                    columns_clause = "(" + ",".join(identifier(c) for c in sorted(names)) + ")" if names else ""
                    connection.execute(text(
                        f"GRANT {privilege}{columns_clause} ON {qschema}.{identifier(table)} TO {quoted}"))
            for row in sequences:
                connection.execute(text(f"GRANT USAGE,SELECT ON {qschema}.{identifier(row['relname'])} TO {quoted}"))
            for row in reviewed:
                if function_allowed(row, workload, schema):
                    # regprocedure is emitted by PostgreSQL with identifier quoting.
                    signature = connection.scalar(text("SELECT CAST(:oid AS oid)::regprocedure::text"), {"oid": row["oid"]})
                    connection.execute(text(f"GRANT EXECUTE ON FUNCTION {signature} TO {quoted}"))


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
