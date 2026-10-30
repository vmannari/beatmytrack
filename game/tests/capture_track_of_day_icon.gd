extends SceneTree
## Offline review of the shared production rail, at its real display size.
var output: String
var captures: int = 0
var app: Node

func _initialize() -> void:
	run.call_deferred()

func capture(filename: String) -> void:
	for _frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(output.path_join(filename+".png"))
	if result != OK:
		push_error("Icon capture failed: "+error_string(result))
		quit(1)
	captures += 1

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_DAILY_ICON_OUTPUT")
	if output.is_empty():
		push_error("Set BMT_DAILY_ICON_OUTPUT to the review directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,720)
	var directory: String = "user://daily_icon_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await capture("free-race-1280x720")
	# Press the actual shared button so the transition rail also uses the icon.
	var daily: Button = app.content.find_child("Mode_sun",true,false)
	if daily == null:
		push_error("Missing Track of the Day destination")
		quit(1)
		return
	daily.pressed.emit()
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await capture("daily-%dx%d" % [dimensions.x,dimensions.y])
	app.queue_free()
	await process_frame
	# Compare active/inactive artwork without the background or page content.
	root.size = Vector2i(480,380)
	root.content_scale_size = Vector2i(480,380)
	root.content_scale_factor = 1.0
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("101c26"),0))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",64)
	panel.add_child(row)
	for mode: String in ["free","daily"]:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",16)
		row.add_child(column)
		var label: Label = MenuStyle.label("Inactive" if mode == "free" else "Selected",18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		var rail := RaceModeRail.new()
		rail.selected = mode
		column.add_child(rail)
	await capture("rail-actual-size")
	panel.queue_free()
	await process_frame
	print("DAILY_ICON_CAPTURE: %d native views saved" % captures)
	quit(0)
