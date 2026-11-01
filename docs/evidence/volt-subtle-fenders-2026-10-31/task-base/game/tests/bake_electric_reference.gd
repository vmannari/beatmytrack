extends SceneTree
## Bake only the independently authored reference-based Electric geometry.
const M = preload("res://vehicle/electric_reference_mesh.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	M.use_baked = false
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		root.add_child(car)
		car.set_night_headlights(true)
		car.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(M.ASSET_ROOT))
	var entries: Array[Dictionary] = []
	for key: String in M.meshes:
		var mesh: ArrayMesh = M.meshes[key]
		var filename: String = key.sha256_text().left(24)+".res"
		assert(ResourceSaver.save(mesh,M.ASSET_ROOT.path_join(filename)) == OK)
		entries.append({"part":key,"file":filename,"triangles":mesh.get_faces().size()/3})
	var sources: Dictionary = {}
	for file: String in ["electric_car_model.gd","electric_reference_mesh.gd","electric_reference_body.gd","electric_reference_cabin.gd","electric_reference_details.gd"]:
		sources[file] = FileAccess.get_sha256("res://vehicle/"+file)
	var manifest := FileAccess.open(M.ASSET_ROOT.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"provenance":"Original reference-based Electric geometry", "sources":sources, "meshes":entries},"\t"))
	print("ELECTRIC_REFERENCE_BAKE: ",entries.size()," full/simple meshes")
	quit()
