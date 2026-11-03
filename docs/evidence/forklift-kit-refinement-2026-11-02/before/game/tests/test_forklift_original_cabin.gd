extends "res://tests/test_modular_car_assets.gd"
## Compare stock body geometry and finishes against the exact task-start builder.

func run() -> void:
	Garage.enabled = false
	Base.enabled = false
	Rest.enabled = false
	Kits.enabled = false
	var legacy: GDScript = load("res://../docs/evidence/forklift-cabin-kits-2026-11-02/before/game/vehicle/forklift_model.gd")
	for simple: bool in [false,true]:
		var current: CarVisual = await raw_car(simple)
		var control: CarVisual = await raw_car(simple)
		control.graphics.restore_originals()
		control.remove_child(control.body)
		control.body.free()
		control.body = Node3D.new()
		control.add_child(control.body)
		legacy.build(control)
		if simple: RacingCarModels._reduce_primitives(control.body)
		# The model builder is compared before batching and livery overlays.
		current.graphics.restore_originals()
		var difference: Dictionary = TriangleCompare.compare(TriangleCompare.collect(control,[control.body]),TriangleCompare.collect(current,[current.body]))
		check(difference.unmatched_geometry == 0,"Original body triangle geometry retained simple="+str(simple))
		check(difference.unmatched_uv_color == 0,"Original body UVs retained simple="+str(simple))
		check(difference.max_normal_degrees <= 0.02,"Original body normals retained simple="+str(simple))
		print("FORKLIFT_ORIGINAL_DIFFERENCE ",JSON.stringify(difference))
		control.free()
		current.free()
	print("FORKLIFT_ORIGINAL_CABIN: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

func raw_car(simple: bool) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	car.simple_model = simple
	car.editable_kits = true
	car.batch_parts = false
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	return car
