"""Retire disposable v2 catalogue vectors after the v3-only client transition.

No tracks, results, tickets, player settings or current v3 journals are changed.
Apply through the explicit migrator; HTTP and workers never perform this DDL.
"""
import sqlalchemy as sa
from alembic import op

revision = "0062_retire_discovery_cache"
down_revision = "0061_security_authority"
branch_labels = None
depends_on = None


def upgrade():
    op.drop_table("discovery_budget")
    op.drop_table("discovery_snapshots")


def downgrade():
    # These are expiring caches. Recreate empty storage, never old vectors.
    op.create_table("discovery_snapshots", sa.Column("id", sa.String(36), primary_key=True),
                    sa.Column("query_hash", sa.String(64), nullable=False),
                    sa.Column("expires_at", sa.Integer(), nullable=False),
                    sa.Column("version_ids", sa.JSON(), nullable=False),
                    sa.Column("entry_count", sa.Integer(), nullable=False, server_default="0"))
    op.create_index("ix_discovery_snapshot_expiry", "discovery_snapshots", ["expires_at"])
    op.create_table("discovery_budget", sa.Column("id", sa.Integer(), primary_key=True),
                    sa.Column("entries", sa.Integer(), nullable=False),
                    sa.Column("snapshots", sa.Integer(), nullable=False))
    op.execute(sa.text("INSERT INTO discovery_budget VALUES (1,0,0)"))
