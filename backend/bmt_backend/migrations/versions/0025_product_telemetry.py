"""Add bounded product observations and prepared analytics; no historical guesses."""
import sqlalchemy as sa
from alembic import op

revision = "0025_product_telemetry"
down_revision = "0024_lap_personal_bests"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("product_events", sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("client_id", sa.String(36)), sa.Column("entity_id", sa.String(36)),
        sa.Column("player_id", sa.String(36), nullable=False),
        sa.Column("is_test_driver", sa.Boolean()), sa.Column("source", sa.String(8), nullable=False),
        sa.Column("name", sa.String(32), nullable=False), sa.Column("occurred_at", sa.Integer(), nullable=False),
        sa.Column("received_at", sa.Integer(), nullable=False), sa.Column("session_id", sa.String(36)),
        sa.Column("install_id", sa.String(36)),
        sa.Column("seq", sa.Integer()), sa.Column("monotonic_ms", sa.Integer()),
        sa.Column("build_id", sa.String(80), nullable=False), sa.Column("platform", sa.String(12), nullable=False),
        sa.Column("clock_quality", sa.String(16), nullable=False),
        sa.Column("payload_hash", sa.String(64), nullable=False), sa.Column("properties", sa.JSON(), nullable=False),
        sa.Column("processed_at", sa.Integer()), sa.Column("compacted", sa.Boolean(), nullable=False))
    op.create_index("ix_product_pending", "product_events", ["processed_at", "received_at", "id"])
    op.create_index("ix_product_pending_order", "product_events", ["received_at", "id"],
        sqlite_where=sa.text("processed_at IS NULL"), postgresql_where=sa.text("processed_at IS NULL"))
    op.create_index("ix_product_client_cleanup", "product_events", ["received_at", "id"],
        sqlite_where=sa.text("source='client' AND processed_at IS NOT NULL"),
        postgresql_where=sa.text("source='client' AND processed_at IS NOT NULL"))
    op.create_index("ix_product_server_compact", "product_events", ["received_at", "id"],
        sqlite_where=sa.text("source='server' AND processed_at IS NOT NULL AND compacted=false"),
        postgresql_where=sa.text("source='server' AND processed_at IS NOT NULL AND compacted=false"))
    op.create_table("product_player_days", sa.Column("day", sa.Integer(), primary_key=True),
        sa.Column("player_id", sa.String(36), primary_key=True))
    op.create_index("ix_product_activity_player", "product_player_days", ["player_id", "day"])
    op.create_table("product_metrics", sa.Column("day", sa.Integer(), primary_key=True),
        sa.Column("key", sa.String(48), primary_key=True), sa.Column("dimension", sa.String(32), primary_key=True),
        sa.Column("value", sa.Integer(), nullable=False))
    op.create_table("product_profiles", sa.Column("player_id", sa.String(36), primary_key=True),
        sa.Column("first_activity_at", sa.Integer()), sa.Column("milestones", sa.JSON(), nullable=False),
        sa.Column("projection", sa.JSON(), nullable=False), sa.Column("truncated", sa.Boolean(), nullable=False),
        sa.Column("quality", sa.JSON(), nullable=False), sa.Column("truncations", sa.JSON(), nullable=False))
    op.create_table("product_publications", sa.Column("version_id", sa.String(36), primary_key=True),
        sa.Column("owner_id", sa.String(36), nullable=False), sa.Column("published_at", sa.Integer(), nullable=False),
        sa.Column("observed", sa.Boolean(), nullable=False), sa.Column("first_external_at", sa.Integer()))
    op.create_index("ix_product_publication_age", "product_publications", ["published_at"])
    op.create_table("product_state", sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("collection_started_at", sa.Integer()), sa.Column("processed_through", sa.Integer()),
        sa.Column("latest_receipt_at", sa.Integer()), sa.Column("observed_at", sa.Integer()),
        sa.Column("pending_events", sa.Integer(), nullable=False), sa.Column("processed_events", sa.Integer(), nullable=False),
        sa.Column("truncated_profiles", sa.Integer(), nullable=False),
        sa.Column("pending_clients", sa.Integer(), nullable=False), sa.Column("pending_capped", sa.Boolean(), nullable=False),
        sa.Column("retained_from_day", sa.Integer()), sa.Column("fact_days", sa.Integer(), nullable=False))
    op.execute(sa.text("INSERT INTO product_state(id,pending_events,processed_events,truncated_profiles,pending_clients,pending_capped,fact_days) VALUES(1,0,0,0,0,false,180)"))


def downgrade():
    for table in ("product_state", "product_publications", "product_profiles", "product_metrics", "product_player_days", "product_events"):
        op.drop_table(table)
