"""Indexed composite ranking for continuation beyond the daily Free Race picks."""
import sqlalchemy as sa
from alembic import op

revision = "0067_discovery_rank"
down_revision = "0066_cost_archives"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("discovery_entries", sa.Column("recommendation_score", sa.Integer(),
        nullable=False, server_default="0"))
    op.create_index("ix_discovery_entry_recommended", "discovery_entries",
        ["partition", "recommendation_score", "track_id"])
    # Reuse the bounded worker bootstrap. Retain epochs/history for open views;
    # new views wait until every current entry has its composite score.
    op.execute(sa.text("UPDATE discovery_partitions SET ready=false, cursor=''"))


def downgrade():
    # Only daily views can contain a composite-rank cursor. Source data and
    # ordinary discovery views survive this explicit rollback.
    condition = ("json_extract(query, '$.daily_day') IS NOT NULL" if op.get_bind().dialect.name == "sqlite"
        else "query->>'daily_day' IS NOT NULL")
    op.execute(sa.text("DELETE FROM discovery_boundaries WHERE session_id IN "
        "(SELECT id FROM discovery_sessions WHERE " + condition + ")"))
    op.execute(sa.text("DELETE FROM discovery_sessions WHERE " + condition))
    op.drop_index("ix_discovery_entry_recommended", table_name="discovery_entries")
    op.drop_column("discovery_entries", "recommendation_score")
