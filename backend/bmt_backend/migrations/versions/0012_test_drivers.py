"""Explicit synthetic identity markers and isolated development championships."""

import sqlalchemy as sa
from alembic import op

revision = "0012_test_drivers"
down_revision = "0011_weekly_rivalry"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("players") as table:
        table.add_column(sa.Column("is_test_driver", sa.Boolean(), nullable=False, server_default=sa.false()))
    # 0011 creates its tables from runtime models on a fresh installation.
    # An existing 0011 installation still needs this column added explicitly.
    if "test_population" not in {c["name"] for c in sa.inspect(op.get_bind()).get_columns("rivalry_groups")}:
        with op.batch_alter_table("rivalry_groups") as table:
            table.add_column(
                sa.Column("test_population", sa.Boolean(), nullable=False, server_default=sa.false())
            )
    from bmt_backend.test_driver_models import TestDriverProfile

    TestDriverProfile.__table__.create(op.get_bind())


def downgrade():
    op.drop_table("test_driver_profiles")
    with op.batch_alter_table("rivalry_groups") as table:
        table.drop_column("test_population")
    with op.batch_alter_table("players") as table:
        table.drop_column("is_test_driver")
