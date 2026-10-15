"""Account erasure preserves public content and score identities."""
import sqlalchemy as sa
from alembic import op

revision = "0034_account_privacy"
down_revision = "0033_attack_resource_bounds"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("players", sa.Column("deleted_at", sa.Integer(), nullable=True))
    op.create_index("ix_players_deleted_at", "players", ["deleted_at"])
    op.add_column("players", sa.Column("analytics_enabled", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("track_versions", sa.Column("redacted_track_hash", sa.String(64), nullable=True))
    op.create_table("account_deletions",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("operation_hash", sa.String(64), nullable=False),
        sa.Column("credential_hash", sa.String(64), nullable=False),
        sa.Column("requested_at", sa.Integer(), nullable=False),
        sa.Column("journal_written_at", sa.Integer(), nullable=True),
        sa.Column("completed_at", sa.Integer(), nullable=True),
        sa.Column("stage", sa.Integer(), nullable=False),
        sa.Column("plan_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("cursor", sa.String(36), nullable=False),
        sa.Column("next_attempt_at", sa.Integer(), nullable=False))
    op.create_index("ix_account_deletion_due", "account_deletions", ["completed_at", "next_attempt_at"])
    op.create_index("ix_account_deletion_receipt", "account_deletions", ["credential_hash", "operation_hash"])
    op.create_index("ix_product_erasure_player", "product_events", ["player_id", "id"])
    op.create_table("deletion_blobs",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("digest", sa.String(64), primary_key=True))


def downgrade():
    if op.get_bind().execute(sa.text("SELECT COUNT(*) FROM account_deletions")).scalar():
        raise RuntimeError("Account erasure is irreversible; retain its authentication fence and ledger")
    op.drop_index("ix_product_erasure_player", table_name="product_events")
    op.drop_table("deletion_blobs")
    op.drop_table("account_deletions")
    op.drop_column("track_versions", "redacted_track_hash")
    op.drop_column("players", "analytics_enabled")
    op.drop_index("ix_players_deleted_at", table_name="players")
    op.drop_column("players", "deleted_at")
