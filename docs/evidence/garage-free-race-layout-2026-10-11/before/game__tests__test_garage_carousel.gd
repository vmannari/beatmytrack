extends SceneTree
## Actual Garage navigation/input with isolated per-car local saves and captures.
var checks: int = 0
var failures: int = 0
var app: Node
var page: GaragePage
var output: String = "res://../docs/evidence/garage-carousel-2026-10-11"

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	await create_timer(0.25).timeout
	for i: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func touch(point: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 0
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)

func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	touch(point, true)
	await process_frame
	touch(point, false)
	await settle()

func swipe(control: Control, distance: float, canceled: bool = false) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	touch(point, true)
	await process_frame
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = point + Vector2(distance, 0)
	event.relative = Vector2(distance, 0)
	root.push_input(event, true)
	await process_frame
	touch(event.position, false, canceled)
	await settle()

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = ProjectSettings.globalize_path(output)
	if "--mobile-evidence" in OS.get_cmdline_user_args(): output = output.path_join("mobile")
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://garage_carousel_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await settle()
	check(app.records.settings.get("vehicle_conditions", {}).is_empty(), "preparing a clean Garage creates no cosmetic save")
	VehicleCatalog.selected = "compact"
	var dirty: Dictionary = VehicleWeathering.new().snapshot()
	dirty.dirt = 0.85
	dirty.mud = 0.85
	check(VehicleCondition.save(app.records, "compact", dirty) == OK, "seed local compact dirt")
	var pb_key: String = app.records.key_for(app.selected_track, VehicleCatalog.config("compact"))
	app._show_screen("garage")
	await settle()
	page = app.root_ui.find_child("GaragePage", true, false)
	var shell: Control = app.root_ui
	check(page.section == "cars" and page.gallery_slot.visible, "Garage opens the car carousel")
	check(page.cards.get_child_count() == 5 and page.find_child("VehicleSelector", true, false) == null, "all five cars replace the old dropdown")
	check(page.find_child("GarageWash", true, false) == null and page.pickers.is_empty(), "overview exposes car selection before care/customise")
	check(page.gallery.get_h_scroll_bar().max_value > page.gallery.size.x, "car carousel has scrollable content")
	check(app.root_ui.get_node("MenuPageSwipe")._owns_gesture(app.root_ui, page.gallery.get_global_rect().get_center()), "car carousel owns its gestures")
	await swipe(page.gallery, -180)
	check(app.screen == "garage" and page.section == "cars" and VehicleCatalog.selected == "compact", "swiping cards never opens a car or changes menu page")
	check(page.gallery.scroll_horizontal == page.tile_stride, "swipe settles on a complete card")
	await swipe(page.gallery, 180)
	await swipe(page.gallery, 180)
	check(page.gallery.scroll_horizontal == 0 and app.screen == "garage", "carousel first edge retains gesture ownership")
	await swipe(page.cards.get_child(0), 0, true)
	check(page.section == "cars", "canceled tap cannot open a car")
	check(page.telemetry_exposures().size() == 4 and page.telemetry_exposures().all(func(entry: Dictionary) -> bool: return entry.car_id != "kart"), "only visible car cards count as existing car exposures")
	(page.cards.get_child(4) as Control).grab_focus()
	await settle()
	check(page.gallery.get_global_rect().encloses((page.cards.get_child(4) as Control).get_global_rect()), "keyboard focus reveals the last car")
	page.gallery.scroll_horizontal = 0
	for dimensions: Vector2i in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.gallery.get_global_rect()), "carousel fits " + str(dimensions))
		check((roundi(page.gallery.size.x) + 12) % page.tile_stride == 0, "only complete cards " + str(dimensions))
		await capture("cars-" + str(dimensions.x))
		await tap(page.cards.get_child(0))
		check(page.telemetry_exposures().is_empty(), "car menus do not report hidden carousel impressions")
		check(page.section == "car" and not page.gallery_slot.visible and app.root_ui == shell, "car card opens menu without rebuilding shell")
		for name: String in ["GarageCustomise", "GarageCare", "GarageTuning", "GarageBack"]:
			var button: Control = page.find_child(name, true, false)
			check(button != null and app.root_ui.get_global_rect().encloses(button.get_global_rect()), name + " fits " + str(dimensions))
		await capture("car-menu-" + str(dimensions.x))
		await tap(page.find_child("GarageCustomise", true, false))
		check(page.section == "customise" and page.pickers.size() == 2, "Customise opens livery and colours")
		page._select_livery(1)
		var saved_livery: Dictionary = VehicleLivery.for_car(app.records.settings, "compact")
		check(saved_livery.colors.body == "9a3e50" and saved_livery.colors.accent == "e4b74c", "selecting livery persists both paint slots")
		check(page.showroom.car.paint_materials.body.albedo_color.to_html(false) == "9a3e50", "livery updates actual model")
		check(VehicleCondition.read(app.records, "compact").dirt == 0.85, "livery leaves accumulated dirt intact")
		check(app.root_ui.get_global_rect().encloses(page.pickers.body.get_global_rect()), "colours fit " + str(dimensions))
		await capture("customise-" + str(dimensions.x))
		page._preview_color(Color("417585"), "body")
		await tap(page.find_child("GarageBack", true, false))
		check(VehicleLivery.for_car(app.records.settings, "compact").colors.body == "417585", "leaving Customise saves unclosed colour preview")
		await tap(page.find_child("GarageCare", true, false))
		check(page.section == "care" and not page.showroom.wash_mode, "Care waits for explicit Wash action")
		await tap(page.wash_button)
		check(page.showroom.wash_mode and page.wash_button.text == "Done", "Care enters manual Wash")
		await capture("care-" + str(dimensions.x))
		# Wash one real body patch; navigation must commit the partial mask.
		var before: PackedByteArray = page.showroom.weathering.wash_image.get_data()
		page.showroom.weathering.wash(Vector3(-0.9, 0.5, 0.1), 0.8)
		check(page.showroom.weathering.wash_image.get_data() != before, "Care changes a local dirt patch")
		await tap(page.find_child("GarageBack", true, false))
		check(not page.showroom.wash_mode and not page.showroom.washing, "leaving Care stops the brush")
		check(VehicleCondition.read(app.records, "compact").wash == page.showroom.weathering.snapshot().wash, "leaving Care commits exact partial wash")
		await tap(page.find_child("GarageTuning", true, false))
		check(page.section == "tuning" and page.tools.find_children("*", "Range", true, false).is_empty(), "Tuning is a placeholder with no handling controls")
		check(app.records.key_for(app.selected_track, VehicleCatalog.config("compact")) == pb_key, "garage tools preserve canonical PB key")
		await capture("tuning-" + str(dimensions.x))
		await tap(page.find_child("GarageBack", true, false))
		await tap(page.find_child("GarageBack", true, false))
		check(page.section == "cars", "two Back actions return through car menu to carousel")
		# Reapply seed between independent viewport checks.
		check(VehicleCondition.save(app.records, "compact", dirty) == OK, "restore independent dirty-view fixture")
		await settle()
	for index: int in range(VehicleCatalog.IDS.size()):
		page.open_car(index)
		await settle()
		var id: String = VehicleCatalog.IDS[index]
		check(VehicleCatalog.selected == id and app.records.settings.selected_car == id and page.showroom.car.vehicle_id == id, id + " selection persists and switches actual model")
		page._show_section("customise")
		page._select_livery(2)
		page._show_section("care")
		check(page.showroom.weathering.dirt_amount == (0.85 if id == "compact" else 0.0), id + " independent local dirt")
		page._show_section("cars")
	var reopened := LocalRecords.new(app.records.path)
	reopened.load_records()
	check(reopened.settings.selected_car == "kart", "selected car survives local restart")
	for id: String in VehicleCatalog.IDS:
		check(VehicleLivery.for_car(reopened.settings, id).colors.body == "273b50", id + " livery survives local restart")
	check(VehicleCondition.read(reopened, "compact").dirt == 0.85 and float(VehicleCondition.read(reopened, "kart").get("dirt", 0.0)) == 0.0, "cosmetic conditions remain separate on restart")
	page.open_car(4)
	page._show_section("care")
	page._toggle_wash()
	page.hide()
	check(page.telemetry_exposures().is_empty(), "hidden cached Garage emits no car impressions")
	check(not page.showroom.wash_mode, "hidden cached Garage ends Wash")
	page.show()
	check(page.wash_button.text == "Wash", "returning Care offers Wash after the brush was stopped")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await settle()
	check(page.section == "car", "Escape returns from Care to car menu")
	root.push_input(escape, true)
	await settle()
	check(page.section == "cars", "Escape returns from car menu to carousel")
	page._show_section("cars")
	check(page.wash_button == null, "returning carousel has no stale Wash control")
	app.queue_free()
	await process_frame
	print("GARAGE_CAROUSEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
