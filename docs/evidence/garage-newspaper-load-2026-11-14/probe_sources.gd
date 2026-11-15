extends SceneTree
func _initialize() -> void:
	var bases = load("res://vehicle/modular_car_base.gd")
	var sources = load("res://vehicle/prepared_asset_sources.gd")
	var car := CarVisual.new()
	car.vehicle_id = "compact"
	car.customisation = VehicleCustomisation.defaults()
	var scene: PackedScene = load(bases.path_for(car))
	var holder: Node = scene.instantiate()
	var data: Dictionary = holder.get_meta("modular_car_base",{})
	var current: Dictionary = sources.runtime_hashes("compact")
	var stored: Dictionary = sources.runtime_projection(data.get("sources",{}))
	var differences: Array = []
	for path: String in current:
		if current[path] != stored.get(path): differences.append({"path":path,"live":current[path],"stored":stored.get(path)})
	print("PREPARED_SOURCE_DIAGNOSTIC ",JSON.stringify({"key_equal":data.get("key",[]) == bases.key_for(car),"sources_equal":current == stored,"differences":differences}))
	holder.free()
	car.free()
	quit()
