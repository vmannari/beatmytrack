extends SceneTree
## One-off review capture; no preference writes or simulation changes.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output := ProjectSettings.globalize_path("res://../docs/evidence/race-settings-padding-2026-10-08")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(fixture.document)
	game.production_mode = true
	game.preference_records = LocalRecords.new("user://race-settings-padding-records.json")
	game.preference_records.settings.ghost_mode = "race"
	root.add_child(game)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	for frame: int in range(5): await RenderingServer.frame_post_draw
	game.toggle_pause()
	var menu: Control = game.hud.pause_menu
	var scroll: ScrollContainer = menu.drawer.get_child(0)
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1600,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu._settings()
		scroll.scroll_vertical = 0
		for frame: int in range(6): await RenderingServer.frame_post_draw
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var gap: float = bar.global_position.x - menu.column.get_global_rect().end.x
		print("SETTINGS_PADDING: %dx%d gap=%.1f scrollbar_visible=%s" % [dimensions.x,dimensions.y,gap,bar.visible])
		var image: Image = root.get_texture().get_image()
		print("CAPTURE: ",image.save_png(output.path_join("settings-top-%dx%d.png" % [dimensions.x,dimensions.y])))
		scroll.scroll_vertical = int(bar.max_value)
		for frame: int in range(5): await RenderingServer.frame_post_draw
		print("CAPTURE: ",root.get_texture().get_image().save_png(output.path_join("settings-bottom-%dx%d.png" % [dimensions.x,dimensions.y])))
	menu.show_main()
	for frame: int in range(5): await RenderingServer.frame_post_draw
	scroll.scroll_vertical = 0
	for frame: int in range(5): await RenderingServer.frame_post_draw
	print("CAPTURE: ",root.get_texture().get_image().save_png(output.path_join("pause-main-1600x720.png")))
	game.queue_free()
	await process_frame
	quit()
