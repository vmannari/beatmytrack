"""Durable administrative command audit."""

import sqlalchemy as sa
from alembic import op

revision = "0007_admin_audit"
down_revision = "0006_resumes"
branch_labels = depends_on = None


def upgrade():
    op.create_table(
        "admin_audit",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("command_id", sa.String(36), nullable=False, unique=True),
        sa.Column("actor", sa.String(80), nullable=False),
        sa.Column("action", sa.String(32), nullable=False),
        sa.Column("entity_id", sa.String(36), nullable=False),
        sa.Column("reason", sa.String(500), nullable=False),
        sa.Column("before", sa.JSON(), nullable=False),
        sa.Column("after", sa.JSON(), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
    )
    op.create_index("ix_admin_audit_entity_id", "admin_audit", ["entity_id"])


def downgrade():
    op.drop_table("admin_audit")
