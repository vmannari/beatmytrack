"""Stable authoring identities, immutable revision retries and queued validation."""

import sqlalchemy as sa
from alembic import op

revision = "0009_track_lifecycle"
down_revision = "0008_review_reliability"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("tracks") as table:
        table.add_column(sa.Column("authoring_id", sa.String(80), nullable=True))
        table.create_unique_constraint("uq_track_authoring", ["owner_id", "authoring_id"])
    with op.batch_alter_table("track_versions") as table:
        table.add_column(sa.Column("revision_key", sa.String(64), nullable=True))
        table.create_unique_constraint("uq_track_revision", ["track_id", "revision_key"])
    op.create_table("track_validations",
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), primary_key=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("lease_until", sa.Integer(), nullable=False),
        sa.Column("lease_token", sa.String(36), nullable=True),
        sa.Column("failure_code", sa.String(64), nullable=True),
        sa.Column("detail", sa.String(500), nullable=True),
        sa.Column("created_at", sa.Integer(), nullable=False))


def downgrade():
    op.drop_table("track_validations")
    with op.batch_alter_table("track_versions") as table:
        table.drop_constraint("uq_track_revision", type_="unique")
        table.drop_column("revision_key")
    with op.batch_alter_table("tracks") as table:
        table.drop_constraint("uq_track_authoring", type_="unique")
        table.drop_column("authoring_id")
