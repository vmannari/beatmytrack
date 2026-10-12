"""Durable invitations and best-only challenge standings."""
import sqlalchemy as sa
from alembic import op

revision = "0020_challenges"
down_revision = "0019_discovery_snapshots"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("challenges",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("code", sa.String(16), nullable=False, unique=True),
        sa.Column("creator_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), nullable=False),
        sa.Column("mode", sa.String(8), nullable=False),
        sa.Column("target_run_id", sa.String(36), sa.ForeignKey("runs.id")),
        sa.Column("target_ticks", sa.Integer()),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("ends_at", sa.Integer(), nullable=False),
        sa.Column("member_count", sa.Integer(), nullable=False),
        sa.Column("cancelled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.CheckConstraint("member_count >= 1 AND member_count <= 20"))
    op.create_index("ix_challenge_creator_recent", "challenges", ["creator_id", "created_at"])
    op.create_table("challenge_members",
        sa.Column("challenge_id", sa.String(36), sa.ForeignKey("challenges.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("joined_at", sa.Integer(), nullable=False),
        sa.Column("run_id", sa.String(36), sa.ForeignKey("runs.id")),
        sa.Column("time_ticks", sa.Integer()))
    op.create_index("ix_challenge_member_recent", "challenge_members", ["player_id", "joined_at"])
    op.create_table("challenge_tickets",
        sa.Column("ticket_id", sa.String(36), sa.ForeignKey("run_tickets.id"), primary_key=True),
        sa.Column("challenge_id", sa.String(36), sa.ForeignKey("challenges.id"), nullable=False),
        sa.Column("outcome", sa.JSON()))
    op.create_index("ix_challenge_tickets_challenge_id", "challenge_tickets", ["challenge_id"])


def downgrade():
    op.drop_table("challenge_tickets")
    op.drop_table("challenge_members")
    op.drop_table("challenges")
