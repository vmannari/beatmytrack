"""Prepared client quality and spatial counters."""
import sqlalchemy as sa
from alembic import op

revision = "0027_client_quality"
down_revision = "0026_studio_cases"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index("ix_studio_creator_versions", "track_versions", ["created_at", "id"])
    op.create_index("ix_studio_rivalry_recent", "rivalry_groups", ["created_at", "id"])
    op.create_index("ix_studio_challenge_recent", "challenges", ["created_at", "id"])
    op.create_table("quality_facts", sa.Column("day", sa.Integer(), primary_key=True),
        sa.Column("kind", sa.String(24), primary_key=True), sa.Column("dimension", sa.String(64), primary_key=True),
        sa.Column("context", sa.JSON(), nullable=False),
        *(sa.Column(field, sa.BigInteger(), nullable=False) for field in
            ("reports", "samples", "slow", *("b" + str(i) for i in range(8)))))


def downgrade():
    op.drop_table("quality_facts")
    op.drop_index("ix_studio_challenge_recent", table_name="challenges")
    op.drop_index("ix_studio_rivalry_recent", table_name="rivalry_groups")
    op.drop_index("ix_studio_creator_versions", table_name="track_versions")
