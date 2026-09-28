"""Remember unfinished name selection across sign-ins without changing existing names."""

import sqlalchemy as sa
from alembic import op

revision = "0003_profile_name"
down_revision = "0002_browser_login"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "players", sa.Column("needs_username", sa.Boolean(), nullable=False, server_default=sa.false())
    )


def downgrade():
    op.drop_column("players", "needs_username")
