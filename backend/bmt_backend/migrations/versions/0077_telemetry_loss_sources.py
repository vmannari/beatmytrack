"""Keep loss-counter watermarks per account/source without unbounded profile JSON."""
import sqlalchemy as sa
from alembic import op

revision = "0077_telemetry_loss_sources"
down_revision = "0076_multi_car_world_ranking"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("product_loss_sources",
        sa.Column("player_id", sa.String(36), primary_key=True),
        sa.Column("source_id", sa.String(36), primary_key=True),
        sa.Column("counters", sa.JSON(), nullable=False))


def downgrade():
    op.drop_table("product_loss_sources")
