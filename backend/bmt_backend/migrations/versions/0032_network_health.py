"""Prepared network counters and bounded selected-failure lookup."""
import sqlalchemy as sa
from alembic import op

revision = "0032_network_health"
down_revision = "0031_race_render_context"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("network_health_days", sa.Column("day", sa.Integer(), primary_key=True),
        sa.Column("dimension", sa.String(64), primary_key=True),
        sa.Column("platform", sa.String(12), nullable=False), sa.Column("build_id", sa.String(80), nullable=False),
        sa.Column("category", sa.String(24), nullable=False), sa.Column("device_model", sa.String(80), nullable=False),
        sa.Column("os_version", sa.String(80), nullable=False), sa.Column("counters", sa.JSON(), nullable=False),
        sa.Column("buckets", sa.JSON(), nullable=False), sa.Column("latest_received_at", sa.BigInteger(), nullable=False))
    op.create_index("ix_network_health_scope", "network_health_days", ["platform", "build_id", "day"])
    selected = sa.text("source='client' AND name='network_failure'")
    op.create_index("ix_product_network_failures", "product_events", ["occurred_at", "id"],
        sqlite_where=selected, postgresql_where=selected)


def downgrade():
    op.drop_index("ix_product_network_failures", table_name="product_events")
    op.drop_table("network_health_days")
