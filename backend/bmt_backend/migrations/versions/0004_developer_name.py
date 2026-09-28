"""Set the fixed developer racing name without changing identity or ownership."""

import sqlalchemy as sa
from alembic import op

revision = "0004_developer_name"
down_revision = "0003_profile_name"
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        sa.text(
            "UPDATE players SET display_name = 'Beat My Track' WHERE id IN (SELECT player_id FROM identities WHERE provider = 'development' AND subject = 'developer')"
        )
    )


def downgrade():
    op.execute(
        sa.text(
            "UPDATE players SET display_name = 'developer' WHERE id IN (SELECT player_id FROM identities WHERE provider = 'development' AND subject = 'developer')"
        )
    )
