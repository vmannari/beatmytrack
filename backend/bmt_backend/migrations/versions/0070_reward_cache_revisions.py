"""Complete board revision invalidation for reward eligibility memoization."""
from alembic import op

revision = "0070_reward_cache_revisions"
down_revision = "0069_slot_gifts"
branch_labels = None
depends_on = None


def upgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    changed = " OR ".join(f"OLD.{column} IS {'NOT' if sqlite else 'DISTINCT FROM'} NEW.{column}"
                          for column in ("disabled", "is_test_driver", "deleted_at"))
    boards = """SELECT board_id FROM personal_bests WHERE player_id=NEW.id
        UNION SELECT board_id FROM lap_personal_bests WHERE player_id=NEW.id"""
    body = f"""UPDATE boards SET stats_revision=stats_revision+1,lap_revision=lap_revision+1
        WHERE id IN ({boards});"""
    if sqlite:
        op.execute(f"""CREATE TRIGGER reward_player_revision AFTER UPDATE OF disabled,is_test_driver,deleted_at
            ON players WHEN {changed} BEGIN {body} END""")
    else:
        op.execute(f"""CREATE FUNCTION bmt_reward_player_revision() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN IF {changed} THEN {body} END IF; RETURN NULL; END $$""")
        op.execute("""CREATE TRIGGER reward_player_revision AFTER UPDATE OF disabled,is_test_driver,deleted_at
            ON players FOR EACH ROW EXECUTE FUNCTION bmt_reward_player_revision()""")
    for table, column in (("personal_bests", "stats_revision"), ("lap_personal_bests", "lap_revision")):
        name = "reward_move_" + table
        condition = " OR ".join(f"OLD.{field} IS {'NOT' if sqlite else 'DISTINCT FROM'} NEW.{field}"
                                for field in ("board_id", "player_id"))
        body = f"UPDATE boards SET {column}={column}+1 WHERE id IN (OLD.board_id,NEW.board_id);"
        if sqlite:
            op.execute(f"""CREATE TRIGGER {name} AFTER UPDATE OF board_id,player_id ON {table}
                WHEN {condition} BEGIN {body} END""")
        else:
            op.execute(f"""CREATE FUNCTION bmt_{name}() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN IF {condition} THEN {body} END IF; RETURN NULL; END $$""")
            op.execute(f"""CREATE TRIGGER {name} AFTER UPDATE OF board_id,player_id ON {table}
                FOR EACH ROW EXECUTE FUNCTION bmt_{name}()""")


def downgrade():
    sqlite = op.get_bind().dialect.name == "sqlite"
    for name, table in (("reward_player_revision", "players"),
                        ("reward_move_personal_bests", "personal_bests"),
                        ("reward_move_lap_personal_bests", "lap_personal_bests")):
        op.execute(f"DROP TRIGGER {name}" + ("" if sqlite else f" ON {table}"))
        if not sqlite:
            op.execute(f"DROP FUNCTION bmt_{name}()")
