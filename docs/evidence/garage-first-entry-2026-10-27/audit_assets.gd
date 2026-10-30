extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache=preload("res://ui/garage_car_cache.gd")
	var current: Dictionary=cache.geometry_sources()
	for id: String in VehicleCatalog.IDS:
		var began: int=Time.get_ticks_usec()
		var holder: Node=load(cache.DIRECTORY+id+".scn").instantiate()
		var sources: Dictionary=holder.get_meta("garage_rest").sources
		var changed: Array=[]
		for file: String in current:
			if sources.get(file)!=current[file]: changed.append(file)
		print("ASSET_AUDIT ",id," changed=",changed," read_ms=",(Time.get_ticks_usec()-began)/1000.0)
		holder.free()
	quit()
