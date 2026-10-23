"""Earned coin balances, verified reward receipts and cosmetic ownership."""
import sqlalchemy as sa
from alembic import op

revision = "0037_earned_coins"
down_revision = "0036_community_safety"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("coin_wallets",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("balance", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.CheckConstraint("balance >= 0 AND balance <= 2147483647"))
    op.create_table("cosmetic_unlocks",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("item_id", sa.String(100), primary_key=True),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_table("coin_rewards",
        sa.Column("run_id", sa.String(36), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("rows", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_index("ix_coin_rewards_player_id", "coin_rewards", ["player_id"])
    op.create_table("coin_milestones",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("scope", sa.String(120), primary_key=True),
        sa.Column("value", sa.Integer(), nullable=False))


def downgrade():
    for table in ("coin_milestones", "coin_rewards", "cosmetic_unlocks", "coin_wallets"):
        op.drop_table(table)
