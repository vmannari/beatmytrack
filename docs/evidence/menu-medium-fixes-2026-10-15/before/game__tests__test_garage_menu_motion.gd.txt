extends SceneTree
## Real retained viewport, sliding native panels, interruption and rendered frames.
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String = "res://../docs/evidence/garage-menu-motion-2026-10-14"
var motion_capture: bool = false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	while page._menu_motion != null: await frame()
	for tick: int in range(5): await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func check_resize_pixels() -> void:
	if DisplayServer.get_name() == "headless": return
	var immediately: PackedByteArray = page.showroom.showroom_viewport.get_texture().get_image().get_data()
	await frame()
	check(page.showroom.showroom_viewport.get_texture().get_image().get_data() == immediately,"first resized draw equals settled reflection/car pixels")

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
		if argument == "--capture-motion": motion_capture = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://garage_menu_motion_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	await settle()
	var viewport: SubViewport = page.showroom.showroom_viewport
	var car: CarVisual = page.showroom.car
	var room: Node = viewport.find_child("GarageArchitecture",true,false)
	var preview_parent: Node = page.preview.get_parent()
	var visibility_events: Array[int] = [0]
	page.showroom.visibility_changed.connect(func() -> void: visibility_events[0] += 1)
	page.showroom.zoom_by(0.86)
	page.showroom.rotate_view(Vector2(28,-6))
	var camera_pose: Transform3D = page.showroom.camera.transform
	var deck_pose: Transform3D = page.showroom.turntable.transform
	var condition: Dictionary = page.showroom.weathering.snapshot()
	var pigment: Dictionary = page.draft.duplicate(true)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		await capture("cars-"+str(dimensions.x))
		var start: Rect2 = page.preview.get_rect()
		page._confirm_car()
		check(page._menu_motion != null,"confirmation starts layout motion "+str(dimensions))
		check(page.preview.get_parent() == preview_parent and page.showroom.showroom_viewport == viewport,"confirmation keeps attached live viewport")
		page._menu_motion.pause()
		await frame()
		check(page.preview.get_rect().is_equal_approx(start),"confirmation retains exact outgoing car pane")
		check(page.gallery.visible and not page.gallery_slot.visible,"carousel remains drawn during departure")
		check(not page._departures.is_empty(),"native outgoing menus remain until they slide away")
		var tween: Tween = page._menu_motion
		for tick: int in range(1,13):
			tween.custom_step(GaragePage.MENU_MOVE_SECONDS/12.0)
			page._present_menu_layout()
			await frame()
			await check_resize_pixels()
			check(page.showroom.is_visible_in_tree() and page.showroom.showroom_viewport == viewport and page.showroom.car == car,"live car remains visible throughout movement")
			check(page.showroom.camera.transform == camera_pose and page.showroom.turntable.transform == deck_pose,"moving pane preserves actual camera and car pose")
			if tick == 6: await capture("select-mid-"+str(dimensions.x))
			if motion_capture: await capture("select-%d-%02d" % [dimensions.x,tick])
		tween.custom_step(0.001)
		await settle()
		check(page.preview.get_rect().is_equal_approx(page._slot_rect(page._preview_slot)),"car pane reaches new layout slot")
		check(page.preview.size != start.size and not page.gallery.visible,"confirmation reshapes pane and finishes carousel departure")
		check(page._departing_menus.get_child_count() == 0,"outgoing controls are released")
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"incoming tools finish on screen")
		await capture("selected-"+str(dimensions.x))
		var workbench: GarageLiveryMenu = page.livery_menu
		for destination: String in ["care","tuning","customise"]:
			page._show_section(destination)
			await settle()
			check(page.preview.get_parent() == preview_parent and page.showroom.car == car and viewport.find_child("GarageArchitecture",true,false) == room,"section retains showroom, car and room")
			check(page.showroom.weathering.snapshot() == condition and page.draft == pigment,"section preserves local condition and pigments")
			await capture(destination+"-"+str(dimensions.x))
		check(page.livery_menu == workbench,"sliding away and back retains livery workbench")
		page._show_section("cars")
		page._menu_motion.pause()
		await frame()
		tween = page._menu_motion
		for tick: int in range(1,13):
			tween.custom_step(GaragePage.MENU_MOVE_SECONDS/12.0)
			page._present_menu_layout()
			await frame()
			await check_resize_pixels()
			if tick == 6: await capture("back-mid-"+str(dimensions.x))
			if motion_capture: await capture("back-%d-%02d" % [dimensions.x,tick])
		tween.custom_step(0.001)
		await settle()
		check(page.gallery.visible and page._departures.is_empty(),"Back restores carousel and cleans departures")
	check(visibility_events[0] == 0,"layout never hides or reparents live showroom")
	page.open_car(0)
	page._menu_motion.pause()
	await frame()
	page._menu_motion.custom_step(0.08)
	page._present_menu_layout()
	var interrupted: Rect2 = page.preview.get_rect()
	page._show_section("care")
	check(page.preview.get_rect() == interrupted,"rapid navigation continues from displayed car rectangle")
	page._show_section("tuning")
	page._show_section("customise")
	page._show_section("cars")
	await settle()
	check(page.section == "cars" and page._departing_menus.get_child_count() == 0,"rapid navigation retains latest destination with bounded panels")
	page.open_car(0)
	page._show_section("care")
	var dirty: Dictionary = VehicleWeathering.new().snapshot()
	dirty.dirt = 0.75
	dirty.mud = 0.75
	check(VehicleCondition.save(app.records,"compact",dirty) == OK,"seed local wash condition")
	await frame()
	page._toggle_wash()
	var before_wash: Dictionary = page.showroom.weathering.snapshot()
	page.showroom.weathering.wash(Vector3(-0.9,0.5,0.1),0.8)
	page._show_section("tuning")
	check(not page.showroom.wash_mode,"navigation stops washing before sliding controls")
	check(page.showroom.weathering.snapshot() != before_wash,"manual washing changes real local dirt")
	check(VehicleCondition.read(app.records,"compact").wash == page.showroom.weathering.snapshot().wash,"navigation saves exact partial wash before sliding controls")
	page.hide()
	check(page._menu_motion == null and page._departures.is_empty(),"hiding cancels motion and releases outgoing controls")
	check(viewport.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE,"live viewport retains visible-only updates")
	page.show()
	await settle()
	check(page.preview.get_rect().is_equal_approx(page._slot_rect(page._preview_slot)),"return restores exact final layout")
	page._show_section("customise")
	root.size = Vector2i(1280,720)
	await settle()
	check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"resize during motion keeps final tools inside shell")
	page._show_section("cars")
	await settle()
	page.gallery.scroll_horizontal = 19
	page._present_menu_layout()
	check(page.gallery.scroll_horizontal == 19,"layout presentation does not interrupt carousel scrolling")
	app.queue_free()
	await process_frame
	print("GARAGE_MENU_MOTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
