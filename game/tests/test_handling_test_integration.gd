extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", description)

func create_game(track: NativeTrack, vehicle: String, editor: bool = false, enabled: bool = true) -> Node:
	var game: Node = (load("res://core/game.tscn") as PackedScene).instantiate()
	game.initial_track = track
	game.vehicle_id = vehicle
	game.production_mode = true
	game.editor_test = editor
	game.handling_test_enabled = enabled
	root.add_child(game)
	game.set_physics_process(false)
	return game

func run() -> void:
	root.size = Vector2i(1280, 720)
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
	var game: Node = create_game(track, "pickup")
	var baseline: Dictionary = game.handling.snapshot()
	check(not game.hud.handling_test_choice.is_visible_in_tree(), "selector stays clear of countdown lights")
	game.countdown_ticks = 0
	game.call("_process", 0.0)
	check(game.hud.handling_test_choice.is_visible_in_tree(), "selector appears when countdown ends")
	var observed: Array[int] = [0]
	game.handling_test_started.connect(func() -> void: observed[0] += 1)
	game.resume_ticket_id = "issued-canonical-ticket"
	game.online_frames.append(42)
	game.sim.state.tick = 100
	game.hud.handling_test_choice.select(1)
	game.hud.handling_test_choice.item_selected.emit(1)
	check(observed[0] == 1 and game.handling_test_index == 0, "selection announces the test before restarting")
	check(game.attempt_practice and game.sim.state.tick == 0 and game.online_frames.is_empty(), "test restarts as an unscored attempt and clears recorded inputs")
	check(game.handling.snapshot() != baseline and game.sim.config == game.handling, "simulation uses a distinct experimental configuration")
	check(game.resume_credits.ticket_id.is_empty() and not game.hud.rewind_button.visible, "test cannot spend canonical ticket rewind credits")
	game.open_rewind()
	check(not is_instance_valid(game.rewind_panel), "test cannot open a paid rewind")
	game.restart()
	check(game.attempt_practice and game.handling_test_index == 0, "retry remains unscored")
	game.hud.handling_test_choice.select(0)
	game.hud.handling_test_choice.item_selected.emit(0)
	check(not game.attempt_practice and game.handling.snapshot() == baseline and game.sim.state.tick == 0, "current handling restores the exact canonical config and restarts")
	game.queue_free()
	await process_frame
	var compact: Node = create_game(track, "compact")
	check(compact.hud.handling_test_choice == null, "Compact has no experimental selector")
	compact.select_handling_test(0)
	check(compact.handling_test_index == -1 and not compact.attempt_practice, "Compact rejects test selection")
	compact.queue_free()
	await process_frame
	var kart: Node = create_game(track, "kart")
	check(kart.hud.handling_test_choice == null, "final kart has no experimental selector")
	kart.select_handling_test(0)
	check(kart.handling_test_index == -1 and not kart.attempt_practice, "final kart rejects test selection")
	kart.queue_free()
	await process_frame
	var volt: Node = create_game(track, "electric")
	check(volt.hud.handling_test_choice == null, "final Volt has no experimental selector")
	volt.select_handling_test(0)
	check(volt.handling_test_index == -1 and not volt.attempt_practice, "final Volt rejects test selection")
	volt.queue_free()
	await process_frame
	var forklift: Node = create_game(track, "forklift")
	check(forklift.hud.handling_test_choice == null, "final forklift has no experimental selector")
	forklift.select_handling_test(1)
	check(forklift.handling_test_index == -1 and not forklift.attempt_practice, "final forklift rejects test selection")
	forklift.queue_free()
	await process_frame
	var restricted: Node = create_game(track, "pickup", false, false)
	check(restricted.hud.handling_test_choice == null, "restricted competitive mode hides the selector")
	restricted.select_handling_test(0)
	check(restricted.handling_test_index == -1 and not restricted.attempt_practice, "restricted mode rejects direct selection")
	restricted.queue_free()
	await process_frame
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var creator_track: NativeTrack = TrackCompiler.compile(fixture.document)
	var editor: Node = create_game(creator_track, "pickup", true)
	check(editor.practice_validation_eligible, "canonical editor drive can validate a creator lap")
	editor.select_handling_test(2)
	check(editor.attempt_practice and not editor.practice_validation_eligible, "experimental editor driving cannot validate a creator lap")
	editor.select_handling_test(-1)
	check(editor.attempt_practice and editor.practice_validation_eligible, "restoring canonical handling restarts creator validation")
	editor.queue_free()
	await process_frame
	print("HANDLING_TEST_INTEGRATION ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
