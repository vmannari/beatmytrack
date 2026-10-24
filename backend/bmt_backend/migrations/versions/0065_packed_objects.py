"""Durable bounded object intake and independently compressed immutable packs."""
import sqlalchemy as sa
from alembic import op

revision = "0065_packed_objects"
down_revision = "0064_daily_track_selection"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("object_partitions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("pending_bytes", sa.Integer(), nullable=False),
        sa.Column("pending_records", sa.Integer(), nullable=False),
        sa.Column("lease_until", sa.Integer(), nullable=False),
        sa.Column("lease_token", sa.String(36), nullable=False),
        sa.Column("batch", sa.JSON(), nullable=False), sa.CheckConstraint("pending_bytes >= 0 AND pending_records >= 0"))
    op.create_table("object_packs",
        sa.Column("digest", sa.String(64), primary_key=True),
        sa.Column("size", sa.Integer(), nullable=False), sa.Column("records", sa.Integer(), nullable=False),
        sa.Column("dead_bytes", sa.Integer(), nullable=False), sa.Column("retire_after", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False), sa.Column("hold_until", sa.Integer(), nullable=False))
    op.create_index("ix_object_packs_retire_after", "object_packs", ["retire_after"])
    op.create_table("packed_objects",
        sa.Column("digest", sa.String(64), primary_key=True), sa.Column("partition", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False), sa.Column("pending", sa.LargeBinary(), nullable=True),
        sa.Column("pack_digest", sa.String(64), sa.ForeignKey("object_packs.digest"), nullable=True),
        sa.Column("offset", sa.Integer(), nullable=False), sa.Column("length", sa.Integer(), nullable=False),
        sa.CheckConstraint('length > 0 AND "offset" >= 0'))
    op.create_index("ix_packed_object_pending", "packed_objects", ["partition", "created_at", "digest"],
                    postgresql_where=sa.text("pending IS NOT NULL"), sqlite_where=sa.text("pending IS NOT NULL"))
    op.create_index("ix_packed_objects_created_at", "packed_objects", ["created_at"])
    op.create_index("ix_packed_objects_pack_digest", "packed_objects", ["pack_digest"])


def downgrade():
    # Pending bytes and live packs are authoritative. Never discard them on rollback.
    if op.get_bind().scalar(sa.text("SELECT 1 FROM packed_objects LIMIT 1")):
        raise RuntimeError("Drain/materialize packed objects before removing packed storage")
    op.drop_table("packed_objects")
    op.drop_table("object_packs")
    op.drop_table("object_partitions")
