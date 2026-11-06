extends SceneTree
## Offline header template bake. Revision must come from the build receipt.

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var revision: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--revision="): revision = argument.trim_prefix("--revision=")
	if revision.length()!=64 or not revision.is_valid_hex_number():
		push_error("A source-checked compact visual revision is required.")
		quit(1); return
	var car := CarVisual.new()
	car.vehicle_id = "compact"
	car.simple_model = true
	car.livery = VehicleLivery.defaults("compact")
	root.add_child(car)
	while not car.model_ready: await process_frame
	var error: Error = preload("res://ui/header_simple_cache.gd").bake(car,revision)
	print("HEADER_SIMPLE_BAKE: ",error)
	car.free()
	quit(0 if error == OK else 1)
