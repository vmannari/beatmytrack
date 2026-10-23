extends SceneTree
## Native Garage navigation bounds, real pointer activation and review captures.
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String
var before: bool = false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	for tick: int in range(8): await frame()
	while page._menu_motion != null: await frame()
	for tick: int in range(4): await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func rail_bounds(label: String) -> void:
	var first: Button = page.rail.get_child(0)
	var previous: Rect2
	for child: Node in page.rail.get_children():
		var button: Button = child
		var rect: Rect2 = button.get_global_rect()
		check(rect.size.is_equal_approx(first.size),"equal button dimensions "+label+" "+button.name)
		check(is_equal_approx(rect.position.x,first.global_position.x),"aligned left edges "+label+" "+button.name)
		check(rect.size.x >= 48 and rect.size.y >= 48,"touch target "+label+" "+button.name)
		check(page.get_global_rect().encloses(rect),"button fits Garage "+label+" "+button.name)
		check(button.icon != null and not button.tooltip_text.is_empty(),"named navigation icon "+label+" "+button.name)
		if previous.has_area(): check(rect.position.y >= previous.end.y,"no overlapping buttons "+label)
		previous = rect
		if before: continue
		# Focus and pointer states must not shift the glyph within its button.
		var normal: StyleBox = button.get_theme_stylebox("normal")
		for state: String in ["hover","pressed","focus","disabled"]:
			var style: StyleBox = button.get_theme_stylebox(state)
			check(style.get_content_margin(SIDE_LEFT) == normal.get_content_margin(SIDE_LEFT) and style.get_content_margin(SIDE_RIGHT) == normal.get_content_margin(SIDE_RIGHT) and style.get_content_margin(SIDE_TOP) == normal.get_content_margin(SIDE_TOP) and style.get_content_margin(SIDE_BOTTOM) == normal.get_content_margin(SIDE_BOTTOM),"stable icon placement in "+state+" "+label+" "+button.name)

func click(button: Button, touch: bool = false) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move,true)
	await frame()
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 5
			event.position = point
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = pressed
			root.push_input(event,true)
		await frame()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var evidence_root: String = "res://../docs/evidence/garage-sidebar-2026-10-19/final"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): evidence_root = argument.trim_prefix("--evidence-root=")
	before = "--before" in OS.get_cmdline_user_args()
	output = ProjectSettings.globalize_path(evidence_root)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = ProjectSettings.globalize_path("res://../build/garage-sidebar/"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await frame()
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	await settle()
	var viewport: SubViewport = page.showroom.showroom_viewport
	var car: CarVisual = page.showroom.car
	var rail_report: Array[Dictionary] = []
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		page._show_section("cars")
		await settle()
		rail_bounds("cars "+str(dimensions))
		await capture("cars-"+str(dimensions.x))
		page._confirm_car()
		await settle()
		rail_bounds("selected "+str(dimensions))
		await capture("customise-"+str(dimensions.x))
		var rects: Array = []
		for button: Node in page.rail.get_children(): rects.append({"name":button.name,"rect":str(button.get_global_rect())})
		rail_report.append({"size":str(dimensions),"buttons":rects})
		var positions: Array[Rect2] = []
		for button: Node in page.rail.get_children(): positions.append(button.get_global_rect())
		for destination: String in ["care","tuning","records","trophies","news"]:
			var target: Button = page.rail.get_node("Garage"+destination.capitalize())
			await click(target,destination in ["records","news"])
			await settle()
			check(page.section == destination,"pointer opens "+destination+" "+str(dimensions))
			for index: int in range(positions.size()):
				check(page.rail.get_child(index).get_global_rect().is_equal_approx(positions[index]),"rail stays fixed across sections "+destination+" "+str(index)+" "+str(dimensions))
			check(page.showroom.showroom_viewport == viewport and page.showroom.car == car,"retained car/viewport "+destination)
			if dimensions.x == 1280: await capture(destination+"-1280")
		page._car_menu_open = false
	page._show_section("cars")
	await settle()
	check(app.records.settings.get("vehicle_conditions",{}).is_empty(),"navigation does not write car condition")
	var report := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"before":before,"renderer":RenderingServer.get_current_rendering_method(),"layouts":rail_report},"\t"))
	report.close()
	app.queue_free()
	await frame()
	print("GARAGE_SIDEBAR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
