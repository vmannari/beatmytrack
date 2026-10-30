extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for name: String in ["compact_rear_design.gd","compact_detail.gd"]:
		var old: GDScript=load("res://vehicle/"+name)
		old.source_code=FileAccess.get_file_as_string("res://../build/native-shader-preparation-2026-10-28/before/game/vehicle/"+name)
		assert(old.reload(true)==OK)
	var old_cache: GDScript=load("res://ui/garage_car_cache.gd")
	old_cache.source_code=old_cache.source_code.replace("res://assets/garage/cars_v1/","res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/")
	old_cache.source_code=old_cache.source_code.replace('const DIRECTORY: String="res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/"','static var DIRECTORY: String=ProjectSettings.globalize_path("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/")')
	old_cache.source_code=old_cache.source_code.replace('result[file]=FileAccess.get_sha256("res://vehicle/"+file)', 'result[file]=FileAccess.get_sha256("res://vehicle/"+file)\n\t\t\tif file in ["compact_rear_design.gd","compact_detail.gd"]: result[file]=FileAccess.get_sha256("res://../build/native-shader-preparation-2026-10-28/before/game/vehicle/"+file)')
	assert(old_cache.reload(true)==OK)
	if ResourceLoader.exists("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/compact.scn"):
		var holder: Node3D=load("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/compact.scn").instantiate()
		assert(old_cache.geometry_sources()==holder.get_meta("garage_rest").sources,"Baseline control templates retain the exact loaded frozen builders and current unchanged authors")
		holder.free()

	var task_config:=ConfigFile.new();task_config.set_value("backend","url","");assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

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
