"""Invalidate shared comparisons for verified lap changes and test resets."""
import sqlalchemy as sa
from alembic import op

revision = "0022_histogram_cache"
down_revision = "0021_challenge_attempts"
branch_labels = None
depends_on = None


def sql(statement):
    op.execute(sa.text(statement))


def upgrade():
    op.add_column("boards", sa.Column("lap_revision", sa.Integer(), nullable=False, server_default="0"))
    op.create_table("histogram_snapshots",
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), primary_key=True),
        sa.Column("vehicle_id", sa.String(80), primary_key=True),
        sa.Column("include_artificial", sa.Boolean(), primary_key=True),
        sa.Column("generation", sa.String(36), nullable=False, server_default=""),
        sa.Column("source_revision", sa.Integer(), nullable=False, server_default="-1"),
        sa.Column("source_fingerprint", sa.String(64), nullable=False, server_default=""),
        sa.Column("population", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("next_refresh_at", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("lease_until", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("lease_token", sa.String(36)),
        sa.Column("invalidated", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("dirty", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("payload", sa.JSON(), nullable=False, server_default=sa.text("'{}'")))
    op.create_index("ix_histogram_snapshots_next_refresh_at", "histogram_snapshots", ["next_refresh_at"])
    op.create_index("ix_histogram_snapshots_dirty_due", "histogram_snapshots", ["dirty", "next_refresh_at", "lease_until"])
    for scope in ("false", "true"):
        sql(f"""INSERT INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
            SELECT DISTINCT version_id,vehicle_id,{scope} FROM boards""")
    if op.get_bind().dialect.name == "sqlite":
        sql("""CREATE TRIGGER histogram_board_dirty AFTER UPDATE OF stats_revision,lap_revision ON boards
            WHEN OLD.stats_revision IS NOT NEW.stats_revision OR OLD.lap_revision IS NOT NEW.lap_revision BEGIN
            UPDATE histogram_snapshots SET dirty=true WHERE version_id=NEW.version_id AND vehicle_id=NEW.vehicle_id; END""")
        for event, ref in (("INSERT", "NEW"), ("DELETE", "OLD")):
            sql(f"""CREATE TRIGGER lap_revision_{event.lower()} AFTER {event} ON runs
                WHEN {ref}.status='verified' BEGIN
                UPDATE boards SET lap_revision=lap_revision+1 WHERE id={ref}.board_id; END""")
        sql("""CREATE TRIGGER lap_revision_update AFTER UPDATE ON runs
            WHEN (OLD.status='verified' OR NEW.status='verified') AND
            (OLD.status IS NOT NEW.status OR OLD.lap_ticks IS NOT NEW.lap_ticks OR
             OLD.board_id IS NOT NEW.board_id OR OLD.player_id IS NOT NEW.player_id OR OLD.created_at IS NOT NEW.created_at)
            BEGIN UPDATE boards SET lap_revision=lap_revision+1 WHERE id IN (OLD.board_id,NEW.board_id); END""")
        for event, ref in (("INSERT", "NEW"), ("DELETE", "OLD")):
            sql(f"""CREATE TRIGGER lap_reset_{event.lower()} AFTER {event} ON operation_state
                WHEN {ref}.id LIKE 'test-pop-batch:%' AND json_extract({ref}.details,'$.request.clear_test_records')=1
                BEGIN UPDATE boards SET lap_revision=lap_revision+1; END""")
        changed = " OR ".join(f"json_extract(OLD.details,'$.{p}') IS NOT json_extract(NEW.details,'$.{p}')"
                              for p in ("request.clear_test_records", "created_at", "vehicle_id", "tracks"))
        sql(f"""CREATE TRIGGER lap_reset_update AFTER UPDATE ON operation_state
            WHEN (OLD.id LIKE 'test-pop-batch:%' OR NEW.id LIKE 'test-pop-batch:%') AND
            (json_extract(OLD.details,'$.request.clear_test_records')=1 OR json_extract(NEW.details,'$.request.clear_test_records')=1)
            AND (OLD.id IS NOT NEW.id OR {changed})
            BEGIN UPDATE boards SET lap_revision=lap_revision+1; END""")
    else:
        sql("""CREATE FUNCTION bmt_histogram_dirty() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            UPDATE histogram_snapshots SET dirty=true WHERE version_id=NEW.version_id AND vehicle_id=NEW.vehicle_id;
            RETURN NULL; END $$""")
        sql("""CREATE TRIGGER histogram_board_dirty AFTER UPDATE OF stats_revision,lap_revision ON boards FOR EACH ROW
            WHEN (OLD.stats_revision IS DISTINCT FROM NEW.stats_revision OR OLD.lap_revision IS DISTINCT FROM NEW.lap_revision)
            EXECUTE FUNCTION bmt_histogram_dirty()""")
        sql("""CREATE FUNCTION bmt_lap_revision() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN
            IF TG_OP='INSERT' THEN
              IF NEW.status='verified' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=NEW.board_id; END IF;
            ELSIF TG_OP='DELETE' THEN
              IF OLD.status='verified' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=OLD.board_id; END IF;
            ELSIF (OLD.status='verified' OR NEW.status='verified') AND
              (OLD.status IS DISTINCT FROM NEW.status OR OLD.lap_ticks::text IS DISTINCT FROM NEW.lap_ticks::text OR
               OLD.board_id IS DISTINCT FROM NEW.board_id OR OLD.player_id IS DISTINCT FROM NEW.player_id OR
               OLD.created_at IS DISTINCT FROM NEW.created_at) THEN
              UPDATE boards SET lap_revision=lap_revision+1 WHERE id IN (OLD.board_id,NEW.board_id);
            END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_revision AFTER INSERT OR UPDATE OR DELETE ON runs FOR EACH ROW EXECUTE FUNCTION bmt_lap_revision()")
        sql("""CREATE FUNCTION bmt_lap_reset() RETURNS trigger LANGUAGE plpgsql AS $$
            DECLARE previous jsonb; current_data jsonb; previous_id text; current_id text;
            BEGIN
              IF TG_OP<>'INSERT' THEN previous=OLD.details::jsonb; previous_id=OLD.id; END IF;
              IF TG_OP<>'DELETE' THEN current_data=NEW.details::jsonb; current_id=NEW.id; END IF;
              IF (previous_id LIKE 'test-pop-batch:%' OR current_id LIKE 'test-pop-batch:%') AND
                (previous#>>'{request,clear_test_records}'='true' OR current_data#>>'{request,clear_test_records}'='true') AND
                (previous_id IS DISTINCT FROM current_id OR previous#>'{request,clear_test_records}' IS DISTINCT FROM current_data#>'{request,clear_test_records}' OR
                 previous->'created_at' IS DISTINCT FROM current_data->'created_at' OR previous->'vehicle_id' IS DISTINCT FROM current_data->'vehicle_id' OR
                 previous->'tracks' IS DISTINCT FROM current_data->'tracks') THEN
                UPDATE boards SET lap_revision=lap_revision+1;
              END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_reset AFTER INSERT OR UPDATE OR DELETE ON operation_state FOR EACH ROW EXECUTE FUNCTION bmt_lap_reset()")
    snapshot_triggers()


def snapshot_triggers():
    invalidate = "UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0;"
    if op.get_bind().dialect.name == "sqlite":
        for scope in ("false", "true"):
            sql(f"""INSERT OR IGNORE INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
                SELECT v.id,j.key,{scope} FROM track_versions v,json_each(v.manifest,'$.vehicles') j WHERE v.state='published'""")
        for event in ("INSERT", "UPDATE OF state,manifest"):
            name = "insert" if event == "INSERT" else "update"
            sql(f"""CREATE TRIGGER histogram_version_{name} AFTER {event} ON track_versions WHEN NEW.state='published' BEGIN
                INSERT OR IGNORE INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
                SELECT NEW.id,key,false FROM json_each(NEW.manifest,'$.vehicles');
                INSERT OR IGNORE INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
                SELECT NEW.id,key,true FROM json_each(NEW.manifest,'$.vehicles');
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE version_id=NEW.id; END""")
        sql("""CREATE TRIGGER histogram_board_insert AFTER INSERT ON boards BEGIN
            INSERT OR IGNORE INTO histogram_snapshots(version_id,vehicle_id,include_artificial) VALUES(NEW.version_id,NEW.vehicle_id,false);
            INSERT OR IGNORE INTO histogram_snapshots(version_id,vehicle_id,include_artificial) VALUES(NEW.version_id,NEW.vehicle_id,true); END""")
        conditions = [("player", "UPDATE OF disabled,is_test_driver ON players", "OLD.disabled IS NOT NEW.disabled OR OLD.is_test_driver IS NOT NEW.is_test_driver"),
                      ("pb", "DELETE ON personal_bests", "1"),
                      ("run_delete", "DELETE ON runs", "OLD.status='verified'"),
                      ("run_retire", "UPDATE OF status ON runs", "OLD.status='verified' AND NEW.status!='verified'")]
        for name, event, condition in conditions:
            sql(f"CREATE TRIGGER histogram_{name} AFTER {event} WHEN {condition} BEGIN {invalidate} END")
        # Reset rows can change eligibility even when the retained PB did not.
        for event, ref in (("INSERT", "NEW"), ("DELETE", "OLD")):
            sql(f"""CREATE TRIGGER histogram_reset_{event.lower()} AFTER {event} ON operation_state
                WHEN {ref}.id LIKE 'test-pop-batch:%' AND json_extract({ref}.details,'$.request.clear_test_records')=1
                BEGIN {invalidate} END""")
        changed = " OR ".join(f"json_extract(OLD.details,'$.{p}') IS NOT json_extract(NEW.details,'$.{p}')"
                              for p in ("request.clear_test_records", "created_at", "vehicle_id", "tracks"))
        sql(f"""CREATE TRIGGER histogram_reset_update AFTER UPDATE ON operation_state
            WHEN (OLD.id LIKE 'test-pop-batch:%' OR NEW.id LIKE 'test-pop-batch:%') AND
            (json_extract(OLD.details,'$.request.clear_test_records')=1 OR json_extract(NEW.details,'$.request.clear_test_records')=1)
            AND ({changed} OR OLD.id IS NOT NEW.id) BEGIN {invalidate} END""")
    else:
        for scope in ("false", "true"):
            sql(f"""INSERT INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
                SELECT v.id,j.key,{scope} FROM track_versions v CROSS JOIN LATERAL json_each(v.manifest->'vehicles') j
                WHERE v.state='published' ON CONFLICT DO NOTHING""")
        sql("""CREATE FUNCTION bmt_histogram_version() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            IF NEW.state='published' THEN
                INSERT INTO histogram_snapshots(version_id,vehicle_id,include_artificial)
                SELECT NEW.id,j.key,s.scope FROM json_each(NEW.manifest->'vehicles') j CROSS JOIN (VALUES(false),(true)) s(scope)
                ON CONFLICT DO NOTHING;
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE version_id=NEW.id;
            END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER histogram_version AFTER INSERT OR UPDATE OF state,manifest ON track_versions FOR EACH ROW EXECUTE FUNCTION bmt_histogram_version()")
        sql("""CREATE FUNCTION bmt_histogram_board() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            INSERT INTO histogram_snapshots(version_id,vehicle_id,include_artificial) VALUES
                (NEW.version_id,NEW.vehicle_id,false),(NEW.version_id,NEW.vehicle_id,true) ON CONFLICT DO NOTHING;
            RETURN NULL; END $$""")
        sql("CREATE TRIGGER histogram_board_insert AFTER INSERT ON boards FOR EACH ROW EXECUTE FUNCTION bmt_histogram_board()")
        sql(f"CREATE FUNCTION bmt_histogram_invalidate() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN {invalidate} RETURN NULL; END $$")
        for name, event, condition in [
            ("player", "UPDATE OF disabled,is_test_driver ON players", "OLD.disabled IS DISTINCT FROM NEW.disabled OR OLD.is_test_driver IS DISTINCT FROM NEW.is_test_driver"),
            ("pb", "DELETE ON personal_bests", "true"),
            ("run_delete", "DELETE ON runs", "OLD.status='verified'"),
            ("run_retire", "UPDATE OF status ON runs", "OLD.status='verified' AND NEW.status!='verified'")]:
            sql(f"CREATE TRIGGER histogram_{name} AFTER {event} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION bmt_histogram_invalidate()")
        # The reset revision trigger already distinguishes reset metadata from progress.
        sql(f"""CREATE FUNCTION bmt_histogram_reset() RETURNS trigger LANGUAGE plpgsql AS $$
            DECLARE previous jsonb; current_data jsonb;
            BEGIN
              IF TG_OP<>'INSERT' AND OLD.id LIKE 'test-pop-batch:%' THEN previous=OLD.details::jsonb; END IF;
              IF TG_OP<>'DELETE' AND NEW.id LIKE 'test-pop-batch:%' THEN current_data=NEW.details::jsonb; END IF;
              IF (previous#>>'{{request,clear_test_records}}'='true' OR current_data#>>'{{request,clear_test_records}}'='true') AND
                (previous#>'{{request,clear_test_records}}' IS DISTINCT FROM current_data#>'{{request,clear_test_records}}' OR
                 previous->'created_at' IS DISTINCT FROM current_data->'created_at' OR previous->'vehicle_id' IS DISTINCT FROM current_data->'vehicle_id' OR
                 previous->'tracks' IS DISTINCT FROM current_data->'tracks') THEN {invalidate} END IF;
              RETURN NULL; END $$""")
        sql("CREATE TRIGGER histogram_reset AFTER INSERT OR UPDATE OR DELETE ON operation_state FOR EACH ROW EXECUTE FUNCTION bmt_histogram_reset()")


def downgrade():
    if op.get_bind().dialect.name == "sqlite":
        for name in ("board_insert", "board_dirty", "version_insert", "version_update", "player", "pb", "run_delete", "run_retire", "reset_insert", "reset_update", "reset_delete"):
            sql(f"DROP TRIGGER histogram_{name}")
        for prefix in ("lap_revision", "lap_reset"):
            for event in ("insert", "update", "delete"):
                sql(f"DROP TRIGGER {prefix}_{event}")
    else:
        for name, table in (("board_insert", "boards"), ("board_dirty", "boards"), ("version", "track_versions"), ("player", "players"), ("pb", "personal_bests"), ("run_delete", "runs"), ("run_retire", "runs"), ("reset", "operation_state")):
            sql(f"DROP TRIGGER histogram_{name} ON {table}")
        for name in ("board", "dirty", "version", "invalidate", "reset"):
            sql(f"DROP FUNCTION bmt_histogram_{name}()")
        sql("DROP TRIGGER lap_revision ON runs")
        sql("DROP TRIGGER lap_reset ON operation_state")
        sql("DROP FUNCTION bmt_lap_revision()")
        sql("DROP FUNCTION bmt_lap_reset()")
    op.drop_column("boards", "lap_revision")
    op.drop_table("histogram_snapshots")
