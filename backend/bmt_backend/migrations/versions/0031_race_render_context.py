"""Retain bounded rendering context; historical observations stay unknown."""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "0031_race_render_context"
down_revision = "0030_studio_catalogue"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("race_statistics_days", sa.Column("render_context_key", sa.String(64), nullable=True))
    op.add_column("race_statistics_days", sa.Column("render_context",
        sa.JSON().with_variant(JSONB(), "postgresql"), nullable=True))
    op.add_column("race_statistics_days", sa.Column("render_context_changed", sa.Boolean(), nullable=True))


def downgrade():
    with op.batch_alter_table("race_statistics_days") as table:
        table.drop_column("render_context_changed")
        table.drop_column("render_context")
        table.drop_column("render_context_key")
