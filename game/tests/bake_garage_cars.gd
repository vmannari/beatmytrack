extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache=preload("res://ui/garage_car_cache.gd")
	cache.enabled=false
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	var lods = preload("res://tests/support/garage_mesh_lods.gd").new()
	var only_vehicle: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only_vehicle=argument.trim_prefix("--vehicle=")
	assert(only_vehicle.is_empty() or only_vehicle in VehicleCatalog.IDS)
	for id: String in VehicleCatalog.IDS:
		if VehicleCatalog.model_id(id) != id: continue # Shared chassis is baked once.
		if not only_vehicle.is_empty() and id!=only_vehicle: continue
		preload("res://vehicle/prepared_car_cache.gd").enabled=false
		var car:=CarVisual.new()
		car.vehicle_id=id
		car.simple_model=false # Standard exterior references used by wash eligibility.
		car.livery=VehicleLivery.defaults(id)
		car.editable_kits=VehicleCustomisation.supported(id)
		root.add_child(car)
		while not car.model_ready: await process_frame
		# Modular restoration also needs an owned rest snapshot for this bake.
		preload("res://vehicle/prepared_car_cache.gd").enabled=true
		preload("res://vehicle/prepared_car_cache.gd").remember(car)
		lods.remember(cache.DIRECTORY+id+".scn")
		var error: Error=cache.bake(car)
		if error == OK: error = lods.bake(cache.DIRECTORY+id+".scn")
		if error == OK: error = preload("res://tests/support/car_model_buffers.gd").bake(cache.DIRECTORY+id+".scn",id)
		print("GARAGE_CAR_BAKE ",id," ",error)
		car.free()
		if error!=OK: quit(1);return
	quit()
