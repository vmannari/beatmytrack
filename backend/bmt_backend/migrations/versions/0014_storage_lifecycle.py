"""Online storage pins and compact closed-week evidence."""
import sqlalchemy as sa
from alembic import op

revision = "0014_storage_lifecycle"
down_revision = "0013_scalability"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("object_pins", sa.Column("digest", sa.String(64), primary_key=True),
                    sa.Column("expires_at", sa.Integer(), nullable=False))
    op.create_index("ix_object_pins_expires_at", "object_pins", ["expires_at"])
    state = sa.table("operation_state",sa.column("id",sa.String()),sa.column("updated_at",sa.Integer()),sa.column("details",sa.JSON()))
    op.bulk_insert(state,[{"id":"object-maintenance","updated_at":0,"details":{}}])
    if "archived" not in {c["name"] for c in sa.inspect(op.get_bind()).get_columns("rivalry_groups")}:
        op.add_column("rivalry_groups", sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_table("rivalry_archived_bests",
        sa.Column("group_id", sa.String(36), sa.ForeignKey("rivalry_groups.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("slot", sa.Integer(), primary_key=True),
        sa.Column("time_ticks", sa.Integer(), nullable=False),
        sa.Column("achieved_at", sa.Integer(), nullable=False))
    op.create_index("ix_rivalry_archive", "rivalry_groups", ["archived", "ends_at"])


def downgrade():
    raise RuntimeError("Archived evidence cannot be reconstructed; restore the pre-upgrade backup")
