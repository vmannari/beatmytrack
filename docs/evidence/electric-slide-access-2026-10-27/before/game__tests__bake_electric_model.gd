extends SceneTree
const COACH = preload("res://vehicle/electric_coachwork.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	COACH.use_baked = false
	COACH.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		root.add_child(car)
		car.set_night_headlights(true)
		car.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COACH.ASSET_ROOT))
	var entries: Array[Dictionary] = []
	for key: String in COACH.meshes:
		var mesh: ArrayMesh = COACH.meshes[key]
		var name_value: String = key.sha256_text().left(24)+".res"
		assert(ResourceSaver.save(mesh,COACH.ASSET_ROOT.path_join(name_value)) == OK)
		entries.append({"part":key,"file":name_value,"triangles":mesh.get_faces().size()/3})
	var manifest := FileAccess.open(COACH.ASSET_ROOT.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"provenance":"Original authored Beat my track geometry; CompactFinish and CompactDetail tyre system reused.","source_sha256":FileAccess.get_sha256("res://vehicle/electric_coachwork.gd"),"model_sha256":FileAccess.get_sha256("res://vehicle/electric_car_model.gd"),"meshes":entries},"\t"))
	manifest.close()
	print("ELECTRIC_BAKE: ",entries.size()," authored full/simple mesh resources")
	quit()
