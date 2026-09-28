"""Short-lived browser handoff; credentials are never stored in plaintext."""

import sqlalchemy as sa
from alembic import op

revision = "0002_browser_login"
down_revision = "0001_backend"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "browser_logins",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("browser_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("poll_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("nonce", sa.String(64), nullable=False),
        sa.Column("display_name", sa.String(40), nullable=False),
        sa.Column("subject", sa.String(255), nullable=True),
        sa.Column("expires_at", sa.Integer(), nullable=False),
        sa.Column("consumed", sa.Boolean(), nullable=False),
    )
    op.create_index("ix_browser_logins_expires_at", "browser_logins", ["expires_at"])


def downgrade():
    op.drop_table("browser_logins")
