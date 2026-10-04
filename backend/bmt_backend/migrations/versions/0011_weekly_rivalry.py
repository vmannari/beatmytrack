"""Weekly skill groups, verified weekly bests and trusted official provenance."""
import sqlalchemy as sa
from alembic import op

revision = "0011_weekly_rivalry"
down_revision = "0010_archive_drafts"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("tracks") as table:
        table.add_column(sa.Column("official", sa.Boolean(), nullable=False, server_default=sa.false()))
    # Historical official author is the reserved, operator-authenticated account,
    # not any Google account that happens to choose a similar display name.
    op.execute(sa.text("UPDATE tracks SET official = true WHERE owner_id IN "
                       "(SELECT player_id FROM identities WHERE provider = 'development' AND subject = 'developer')"))
    with op.batch_alter_table("runs") as table:
        table.add_column(sa.Column("ghost_hash", sa.String(64), nullable=True))
    from bmt_backend.rivalry_models import RivalryBest, RivalryGroup, RivalryMember, RivalryTicket
    for model in (RivalryGroup, RivalryMember, RivalryBest, RivalryTicket):
        model.__table__.create(op.get_bind())


def downgrade():
    for name in ("rivalry_tickets", "rivalry_bests", "rivalry_members", "rivalry_groups"):
        op.drop_table(name)
    with op.batch_alter_table("runs") as table:
        table.drop_column("ghost_hash")
    with op.batch_alter_table("tracks") as table:
        table.drop_column("official")
