"""Expand telemetry ownership; preserve receipts and historical prepared totals.

Drain old writers before activation. Pending receipt routing is backfilled by the
bounded worker, not by this migration. PostgreSQL indexes build concurrently.
"""
import sqlalchemy as sa
from alembic import op

revision = "0051_telemetry_parallel"
down_revision = "0050_discovery_indexed"
branch_labels = None
depends_on = None


SCHEMA = [('telemetry_control',
  [('id', 'int', None, True, False, None),
   ('active', 'bool', None, False, False, False),
   ('ready', 'bool', None, False, False, False),
   ('capacity', 'int', None, False, False, 50000),
   ('baseline_processed', 'big', None, False, False, 0),
   ('baseline_truncated', 'big', None, False, False, 0),
   ('barrier', 'json', None, False, False, '{}'),
   ('published_at', 'big', None, False, False, 0),
   ('maintenance_at', 'big', None, False, False, 0),
   ('person_cursor', 'str', 36, False, False, '')],
  []),
 ('telemetry_credits',
  [('id', 'int', None, True, False, None),
   ('capacity', 'int', None, False, False, None),
   ('free', 'int', None, False, False, None)],
  [('ix_telemetry_free_credit', ['free', 'id'])]),
 ('telemetry_intake',
  [('id', 'int', None, True, False, None),
   ('position', 'big', None, False, False, 0),
   ('events', 'big', None, False, False, 0),
   ('clients', 'big', None, False, False, 0),
   ('latest', 'big', None, False, False, 0)],
  []),
 ('telemetry_actors',
  [('id', 'int', None, True, False, None),
   ('position', 'big', None, False, False, 0),
   ('revision', 'big', None, False, False, 0),
   ('serviced_at', 'big', None, False, False, 0),
   ('first_activity', 'big', None, False, True, None),
   ('latest_client_at', 'big', None, False, False, 0),
   ('truncated', 'big', None, False, False, 0)],
  []),
 ('telemetry_finishes',
  [('id', 'int', None, True, False, None),
   ('position', 'big', None, False, False, 0),
   ('events', 'big', None, False, False, 0),
   ('clients', 'big', None, False, False, 0),
   ('processed', 'big', None, False, False, 0)],
  []),
 ('telemetry_shared_intake',
  [('id', 'int', None, True, False, None), ('position', 'big', None, False, False, 0)],
  []),
 ('telemetry_shared',
  [('id', 'int', None, True, False, None),
   ('position', 'big', None, False, False, 0),
   ('revision', 'big', None, False, False, 0),
   ('serviced_at', 'big', None, False, False, 0)],
  []),
 ('telemetry_work',
  [('event_id', 'str', 36, True, False, None),
   ('partition', 'int', None, False, False, None),
   ('position', 'big', None, False, False, None),
   ('kind', 'str', 16, False, False, None),
   ('key', 'str', 64, False, False, None),
   ('player_id', 'str', 36, False, False, None),
   ('owner_id', 'str', 36, False, True, None)],
  [('ix_telemetry_work_order', ['partition', 'position']),
   ('ix_telemetry_work_owner_id', ['owner_id']),
   ('ix_telemetry_work_player_id', ['player_id'])]),
 ('telemetry_metric_partials',
  [('owner', 'int', None, True, False, None),
   ('day', 'int', None, True, False, None),
   ('key', 'str', 48, True, False, None),
   ('dimension', 'str', 32, True, False, None),
   ('value', 'big', None, False, False, None),
   ('revision', 'big', None, False, False, None)],
  [('ix_telemetry_metric_revision', ['owner', 'revision'])]),
 ('telemetry_metric_folds',
  [('owner', 'int', None, True, False, None),
   ('day', 'int', None, True, False, None),
   ('key', 'str', 48, True, False, None),
   ('dimension', 'str', 32, True, False, None),
   ('value', 'big', None, False, False, None)],
  []),
 ('telemetry_rollups',
  [('id', 'int', None, True, False, None),
   ('revision', 'big', None, False, False, 0),
   ('serviced_at', 'big', None, False, False, 0)],
  []),
 ('telemetry_erasure',
  [('player_id', 'str', 36, True, False, None),
   ('cursor', 'str', 36, False, False, ''),
   ('done', 'bool', None, False, False, False)],
  [])]


# Frozen v2 scheduling and expiry fields (not imported from mutable ORM models).
for name, columns, indexes in SCHEMA:
    if name in ("telemetry_actors", "telemetry_shared"):
        columns.extend([("retry_after", "big", None, False, False, 0), ("failures", "big", None, False, False, 0)])
    if name == "telemetry_actors":
        columns.extend([("metric_owner", "int", None, False, True, None),
                        ("metric_revision", "big", None, False, False, 0)])
    if name == "telemetry_metric_partials":
        indexes.append(("ix_telemetry_metric_expiry", ["day", "owner"]))


def upgrade():
    # The concurrent-index block commits the expansion before Alembic records
    # this revision. Resume safely if the process stops during that block.
    connection = op.get_bind()
    existing = set(sa.inspect(connection).get_table_names())
    tables = {}
    for name, columns, indexes in SCHEMA:
        fields = []
        for field, kind, size, primary, nullable, default in columns:
            datatype = {"int": sa.Integer, "big": sa.BigInteger, "bool": sa.Boolean, "json": sa.JSON}.get(kind)
            datatype = datatype() if datatype else sa.String(size)
            options = {"primary_key": primary, "nullable": nullable}
            if default is not None:
                options["server_default"] = (default if kind == "str" else
                    sa.text("'{}'" if kind == "json" else "false" if default is False else str(default)))
            fields.append(sa.Column(field, datatype, **options))
        if name == "telemetry_credits":
            fields.append(sa.CheckConstraint("capacity >= 0 AND free >= 0 AND free <= capacity", name="ck_telemetry_credit_bounds"))
        tables[name] = (sa.Table(name, sa.MetaData(), autoload_with=connection)
                        if name in existing else op.create_table(name, *fields))
        current_indexes = {index["name"] for index in sa.inspect(connection).get_indexes(name)}
        for index, fields in indexes:
            if index not in current_indexes:
                op.create_index(index, name, fields)

    from sqlalchemy.dialects.postgresql import insert as pg_insert
    from sqlalchemy.dialects.sqlite import insert as sqlite_insert
    insert = pg_insert if connection.dialect.name == "postgresql" else sqlite_insert

    def seed(name, values):
        connection.execute(insert(tables[name]).values(values).on_conflict_do_nothing())

    seed("telemetry_control", [{"id": 1}])
    seed("telemetry_credits", [
        {"id": i, "capacity": 50000 // 64 + int(i < 50000 % 64),
         "free": 50000 // 64 + int(i < 50000 % 64)} for i in range(64)])
    for name in ("telemetry_intake", "telemetry_actors", "telemetry_finishes", "telemetry_shared_intake", "telemetry_shared"):
        seed(name, [{"id": i} for i in range(256)])
    seed("telemetry_rollups", [{"id": i} for i in range(512)])
    columns = {column["name"] for column in sa.inspect(connection).get_columns("product_events")}
    for name, kind in (("partition_id", sa.Integer()), ("position", sa.BigInteger()),
                       ("actor_at", sa.BigInteger()), ("credit_bucket", sa.Integer())):
        if name not in columns:
            op.add_column("product_events", sa.Column(name, kind, nullable=True))
    metric_type = next(column["type"] for column in sa.inspect(connection).get_columns("product_metrics")
                       if column["name"] == "value")
    if not isinstance(metric_type, sa.BigInteger):
        with op.batch_alter_table("product_metrics") as table:
            table.alter_column("value", existing_type=sa.Integer(), type_=sa.BigInteger(), existing_nullable=False)
    indexes = (
        ("ix_telemetry_actor_pending", ["partition_id", "position"], "actor_at IS NULL AND processed_at IS NULL"),
        ("ix_telemetry_full_pending", ["partition_id", "position"], "processed_at IS NULL"),
        ("ix_telemetry_legacy_pending", ["id"], "partition_id IS NULL AND processed_at IS NULL"),
    )
    if op.get_bind().dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            def concurrent_index(name, table, columns, **options):
                valid = connection.scalar(sa.text("SELECT i.indisvalid FROM pg_index i "
                    "JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_namespace n ON n.oid=c.relnamespace "
                    "WHERE n.nspname=current_schema() AND c.relname=:name"), {"name": name})
                if valid is True:
                    return
                if valid is False:
                    op.drop_index(name, table_name=table, postgresql_concurrently=True)
                op.create_index(name, table, columns, postgresql_concurrently=True, **options)

            for name, columns, predicate in indexes:
                concurrent_index(name, "product_events", columns, postgresql_where=sa.text(predicate))
            concurrent_index("ix_product_publication_owner", "product_publications", ["owner_id", "version_id"])
            concurrent_index("ix_analysis_session_expiry", "studio_analysis_sessions", ["last_at", "player_id", "session_id"])
    else:
        for name, columns, predicate in indexes:
            op.create_index(name, "product_events", columns, sqlite_where=sa.text(predicate))
        op.create_index("ix_product_publication_owner", "product_publications", ["owner_id", "version_id"])
        op.create_index("ix_analysis_session_expiry", "studio_analysis_sessions", ["last_at", "player_id", "session_id"])


def downgrade():
    raise RuntimeError("Telemetry v2 rollback uses its serial mode; restore a reconciled backup for legacy binaries")
