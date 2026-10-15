"""Bounded cosmetic IDs for each player's rivalry cars."""
import sqlalchemy as sa
from alembic import op

revision = "0035_rivalry_car_appearance"
down_revision = "0034_account_privacy"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("players", sa.Column("vehicle_appearances", sa.JSON(), nullable=False, server_default="{}"))


def downgrade():
    op.drop_column("players", "vehicle_appearances")
