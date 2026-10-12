"""Owner-approved creator capacity and one-time ad-free purchases."""
import sqlalchemy as sa
from alembic import op

revision = "0016_commerce"
down_revision = "0015_exception_recovery"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("entitlements",
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), primary_key=True),
        sa.Column("slots", sa.Integer(), nullable=False),
        sa.Column("simulated_slots", sa.Integer(), nullable=False),
        sa.Column("ad_free_until", sa.BigInteger(), nullable=False),
        sa.Column("simulated_ad_free_until", sa.BigInteger(), nullable=False),
        sa.Column("forever", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("simulated_forever", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.CheckConstraint("slots >= 0 AND simulated_slots >= 0"))
    op.create_table("purchases",
        sa.Column("id", sa.String(96), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("provider", sa.String(24), nullable=False),
        sa.Column("product_id", sa.String(40), nullable=False),
        sa.Column("state", sa.String(16), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False),
        sa.Column("fulfilled_at", sa.Integer(), nullable=True))
    op.create_index("ix_purchase_player_created", "purchases", ["player_id", "created_at", "id"])
    op.create_index("ix_purchase_player_state", "purchases", ["player_id", "provider", "state", "created_at", "id"])
    op.create_table("publication_slots",
        sa.Column("version_id", sa.String(36), sa.ForeignKey("track_versions.id"), primary_key=True),
        sa.Column("player_id", sa.String(36), sa.ForeignKey("players.id"), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=False))
    op.create_index("ix_publication_slots_player_id", "publication_slots", ["player_id"])
    # Grandfather every existing immutable publication. Existing publishers have
    # spent their initial allowance; older additional publications incur no debt.
    op.execute(sa.text("""INSERT INTO entitlements
        (player_id, slots, simulated_slots, ad_free_until, simulated_ad_free_until, forever, simulated_forever)
        SELECT p.id, CASE WHEN EXISTS (SELECT 1 FROM tracks t JOIN track_versions v ON v.track_id=t.id
            WHERE t.owner_id=p.id AND v.state='published' AND t.official=false) THEN 0 ELSE 1 END,
            0, 0, 0, false, false FROM players p"""))
    op.execute(sa.text("""INSERT INTO publication_slots (version_id, player_id, source, created_at)
        SELECT v.id, t.owner_id, 'legacy', COALESCE(v.published_at, 0) FROM track_versions v JOIN tracks t ON t.id=v.track_id
        WHERE v.state='published'"""))


def downgrade():
    raise RuntimeError("Purchase and publication ledgers must be retained; restore a matching backup")
