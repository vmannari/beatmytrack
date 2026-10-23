"""Explicitly public challenge discovery; existing invitations remain private."""
import sqlalchemy as sa
from alembic import op

revision = "0041_challenge_discovery"
down_revision = "0040_studio_platform"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("challenges", sa.Column("visibility", sa.String(8), nullable=False, server_default="private"))
    op.create_index("ix_challenge_discover", "challenges", ["visibility", "cancelled", "ends_at", "id"])


def downgrade():
    op.drop_index("ix_challenge_discover", table_name="challenges")
    op.drop_column("challenges", "visibility")
