extends SceneTree
const WORK: String="res://../build/volt-reflection-smoothing-2026-11-15"
const OUT: String="res://../docs/evidence/volt-reflection-smoothing-2026-11-15"
const G=preload("res://tests/support/volt_smooth_geometry.gd")
const D=preload("res://vehicle/car_detail_reduction.gd")
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var parts: Dictionary={}
	var field: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("smooth-field.json")))
	for label: String in catalog:
		if label in ["ReferenceRear"]:continue
		var row: Dictionary=catalog[label]
		var base: ArrayMesh=row.native
		var mesh:=ArrayMesh.new()
		var arrays: Array=base.surface_get_arrays(0)
		var normals:=PackedVector3Array()
		for value: Array in field[label]:normals.append(Vector3(value[0],value[1],value[2]))
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		for at: int in range(normals.size()):
			var axis:=Vector3(tangents[at*4],tangents[at*4+1],tangents[at*4+2])
			axis=(axis-normals[at]*axis.dot(normals[at])).normalized()
			assert(axis.length_squared()>0.99)
			tangents[at*4]=axis.x;tangents[at*4+1]=axis.y;tangents[at*4+2]=axis.z
		arrays[Mesh.ARRAY_TANGENT]=tangents
		arrays[Mesh.ARRAY_NORMAL]=normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		for key: StringName in row.current.get_meta_list():mesh.set_meta(key,row.current.get_meta(key))
		mesh.custom_aabb=row.current.get_aabb()
		var file: String=label+".res"
		assert(ResourceSaver.save(mesh,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts["electric_"+D.mesh_key(row.current)]={"file":file,"name":label,"before":row.current.get_faces().size()/3,"after":mesh.get_faces().size()/3}
		print("VSR_CANDIDATE ",label," ",row.current.get_faces().size()/3," -> ",mesh.get_faces().size()/3)
	FileAccess.open(OUT.path_join("selected-plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"parts":parts},"  "));quit()
