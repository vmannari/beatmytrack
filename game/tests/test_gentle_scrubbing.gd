extends "res://tests/test_vehicle_weathering.gd"
## Actual brush splitting, bounded age resistance and saved per-patch grime.
func _initialize() -> void: verify.call_deferred()

func make_effect(car: CarVisual, aged: bool = false) -> VehicleWeathering:
	var effect := VehicleWeathering.new()
	effect.configure(car, "pine", VehicleCatalog.config(car.vehicle_id))
	effect.dirt_amount = 0.85
	effect.slow_dirt_amount = 0.3
	effect.mud_amount = 1.0
	effect.deposit_color = VehicleWeathering.COLORS.pine
	if aged: effect.grime_age.fill(255)
	effect._update_finish()
	return effect

func peak(bytes: PackedByteArray) -> int:
	var result: int = 0
	for value: int in bytes: result = maxi(result, value)
	return result

func verify() -> void:
	OS.set_environment("BMT_API_URL", "")
	var directory: String = "user://gentle_scrub_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var fresh: VehicleWeathering = make_effect(car)
		var point: Vector3 = fresh.bounds.position + fresh.bounds.size * Vector3(1, 0.25, 0.6)
		fresh.wash(point, 0.2)
		var one_pass: PackedByteArray = fresh.wash_image.get_data()
		check(peak(one_pass) > 0 and peak(one_pass) < 60, id + " one quick swipe leaves dirt")
		fresh.reset()
		var split: VehicleWeathering = make_effect(car)
		for sample: int in range(100): split.wash(point, 0.002)
		check(split.wash_image.get_data() == one_pass, id + " many tiny brush samples cannot inflate cleaning")
		split.reset()
		fresh = make_effect(car)
		fresh.wash(point, 0.8)
		var fresh_progress: int = peak(fresh.wash_image.get_data())
		fresh.reset()
		var aged: VehicleWeathering = make_effect(car, true)
		aged.wash(point, 0.8)
		var aged_progress: int = peak(aged.wash_image.get_data())
		check(aged_progress > 0 and aged_progress < fresh_progress and float(fresh_progress)/aged_progress < 1.45, "old dirt takes a little more effort, capped")
		for pass_index: int in range(20): aged.wash(point, 0.2)
		check(peak(aged.wash_image.get_data()) == 255, "repeated modest scrubbing comfortably finishes")
		var clean_cells: int = 0
		var remaining_old: int = 0
		for index: int in range(VehicleCondition.CELLS):
			if aged.wash_image.get_data()[index] == 255:
				clean_cells += 1
				check(aged.grime_age[index] == 0, "cleaned patch starts soft again")
			elif aged.grime_age[index] == 255: remaining_old += 1
		check(clean_cells > 0 and remaining_old > 0, "cleaning one patch does not reset all old dirt")
		var saved: Dictionary = aged.snapshot()
		check(VehicleCondition.save(records, id, saved) == OK, "save dirt age and partial scrubbing")
		var reopened := LocalRecords.new(records.path)
		reopened.load_records()
		var recovered: Dictionary = VehicleCondition.read(reopened, id)
		check(recovered.grime_age == saved.grime_age and recovered.wash == saved.wash, "reboot retains exact age and wash progress")
		var legacy: Dictionary = saved.duplicate(true)
		legacy.erase("grime_age")
		legacy.erase("grime_elapsed")
		check(VehicleCondition.valid_collection({id: legacy}), "previous twelve-field conditions remain valid")
		aged.restore(legacy)
		check(peak(aged.grime_age) == 0 and aged.snapshot().wash == legacy.wash, "old saves retain strokes and start with gentle age")
		aged.reset()
		var dirty: VehicleWeathering = make_effect(car)
		var state := VehicleState.new()
		state.velocity = Vector2(0, 20)
		expose(dirty, state, soil("pine", 1), 900.0)
		check(peak(dirty.grime_age) == 255, "driving old dirt reaches bounded maximum age")
		var old_age: PackedByteArray = dirty.grime_age.duplicate()
		expose(dirty, state, soil("pine", 1), 10.0, 2, true)
		check(dirty.grime_age == old_age, "pause cannot age grime")
		dirty.reset()
		car.queue_free()
		await process_frame
	if "--capture" in OS.get_cmdline_user_args(): await preview()
	print("GENTLE_SCRUBBING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func preview() -> void:
	output = "res://../docs/evidence/gentle-scrubbing-2026-10-11"
	if RenderingServer.get_current_rendering_method() == "mobile": output += "/mobile"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 720)
	var view := CarShowroom.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	view.set_process(false)
	view.yaw = -PI * 0.5
	view.elevation = 0.16
	view._orbit()
	for warm: int in range(60): await RenderingServer.frame_post_draw
	await create_timer(1.0).timeout
	for label: String in ["fresh", "aged"]:
		view.weathering.dirt_amount = 0.85
		view.weathering.slow_dirt_amount = 0.3
		view.weathering.mud_amount = 1.0
		view.weathering.grime_age.fill(255 if label == "aged" else 0)
		view.weathering._update_finish()
		var pixel: Vector2 = view.camera.unproject_position(view.car.body.global_transform * Vector3(-0.9, 0.65, 0.1))
		await save(label + "-dirty")
		check(view.wash_at(pixel, 0.2), "actual surface brush hits door")
		await save(label + "-one-pass")
		for pass_index: int in range(4): view.wash_at(pixel, 0.2)
		await save(label + "-five-passes")
		for pass_index: int in range(15): view.wash_at(pixel, 0.2)
		await save(label + "-finished")
		view.weathering.reset()
		view.weathering.configure(view.car, "pine", VehicleCatalog.config("compact"))
	view.queue_free()
	await process_frame
