"""Versioned public-sharing acceptance, private blocks and report targets."""
import sqlalchemy as sa
from alembic import op

revision = "0036_community_safety"
down_revision = "0035_rivalry_car_appearance"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("community_acceptances",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("version", sa.String(64), primary_key=True),
        sa.Column("accepted_at", sa.Integer(), nullable=False))
    op.create_table("player_blocks",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("blocked_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_index("ix_player_blocks_blocked_id", "player_blocks", ["blocked_id"])
    # Additive nullable targets preserve existing support cases and reporter ownership.
    with op.batch_alter_table("studio_cases") as batch:
        batch.add_column(sa.Column("reported_player_id", sa.String(36), nullable=True))


def downgrade():
    with op.batch_alter_table("studio_cases") as batch:
        batch.drop_column("reported_player_id")
    op.drop_table("player_blocks")
    op.drop_table("community_acceptances")
