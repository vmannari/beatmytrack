"""Index exact retry-receipt references used by bounded race retention."""
import sqlalchemy as sa
from alembic import op

revision = "0075_receipt_reference_indexes"
down_revision = "0074_shader_profile_receipts"
branch_labels = None
depends_on = None

FIELDS = ("run_id", "ticket_id", "race_id", "receipt_id")


def upgrade():
    response = sa.column("response", sa.JSON)
    with op.get_context().autocommit_block():
        for field in FIELDS:
            name = f"ix_retry_{field}"
            expression = response[field].as_string()
            if op.get_bind().dialect.name == "postgresql":
                valid = op.get_bind().scalar(sa.text(
                    "SELECT indisvalid FROM pg_index WHERE indexrelid=to_regclass(:name)"), {"name": name})
                if valid is False:
                    op.drop_index(name, table_name="domain_idempotency", postgresql_concurrently=True)
            op.create_index(name, "domain_idempotency", [expression], if_not_exists=True,
                            sqlite_where=expression.is_not(None), postgresql_where=expression.is_not(None),
                            postgresql_concurrently=True)


def downgrade():
    with op.get_context().autocommit_block():
        for field in reversed(FIELDS):
            op.drop_index(f"ix_retry_{field}", table_name="domain_idempotency", postgresql_concurrently=True)
