extends RefCounted
## Offline only: conservative indices and raw encoded vertex compaction.
const Runtime = preload("res://vehicle/car_static_reduction.gd")
var lods = preload("res://vehicle/car_mesh_lods.gd").new()
var saved: Dictionary = {}
var observations: Array = []

func create(part: MeshInstance3D, id: String) -> Mesh:
	var source: ArrayMesh = part.mesh
	if id=="hovercraft" or not lods.eligible(part,id): return source
	if id=="compact" and str(part.name)=="ContinuousContour": return source
	var wheel: bool = false
	var ancestor: Node = part
	while ancestor!=null:
		if str(ancestor.name)=="WheelSpin": wheel=true
		ancestor=ancestor.get_parent()
	if id=="kart" and str(part.name)!="HelmetStatic" and not wheel: return source
	if id=="electric" and not wheel: return source
	var source_key: String = id+"_"+Runtime.key(source)
	if saved.has(source_key): return saved[source_key]
	var generated: Mesh = lods.prepare(source)
	var packets: Array = source.get("_surfaces").duplicate(true)
	var reduced: bool = false
	for surface: int in range(packets.size()):
		var packet: Dictionary = packets[surface]
		var levels: Array = generated.get("_surfaces")[surface].get("lods",[])
		var chosen: PackedByteArray = packet.get("index_data",PackedByteArray())
		var stride: int = 2 if int(packet.vertex_count)<=65536 else 4
		for at: int in range(0,levels.size(),2):
			if float(levels[at])<=0.001 and levels[at+1].size()<chosen.size(): chosen=levels[at+1]
		packet.erase("lods")
		if not chosen.is_empty() and chosen.size()/stride<int(packet.get("index_count",0)):
			packet.index_data=chosen
			packet.index_count=chosen.size()/stride
			reduced=true
	if not reduced:
		saved[source_key]=source
		return source
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.custom_aabb
	result.shadow_mesh=source.shadow_mesh
	result=compact(result)
	publish(source,result,id)
	saved[source_key]=result
	return result

func publish(source: ArrayMesh, result: ArrayMesh, id: String) -> void:
	var source_key: String = Runtime.key(source)
	result.set_meta("car_reduction_source",source_key)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Runtime.ROOT))
	var path: String = Runtime.ROOT.path_join(id+"_"+source_key+".res")
	assert(ResourceSaver.save(result,path,ResourceSaver.FLAG_COMPRESS)==OK)
	observations.append({"vehicle":id,"file":path,"before_triangles":source.get_faces().size()/3,"after_triangles":result.get_faces().size()/3,"authored_far":result.has_meta("car_authored_far")})
	print("STATIC_REDUCTION ",id," ",source.get_faces().size()/3," -> ",result.get_faces().size()/3)

func compact(source: ArrayMesh) -> ArrayMesh:
	var packets: Array = source.get("_surfaces").duplicate(true)
	for surface: int in range(packets.size()):
		var packet: Dictionary = packets[surface]
		var count: int = packet.vertex_count
		var format: int = source.surface_get_format(surface)
		if format&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES or format&Mesh.ARRAY_FORMAT_BONES: continue
		var old_indices: PackedByteArray = packet.get("index_data",PackedByteArray())
		if old_indices.is_empty(): continue
		var old_stride: int = old_indices.size()/int(packet.index_count)
		var levels: Array = packet.get("lods",[])
		var streams: Array = [old_indices]
		for at: int in range(1,levels.size(),2): streams.append(levels[at])
		var unique := PackedInt32Array()
		var remap: Dictionary = {}
		for stream: PackedByteArray in streams:
			for offset: int in range(0,stream.size(),old_stride):
				var old: int = stream.decode_u16(offset) if old_stride==2 else stream.decode_u32(offset)
				if not remap.has(old):
					remap[old]=unique.size()
					unique.append(old)
		var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var raw: PackedByteArray = packet.vertex_data
		var attributes: PackedByteArray = packet.get("attribute_data",PackedByteArray())
		assert(raw.size()==count*(ps+ns))
		var positions := PackedByteArray()
		var normals := PackedByteArray()
		var attrs := PackedByteArray()
		for old: int in unique:
			positions.append_array(raw.slice(old*ps,(old+1)*ps))
			if ns: normals.append_array(raw.slice(count*ps+old*ns,count*ps+(old+1)*ns))
			if ats: attrs.append_array(attributes.slice(old*ats,(old+1)*ats))
		positions.append_array(normals)
		packet.vertex_data=positions
		packet.vertex_count=unique.size()
		if ats: packet.attribute_data=attrs
		var stride: int = 2 if unique.size()<=65536 else 4
		var mapped: Array = []
		for stream: PackedByteArray in streams:
			var indices := PackedByteArray()
			indices.resize(stream.size()/old_stride*stride)
			for corner: int in range(stream.size()/old_stride):
				var old: int = stream.decode_u16(corner*old_stride) if old_stride==2 else stream.decode_u32(corner*old_stride)
				if stride==2: indices.encode_u16(corner*stride,remap[old])
				else: indices.encode_u32(corner*stride,remap[old])
			mapped.append(indices)
		packet.index_data=mapped[0]
		for index: int in range(1,mapped.size()): levels[index*2-1]=mapped[index]
		if not levels.is_empty(): packet.lods=levels
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb=source.custom_aabb
	result.shadow_mesh=source.shadow_mesh
	return result

func half_seam(source: ArrayMesh) -> ArrayMesh:
	var arrays: Array = source.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_VERTEX].size()==35)
	var old_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	for row: int in range(6):
		for column: int in [0,2]:
			var a: int = row*5+column
			for triangle: Array in [[a,a+2,a+7],[a,a+7,a+5]]:
				if old_indices[1]>old_indices[2]: triangle.reverse()
				for vertex: int in triangle: indices.append(vertex)
	arrays[Mesh.ARRAY_INDEX]=indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
