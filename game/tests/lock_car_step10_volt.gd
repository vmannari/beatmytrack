extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const WORK: String="res://../build/car-step10-2026-11-15"
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("volt-protected")))
	var inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("volt-publication.json"))).files
	var observations: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	for row: Dictionary in observations:
		if row.vehicle=="electric" and row.mode=="stock" and str(row.name).begins_with("ReferenceSide"):
			inputs["game/"+str(row.resource).trim_prefix("res://")]={}
	var files: Dictionary={}
	for relative: String in inputs:
		var path: String="res://"+relative.trim_prefix("game/")
		var original: ArrayMesh=load(path);var selected: ArrayMesh=original.duplicate()
		selected.set_meta("car_keep_master",true);selected.set_meta("car_authored_far",true);selected.set_meta("car_surface_guide_locked",true)
		assert(D.mesh_key(original)==D.mesh_key(selected),"Metadata protection preserves every original GPU byte")
		var name: String=path.get_file()
		assert(ResourceSaver.save(selected,WORK.path_join("volt-protected").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		files[name]=relative
	FileAccess.open(OUT.path_join("volt-lock-staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files},"  "))
	print("VOLT_MASTER_LOCK ",files.size()," exact master protections");quit()
