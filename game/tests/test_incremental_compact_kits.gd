extends SceneTree
## Partial upgrades retain the actual car/tyres/pivots, paint and local wear.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func part_counts(frames: Array) -> Vector2i:
	var result := Vector2i.ZERO
	for frame: Node3D in frames:
		for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				result.x += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
				result.y += 1
	return result
func _run() -> void:
	var control := Control.new()
	root.add_child(control)
	var view := CarShowroom.new()
	view.garage_mode = true
	control.add_child(view)
	var car: CarVisual = view.car
	var body: Node3D = car.body
	var wheels: Array[Node3D] = car.rolling_wheels.duplicate()
	var paints: Dictionary = VehicleLivery.defaults("compact")
	paints.colors.body = "945848"
	view.apply_livery(paints)
	view.weathering.dirt_amount = 0.45
	view.weathering.slow_dirt_amount = 0.12
	view.weathering._update_finish()
	var condition: Dictionary = view.weathering.snapshot()
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var value: Dictionary = car.customisation.duplicate(true)
			value[category] = option[0]
			var unchanged: Dictionary = {}
			for other: String in VehicleCustomisation.CATEGORIES:
				if other!=category: unchanged[other] = car.kit_frames[other].duplicate()
			view.apply_customisation(value)
			check(view.car==car and car.body==body,"part selection retains original sprung body/car")
			check(car.rolling_wheels==wheels,"original rolling/steering pivots retained")
			for other: String in unchanged: check(car.kit_frames[other]==unchanged[other],"unselected parts retained "+other)
			check(view.weathering.snapshot()==condition,"dirty/washed condition retained")
			check(car.livery==paints and car.paint_materials.body.albedo_color.to_html(false)=="945848","paint retained")
			var fresh := CarVisual.new()
			fresh.editable_kits = true
			fresh.customisation = value
			root.add_child(fresh)
			check(part_counts(car.kit_frames[category]).x==part_counts(fresh.kit_frames[category]).x,"same fitted triangles as new car "+category+"/"+str(option[0]))
			fresh.queue_free()
			await process_frame
	view.apply_customisation(VehicleCustomisation.defaults())
	check(car.kit_frames.rims.size()==8,"four rim and four stationary brake frames remain bounded")
	check(view.weathering.snapshot()==condition,"reset retains local condition")
	control.queue_free()
	await process_frame
	print("INCREMENTAL_COMPACT_KITS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
