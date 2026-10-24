"""Three pinned tracks with independent, authoritative three-start budgets."""
import sqlalchemy as sa
from alembic import op

revision = "0058_challenge_series"
down_revision = "0057_discovery_resource_guards"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("challenge_stages",
        sa.Column("challenge_id", sa.String(36), sa.ForeignKey("challenges.id"), primary_key=True),
        sa.Column("ordinal", sa.Integer(), primary_key=True),
        sa.Column("board_id", sa.String(64), sa.ForeignKey("boards.id"), nullable=False),
        sa.CheckConstraint("ordinal >= 0 AND ordinal < 3"))
    op.create_table("challenge_stage_members",
        sa.Column("challenge_id", sa.String(36), primary_key=True),
        sa.Column("ordinal", sa.Integer(), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("attempts_used", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("run_id", sa.String(36), sa.ForeignKey("runs.id")),
        sa.Column("time_ticks", sa.Integer()),
        sa.ForeignKeyConstraint(["challenge_id", "ordinal"], ["challenge_stages.challenge_id", "challenge_stages.ordinal"]),
        sa.ForeignKeyConstraint(["challenge_id", "player_id"], ["challenge_members.challenge_id", "challenge_members.player_id"]),
        sa.CheckConstraint("attempts_used >= 0 AND attempts_used <= 3"))
    op.create_index("ix_challenge_stage_member_run", "challenge_stage_members", ["run_id"])
    op.create_table("challenge_stage_tickets",
        sa.Column("ticket_id", sa.String(36), sa.ForeignKey("challenge_tickets.ticket_id"), primary_key=True),
        sa.Column("ordinal", sa.Integer(), nullable=False))


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM challenges WHERE mode = '3x3'")):
        raise RuntimeError("3x3 challenges require schema 0058; retain their stages before downgrade")
    op.drop_table("challenge_stage_tickets")
    op.drop_index("ix_challenge_stage_member_run", table_name="challenge_stage_members")
    op.drop_table("challenge_stage_members")
    op.drop_table("challenge_stages")
