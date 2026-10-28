extends "res://tests/test_editor_practice.gd"
## Exact pre-task Game loaded only in this diagnostic process.
func _new_game(track: NativeTrack, practice: bool) -> Node:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/storm-test-recovery-2026-10-26/before/game/core/game.gd")
	assert(script.reload()==OK)
	var game: Node = (load("res://core/game.tscn") as PackedScene).instantiate()
	game.set_script(script)
	game.set("initial_track",track)
	game.set("production_mode",true)
	game.set("editor_test",practice)
	root.add_child(game)
	game.set_physics_process(false)
	return game
