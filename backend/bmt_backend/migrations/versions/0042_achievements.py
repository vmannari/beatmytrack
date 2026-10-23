"""Permanent, bounded achievement projections; no historical race scan."""
import sqlalchemy as sa
from alembic import op

revision = "0042_achievements"
down_revision = "0041_challenge_discovery"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("achievement_states",
        sa.Column("player_id", sa.String(36), primary_key=True),
        sa.Column("scope", sa.String(8), primary_key=True),
        sa.Column("metrics", sa.JSON(), nullable=False),
        sa.Column("unlocked", sa.JSON(), nullable=False),
        sa.Column("featured", sa.JSON(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("rarity_pending", sa.Boolean(), nullable=False),
        sa.Column("rarity_counted", sa.JSON(), nullable=False))
    op.create_index("ix_achievement_rarity_pending", "achievement_states", ["rarity_pending", "player_id", "scope"])
    op.create_table("achievement_cohort", sa.Column("player_id", sa.String(36), primary_key=True))
    op.create_table("achievement_counts", sa.Column("key", sa.String(64), primary_key=True),
        sa.Column("shard", sa.Integer(), primary_key=True), sa.Column("value", sa.BigInteger(), nullable=False))
    op.create_table("achievement_facts", sa.Column("player_id", sa.String(36), primary_key=True),
        sa.Column("kind", sa.String(16), primary_key=True), sa.Column("identity", sa.String(64), primary_key=True))
    op.create_table("achievement_competitions", sa.Column("kind", sa.String(12), primary_key=True),
        sa.Column("id", sa.String(36), primary_key=True), sa.Column("due_at", sa.Integer(), nullable=False),
        sa.Column("done", sa.Boolean(), nullable=False), sa.Column("facts", sa.JSON(), nullable=False))
    op.create_index("ix_achievement_competition_due", "achievement_competitions", ["done", "due_at", "id"])
    op.create_table("achievement_records", sa.Column("board_id", sa.String(64), primary_key=True),
        sa.Column("player_id", sa.String(36), nullable=False), sa.Column("ticks", sa.Integer(), nullable=False),
        sa.Column("since", sa.Integer(), nullable=False), sa.Column("due_at", sa.Integer(), nullable=False))
    op.create_index("ix_achievement_record_due", "achievement_records", ["due_at", "board_id"])
    op.create_index("ix_achievement_records_player_id", "achievement_records", ["player_id"])


def downgrade():
    for table in ("achievement_records", "achievement_competitions", "achievement_facts",
                  "achievement_counts", "achievement_cohort", "achievement_states"):
        op.drop_table(table)
