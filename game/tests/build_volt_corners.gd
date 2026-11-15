extends SceneTree
const WORK: String="res://../build/volt-rear-corners-2026-11-15"
const OUT: String="res://../docs/evidence/volt-rear-corners-2026-11-15"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var parts: Dictionary={}
	for label: String in ["ReferenceSide-1_0","ReferenceSide1_0"]:
		var row: Dictionary=catalog[label]
		var mesh: ArrayMesh=preload("res://tests/support/volt_corner_geometry.gd").side(row.current,row.native)
		var file: String=label+".res"
		assert(ResourceSaver.save(mesh,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		var key: String="electric_"+preload("res://vehicle/car_detail_reduction.gd").mesh_key(row.current)
		parts[key]={"file":file,"name":label,"before":row.current.get_faces().size()/3,"after":mesh.get_faces().size()/3}
		print("VOLT_REAR_CANDIDATE ",label," ",row.current.get_faces().size()/3," -> ",mesh.get_faces().size()/3)
	FileAccess.open(OUT.path_join("selected-plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"parts":parts},"  "));quit()
