"""Widen the lifetime processed-event count without resetting telemetry state."""
import sqlalchemy as sa
from alembic import op

revision = "0044_telemetry_counter_bigint"
down_revision = "0043_rivalry_planning"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("product_state") as table:
        table.alter_column("processed_events", existing_type=sa.Integer(),
                           type_=sa.BigInteger(), existing_nullable=False)


def downgrade():
    overflow = op.get_bind().scalar(sa.text(
        "SELECT 1 FROM product_state WHERE processed_events < -2147483648 "
        "OR processed_events > 2147483647 LIMIT 1"))
    if overflow:
        raise RuntimeError("Cannot narrow processed_events: its value exceeds the INTEGER range")
    with op.batch_alter_table("product_state") as table:
        table.alter_column("processed_events", existing_type=sa.BigInteger(),
                           type_=sa.Integer(), existing_nullable=False)
