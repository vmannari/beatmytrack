"""Shared first-publication facts, read only by friends opening News."""
import sqlalchemy as sa
from alembic import op

revision = "0039_friend_publications"
down_revision = "0038_garage_news"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("news_publications",
        sa.Column("track_id", sa.String(36), sa.ForeignKey("tracks.id"), primary_key=True),
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), nullable=False),
        sa.Column("owner_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("published_at", sa.Integer(), nullable=False))
    op.create_index("ix_news_publications_owner", "news_publications", ["owner_id", "published_at", "version_id"])
    op.create_index("ix_news_publications_expiry", "news_publications", ["published_at", "track_id"])
    # Future publications only: do not invent historical friend announcements.


def downgrade():
    op.drop_table("news_publications")
