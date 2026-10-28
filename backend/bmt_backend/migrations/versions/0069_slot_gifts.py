"""Bind gifted publishing-slot purchases to their recipient."""
import sqlalchemy as sa
from alembic import op

revision = "0069_slot_gifts"
down_revision = "0068_track_of_day"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("purchases") as batch:
        batch.add_column(sa.Column("recipient_player_id", sa.String(36), nullable=True))
        batch.create_foreign_key("fk_purchase_recipient", "players", ["recipient_player_id"], ["id"])


def downgrade():
    with op.batch_alter_table("purchases") as batch:
        batch.drop_constraint("fk_purchase_recipient", type_="foreignkey")
        batch.drop_column("recipient_player_id")
