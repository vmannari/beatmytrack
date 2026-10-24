"""Encrypted exact retry/reward archives and exact anonymous financial counters."""
import sqlalchemy as sa
from alembic import op

revision = "0066_cost_archives"
down_revision = "0065_packed_objects"
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    if "reward_archive_hash" not in {column["name"] for column in sa.inspect(connection).get_columns("runs")}:
        op.add_column("runs", sa.Column("reward_archive_hash", sa.String(64), nullable=True))
    if "archive_key" not in {column["name"] for column in sa.inspect(connection).get_columns("domain_idempotency")}:
        op.add_column("domain_idempotency", sa.Column("archive_key", sa.String(80), nullable=False, server_default=""))
    if connection.dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            for name, definition in (("ix_domain_idempotency_archive_key", "ON domain_idempotency (archive_key) WHERE archive_key <> ''"),
                                     ("ix_coin_reward_archive", "ON coin_rewards (created_at, run_id)")):
                valid = connection.scalar(sa.text("SELECT i.indisvalid FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid WHERE c.relname=:name AND c.relnamespace=current_schema()::regnamespace"), {"name": name})
                if valid is False:
                    connection.execute(sa.text("DROP INDEX CONCURRENTLY " + name))
                connection.execute(sa.text("CREATE INDEX CONCURRENTLY IF NOT EXISTS " + name + " " + definition))
    else:
        op.create_index("ix_domain_idempotency_archive_key", "domain_idempotency", ["archive_key"], sqlite_where=sa.text("archive_key <> ''"))
        op.create_index("ix_coin_reward_archive", "coin_rewards", ["created_at", "run_id"])
    op.create_table("object_garbage_candidates", sa.Column("digest", sa.String(64), primary_key=True),
                    sa.Column("due_at", sa.Integer(), nullable=False))
    op.create_index("ix_object_garbage_candidates_due_at", "object_garbage_candidates", ["due_at"])
    op.create_table("private_archive_keys", sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
                    sa.Column("secret", sa.LargeBinary(), nullable=False), sa.Column("key_id", sa.String(64), nullable=False),
                    sa.UniqueConstraint("key_id"))
    op.create_table("cost_archive_chunks", sa.Column("digest", sa.String(64), primary_key=True),
        sa.Column("kind", sa.String(16), nullable=False), sa.Column("lower", sa.String(80), nullable=False),
        sa.Column("upper", sa.String(80), nullable=False), sa.Column("records", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_index("ix_cost_archive_lookup", "cost_archive_chunks", ["kind", "lower", "upper"])
    op.create_table("coin_archive_metrics", sa.Column("at", sa.Integer(), primary_key=True),
        sa.Column("kind", sa.String(16), primary_key=True), sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("count", sa.BigInteger(), nullable=False))


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT 1 FROM cost_archive_chunks LIMIT 1")):
        raise RuntimeError("Materialize exact archives before removing archive support")
    op.drop_table("coin_archive_metrics")
    op.drop_table("object_garbage_candidates")
    op.drop_table("cost_archive_chunks")
    op.drop_table("private_archive_keys")
    op.drop_index("ix_coin_reward_archive", table_name="coin_rewards")
    op.drop_index("ix_domain_idempotency_archive_key", table_name="domain_idempotency")
    op.drop_column("domain_idempotency", "archive_key")
    op.drop_column("runs", "reward_archive_hash")
