"""Partitioned discovery journals and changed-row history; bounded worker backfill.

Install journals before backfill. No source data is copied in this migration.
Review large-host index builds separately; HTTP/workers never run migrations.
"""
import sqlalchemy as sa
from alembic import op

revision = "0050_discovery_indexed"
down_revision = "0047_queue_capacity_slots"
branch_labels = None
depends_on = None

SCHEMA = [('discovery_partitions',
  [('id', 'int', None, True, False, False),
   ('epoch', 'big', None, False, False, False),
   ('slots', 'big', None, False, False, False),
   ('checked_at', 'big', None, False, False, False),
   ('cursor', 'str', 36, False, False, False),
   ('ready', 'bool', None, False, False, False),
   ('audit_at', 'big', None, False, False, False)],
  [],
  []),
 ('discovery_heads',
  [('track_id', 'str', 36, True, False, False),
   ('partition', 'int', None, False, False, False),
   ('slot', 'big', None, False, False, False),
   ('epoch', 'big', None, False, False, False),
   ('popularity', 'big', None, False, False, False),
   ('due_at', 'big', None, False, False, False)],
  [('ix_discovery_head_due', ['partition', 'due_at'])],
  [('partition', 'slot')]),
 ('discovery_entries',
  [('track_id', 'str', 36, True, False, False),
   ('epoch', 'big', None, True, False, False),
   ('partition', 'int', None, False, False, False),
   ('until', 'big', None, False, True, False),
   ('retired_at', 'big', None, False, True, False),
   ('version_id', 'str', 36, False, False, False),
   ('owner_id', 'str', 36, False, False, False),
   ('visible', 'bool', None, False, False, False),
   ('official', 'bool', None, False, False, False),
   ('name', 'str', 80, False, False, False),
   ('creator', 'str', 40, False, False, False),
   ('name_key', 'str', 160, False, False, False),
   ('creator_key', 'str', 80, False, False, False),
   ('theme', 'str', 40, False, False, False),
   ('published_at', 'big', None, False, False, False),
   ('created_at', 'big', None, False, False, False),
   ('rating_sum', 'big', None, False, False, False),
   ('rating_count', 'big', None, False, False, False),
   ('rated', 'bool', None, False, False, False),
   ('score', 'big', None, False, False, False),
   ('finishers', 'big', None, False, False, False),
   ('popularity', 'big', None, False, False, False)],
  [('ix_discovery_entry_creator', ['partition', 'creator_key', 'name_key', 'track_id']),
   ('ix_discovery_entry_mix', ['partition', 'official', 'published_at', 'track_id']),
   ('ix_discovery_entry_name', ['partition', 'name_key', 'track_id']),
   ('ix_discovery_entry_new', ['partition', 'published_at', 'track_id']),
   ('ix_discovery_entry_plays', ['partition', 'finishers', 'published_at', 'track_id']),
   ('ix_discovery_entry_popular', ['partition', 'popularity', 'published_at', 'track_id']),
   ('ix_discovery_entry_retired', ['retired_at', 'track_id', 'epoch']),
   ('ix_discovery_entry_score', ['partition', 'rated', 'score', 'published_at', 'track_id']),
   ('ix_discovery_entry_theme', ['partition', 'theme', 'published_at', 'track_id']),
   ('ix_discovery_entry_version', ['version_id', 'epoch'])],
  []),
 ('discovery_changes',
  [('id', 'big', None, True, False, False),
   ('partition', 'int', None, False, False, False),
   ('kind', 'str', 12, False, False, False),
   ('target', 'str', 36, False, False, False),
   ('player_id', 'str', 36, False, True, False),
   ('run_id', 'str', 36, False, True, True),
   ('finished_at', 'big', None, False, False, False),
   ('created_at', 'big', None, False, False, False),
   ('processed_at', 'big', None, False, True, False)],
  [('ix_discovery_change_claim', ['partition', 'processed_at', 'id']),
   ('ix_discovery_change_player', ['player_id', 'id']),
   ('ix_discovery_change_retire', ['processed_at', 'id'])],
  []),
 ('discovery_drivers',
  [('track_id', 'str', 36, True, False, False),
   ('player_id', 'str', 36, True, False, False),
   ('partition', 'int', None, False, False, False),
   ('last_at', 'big', None, False, False, False),
   ('expires_at', 'big', None, False, False, False),
   ('counted', 'bool', None, False, False, False)],
  [('ix_discovery_driver_expire', ['partition', 'expires_at', 'track_id', 'player_id']),
   ('ix_discovery_driver_player', ['player_id', 'track_id'])],
  []),
 ('discovery_owner_jobs',
  [('partition', 'int', None, True, False, False),
   ('player_id', 'str', 36, True, False, False),
   ('cursor', 'str', 36, False, False, False),
   ('phase', 'int', None, False, False, False)],
  [],
  []),
 ('discovery_bootstrap',
  [('id', 'int', None, True, False, False),
   ('finished_at', 'big', None, False, False, False),
   ('run_id', 'str', 36, False, False, False),
   ('ready', 'bool', None, False, False, False)],
  [],
  []),
 ('discovery_collections',
  [('id', 'str', 64, True, False, False),
   ('scope', 'str', 64, False, False, False),
   ('expires_at', 'big', None, False, False, False)],
  [('ix_discovery_collection_expire', ['expires_at', 'id']),
   ('ix_discovery_collection_scope', ['scope', 'expires_at'])],
  []),
 ('discovery_members',
  [('collection_id', 'str', 64, True, False, False),
   ('kind', 'str', 8, True, False, False),
   ('track_id', 'str', 80, True, False, False)],
  [],
  []),
 ('discovery_sessions',
  [('id', 'str', 36, True, False, False),
   ('scope', 'str', 64, False, False, False),
   ('expires_at', 'big', None, False, False, False),
   ('created_at', 'big', None, False, False, False),
   ('secret', 'str', 64, False, False, False),
   ('query', 'json', None, False, False, False),
   ('epochs', 'json', None, False, False, False),
   ('slots', 'json', None, False, False, False),
   ('collection_id', 'str', 64, False, True, False)],
  [('ix_discovery_session_expire', ['expires_at', 'id']),
   ('ix_discovery_session_scope', ['scope', 'expires_at'])],
  []),
 ('discovery_boundaries',
  [('id', 'str', 64, True, False, False),
   ('session_id', 'str', 36, False, False, False),
   ('expires_at', 'big', None, False, False, False),
   ('positions', 'json', None, False, False, False),
   ('phase', 'int', None, False, False, False),
   ('previous_id', 'str', 64, False, True, False),
   ('anchor_version', 'str', 36, False, True, False)],
  [('ix_discovery_boundary_expire', ['expires_at', 'id'])],
  [])]


def sql(value):
    op.execute(sa.text(value))


def partition(ref, sqlite):
    function = "instr" if sqlite else "strpos"
    return f"({function}('0123456789abcdef',lower(substr({ref},1,1)))-1)"


def install(sqlite):
    stamp = "CAST(strftime('%s','now') AS INTEGER)" if sqlite else "CAST(EXTRACT(EPOCH FROM clock_timestamp()) AS BIGINT)"
    for table, target, watched in (
        ("tracks", "id", ("owner_id", "hidden", "official", "archived")),
        ("track_versions", "track_id", ("state", "name", "published_at", "discovery", "rating_sum", "rating_count", "verified_finishers", "redacted_track_hash")),
    ):
        for event in ("INSERT", "UPDATE", "DELETE"):
            ref = "OLD" if event == "DELETE" else "NEW"
            distinct = "IS NOT" if sqlite else "IS DISTINCT FROM"
            def compare(c, distinct=distinct):
                cast = "::jsonb" if c == "discovery" and not sqlite else ""
                return f"OLD.{c}{cast} {distinct} NEW.{c}{cast}"
            condition = " OR ".join(compare(c) for c in watched) if event == "UPDATE" else "true"
            body = f"INSERT INTO discovery_changes(partition,kind,target,finished_at,created_at) VALUES({partition(ref+'.'+target,sqlite)},'track',{ref}.{target},0,{stamp});"
            if table == "track_versions" and event == "UPDATE":
                metadata_changed = " OR ".join(compare(c) for c in watched
                    if c not in ("verified_finishers", "rating_sum", "rating_count"))
                body = body.replace("'track'", f"CASE WHEN {metadata_changed} THEN 'track' ELSE 'stats' END")
            name = f"discovery_{table}_{event.lower()}"
            if sqlite:
                sql(f"CREATE TRIGGER {name} AFTER {event} ON {table} WHEN {condition} BEGIN {body} END")
            else:
                sql(f"CREATE FUNCTION {name}() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF {condition} THEN {body} END IF; RETURN NULL; END $$")
                sql(f"CREATE TRIGGER {name} AFTER {event} ON {table} FOR EACH ROW EXECUTE FUNCTION {name}()")
    distinct = "IS NOT" if sqlite else "IS DISTINCT FROM"
    condition = " OR ".join(f"OLD.{c} {distinct} NEW.{c}" for c in ("display_name", "disabled", "is_test_driver", "deleted_at"))
    body = " ".join(f"INSERT INTO discovery_changes(partition,kind,target,player_id,finished_at,created_at) VALUES({p},'owner',NEW.id,NEW.id,0,{stamp});" for p in range(16))
    if sqlite:
        sql(f"CREATE TRIGGER discovery_players_update AFTER UPDATE ON players WHEN {condition} BEGIN {body} END")
    else:
        sql(f"CREATE FUNCTION discovery_players_update() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF {condition} THEN {body} END IF; RETURN NULL; END $$")
        sql("CREATE TRIGGER discovery_players_update AFTER UPDATE ON players FOR EACH ROW EXECUTE FUNCTION discovery_players_update()")
    purpose = "json_extract(b.manifest,'$.purpose')" if sqlite else "b.manifest->>'purpose'"
    population = "COALESCE(json_extract(b.manifest,'$.test_population'),0)<>1" if sqlite else "b.manifest->>'test_population' IS DISTINCT FROM 'true'"
    for event in ("INSERT", "UPDATE"):
        condition = "NEW.status='verified'" + (" AND OLD.status<>'verified'" if event == "UPDATE" else "")
        body = f"""INSERT INTO discovery_changes(partition,kind,target,player_id,run_id,finished_at,created_at)
          SELECT {partition('v.track_id',sqlite)},'finish',v.track_id,NEW.player_id,NEW.id,COALESCE(NEW.finished_at,0),{stamp}
          FROM boards b JOIN track_versions v ON v.id=b.version_id
          WHERE b.id=NEW.board_id AND ({purpose} IS NULL OR {purpose}<>'creator_test') AND {population}
            AND (v.creator_test_run_id IS NULL OR v.creator_test_run_id<>NEW.id)
          ON CONFLICT(run_id) DO NOTHING;"""
        name = "discovery_runs_" + event.lower()
        if sqlite:
            sql(f"CREATE TRIGGER {name} AFTER {event} ON runs WHEN {condition} BEGIN {body} END")
        else:
            sql(f"CREATE FUNCTION {name}() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF {condition} THEN {body} END IF; RETURN NULL; END $$")
            sql(f"CREATE TRIGGER {name} AFTER {event} ON runs FOR EACH ROW EXECUTE FUNCTION {name}()")


def upgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    # Five votes per 500 million accounts exceeds signed INTEGER. SQLite
    # already stores 64-bit integers; rebuilding it would drop source triggers.
    if not sqlite:
        op.alter_column("track_versions", "rating_sum", existing_type=sa.Integer(), type_=sa.BigInteger())
    kinds = {"int": sa.Integer, "big": sa.BigInteger, "str": sa.String, "bool": sa.Boolean, "json": sa.JSON}
    for name, columns, indexes, unique in SCHEMA:
        args = []
        for col, kind, length, pk, nullable, uniq in columns:
            typ = kinds[kind](length) if kind == "str" else kinds[kind]()
            if name == "discovery_changes" and col == "id":
                typ = sa.BigInteger().with_variant(sa.Integer(), "sqlite")
            args.append(sa.Column(col, typ, primary_key=pk, nullable=nullable, unique=uniq))
        args += [sa.UniqueConstraint(*keys) for keys in unique]
        op.create_table(name, *args)
        for index, keys in indexes:
            op.create_index(index, name, keys)
    for p in range(16):
        sql(f"INSERT INTO discovery_partitions(id,epoch,slots,checked_at,audit_at,cursor,ready) VALUES({p},0,0,0,0,'',false)")
    sql("INSERT INTO discovery_bootstrap(id,finished_at,run_id,ready) VALUES(1,0,'',false)")
    op.create_index("ix_discovery_run_bootstrap", "runs", ["status", "finished_at", "id"])
    op.create_index("ix_discovery_entry_owner", "discovery_entries", ["owner_id", "track_id", "epoch"])
    op.create_index("ix_discovery_boundary_session", "discovery_boundaries", ["session_id", "id"])
    if not sqlite:
        sql("CREATE INDEX ix_discovery_entry_name_trgm ON discovery_entries USING gin (name public.gin_trgm_ops)")
        sql("CREATE INDEX ix_discovery_entry_creator_trgm ON discovery_entries USING gin (creator public.gin_trgm_ops)")
    install(sqlite)


def downgrade():
    raise RuntimeError("Restore the source checkpoint/backup; active v3 cursors require discovery history")
