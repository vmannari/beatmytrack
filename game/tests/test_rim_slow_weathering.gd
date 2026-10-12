extends "res://tests/test_vehicle_weathering.gd"
## Actual exposure, independent local persistence and spinning/washable rims.
func _initialize() -> void: verify.call_deferred()

func verify() -> void:
	OS.set_environment("BMT_API_URL", "")
	var directory: String = "user://rim_slow_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		for theme: String in ["desert", "pine", "winter"]:
			var effect := VehicleWeathering.new()
			effect.configure(car, theme, VehicleCatalog.config(id))
			var wheels: Array = []
			for binding: Dictionary in effect.bindings:
				if binding.wheel: wheels.append(binding)
			check(effect._wheel_frames.size() == 4 and wheels.size() >= 4, id + " four real rim sets")
			var state := VehicleState.new()
			state.velocity = Vector2(0, 20)
			expose(effect, state, soil(theme, 1 if theme == "pine" else 0), 30.0)
			var fast: float = effect.snow_amount if theme == "winter" else effect.dirt_amount
			var slow: float = effect.slow_snow_amount if theme == "winter" else effect.slow_dirt_amount
			check(fast > 0.1 and slow > 0.0 and absf(log(1.0-slow)/log(1.0-fast)-0.05) < 0.00000001, id + " " + theme + " exactly 1/20 exposure rate")
			var snapshot: Array = state.snapshot().duplicate(true)
			state.tick += 120
			effect.present(state, soil(theme, 1), true)
			check(state.snapshot().slice(0,9) == snapshot.slice(0,9) and (effect.slow_snow_amount if theme == "winter" else effect.slow_dirt_amount) == slow, "blocked exposure leaves slow layer and canonical motion exact")
			var rim: Dictionary = wheels[0]
			var transform: Transform3D = rim.wash_transform
			var local := Vector3(0.05, 0.02, 0.01)
			var clean_point: Vector3 = effect.wash_point(rim.node, local)
			car.rolling_wheels[0].rotation.x += 1.3
			check(effect.wash_point(rim.node, local).is_equal_approx(clean_point) and clean_point.is_equal_approx(transform*local), "rim wash coordinates follow the spinning mesh")
			var point: Vector3 = car.wheel_rest_positions[0]
			var primary_before: PackedByteArray = effect.wash_image.get_data()
			var slow_before: PackedByteArray = effect.slow_wash_image.get_data()
			effect.wash(point, 0.6)
			check(effect.wash_image.get_data() != primary_before and effect.slow_wash_image.get_data() != slow_before, "rim washing clears both layers")
			check(effect._slow_mask_travel == 0.0, "fresh washing clears pre-wash coating debt")
			expose(effect, state, soil(theme, 1 if theme == "pine" else 0), 0.1)
			check(effect._slow_mask_travel > 0.0, "short post-wash driving earns a pending slow remainder")
			var saved: Dictionary = effect.snapshot()
			check(VehicleCondition.valid_collection({id: saved}) and VehicleCondition.save(records, id, saved) == OK, "new local condition saves with both volumes")
			var reopened := LocalRecords.new(records.path)
			reopened.load_records()
			var recovered: Dictionary = VehicleCondition.read(reopened, id)
			check(recovered.slow_wash == saved.slow_wash and absf(float(recovered.slow_dirt)-saved.slow_dirt) < 1e-9 and absf(float(recovered.slow_snow)-saved.slow_snow) < 1e-9, "slow exposure and wash volume survive restart")
			check(absf(float(recovered.slow_recoat)-saved.slow_recoat) < 1e-9, "pending slow re-coating survives short races and restart")
			var legacy: Dictionary = saved.duplicate(true)
			for field: String in ["slow_dirt", "slow_snow", "slow_wash", "slow_recoat", "grime_age", "grime_elapsed"]: legacy.erase(field)
			check(VehicleCondition.valid_collection({id: legacy}), "original eight-field local saves remain valid")
			effect.restore(legacy)
			check(effect.slow_dirt_amount == 0.0 and effect.slow_snow_amount == 0.0 and effect.snapshot().wash == legacy.wash, "legacy upgrade retains exact existing wash strokes without inventing slow dirt")
			var invalid: Dictionary = saved.duplicate(true)
			invalid.slow_dirt = INF
			check(not VehicleCondition.valid_collection({id: invalid}), "reject nonfinite slow exposure")
			effect.reset()
		car.queue_free()
		await process_frame
	if "--capture" in OS.get_cmdline_user_args(): await previews()
	print("RIM_SLOW_WEATHERING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func previews() -> void:
	output = "res://../docs/evidence/rim-slow-weathering-2026-10-11"
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 720)
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.yaw = -1.15
		view.elevation = 0.43
		view._orbit()
		for warm: int in range(60): await RenderingServer.frame_post_draw
		await create_timer(1.0).timeout
		var clean: Image = await save(id + "-clean")
		for theme: String in ["desert", "pine", "winter"]:
			view.weathering.configure(view.car, theme, VehicleCatalog.config(id))
			var state := VehicleState.new()
			state.velocity = Vector2(0, 20)
			var track: NativeTrack = soil(theme, 1 if theme == "pine" else 0)
			expose(view.weathering, state, track, 75.0)
			var dirty: Image = await save(id + "-" + theme + "-75s")
			if id == "compact" and theme == "pine":
				var pixel: Vector2 = view.camera.unproject_position(view.car.global_transform * view.car.wheel_rest_positions[0])
				check(view.wash_at(pixel, 0.8), "actual Garage picker washes the front rim")
				var washed: Image = await save("compact-pine-rim-washed")
				check(region_change(dirty, washed, Rect2i(Vector2i(pixel)-Vector2i(25,25),Vector2i(50,50))) > 0.015, "washing visibly removes rim dirt")
			if id == "compact" and theme == "desert":
				expose(view.weathering, state, track, 1425.0)
				await save("compact-desert-1500s")
			view.weathering.reset()
			var restored: Image = await save(id + "-" + theme + "-reset")
			check(clean.get_data() == restored.get_data(), id + " " + theme + " both layers/rims reset exactly")
		view.queue_free()
		await process_frame
