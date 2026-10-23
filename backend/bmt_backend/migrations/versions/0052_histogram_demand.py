"""Index recently viewed histogram refresh work without touching race writes."""
import sqlalchemy as sa
from alembic import op

revision = "0052_histogram_demand"
down_revision = "0051_telemetry_parallel"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("histogram_demand",
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), primary_key=True),
        sa.Column("vehicle_id", sa.String(80), primary_key=True),
        sa.Column("include_artificial", sa.Boolean(), primary_key=True),
        sa.Column("due_at", sa.Integer(), nullable=False),
        sa.Column("requested_until", sa.Integer(), nullable=False))
    op.create_index("ix_histogram_demand_due", "histogram_demand", ["due_at", "version_id", "vehicle_id", "include_artificial"])
    op.create_index("ix_histogram_demand_expiry", "histogram_demand", ["requested_until"])


def downgrade():
    op.drop_table("histogram_demand")
