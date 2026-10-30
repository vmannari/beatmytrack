extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "compact"
	car.garage_template = true
	car.editable_kits = true
	world.add_child(car)
	while not car.model_ready: await process_frame
	var stage: Node3D = GarageEnvironment.build(world,car,false)
	var samples: Array[float] = []
	for i: int in range(20):
		car.reparent(world)
		stage.free()
		var start: int = Time.get_ticks_usec()
		stage = GarageEnvironment.build_pedestal(world,car)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	print("GARAGE_PEDESTAL ",JSON.stringify({"median_ms":samples[10],"p95_ms":samples[19],"samples":samples}))
	world.free()
	quit()
