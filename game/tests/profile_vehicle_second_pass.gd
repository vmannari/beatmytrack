extends SceneTree
var rows: Array=[]
func _initialize() -> void: run.call_deferred()
func indices_from(data: PackedByteArray, vertices: int) -> PackedInt32Array:
	var stride: int=2 if vertices<=65536 else 4
	var result:=PackedInt32Array();result.resize(data.size()/stride)
	for i: int in range(result.size()): result[i]=data.decode_u16(i*stride) if stride==2 else data.decode_u32(i*stride)
	return result
func reorder(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool:=SurfaceTool.new();tool.create_from(mesh,0);tool.optimize_indices_for_cache()
	var after: Array=tool.commit_to_arrays()
	assert(after[Mesh.ARRAY_VERTEX]==vertices)
	return after[Mesh.ARRAY_INDEX]
func misses(indices: PackedInt32Array, capacity: int) -> int:
	var cache: Array[int]=[];var count: int=0
	for value: int in indices:
		var found: int=cache.find(value)
		if found<0: count+=1
		else: cache.remove_at(found)
		cache.push_front(value)
		if cache.size()>capacity: cache.pop_back()
	return count
func run() -> void:
	var output: String="res://../docs/evidence/vehicle-simplification-pass2-2026-11-07/probe.json"
	for id: String in VehicleCatalog.IDS:
		var car:=CarVisual.new();car.vehicle_id=id;root.add_child(car)
		while not car.model_ready:await process_frame
		var old_misses: int=0;var new_misses: int=0;var lod_indices: int=0
		for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if not node.mesh is ArrayMesh:continue
			var stored: Array=node.mesh.get("_surfaces")
			for surface: int in range(stored.size()):
				var arrays: Array=node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var levels: Array=stored[surface].get("lods",[])
				for index: int in range(mini(levels.size()/2,2)):
					var raw: Variant=levels[index*2+1]
					var indices: PackedInt32Array=raw if raw is PackedInt32Array else indices_from(raw,vertices.size())
					assert(indices.size()%3==0)
					var after: PackedInt32Array=reorder(vertices,indices)
					old_misses+=misses(indices,16);new_misses+=misses(after,16);lod_indices+=indices.size()
		var original: ArrayMesh=PersonalGhost.mesh_for(car)
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		PersonalGhost._append_meshes(car,car.global_transform.affine_inverse(),tool)
		tool.generate_normals();tool.index()
		var indexed: ArrayMesh=tool.commit()
		var before: Array=original.surface_get_arrays(0);var after: Array=indexed.surface_get_arrays(0)
		var exact: bool=true
		for corner: int in range(before[Mesh.ARRAY_VERTEX].size()):
			var index: int=after[Mesh.ARRAY_INDEX][corner]
			if before[Mesh.ARRAY_VERTEX][corner]!=after[Mesh.ARRAY_VERTEX][index] or before[Mesh.ARRAY_NORMAL][corner]!=after[Mesh.ARRAY_NORMAL][index]:exact=false;break
		var old_bytes: int=before[Mesh.ARRAY_VERTEX].size()*24
		var new_bytes: int=after[Mesh.ARRAY_VERTEX].size()*24+after[Mesh.ARRAY_INDEX].size()*4
		var row: Dictionary={"vehicle":id,"lod_indices":lod_indices,"cache16_before":old_misses,"cache16_after":new_misses,"ghost_vertices_before":before[Mesh.ARRAY_VERTEX].size(),"ghost_vertices_after":after[Mesh.ARRAY_VERTEX].size(),"ghost_bytes_before":old_bytes,"ghost_bytes_after":new_bytes,"ghost_exact_corners":exact}
		rows.append(row);print("SECOND_PASS_PROBE ",JSON.stringify(row));car.free();await process_frame
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
