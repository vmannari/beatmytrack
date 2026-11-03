"""Expose official publisher classification without worker authentication reads."""
import sqlalchemy as sa
from alembic import op

revision = "0073_publication_publisher_check"
down_revision = "0072_fixed_daily_lap_limits"
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    if connection.dialect.name != "postgresql":
        return
    schema = connection.scalar(sa.text("SELECT current_schema()"))
    quoted = connection.dialect.identifier_preparer.quote_identifier(schema)
    connection.execute(sa.text(f"""CREATE FUNCTION {quoted}.bmt_is_official_publisher(pid text)
        RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog
        AS $$ SELECT EXISTS (SELECT 1 FROM {quoted}.identities
            WHERE player_id = pid AND provider = 'development' AND subject = 'developer') $$"""))
    connection.execute(sa.text(f"REVOKE ALL ON FUNCTION {quoted}.bmt_is_official_publisher(text) FROM PUBLIC"))


def downgrade():
    connection = op.get_bind()
    if connection.dialect.name != "postgresql":
        return
    schema = connection.scalar(sa.text("SELECT current_schema()"))
    quoted = connection.dialect.identifier_preparer.quote_identifier(schema)
    connection.execute(sa.text(f"DROP FUNCTION {quoted}.bmt_is_official_publisher(text)"))
