extends SceneTree
## Finalise immutable recipe resources; ordered geometry bytes stay exact.
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const WORK: String="res://../build/car-detail-reduction-2026-11-14/material-stage"
const OUT: String="res://../docs/evidence/car-detail-reduction-2026-11-14/material-finalisation.json"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK))
	var rows: Array=[]
	for file: String in DirAccess.get_files_at(Detail.ROOT):
		if not file.ends_with(".res"): continue
		var path: String=Detail.ROOT.path_join(file)
		var mesh: ArrayMesh=load(path)
		var before: String=Detail.mesh_key(mesh)
		var packets: Array=mesh.get("_surfaces").duplicate(true)
		var missing: int=0
		for surface: int in range(mesh.get_surface_count()):
			if mesh.surface_get_material(surface)==null: missing+=1
			mesh.surface_set_material(surface,StandardMaterial3D.new())
		var exact: bool=true
		for surface: int in range(packets.size()):
			var after: Dictionary=mesh.get("_surfaces")[surface].duplicate()
			var original: Dictionary=packets[surface].duplicate()
			after.erase("material");original.erase("material")
			exact=exact and var_to_bytes(after)==var_to_bytes(original)
		assert(exact)
		assert(ResourceSaver.save(mesh,WORK.path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		rows.append({"file":file,"source_sha256":FileAccess.get_sha256(path),"geometry_key":before,"exact_geometry":exact,"missing_intrinsic_materials":missing,"staged_sha256":FileAccess.get_sha256(WORK.path_join(file))})
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("DETAIL_MATERIAL_FINALISE ",rows.size()," exact geometry resources")
	quit()
