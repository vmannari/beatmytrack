"""Exact bounded percentile queries, maintained with PB and visibility changes.

Quiesce writers for rollout: existing eligible PBs are aggregated once while the
source tables are write-locked. No rewards, wallets or historical results change.
The 2**31 root covers every positive INTEGER time, not only today's replay cap.
"""
import sqlalchemy as sa
from alembic import op

revision = "0045_reward_rank_index"
down_revision = "0044_telemetry_counter_bigint"
branch_labels = None
depends_on = None

SIZE = 2147483648
SOURCES = (("personal_bests", "race"), ("lap_personal_bests", "lap"))


def sql(statement):
    op.execute(sa.text(statement))


def eligible(ref):
    return f"NOT {ref}.disabled AND NOT {ref}.is_test_driver AND {ref}.deleted_at IS NULL"


def player_rows(identity):
    return " UNION ALL ".join(
        f"SELECT board_id,'{metric}' AS metric,time_ticks FROM {table} WHERE player_id={identity}"
        for table, metric in SOURCES)


def sqlite_path(ref):
    return f"""WITH RECURSIVE nodes(node) AS (
        SELECT CASE WHEN {ref}.time_ticks<=0 THEN RAISE(ABORT,'Invalid reward ticks')
                    ELSE {ref}.time_ticks END
        WHERE EXISTS(SELECT 1 FROM players p WHERE p.id={ref}.player_id AND {eligible('p')})
        UNION ALL SELECT node+(node & -node) FROM nodes WHERE node<{SIZE}) SELECT node FROM nodes"""


def sqlite_delta(ref, metric, delta, other=None):
    path = sqlite_path(ref)
    if other is not None:
        path = (f"SELECT node FROM ({path}) WHERE {ref}.board_id IS NOT {other}.board_id "
                f"OR node NOT IN ({sqlite_path(other)})")
    if delta < 0:
        return f"""UPDATE reward_rank_counts SET total=total-1 WHERE board_id={ref}.board_id
            AND metric='{metric}' AND node IN ({path});"""
    return f"""INSERT INTO reward_rank_counts(board_id,metric,node,total)
        SELECT {ref}.board_id,'{metric}',node,1 FROM ({path}) WHERE 1
        ON CONFLICT(board_id,metric,node) DO UPDATE SET total=reward_rank_counts.total+1;"""


def sqlite_triggers():
    for table, metric in SOURCES:
        for event in ("INSERT", "UPDATE", "DELETE"):
            guard = ""
            if event == "UPDATE":
                guard = "WHEN OLD.board_id IS NOT NEW.board_id OR OLD.player_id IS NOT NEW.player_id OR OLD.time_ticks IS NOT NEW.time_ticks"
            body = (sqlite_delta("OLD", metric, -1, "NEW" if event == "UPDATE" else None) if event != "INSERT" else "")
            body += sqlite_delta("NEW", metric, 1, "OLD" if event == "UPDATE" else None) if event != "DELETE" else ""
            sql(f"CREATE TRIGGER reward_rank_{metric}_{event.lower()} AFTER {event} ON {table} {guard} BEGIN {body} END")
    rows = player_rows("NEW.id")
    paths = f"""WITH RECURSIVE nodes(board_id,metric,node) AS (
        SELECT board_id,metric,time_ticks FROM ({rows})
        UNION ALL SELECT board_id,metric,node+(node & -node) FROM nodes WHERE node<{SIZE})
        SELECT board_id,metric,node FROM nodes"""
    # BEFORE visibility changes: subsequent reclassification/erasure triggers can
    # remove PBs. Their AFTER triggers then see the new, already-counted visibility.
    sql(f"""CREATE TRIGGER reward_rank_player BEFORE UPDATE OF disabled,is_test_driver,deleted_at ON players
        WHEN ({eligible('OLD')}) IS NOT ({eligible('NEW')}) BEGIN
        UPDATE reward_rank_counts SET total=total-1 WHERE ({eligible('OLD')})
            AND (board_id,metric,node) IN ({paths});
        INSERT INTO reward_rank_counts(board_id,metric,node,total)
            SELECT board_id,metric,node,1 FROM ({paths}) WHERE ({eligible('NEW')})
            ON CONFLICT(board_id,metric,node) DO UPDATE SET total=reward_rank_counts.total+1;
        END""")


def postgres_triggers():
    sql(f"""CREATE FUNCTION bmt_reward_rank_delta(bid text, kind text, ticks integer, delta integer, exclude_ticks integer DEFAULT NULL)
        RETURNS void LANGUAGE plpgsql AS $$
        DECLARE idx bigint:=ticks; path bigint[]:=ARRAY[]::bigint[];
                omitted bigint[]:=ARRAY[]::bigint[]; changed integer;
        BEGIN
            IF ticks<=0 THEN RAISE EXCEPTION 'Invalid reward ticks'; END IF;
            IF exclude_ticks IS NOT NULL THEN
                IF exclude_ticks<=0 THEN RAISE EXCEPTION 'Invalid reward ticks'; END IF;
                idx:=exclude_ticks;
                WHILE idx<={SIZE} LOOP
                    omitted:=array_append(omitted,idx); idx:=idx+(idx & -idx);
                END LOOP;
            END IF;
            idx:=ticks;
            WHILE idx<={SIZE} LOOP
                IF NOT idx=ANY(omitted) THEN path:=array_append(path,idx); END IF;
                idx:=idx+(idx & -idx);
            END LOOP;
            IF delta>0 THEN
                INSERT INTO reward_rank_counts(board_id,metric,node,total)
                    SELECT bid,kind,n,delta FROM unnest(path) n ORDER BY n
                    ON CONFLICT(board_id,metric,node) DO UPDATE
                    SET total=reward_rank_counts.total+EXCLUDED.total;
            ELSE
                UPDATE reward_rank_counts SET total=total+delta
                    WHERE board_id=bid AND metric=kind AND node=ANY(path);
                GET DIAGNOSTICS changed=ROW_COUNT;
                IF changed<>cardinality(path) THEN RAISE EXCEPTION 'Incomplete reward rank index'; END IF;
            END IF;
        END $$""")
    sql(f"""CREATE FUNCTION bmt_reward_rank_pb() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE old_visible boolean:=false; new_visible boolean:=false;
                skip_old integer; skip_new integer;
        BEGIN
            IF TG_OP='UPDATE' THEN
                IF (OLD.board_id,OLD.player_id,OLD.time_ticks) IS NOT DISTINCT FROM
                   (NEW.board_id,NEW.player_id,NEW.time_ticks) THEN RETURN NULL; END IF;
            END IF;
            IF TG_OP<>'INSERT' THEN
                SELECT EXISTS(SELECT 1 FROM players p WHERE p.id=OLD.player_id AND {eligible('p')}) INTO old_visible;
            END IF;
            IF TG_OP<>'DELETE' THEN
                SELECT EXISTS(SELECT 1 FROM players p WHERE p.id=NEW.player_id AND {eligible('p')}) INTO new_visible;
            END IF;
            IF TG_OP='UPDATE' AND old_visible AND new_visible THEN
                IF OLD.board_id=NEW.board_id THEN
                    -- Shared ancestors have net zero change on an improvement;
                    -- avoid touching the population root or other common nodes.
                    skip_old:=NEW.time_ticks; skip_new:=OLD.time_ticks;
                END IF;
            END IF;
            IF TG_OP<>'INSERT' THEN
                IF old_visible THEN
                    PERFORM bmt_reward_rank_delta(OLD.board_id,TG_ARGV[0],OLD.time_ticks,-1,skip_old);
                END IF;
            END IF;
            IF TG_OP<>'DELETE' THEN
                IF new_visible THEN
                    PERFORM bmt_reward_rank_delta(NEW.board_id,TG_ARGV[0],NEW.time_ticks,1,skip_new);
                END IF;
            END IF;
            RETURN NULL;
        END $$""")
    for table, metric in SOURCES:
        # Existing PB projections acquire Board first; alphabetical AFTER trigger
        # order retains Player -> Board -> prefix-counter ordering.
        sql(f"CREATE TRIGGER reward_rank_{metric} AFTER INSERT OR UPDATE OR DELETE ON {table} "
            f"FOR EACH ROW EXECUTE FUNCTION bmt_reward_rank_pb('{metric}')")
    rows = player_rows("NEW.id")
    sql(f"""CREATE FUNCTION bmt_reward_rank_player() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE item record; delta integer;
        BEGIN
            delta:=({eligible('NEW')})::integer-({eligible('OLD')})::integer;
            IF delta=0 THEN RETURN NEW; END IF;
            -- PB writers already acquire Board before changing prefix counters.
            -- Take that same order before any visibility delta to avoid inversion.
            PERFORM 1 FROM boards WHERE id IN (SELECT board_id FROM ({rows}) p)
                ORDER BY id FOR UPDATE;
            FOR item IN SELECT * FROM ({rows}) p ORDER BY board_id,metric LOOP
                PERFORM bmt_reward_rank_delta(item.board_id,item.metric,item.time_ticks,delta);
            END LOOP;
            RETURN NEW;
        END $$""")
    sql("CREATE TRIGGER reward_rank_player BEFORE UPDATE OF disabled,is_test_driver,deleted_at ON players "
        "FOR EACH ROW EXECUTE FUNCTION bmt_reward_rank_player()")


def upgrade():
    if op.get_bind().dialect.name == "postgresql":
        sql("LOCK TABLE players, personal_bests, lap_personal_bests IN SHARE ROW EXCLUSIVE MODE")
    op.create_table("reward_rank_counts",
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("metric", sa.String(4), primary_key=True),
        sa.Column("node", sa.BigInteger(), primary_key=True),
        sa.Column("total", sa.BigInteger(), nullable=False),
        sa.CheckConstraint("total >= 0"),
        sa.CheckConstraint(f"node > 0 AND node <= {SIZE}"),
        sa.CheckConstraint("metric IN ('race','lap')"))
    rows = " UNION ALL ".join(
        f"SELECT b.board_id,'{metric}' AS metric,b.time_ticks FROM {table} b JOIN players p ON p.id=b.player_id WHERE {eligible('p')}"
        for table, metric in SOURCES)
    if op.get_bind().scalar(sa.text(f"SELECT 1 FROM ({rows}) p WHERE time_ticks<=0 LIMIT 1")):
        raise RuntimeError("Repair invalid nonpositive PB ticks before indexing rewards")
    # Group equal ticks before expanding paths; do not expand every player into
    # dozens of migration rows when a large board has many ties.
    sql(f"""INSERT INTO reward_rank_counts(board_id,metric,node,total)
        WITH RECURSIVE frequencies AS (
            SELECT board_id,metric,time_ticks,COUNT(*) AS total FROM ({rows}) p
            GROUP BY board_id,metric,time_ticks), nodes(board_id,metric,node,total) AS (
            SELECT board_id,metric,CAST(time_ticks AS BIGINT),total FROM frequencies
            UNION ALL SELECT board_id,metric,node+(node & -node),total FROM nodes WHERE node<{SIZE})
        SELECT board_id,metric,node,SUM(total) FROM nodes GROUP BY board_id,metric,node""")
    if op.get_bind().dialect.name == "sqlite":
        sqlite_triggers()
    else:
        postgres_triggers()


def downgrade():
    if op.get_bind().dialect.name == "sqlite":
        for _table, metric in SOURCES:
            for event in ("insert", "update", "delete"):
                sql(f"DROP TRIGGER reward_rank_{metric}_{event}")
    else:
        for table, metric in SOURCES:
            sql(f"DROP TRIGGER reward_rank_{metric} ON {table}")
        sql("DROP FUNCTION bmt_reward_rank_pb()")
    sql("DROP TRIGGER reward_rank_player" + (" ON players" if op.get_bind().dialect.name == "postgresql" else ""))
    if op.get_bind().dialect.name == "postgresql":
        sql("DROP FUNCTION bmt_reward_rank_player()")
        sql("DROP FUNCTION bmt_reward_rank_delta(text,text,integer,integer,integer)")
    op.drop_table("reward_rank_counts")
