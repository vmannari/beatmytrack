extends SceneTree
func _initialize() -> void: restore.call_deferred()
func restore() -> void:
	var sim_script: GDScript = load("res://vehicle/vehicle_simulation.gd") as GDScript
	sim_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/electric-turn-radius-2026-10-25/before/game__vehicle__vehicle_simulation.gd")
	if sim_script.reload(true) != OK: quit(2); return
	var config: HandlingConfig = load("res://resources/cars/electric.tres") as HandlingConfig
	var old: HandlingConfig = load("res://../docs/evidence/electric-turn-radius-2026-10-25/before/game__resources__cars__electric.tres") as HandlingConfig
	for property: Dictionary in old.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_EDITOR:
			config.set(property.name,old.get(property.name))
	for name: String in ["test_electric_low_speed_steering","test_electric_launch_drift"]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/electric-turn-radius-2026-10-25/before/game__tests__"+name+".gd")
		script.source_code = script.source_code.replace("VehicleSimulation.PHYSICS_VERSION",'load("res://vehicle/vehicle_simulation.gd").get_script_constant_map()["PHYSICS_VERSION"]')
		if script.reload() != OK: quit(3); return
		print("RESTORE_IDENTITY ",config.version," ",sim_script.get_script_constant_map().get("PHYSICS_VERSION")," GLOBAL ",VehicleSimulation.PHYSICS_VERSION)
		var suite: SceneTree = script.new()
		suite.run()
		suite.free()
	quit()
