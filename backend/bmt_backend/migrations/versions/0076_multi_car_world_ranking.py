"""Per-car World Rankings and frozen dynamic competition weights; preserve v1 history."""
import sqlalchemy as sa
from alembic import op

revision = "0076_multi_car_world_ranking"
down_revision = "0075_receipt_reference_indexes"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index("ix_world_ranking_published", "world_ranking_snapshots", ["published_at", "id"])
    op.add_column("world_ranking_corrections", sa.Column("vehicle_id", sa.String(80), nullable=False, server_default=""))
    op.create_table('world_car_circuits',
        sa.Column('circuit_id', sa.Integer(), sa.ForeignKey('world_circuits.id'), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('contract_key', sa.String(length=64), nullable=False),
        sa.Column('tracks', sa.JSON(), nullable=False),
        sa.Column('participation_bps', sa.Integer(), nullable=False),
        sa.Column('population_units', sa.BigInteger(), nullable=False),
        sa.Column('population_snapshot', sa.Integer(), nullable=True),
        sa.Column('weights_locked', sa.Boolean(), nullable=False))
    op.create_table('world_car_entries',
        sa.Column('circuit_id', sa.Integer(), sa.ForeignKey('world_circuits.id'), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), sa.ForeignKey('world_ranking_players.key'), primary_key=True),
        sa.Column('group_id', sa.String(36), sa.ForeignKey('rivalry_groups.id'), nullable=False))
    op.create_index('ix_world_car_entries_group_id', 'world_car_entries', ['group_id'])
    op.create_table('world_car_weeks',
        sa.Column('snapshot_id', sa.Integer(), sa.ForeignKey('world_ranking_snapshots.id'), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('field_size', sa.Integer(), nullable=False),
        sa.Column('ranked_count', sa.Integer(), nullable=False),
        sa.Column('participation_bps', sa.Integer(), nullable=False),
        sa.Column('strength_bps', sa.Integer(), nullable=False),
        sa.Column('rating_histogram', sa.JSON(), nullable=False))
    op.create_table('world_car_awards',
        sa.Column('branch_id', sa.Integer(), primary_key=True),
        sa.Column('circuit_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('points', sa.SmallInteger(), nullable=False),
        sa.Column('weekly_place', sa.Integer(), nullable=False),
        sa.Column('tie_count', sa.Integer(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('rated_weeks', sa.Integer(), nullable=False))
    op.create_index('ix_world_car_award_history', 'world_car_awards', ['branch_id', 'player_key', 'circuit_id'])
    op.create_index('ix_world_car_award_members', 'world_car_awards', ['branch_id', 'circuit_id', 'player_key', 'vehicle_id'])
    op.create_table('world_car_standings',
        sa.Column('snapshot_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('total', sa.Integer(), nullable=False),
        sa.Column('world_rank', sa.Integer(), nullable=True),
        sa.Column('country', sa.String(length=2), nullable=False),
        sa.Column('country_rank', sa.Integer(), nullable=True),
        sa.Column('season_points', sa.Integer(), nullable=False),
        sa.Column('season_rank', sa.Integer(), nullable=True),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('rated_weeks', sa.Integer(), nullable=False),
        sa.Column('last_rated_week', sa.BigInteger(), nullable=False))
    op.create_index('ix_world_car_country', 'world_car_standings', ['snapshot_id', 'vehicle_id', 'country', 'country_rank', 'player_key'])
    op.create_index('ix_world_car_page', 'world_car_standings', ['snapshot_id', 'vehicle_id', 'world_rank', 'player_key'])
    op.create_index('ix_world_car_season', 'world_car_standings', ['snapshot_id', 'vehicle_id', 'season_rank', 'player_key'])
    op.create_table('world_car_work_inputs',
        sa.Column('snapshot_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('t0', sa.Integer(), nullable=False),
        sa.Column('t1', sa.Integer(), nullable=False),
        sa.Column('t2', sa.Integer(), nullable=False),
        sa.Column('t3', sa.Integer(), nullable=False),
        sa.Column('t4', sa.Integer(), nullable=False),
        sa.Column('country', sa.String(length=2), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('strength_rating', sa.Integer(), nullable=False),
        sa.Column('rated_weeks', sa.Integer(), nullable=False))
    op.create_table('world_car_work_places',
        sa.Column('snapshot_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('slot', sa.Integer(), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('place2', sa.Integer(), nullable=False))
    op.create_table('world_car_work_weekly',
        sa.Column('snapshot_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('sum2', sa.BigInteger(), nullable=False),
        sa.Column('k0', sa.Integer(), nullable=False),
        sa.Column('k1', sa.Integer(), nullable=False),
        sa.Column('k2', sa.Integer(), nullable=False),
        sa.Column('k3', sa.Integer(), nullable=False),
        sa.Column('k4', sa.Integer(), nullable=False))
    op.create_table('world_car_work_standings',
        sa.Column('snapshot_id', sa.Integer(), primary_key=True),
        sa.Column('vehicle_id', sa.String(length=80), primary_key=True),
        sa.Column('player_key', sa.BigInteger(), primary_key=True),
        sa.Column('country', sa.String(length=2), nullable=False),
        sa.Column('total', sa.Integer(), nullable=False),
        sa.Column('season_points', sa.Integer(), nullable=False),
        sa.Column('world_key', sa.LargeBinary(length=512), nullable=False),
        sa.Column('season_key', sa.LargeBinary(length=512), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('rated_weeks', sa.Integer(), nullable=False),
        sa.Column('last_rated_week', sa.BigInteger(), nullable=False))
    op.create_index('ix_world_car_standing_members', 'world_car_standings', ['snapshot_id', 'player_key', 'vehicle_id'])
    op.create_index('ix_world_car_input_members', 'world_car_work_inputs', ['snapshot_id', 'player_key', 'vehicle_id'])
    op.create_index('ix_world_car_place_members', 'world_car_work_places', ['snapshot_id', 'player_key', 'vehicle_id', 'slot'])
    op.create_index('ix_world_car_work_members', 'world_car_work_standings', ['snapshot_id', 'player_key', 'vehicle_id'])


def downgrade():
    connection = op.get_bind()
    for name in ('world_car_circuits', 'world_car_entries', 'world_car_weeks', 'world_car_awards', 'world_car_standings', 'world_car_work_inputs', 'world_car_work_places', 'world_car_work_weekly', 'world_car_work_standings'):
        if connection.scalar(sa.text("SELECT COUNT(*) FROM " + name)):
            raise RuntimeError("Cannot discard populated multi-car ranking history")
    op.drop_table('world_car_work_standings')
    op.drop_table('world_car_work_weekly')
    op.drop_table('world_car_work_places')
    op.drop_table('world_car_work_inputs')
    op.drop_table('world_car_standings')
    op.drop_table('world_car_awards')
    op.drop_table('world_car_weeks')
    op.drop_table('world_car_entries')
    op.drop_table('world_car_circuits')
    op.drop_column("world_ranking_corrections", "vehicle_id")
    op.drop_index("ix_world_ranking_published", table_name="world_ranking_snapshots")
