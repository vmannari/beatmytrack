"""Independent transactional queue slots replace the global counter write lock."""
import sqlalchemy as sa
from alembic import op

revision = "0047_queue_capacity_slots"
down_revision = ("0045_reward_rank_index", "0045_studio_report_reads")
branch_labels = None
depends_on = None

JOBS = (
    ("runs", "id", "{ref}.player_id", "'queued','verifying'"),
    ("track_validations", "version_id", "(SELECT t.owner_id FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE v.id={ref}.version_id)", "'queued','validating'"),
    ("publication_intents", "id", "{ref}.player_id", "'queued','verifying'"),
)


def sql(value):
    op.execute(sa.text(value))


def drop_triggers(sqlite):
    for table, *_ in JOBS:
        if sqlite:
            prefix = "queue_publications" if table == "publication_intents" else "queue_" + table
            for event in ("insert", "update", "delete"):
                sql(f"DROP TRIGGER {prefix}_{event}")
        else:
            sql(f"DROP TRIGGER queue_delta ON {table}")


def upgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    # Deploy with writers drained/stopped. The explicit table locks also fence
    # accidental old writers during PostgreSQL's transactional cutover.
    if not sqlite:
        sql("LOCK TABLE runs,track_validations,publication_intents IN ACCESS EXCLUSIVE MODE")
    drop_triggers(sqlite)
    op.create_table("queue_limits", sa.Column("id", sa.Integer(), primary_key=True),
                    sa.Column("capacity", sa.Integer(), nullable=False), sa.CheckConstraint("capacity > 0"))
    op.create_table("queue_reservations",
        sa.Column("kind", sa.String(24), primary_key=True),
        sa.Column("job_id", sa.String(36), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("slot", sa.Integer(), nullable=False), sa.UniqueConstraint("slot"), sa.CheckConstraint("slot >= 0"))
    op.create_index("ix_queue_reservations_player_id", "queue_reservations", ["player_id"])
    sql("""INSERT INTO queue_reservations(kind,job_id,player_id,slot)
        SELECT kind,job_id,player_id,ROW_NUMBER() OVER(ORDER BY kind,job_id)-1 FROM (
          SELECT 'runs' AS kind,id AS job_id,player_id FROM runs WHERE status IN('queued','verifying')
          UNION ALL SELECT 'track_validations',j.version_id,t.owner_id FROM track_validations j
            JOIN track_versions v ON v.id=j.version_id JOIN tracks t ON t.id=v.track_id WHERE j.status IN('queued','validating')
          UNION ALL SELECT 'publication_intents',id,player_id FROM publication_intents WHERE status IN('queued','verifying')
        ) pending""")
    # Keep arbitrary existing backlogs intact. Matching runtime configuration
    # can increase this limit, or shrink once occupied slots fit its range.
    sql("INSERT INTO queue_limits SELECT 1,CASE WHEN COUNT(*)>128 THEN COUNT(*) ELSE 128 END FROM queue_reservations")
    original = op.get_bind().scalar(sa.text("SELECT pending FROM queue_capacity WHERE id=1"))
    reconstructed = op.get_bind().scalar(sa.text("SELECT COUNT(*) FROM queue_reservations"))
    if original != reconstructed:
        raise RuntimeError("Queue counters disagree with pending jobs; investigate before migrating")
    # Touch only the bounded active owners, never every registered account.
    sql("""INSERT INTO queue_players(player_id,last_claim_at,pending)
        SELECT player_id,0,COUNT(*) FROM queue_reservations GROUP BY player_id
        ON CONFLICT(player_id) DO UPDATE SET pending=excluded.pending""")
    op.drop_table("queue_capacity")
    sql("CREATE VIEW queue_capacity AS SELECT 1 AS id,CAST(COUNT(*) AS INTEGER) AS pending FROM queue_reservations")
    if sqlite:
        sqlite_triggers()
    else:
        postgres_triggers()


def sqlite_triggers():
    for table, key, owner, statuses in JOBS:
        prefix = "queue_publications" if table == "publication_intents" else "queue_" + table
        for event in ("INSERT", "UPDATE", "DELETE"):
            body = ""
            for ref, delta in (("OLD", -1), ("NEW", 1)):
                if event == "INSERT" and ref == "OLD" or event == "DELETE" and ref == "NEW":
                    continue
                condition = f"{ref}.status IN ({statuses})"
                if event == "UPDATE":
                    other = "NEW" if ref == "OLD" else "OLD"
                    condition += f" AND {other}.status NOT IN ({statuses})"
                if delta == 1:
                    body += f"""INSERT INTO queue_reservations(kind,job_id,player_id,slot)
                        SELECT '{table}',NEW.{key},{owner.format(ref='NEW')},free.slot FROM (
                          WITH RECURSIVE slots(slot) AS (SELECT 0 UNION ALL SELECT slot+1 FROM slots
                            WHERE slot+1<(SELECT capacity FROM queue_limits WHERE id=1))
                          SELECT slot FROM slots WHERE NOT EXISTS(SELECT 1 FROM queue_reservations r WHERE r.slot=slots.slot)
                          ORDER BY slot LIMIT 1) free WHERE {condition};
                        SELECT CASE WHEN {condition} AND changes()=0 THEN RAISE(ABORT,'verification_capacity_reached') END;"""
                else:
                    body += f"DELETE FROM queue_reservations WHERE kind='{table}' AND job_id=OLD.{key} AND {condition};"
                body += f"""INSERT INTO queue_players(player_id,last_claim_at,pending)
                    SELECT {owner.format(ref=ref)},0,{delta} WHERE {condition}
                    ON CONFLICT(player_id) DO UPDATE SET pending=pending+{delta};"""
            sql(f"CREATE TRIGGER {prefix}_{event.lower()} AFTER {event} ON {table} BEGIN {body} END")


def postgres_triggers():
    sql("""CREATE FUNCTION bmt_queue_reserve(kind text,job text,owner text) RETURNS void LANGUAGE plpgsql AS $$
        DECLARE maximum integer; candidate integer; start_slot bigint; inserted integer; namespace integer;
        BEGIN
          -- SHARE locks are mutually compatible; only a rare limit resize takes
          -- an exclusive configuration lock. No counter is updated here.
          SELECT capacity INTO STRICT maximum FROM queue_limits WHERE id=1 FOR SHARE;
          namespace := hashtext(current_schema() || '/bmt-queue-slot');
          start_slot := (hashtext(kind || '/' || job)::bigint+2147483648) % maximum;
          FOR candidate IN SELECT ((start_slot+g.i)%maximum)::integer FROM generate_series(0,maximum-1) g(i)
            WHERE NOT EXISTS(SELECT 1 FROM queue_reservations r WHERE r.slot=((start_slot+g.i)%maximum)::integer)
          LOOP
            -- Transaction-scoped, per-slot try-locks avoid waiting behind an
            -- unrelated uncommitted admission. Unique(slot) is the hard fence.
            IF pg_try_advisory_xact_lock(namespace,candidate) THEN
              INSERT INTO queue_reservations(kind,job_id,player_id,slot) VALUES(kind,job,owner,candidate)
                ON CONFLICT DO NOTHING;
              GET DIAGNOSTICS inserted=ROW_COUNT;
              IF inserted=1 THEN RETURN; END IF;
            END IF;
          END LOOP;
          RAISE EXCEPTION 'verification_capacity_reached';
        END $$""")
    sql("""CREATE OR REPLACE FUNCTION bmt_queue_delta() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE delta integer:=0; pid text; job text; statuses text[];
        BEGIN
          statuses := CASE WHEN TG_TABLE_NAME='track_validations' THEN ARRAY['queued','validating'] ELSE ARRAY['queued','verifying'] END;
          IF TG_OP<>'INSERT' AND OLD.status=ANY(statuses) THEN delta:=delta-1; END IF;
          IF TG_OP<>'DELETE' AND NEW.status=ANY(statuses) THEN delta:=delta+1; END IF;
          IF delta=0 THEN RETURN NULL; END IF;
          IF TG_TABLE_NAME='track_validations' THEN
            job:=COALESCE(NEW.version_id,OLD.version_id);
            SELECT t.owner_id INTO pid FROM track_versions v JOIN tracks t ON t.id=v.track_id WHERE v.id=job;
          ELSE job:=COALESCE(NEW.id,OLD.id); pid:=COALESCE(NEW.player_id,OLD.player_id); END IF;
          IF delta=1 THEN PERFORM bmt_queue_reserve(TG_TABLE_NAME,job,pid);
          ELSE DELETE FROM queue_reservations WHERE kind=TG_TABLE_NAME AND job_id=job; END IF;
          INSERT INTO queue_players(player_id,last_claim_at,pending) VALUES(pid,0,delta)
            ON CONFLICT(player_id) DO UPDATE SET pending=queue_players.pending+delta;
          RETURN NULL;
        END $$""")
    for table, *_ in JOBS:
        sql(f"CREATE TRIGGER queue_delta AFTER INSERT OR UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION bmt_queue_delta()")
    sql("DROP FUNCTION bmt_publication_queue_delta()")


def downgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    if not sqlite:
        sql("LOCK TABLE runs,track_validations,publication_intents IN ACCESS EXCLUSIVE MODE")
    drop_triggers(sqlite)
    sql("DROP VIEW queue_capacity")
    op.create_table("queue_capacity", sa.Column("id", sa.Integer(), primary_key=True),
                    sa.Column("pending", sa.Integer(), nullable=False))
    sql("INSERT INTO queue_capacity SELECT 1,COUNT(*) FROM queue_reservations")
    if sqlite:
        for table, key, owner, statuses in JOBS:
            prefix = "queue_publications" if table == "publication_intents" else "queue_" + table
            for event in ("INSERT", "UPDATE", "DELETE"):
                body = ""
                for ref, delta in (("OLD", -1), ("NEW", 1)):
                    if event == "INSERT" and ref == "OLD" or event == "DELETE" and ref == "NEW":
                        continue
                    condition = f"{ref}.status IN ({statuses})"
                    if event == "UPDATE":
                        condition += f" AND {'NEW' if ref == 'OLD' else 'OLD'}.status NOT IN ({statuses})"
                    body += f"""INSERT INTO queue_players(player_id,last_claim_at,pending)
                        SELECT {owner.format(ref=ref)},0,{delta} WHERE {condition}
                        ON CONFLICT(player_id) DO UPDATE SET pending=pending+{delta};
                        UPDATE queue_capacity SET pending=pending+{delta} WHERE {condition};"""
                sql(f"CREATE TRIGGER {prefix}_{event.lower()} AFTER {event} ON {table} BEGIN {body} END")
    else:
        # Restore the historical counter functions without touching PB/board
        # projections that share migration 0013 with the original queue code.
        for name, publication in (("bmt_queue_delta", False), ("bmt_publication_queue_delta", True)):
            owner_sql = "pid:=COALESCE(NEW.player_id,OLD.player_id);" if publication else """
                IF TG_TABLE_NAME='runs' THEN pid:=COALESCE(NEW.player_id,OLD.player_id);
                ELSE SELECT t.owner_id INTO pid FROM track_versions v JOIN tracks t ON t.id=v.track_id
                  WHERE v.id=COALESCE(NEW.version_id,OLD.version_id); END IF;"""
            status_sql = "ARRAY['queued','verifying']" if publication else "CASE WHEN TG_TABLE_NAME='runs' THEN ARRAY['queued','verifying'] ELSE ARRAY['queued','validating'] END"
            sql(f"""CREATE OR REPLACE FUNCTION {name}() RETURNS trigger LANGUAGE plpgsql AS $$
                DECLARE delta integer:=0;pid text;statuses text[];
                BEGIN statuses:={status_sql};
                IF TG_OP<>'INSERT' AND OLD.status=ANY(statuses) THEN delta:=delta-1; END IF;
                IF TG_OP<>'DELETE' AND NEW.status=ANY(statuses) THEN delta:=delta+1; END IF;
                IF delta=0 THEN RETURN NULL; END IF;
                {owner_sql}
                UPDATE queue_capacity SET pending=pending+delta WHERE id=1;
                INSERT INTO queue_players(player_id,last_claim_at,pending) VALUES(pid,0,delta)
                  ON CONFLICT(player_id) DO UPDATE SET pending=queue_players.pending+delta;
                RETURN NULL; END $$""")
        for table, *_ in JOBS:
            function = "bmt_publication_queue_delta" if table == "publication_intents" else "bmt_queue_delta"
            sql(f"CREATE TRIGGER queue_delta AFTER INSERT OR UPDATE OR DELETE ON {table} FOR EACH ROW EXECUTE FUNCTION {function}()")
        sql("DROP FUNCTION bmt_queue_reserve(text,text,text)")
    op.drop_table("queue_reservations")
    op.drop_table("queue_limits")
