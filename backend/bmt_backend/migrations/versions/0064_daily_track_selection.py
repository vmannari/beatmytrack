"""Daily Free Race selection and bounded, prospective verified replay signals."""
import sqlalchemy as sa
from alembic import op

revision = "0064_daily_track_selection"
down_revision = "0063_custom_challenge_tracks"
branch_labels = None
depends_on = None


def upgrade():
    for name in ("activity_races", "activity_replays"):
        op.add_column("discovery_heads", sa.Column(name, sa.BigInteger(), nullable=False, server_default="0"))
    op.create_index("ix_discovery_head_track", "discovery_heads", ["partition", "track_id"])
    op.create_table("discovery_activity",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("track_id", sa.String(36), nullable=False),
        sa.Column("player_id", sa.String(36), nullable=False),
        sa.Column("partition", sa.Integer(), nullable=False),
        sa.Column("day", sa.BigInteger(), nullable=False),
        sa.Column("races", sa.Integer(), nullable=False),
        sa.Column("counted", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("track_id", "player_id", "day"))
    op.create_index("ix_discovery_activity_expire", "discovery_activity", ["partition", "day", "id"])
    op.create_index("ix_discovery_activity_player", "discovery_activity", ["player_id", "partition", "id"])
    op.create_table("discovery_days",
        sa.Column("day", sa.BigInteger(), primary_key=True),
        sa.Column("policy", sa.String(40), nullable=False),
        sa.Column("shard", sa.Integer(), nullable=False),
        sa.Column("cursor", sa.String(36), nullable=False),
        sa.Column("pools", sa.JSON(), nullable=False),
        sa.Column("items", sa.JSON(), nullable=False),
        sa.Column("published_at", sa.BigInteger(), nullable=False))


def downgrade():
    # Explicit rollback invalidates only disposable daily cursors. Canonical
    # tracks, runs, ratings, collections and ordinary discovery views survive.
    condition = ("json_extract(query, '$.daily_day') IS NOT NULL" if op.get_bind().dialect.name == "sqlite"
        else "query->>'daily_day' IS NOT NULL")
    op.execute(sa.text("DELETE FROM discovery_boundaries WHERE session_id IN "
        "(SELECT id FROM discovery_sessions WHERE " + condition + ")"))
    op.execute(sa.text("DELETE FROM discovery_sessions WHERE " + condition))
    op.drop_table("discovery_days")
    op.drop_table("discovery_activity")
    op.drop_index("ix_discovery_head_track", table_name="discovery_heads")
    op.drop_column("discovery_heads", "activity_replays")
    op.drop_column("discovery_heads", "activity_races")
