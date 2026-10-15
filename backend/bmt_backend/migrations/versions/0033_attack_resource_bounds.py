"""Durable publication reservations and shared discovery storage budgets."""
import sqlalchemy as sa
from alembic import op

revision = "0033_attack_resource_bounds"
down_revision = "0032_network_health"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("publication_intents", sa.Column("evidence_bytes", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("publication_intents", sa.Column("evidence_retired", sa.Boolean(), nullable=False, server_default=sa.false()))
    # Existing remote evidence was capped at 512 KiB + 2 MiB; reserve its full
    # allowance without network IO. Published content is governed separately.
    op.execute(sa.text("UPDATE publication_intents SET evidence_bytes=2621440 WHERE status!='published'"))
    op.create_index("ix_publication_evidence", "publication_intents", ["player_id", "evidence_retired", "status"])
    op.create_table("publication_uploads",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("operation_key", sa.String(128), primary_key=True),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("content_hash", sa.String(64), nullable=False),
        sa.Column("replay_hash", sa.String(64), nullable=False),
        sa.Column("creator_name", sa.String(40), nullable=False),
        sa.Column("evidence_bytes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("lease_until", sa.Integer(), nullable=False),
        sa.Column("lease_token", sa.String(36), nullable=False),
        sa.Column("evidence_retired", sa.Boolean(), nullable=False, server_default=sa.false()))
    for name in ("content_hash", "replay_hash", "created_at", "evidence_retired"):
        op.create_index("ix_publication_uploads_"+name, "publication_uploads", [name])
    op.add_column("discovery_snapshots", sa.Column("entry_count", sa.Integer(), nullable=False, server_default="0"))
    length = "json_array_length(version_ids)" if op.get_bind().dialect.name == "sqlite" else "json_array_length(version_ids::json)"
    op.execute(sa.text("UPDATE discovery_snapshots SET entry_count="+length))
    op.create_table("discovery_budget", sa.Column("id", sa.Integer(), primary_key=True),
                    sa.Column("entries", sa.Integer(), nullable=False),
                    sa.Column("snapshots", sa.Integer(), nullable=False))
    op.execute(sa.text("INSERT INTO discovery_budget SELECT 1,COALESCE(SUM(entry_count),0),COUNT(*) FROM discovery_snapshots"))


def downgrade():
    op.drop_table("discovery_budget")
    op.drop_column("discovery_snapshots", "entry_count")
    op.drop_table("publication_uploads")
    op.drop_index("ix_publication_evidence", table_name="publication_intents")
    op.drop_column("publication_intents", "evidence_retired")
    op.drop_column("publication_intents", "evidence_bytes")
