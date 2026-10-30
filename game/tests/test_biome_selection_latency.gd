extends SceneTree
## Exercise real menu taps, retained swipe pages and the final Create action.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var output: String = ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output = ProjectSettings.globalize_path(argument.trim_prefix("--out="))
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://biome_selection_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"covered startup completes")
	app._new_document()
	await create_timer(0.5).timeout
	await capture("initial")
	var original_document: Dictionary = app.document.duplicate(true)
	for biome: String in ["desert","winter","night_city","storm","pine"]:
		var shell: Node = app.root_ui
		var body: Node = app.menu_body
		var picker: Node = app.content.find_child("BiomePicker",true,false)
		var summary: Node = app.content.find_child("BiomeSummary",true,false)
		var create: Button = app.content.find_child("CreateTrack",true,false)
		var choice: Button = picker.get_node("Biome_"+biome)
		var neighbors: Dictionary = app.menu_neighbors.duplicate()
		var generation: int = app._navigation_generation
		choice.grab_focus()
		var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var began: int = Time.get_ticks_usec()
		choice.pressed.emit()
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		rows.append({"biome":biome,"callback_ms":elapsed,"new_nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))-nodes_before})
		check(app.document.theme == biome and app.screen == "biome","tap commits "+biome+" immediately")
		check(app.root_ui == shell and app.menu_body == body,"tap retains menu shell and body: "+biome)
		check(is_instance_valid(picker) and picker == app.content.find_child("BiomePicker",true,false),"tap retains biome cards: "+biome)
		check(is_instance_valid(summary) and summary == app.content.find_child("BiomeSummary",true,false),"tap retains summary: "+biome)
		check(is_instance_valid(create) and create == app.content.find_child("CreateTrack",true,false),"tap retains Create action: "+biome)
		check(app._navigation_generation == generation and app.menu_neighbors == neighbors,"tap preserves warmed swipe pages: "+biome)
		check(root.gui_get_focus_owner() == choice,"tap preserves keyboard focus: "+biome)
		check(app.content.get_meta("biome_theme") == biome,"cached page records latest biome: "+biome)
		check(app.content.find_child("BiomeDescription",true,false).text.contains({"pine":"Sunlit grass","desert":"sunlit sand","night_city":"Dark asphalt","winter":"Snowy ground","storm":"Rain falls"}[biome]),"summary describes selected biome: "+biome)
		for other: String in TrackDocument.THEMES:
			var card: Node = app.content.find_child("Biome_"+other,true,false)
			var band: StyleBoxFlat = card.find_child("BiomeLabelOverlay",true,false).get_theme_stylebox("panel")
			check(band.bg_color == (MenuStyle.ACCENT if other == biome else Color("091720f2")),"exact selected label band: "+biome+"/"+other)
		await process_frame
		if biome in ["winter","storm"]: await capture(biome)
	var expected: Dictionary = original_document.duplicate(true)
	expected.theme = "pine"
	check(app.document == expected and app.history.is_empty() and app.redo_history.is_empty(),"preview changes only biome and leaves editing history untouched")
	var shell: Node = app.root_ui
	var generation: int = app._navigation_generation
	app._preview_creation_biome("pine")
	app._preview_creation_biome("coast")
	check(app.root_ui == shell and app._navigation_generation == generation and app.document == expected,"same or invalid biome does no navigation")
	app._preview_creation_biome("storm")
	app._preview_creation_biome("winter")
	check(app.document.theme == "winter" and app.root_ui == shell,"rapid taps retain the latest choice without rebuilding")
	tap(app.content.find_child("Biome_storm",true,false))
	check(app.document.theme == "storm" and app.root_ui == shell,"viewport touch selects Storm without rebuilding")
	tap(app.content.find_child("Biome_winter",true,false))
	check(app.document.theme == "winter" and app.root_ui == shell,"second viewport touch immediately selects Winter")
	# A new draft can reuse this cached page after resetting its biome.
	var picker: Node = app.content.find_child("BiomePicker",true,false)
	app.document.theme = "desert"
	app._refresh_cached_menu_page("biome",app.content)
	check(app.content.find_child("BiomePicker",true,false) == picker and app.content.get_meta("biome_theme") == "desert","cached-page refresh updates existing controls")
	app._navigate_menu_page("garage")
	await create_timer(0.4).timeout
	app._navigate_menu_page("biome")
	await create_timer(0.4).timeout
	check(app.root_ui == shell and app.document.theme == "desert" and app.content.get_meta("biome_theme") == "desert","Garage return preserves selection and shell")
	app._new_document()
	check(app.document.theme == "pine" and app.content.get_meta("biome_theme") == "pine","new draft resets the retained picker")
	app._preview_creation_biome("winter")
	var create: Button = app.content.find_child("CreateTrack",true,false)
	create.pressed.emit()
	check(app.screen == "create" and app.document.theme == "winter","retained Create action opens the latest biome")
	app._preview_creation_biome("desert")
	check(app.document.theme == "winter","biome cannot change after entering editor")
	deadline = Time.get_ticks_msec()+15000
	while (app.editor_preview_thread != null or app.canvas.preparing) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.canvas.preparing,"selected editor finishes preparing")
	app.queue_free()
	await process_frame
	GameSoundtrack.instance().queue_free()
	for i: int in range(3): await process_frame
	# Retire the menu decoder on the mixer thread before engine shutdown.
	await create_timer(0.25).timeout
	var result: Dictionary = {"checks":checks,"failures":failures,"renderer":"headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method(),"selections":rows}
	print("BIOME_SELECTION: ",JSON.stringify(result))
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"))
	quit(1 if failures else 0)

func tap(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)

func capture(label: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
