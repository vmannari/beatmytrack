extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = "--uncached" not in OS.get_cmdline_user_args()
	game.hitch_diagnostics_enabled = false
	print("SCENE_PROBE before_ready diagnostics_disabled")
	root.add_child(game)
	print("SCENE_PROBE after_ready")
	for index: int in range(5): await process_frame
	game.free()
	quit()
