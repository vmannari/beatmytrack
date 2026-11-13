extends SceneTree
## Compact the existing Hover proxy without changing any used corner.
func _initialize() -> void:
	var path: String = "res://assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res"
	var source: ArrayMesh = load(path)
	var arrays: Array = source.surface_get_arrays(0)
	var original: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var positions := PackedVector3Array()
	var remap: Dictionary = {}
	var mapped := PackedInt32Array()
	for vertex: int in indices:
		if not remap.has(vertex):
			remap[vertex] = positions.size()
			positions.append(original[vertex])
		mapped.append(remap[vertex])
	for corner: int in range(indices.size()): assert(original[indices[corner]]==positions[mapped[corner]])
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_INDEX] = mapped
	var compact := ArrayMesh.new()
	compact.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	compact.custom_aabb = source.get_aabb()
	assert(compact.get_faces()==source.get_faces())
	assert(ResourceSaver.save(compact,path,ResourceSaver.FLAG_COMPRESS)==OK)
	print("MODEL_HOVER_SHADOW vertices=",original.size(),"->",positions.size()," position_bytes_saved=",(original.size()-positions.size())*12)
	quit()
