"""Bounded open-group matching and transactional creator achievement effects.

Drain old writers before cutover. No history replay: existing creator totals and
CoinReward receipts remain authoritative. Large live rivalry indexes require a
reviewed concurrent-index rollout before the equivalent migration is recorded.
"""
import sqlalchemy as sa
from alembic import op

revision = "0054_priority_scaling"
down_revision = "0053_discovery_short_search"
branch_labels = None
depends_on = None


def upgrade():
    # The historical Rivalry migration creates tables from current metadata on
    # fresh installs; an existing deployment still needs this additive index.
    indexes = {item["name"] for item in sa.inspect(op.get_bind()).get_indexes("rivalry_groups")}
    if "ix_rivalry_open_matching" not in indexes:
        op.create_index("ix_rivalry_open_matching", "rivalry_groups",
                        ["week_start", "contract_key", "skill_band", "created_at", "id"],
                        postgresql_where=sa.text("member_count < 20"), sqlite_where=sa.text("member_count < 20"))
    partitions = op.create_table("creator_achievement_partitions", sa.Column("id", sa.Integer(), primary_key=True))
    op.bulk_insert(partitions, [{"id": index} for index in range(16)])
    op.create_table("creator_achievement_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("partition", sa.Integer(), nullable=False),
        sa.Column("creator_id", sa.String(36), nullable=False),
        sa.Column("stamp", sa.Integer(), nullable=False),
        sa.Column("reach", sa.BigInteger(), nullable=False))
    op.create_index("ix_creator_achievement_pending", "creator_achievement_events", ["partition", "stamp", "id"])
    op.create_index("ix_creator_achievement_owner", "creator_achievement_events", ["creator_id", "stamp", "id"])


def downgrade():
    # Dropping committed but unapplied effects silently loses awards. Operators
    # must first stop new writers and drain the outbox with the matching worker.
    if op.get_bind().scalar(sa.text("SELECT EXISTS (SELECT 1 FROM creator_achievement_events)")):
        raise RuntimeError("Drain creator achievement events before downgrading 0054")
    op.drop_table("creator_achievement_events")
    op.drop_table("creator_achievement_partitions")
    op.drop_index("ix_rivalry_open_matching", table_name="rivalry_groups")
