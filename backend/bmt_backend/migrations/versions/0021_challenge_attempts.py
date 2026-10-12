"""Optional per-driver challenge attempt limits; existing challenges stay unlimited."""
import sqlalchemy as sa
from alembic import op

revision = "0021_challenge_attempts"
down_revision = "0020_challenges"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("challenges", sa.Column("attempt_limit", sa.Integer(), nullable=True))
    op.add_column("challenge_members", sa.Column("attempts_used", sa.Integer(), nullable=False, server_default="0"))
    # Backfill prior starts and seeded creator finishes without changing unlimited contracts.
    op.execute("UPDATE challenge_members SET attempts_used = "
               "(SELECT COUNT(*) FROM challenge_tickets JOIN run_tickets ON run_tickets.id = challenge_tickets.ticket_id "
               "WHERE challenge_tickets.challenge_id = challenge_members.challenge_id "
               "AND run_tickets.player_id = challenge_members.player_id) + "
               "CASE WHEN EXISTS (SELECT 1 FROM challenges WHERE challenges.id = challenge_members.challenge_id "
               "AND challenges.creator_id = challenge_members.player_id AND challenges.target_run_id IS NOT NULL) "
               "THEN 1 ELSE 0 END")


def downgrade():
    op.drop_column("challenge_members", "attempts_used")
    op.drop_column("challenges", "attempt_limit")
