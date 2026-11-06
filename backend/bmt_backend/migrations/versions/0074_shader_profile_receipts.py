"""Index bounded shader diagnostics without rewriting existing receipts."""
import sqlalchemy as sa
from alembic import op

revision = "0074_shader_profile_receipts"
down_revision = "0073_publication_publisher_check"
branch_labels = None
depends_on = None


def upgrade():
    with op.get_context().autocommit_block():
        op.create_index("ix_product_shader_profiles", "product_events", ["occurred_at", "id"],
                        sqlite_where=sa.text("source='client' AND name='shader_profile'"),
                        postgresql_where=sa.text("source='client' AND name='shader_profile'"),
                        postgresql_concurrently=True)


def downgrade():
    with op.get_context().autocommit_block():
        op.drop_index("ix_product_shader_profiles", table_name="product_events", postgresql_concurrently=True)
