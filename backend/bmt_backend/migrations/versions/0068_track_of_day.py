"""Permanent Track of the Day selection and logical-track history."""
import sqlalchemy as sa
from alembic import op

revision = "0068_track_of_day"
down_revision = "0067_discovery_rank"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("track_of_day_state",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("mature", sa.Boolean(), nullable=False),
        sa.Column("last_day", sa.BigInteger(), nullable=False))
    op.create_table("track_of_day_history",
        sa.Column("track_id", sa.String(36), primary_key=True),
        sa.Column("first_day", sa.BigInteger(), nullable=False),
        sa.Column("last_day", sa.BigInteger(), nullable=False))
    op.create_table("track_of_days",
        sa.Column("day", sa.BigInteger(), primary_key=True),
        sa.Column("policy", sa.String(40), nullable=False),
        sa.Column("track_id", sa.String(36), nullable=True),
        sa.Column("version_id", sa.String(36), nullable=True),
        sa.Column("reason", sa.String(24), nullable=False),
        sa.Column("selected_at", sa.BigInteger(), nullable=False))


def downgrade():
    # Explicit rollback only: this removes the permanent no-repeat ledger.
    op.drop_table("track_of_days")
    op.drop_table("track_of_day_history")
    op.drop_table("track_of_day_state")
