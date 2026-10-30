extends SceneTree
func _initialize() -> void:
	var cache=load("res://ui/garage_car_cache.gd")
	var live: Dictionary=cache.geometry_sources()
	var result: Dictionary={}
	for id: String in VehicleCatalog.IDS:
		var holder: Node3D=load("res://assets/garage/cars_v1/"+id+".scn").instantiate()
		var old: Dictionary=holder.get_meta("garage_rest").sources
		var differences: Dictionary={}
		for name: String in live:
			if old.get(name)!=live[name]: differences[name]={"template":old.get(name),"live":live[name]}
		result[id]=differences;holder.free()
	print("TEMPLATE_SOURCE_DIFFERENCES ",JSON.stringify(result))
	quit()
