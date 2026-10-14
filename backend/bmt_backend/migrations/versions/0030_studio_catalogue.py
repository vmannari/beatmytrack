"""Indexed published catalogue sorting and case-linked support queries.

Revision ID: 0030_studio_catalogue
Revises: 0029_race_statistics
"""

import sqlalchemy as sa
from alembic import op

revision = "0030_studio_catalogue"
down_revision = "0029_race_statistics"
branch_labels = None
depends_on = None


def upgrade():
    published = sa.text("state = 'published'")
    for name, columns in (
        ("ix_studio_published_name", [sa.text("lower(name)"), "id"]),
        ("ix_studio_published_finishers", ["verified_finishers", "id"]),
        ("ix_studio_published_rating", [sa.text("(rating_sum * 1.0 / nullif(rating_count, 0))"), "id"]),
    ):
        op.create_index(name, "track_versions", columns, sqlite_where=published, postgresql_where=published)
    op.create_index("ix_studio_player_created", "players", ["created_at", "id"])
    op.create_index("ix_studio_player_name", "players", [sa.text("lower(display_name)"), "id"])
    op.create_index("ix_studio_case_player", "studio_cases", ["player_id", "status", "updated_at", "id"])
    op.create_index("ix_studio_case_track", "studio_cases", ["track_id", "updated_at", "id"])


def downgrade():
    for name, table in (
        ("ix_studio_case_track", "studio_cases"), ("ix_studio_case_player", "studio_cases"),
        ("ix_studio_player_name", "players"), ("ix_studio_player_created", "players"),
        ("ix_studio_published_rating", "track_versions"), ("ix_studio_published_finishers", "track_versions"),
        ("ix_studio_published_name", "track_versions"),
    ):
        op.drop_index(name, table_name=table)
