"""Shared stable discovery order without duplicating track documents."""
import sqlalchemy as sa
from alembic import op

revision = "0019_discovery_snapshots"
down_revision = "0018_player_country"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table("discovery_snapshots", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("query_hash", sa.String(64), nullable=False), sa.Column("expires_at", sa.Integer(), nullable=False),
        sa.Column("version_ids", sa.JSON(), nullable=False))
    op.create_index("ix_discovery_snapshot_expiry", "discovery_snapshots", ["expires_at"])
    op.create_index("ix_discovery_names", "track_versions", [sa.text("lower(name)"), "state"])
    op.create_index("ix_discovery_recent_runs", "runs", ["status", "finished_at", "board_id", "player_id"])

    if op.get_bind().dialect.name == "postgresql":
        op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public")
        op.execute("CREATE INDEX ix_discovery_name_trgm ON track_versions USING gin (name public.gin_trgm_ops)")
        op.execute("CREATE INDEX ix_discovery_creator_trgm ON players USING gin (display_name public.gin_trgm_ops)")

def downgrade():
    if op.get_bind().dialect.name == "postgresql":
        op.drop_index("ix_discovery_name_trgm", table_name="track_versions")
        op.drop_index("ix_discovery_creator_trgm", table_name="players")
    op.drop_index("ix_discovery_recent_runs", table_name="runs")
    op.drop_index("ix_discovery_names", table_name="track_versions")
    op.drop_table("discovery_snapshots")
