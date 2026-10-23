"""Index the latest provider receipt used by Studio coverage and finance."""
from alembic import op

revision = "0045_studio_report_reads"
down_revision = "0044_telemetry_counter_bigint"
branch_labels = None
depends_on = None


def upgrade():
    # Explicit one-shot migration; live large-ledger rollout needs an index-build
    # window or its reviewed concurrent equivalent before switching the readers.
    op.create_index("ix_studio_finance_received", "studio_finance_events", ["received_at"])


def downgrade():
    op.drop_index("ix_studio_finance_received", table_name="studio_finance_events")
