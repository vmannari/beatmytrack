"""Discovery projection and durable queue operations state."""
import sqlalchemy as sa
from alembic import op

revision = "0008_review_reliability"
down_revision = "0007_admin_audit"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("track_versions", sa.Column("discovery", sa.JSON(), nullable=True))
    op.add_column("boards", sa.Column("stats_revision", sa.Integer(), nullable=False, server_default="0"))
    op.create_index("ix_version_content", "track_versions", ["content_hash"])
    op.create_index("ix_run_replay", "runs", ["replay_hash"])
    op.create_index("ix_run_finished", "runs", ["finished_at"])
    op.create_index("ix_published_track_revision", "track_versions", ["state", "track_id", "number"])
    op.create_table("queue_players",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("last_claim_at", sa.Integer(), nullable=False))
    op.create_index("ix_queue_players_last_claim_at", "queue_players", ["last_claim_at"])
    op.execute(sa.text("INSERT INTO queue_players (player_id, last_claim_at) SELECT id, 0 FROM players"))
    state = op.create_table("operation_state",
        sa.Column("id", sa.String(80), primary_key=True),
        sa.Column("updated_at", sa.Integer(), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False))
    op.bulk_insert(state, [{"id": "queue", "updated_at": 0, "details": {}}])
    if op.get_bind().dialect.name == "sqlite":
        for event, ref in (("INSERT", "NEW"), ("UPDATE", "NEW"), ("DELETE", "OLD")):
            op.execute(sa.text(f"CREATE TRIGGER pb_revision_{event.lower()} AFTER {event} ON personal_bests BEGIN UPDATE boards SET stats_revision = stats_revision + 1 WHERE id = {ref}.board_id; END"))
        op.execute(sa.text("CREATE TRIGGER player_board_revision AFTER UPDATE OF disabled ON players WHEN OLD.disabled != NEW.disabled BEGIN UPDATE boards SET stats_revision = stats_revision + 1 WHERE id IN (SELECT board_id FROM personal_bests WHERE player_id = NEW.id); END"))
    else:
        op.execute(sa.text("""CREATE FUNCTION bmt_pb_revision() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN UPDATE boards SET stats_revision = stats_revision + 1 WHERE id = COALESCE(NEW.board_id, OLD.board_id); RETURN NULL; END $$"""))
        op.execute(sa.text("CREATE TRIGGER pb_revision AFTER INSERT OR UPDATE OR DELETE ON personal_bests FOR EACH ROW EXECUTE FUNCTION bmt_pb_revision()"))
        op.execute(sa.text("""CREATE FUNCTION bmt_player_board_revision() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN IF OLD.disabled IS DISTINCT FROM NEW.disabled THEN UPDATE boards SET stats_revision = stats_revision + 1 WHERE id IN (SELECT board_id FROM personal_bests WHERE player_id = NEW.id); END IF; RETURN NULL; END $$"""))
        op.execute(sa.text("CREATE TRIGGER player_board_revision AFTER UPDATE OF disabled ON players FOR EACH ROW EXECUTE FUNCTION bmt_player_board_revision()"))


def downgrade():
    if op.get_bind().dialect.name == "sqlite":
        for event in ("insert", "update", "delete"): op.execute(sa.text(f"DROP TRIGGER pb_revision_{event}"))
        op.execute(sa.text("DROP TRIGGER player_board_revision"))
    else:
        op.execute(sa.text("DROP TRIGGER pb_revision ON personal_bests"))
        op.execute(sa.text("DROP TRIGGER player_board_revision ON players"))
        op.execute(sa.text("DROP FUNCTION bmt_pb_revision()"))
        op.execute(sa.text("DROP FUNCTION bmt_player_board_revision()"))
    op.drop_table("operation_state")
    op.drop_table("queue_players")
    op.drop_index("ix_published_track_revision", table_name="track_versions")
    op.drop_index("ix_run_finished", table_name="runs")
    op.drop_index("ix_run_replay", table_name="runs")
    op.drop_index("ix_version_content", table_name="track_versions")
    op.drop_column("track_versions", "discovery")
    op.drop_column("boards", "stats_revision")
