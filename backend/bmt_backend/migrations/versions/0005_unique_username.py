"""Claim unique normalized names while retaining UUID ownership."""

import unicodedata
from collections import Counter

import sqlalchemy as sa
from alembic import op

revision = "0005_unique_username"
down_revision = "0004_developer_name"
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    rows = connection.execute(
        sa.text("SELECT id, display_name FROM players WHERE needs_username = false")
    ).all()
    claims = [(pid, " ".join(unicodedata.normalize("NFKC", name).split()).casefold()) for pid, name in rows]
    if any(count > 1 for count in Counter(key for _, key in claims).values()):
        raise RuntimeError(
            "Duplicate racing names exist; resolve conflicts before migrating. No accounts were renamed."
        )
    op.add_column("players", sa.Column("username_key", sa.String(160), nullable=True))
    for pid, key in claims:
        connection.execute(
            sa.text("UPDATE players SET username_key=:key WHERE id=:id"), {"key": key, "id": pid}
        )
    with op.batch_alter_table("players") as batch:
        batch.create_unique_constraint("uq_players_username_key", ["username_key"])
        batch.create_check_constraint("ck_player_claimed_name", "needs_username OR username_key IS NOT NULL")


def downgrade():
    with op.batch_alter_table("players") as batch:
        batch.drop_constraint("ck_player_claimed_name", type_="check")
        batch.drop_constraint("uq_players_username_key", type_="unique")
        batch.drop_column("username_key")
