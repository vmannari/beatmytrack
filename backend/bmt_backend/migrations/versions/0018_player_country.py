"""Self-selected countries, preserving existing real-player profiles."""
import hashlib

import sqlalchemy as sa
from alembic import op

revision = "0018_player_country"
down_revision = "0017_product_controls"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("players", sa.Column("country_code", sa.String(2), nullable=False, server_default=""))
    players = sa.table("players", sa.column("id", sa.String(36)), sa.column("is_test_driver", sa.Boolean()),
                       sa.column("country_code", sa.String(2)))
    connection = op.get_bind()
    # Frozen values/algorithm: only explicitly artificial development identities.
    countries = ("FI", "SE", "GB", "DE", "FR", "IT", "ES", "US", "CA", "BR", "JP", "AU", "NL", "NO")
    for player_id in connection.scalars(sa.select(players.c.id).where(players.c.is_test_driver.is_(True))):
        code = countries[int(hashlib.sha256(player_id.encode()).hexdigest()[:8], 16) % len(countries)]
        connection.execute(players.update().where(players.c.id == player_id).values(country_code=code))


def downgrade():
    raise RuntimeError("Player countries require a matching backup restore")
