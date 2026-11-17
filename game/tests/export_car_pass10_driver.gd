extends SceneTree
const WORK: String="res://../build/car-pass10-2026-11-16"
const PATH: String="res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res"
func vectors(points: PackedVector3Array) -> Array:
	var result: Array=[]
	for p: Vector3 in points:result.append([p.x,p.y,p.z])
	return result
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	var source: ArrayMesh=load(PATH);var geometry: Array=[];var options: Array=[]
	for surface: int in range(source.get_surface_count()):
		var shapes: Array=[vectors(source.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])]
		var normal_poses: Array=[vectors(source.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL])]
		for shape: Array in source.surface_get_blend_shape_arrays(surface):
			shapes.append(vectors(shape[Mesh.ARRAY_VERTEX]));normal_poses.append(vectors(shape[Mesh.ARRAY_NORMAL]))
		var uv: Array=[]
		for p: Vector2 in source.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]:uv.append([p.x,p.y])
		geometry.append({"poses":shapes,"normal_poses":normal_poses,"uv":uv,"indices":Array(source.surface_get_arrays(surface)[Mesh.ARRAY_INDEX])})
	for ratio: float in [1.0,0.98,0.96,0.94,0.92,0.90]:
		var packets: Array=source.get("_surfaces").duplicate(true);var chosen: Array=[];var before: int=0;var after: int=0
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface);var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];before+=indices.size()/3
			var tool:=SurfaceTool.new();tool.create_from_arrays(arrays)
			var reduced: PackedInt32Array=indices if ratio==1.0 else tool.generate_lod(0.001,int(indices.size()*ratio)/3*3)
			if reduced.is_empty():reduced=indices
			var stride: int=2 if int(packets[surface].vertex_count)<=65536 else 4;var bytes:=PackedByteArray();bytes.resize(reduced.size()*stride)
			for i: int in range(reduced.size()):
				if stride==2:bytes.encode_u16(i*stride,reduced[i])
				else:bytes.encode_u32(i*stride,reduced[i])
			packets[surface].index_data=bytes;packets[surface].index_count=reduced.size();chosen.append(Array(reduced));after+=reduced.size()/3
		var result:=ArrayMesh.new();result.blend_shape_mode=source.blend_shape_mode
		for i: int in range(source.get_blend_shape_count()):result.add_blend_shape(source.get_blend_shape_name(i))
		result.set("_surfaces",packets);result.custom_aabb=source.get_aabb()
		for property: StringName in source.get_meta_list():result.set_meta(property,source.get_meta(property))
		var file: String="driver_"+str(ratio)+".res";assert(ResourceSaver.save(result,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		options.append({"ratio":ratio,"file":file,"before":before,"after":after,"indices":chosen})
	FileAccess.open(WORK.path_join("driver-candidates.json"),FileAccess.WRITE).store_string(JSON.stringify({"source":PATH,"geometry":geometry,"options":options}))
	print("CP3_DRIVER_CANDIDATES ",options.map(func(row: Dictionary) -> Array:return [row.ratio,row.before,row.after]));quit()
