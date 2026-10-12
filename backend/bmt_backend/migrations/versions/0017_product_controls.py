"""Audited testing availability for the owner-approved product catalog."""
import sqlalchemy as sa
from alembic import op

revision = "0017_product_controls"
down_revision = "0016_commerce"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index("ix_purchase_history", "purchases", [sa.text("created_at DESC"), "id"])
    table = op.create_table("product_controls",
        sa.Column("id", sa.String(40), primary_key=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.Integer(), nullable=False),
        sa.CheckConstraint("revision >= 0"))
    op.bulk_insert(table, [{"id": sku, "enabled": True, "revision": 0, "updated_at": 0}
        for sku in ("creator_slot_1", "creator_slots_5", "creator_slots_10", "ad_free_month", "ad_free_forever")])


def downgrade():
    raise RuntimeError("Product availability history requires a matching backup restore")
