"""Bound operational reads and restrict histogram invalidation to affected tracks."""
import sqlalchemy as sa
from alembic import op

revision = "0023_operational_read_indexes"
down_revision = "0022_histogram_cache"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index("ix_run_created_at", "runs", ["created_at"])
    op.create_index("ix_operation_state_updated_at", "operation_state", ["updated_at"])
    invalidate_triggers(scoped=True)


def downgrade():
    invalidate_triggers(scoped=False)
    op.drop_index("ix_operation_state_updated_at", table_name="operation_state")
    op.drop_index("ix_run_created_at", table_name="runs")


def sql(statement):
    op.execute(sa.text(statement))


def invalidate_triggers(*, scoped):
    if op.get_bind().dialect.name == "sqlite":
        for name, event, guard, target in (
            ("player", "UPDATE OF disabled,is_test_driver ON players",
             "OLD.disabled IS NOT NEW.disabled OR OLD.is_test_driver IS NOT NEW.is_test_driver",
             "(version_id,vehicle_id) IN (SELECT b.version_id,b.vehicle_id FROM personal_bests p JOIN boards b ON b.id=p.board_id WHERE p.player_id=NEW.id)"),
            ("pb", "DELETE ON personal_bests", "1", board_region("OLD")),
            ("run_delete", "DELETE ON runs", "OLD.status='verified'", board_region("OLD")),
            ("run_retire", "UPDATE OF status ON runs", "OLD.status='verified' AND NEW.status!='verified'", board_region("OLD")),
        ):
            sql(f"DROP TRIGGER histogram_{name}")
            where = " WHERE " + target if scoped else ""
            sql(f"CREATE TRIGGER histogram_{name} AFTER {event} WHEN {guard} BEGIN "
                f"UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0{where}; END")
        for prefix in ("lap_reset", "histogram_reset"):
            for event in ("insert", "update", "delete"):
                sql(f"DROP TRIGGER {prefix}_{event}")
            table, values = ("boards", "lap_revision=lap_revision+1") if prefix == "lap_reset" else (
                "histogram_snapshots", "invalidated=true,next_refresh_at=0")
            flag = "json_extract(manifest,'$.test_population')=1" if table == "boards" else "include_artificial=true"
            for event, refs in (("INSERT", ["NEW"]), ("DELETE", ["OLD"]), ("UPDATE", ["OLD", "NEW"])):
                if event == "UPDATE":
                    changed = " OR ".join(f"json_extract(OLD.details,'$.{p}') IS NOT json_extract(NEW.details,'$.{p}')"
                        for p in ("request.clear_test_records", "created_at", "vehicle_id", "tracks"))
                    guard = f"(OLD.id LIKE 'test-pop-batch:%' OR NEW.id LIKE 'test-pop-batch:%') AND " \
                        f"(json_extract(OLD.details,'$.request.clear_test_records')=1 OR json_extract(NEW.details,'$.request.clear_test_records')=1) AND (OLD.id IS NOT NEW.id OR {changed})"
                else:
                    ref = refs[0]
                    guard = f"{ref}.id LIKE 'test-pop-batch:%' AND json_extract({ref}.details,'$.request.clear_test_records')=1"
                regions = " OR ".join(reset_region(ref + ".details", sqlite=True) for ref in refs)
                where = f" WHERE {flag} AND ({regions})" if scoped else ""
                sql(f"CREATE TRIGGER {prefix}_{event.lower()} AFTER {event} ON operation_state WHEN {guard} "
                    f"BEGIN UPDATE {table} SET {values}{where}; END")
    else:
        if scoped:
            body = """IF TG_TABLE_NAME='players' THEN
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE (version_id,vehicle_id) IN
                  (SELECT b.version_id,b.vehicle_id FROM personal_bests p JOIN boards b ON b.id=p.board_id WHERE p.player_id=NEW.id);
              ELSE UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE (version_id,vehicle_id) IN
                  (SELECT version_id,vehicle_id FROM boards WHERE id=OLD.board_id); END IF;"""
        else:
            body = "UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0;"
        sql(f"CREATE OR REPLACE FUNCTION bmt_histogram_invalidate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN {body} RETURN NULL; END $$")
        for name, table, values, flag in (
            ("bmt_lap_reset", "boards", "lap_revision=lap_revision+1", "manifest->>'test_population'='true'"),
            ("bmt_histogram_reset", "histogram_snapshots", "invalidated=true,next_refresh_at=0", "include_artificial=true"),
        ):
            regions = " OR ".join(reset_region(ref, sqlite=False) for ref in ("previous", "current_data"))
            where = f" WHERE {flag} AND ({regions})" if scoped else ""
            sql(f"""CREATE OR REPLACE FUNCTION {name}() RETURNS trigger LANGUAGE plpgsql AS $$
                DECLARE previous jsonb; current_data jsonb; previous_id text; current_id text;
                BEGIN
                IF TG_OP<>'INSERT' THEN previous=OLD.details::jsonb; previous_id=OLD.id; END IF;
                IF TG_OP<>'DELETE' THEN current_data=NEW.details::jsonb; current_id=NEW.id; END IF;
                IF (previous_id LIKE 'test-pop-batch:%' OR current_id LIKE 'test-pop-batch:%') AND
                  (previous#>>'{{request,clear_test_records}}'='true' OR current_data#>>'{{request,clear_test_records}}'='true') AND
                  (previous_id IS DISTINCT FROM current_id OR previous#>'{{request,clear_test_records}}' IS DISTINCT FROM current_data#>'{{request,clear_test_records}}' OR
                   previous->'created_at' IS DISTINCT FROM current_data->'created_at' OR previous->'vehicle_id' IS DISTINCT FROM current_data->'vehicle_id' OR
                   previous->'tracks' IS DISTINCT FROM current_data->'tracks') THEN
                    UPDATE {table} SET {values}{where};
                END IF; RETURN NULL; END $$""")


def board_region(ref):
    return f"(version_id,vehicle_id) IN (SELECT version_id,vehicle_id FROM boards WHERE id={ref}.board_id)"


def reset_region(ref, *, sqlite):
    if sqlite:
        return f"(vehicle_id=json_extract({ref},'$.vehicle_id') AND version_id IN " \
            f"(SELECT json_extract(value,'$.version_id') FROM json_each({ref},'$.tracks')))"
    return f"(vehicle_id={ref}->>'vehicle_id' AND version_id IN " \
        f"(SELECT item->>'version_id' FROM jsonb_array_elements(COALESCE({ref}->'tracks','[]'::jsonb)) item))"
