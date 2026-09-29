"""Add server-owned resume wallets, grants and race receipts."""

import sqlalchemy as sa
from alembic import op

revision = "0006_resumes"
down_revision = "0005_unique_username"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "resume_wallets",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("balance", sa.Integer(), nullable=False),
        sa.Column("free_day", sa.Integer(), nullable=False),
        sa.CheckConstraint("balance >= 0"),
    )
    op.create_table(
        "resume_races",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("ticket_id", sa.String(36), sa.ForeignKey("run_tickets.id"), unique=True),
        sa.Column("used", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.Integer(), nullable=False),
        sa.CheckConstraint("used >= 0 AND used <= 3"),
    )
    op.create_index("ix_resume_races_player_id", "resume_races", ["player_id"])
    op.create_table(
        "resume_receipts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("race_id", sa.String(36), sa.ForeignKey("resume_races.id"), nullable=False),
        sa.Column("ordinal", sa.Integer(), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("input_offset", sa.Integer(), nullable=False),
        sa.Column("from_tick", sa.Integer(), nullable=False),
        sa.Column("to_tick", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.UniqueConstraint("race_id", "ordinal"),
    )
    op.create_index("ix_resume_receipts_race_id", "resume_receipts", ["race_id"])
    op.create_table(
        "resume_grants",
        sa.Column("id", sa.String(160), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
    )
    op.create_index("ix_resume_grants_player_id", "resume_grants", ["player_id"])


def downgrade():
    for table in ("resume_grants", "resume_receipts", "resume_races", "resume_wallets"):
        op.drop_table(table)
