"""Bounded refresh recovery and abandoned unsubmitted resume attempts."""
import sqlalchemy as sa
from alembic import op

revision = "0015_exception_recovery"
down_revision = "0014_storage_lifecycle"
branch_labels = None
depends_on = None


def upgrade():
    for name, kind in (
        ("recovery_key_hash", sa.String(64)), ("recovery_nonce", sa.String(64)),
        ("replacement_id", sa.String(36)), ("rotated_at", sa.Integer()),
    ):
        op.add_column("session_tokens", sa.Column(name, kind, nullable=True))
    op.add_column("resume_races", sa.Column("abandoned", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("resume_receipts", sa.Column("settled", sa.Boolean(), nullable=False, server_default=sa.true()))
    op.add_column("resume_receipts", sa.Column("refunded", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_index("ix_resume_unsettled", "resume_receipts", ["settled", "refunded", "race_id"])


def downgrade():
    raise RuntimeError("Resume recovery state must not be discarded; restore a matching pre-upgrade backup")
