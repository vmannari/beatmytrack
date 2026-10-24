"""Exact bounded public/artificial time counts and compressed tie ordinals.

The one-time seed reads existing PBs. Quiesce writers and measure migration
storage/time on a representative copy before rollout; no lazy partial index is
served. Compressed tie trees store N..2N-1 rows per N visible PBs.
"""
import sqlalchemy as sa
from alembic import op

revision = "0055_bounded_rank_reads"
down_revision = "0054_priority_scaling"
branch_labels = None
depends_on = None
SIZE = 2147483648


def sql(statement):
    op.execute(sa.text(statement))


def visible(ref, population):
    return f"NOT {ref}.disabled AND " + (f"NOT {ref}.is_test_driver" if population == "public" else f"{ref}.is_test_driver")


def sqlite_prefixes(ref):
    return f"""WITH RECURSIVE path(prefix,n) AS (SELECT '',0 UNION ALL
        SELECT substr({ref},1,n+1),n+1 FROM path WHERE n<length({ref})) SELECT prefix FROM path"""


def sqlite_tie_triggers():
    # A request is consumed inside the same trigger/transaction. It also lets
    # one visibility change dispatch each PB without relying on Python UDFs.
    sql("""CREATE TABLE leaderboard_tie_work (
        board_id VARCHAR(64) NOT NULL,time_ticks INTEGER NOT NULL,player_id VARCHAR(36) NOT NULL,
        delta INTEGER NOT NULL,ancestor VARCHAR(36),child VARCHAR(36),child_leaf BOOLEAN,branch VARCHAR(36),
        old_parent VARCHAR(36),PRIMARY KEY(board_id,time_ticks,player_id))""")
    match = "board_id=NEW.board_id AND time_ticks=NEW.time_ticks"
    work = "board_id=NEW.board_id AND time_ticks=NEW.time_ticks AND player_id=NEW.player_id"
    ancestor = f"(SELECT ancestor FROM leaderboard_tie_work WHERE {work})"
    child = f"(SELECT child FROM leaderboard_tie_work WHERE {work})"
    child_leaf = f"(SELECT child_leaf FROM leaderboard_tie_work WHERE {work})"
    branch = f"(SELECT branch FROM leaderboard_tie_work WHERE {work})"
    paths = sqlite_prefixes("NEW.player_id")
    sql(f"""CREATE TRIGGER leaderboard_tie_add AFTER INSERT ON leaderboard_tie_work WHEN NEW.delta=1 BEGIN
        UPDATE leaderboard_tie_work SET ancestor=(SELECT prefix FROM leaderboard_tie_nodes
            WHERE {match} AND NOT leaf AND prefix IN ({paths}) ORDER BY length(prefix) DESC LIMIT 1) WHERE {work};
        UPDATE leaderboard_tie_work SET (child,child_leaf)=(SELECT prefix,leaf FROM leaderboard_tie_nodes WHERE {match}
            AND (parent={ancestor} AND substr(prefix,1,length({ancestor})+1)=substr(NEW.player_id,1,length({ancestor})+1)
                 OR {ancestor} IS NULL AND parent IS NULL) LIMIT 1) WHERE {work};
        UPDATE leaderboard_tie_work SET branch=(WITH RECURSIVE lengths(n) AS (SELECT 0 UNION ALL
            SELECT n+1 FROM lengths WHERE n<length(NEW.player_id)) SELECT substr(NEW.player_id,1,MAX(n)) FROM lengths
            WHERE substr({child},1,n)=substr(NEW.player_id,1,n)) WHERE {work} AND child IS NOT NULL;
        UPDATE leaderboard_tie_nodes SET total=total+1 WHERE {match} AND NOT leaf AND prefix IN ({paths});
        INSERT INTO leaderboard_tie_nodes(board_id,time_ticks,prefix,leaf,parent,total)
            SELECT NEW.board_id,NEW.time_ticks,{branch},FALSE,{ancestor},total+1 FROM leaderboard_tie_nodes
            WHERE {match} AND prefix={child} AND leaf={child_leaf};
        UPDATE leaderboard_tie_nodes SET parent={branch} WHERE {match} AND prefix={child} AND leaf={child_leaf};
        INSERT INTO leaderboard_tie_nodes(board_id,time_ticks,prefix,leaf,parent,total)
            VALUES(NEW.board_id,NEW.time_ticks,NEW.player_id,TRUE,CASE WHEN {child} IS NULL THEN {ancestor} ELSE {branch} END,1);
        DELETE FROM leaderboard_tie_work WHERE {work};
        END""")
    sql(f"""CREATE TRIGGER leaderboard_tie_remove AFTER INSERT ON leaderboard_tie_work WHEN NEW.delta=-1 BEGIN
        UPDATE leaderboard_tie_work SET ancestor=(SELECT parent FROM leaderboard_tie_nodes
            WHERE {match} AND prefix=NEW.player_id AND leaf) WHERE {work};
        UPDATE leaderboard_tie_work SET old_parent=(SELECT parent FROM leaderboard_tie_nodes
            WHERE {match} AND prefix={ancestor} AND NOT leaf) WHERE {work};
        UPDATE leaderboard_tie_nodes SET total=total-1 WHERE {match} AND NOT leaf AND prefix IN ({paths});
        DELETE FROM leaderboard_tie_nodes WHERE {match} AND prefix=NEW.player_id AND leaf;
        UPDATE leaderboard_tie_nodes SET parent=(SELECT old_parent FROM leaderboard_tie_work WHERE {work})
            WHERE {match} AND parent={ancestor} AND (SELECT COUNT(*) FROM leaderboard_tie_nodes
                WHERE {match} AND parent={ancestor})=1;
        DELETE FROM leaderboard_tie_nodes WHERE {match} AND prefix={ancestor} AND NOT leaf
            AND NOT EXISTS(SELECT 1 FROM leaderboard_tie_nodes WHERE {match} AND parent={ancestor});
        DELETE FROM leaderboard_tie_work WHERE {work};
        END""")


def sqlite_time_delta(ref, population, delta):
    eligibility = visible("p", population)
    path = f"""WITH RECURSIVE nodes(node) AS (SELECT {ref}.time_ticks WHERE EXISTS(
        SELECT 1 FROM players p WHERE p.id={ref}.player_id AND {eligibility})
        UNION ALL SELECT node+(node & -node) FROM nodes WHERE node<{SIZE}) SELECT node FROM nodes"""
    if delta < 0:
        return f"""UPDATE leaderboard_rank_counts SET total=total-1 WHERE board_id={ref}.board_id
            AND population='{population}' AND node IN ({path});"""
    return f"""INSERT INTO leaderboard_rank_counts(board_id,population,node,total)
        SELECT {ref}.board_id,'{population}',node,1 FROM ({path}) WHERE 1
        ON CONFLICT(board_id,population,node) DO UPDATE SET total=total+1;"""


def sqlite_triggers():
    sqlite_tie_triggers()
    for event in ("INSERT", "UPDATE", "DELETE"):
        body = ""
        for ref, delta in (("OLD", -1), ("NEW", 1)):
            if (event == "INSERT" and ref == "OLD") or (event == "DELETE" and ref == "NEW"):
                continue
            for population in ("public", "test"):
                body += sqlite_time_delta(ref, population, delta)
            body += f"""INSERT INTO leaderboard_tie_work(board_id,time_ticks,player_id,delta)
                SELECT {ref}.board_id,{ref}.time_ticks,{ref}.player_id,{delta}
                WHERE EXISTS(SELECT 1 FROM players p WHERE p.id={ref}.player_id AND {visible('p', 'public')});"""
        guard = "" if event != "UPDATE" else "WHEN (OLD.board_id,OLD.player_id,OLD.time_ticks) IS NOT (NEW.board_id,NEW.player_id,NEW.time_ticks)"
        sql(f"CREATE TRIGGER zz_leaderboard_pb_{event.lower()} AFTER {event} ON personal_bests {guard} BEGIN {body} END")
    body = ""
    for population in ("public", "test"):
        delta = f"(CASE WHEN {visible('NEW', population)} THEN 1 ELSE 0 END)-(CASE WHEN {visible('OLD', population)} THEN 1 ELSE 0 END)"
        paths = f"""WITH RECURSIVE nodes(board_id,node) AS (SELECT board_id,time_ticks FROM personal_bests WHERE player_id=NEW.id
            UNION ALL SELECT board_id,node+(node & -node) FROM nodes WHERE node<{SIZE}) SELECT board_id,node FROM nodes"""
        # A player contributes at most once per board; disjoint PB board keys
        # make a set-based visibility update exact.
        body += f"""INSERT INTO leaderboard_rank_counts(board_id,population,node,total)
            SELECT board_id,'{population}',node,({delta}) FROM ({paths}) WHERE ({delta})>0
            ON CONFLICT(board_id,population,node) DO UPDATE SET total=total+({delta});
            UPDATE leaderboard_rank_counts SET total=total+({delta}) WHERE population='{population}'
            AND ({delta})<0 AND (board_id,node) IN ({paths});"""
        if population == "public":
            body += f"""INSERT INTO leaderboard_tie_work(board_id,time_ticks,player_id,delta)
                SELECT board_id,time_ticks,NEW.id,({delta}) FROM personal_bests WHERE player_id=NEW.id AND ({delta})<>0;"""
    # BEFORE follows reward rank's lock/visibility convention: later PB erasure
    # triggers see the new eligibility and cannot subtract a second time.
    sql(f"CREATE TRIGGER zz_leaderboard_player BEFORE UPDATE OF disabled,is_test_driver ON players BEGIN {body} END")


def postgres_triggers():
    sql(f"""CREATE FUNCTION bmt_leaderboard_time(bid text,pop text,ticks integer,delta integer,exclude_ticks integer DEFAULT NULL)
        RETURNS void LANGUAGE plpgsql AS $$
        DECLARE idx bigint; path bigint[]:=ARRAY[]::bigint[]; omitted bigint[]:=ARRAY[]::bigint[];
        BEGIN
            IF ticks<=0 THEN RAISE EXCEPTION 'Invalid leaderboard ticks'; END IF;
            idx:=exclude_ticks;
            WHILE idx IS NOT NULL AND idx<={SIZE} LOOP omitted:=array_append(omitted,idx);idx:=idx+(idx & -idx);END LOOP;
            idx:=ticks;
            WHILE idx<={SIZE} LOOP
                IF NOT idx=ANY(omitted) THEN path:=array_append(path,idx);END IF;
                idx:=idx+(idx & -idx);
            END LOOP;
            IF delta>0 THEN
                INSERT INTO leaderboard_rank_counts(board_id,population,node,total)
                    SELECT bid,pop,n,delta FROM unnest(path) n ORDER BY n
                    ON CONFLICT(board_id,population,node) DO UPDATE SET total=leaderboard_rank_counts.total+EXCLUDED.total;
            ELSE
                UPDATE leaderboard_rank_counts SET total=total+delta WHERE board_id=bid AND population=pop AND node=ANY(path);
            END IF;
        END $$""")
    sql("""CREATE FUNCTION bmt_leaderboard_tie(bid text,ticks integer,pid text,delta integer)
        RETURNS void LANGUAGE plpgsql AS $$
        DECLARE ancestor text; child text; child_leaf boolean; branch text; old_parent text; quantity bigint; prefixes text[];
        BEGIN
            SELECT array_agg(substr(pid,1,n)) INTO prefixes FROM generate_series(0,length(pid)) n;
            IF delta>0 THEN
                SELECT prefix INTO ancestor FROM leaderboard_tie_nodes
                    WHERE board_id=bid AND time_ticks=ticks AND NOT leaf AND prefix=ANY(prefixes) ORDER BY length(prefix) DESC LIMIT 1;
                SELECT prefix,total,leaf INTO child,quantity,child_leaf FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks
                    AND (parent=ancestor AND substr(prefix,1,length(ancestor)+1)=substr(pid,1,length(ancestor)+1)
                         OR ancestor IS NULL AND parent IS NULL) LIMIT 1;
                IF child IS NOT NULL THEN
                    SELECT substr(pid,1,MAX(n)) INTO branch FROM generate_series(0,length(pid)) n
                        WHERE substr(pid,1,n)=substr(child,1,n);
                END IF;
                UPDATE leaderboard_tie_nodes SET total=total+1 WHERE board_id=bid AND time_ticks=ticks AND NOT leaf AND prefix=ANY(prefixes);
                IF child IS NOT NULL THEN
                    INSERT INTO leaderboard_tie_nodes VALUES(bid,ticks,branch,FALSE,ancestor,quantity+1);
                    UPDATE leaderboard_tie_nodes SET parent=branch WHERE board_id=bid AND time_ticks=ticks AND prefix=child AND leaf=child_leaf;
                END IF;
                INSERT INTO leaderboard_tie_nodes VALUES(bid,ticks,pid,TRUE,CASE WHEN child IS NULL THEN ancestor ELSE branch END,1);
            ELSE
                SELECT parent INTO ancestor FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks AND prefix=pid AND leaf;
                SELECT parent INTO old_parent FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks AND prefix=ancestor AND NOT leaf;
                UPDATE leaderboard_tie_nodes SET total=total-1 WHERE board_id=bid AND time_ticks=ticks AND NOT leaf AND prefix=ANY(prefixes);
                DELETE FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks AND prefix=pid AND leaf;
                SELECT COUNT(*) INTO quantity FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks AND parent=ancestor;
                IF quantity=1 THEN
                    UPDATE leaderboard_tie_nodes SET parent=old_parent WHERE board_id=bid AND time_ticks=ticks AND parent=ancestor;
                    DELETE FROM leaderboard_tie_nodes WHERE board_id=bid AND time_ticks=ticks AND prefix=ancestor AND NOT leaf;
                END IF;
            END IF;
        END $$""")
    sql("""CREATE FUNCTION bmt_leaderboard_pb() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE pop text; old_visible boolean; new_visible boolean; skip_old integer; skip_new integer;
        BEGIN
            IF TG_OP='UPDATE' AND (OLD.board_id,OLD.player_id,OLD.time_ticks) IS NOT DISTINCT FROM
                (NEW.board_id,NEW.player_id,NEW.time_ticks) THEN RETURN NULL;END IF;
            FOREACH pop IN ARRAY ARRAY['test','public'] LOOP
                old_visible:=false;new_visible:=false;skip_old:=NULL;skip_new:=NULL;
                IF TG_OP<>'INSERT' THEN SELECT NOT disabled AND (is_test_driver=(pop='test')) INTO old_visible FROM players WHERE id=OLD.player_id;END IF;
                IF TG_OP<>'DELETE' THEN SELECT NOT disabled AND (is_test_driver=(pop='test')) INTO new_visible FROM players WHERE id=NEW.player_id;END IF;
                IF TG_OP='UPDATE' AND old_visible AND new_visible AND OLD.board_id=NEW.board_id THEN skip_old:=NEW.time_ticks;skip_new:=OLD.time_ticks;END IF;
                IF old_visible THEN
                    PERFORM bmt_leaderboard_time(OLD.board_id,pop,OLD.time_ticks,-1,skip_old);
                    IF pop='public' THEN PERFORM bmt_leaderboard_tie(OLD.board_id,OLD.time_ticks,OLD.player_id,-1);END IF;
                END IF;
                IF new_visible THEN
                    PERFORM bmt_leaderboard_time(NEW.board_id,pop,NEW.time_ticks,1,skip_new);
                    IF pop='public' THEN PERFORM bmt_leaderboard_tie(NEW.board_id,NEW.time_ticks,NEW.player_id,1);END IF;
                END IF;
            END LOOP;
            RETURN NULL;
        END $$""")
    sql("CREATE TRIGGER zz_leaderboard_pb AFTER INSERT OR UPDATE OR DELETE ON personal_bests FOR EACH ROW EXECUTE FUNCTION bmt_leaderboard_pb()")
    sql("""CREATE FUNCTION bmt_leaderboard_player() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE item record; pop text; delta integer;
        BEGIN
            IF (OLD.disabled,OLD.is_test_driver) IS NOT DISTINCT FROM (NEW.disabled,NEW.is_test_driver) THEN RETURN NEW;END IF;
            PERFORM 1 FROM boards WHERE id IN (SELECT board_id FROM personal_bests WHERE player_id=NEW.id) ORDER BY id FOR UPDATE;
            FOREACH pop IN ARRAY ARRAY['test','public'] LOOP
                delta:=(NOT NEW.disabled AND (NEW.is_test_driver=(pop='test')))::integer
                     -(NOT OLD.disabled AND (OLD.is_test_driver=(pop='test')))::integer;
                IF delta=0 THEN CONTINUE;END IF;
                FOR item IN SELECT board_id,time_ticks FROM personal_bests WHERE player_id=NEW.id ORDER BY board_id LOOP
                    PERFORM bmt_leaderboard_time(item.board_id,pop,item.time_ticks,delta);
                    IF pop='public' THEN PERFORM bmt_leaderboard_tie(item.board_id,item.time_ticks,NEW.id,delta);END IF;
                END LOOP;
            END LOOP;
            RETURN NEW;
        END $$""")
    sql("CREATE TRIGGER zz_leaderboard_player BEFORE UPDATE OF disabled,is_test_driver ON players FOR EACH ROW EXECUTE FUNCTION bmt_leaderboard_player()")


def upgrade():
    postgres = op.get_bind().dialect.name == "postgresql"
    if postgres:
        sql("LOCK TABLE players,personal_bests IN SHARE ROW EXCLUSIVE MODE")
    op.create_table("leaderboard_rank_counts",
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("population", sa.String(6), primary_key=True),
        sa.Column("node", sa.BigInteger(), primary_key=True),
        sa.Column("total", sa.BigInteger(), nullable=False),
        sa.CheckConstraint("total>=0"),sa.CheckConstraint(f"node>0 AND node<={SIZE}"))
    op.create_table("leaderboard_tie_nodes",
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("time_ticks", sa.Integer(), primary_key=True),
        sa.Column("prefix", sa.String(36), primary_key=True),
        sa.Column("leaf", sa.Boolean(), primary_key=True),
        sa.Column("parent", sa.String(36), nullable=True),
        sa.Column("total", sa.BigInteger(), nullable=False),sa.CheckConstraint("total>0"))
    op.create_index("ix_leaderboard_tie_children", "leaderboard_tie_nodes", ["board_id","time_ticks","parent","prefix"])
    op.create_index("ix_leaderboard_visible_order", "leaderboard_tie_nodes", ["board_id","time_ticks","prefix"],
                    postgresql_where=sa.text("leaf IS TRUE"), sqlite_where=sa.text("leaf IS 1"))
    if postgres:
        postgres_triggers()
    else:
        sqlite_triggers()
    for population in ("public", "test"):
        sql(f"""INSERT INTO leaderboard_rank_counts(board_id,population,node,total)
            WITH RECURSIVE frequencies AS (SELECT b.board_id,b.time_ticks,COUNT(*) AS total
                FROM personal_bests b JOIN players p ON p.id=b.player_id WHERE {visible('p', population)} GROUP BY b.board_id,b.time_ticks),
            nodes(board_id,node,total) AS (SELECT board_id,CAST(time_ticks AS BIGINT),total FROM frequencies
                UNION ALL SELECT board_id,node+(node & -node),total FROM nodes WHERE node<{SIZE})
            SELECT board_id,'{population}',node,SUM(total) FROM nodes GROUP BY board_id,node""")
    # Stream the existing leaves in bounded driver batches; the compressed tree
    # path itself is bounded. SQL writer locks cover the complete seed.
    rows = op.get_bind().execute(sa.text(
        "SELECT b.board_id,b.time_ticks,b.player_id FROM personal_bests b JOIN players p ON p.id=b.player_id "
        "WHERE NOT p.disabled AND NOT p.is_test_driver ORDER BY b.board_id,b.time_ticks,b.player_id")
        .execution_options(stream_results=True))
    try:
        for batch in rows.partitions(1000):
            if postgres:
                statement = sa.text("SELECT bmt_leaderboard_tie(:bid,:ticks,:pid,1)")
            else:
                statement = sa.text("INSERT INTO leaderboard_tie_work(board_id,time_ticks,player_id,delta) VALUES(:bid,:ticks,:pid,1)")
            op.get_bind().execute(statement, [{"bid":bid,"ticks":ticks,"pid":pid} for bid,ticks,pid in batch])
    finally:
        rows.close()


def downgrade():
    postgres = op.get_bind().dialect.name == "postgresql"
    if postgres:
        sql("DROP TRIGGER zz_leaderboard_pb ON personal_bests")
        sql("DROP TRIGGER zz_leaderboard_player ON players")
        for signature in ("bmt_leaderboard_pb()", "bmt_leaderboard_player()", "bmt_leaderboard_tie(text,integer,text,integer)",
                          "bmt_leaderboard_time(text,text,integer,integer,integer)"):
            sql("DROP FUNCTION " + signature)
    else:
        for event in ("insert", "update", "delete"):
            sql(f"DROP TRIGGER zz_leaderboard_pb_{event}")
        sql("DROP TRIGGER zz_leaderboard_player")
        op.drop_table("leaderboard_tie_work")
    op.drop_table("leaderboard_tie_nodes")
    op.drop_table("leaderboard_rank_counts")
