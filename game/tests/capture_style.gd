extends SceneTree
## Read-only graphical review of an existing creator document. Never saves records.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path: String = ""
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--style-document="): path = argument.trim_prefix("--style-document=")
		if argument.begins_with("--style-output="): output = argument.trim_prefix("--style-output=")
	if not FileAccess.file_exists(path) or not output.is_absolute_path():
		push_error("CaptureStyle requires -StyleDocument pointing to an existing creator JSON.")
		quit(1)
		return
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null:
		quit(1)
		return
	root.size = Vector2i(1494,1009)
	var original_cells: PackedInt32Array = track.cells.duplicate()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	game.set("paused",true)
	for frame: int in range(4):
		game.call("_process",0.1)
		await RenderingServer.frame_post_draw
	if track.cells != original_cells:
		push_error("Presentation changed native collision cells")
		quit(1)
		return
	print("STYLE_CHECK: native cells preserved")
	var error: Error = root.get_texture().get_image().save_png(output)
	print("STYLE_CAPTURE: ",error_string(error))
	quit(0 if error == OK else 1)
