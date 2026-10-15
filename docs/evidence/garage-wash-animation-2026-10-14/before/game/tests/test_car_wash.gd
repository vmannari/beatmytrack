extends SceneTree
## Isolated local storage; real models, race lifecycle, hit-tested mouse/touch washing.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/car-wash-2026-10-11"
var records: LocalRecords

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func settle() -> void:
	for i: int in range(10): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	var directory: String = "user://car_wash_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	records = LocalRecords.new(directory.path_join("records.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var effect := VehicleWeathering.new()
		effect.configure(car, "pine", VehicleCatalog.config(id))
		effect.dirt_amount = 0.8
		effect.mud_amount = 1.0
		effect.deposit_color = VehicleWeathering.COLORS.pine
		effect.snow_amount = 0.7
		effect.melt(2.0)
		check(is_equal_approx(effect.snow_amount, 0.45) and effect.smudge > 0.0 and effect.dirt_amount == 0.8, id + " snow melts into existing dirt")
		effect.melt(8.0)
		check(effect.snow_amount == 0.0 and effect.dirt_amount == 0.8 and effect.smudge > 0.4, id + " snow disappears without removing dirt")
		var point: Vector3 = effect.bounds.position + effect.bounds.size * Vector3(1.0, 0.2, 0.6)
		var before: PackedByteArray = effect.wash_image.get_data()
		effect.wash(point, 0.15)
		var partial: PackedByteArray = effect.wash_image.get_data()
		check(partial != before, id + " local wash changes volume")
		var cleaned: int = 0
		for index: int in range(partial.size()):
			if partial[index] > 0: cleaned += 1
		check(cleaned > 0 and cleaned < VehicleCondition.CELLS / 4, id + " wash is a patch")
		for z: int in range(16):
			for y: int in range(16): check(partial[y * 256 + z * 16] == 0, id + " opposite side remains dirty")
		effect.wash(point, 0.8)
		check(effect.wash_image.get_data() != partial, id + " continued washing cleans progressively")
		var saved: Dictionary = effect.snapshot()
		check(VehicleCondition.save(records, id, saved) == OK, id + " atomic local save")
		var reopened := LocalRecords.new(records.path)
		reopened.load_records()
		var recovered: Dictionary = VehicleCondition.read(reopened, id)
		check(recovered.get("wash") == saved.wash and recovered.get("color") == saved.color and recovered.get("version") == saved.version, id + " restart preserves exact wash and palette")
		for field: String in ["dirt", "snow", "wetness", "mud", "smudge"]:
			check(absf(float(recovered.get(field, -1)) - float(saved[field])) < 0.000000001, id + " restart preserves " + field)
		effect.configure(car, "desert", VehicleCatalog.config(id))
		check(effect.snapshot() == saved, id + " biome change retains condition")
		var state := VehicleState.new()
		state.velocity = Vector2(0, 20)
		var track := NativeTrack.new()
		track.metadata = {"theme": "desert"}
		track.cell_size = 10.0
		track.grid_width = 10
		track.grid_height = 10
		track.half_extent = Vector2(50, 50)
		track.cells.resize(100)
		track.cells.fill(0)
		track.deck_cells.resize(100)
		track.deck_cells.fill(-1)
		effect.present(state, track, false)
		state.tick = 120
		var canonical: Array = state.snapshot().duplicate(true)
		effect.present(state, track, false)
		check(effect.wash_image.get_data() != partial and effect.wash_image.get_data() != Marshalls.base64_to_raw(saved.wash), id + " later driving coats washed areas again")
		check(state.snapshot() == canonical, id + " re-coating does not change canonical state")
		effect.reset()
		effect.snow_amount = 0.6
		effect.melt(8.0)
		check(effect.smudge == 0.0 and effect.dirt_amount == 0.0 and not effect.installed, id + " clean car snow melts without inventing dirt")
		car.queue_free()
		await process_frame
	check(records.settings.vehicle_conditions.size() == 5 and records.records.is_empty(), "five independent cars; no PB writes")
	var invalid: Dictionary = records.settings.vehicle_conditions.duplicate(true)
	invalid.compact.dirt = INF
	check(not VehicleCondition.valid_collection(invalid), "reject nonfinite local dirt")
	invalid = records.settings.vehicle_conditions.duplicate(true)
	invalid.compact.version = 2
	check(not VehicleCondition.valid_collection(invalid), "reject unknown cosmetic version")
	await race_lifecycle()
	await garage()
	if DisplayServer.get_name() != "headless": await app_capture()
	print("CAR_WASH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func race_lifecycle() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = loop_track()
	game.vehicle_id = "compact"
	game.preference_records = records
	game.production_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var before: Dictionary = game.car_weathering.snapshot()
	check(before == VehicleCondition.read(records, "compact"), "race restores local condition")
	game.restart()
	check(game.car_weathering.snapshot() == before, "retry preserves cosmetic condition")
	game.car_weathering.snow_amount = 0.5
	var canonical: Array = game.sim.state.snapshot().duplicate(true)
	game._begin_finish()
	game.car_weathering.melt(8.0)
	game._complete_finish()
	check(game.sim.state.snapshot() == canonical, "finish/melt never changes scored state")
	check(VehicleCondition.read(records, "compact").snow == 0.0, "completed race persists melted snow")
	game.car_weathering.dirt_amount = 0.92
	game.queue_free()
	await process_frame
	check(VehicleCondition.read(records, "compact").dirt == 0.92, "abandoned race saves before next menu")

func garage() -> void:
	root.size = Vector2i(1280, 720)
	VehicleCatalog.selected = "compact"
	var page := GaragePage.new()
	page.records = records
	page.circuit_title = "CIRCUIT / 5 LAPS"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	var view: CarShowroom = page.showroom
	view.set_process(false)
	view.yaw = -PI * 0.5
	view.elevation = 0.12
	view.set_zoom(0.85)
	check(view.weathering.snapshot() == VehicleCondition.read(records, "compact"), "garage displays raced condition")
	page.open_car(0)
	page._show_section("care")
	await settle()
	page._toggle_wash()
	check(view.wash_mode and page.wash_button.text == "Done", "explicit wash mode")
	var target: Vector3 = Vector3(-0.9, 0.50, 0.1)
	var pixel: Vector2 = view.camera.unproject_position(view.car.body.global_transform * target) * view.size / Vector2(view.showroom_viewport.size)
	check(view.pick_body_point(pixel) != null, "ray hits actual door mesh")
	check(view.pick_body_point(Vector2(-100, -100)) == null, "missed car cannot wash")
	var mask: PackedByteArray = view.weathering.wash_image.get_data()
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	motion.relative = Vector2(12, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	var yaw: float = view.yaw
	view.gui_input.emit(motion)
	check(view.yaw == yaw, "wash drag does not orbit")
	var dirty_image: Image
	if DisplayServer.get_name() != "headless":
		view.wash_pointer_valid = false
		await settle()
		dirty_image = root.get_texture().get_image()
	if DisplayServer.get_name() != "headless": await capture("garage-dirty", page)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pixel
	press.pressed = true
	view.gui_input.emit(press)
	for i: int in range(40): view._process(0.05)
	check(view.weathering.wash_image.get_data() != mask, "held mouse wash cleans real hit")
	if DisplayServer.get_name() != "headless":
		view.wash_pointer_valid = false
		await settle()
		var washed_image: Image = root.get_texture().get_image()
		var actual: Vector2i = Vector2i(view.get_global_rect().position + pixel)
		print("WASH_PIXEL: ", actual, " ", dirty_image.get_pixelv(actual), " -> ", washed_image.get_pixelv(actual))
		check(dirty_image.get_pixelv(actual).b < washed_image.get_pixelv(actual).b - 0.02, "washing visibly reveals original blue door paint")
		view.wash_pointer_valid = true
	if DisplayServer.get_name() != "headless": await capture("garage-partly-washed", page)
	press.pressed = false
	view.gui_input.emit(press)
	check(VehicleCondition.read(records, "compact") == view.weathering.snapshot(), "mouse release commits wash")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pixel
	touch.pressed = true
	view.gui_input.emit(touch)
	check(view.washing, "one finger washes")
	touch.index = 1
	touch.position = pixel + Vector2(80, 0)
	view.gui_input.emit(touch)
	check(not view.washing, "second finger switches to orbit")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = pixel + Vector2(100, 10)
	view.gui_input.emit(drag)
	check(view.yaw != yaw, "two fingers rotate in wash mode")
	touch.canceled = true
	view.gui_input.emit(touch)
	check(not view.washing and view.touches.is_empty(), "canceled touch stops washing")
	var newer: Dictionary = VehicleCondition.read(records, "compact")
	newer.dirt = 0.97
	check(VehicleCondition.save(records, "compact", newer) == OK, "newer local race state")
	page._save_condition()
	check(VehicleCondition.read(records, "compact").dirt == 0.97, "cached garage never overwrites newer condition")
	page._reset()
	check(view.weathering.dirt_amount == 0.97, "reset paint does not wash dirt")
	page.queue_free()
	await process_frame
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(VehicleCondition.read(reopened, "compact").dirt == 0.97, "garage exit retains local condition")

func capture(label: String, page: GaragePage) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, label + " screenshot")
	for dimensions: Vector2i in [Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(page.wash_button.get_global_rect()), "wash action fits " + str(dimensions.x))
		check(root.get_texture().get_image().save_png(output.path_join(label + "-" + str(dimensions.x) + ".png")) == OK, label + " responsive capture")
	root.size = Vector2i(1280, 720)
	await settle()

func loop_track() -> NativeTrack:
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = "desert"
	var point := Vector2(-28, -18)
	var heading: float = 0.0
	for kind: String in ["straight", "hairpin", "straight", "hairpin"]:
		var piece: Dictionary = RoadPieces.create(kind, point, heading)
		piece.length = 56.0 if kind == "straight" else 0.0
		piece.radius = 18.0
		document.pieces.append(piece)
		var pose: Dictionary = RoadPieces.end_pose(piece)
		point = pose.position
		heading = pose.heading
	document = RoadPieces.route_from_pieces(document).document
	document.start_line = {"position": [0.0, -18.0], "heading": 0.0}
	return TrackCompiler.compile(JSON.parse_string(JSON.stringify(document)))

func app_capture() -> void:
	var directory: String = records.path.get_base_dir()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage", true, false)
	page.open_car(0)
	page._show_section("care")
	await settle()
	var button: Button = app.root_ui.find_child("GarageWash", true, false)
	button.pressed.emit()
	var view: CarShowroom = app.root_ui.find_child("GarageShowroom", true, false)
	check(view.wash_mode, "real app enters Wash")
	var swipe: Node = app.root_ui.get_node("MenuPageSwipe")
	check(swipe._owns_gesture(app.root_ui, view.get_global_rect().get_center()), "wash owns gestures over menu paging")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(button.get_global_rect()), "real app Wash action fits " + str(dimensions.x))
		check(root.get_texture().get_image().save_png(output.path_join("garage-app-" + str(dimensions.x) + ".png")) == OK, "real app capture " + str(dimensions.x))
	app.queue_free()
	await process_frame
