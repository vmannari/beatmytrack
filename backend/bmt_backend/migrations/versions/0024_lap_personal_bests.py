"""Durable flying-lap minima, PB-only revisions and resumable shadow backfill."""
import importlib

import sqlalchemy as sa
from alembic import op

revision = "0024_lap_personal_bests"
down_revision = "0023_operational_read_indexes"
branch_labels = None
depends_on = None


def sql(statement):
    op.execute(sa.text(statement))


def candidates(where, *, sqlite):
    """Immutable migration SQL. Reject missing, fractional or non-five-lap facts."""
    if sqlite:
        array = "CASE WHEN json_type(r.lap_ticks)='array' THEN r.lap_ticks ELSE '[]' END"
        items = f"json_each({array}) j"
        tick = "CASE WHEN j.type='integer' AND j.value BETWEEN 1 AND 216000 THEN j.value END"
        index = "CAST(j.key AS integer)"
        five = f"json_array_length({array})=5 AND (SELECT count(*) FROM {items} WHERE {tick} IS NOT NULL)=5"
        private = "json_extract(b.manifest,'$.test_population')=1"
        purpose = "coalesce(json_extract(b.manifest,'$.purpose'),'')"
    else:
        array = "CASE WHEN json_typeof(r.lap_ticks)='array' THEN r.lap_ticks ELSE '[]'::json END"
        items = f"json_array_elements({array}) WITH ORDINALITY j(value,ordinal)"
        tick = ("CASE WHEN json_typeof(j.value)='number' AND j.value::text ~ '^[0-9]+$' THEN "
                "CASE WHEN j.value::text::numeric BETWEEN 1 AND 216000 THEN j.value::text::integer END END")
        index = "(j.ordinal-1)::integer"
        five = f"json_array_length({array})=5 AND (SELECT count(*) FROM {items} WHERE {tick} IS NOT NULL)=5"
        private = "b.manifest->>'test_population'='true'"
        purpose = "coalesce(b.manifest->>'purpose','')"
    return f"""SELECT r.board_id,r.player_id,r.id AS run_id,{tick} AS time_ticks,
        {index} AS lap_index,coalesce(r.finished_at,r.created_at) AS achieved_at,r.created_at AS source_created_at
        FROM runs r JOIN boards b ON b.id=r.board_id JOIN players p ON p.id=r.player_id
        JOIN lap_best_state s ON s.board_id=r.board_id CROSS JOIN {items}
        WHERE {where} AND r.status='verified' AND r.time_ticks>0 AND {purpose}<>'creator_test'
        AND {five} AND {index} BETWEEN 1 AND 4
        AND (NOT coalesce({private},false) OR NOT p.is_test_driver OR r.created_at>=s.cutoff)"""


def upsert(selection, *, improve, winning_source=False):
    guard = " WHERE excluded.time_ticks<lap_personal_bests.time_ticks" if improve else (
        " WHERE lap_personal_bests.run_id=OLD.id" if winning_source else "")
    return f"""INSERT INTO lap_personal_bests(board_id,player_id,run_id,time_ticks,lap_index,achieved_at,source_created_at)
        SELECT board_id,player_id,run_id,time_ticks,lap_index,achieved_at,source_created_at FROM ({selection}) c
        ORDER BY time_ticks,achieved_at,run_id,lap_index LIMIT 1
        ON CONFLICT(board_id,player_id) DO UPDATE SET run_id=excluded.run_id,time_ticks=excluded.time_ticks,
            lap_index=excluded.lap_index,achieved_at=excluded.achieved_at,source_created_at=excluded.source_created_at{guard};"""


def reset_repair(region, *, sqlite):
    # An administrative cutoff can retire the old winner while a later accepted
    # attempt already exists. Repair only those affected driver/board subsets.
    selection = candidates(f"""EXISTS(SELECT 1 FROM lap_personal_bests l JOIN runs retired ON retired.id=l.run_id
        WHERE l.board_id=r.board_id AND l.player_id=r.player_id AND retired.created_at<s.cutoff)
        AND p.is_test_driver=true AND {region}""",sqlite=sqlite)
    return f"""INSERT INTO lap_personal_bests(board_id,player_id,run_id,time_ticks,lap_index,achieved_at,source_created_at)
        SELECT board_id,player_id,run_id,time_ticks,lap_index,achieved_at,source_created_at FROM
        (SELECT c.*,row_number() OVER(PARTITION BY board_id,player_id ORDER BY time_ticks,achieved_at,run_id,lap_index) n
         FROM ({selection}) c) ranked WHERE n=1
        ON CONFLICT(board_id,player_id) DO UPDATE SET run_id=excluded.run_id,time_ticks=excluded.time_ticks,
        lap_index=excluded.lap_index,achieved_at=excluded.achieved_at,source_created_at=excluded.source_created_at;"""


def reset_region(details, *, sqlite):
    if sqlite:
        versions = f"SELECT json_extract(value,'$.version_id') FROM json_each({details},'$.tracks')"
    else:
        versions = f"SELECT entry->>'version_id' FROM jsonb_array_elements(coalesce({details}->'tracks','[]'::jsonb)) entry"
    # Preserve the reset API's existing physical-track/all-car clearing scope,
    # including older pinned versions, rather than retaining mismatched cutoffs.
    return f"""b.version_id IN (SELECT v.id FROM track_versions v WHERE v.track_id IN
        (SELECT track_id FROM track_versions WHERE id IN ({versions})))"""


def upgrade():
    op.create_table("lap_personal_bests",
        sa.Column("board_id",sa.String(64),sa.ForeignKey("boards.id"),primary_key=True),
        sa.Column("player_id",sa.String(36),sa.ForeignKey("players.id"),primary_key=True),
        sa.Column("run_id",sa.String(36),sa.ForeignKey("runs.id"),nullable=False),
        sa.Column("time_ticks",sa.Integer(),nullable=False),
        sa.Column("lap_index",sa.Integer(),nullable=False),
        sa.Column("achieved_at",sa.Integer(),nullable=False),
        sa.Column("source_created_at",sa.Integer(),nullable=False),
        sa.CheckConstraint("time_ticks>0"),sa.CheckConstraint("lap_index BETWEEN 1 AND 4"))
    op.create_index("ix_lap_personal_bests_run_id","lap_personal_bests",["run_id"])
    op.create_table("lap_best_state",
        sa.Column("board_id",sa.String(64),sa.ForeignKey("boards.id"),primary_key=True),
        sa.Column("cutoff",sa.Integer(),nullable=False,server_default="0"),
        sa.Column("epoch",sa.Integer(),nullable=False,server_default="0"),
        sa.Column("cursor",sa.String(36),nullable=False,server_default=""),
        sa.Column("complete",sa.Boolean(),nullable=False,server_default=sa.true()),
        sa.Column("invalid_records",sa.Integer(),nullable=False,server_default="0"))
    op.create_index("ix_run_board_player_id","runs",["board_id","player_id","id"])
    op.create_index("ix_run_board_id","runs",["board_id","id"])
    # No history replay in the migration transaction. The worker/maintenance
    # command walks old boards in bounded batches before snapshot publication.
    sql("INSERT INTO lap_best_state(board_id,complete) SELECT id,false FROM boards")
    sql("UPDATE histogram_snapshots SET dirty=true,invalidated=true,next_refresh_at=0")
    sqlite = op.get_bind().dialect.name == "sqlite"
    if sqlite:
        for event in ("insert","update","delete"):
            sql(f"DROP TRIGGER lap_revision_{event}")
            sql(f"DROP TRIGGER lap_reset_{event}")
        for name in ("run_delete","run_retire"):
            sql(f"DROP TRIGGER histogram_{name}")
        sql("CREATE TRIGGER lap_state_board AFTER INSERT ON boards BEGIN INSERT INTO lap_best_state(board_id) VALUES(NEW.id); END")
        for action in ("INSERT","UPDATE"):
            sql(f"""CREATE TRIGGER lap_pb_eligible_{action.lower()} BEFORE {action} ON lap_personal_bests
                WHEN EXISTS(SELECT 1 FROM players p JOIN boards b ON b.id=NEW.board_id
                JOIN lap_best_state s ON s.board_id=b.id WHERE p.id=NEW.player_id AND p.is_test_driver=true
                AND json_extract(b.manifest,'$.test_population')=1 AND NEW.source_created_at<s.cutoff)
                BEGIN SELECT RAISE(IGNORE); END""")
        for event,ref in (("INSERT","NEW"),("DELETE","OLD")):
            sql(f"CREATE TRIGGER lap_pb_{event.lower()} AFTER {event} ON lap_personal_bests BEGIN "
                f"UPDATE boards SET lap_revision=lap_revision+1 WHERE id={ref}.board_id; END")
        sql("""CREATE TRIGGER lap_pb_update AFTER UPDATE ON lap_personal_bests
            WHEN OLD.time_ticks IS NOT NEW.time_ticks BEGIN
            UPDATE boards SET lap_revision=lap_revision+1 WHERE id=NEW.board_id; END""")
        # Removal/correction must hide a stale snapshot immediately, while
        # ordinary improvements retain the existing scheduled cadence.
        for event,guard in (("DELETE","1"),("UPDATE","NEW.time_ticks>OLD.time_ticks")):
            sql(f"""CREATE TRIGGER lap_pb_retire_{event.lower()} AFTER {event} ON lap_personal_bests WHEN {guard} BEGIN
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE
                (version_id,vehicle_id) IN (SELECT version_id,vehicle_id FROM boards WHERE id=OLD.board_id); END""")
        sql("CREATE TRIGGER lap_capture_insert AFTER INSERT ON runs WHEN NEW.status='verified' BEGIN " +
            upsert(candidates("r.id=NEW.id",sqlite=True),improve=True) + " END")
        guard = ("OLD.status IS NOT NEW.status OR OLD.lap_ticks IS NOT NEW.lap_ticks OR OLD.board_id IS NOT NEW.board_id "
                 "OR OLD.player_id IS NOT NEW.player_id OR OLD.created_at IS NOT NEW.created_at OR OLD.time_ticks IS NOT NEW.time_ticks")
        repair = candidates("r.board_id=OLD.board_id AND r.player_id=OLD.player_id",sqlite=True)
        sql(f"CREATE TRIGGER lap_capture_update AFTER UPDATE ON runs WHEN {guard} BEGIN " +
            upsert(candidates('r.id=NEW.id',sqlite=True),improve=True) + " END")
        sql(f"""CREATE TRIGGER lap_repair_update AFTER UPDATE ON runs WHEN ({guard}) AND
            EXISTS(SELECT 1 FROM lap_personal_bests WHERE run_id=OLD.id) BEGIN
            {upsert(repair,improve=False,winning_source=True)}
            DELETE FROM lap_personal_bests WHERE run_id=OLD.id AND NOT EXISTS(SELECT 1 FROM ({repair}) c);
            END""")
        other = candidates("r.board_id=OLD.board_id AND r.player_id=OLD.player_id AND r.id<>OLD.id",sqlite=True)
        sql(f"""CREATE TRIGGER lap_capture_delete BEFORE DELETE ON runs
            WHEN EXISTS(SELECT 1 FROM lap_personal_bests WHERE run_id=OLD.id) BEGIN
            {upsert(other,improve=False,winning_source=True)} DELETE FROM lap_personal_bests WHERE run_id=OLD.id; END""")
        for event in ("INSERT","UPDATE"):
            guard = "NEW.id LIKE 'test-pop-batch:%' AND json_extract(NEW.details,'$.request.clear_test_records')=1"
            if event=="UPDATE":
                changed=" OR ".join(f"json_extract(OLD.details,'$.{p}') IS NOT json_extract(NEW.details,'$.{p}')"
                    for p in ("request.clear_test_records","created_at","vehicle_id","tracks"))
                guard+=f" AND ({changed})"
            region = reset_region("NEW.details",sqlite=True)
            sql(f"""CREATE TRIGGER lap_state_reset_{event.lower()} AFTER {event} ON operation_state WHEN {guard} BEGIN
                UPDATE lap_best_state SET epoch=epoch+1,cutoff=json_extract(NEW.details,'$.created_at')
                WHERE cutoff<json_extract(NEW.details,'$.created_at') AND board_id IN
                (SELECT b.id FROM boards b WHERE json_extract(b.manifest,'$.test_population')=1 AND {region});
                {reset_repair(region,sqlite=True)}
                DELETE FROM lap_personal_bests WHERE player_id IN (SELECT id FROM players WHERE is_test_driver=true)
                AND board_id IN (SELECT b.id FROM boards b WHERE json_extract(b.manifest,'$.test_population')=1 AND {region})
                AND run_id IN (SELECT r.id FROM runs r JOIN lap_best_state s ON s.board_id=r.board_id WHERE r.created_at<s.cutoff); END""")
        for event,refs in (("INSERT",["NEW"]),("DELETE",["OLD"]),("UPDATE",["OLD","NEW"])):
            sql(f"DROP TRIGGER histogram_reset_{event.lower()}")
            if event=="UPDATE":
                changed=" OR ".join(f"json_extract(OLD.details,'$.{p}') IS NOT json_extract(NEW.details,'$.{p}')"
                    for p in ("request.clear_test_records","created_at","vehicle_id","tracks"))
                guard=f"(OLD.id LIKE 'test-pop-batch:%' OR NEW.id LIKE 'test-pop-batch:%') AND " \
                    f"(json_extract(OLD.details,'$.request.clear_test_records')=1 OR json_extract(NEW.details,'$.request.clear_test_records')=1) AND ({changed})"
            else:
                guard=f"{refs[0]}.id LIKE 'test-pop-batch:%' AND json_extract({refs[0]}.details,'$.request.clear_test_records')=1"
            regions=" OR ".join("version_id IN (SELECT b.version_id FROM boards b WHERE " +
                reset_region(ref+".details",sqlite=True)+")" for ref in refs)
            sql(f"""CREATE TRIGGER histogram_reset_{event.lower()} AFTER {event} ON operation_state WHEN {guard} BEGIN
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0
                WHERE include_artificial=true AND ({regions}); END""")
        historical = """UPDATE lap_best_state SET cutoff=coalesce((SELECT max(json_extract(o.details,'$.created_at'))
            FROM operation_state o JOIN boards b ON b.id=lap_best_state.board_id WHERE
            o.id LIKE 'test-pop-batch:%' AND json_extract(o.details,'$.request.clear_test_records')=1
            AND json_extract(b.manifest,'$.test_population')=1 AND """ + reset_region("o.details",sqlite=True) + "),0)"
        sql(historical)
        # Boards first created after a reset inherit the durable cutoff.
        sql("CREATE TRIGGER lap_state_cutoff AFTER INSERT ON lap_best_state BEGIN " + historical + " WHERE board_id=NEW.board_id; END")
        sql(f"""CREATE TRIGGER lap_player_reclassify AFTER UPDATE OF is_test_driver ON players
            WHEN OLD.is_test_driver IS NOT NEW.is_test_driver AND NEW.is_test_driver=true BEGIN
            {reset_repair('p.id=NEW.id',sqlite=True)}
            DELETE FROM lap_personal_bests WHERE player_id=NEW.id AND board_id IN
            (SELECT board_id FROM lap_best_state s WHERE lap_personal_bests.source_created_at<s.cutoff); END""")
    else:
        sql("DROP TRIGGER lap_revision ON runs")
        sql("DROP FUNCTION bmt_lap_revision()")
        sql("DROP TRIGGER lap_reset ON operation_state")
        sql("DROP FUNCTION bmt_lap_reset()")
        for name in ("run_delete","run_retire"):
            sql(f"DROP TRIGGER histogram_{name} ON runs")
        sql("""CREATE FUNCTION bmt_lap_state_board() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            INSERT INTO lap_best_state(board_id) VALUES(NEW.id); RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_state_board AFTER INSERT ON boards FOR EACH ROW EXECUTE FUNCTION bmt_lap_state_board()")
        sql("""CREATE FUNCTION bmt_lap_pb_eligible() RETURNS trigger LANGUAGE plpgsql AS $$
            DECLARE reset_cutoff integer;
            BEGIN
                IF EXISTS(SELECT 1 FROM players p JOIN boards b ON b.id=NEW.board_id
                    WHERE p.id=NEW.player_id AND p.is_test_driver=true AND b.manifest->>'test_population'='true') THEN
                    -- Only artificial private writes take a compatible share
                    -- lock. Real/public acceptance never waits on reset state.
                    SELECT cutoff INTO reset_cutoff FROM lap_best_state WHERE board_id=NEW.board_id FOR SHARE;
                    IF NEW.source_created_at<reset_cutoff THEN RETURN NULL; END IF;
                END IF;
                RETURN NEW;
            END $$""")
        sql("CREATE TRIGGER lap_pb_eligible BEFORE INSERT OR UPDATE ON lap_personal_bests FOR EACH ROW EXECUTE FUNCTION bmt_lap_pb_eligible()")
        sql("""CREATE FUNCTION bmt_lap_pb_revision() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            IF TG_OP='INSERT' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=NEW.board_id;
            ELSIF TG_OP='DELETE' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=OLD.board_id;
            ELSIF OLD.time_ticks IS DISTINCT FROM NEW.time_ticks THEN
                UPDATE boards SET lap_revision=lap_revision+1 WHERE id=NEW.board_id;
            END IF;
            IF TG_OP='DELETE' OR (TG_OP='UPDATE' AND NEW.time_ticks>OLD.time_ticks) THEN
                UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0 WHERE (version_id,vehicle_id) IN
                (SELECT version_id,vehicle_id FROM boards WHERE id=OLD.board_id);
            END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_pb_revision AFTER INSERT OR UPDATE OR DELETE ON lap_personal_bests FOR EACH ROW EXECUTE FUNCTION bmt_lap_pb_revision()")
        repair = candidates("r.board_id=OLD.board_id AND r.player_id=OLD.player_id",sqlite=False)
        other = candidates("r.board_id=OLD.board_id AND r.player_id=OLD.player_id AND r.id<>OLD.id",sqlite=False)
        sql(f"""CREATE FUNCTION bmt_lap_capture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            IF TG_OP='DELETE' THEN
                IF EXISTS(SELECT 1 FROM lap_personal_bests WHERE run_id=OLD.id) THEN
                    {upsert(other,improve=False,winning_source=True)} DELETE FROM lap_personal_bests WHERE run_id=OLD.id;
                END IF; RETURN OLD;
            END IF;
            IF TG_OP='UPDATE' THEN
                IF OLD.status IS NOT DISTINCT FROM NEW.status AND OLD.lap_ticks::text IS NOT DISTINCT FROM NEW.lap_ticks::text
                    AND OLD.board_id IS NOT DISTINCT FROM NEW.board_id AND OLD.player_id IS NOT DISTINCT FROM NEW.player_id
                    AND OLD.created_at IS NOT DISTINCT FROM NEW.created_at AND OLD.time_ticks IS NOT DISTINCT FROM NEW.time_ticks
                    THEN RETURN NULL; END IF;
                IF EXISTS(SELECT 1 FROM lap_personal_bests WHERE run_id=OLD.id) THEN
                    {upsert(repair,improve=False,winning_source=True)}
                    DELETE FROM lap_personal_bests WHERE run_id=OLD.id AND NOT EXISTS(SELECT 1 FROM ({repair}) c);
                END IF;
            END IF;
            {upsert(candidates('r.id=NEW.id',sqlite=False),improve=True)} RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_capture AFTER INSERT OR UPDATE ON runs FOR EACH ROW EXECUTE FUNCTION bmt_lap_capture()")
        sql("CREATE TRIGGER lap_capture_delete BEFORE DELETE ON runs FOR EACH ROW EXECUTE FUNCTION bmt_lap_capture()")
        region = reset_region("NEW.details::jsonb",sqlite=False)
        sql(f"""CREATE FUNCTION bmt_lap_state_reset() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            IF TG_OP='UPDATE' AND OLD.details::jsonb->'created_at' IS NOT DISTINCT FROM NEW.details::jsonb->'created_at'
                AND OLD.details::jsonb->'tracks' IS NOT DISTINCT FROM NEW.details::jsonb->'tracks'
                AND OLD.details::jsonb->'vehicle_id' IS NOT DISTINCT FROM NEW.details::jsonb->'vehicle_id'
                AND OLD.details::jsonb#>'{{request,clear_test_records}}' IS NOT DISTINCT FROM NEW.details::jsonb#>'{{request,clear_test_records}}'
                THEN RETURN NULL; END IF;
            IF NEW.id LIKE 'test-pop-batch:%' AND NEW.details#>>'{{request,clear_test_records}}'='true' THEN
                UPDATE lap_best_state SET epoch=epoch+1,cutoff=(NEW.details->>'created_at')::integer
                WHERE cutoff<(NEW.details->>'created_at')::integer AND board_id IN
                (SELECT b.id FROM boards b WHERE b.manifest->>'test_population'='true' AND {region});
                {reset_repair(region,sqlite=False)}
                DELETE FROM lap_personal_bests WHERE player_id IN (SELECT id FROM players WHERE is_test_driver=true)
                AND board_id IN (SELECT b.id FROM boards b WHERE b.manifest->>'test_population'='true' AND {region})
                AND run_id IN (SELECT r.id FROM runs r JOIN lap_best_state s ON s.board_id=r.board_id WHERE r.created_at<s.cutoff);
            END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_state_reset AFTER INSERT OR UPDATE ON operation_state FOR EACH ROW EXECUTE FUNCTION bmt_lap_state_reset()")
        regions=" OR ".join("version_id IN (SELECT b.version_id FROM boards b WHERE " +
            reset_region(ref,sqlite=False)+")" for ref in ("previous","current_data"))
        sql(f"""CREATE OR REPLACE FUNCTION bmt_histogram_reset() RETURNS trigger LANGUAGE plpgsql AS $$
            DECLARE previous jsonb; current_data jsonb;
            BEGIN
                IF TG_OP<>'INSERT' AND OLD.id LIKE 'test-pop-batch:%' THEN previous=OLD.details::jsonb; END IF;
                IF TG_OP<>'DELETE' AND NEW.id LIKE 'test-pop-batch:%' THEN current_data=NEW.details::jsonb; END IF;
                IF (previous#>>'{{request,clear_test_records}}'='true' OR current_data#>>'{{request,clear_test_records}}'='true')
                    AND (previous#>'{{request,clear_test_records}}' IS DISTINCT FROM current_data#>'{{request,clear_test_records}}'
                    OR previous->'created_at' IS DISTINCT FROM current_data->'created_at'
                    OR previous->'vehicle_id' IS DISTINCT FROM current_data->'vehicle_id'
                    OR previous->'tracks' IS DISTINCT FROM current_data->'tracks') THEN
                    UPDATE histogram_snapshots SET invalidated=true,next_refresh_at=0
                    WHERE include_artificial=true AND ({regions});
                END IF; RETURN NULL;
            END $$""")
        historical = """SELECT coalesce(max((o.details->>'created_at')::integer),0) FROM operation_state o
            JOIN boards b ON b.id=NEW.board_id WHERE o.id LIKE 'test-pop-batch:%'
            AND o.details#>>'{request,clear_test_records}'='true' AND b.manifest->>'test_population'='true'
            AND """ + reset_region("o.details::jsonb",sqlite=False)
        sql(f"""CREATE FUNCTION bmt_lap_state_cutoff() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            NEW.cutoff=({historical}); RETURN NEW; END $$""")
        sql("CREATE TRIGGER lap_state_cutoff BEFORE INSERT ON lap_best_state FOR EACH ROW EXECUTE FUNCTION bmt_lap_state_cutoff()")
        sql("""UPDATE lap_best_state s SET cutoff=coalesce((SELECT max((o.details->>'created_at')::integer)
            FROM operation_state o JOIN boards b ON b.id=s.board_id WHERE o.id LIKE 'test-pop-batch:%'
            AND o.details#>>'{request,clear_test_records}'='true' AND b.manifest->>'test_population'='true'
            AND """ + reset_region("o.details::jsonb",sqlite=False) + "),0)")
        sql(f"""CREATE FUNCTION bmt_lap_player_reclassify() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            {reset_repair('p.id=NEW.id',sqlite=False)}
            DELETE FROM lap_personal_bests WHERE player_id=NEW.id AND board_id IN
            (SELECT board_id FROM lap_best_state s WHERE lap_personal_bests.source_created_at<s.cutoff);
            RETURN NULL; END $$""")
        sql("""CREATE TRIGGER lap_player_reclassify AFTER UPDATE OF is_test_driver ON players FOR EACH ROW
            WHEN (OLD.is_test_driver IS DISTINCT FROM NEW.is_test_driver AND NEW.is_test_driver=true)
            EXECUTE FUNCTION bmt_lap_player_reclassify()""")


def downgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    if sqlite:
        for name in ("lap_state_board","lap_state_cutoff","lap_state_reset_insert","lap_state_reset_update",
                     "lap_pb_insert","lap_pb_update","lap_pb_delete","lap_pb_retire_delete","lap_pb_retire_update",
                     "lap_capture_insert","lap_capture_update","lap_repair_update","lap_capture_delete","lap_player_reclassify",
                     "lap_pb_eligible_insert","lap_pb_eligible_update"):
            sql(f"DROP TRIGGER {name}")
    else:
        for name,table in (("lap_state_board","boards"),("lap_state_cutoff","lap_best_state"),
                           ("lap_state_reset","operation_state"),("lap_pb_revision","lap_personal_bests"),
                           ("lap_capture","runs"),("lap_capture_delete","runs"),("lap_player_reclassify","players"),
                           ("lap_pb_eligible","lap_personal_bests")):
            sql(f"DROP TRIGGER {name} ON {table}")
        for name in ("state_board","state_cutoff","state_reset","pb_revision","capture","player_reclassify","pb_eligible"):
            sql(f"DROP FUNCTION bmt_lap_{name}()")
    op.drop_table("lap_personal_bests")
    op.drop_table("lap_best_state")
    op.drop_index("ix_run_board_player_id",table_name="runs")
    op.drop_index("ix_run_board_id",table_name="runs")
    # Restore the previous source-of-revision and scoped invalidation contracts.
    restore_revisions(sqlite)
    scoped = importlib.import_module("bmt_backend.migrations.versions.0023_operational_read_indexes")
    # Its helper expects the old triggers to exist before replacing them.
    if sqlite:
        for event in ("insert","update","delete"):
            sql(f"CREATE TRIGGER lap_reset_{event} AFTER {event.upper()} ON operation_state BEGIN SELECT 1; END")
        for name,event in (("run_delete","DELETE"),("run_retire","UPDATE")):
            sql(f"CREATE TRIGGER histogram_{name} AFTER {event} ON runs BEGIN SELECT 1; END")
    else:
        sql("CREATE FUNCTION bmt_lap_reset() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$")
        sql("CREATE TRIGGER lap_reset AFTER INSERT OR UPDATE OR DELETE ON operation_state FOR EACH ROW EXECUTE FUNCTION bmt_lap_reset()")
        for name,event in (("run_delete","DELETE"),("run_retire","UPDATE")):
            sql(f"CREATE TRIGGER histogram_{name} AFTER {event} ON runs FOR EACH ROW EXECUTE FUNCTION bmt_histogram_invalidate()")
    scoped.invalidate_triggers(scoped=True)
    sql("UPDATE histogram_snapshots SET dirty=true,invalidated=true,next_refresh_at=0")


def restore_revisions(sqlite):
    if sqlite:
        for event,ref in (("INSERT","NEW"),("DELETE","OLD")):
            sql(f"CREATE TRIGGER lap_revision_{event.lower()} AFTER {event} ON runs WHEN {ref}.status='verified' BEGIN "
                f"UPDATE boards SET lap_revision=lap_revision+1 WHERE id={ref}.board_id; END")
        sql("""CREATE TRIGGER lap_revision_update AFTER UPDATE ON runs
            WHEN (OLD.status='verified' OR NEW.status='verified') AND
            (OLD.status IS NOT NEW.status OR OLD.lap_ticks IS NOT NEW.lap_ticks OR OLD.board_id IS NOT NEW.board_id
             OR OLD.player_id IS NOT NEW.player_id OR OLD.created_at IS NOT NEW.created_at)
            BEGIN UPDATE boards SET lap_revision=lap_revision+1 WHERE id IN(OLD.board_id,NEW.board_id); END""")
    else:
        sql("""CREATE FUNCTION bmt_lap_revision() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
            IF TG_OP='INSERT' THEN
                IF NEW.status='verified' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=NEW.board_id; END IF;
            ELSIF TG_OP='DELETE' THEN
                IF OLD.status='verified' THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id=OLD.board_id; END IF;
            ELSIF (OLD.status='verified' OR NEW.status='verified') AND
                (OLD.status IS DISTINCT FROM NEW.status OR OLD.lap_ticks::text IS DISTINCT FROM NEW.lap_ticks::text
                OR OLD.board_id IS DISTINCT FROM NEW.board_id OR OLD.player_id IS DISTINCT FROM NEW.player_id
                OR OLD.created_at IS DISTINCT FROM NEW.created_at) THEN
                UPDATE boards SET lap_revision=lap_revision+1 WHERE id IN(OLD.board_id,NEW.board_id);
            END IF; RETURN NULL; END $$""")
        sql("CREATE TRIGGER lap_revision AFTER INSERT OR UPDATE OR DELETE ON runs FOR EACH ROW EXECUTE FUNCTION bmt_lap_revision()")
