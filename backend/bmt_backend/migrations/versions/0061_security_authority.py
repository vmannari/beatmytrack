"""Grandfather server-stored cosmetic selections at the enforcement cutover.

No client-reported legacy list or future first write can grant an unlock.
"""

import sqlalchemy as sa
from alembic import op

revision = "0061_security_authority"
down_revision = "0060_game_configuration"
branch_labels = None
depends_on = None

CATALOG = {
    "patterns": [
        "plain",
        "apex_twin",
        "offset_gt",
        "endurance",
        "rally_blocks",
        "heritage_sweep",
        "chevron",
        "velocity",
        "split_grid",
        "contour",
        "forged_hex",
        "digital_camo",
        "tiger",
        "flame",
        "lightning",
        "orbit",
        "prism",
        "sunburst",
        "scallop",
        "herringbone",
        "circuit",
        "monza_fan",
        "nightfall",
        "crossfire",
        "coastal_wave",
        "topo_rally",
        "saber",
        "checker_fade",
        "pinstripe_club",
        "delta_wing",
        "fracture",
        "pulse",
        "aero_cut",
        "tribal_fang",
        "tribal_flow",
        "tribal_wing",
        "tribal_thorn",
        "tribal_crest",
        "tribal_surge",
        "ink_brush",
        "paint_splash",
        "art_deco",
        "op_art",
        "paisley_drift",
        "ribbon_weave",
        "scale_shift",
        "petal_drift",
        "halftone",
        "graffiti_slash",
    ],
    "parts": {
        "hood": [
            "stock",
            "louvres",
            "scoop",
            "dome",
            "extractor",
            "cowl",
            "twin_scoop",
            "reverse",
            "ribs",
            "vented",
        ],
        "aero": [
            "stock",
            "lip",
            "ducktail",
            "wing",
            "touring",
            "pedestal",
            "swan",
            "biwing",
            "rallywing",
            "endurance",
            "whale",
            "drag",
            "splitwing",
        ],
        "rims": ["stock", "five", "split", "turbine", "mesh", "dish", "rallydisc", "six", "ten", "tri"],
        "body": [
            "stock",
            "street",
            "rally",
            "club",
            "heritage",
            "touring",
            "wide",
            "endurance",
            "gravel",
            "urban",
        ],
    },
}


def upgrade():
    connection = op.get_bind()
    players = sa.table(
        "players",
        sa.column("id", sa.String()),
        sa.column("deleted_at", sa.Integer()),
        sa.column("vehicle_appearances", sa.JSON()),
    )
    unlocks = sa.table(
        "cosmetic_unlocks",
        sa.column("player_id", sa.String()),
        sa.column("item_id", sa.String()),
        sa.column("price", sa.Integer()),
        sa.column("created_at", sa.Integer()),
    )
    import time

    from sqlalchemy.dialects.postgresql import insert as postgres_insert
    from sqlalchemy.dialects.sqlite import insert as sqlite_insert

    stamp, cursor = int(time.time()), ""
    insert = sqlite_insert if connection.dialect.name == "sqlite" else postgres_insert
    while True:
        rows = connection.execute(
            sa.select(players.c.id, players.c.vehicle_appearances)
            .where(players.c.id > cursor, players.c.deleted_at.is_(None))
            .order_by(players.c.id)
            .limit(200)
        ).all()
        if not rows:
            break
        grants = []
        for player_id, cars in rows:
            items = set()
            if isinstance(cars, dict):
                for vehicle in ("compact", "pickup", "classic", "formula", "kart"):
                    value = cars.get(vehicle)
                    if not isinstance(value, dict) or value.get("vehicle_id") != vehicle:
                        continue
                    livery = value.get("livery")
                    pattern = livery.get("pattern") if isinstance(livery, dict) else None
                    if isinstance(pattern, str) and pattern != "plain" and pattern in CATALOG["patterns"]:
                        items.add("livery/" + pattern)
                    parts = value.get("customisation")
                    if vehicle == "compact" and isinstance(parts, dict):
                        for category, known in CATALOG["parts"].items():
                            option = parts.get(category)
                            if isinstance(option, str) and option != "stock" and option in known:
                                items.add("kit/compact/" + category + "/" + option)
            grants.extend(
                {"player_id": player_id, "item_id": item, "price": 0, "created_at": stamp}
                for item in sorted(items)
            )
        if grants:
            connection.execute(
                insert(unlocks)
                .values(grants)
                .on_conflict_do_nothing(index_elements=[unlocks.c.player_id, unlocks.c.item_id])
            )
        cursor = rows[-1][0]
    if connection.dialect.name == "postgresql":
        schema = connection.scalar(sa.text("SELECT current_schema()"))
        quoted = connection.dialect.identifier_preparer.quote(schema)
        # A worker may redact private support data only after the immutable
        # account tombstone exists. It cannot edit command/actor/action fields.
        connection.execute(
            sa.text(f"""CREATE OR REPLACE FUNCTION {quoted}.bmt_redact_removed_audit(pid text)
            RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
            BEGIN
              IF NOT EXISTS (SELECT 1 FROM {quoted}.players WHERE id=pid AND deleted_at IS NOT NULL) THEN
                RAISE EXCEPTION 'Account removal is required for audit redaction' USING ERRCODE='42501';
              END IF;
              UPDATE {quoted}.admin_audit SET reason='Removed account', before='{{}}'::json, after='{{}}'::json
                WHERE entity_id=pid;
            END $$""")
        )
        connection.execute(
            sa.text(f"REVOKE ALL ON FUNCTION {quoted}.bmt_redact_removed_audit(text) FROM PUBLIC")
        )
    # The scheduler never needs permission to create/replace owner policy.
    control = sa.table(
        "game_config_control",
        sa.column("id", sa.Integer()),
        sa.column("revision", sa.Integer()),
        sa.column("active_generation", sa.Integer()),
        sa.column("emergency", sa.JSON()),
    )
    connection.execute(
        insert(control)
        .values(id=1, revision=0, active_generation=0, emergency={})
        .on_conflict_do_nothing(index_elements=[control.c.id])
    )


def downgrade():
    # These permanent grants are indistinguishable from later support awards.
    # Preserve them and never reopen the old unauthorised appearance writers.
    pass
