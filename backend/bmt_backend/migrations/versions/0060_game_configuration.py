"""Versioned app configuration and existing experiment-policy integration."""
import sqlalchemy as sa
from alembic import op

revision = "0060_game_configuration"
down_revision = "0059_world_ranking"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("game_config_control",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("active_generation", sa.Integer(), nullable=False),
        sa.Column("emergency", sa.JSON(), nullable=False))
    op.create_table("game_config_drafts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("base_generation", sa.Integer(), nullable=False),
        sa.Column("policy", sa.JSON(), nullable=False),
        sa.Column("audiences", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.BigInteger(), nullable=False))
    op.create_table("game_config_releases",
        sa.Column("generation", sa.Integer(), primary_key=True, autoincrement=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("policy", sa.JSON(), nullable=False),
        sa.Column("audiences", sa.JSON(), nullable=False),
        sa.Column("fallback", sa.JSON(), nullable=False),
        sa.Column("rollout", sa.Integer(), nullable=False),
        sa.Column("internal_players", sa.JSON(), nullable=False),
        sa.Column("salt", sa.String(64), nullable=False),
        sa.Column("state", sa.String(24), nullable=False),
        sa.Column("base_generation", sa.Integer(), nullable=False),
        sa.Column("scheduled_at", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("actor", sa.String(80), nullable=False))
    op.create_index("ix_game_config_releases_scheduled_at", "game_config_releases", ["scheduled_at"])
    op.create_table("game_config_deliveries",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("generation", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("platform", sa.String(16), nullable=False),
        sa.Column("build_id", sa.String(80), nullable=False),
        sa.Column("observed_at", sa.BigInteger(), nullable=False),
        sa.Column("applied_groups", sa.JSON(), nullable=False))
    op.create_index("ix_game_config_deliveries_observed_at", "game_config_deliveries", ["observed_at"])
    op.add_column("studio_experiments", sa.Column("configuration", sa.JSON(), nullable=False, server_default="{}"))
    op.add_column("studio_assignments", sa.Column("observed_counters", sa.JSON(), nullable=False, server_default="{}"))


def downgrade():
    op.drop_column("studio_assignments", "observed_counters")
    op.drop_column("studio_experiments", "configuration")
    for table in ("game_config_deliveries", "game_config_releases", "game_config_drafts", "game_config_control"):
        op.drop_table(table)
