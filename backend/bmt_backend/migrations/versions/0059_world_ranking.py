"""Prospective World Ranking with compact scores and bounded SQL work."""
import sqlalchemy as sa
from alembic import op

revision = "0059_world_ranking"
down_revision = "0058_challenge_series"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("world_ranking_control",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("launch_week", sa.BigInteger(), nullable=False),
        sa.Column("published_id", sa.Integer()),
        sa.Column("previous_id", sa.Integer()),
        sa.Column("running_branch", sa.Integer(), nullable=False))
    op.create_table("world_ranking_players",
        sa.Column("key", sa.BigInteger().with_variant(sa.Integer(), "sqlite"), primary_key=True, autoincrement=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.UniqueConstraint('player_id'))
    op.create_table("world_circuits",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("week_start", sa.BigInteger(), nullable=False),
        sa.Column("contract_key", sa.String(64), nullable=False),
        sa.Column("policy", sa.String(40), nullable=False),
        sa.Column("tracks", sa.JSON(), nullable=False),
        sa.Column("original_snapshot", sa.Integer()),
        sa.UniqueConstraint('week_start'))
    op.create_table("world_circuit_entries",
        sa.Column("circuit_id", sa.Integer(), sa.ForeignKey("world_circuits.id"), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), sa.ForeignKey("world_ranking_players.key"), primary_key=True),
        sa.Column("group_id", sa.String(36), sa.ForeignKey("rivalry_groups.id"), nullable=False))
    op.create_index("ix_world_circuit_entries_group_id", "world_circuit_entries", ['group_id'])
    op.create_table("world_ranking_branches",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("mode", sa.String(16), nullable=False),
        sa.Column("next_week", sa.BigInteger(), nullable=False),
        sa.Column("through_week", sa.BigInteger()),
        sa.Column("last_snapshot", sa.Integer()),
        sa.Column("snapshot_id", sa.Integer()),
        sa.Column("phase", sa.String(32), nullable=False),
        sa.Column("cursor", sa.BigInteger(), nullable=False),
        sa.Column("part", sa.Integer(), nullable=False),
        sa.Column("lease_token", sa.String(36), nullable=False),
        sa.Column("lease_until", sa.BigInteger(), nullable=False),
        sa.Column("failure", sa.String(160), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False))
    op.create_table("world_ranking_snapshots",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("branch_id", sa.Integer(), sa.ForeignKey("world_ranking_branches.id"), nullable=False),
        sa.Column("circuit_id", sa.Integer(), sa.ForeignKey("world_circuits.id"), nullable=False),
        sa.Column("week_start", sa.BigInteger(), nullable=False),
        sa.Column("previous_id", sa.Integer()),
        sa.Column("field_size", sa.Integer(), nullable=False),
        sa.Column("ranked_count", sa.Integer(), nullable=False),
        sa.Column("season_qualifying_weeks", sa.SmallInteger(), nullable=False),
        sa.Column("state", sa.String(16), nullable=False),
        sa.Column("published_at", sa.BigInteger()),
        sa.UniqueConstraint('branch_id', 'week_start'))
    op.create_table("world_ranking_awards",
        sa.Column("branch_id", sa.Integer(), primary_key=True),
        sa.Column("circuit_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("points", sa.SmallInteger(), nullable=False),
        sa.Column("weekly_place", sa.Integer(), nullable=False))
    op.create_table("world_ranking_standings",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("total", sa.SmallInteger(), nullable=False),
        sa.Column("world_rank", sa.Integer(), nullable=False),
        sa.Column("country", sa.String(2), nullable=False),
        sa.Column("country_rank", sa.Integer()),
        sa.Column("season_points", sa.SmallInteger(), nullable=False),
        sa.Column("season_rank", sa.Integer()))
    op.create_index("ix_world_standing_country", "world_ranking_standings", ['snapshot_id', 'country', 'country_rank', 'player_key'])
    op.create_index("ix_world_standing_page", "world_ranking_standings", ['snapshot_id', 'world_rank', 'player_key'])
    op.create_index("ix_world_standing_season", "world_ranking_standings", ['snapshot_id', 'season_rank', 'player_key'])
    op.create_table("world_ranking_careers",
        sa.Column("branch_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("generation", sa.Integer(), primary_key=True),
        sa.Column("peak_rank", sa.Integer(), nullable=False),
        sa.Column("peak_week", sa.BigInteger(), nullable=False),
        sa.Column("peak_field", sa.Integer(), nullable=False),
        sa.Column("weeks_top100", sa.Integer(), nullable=False),
        sa.Column("weeks_no1", sa.Integer(), nullable=False),
        sa.Column("victories", sa.Integer(), nullable=False),
        sa.Column("season_titles", sa.Integer(), nullable=False))
    op.create_table("world_ranking_archives",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("kind", sa.String(8), primary_key=True),
        sa.Column("part", sa.Integer(), primary_key=True),
        sa.Column("digest", sa.String(64), nullable=False),
        sa.Column("first_key", sa.BigInteger(), nullable=False),
        sa.Column("last_key", sa.BigInteger(), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False))
    op.create_index("ix_world_ranking_archives_digest", "world_ranking_archives", ["digest"])
    op.create_table("world_ranking_corrections",
        sa.Column("command_id", sa.String(128), primary_key=True),
        sa.Column("circuit_id", sa.Integer(), nullable=False),
        sa.Column("player_key", sa.BigInteger(), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("actor", sa.String(120), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False))
    op.create_index("ix_world_correction_week", "world_ranking_corrections", ['circuit_id', 'player_key'])
    op.create_table("world_work_inputs",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("t0", sa.Integer(), nullable=False),
        sa.Column("t1", sa.Integer(), nullable=False),
        sa.Column("t2", sa.Integer(), nullable=False),
        sa.Column("t3", sa.Integer(), nullable=False),
        sa.Column("t4", sa.Integer(), nullable=False),
        sa.Column("country", sa.String(2), nullable=False))
    op.create_table("world_work_places",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("slot", sa.SmallInteger(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("place2", sa.Integer(), nullable=False))
    op.create_table("world_work_weekly",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("sum2", sa.BigInteger(), nullable=False),
        sa.Column("k0", sa.Integer(), nullable=False),
        sa.Column("k1", sa.Integer(), nullable=False),
        sa.Column("k2", sa.Integer(), nullable=False),
        sa.Column("k3", sa.Integer(), nullable=False),
        sa.Column("k4", sa.Integer(), nullable=False))
    op.create_table("world_work_standings",
        sa.Column("snapshot_id", sa.Integer(), primary_key=True),
        sa.Column("player_key", sa.BigInteger(), primary_key=True),
        sa.Column("country", sa.String(2), nullable=False),
        sa.Column("total", sa.SmallInteger(), nullable=False),
        sa.Column("season_points", sa.SmallInteger(), nullable=False),
        sa.Column("world_key", sa.LargeBinary(), nullable=False),
        sa.Column("season_key", sa.LargeBinary(), nullable=False))
    # Legacy 0011 bootstraps the current Rivalry model on a fresh database.
    inspector = sa.inspect(op.get_bind())
    if "world_circuit_id" not in {c["name"] for c in inspector.get_columns("rivalry_groups")}:
        op.add_column("rivalry_groups", sa.Column("world_circuit_id", sa.Integer(), nullable=True))
    if "ix_rivalry_groups_world_circuit_id" not in {i["name"] for i in inspector.get_indexes("rivalry_groups")}:
        op.create_index("ix_rivalry_groups_world_circuit_id", "rivalry_groups", ["world_circuit_id"])


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM world_ranking_snapshots")):
        raise RuntimeError("Preserve World Ranking evidence before downgrade")
    op.drop_index("ix_rivalry_groups_world_circuit_id", table_name="rivalry_groups")
    op.drop_column("rivalry_groups", "world_circuit_id")
    op.drop_table("world_work_standings")
    op.drop_table("world_work_weekly")
    op.drop_table("world_work_places")
    op.drop_table("world_work_inputs")
    op.drop_table("world_ranking_corrections")
    op.drop_table("world_ranking_archives")
    op.drop_table("world_ranking_careers")
    op.drop_table("world_ranking_standings")
    op.drop_table("world_ranking_awards")
    op.drop_table("world_ranking_snapshots")
    op.drop_table("world_ranking_branches")
    op.drop_table("world_circuit_entries")
    op.drop_table("world_circuits")
    op.drop_table("world_ranking_players")
    op.drop_table("world_ranking_control")
