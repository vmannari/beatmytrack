extends SceneTree
## GCS01–GCS04: actual Garage browsing, truthful stats, input and responsive layout.
const Stats = preload("res://ui/garage_car_stats.gd")
var checks: int = 0
var failures: int = 0
var output: String
var page: GaragePage
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",caption)

func settle(count: int = 8) -> void:
	for frame: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func check_content(id: String) -> void:
	var data: Dictionary = Stats.performance(id)
	var config: HandlingConfig = VehicleCatalog.config(id)
	check(preload("res://ui/garage_performance_data.gd").PHYSICS_VERSION == VehicleSimulation.PHYSICS_VERSION,"launch measurement physics version "+id)
	check(float(data.acceleration) >= 0.0,"current tune has a qualified launch measurement "+id)
	check(page._car_stats.vehicle_id == id,"stats follow browsed car "+id)
	check(page._car_stats.stat_rows.top_speed.row.tooltip_text == GameText.message("{speed} km/h",{"speed":roundi(config.maximum_speed*3.6)}),"top speed tooltip matches race configuration "+id)
	check(int(data.mass) == roundi(config.mass),"weight matches race configuration "+id)
	check(page._car_stats._description.text == GameText.message(Stats.SUMMARIES[id]),"short description matches car "+id)
	# Replay the displayed rounded launch time with the actual clean-road simulation.
	var sim := VehicleSimulation.new(config)
	var drive: DriveFrame = DriveFrame.sample(0,1,0)
	var target_tick: int = ceili(float(data.acceleration)*VehicleSimulation.TICK_RATE)
	for tick: int in range(target_tick-1): sim.step(drive)
	check(sim.state.velocity.length()*3.6 < 60.0,"car has not reached 60 before measured tick "+id)
	sim.step(drive)
	check(sim.state.velocity.length()*3.6 >= 60.0,"car reaches 60 at measured tick "+id)
	measurements[id] = data

func check_layout() -> void:
	var panel: Control = page._car_stats
	check(page.preview.get_global_rect().encloses(panel.get_global_rect()),"stats fit inside preview "+str(root.size))
	check(panel.get_global_rect().encloses(page._car_stats._description.get_global_rect()),"description fits panel "+str(root.size))
	var title_rect: Rect2 = page.heading.get_global_rect()
	var title_width: float = page.heading.get_theme_font("font").get_string_size(page.heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,page.heading.get_theme_font_size("font_size")).x
	var painted_title := Rect2(Vector2(title_rect.get_center().x-title_width*0.5,title_rect.position.y),Vector2(title_width,title_rect.size.y))
	check(not panel.get_global_rect().intersects(painted_title),"stats clear centered car title "+str(root.size))
	check(not panel.get_global_rect().intersects(page.view_hint.get_global_rect()),"stats clear drag hint "+str(root.size))
	check(not panel.get_global_rect().intersects(page.gallery.get_global_rect()),"stats clear carousel "+str(root.size))
	check_pass_through(panel)

func check_pass_through(node: Node) -> void:
	if node is Control: check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE,"information passes drag input: "+node.name)
	for child: Node in node.get_children(): check_pass_through(child)

func drag_over_stats(touch: bool) -> void:
	var point: Vector2 = page._car_stats.get_global_rect().get_center()
	var initial_yaw: float = page.showroom.yaw
	if touch:
		var press := InputEventScreenTouch.new()
		press.index = 4
		press.position = point
		press.pressed = true
		root.push_input(press,true)
		var drag := InputEventScreenDrag.new()
		drag.index = 4
		drag.position = point+Vector2(20,0)
		drag.relative = Vector2(20,0)
		root.push_input(drag,true)
		press = press.duplicate()
		press.pressed = false
		root.push_input(press,true)
	else:
		var press := InputEventMouseButton.new()
		press.position = point
		press.global_position = point
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		root.push_input(press,true)
		var motion := InputEventMouseMotion.new()
		motion.position = point+Vector2(20,0)
		motion.global_position = motion.position
		motion.relative = Vector2(20,0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		press = press.duplicate()
		press.pressed = false
		root.push_input(press,true)
	check(not is_equal_approx(page.showroom.yaw,initial_yaw),"touch drag turns car through stats" if touch else "mouse drag turns car through stats")
	page.showroom.yaw = initial_yaw
	page.showroom._orbit()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	# Initialize the test's canonical verifier before App begins worker asset reads.
	VehicleSimulation.new(VehicleCatalog.config("compact")).step(DriveFrame.sample(0,1,0))
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-car-stats-2026-11-14/"+RenderingServer.get_current_rendering_method())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = ProjectSettings.globalize_path(argument.trim_prefix("--evidence-root="))
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = ProjectSettings.globalize_path("res://../build/garage-car-stats-2026-11-14/app-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings = {"music_enabled":false,"selected_car":"compact","tutorial_complete":true}
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	while page == null or not page.showroom.showroom_ready:
		await process_frame
		page = app.root_ui.find_child("GaragePage",true,false)
	await settle(12)
	page._finish_menu_move()
	var settings: Dictionary = app.records.settings.duplicate(true)
	var started: int = Time.get_ticks_usec()
	for id: String in VehicleCatalog.IDS: Stats.performance(id)
	var measurement_ms: float = (Time.get_ticks_usec()-started)/1000.0
	for index: int in range(VehicleCatalog.IDS.size()):
		page.preview_car(index)
		page.gallery.ensure_control_visible(page.cards.get_child(index))
		page.showroom.finish_car_transition()
		await settle()
		check_content(VehicleCatalog.IDS[index])
		check_layout()
		await capture(VehicleCatalog.IDS[index]+"-1280")
	drag_over_stats(false)
	drag_over_stats(true)
	# Immediate browsing and cancellation must keep title, card and stats coherent.
	page._queue_car_preview(1)
	check(page._car_stats.vehicle_id == "kart" and page.heading.text == "KART","stats update in the input callback")
	page._queue_car_preview(3)
	check(page._car_stats.vehicle_id == "electric","latest pending choice owns stats")
	page._cancel_car_preview()
	check(page._car_stats.vehicle_id == page.vehicle_id,"cancel restores displayed car stats")
	page._show_section("care")
	check(not page._car_stats.visible,"stats hidden while washing")
	page._show_section("customise")
	check(not page._car_stats.visible,"stats hidden in workshop")
	page._show_section("cars")
	page._finish_menu_move()
	check(page._car_stats.visible,"returning to cars restores stats")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,900),Vector2i(2560,1354)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle(15)
		for index: int in [2,5]:
			page.preview_car(index)
			page.gallery.ensure_control_visible(page.cards.get_child(index))
			page.showroom.finish_car_transition()
			await settle()
			check_layout()
			await capture(VehicleCatalog.IDS[index]+"-"+str(dimensions.x))
	# Existing installation language choices also need readable compact descriptions.
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await settle()
	for locale: String in ["fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		for id: String in VehicleCatalog.IDS:
			page._car_stats.set_vehicle(id)
			await settle(2)
			check(page.preview.get_global_rect().encloses(page._car_stats.get_global_rect()),"compact localized panel fits "+locale+"/"+id)
			check(page._car_stats.get_global_rect().encloses(page._car_stats._description.get_global_rect()),"compact localized description fits "+locale+"/"+id)
			check(page._car_stats._description.text == GameText.message(Stats.SUMMARIES[id]),"localized car summary "+locale+"/"+id)
	TranslationServer.set_locale("en")
	GameFonts.configure("en")
	GameText.refresh(self)
	page._car_stats.set_vehicle(page.vehicle_id)
	check(app.records.settings == settings,"browsing leaves saved selection and cosmetics unchanged")
	app.queue_free()
	await settle()
	var report: Dictionary = {"checks":checks,"failures":failures,"measurement_ms":measurement_ms,"cars":measurements}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GARAGE_CAR_STATS ",JSON.stringify(report))
	quit(1 if failures else 0)
