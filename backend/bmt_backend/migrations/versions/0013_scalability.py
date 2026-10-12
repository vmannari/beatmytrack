"""Exact bounded competition projections, constant-cost admission and read indexes."""
import sqlalchemy as sa
from alembic import op

revision = "0013_scalability"
down_revision = "0012_test_drivers"
branch_labels = None
depends_on = None


def sql(statement):
    op.execute(sa.text(statement))


def upgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    op.add_column("queue_players", sa.Column("pending", sa.Integer(), nullable=False, server_default="0"))
    if not sqlite:
        op.alter_column("queue_players", "last_claim_at", type_=sa.BigInteger())
    for table, column in (("track_versions", "verified_finishers"), ("boards", "public_count"), ("boards", "all_count")):
        op.add_column(table, sa.Column(column, sa.Integer(), nullable=False, server_default="0"))
    op.create_table("queue_capacity", sa.Column("id", sa.Integer(), primary_key=True),
                    sa.Column("pending", sa.Integer(), nullable=False))
    sql("INSERT INTO queue_capacity VALUES (1, 0)")
    op.create_table("board_time_counts",
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("time_ticks", sa.Integer(), primary_key=True),
        sa.Column("public_count", sa.Integer(), nullable=False),
        sa.Column("all_count", sa.Integer(), nullable=False))
    op.create_table("version_finishers",
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("board_count", sa.Integer(), nullable=False))
    for name, table, fields in (
        ("ix_version_finishers_player_id", "version_finishers", ["player_id"]),
        ("ix_pb_player_recent", "personal_bests", ["player_id", "achieved_at", "board_id"]),
        ("ix_validation_claim", "track_validations", ["status", "lease_until", "created_at"]),
        ("ix_rivalry_pending", "rivalry_tickets", ["group_id", "ticket_id"]),
        ("ix_rivalry_previous", "rivalry_members", ["player_id", "acknowledged", "week_start"]),
        ("ix_track_latest", "track_versions", ["track_id", "state", "number"]),
    ):
        op.create_index(name, table, fields)
    sql("""INSERT INTO board_time_counts SELECT pb.board_id, pb.time_ticks,
        SUM(CASE WHEN NOT p.disabled AND NOT p.is_test_driver THEN 1 ELSE 0 END),
        SUM(CASE WHEN NOT p.disabled THEN 1 ELSE 0 END)
        FROM personal_bests pb JOIN players p ON p.id=pb.player_id GROUP BY pb.board_id,pb.time_ticks""")
    sql("""UPDATE boards SET public_count=COALESCE((SELECT SUM(public_count) FROM board_time_counts c WHERE c.board_id=boards.id),0),
        all_count=COALESCE((SELECT SUM(all_count) FROM board_time_counts c WHERE c.board_id=boards.id),0)""")
    regular = "json_extract(b.manifest,'$.purpose') IS NULL AND COALESCE(json_extract(b.manifest,'$.test_population'),0)=0" if sqlite else "b.manifest->>'purpose' IS NULL AND COALESCE(b.manifest->>'test_population','false') <> 'true'"
    sql(f"""INSERT INTO version_finishers SELECT b.version_id,pb.player_id,COUNT(*) FROM personal_bests pb
        JOIN boards b ON b.id=pb.board_id WHERE {regular} GROUP BY b.version_id,pb.player_id""")
    sql("""UPDATE track_versions SET verified_finishers=(SELECT COUNT(*) FROM version_finishers f
        JOIN players p ON p.id=f.player_id WHERE f.version_id=track_versions.id AND NOT p.disabled AND NOT p.is_test_driver)""")
    sql("""INSERT INTO queue_players (player_id,last_claim_at,pending) SELECT id,0,0 FROM players
        WHERE id NOT IN (SELECT player_id FROM queue_players)""")
    sql("""UPDATE queue_players SET pending=(SELECT COUNT(*) FROM runs r WHERE r.player_id=queue_players.player_id AND r.status IN ('queued','verifying'))+
        (SELECT COUNT(*) FROM track_validations j JOIN track_versions v ON v.id=j.version_id JOIN tracks t ON t.id=v.track_id
        WHERE t.owner_id=queue_players.player_id AND j.status IN ('queued','validating'))""")
    sql("UPDATE queue_capacity SET pending=(SELECT COALESCE(SUM(pending),0) FROM queue_players)")
    if sqlite:
        sqlite_triggers()
        sql("CREATE INDEX ix_compatible_versions ON track_versions(state, json_extract(manifest,'$.rules_key'), json_extract(manifest,'$.physics_version'), id)")
    else:
        postgres_triggers()
        sql("CREATE INDEX ix_compatible_versions ON track_versions(state, (manifest->>'rules_key'), (manifest->>'physics_version'), id)")


def sqlite_pb(ref, delta):
    visible = f"(SELECT CASE WHEN NOT disabled AND NOT is_test_driver THEN 1 ELSE 0 END FROM players WHERE id={ref}.player_id)"
    active = f"(SELECT CASE WHEN NOT disabled THEN 1 ELSE 0 END FROM players WHERE id={ref}.player_id)"
    regular = f"(SELECT json_extract(manifest,'$.purpose') IS NULL AND COALESCE(json_extract(manifest,'$.test_population'),0)=0 FROM boards WHERE id={ref}.board_id)"
    version = f"(SELECT version_id FROM boards WHERE id={ref}.board_id)"
    ticks = f"""INSERT INTO board_time_counts VALUES ({ref}.board_id,{ref}.time_ticks,{delta}*{visible},{delta}*{active})
        ON CONFLICT(board_id,time_ticks) DO UPDATE SET public_count=public_count+{delta}*{visible}, all_count=all_count+{delta}*{active};
        DELETE FROM board_time_counts WHERE board_id={ref}.board_id AND time_ticks={ref}.time_ticks AND public_count=0 AND all_count=0;
        UPDATE boards SET public_count=public_count+{delta}*{visible},all_count=all_count+{delta}*{active} WHERE id={ref}.board_id;"""
    if delta == 1:
        finish = f"""UPDATE track_versions SET verified_finishers=verified_finishers+{visible}
            WHERE id={version} AND {regular} AND NOT EXISTS(SELECT 1 FROM version_finishers WHERE version_id={version} AND player_id={ref}.player_id);
            INSERT INTO version_finishers SELECT {version},{ref}.player_id,1 WHERE {regular}
            ON CONFLICT(version_id,player_id) DO UPDATE SET board_count=board_count+1;"""
    else:
        finish = f"""UPDATE track_versions SET verified_finishers=verified_finishers-{visible} WHERE id={version} AND {regular}
            AND EXISTS(SELECT 1 FROM version_finishers WHERE version_id={version} AND player_id={ref}.player_id AND board_count=1);
            UPDATE version_finishers SET board_count=board_count-1 WHERE version_id={version} AND player_id={ref}.player_id AND {regular};
            DELETE FROM version_finishers WHERE version_id={version} AND player_id={ref}.player_id AND board_count=0;"""
    return ticks + finish


def sqlite_triggers():
    for event in ("INSERT", "UPDATE", "DELETE"):
        body = (sqlite_pb("OLD", -1) if event != "INSERT" else "") + (sqlite_pb("NEW", 1) if event != "DELETE" else "")
        sql(f"CREATE TRIGGER pb_projection_{event.lower()} AFTER {event} ON personal_bests BEGIN {body} END")
    # 0012's SQLite table rebuild discarded the original invalidation trigger.
    sql("DROP TRIGGER IF EXISTS player_board_revision")
    public_delta = "(CASE WHEN NOT NEW.disabled AND NOT NEW.is_test_driver THEN 1 ELSE 0 END)-(CASE WHEN NOT OLD.disabled AND NOT OLD.is_test_driver THEN 1 ELSE 0 END)"
    all_delta = "(CASE WHEN NOT NEW.disabled THEN 1 ELSE 0 END)-(CASE WHEN NOT OLD.disabled THEN 1 ELSE 0 END)"
    sql(f"""CREATE TRIGGER player_board_revision AFTER UPDATE OF disabled,is_test_driver ON players
        WHEN OLD.disabled != NEW.disabled OR OLD.is_test_driver != NEW.is_test_driver BEGIN
        INSERT INTO board_time_counts SELECT board_id,time_ticks,{public_delta},{all_delta} FROM personal_bests WHERE player_id=NEW.id
        ON CONFLICT(board_id,time_ticks) DO UPDATE SET public_count=public_count+({public_delta}),all_count=all_count+({all_delta});
        UPDATE boards SET stats_revision=stats_revision+1,public_count=public_count+({public_delta}),all_count=all_count+({all_delta})
        WHERE id IN (SELECT board_id FROM personal_bests WHERE player_id=NEW.id);
        UPDATE track_versions SET verified_finishers=verified_finishers+({public_delta}) WHERE id IN (SELECT version_id FROM version_finishers WHERE player_id=NEW.id);
        DELETE FROM board_time_counts WHERE public_count=0 AND all_count=0;
        END""")
    for table, owner, statuses in (("runs", "{ref}.player_id", "'queued','verifying'"), ("track_validations", "(SELECT t.owner_id FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE v.id={ref}.version_id)", "'queued','validating'")):
        for event in ("INSERT", "UPDATE", "DELETE"):
            body = ""
            for ref, delta in (("OLD", -1), ("NEW", 1)):
                if (event == "INSERT" and ref == "OLD") or (event == "DELETE" and ref == "NEW"):
                    continue
                condition = f"{ref}.status IN ({statuses})"
                if event == "UPDATE":
                    other = "NEW" if ref == "OLD" else "OLD"
                    condition += f" AND {other}.status NOT IN ({statuses})"
                body += f"""INSERT INTO queue_players (player_id,last_claim_at,pending) SELECT {owner.format(ref=ref)},0,{delta} WHERE {condition}
                    ON CONFLICT(player_id) DO UPDATE SET pending=pending+{delta};
                    UPDATE queue_capacity SET pending=pending+{delta} WHERE {condition};"""
            sql(f"CREATE TRIGGER queue_{table}_{event.lower()} AFTER {event} ON {table} BEGIN {body} END")


def postgres_triggers():
    sql("""CREATE FUNCTION bmt_tick_delta(bid text, tick integer, visible integer, active integer) RETURNS void LANGUAGE plpgsql AS $$
        BEGIN INSERT INTO board_time_counts VALUES(bid,tick,visible,active) ON CONFLICT(board_id,time_ticks)
        DO UPDATE SET public_count=board_time_counts.public_count+visible,all_count=board_time_counts.all_count+active;
        DELETE FROM board_time_counts WHERE board_id=bid AND time_ticks=tick AND public_count=0 AND all_count=0;
        UPDATE boards SET public_count=public_count+visible,all_count=all_count+active WHERE id=bid; END $$""")
    sql("""CREATE FUNCTION bmt_finish_delta(bid text, pid text, delta integer, visible integer) RETURNS void LANGUAGE plpgsql AS $$
        DECLARE vid text; n integer;
        BEGIN SELECT version_id INTO vid FROM boards WHERE id=bid AND manifest->>'purpose' IS NULL AND COALESCE(manifest->>'test_population','false') <> 'true';
        IF vid IS NULL THEN RETURN; END IF;
        INSERT INTO version_finishers VALUES(vid,pid,delta) ON CONFLICT(version_id,player_id) DO UPDATE SET board_count=version_finishers.board_count+delta RETURNING board_count INTO n;
        IF (delta=1 AND n=1) OR (delta=-1 AND n=0) THEN UPDATE track_versions SET verified_finishers=verified_finishers+delta*visible WHERE id=vid; END IF;
        DELETE FROM version_finishers WHERE version_id=vid AND player_id=pid AND board_count=0; END $$""")
    sql("""CREATE FUNCTION bmt_pb_projection() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE visible integer; active integer;
        BEGIN IF TG_OP <> 'INSERT' THEN
          SELECT (NOT disabled AND NOT is_test_driver)::integer,(NOT disabled)::integer INTO visible,active FROM players WHERE id=OLD.player_id;
          PERFORM bmt_tick_delta(OLD.board_id,OLD.time_ticks,-visible,-active); PERFORM bmt_finish_delta(OLD.board_id,OLD.player_id,-1,visible);
        END IF;
        IF TG_OP <> 'DELETE' THEN
          SELECT (NOT disabled AND NOT is_test_driver)::integer,(NOT disabled)::integer INTO visible,active FROM players WHERE id=NEW.player_id;
          PERFORM bmt_tick_delta(NEW.board_id,NEW.time_ticks,visible,active); PERFORM bmt_finish_delta(NEW.board_id,NEW.player_id,1,visible);
        END IF; RETURN NULL; END $$""")
    sql("CREATE TRIGGER pb_projection AFTER INSERT OR UPDATE OR DELETE ON personal_bests FOR EACH ROW EXECUTE FUNCTION bmt_pb_projection()")
    sql("DROP TRIGGER player_board_revision ON players")
    sql("""CREATE OR REPLACE FUNCTION bmt_player_board_revision() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE pb record; visible integer; active integer;
        BEGIN IF OLD.disabled IS DISTINCT FROM NEW.disabled OR OLD.is_test_driver IS DISTINCT FROM NEW.is_test_driver THEN
          visible := (NOT NEW.disabled AND NOT NEW.is_test_driver)::integer-(NOT OLD.disabled AND NOT OLD.is_test_driver)::integer;
          active := (NOT NEW.disabled)::integer-(NOT OLD.disabled)::integer;
          FOR pb IN SELECT board_id,time_ticks FROM personal_bests WHERE player_id=NEW.id LOOP
            PERFORM bmt_tick_delta(pb.board_id,pb.time_ticks,visible,active);
            UPDATE boards SET stats_revision=stats_revision+1 WHERE id=pb.board_id;
          END LOOP;
          UPDATE track_versions SET verified_finishers=verified_finishers+visible WHERE id IN (SELECT version_id FROM version_finishers WHERE player_id=NEW.id);
        END IF; RETURN NULL; END $$""")
    sql("CREATE TRIGGER player_board_revision AFTER UPDATE OF disabled,is_test_driver ON players FOR EACH ROW EXECUTE FUNCTION bmt_player_board_revision()")
    sql("""CREATE FUNCTION bmt_queue_delta() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE delta integer:=0; pid text; statuses text[];
        BEGIN statuses := CASE WHEN TG_TABLE_NAME='runs' THEN ARRAY['queued','verifying'] ELSE ARRAY['queued','validating'] END;
        IF TG_OP <> 'INSERT' AND OLD.status=ANY(statuses) THEN delta:=delta-1; END IF;
        IF TG_OP <> 'DELETE' AND NEW.status=ANY(statuses) THEN delta:=delta+1; END IF;
        IF delta=0 THEN RETURN NULL; END IF;
        IF TG_TABLE_NAME='runs' THEN pid:=COALESCE(NEW.player_id,OLD.player_id);
        ELSE SELECT t.owner_id INTO pid FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE v.id=COALESCE(NEW.version_id,OLD.version_id); END IF;
        UPDATE queue_capacity SET pending=pending+delta WHERE id=1;
        INSERT INTO queue_players VALUES(pid,0,delta) ON CONFLICT(player_id) DO UPDATE SET pending=queue_players.pending+delta;
        RETURN NULL; END $$""")
    for table in ("runs", "track_validations"):
        sql(f"CREATE TRIGGER queue_delta AFTER INSERT OR UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION bmt_queue_delta()")


def downgrade():
    raise RuntimeError("Restore the pre-upgrade backup to downgrade competition projections")
