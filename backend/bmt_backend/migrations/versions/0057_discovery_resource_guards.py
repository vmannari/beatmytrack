"""Shared discovery work leases and bounded retained-member accounting.

Existing collections are accounted by the worker in bounded indexed batches.
New member writes wait for accounting; ordinary discovery and retained views
remain readable. Drain old API writers during this coordinated rollout.
"""
import sqlalchemy as sa
from alembic import op

revision = "0057_discovery_resource_guards"
down_revision = "0056_bounded_retention"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("discovery_guards",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("scope", sa.String(64), nullable=False),
        sa.Column("lane", sa.String(8), nullable=False),
        sa.Column("window", sa.BigInteger(), nullable=False),
        sa.Column("used_units", sa.Integer(), nullable=False),
        sa.Column("failures", sa.Integer(), nullable=False),
        sa.Column("cooldown_until", sa.BigInteger(), nullable=False),
        sa.Column("lease_until", sa.BigInteger(), nullable=False),
        sa.Column("lease_token", sa.String(32), nullable=False),
        sa.Column("expires_at", sa.BigInteger(), nullable=False))
    op.create_index("ix_discovery_guard_expire", "discovery_guards", ["expires_at", "id"])
    op.create_index("ix_discovery_guard_scope", "discovery_guards", ["scope", "id"])
    op.create_table("discovery_storage",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("member_rows", sa.BigInteger(), nullable=False),
        sa.Column("member_bytes", sa.BigInteger(), nullable=False))
    op.bulk_insert(sa.table("discovery_storage", sa.column("id"), sa.column("member_rows"), sa.column("member_bytes")),
        [{"id": i, "member_rows": 0, "member_bytes": 0} for i in range(16)])
    op.create_table("discovery_storage_bootstrap",
        sa.Column("id", sa.Integer(), primary_key=True), sa.Column("ready", sa.Boolean(), nullable=False))
    existing = op.get_bind().scalar(sa.text("SELECT id FROM discovery_collections LIMIT 1"))
    op.bulk_insert(sa.table("discovery_storage_bootstrap", sa.column("id"), sa.column("ready", sa.Boolean())),
                   [{"id": 1, "ready": existing is None}])
    for column in (
        sa.Column("member_rows", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("member_bytes", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("accounted", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("capacity_partition", sa.Integer(), nullable=True),
        sa.Column("member_cursor_kind", sa.String(8), nullable=False, server_default=""),
        sa.Column("member_cursor_id", sa.String(80), nullable=False, server_default=""),
    ):
        op.add_column("discovery_collections", column)
    op.create_index("ix_discovery_collection_accounted", "discovery_collections", ["accounted", "id"])


def downgrade():
    op.drop_index("ix_discovery_collection_accounted", table_name="discovery_collections")
    for name in ("member_cursor_id", "member_cursor_kind", "capacity_partition", "accounted", "member_bytes", "member_rows"):
        op.drop_column("discovery_collections", name)
    op.drop_table("discovery_storage_bootstrap")
    op.drop_table("discovery_storage")
    op.drop_table("discovery_guards")
