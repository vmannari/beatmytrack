extends SceneTree
const WORK: String="res://../build/car-mechanics-2026-11-17"
const OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"

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

func fields(mesh: Mesh, surface: int) -> Dictionary:
	var a: Array=mesh.surface_get_arrays(surface);var n: Array=[];var uv: Array=[];var uv2: Array=[];var colors: Array=[]
	if a[Mesh.ARRAY_NORMAL]!=null:
		for value: Vector3 in a[Mesh.ARRAY_NORMAL]: n.append([value.x,value.y,value.z])
	if a[Mesh.ARRAY_TEX_UV]!=null:
		for value: Vector2 in a[Mesh.ARRAY_TEX_UV]: uv.append([value.x,value.y])
	if a[Mesh.ARRAY_TEX_UV2]!=null:
		for value: Vector2 in a[Mesh.ARRAY_TEX_UV2]: uv2.append([value.x,value.y])
	if a[Mesh.ARRAY_COLOR]!=null:
		for value: Color in a[Mesh.ARRAY_COLOR]: colors.append([value.r,value.g,value.b,value.a])
	return {"normals":n,"uv":uv,"uv2":uv2,"colors":colors,"tangents":Array(a[Mesh.ARRAY_TANGENT]) if a[Mesh.ARRAY_TANGENT]!=null else []}

func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json")))
	var result: Dictionary={}
	for key: String in plan.parts:
		var source: Mesh=catalog[plan.parts[key].get("source_key",key)].source
		var candidate: Mesh=load(WORK.path_join("candidates").path_join(plan.parts[key].get("file",key+".res")))
		var surfaces: Array=[]
		for surface: int in range(source.get_surface_count()): surfaces.append({"before":vertices(source,surface),"after":vertices(candidate,surface),"before_indices":indices(source,surface),"after_indices":indices(candidate,surface),"before_attributes":attributes(source,surface),"after_attributes":attributes(candidate,surface),"after_fields":fields(candidate,surface)})
		result[key]={"surfaces":surfaces,"witnesses":candidate.get_meta("car_pass10_witnesses",[]),"contacts":candidate.get_meta("car_pass10_contacts",[]),"surface_contacts":candidate.get_meta("car_pass10_contact_surfaces",[])}
	FileAccess.open(WORK.path_join("proof-geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("ITERATION_PROOF_EXPORT ",result.size());quit()
