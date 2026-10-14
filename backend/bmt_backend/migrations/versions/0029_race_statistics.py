"""One bounded race package and indexed device/OS diagnostic summaries."""
import sqlalchemy as sa
from alembic import op

revision = "0029_race_statistics"
down_revision = "0028_publication_intents"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("race_statistics_receipts",
        sa.Column("player_id", sa.String(36), primary_key=True), sa.Column("race_id", sa.String(36), primary_key=True),
        sa.Column("event_id", sa.String(36), nullable=False), sa.Column("payload_hash", sa.String(64), nullable=False),
        sa.Column("received_at", sa.Integer(), nullable=False))
    op.create_index("ix_race_statistics_receipt_age", "race_statistics_receipts", ["received_at", "player_id", "race_id"])
    op.create_table("race_statistics_days", sa.Column("day", sa.Integer(), primary_key=True),
        sa.Column("dimension", sa.String(64), primary_key=True),
        sa.Column("track_version_id", sa.String(36), nullable=False), sa.Column("build_id", sa.String(80), nullable=False),
        sa.Column("platform", sa.String(12), nullable=False), sa.Column("device_class", sa.String(24), nullable=False),
        sa.Column("device_model", sa.String(80), nullable=False), sa.Column("os_version", sa.String(80), nullable=False),
        sa.Column("outcome", sa.String(16), nullable=False),
        *(sa.Column(name, sa.BigInteger(), nullable=False) for name in
            ("races", "elapsed_ms", "latest_received_at", "position_samples", "dropped_samples", "aggregate_dropped_samples")),
        *(sa.Column(name, sa.JSON(), nullable=False) for name in ("frame_buckets", "cells", "segments")))
    op.create_index("ix_race_statistics_version", "race_statistics_days", ["track_version_id", "day", "device_model", "os_version"])
    op.create_index("ix_race_statistics_device", "race_statistics_days", ["device_model", "os_version", "day"])


def downgrade():
    op.drop_table("race_statistics_days")
    op.drop_table("race_statistics_receipts")
