"""Publish immutable per-car lap cutoffs with the daily track."""
import sqlalchemy as sa
from alembic import op

revision = "0072_fixed_daily_lap_limits"
down_revision = "0071_track_of_day_bests"
branch_labels = None
depends_on = None


def upgrade():
    # Existing days are prepared once by discovery maintenance after rollout.
    # GET handlers never initialise or replace limits.
    op.add_column("track_of_days", sa.Column("lap_limits", sa.JSON(), nullable=False,
                                           server_default=sa.text("'{}'")))


def downgrade():
    op.drop_column("track_of_days", "lap_limits")
