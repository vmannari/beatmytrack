"""Persistent, versioned weekly Rivalry schedules."""
import sqlalchemy as sa
from alembic import op

revision = "0043_rivalry_planning"
down_revision = "0042_achievements"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("rivalry_week_plans",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("week_start", sa.Integer(), nullable=False),
        sa.Column("contract_key", sa.String(64), nullable=False),
        sa.Column("vehicle_id", sa.String(80), nullable=False),
        sa.Column("tracks", sa.JSON(), nullable=False),
        sa.Column("seed", sa.String(64), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.Integer(), nullable=False),
        sa.UniqueConstraint("week_start", "contract_key"))
    op.create_index("ix_rivalry_plan_vehicle_week", "rivalry_week_plans", ["vehicle_id", "week_start"])


def downgrade():
    op.drop_table("rivalry_week_plans")
