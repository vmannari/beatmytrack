"""Verified best times for each featured UTC day and immutable vehicle board."""
import sqlalchemy as sa
from alembic import op

revision = "0071_track_of_day_bests"
down_revision = "0070_reward_cache_revisions"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("track_of_day_bests",
        sa.Column("day", sa.BigInteger(), primary_key=True),
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("run_id", sa.String(36), nullable=False),
        sa.Column("time_ticks", sa.Integer(), nullable=False),
        sa.Column("achieved_at", sa.BigInteger(), nullable=False),
        sa.CheckConstraint("time_ticks > 0 AND time_ticks <= 216000"))
    op.create_index("ix_daily_best_order", "track_of_day_bests", ["day", "board_id", "time_ticks", "player_id"])
    sqlite = op.get_bind().dialect.name == "sqlite"
    purpose = "json_extract(b.manifest,'$.purpose')" if sqlite else "b.manifest->>'purpose'"
    artificial = "json_extract(b.manifest,'$.test_population')" if sqlite else "b.manifest->>'test_population'"
    laps = "json_extract(b.manifest,'$.laps')" if sqlite else "b.manifest->>'laps'"
    # Migration only: retain existing independently verified daily results, including
    # slower-than-all-time PBs. Skipped/unverified hints never enter the projection.
    op.execute(f"""INSERT INTO track_of_day_bests(day,board_id,player_id,run_id,time_ticks,achieved_at)
        SELECT day,board_id,player_id,id,time_ticks,created_at FROM (
          SELECT d.day,r.board_id,r.player_id,r.id,r.time_ticks,r.created_at,
            row_number() OVER(PARTITION BY d.day,r.board_id,r.player_id
              ORDER BY r.time_ticks,r.created_at,r.id) AS ordinal
          FROM track_of_days d JOIN boards b ON b.version_id=d.version_id
          JOIN runs r ON r.board_id=b.id JOIN run_tickets t ON t.id=r.ticket_id
          JOIN players p ON p.id=r.player_id
          WHERE r.status='verified' AND r.time_ticks>0 AND r.time_ticks<=216000
            AND t.created_at>=d.day*86400 AND t.created_at<(d.day+1)*86400
            AND r.created_at>=t.created_at AND r.created_at<(d.day+1)*86400
            AND NOT p.disabled AND NOT p.is_test_driver AND p.deleted_at IS NULL
            AND coalesce({purpose},'race')<>'creator_test'
            AND coalesce(CAST({artificial} AS TEXT),'false') NOT IN ('true','1')
            AND CAST({laps} AS INTEGER)=5) eligible WHERE ordinal=1""")


def downgrade():
    op.drop_index("ix_daily_best_order", table_name="track_of_day_bests")
    op.drop_table("track_of_day_bests")
