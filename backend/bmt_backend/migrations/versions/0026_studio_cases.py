"""Case records and immutable command events; no business balance changes."""
import sqlalchemy as sa
from alembic import op

revision = "0026_studio_cases"
down_revision = "0025_product_telemetry"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("studio_cases", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id")),
        sa.Column("track_id", sa.String(36), sa.ForeignKey("tracks.id")),
        sa.Column("title", sa.String(160), nullable=False), sa.Column("status", sa.String(24), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False), sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.Integer(), nullable=False))
    op.create_index("ix_studio_case_updated", "studio_cases", ["updated_at", "id"])
    op.create_table("studio_case_events", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("case_id", sa.String(36), sa.ForeignKey("studio_cases.id"), nullable=False),
        sa.Column("actor", sa.String(24), nullable=False), sa.Column("kind", sa.String(24), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("detail", sa.JSON(), nullable=False), sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.UniqueConstraint("case_id", "revision", name="uq_studio_case_revision"))
    op.create_index("ix_studio_case_event", "studio_case_events", ["case_id", "created_at", "id"])
    op.create_table("studio_quarantines", sa.Column("track_id", sa.String(36), sa.ForeignKey("tracks.id"), primary_key=True),
        sa.Column("case_id", sa.String(36), sa.ForeignKey("studio_cases.id"), nullable=False),
        sa.Column("audit_id", sa.String(36), sa.ForeignKey("admin_audit.id"), nullable=False))


def downgrade():
    op.drop_table("studio_quarantines")
    op.drop_table("studio_case_events")
    op.drop_table("studio_cases")
