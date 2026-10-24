"""Index exact short substrings and compact the bounded pair-expiry work index.

Expression GIN indexes contain distinct one/two-character grams, not positions.
The query retains ILIKE to reject false positives. Large live tables require the
operator's reviewed concurrent-index rollout; ordinary migration is transactional.
"""
from alembic import op

revision = "0053_discovery_short_search"
down_revision = "0052_histogram_demand"
branch_labels = None
depends_on = None


def upgrade():
    # Expiry owns its partition and needs no tie order. Removing both UUID keys
    # also permits PostgreSQL B-tree deduplication of equal expiry timestamps.
    op.drop_index("ix_discovery_driver_expire", table_name="discovery_drivers")
    op.create_index("ix_discovery_driver_expire", "discovery_drivers", ["partition", "expires_at"])
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("""CREATE FUNCTION discovery_short_grams(text) RETURNS text[]
        LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
        SELECT ARRAY(SELECT DISTINCT substr(lower($1), position, width)
            FROM generate_series(1, char_length(lower($1))) AS position
            CROSS JOIN generate_series(1, 2) AS width
            WHERE position + width - 1 <= char_length(lower($1)) ORDER BY 1)
        $$""")
    for field in ("name", "creator"):
        op.execute(f"CREATE INDEX ix_discovery_entry_{field}_short ON discovery_entries "
                   f"USING gin (discovery_short_grams({field}))")


def downgrade():
    op.drop_index("ix_discovery_driver_expire", table_name="discovery_drivers")
    op.create_index("ix_discovery_driver_expire", "discovery_drivers",
                    ["partition", "expires_at", "track_id", "player_id"])
    if op.get_bind().dialect.name != "postgresql":
        return
    for field in ("name", "creator"):
        op.drop_index(f"ix_discovery_entry_{field}_short", table_name="discovery_entries")
    op.execute("DROP FUNCTION discovery_short_grams(text)")
