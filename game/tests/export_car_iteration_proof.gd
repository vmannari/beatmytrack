extends SceneTree
const WORK: String="res://../build/car-iteration-01-2026-11-15"
const OUT: String="res://../docs/evidence/car-iteration-01-2026-11-15"

func vertices(mesh: Mesh, surface: int) -> Array:
	var result: Array=[]
	for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: result.append([vertex.x,vertex.y,vertex.z])
	return result

func indices(mesh: Mesh, surface: int) -> Array:
	var arrays: Array=mesh.surface_get_arrays(surface)
	if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty(): return Array(arrays[Mesh.ARRAY_INDEX])
	var result: Array=[]
	for at: int in range(arrays[Mesh.ARRAY_VERTEX].size()): result.append(at)
	return result

func attributes(mesh: Mesh, surface: int) -> Array:
	var packet: Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
	var count: int=packet.vertex_count
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(packet.format,count)
	var ns: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(packet.format,count)
	var ats: int=RenderingServer.mesh_surface_get_format_attribute_stride(packet.format,count)
	var result: Array=[]
	for at: int in range(count):
		var data: PackedByteArray=packet.vertex_data.slice(at*ps,(at+1)*ps)
		if ns: data.append_array(packet.vertex_data.slice(count*ps+at*ns,count*ps+(at+1)*ns))
		if ats: data.append_array(packet.attribute_data.slice(at*ats,(at+1)*ats))
		result.append(data.hex_encode())
	return result

func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	var result: Dictionary={}
	for key: String in plan.parts:
		var source: Mesh=catalog[key].source
		var candidate: Mesh=load(WORK.path_join("candidates").path_join(key+".res"))
		var surfaces: Array=[]
		for surface: int in range(source.get_surface_count()): surfaces.append({"before":vertices(source,surface),"after":vertices(candidate,surface),"before_indices":indices(source,surface),"after_indices":indices(candidate,surface),"before_attributes":attributes(source,surface),"after_attributes":attributes(candidate,surface)})
		result[key]=surfaces
	FileAccess.open(WORK.path_join("proof-geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("ITERATION_PROOF_EXPORT ",result.size());quit()
