extends SceneTree
const OUT: String = "res://../docs/evidence/vehicle-weathering-2026-10-11"
var checks: int = 0
var failures: int = 0
var output: String = OUT
var render_counts: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func soil(theme: String, cell: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.metadata = {"theme": theme}
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500, 500)
	track.cells.resize(10000)
	track.cells.fill(cell)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	return track

func expose(effect: VehicleWeathering, state: VehicleState, track: NativeTrack, seconds: float, stride: int = 2, blocked: bool = false) -> void:
	effect.present(state, track, blocked)
	for i: int in range(roundi(seconds * 120.0 / stride)):
		state.tick += stride
		effect.present(state, track, blocked)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var livery_before: Dictionary = car.livery.duplicate(true)
		var original_paint: Color = car.paint_materials.body.albedo_color
		for biome: String in VehicleWeathering.COLORS:
			var effect := VehicleWeathering.new()
			effect.configure(car, biome, VehicleCatalog.config(id))
			check(effect.bindings.size() > 0 and effect.materials.size() > 0, id + " " + biome + " painted surfaces")
			check(not effect.installed and effect.amount == 0.0, "clean original materials at start")
			var state := VehicleState.new()
			state.velocity = Vector2(0, 20)
			var track: NativeTrack = soil(biome, 0)
			expose(effect, state, track, 10.0)
			if biome in ["pine", "night_city"]: check(effect.amount == 0.0 and not effect.installed, biome + " road stays mud-free")
			else: check(effect.amount > 0.1 and effect.installed, biome + " gradual road buildup")
			track.cells.fill(1)
			expose(effect, state, track, 20.0)
			check(effect.amount > 0.1, biome + " driving coats paint")
			if biome in ["pine", "night_city"]:
				var dirty: float = effect.amount
				track.cells.fill(0)
				expose(effect, state, track, 10.0)
				check(effect.amount == dirty, biome + " deposited mud persists on road without growing")
				track.cells.fill(1)
				state.track_elevated = true
				expose(effect, state, track, 10.0)
				check(effect.amount == dirty, biome + " grass below bridge does not muddy car")
				state.track_elevated = false
			var snapshot: Array = state.snapshot().duplicate(true)
			var amount: float = effect.amount
			var wetness: float = effect.wetness
			effect.present(state, track, false)
			check(state.snapshot() == snapshot and effect.amount == amount, "redraw leaves state and exposure unchanged")
			expose(effect, state, track, 5.0, 2, true)
			check(effect.amount == amount and effect.wetness == wetness, "pause/countdown/finish blocked")
			state.tick -= 240
			effect.present(state, track, true)
			check(effect.amount == amount, "rewind preview leaves finish unchanged")
			state.velocity = Vector2.ZERO
			expose(effect, state, track, 5.0)
			check(effect.amount == amount, "parked wheels do not accumulate deposits")
			state.velocity = Vector2(0, 20)
			state.jump_height = 1.0
			expose(effect, state, track, 5.0)
			check(effect.amount == amount, "airborne wheels do not throw deposits")
			state.jump_height = 0.0
			state.roll_ticks = 30
			expose(effect, state, track, 5.0)
			check(effect.amount == amount, "rolled car does not throw deposits")
			check(car.livery == livery_before and car.paint_materials.body.albedo_color == original_paint, "original livery and paint retained")
			check(effect.materials[0].shader.code.find("ALPHA") == -1, "opaque finish retains dust/depth occlusion")
			effect.reset()
			check(effect.amount == 0.0 and effect.wetness == 0.0 and not effect.installed, "retry cleans car")
			for binding: Dictionary in effect.bindings:
				check(binding.node.get_active_material(binding.index) is StandardMaterial3D, "reset restores original material")
		var exposure: Array[float] = []
		for stride: int in [1, 2, 4]:
			var effect := VehicleWeathering.new()
			effect.configure(car, "desert", VehicleCatalog.config(id))
			var state := VehicleState.new()
			state.velocity = Vector2(0, 20)
			expose(effect, state, soil("desert", 0), 30.0, stride)
			exposure.append(effect.amount)
			effect.reset()
		check(absf(exposure[0] - exposure[1]) < 0.00001 and absf(exposure[0] - exposure[2]) < 0.00001, id + " equal accumulation at 30/60/120 presentation FPS")
		car.queue_free()
		await process_frame
	await integration()
	if "--capture" in OS.get_cmdline_user_args(): await captures()
	if "--capture-rear" in OS.get_cmdline_user_args(): await rear_captures()
	print("VEHICLE_WEATHERING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func loop_track(biome: String) -> NativeTrack:
	var document: Dictionary = TrackDocument.create_blank()
	document.theme = biome
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

func integration() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = loop_track("desert")
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.sim.state.velocity = Vector2(0, 20)
	game.call("_process", 0.0)
	game.sim.state.tick += 120
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	game.call("_process", 0.0)
	check(game.car_weathering.amount > 0.0 and game.car_weathering.installed, "actual Game updates finish")
	check(game.sim.state.snapshot() == snapshot, "actual race snapshot unchanged by finish")
	var amount: float = game.car_weathering.amount
	game.paused = true
	game.sim.state.tick += 120
	game.call("_process", 0.0)
	check(game.car_weathering.amount == amount, "actual Game pause freezes buildup")
	game.restart()
	check(game.car_weathering.amount == 0.0 and not game.car_weathering.installed, "actual restart cleans finish")
	game.native_track.metadata.theme = "winter"
	game.call("_update_weather")
	check(game.car_weathering.theme == "winter" and game.car_weathering.amount == 0.0, "actual biome change resets and selects finish")
	game.queue_free()
	await process_frame

func save(label: String) -> Image:
	for frame: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = root.get_texture().get_image()
	check(result.save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	render_counts.append({"label": label, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "triangles": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	return result

func captures() -> void:
	if RenderingServer.get_current_rendering_method() == "mobile": output = OUT + "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(960, 540)
	var view := CarShowroom.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.yaw = 1.15
	view.elevation = 0.33
	view._orbit()
	# Let the renderer prepare the cached studio radiance before freezing a
	# clean reference; material restoration must still compare exact pixels.
	for warm: int in range(60): await RenderingServer.frame_post_draw
	var clean: Image = await save("clean")
	var effect := VehicleWeathering.new()
	for biome: String in VehicleWeathering.COLORS:
		effect.configure(view.car, biome, VehicleCatalog.config("compact"))
		var track: NativeTrack = soil(biome, 1 if biome in ["pine", "night_city"] else 0)
		var state := VehicleState.new()
		state.velocity = Vector2(0, 20)
		expose(effect, state, track, 15.0)
		await save(biome + "-15s")
		expose(effect, state, track, 60.0)
		await save(biome + "-75s")
		if biome == "desert":
			view.yaw = PI * 0.5
			view.elevation = 0.20
			view._orbit()
			await save("desert-tire-spray-left")
			view.yaw = -PI * 0.5
			view._orbit()
			await save("desert-tire-spray-right")
			view.yaw = 1.15
			view.elevation = 0.33
			view._orbit()
		effect.reset()
		var restored: Image = await save(biome + "-reset")
		if clean.get_data() != restored.get_data():
			var changed: int = 0
			var maximum: float = 0.0
			for y: int in range(clean.get_height()):
				for x: int in range(clean.get_width()):
					var a: Color = clean.get_pixel(x, y)
					var b: Color = restored.get_pixel(x, y)
					if a != b:
						changed += 1
						maximum = maxf(maximum, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
			print("WEATHERING_RESET_PIXEL_DIFF: ", biome, " changed=", changed, " max=", maximum)
		check(clean.get_data() == restored.get_data(), biome + " retry is pixel-identical to original finish")
	view.queue_free()
	await process_frame
	for id: String in ["pickup", "classic", "formula", "kart"]:
		view = CarShowroom.new()
		view.vehicle_id = id
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.yaw = 1.15
		view.elevation = 0.33
		view._orbit()
		effect.configure(view.car, "winter", VehicleCatalog.config(id))
		var state := VehicleState.new()
		state.velocity = Vector2(0, 20)
		expose(effect, state, soil("winter", 0), 75.0)
		await save(id + "-winter")
		effect.reset()
		view.queue_free()
		await process_frame
	await gameplay_captures()
	var report := FileAccess.open(output.path_join("render-counts.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name(), "views": render_counts}, "\t"))
	report.close()

func gameplay_captures() -> void:
	for biome: String in VehicleWeathering.COLORS:
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = loop_track(biome)
		game.production_mode = true
		root.add_child(game)
		game.set_physics_process(false)
		game.set_process(false)
		game.paused = true
		game.countdown_ticks = 0
		game.countdown_label.hide()
		game.race_cues.hide()
		game.call("_process", 0.0)
		await save(biome + "-gameplay-clean")
		var observed := VehicleState.new()
		observed.velocity = Vector2(0, 20)
		expose(game.car_weathering, observed, soil(biome, 1 if biome in ["pine", "night_city"] else 0), 75.0)
		game.call("_process", 0.0)
		await save(biome + "-gameplay-coated")
		game.queue_free()
		await process_frame

func rear_captures() -> void:
	output = "res://../docs/evidence/rear-weathering-2026-10-11"
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(960, 540)
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.yaw = PI
		view.elevation = 0.27
		view._orbit()
		for warm: int in range(60): await RenderingServer.frame_post_draw
		var clean: Image = await save(id + "-rear-clean")
		var effect := VehicleWeathering.new()
		for biome: String in VehicleWeathering.COLORS:
			effect.configure(view.car, biome, VehicleCatalog.config(id))
			var state := VehicleState.new()
			state.velocity = Vector2(0, 20)
			expose(effect, state, soil(biome, 1 if biome in ["pine", "night_city"] else 0), 75.0)
			var coated: Image = await save(id + "-rear-" + biome)
			check(clean.get_data() != coated.get_data(), id + " " + biome + " rear visibly coated")
			effect.reset()
			var restored: Image = await save(id + "-rear-" + biome + "-reset")
			check(clean.get_data() == restored.get_data(), id + " " + biome + " rear reset pixel-exact")
		view.queue_free()
		await process_frame
	var report := FileAccess.open(output.path_join("render-counts.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "views": render_counts}, "\t"))
	report.close()
