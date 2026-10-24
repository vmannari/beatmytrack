"""Indexed analytical expiry without a historical cohort rewrite.

NULL deadlines are backfilled under actor fences by bounded worker batches.
PostgreSQL indexes are concurrent and retry-safe after partial DDL completion.
"""
import sqlalchemy as sa
from alembic import op

revision = "0056_bounded_retention"
down_revision = "0055_bounded_rank_reads"
branch_labels = None
depends_on = None


def upgrade():
    connection = op.get_bind()
    if "last_day" not in {column["name"] for column in sa.inspect(connection).get_columns("studio_analysis_people")}:
        op.add_column("studio_analysis_people", sa.Column("last_day", sa.Integer(), nullable=True))
    indexes = [("ix_analysis_person_expiry", "studio_analysis_people", ["last_day", "player_id"], {}),
               ("ix_worker_heartbeat_expiry", "operation_state", ["updated_at", "id"],
                {"postgresql_where": sa.text("id LIKE 'worker:%'")})]
    if connection.dialect.name == "postgresql":
        with op.get_context().autocommit_block():
            for name, table, columns, options in indexes:
                valid = connection.scalar(sa.text("SELECT i.indisvalid FROM pg_index i "
                    "JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_namespace n ON n.oid=c.relnamespace "
                    "WHERE n.nspname=current_schema() AND c.relname=:name"), {"name": name})
                if valid is True:
                    continue
                if valid is False:
                    op.drop_index(name, table_name=table, postgresql_concurrently=True)
                op.create_index(name, table, columns, postgresql_concurrently=True, **options)
    else:
        for name, table, columns, options in indexes:
            if name not in {index["name"] for index in sa.inspect(connection).get_indexes(table)}:
                sqlite_options = {"sqlite_where": options["postgresql_where"]} if options else {}
                op.create_index(name, table, columns, **sqlite_options)


def downgrade():
    op.drop_index("ix_worker_heartbeat_expiry", table_name="operation_state")
    op.drop_index("ix_analysis_person_expiry", table_name="studio_analysis_people")
    op.drop_column("studio_analysis_people", "last_day")
