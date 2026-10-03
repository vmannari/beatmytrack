"""Retain an owner-scoped archive intent without removing shared versions."""
import sqlalchemy as sa
from alembic import op

revision = "0010_archive_drafts"
down_revision = "0009_track_lifecycle"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("tracks") as table:
        table.add_column(sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    with op.batch_alter_table("tracks") as table:
        table.drop_column("archived")
