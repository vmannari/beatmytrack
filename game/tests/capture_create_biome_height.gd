extends SceneTree
## Native layout receipt. Fresh local storage; no backend or owner profile.
var output: String = ""
var rows: Array[Dictionary] = []
var app: Node
var source_path: String = ""
var locale: String = "en"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output = ProjectSettings.globalize_path(argument.trim_prefix("--out="))
		if argument.begins_with("--source="): source_path = argument.trim_prefix("--source=")
		if argument.begins_with("--locale="): locale = argument.trim_prefix("--locale=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var folder: String = "user://create_biome_height_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	if not source_path.is_empty():
		var original := GDScript.new()
		original.source_code = FileAccess.get_file_as_string(source_path)
		if original.reload() != OK:
			quit(1)
			return
		app.set_script(original)
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	if not app.startup_complete:
		print("CREATE_BIOME_HEIGHT: startup incomplete")
		quit(1)
		return
	app._new_document()
	await create_timer(0.5).timeout
	GameLanguage.instance().choose(locale)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1360,720),Vector2i(1600,720)]:
		root.size = dimensions
		for biome: String in ["desert","winter","night_city","storm","pine","desert"]:
			var choice: Button = app.content.find_child("Biome_"+biome,true,false)
			choice.pressed.emit()
			for frame: int in range(12): await process_frame
			var picker: Control = app.content.find_child("BiomePicker",true,false)
			var summary: Control = app.content.find_child("BiomeSummary",true,false)
			var description: Label = app.content.find_child("BiomeDescription",true,false)
			var create: Control = app.content.find_child("CreateTrack",true,false)
			var row: Dictionary = {"viewport":[dimensions.x,dimensions.y],"biome":biome,"picker":rect(picker),"summary":rect(summary),"create":rect(create),"description":rect(description),"lines":description.get_line_count(),"text_height":description.get_minimum_size().y,"reserved_height":description.custom_minimum_size.y,"font_height":description.get_theme_font("font").get_height(description.get_theme_font_size("font_size")),"line_height":description.get_line_height(),"style_height":description.get_theme_stylebox("normal").get_minimum_size().y}
			rows.append(row)
			print("BIOME_LAYOUT: ",JSON.stringify(row))
			if not output.is_empty() and DisplayServer.get_name() != "headless" and biome in ["pine","winter","storm"]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%dx%d-%s.png" % [dimensions.x,dimensions.y,biome]))
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(rows,"\t"))
	app.queue_free()
	await process_frame
	GameSoundtrack.instance().queue_free()
	await create_timer(0.25).timeout
	print("CREATE_BIOME_HEIGHT: captured %d selections" % rows.size())
	quit()

func rect(control: Control) -> Array:
	var bounds: Rect2 = control.get_global_rect()
	return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
