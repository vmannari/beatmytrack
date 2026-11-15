extends SceneTree
const WORK: String="res://../build/car-step10-2026-11-15"
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("volt-clearance")))
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("volt-fix-staged.json")))
	var files: Dictionary={}
	for row: Dictionary in plan.rows:
		var path: String="res://"+plan.files[row.file].trim_prefix("game/")
		var original: ArrayMesh=load(path)
		var mesh:=ArrayMesh.new()
		var side: float=-1.0 if "-1_0" in row.name.replace(".","_") else 1.0
		for surface: int in range(original.get_surface_count()):
			var arrays: Array=original.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for at: int in range(points.size()):points[at].x+=side*0.00025
			arrays[Mesh.ARRAY_VERTEX]=points
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		for property: StringName in original.get_meta_list():mesh.set_meta(property,original.get_meta(property))
		mesh.set_meta("volt_contour_clearance",0.00105)
		assert(mesh.get_faces().size()==original.get_faces().size())
		assert(ResourceSaver.save(mesh,WORK.path_join("volt-clearance").path_join(row.file),ResourceSaver.FLAG_COMPRESS)==OK)
		files[row.file]=plan.files[row.file]
	FileAccess.open(OUT.path_join("volt-clearance-staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"lift_m":0.00025},"  "))
	print("VOLT_CLEARANCE_STAGE ",files.size());quit()
