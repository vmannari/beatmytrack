"""Private Garage news and demand-only daily comparisons; no recurring player sweep."""
import sqlalchemy as sa
from alembic import op

revision = "0038_garage_news"
down_revision = "0037_earned_coins"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("news_friends",
        sa.Column("low_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("high_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("requested_by", sa.String(36), nullable=False),
        sa.Column("accepted", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_index("ix_news_friends_high", "news_friends", ["high_id", "low_id"])
    op.create_table("news_items",
        sa.Column("id", sa.String(36), primary_key=True),
        # Materialized inbox IDs do not lock another player's FK during score writes.
        sa.Column("player_id", sa.String(36), nullable=False),
        sa.Column("event_key", sa.String(64), nullable=False),
        sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), nullable=False),
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), nullable=True),
        sa.Column("actor_id", sa.String(36), nullable=True),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.UniqueConstraint("player_id", "event_key"))
    op.create_index("ix_news_feed", "news_items", ["player_id", "created_at", "id"])
    op.create_index("ix_news_expiry", "news_items", ["created_at", "id"])
    op.create_index("ix_news_items_actor_id", "news_items", ["actor_id"])
    op.create_table("news_demand",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("requested_day", sa.Integer(), nullable=False),
        sa.Column("completed_day", sa.Integer(), nullable=False),
        sa.Column("requested_until", sa.Integer(), nullable=False),
        sa.Column("pending", sa.Boolean(), nullable=False),
        sa.Column("cursor", sa.String(64), nullable=False))
    op.create_index("ix_news_demand_active", "news_demand", ["pending", "requested_until", "player_id"])
    op.create_table("news_watches",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("friend_key", sa.String(64), nullable=False),
        sa.Column("race_ticks", sa.Integer(), nullable=True),
        sa.Column("lap_ticks", sa.Integer(), nullable=True),
        sa.Column("race_band", sa.Integer(), nullable=True),
        sa.Column("lap_band", sa.Integer(), nullable=True),
        sa.Column("friends", sa.JSON(), nullable=False))
    op.create_table("news_bands",
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("checked_day", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("race", sa.JSON(), nullable=False),
        sa.Column("lap", sa.JSON(), nullable=False))
    op.create_table("news_track_reach",
        sa.Column("track_id", sa.String(36), sa.ForeignKey("tracks.id"), primary_key=True),
        sa.Column("racers", sa.Integer(), nullable=False),
        sa.Column("milestone", sa.Integer(), nullable=False))
    op.create_table("news_track_racers",
        sa.Column("track_id", sa.String(36), sa.ForeignKey("tracks.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True))
    op.create_index("ix_news_track_racers_player_id", "news_track_racers", ["player_id"])
    op.create_index("ix_news_pb_player_board", "personal_bests", ["player_id", "board_id"])
    op.create_index("ix_news_lap_rank", "lap_personal_bests", ["board_id", "time_ticks", "player_id"])
    # One-time distinct, lifetime public participation across immutable revisions.
    # Existing milestones establish the baseline; deployment never invents old news.
    op.execute(sa.text("""INSERT INTO news_track_racers(track_id,player_id)
        SELECT DISTINCT v.track_id,f.player_id FROM version_finishers f
        JOIN track_versions v ON v.id=f.version_id JOIN players p ON p.id=f.player_id
        WHERE p.is_test_driver=false"""))
    op.execute(sa.text("""INSERT INTO news_track_reach(track_id,racers,milestone)
        SELECT track_id,count(*),CASE WHEN count(*)>=10000 THEN 10000
        WHEN count(*)>=1000 THEN 1000 WHEN count(*)>=100 THEN 100 ELSE 0 END
        FROM news_track_racers GROUP BY track_id"""))


def downgrade():
    op.drop_index("ix_news_lap_rank", table_name="lap_personal_bests")
    op.drop_index("ix_news_pb_player_board", table_name="personal_bests")
    for name in ("news_track_racers", "news_track_reach", "news_bands", "news_watches",
                 "news_demand", "news_items", "news_friends"):
        op.drop_table(name)
