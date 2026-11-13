CREATE FUNCTION bmt_reward_player_revision() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN IF OLD.disabled IS DISTINCT FROM NEW.disabled OR OLD.is_test_driver IS DISTINCT FROM NEW.is_test_driver OR OLD.deleted_at IS DISTINCT FROM NEW.deleted_at THEN UPDATE boards SET stats_revision=stats_revision+1,lap_revision=lap_revision+1
        WHERE id IN (SELECT board_id FROM personal_bests WHERE player_id=NEW.id
        UNION SELECT board_id FROM lap_personal_bests WHERE player_id=NEW.id); END IF; RETURN NULL; END $$

CREATE TRIGGER reward_player_revision AFTER UPDATE OF disabled,is_test_driver,deleted_at
            ON players FOR EACH ROW EXECUTE FUNCTION bmt_reward_player_revision()

CREATE FUNCTION bmt_reward_move_personal_bests() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN IF OLD.board_id IS DISTINCT FROM NEW.board_id OR OLD.player_id IS DISTINCT FROM NEW.player_id THEN UPDATE boards SET stats_revision=stats_revision+1 WHERE id IN (OLD.board_id,NEW.board_id); END IF; RETURN NULL; END $$

CREATE TRIGGER reward_move_personal_bests AFTER UPDATE OF board_id,player_id ON personal_bests
                FOR EACH ROW EXECUTE FUNCTION bmt_reward_move_personal_bests()

CREATE FUNCTION bmt_reward_move_lap_personal_bests() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN IF OLD.board_id IS DISTINCT FROM NEW.board_id OR OLD.player_id IS DISTINCT FROM NEW.player_id THEN UPDATE boards SET lap_revision=lap_revision+1 WHERE id IN (OLD.board_id,NEW.board_id); END IF; RETURN NULL; END $$

CREATE TRIGGER reward_move_lap_personal_bests AFTER UPDATE OF board_id,player_id ON lap_personal_bests
                FOR EACH ROW EXECUTE FUNCTION bmt_reward_move_lap_personal_bests()

DROP TRIGGER reward_player_revision ON players

DROP FUNCTION bmt_reward_player_revision()

DROP TRIGGER reward_move_personal_bests ON personal_bests

DROP FUNCTION bmt_reward_move_personal_bests()

DROP TRIGGER reward_move_lap_personal_bests ON lap_personal_bests

DROP FUNCTION bmt_reward_move_lap_personal_bests()
