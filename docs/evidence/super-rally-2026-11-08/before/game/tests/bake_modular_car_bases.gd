extends SceneTree
## Offline generator; run after model source changes and before export.
const BASE = preload("res://vehicle/modular_car_base.gd")
const PREPARED = preload("res://vehicle/prepared_car_cache.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var lods = preload("res://vehicle/car_mesh_lods.gd").new()
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): only = argument.trim_prefix("--vehicle=")
	if not only.is_empty() and only not in VehicleCatalog.IDS:
		push_error("Unknown vehicle: "+only)
		quit(1)
		return
	# Force procedural construction even if another template exists. The
	# snapshot baker is independent of the bounded runtime cache.
	BASE.enabled = false
	PREPARED.enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for id: String in VehicleCatalog.IDS:
		if not only.is_empty() and only != id: continue
		for simple: bool in [false,true]:
			var edit_modes: Array[bool] = [false]
			if VehicleCustomisation.supported(id): edit_modes.append(true)
			for editable: bool in edit_modes:
				var car := CarVisual.new()
				car.vehicle_id = id
				car.livery = VehicleLivery.defaults(id)
				car.simple_model = simple
				car.editable_kits = editable
				root.add_child(car)
				while not car.model_ready: await process_frame
				BASE.enabled = true
				var error: Error = BASE.bake(car)
				if error == OK: error = lods.bake(BASE.path_for(car),id,0.5 if simple else 2.0)
				BASE.enabled = false
				print("MODULAR_BASE_BAKE ",id," simple=",simple," editable=",editable," error=",error)
				car.free()
				if error != OK:
					quit(1)
					return
	quit()
