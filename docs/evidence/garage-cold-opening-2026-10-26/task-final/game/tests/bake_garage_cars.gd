extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache=preload("res://ui/garage_car_cache.gd")
	cache.enabled=false
	var only_vehicle: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only_vehicle=argument.trim_prefix("--vehicle=")
	assert(only_vehicle.is_empty() or only_vehicle in VehicleCatalog.IDS)
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id!=only_vehicle: continue
		var car:=CarVisual.new()
		car.vehicle_id=id
		car.livery=VehicleLivery.defaults(id)
		car.editable_kits=id=="compact"
		root.add_child(car)
		while not car.model_ready: await process_frame
		var error: Error=cache.bake(car)
		print("GARAGE_CAR_BAKE ",id," ",error)
		car.free()
		if error!=OK: quit(1);return
	quit()
