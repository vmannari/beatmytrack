extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	var cache=preload("res://ui/garage_car_cache.gd")
	var sources: Dictionary=cache.geometry_sources()
	var rows: Array=[]
	for id: String in VehicleCatalog.IDS:
		var scene: PackedScene=load(cache.DIRECTORY+id+".scn")
		var holder: Node3D=scene.instantiate()
		var data: Dictionary=holder.get_meta("garage_rest",{})
		var differences: Array=[]
		for file: String in sources:
			if data.get("sources",{}).get(file)!=sources[file]:differences.append(file)
		rows.append({"vehicle":id,"sources_match":data.get("sources",{})==sources,"differences":differences})
		holder.free()
	print("GARAGE_SOURCE_ELIGIBILITY ",JSON.stringify({"editor_feature":OS.has_feature("editor"),"cars":rows}))
	quit()
