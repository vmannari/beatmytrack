"""Allow custom challenges with two to five independently budgeted tracks."""
from contextlib import contextmanager

import sqlalchemy as sa
from alembic import op

revision = "0063_custom_challenge_tracks"
down_revision = "0062_retire_discovery_cache"
branch_labels = None
depends_on = None


@contextmanager
def sqlite_rebuild():
    # Both stage tables have incoming FKs. Alembic's SQLite table copy needs
    # FK checks suspended outside a transaction, then checked before re-enabling.
    if op.get_bind().dialect.name != "sqlite":
        yield
        return
    with op.get_context().autocommit_block():
        op.execute("PRAGMA foreign_keys=OFF")
        try:
            yield
            if op.get_bind().exec_driver_sql("PRAGMA foreign_key_check").first():
                raise RuntimeError("Challenge migration broke a foreign key")
        finally:
            op.execute("PRAGMA foreign_keys=ON")


def replace_check(table, marker, name, expression):
    checks = sa.inspect(op.get_bind()).get_check_constraints(table)
    old = next(check for check in checks if marker in check["sqltext"])
    with op.batch_alter_table(table, naming_convention={"ck": "ck_%(table_name)s_legacy"}) as batch:
        batch.drop_constraint(old["name"] or f"ck_{table}_legacy", type_="check")
        batch.create_check_constraint(name, expression)


def upgrade():
    op.add_column("challenges", sa.Column("track_count", sa.Integer(), nullable=False, server_default="1"))
    op.execute("UPDATE challenges SET track_count=3 WHERE mode='3x3'")
    with sqlite_rebuild():
        replace_check("challenge_stages", "ordinal", "ck_challenge_stage_ordinal", "ordinal >= 0 AND ordinal < 5")
        replace_check("challenge_stage_members", "attempts_used", "ck_challenge_stage_attempts", "attempts_used >= 0")


def downgrade():
    if op.get_bind().scalar(sa.text("SELECT count(*) FROM challenges WHERE track_count>1 AND mode!='3x3'")):
        raise RuntimeError("Custom multi-track challenges require schema 0063; retain their stages before downgrade")
    with sqlite_rebuild():
        replace_check("challenge_stage_members", "attempts_used", "ck_challenge_stage_attempts",
                      "attempts_used >= 0 AND attempts_used <= 3")
        replace_check("challenge_stages", "ordinal", "ck_challenge_stage_ordinal", "ordinal >= 0 AND ordinal < 3")
        with op.batch_alter_table("challenges", naming_convention={"ck": "ck_%(table_name)s_members"}) as batch:
            batch.drop_column("track_count")
