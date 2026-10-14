"""Durable explicit publication; no remote authoring drafts."""
import sqlalchemy as sa
from alembic import op

revision = "0028_publication_intents"
down_revision = "0027_client_quality"
branch_labels = None
depends_on = None


def upgrade():
    # Retire only the superseded authoring queue. Preserve the entire bounded
    # original job metadata while releasing its shared admission counters.
    op.add_column("track_validations", sa.Column("legacy_workflow_snapshot", sa.JSON()))
    json_object = "json_object" if op.get_bind().dialect.name == "sqlite" else "json_build_object"
    op.execute(sa.text(f"""UPDATE track_validations SET legacy_workflow_snapshot={json_object}(
        'status',status,'failure_code',failure_code,'detail',detail,'attempts',attempts,
        'lease_until',lease_until,'lease_token',lease_token)
        WHERE status IN ('queued','validating')"""))
    op.execute(sa.text("""UPDATE track_validations SET status='legacy_saved',failure_code='local_drafts_only',
        detail='Remote authoring retired; historical content and job metadata retained. Publish an exact saved local creator lap to continue.',
        lease_until=0,lease_token=NULL WHERE status IN ('queued','validating')"""))
    op.create_table("publication_intents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("operation_key", sa.String(128), nullable=False),
        sa.Column("request_hash", sa.String(64), nullable=False),
        sa.Column("authoring_id", sa.String(80), nullable=False),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("content_hash", sa.String(64), nullable=False),
        sa.Column("replay_hash", sa.String(64), nullable=False),
        sa.Column("vehicle_id", sa.String(80), nullable=False),
        sa.Column("contract", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("lease_until", sa.Integer(), nullable=False),
        sa.Column("lease_token", sa.String(36)),
        sa.Column("failure_code", sa.String(64)),
        sa.Column("detail", sa.String(500)),
        sa.Column("receipt", sa.JSON()),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("finished_at", sa.Integer()),
        sa.UniqueConstraint("player_id", "operation_key"))
    op.create_index("ix_publication_intents_player_id", "publication_intents", ["player_id"])
    op.create_index("ix_publication_intents_content_hash", "publication_intents", ["content_hash"])
    op.create_index("ix_publication_intents_replay_hash", "publication_intents", ["replay_hash"])
    op.create_index("ix_publication_claim", "publication_intents", ["status", "lease_until", "created_at", "id"])
    if op.get_bind().dialect.name == "sqlite":
        for event in ("INSERT", "UPDATE", "DELETE"):
            body = ""
            for ref, delta in (("OLD", -1), ("NEW", 1)):
                if (event == "INSERT" and ref == "OLD") or (event == "DELETE" and ref == "NEW"):
                    continue
                condition = f"{ref}.status IN ('queued','verifying')"
                if event == "UPDATE":
                    other = "NEW" if ref == "OLD" else "OLD"
                    condition += f" AND {other}.status NOT IN ('queued','verifying')"
                body += f"""INSERT INTO queue_players(player_id,last_claim_at,pending)
                    SELECT {ref}.player_id,0,{delta} WHERE {condition}
                    ON CONFLICT(player_id) DO UPDATE SET pending=pending+{delta};
                    UPDATE queue_capacity SET pending=pending+{delta} WHERE {condition};"""
            op.execute(sa.text(f"CREATE TRIGGER queue_publications_{event.lower()} AFTER {event} ON publication_intents BEGIN {body} END"))
    else:
        op.execute(sa.text("""CREATE FUNCTION bmt_publication_queue_delta() RETURNS trigger LANGUAGE plpgsql AS $$
            DECLARE delta integer:=0; pid text;
            BEGIN
            IF TG_OP <> 'INSERT' AND OLD.status IN ('queued','verifying') THEN delta:=delta-1; END IF;
            IF TG_OP <> 'DELETE' AND NEW.status IN ('queued','verifying') THEN delta:=delta+1; END IF;
            IF delta=0 THEN RETURN NULL; END IF;
            pid:=COALESCE(NEW.player_id,OLD.player_id);
            UPDATE queue_capacity SET pending=pending+delta WHERE id=1;
            INSERT INTO queue_players VALUES(pid,0,delta) ON CONFLICT(player_id)
            DO UPDATE SET pending=queue_players.pending+delta;
            RETURN NULL; END $$"""))
        op.execute(sa.text("CREATE TRIGGER queue_delta AFTER INSERT OR UPDATE OR DELETE ON publication_intents FOR EACH ROW EXECUTE FUNCTION bmt_publication_queue_delta()"))


def downgrade():
    op.drop_table("publication_intents")
    op.drop_column("track_validations", "legacy_workflow_snapshot")
    if op.get_bind().dialect.name == "postgresql":
        op.execute(sa.text("DROP FUNCTION bmt_publication_queue_delta()"))
