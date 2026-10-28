extends SceneTree
## Native placement witness using the production race and parking-hall scenes.
var output: String
var samples: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func frames() -> void:
	for index: int in range(6): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="):
			output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	for mode: String in ["race","test-drive"]:
		var game: Node = load("res://garage/parking_hall_drive.tscn" if mode == "test-drive" else "res://core/game.tscn").instantiate()
		game.production_mode = true
		if mode == "race": game.initial_track = NativeTrack.read("res://resources/tracks/ellipse.json")
		root.add_child(game)
		while not game.preparation_complete: await process_frame
		game.set_physics_process(false)
		game.set_process(false)
		game.countdown_ticks = 0
		game.call("_process",0.0)
		for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1280,914),Vector2i(1920,864)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			await frames()
			var hud: PlaygroundHUD = game.hud
			var speed: Control = hud.find_child("SpeedCard",true,false)
			var bounds: Rect2 = speed.get_global_rect()
			var overlap: bool = false
			for zone: Rect2 in hud.touch.zones(): overlap = overlap or bounds.intersects(zone)
			samples.append({"mode":mode,"viewport":[dimensions.x,dimensions.y],
				"rect":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
				"font_size":hud.speed_label.get_theme_font_size("font_size"),
				"visible":speed.is_visible_in_tree(),"touch_overlap":overlap})
			if DisplayServer.get_name() != "headless":
				var path: String = output.path_join("%s-%dx%d.png" % [mode,dimensions.x,dimensions.y])
				if root.get_texture().get_image().save_png(path) != OK: quit(1); return
		game.queue_free()
		await frames()
	var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	print("SPEEDOMETER_CAPTURE: %d native layout samples" % samples.size())
	quit(0)
