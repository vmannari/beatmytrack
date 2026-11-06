extends SceneTree
## Fresh-process proof: shell parsing and first menu leave optional features cold.
var failures: int = 0
var checks: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("SHELL_FAIL ",label)
func run() -> void:
	root.size = Vector2i(1280,720)
	var before: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://core/app.tscn")
	var loaded: int = Time.get_ticks_usec()
	print("SHELL_RESOURCE ",loaded-before)
	var app: Node = scene.instantiate()
	app.records = load("res://persistence/local_records.gd").new("user://shell/records.json")
	app.library = load("res://persistence/track_library.gd").new("user://shell/tracks")
	app.cloud_root_override = "user://shell/cloud"
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	app._publishing_slots_foreground = false
	app._garage_preloader.set_process(false)
	var generation: int = app._selected_preparation_generation
	app._cancel_selected_preparation()
	app._cancel_selected_preparation()
	check(app._selected_preparation_generation == generation+2,"empty cancellation still invalidates every previous generation")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab,true)
	check(app._feature_resources.is_empty(),"account keyboard navigation does not load the editor")
	print("SHELL_LOADED_MODULES ",app._feature_resources.keys())
	for path: String in ["res://core/game.tscn","res://core/features/race.gd","res://core/features/editor.gd","res://core/features/garage.gd","res://core/features/tracks.gd","res://core/features/rivalry.gd","res://core/features/challenges.gd","res://core/features/daily.gd","res://core/features/settings.gd","res://core/features/selected_track.gd","res://core/features/creator.gd","res://editor/editor_world.gd","res://editor/editor_canvas.gd","res://ui/garage_page.gd","res://ui/car_showroom.gd","res://vehicle/car_visual.gd"]:
		var cached: bool = ResourceLoader.has_cached(path)
		print("SHELL_CACHED ",path," ",cached)
		check(not cached,"optional resource stays cold "+path)
	check(not app.online.configured and app.screen == "account","offline initial destination")
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	for _i: int in range(3): await process_frame
	check(app._feature_resources.is_empty(),"idle account callbacks leave feature modules cold")
	check(app._garage_preloader.studio == null and app._garage_preloader.picture_service == null,"idle account does not construct a native Garage")
	check(app.editor_memory._policy == null,"optional native memory policy stays unloaded")
	print("SHELL_READY ",checks," checks ",failures," failures ",Time.get_ticks_usec()/1000.0," ms")
	app.queue_free()
	app = null
	scene = null
	for _i: int in range(12): await process_frame
	quit(1 if failures else 0)
