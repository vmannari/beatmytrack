extends "res://tests/test_race_loading_first_lap.gd"
## Same current App, effects, car and physics with only the task-start world queue.
func old_scene() -> PackedScene:
	var code: String = FileAccess.get_file_as_string("res://core/game.gd")
	var needle: String = 'preload("res://race/world_render_preparation.gd").new()'
	if code.count(needle) != 1: push_error("Missing world control constructor"); return null
	code = code.replace(needle,'preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd").new()')
	var script := GDScript.new()
	script.source_code = code
	if script.reload() != OK: return null
	var node: Node = load("res://core/game.tscn").instantiate()
	node.set_script(script)
	var result := PackedScene.new()
	var error: Error = result.pack(node)
	node.free()
	return result if error == OK else null
func run() -> void:
	create_timer(200).timeout.connect(func() -> void: printerr("BEFORE_LAP_TIMEOUT"); quit(1))
	root.size = Vector2i(960,540)
	app = load("res://core/app.tscn").instantiate()
	var control: PackedScene = old_scene()
	if control == null: quit(1); return
	app._feature_resources["res://core/game.tscn"] = control
	app.records = LocalRecords.new("user://graphics-before-lap/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://graphics-before-lap/tracks")
	app.cloud_root_override = "user://graphics-before-lap/cloud"
	preload("res://track/road_mesh_disk_cache.gd").directory = "user://graphics-before-lap/roads"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	if not "--only-interruptions" in OS.get_cmdline_user_args():
		app._garage_preloader.idle_ms = 100000000
		app._garage_preloader.foreground = false
	process_frame.connect(observe)
	var theme: String = "desert"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
	if "--only-interruptions" in OS.get_cmdline_user_args():
		for action: String in ["navigation","car","selection","scope","pressure","teardown"]:
			await race("compact","pine",action)
	else: await race("compact",theme)
	process_frame.disconnect(observe)
	app.queue_free()
	app = null
	control = null
	for _i: int in range(24): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"first_laps":lap_rows},"  "))
	print("BEFORE_GRAPHICS_LAP ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
