extends SceneTree
func _initialize() -> void:
	var work: String="res://../build/car-pass12-2026-11-16/staged"
	var stage: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/car-pass12-2026-11-16/staged.json"))
	var detail=preload("res://vehicle/car_detail_reduction.gd")
	for name: String in stage.files:
		if not name.begins_with("hover_"):continue
		var source: ArrayMesh=load("res://"+str(stage.files[name]).trim_prefix("game/"))
		var mesh: ArrayMesh=load(work.path_join(name))
		mesh.set_meta("car_pass12_source","hovercraft_"+detail.mesh_key(source))
		assert(ResourceSaver.save(mesh,work.path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
	print("CP2_HOVER_MARKERS exact original GPU bindings recorded");quit()
