extends RefCounted
## Offline raw-record partition; all ten steering samples remain exact.
func save(source: ArrayMesh, directory: String) -> Dictionary:
	var split: Dictionary=split_driver(source)
	for item: Array in [["driver_steering.res",split.dynamic],["driver_static.res",split.static]]:
		var mesh: ArrayMesh=item[1]
		mesh.set_meta("kart_split_source_sha256",FileAccess.get_sha256(directory+"driver.res"))
		assert(ResourceSaver.save(mesh,directory+item[0],ResourceSaver.FLAG_COMPRESS)==OK)
	return split

func payload(mesh: ArrayMesh) -> int:
	var size: int=0
	for packet: Dictionary in mesh.get("_surfaces"):
		for field: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: size+=packet.get(field,PackedByteArray()).size()
	return size

func rebuild_packet(source: ArrayMesh, surface: int, corners: PackedInt32Array, morph: bool) -> Dictionary:
	var original: Dictionary = source.get("_surfaces")[surface]
	var packet: Dictionary = original.duplicate(true)
	var count: int = packet.vertex_count
	var format: int = source.surface_get_format(surface)
	var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var unique := PackedInt32Array()
	var remap: Dictionary = {}
	for old: int in corners:
		if not remap.has(old): remap[old]=unique.size(); unique.append(old)
	var streams: Array = [packet.vertex_data]
	var shapes: PackedByteArray = packet.get("blend_shapes",PackedByteArray())
	if morph:
		assert(shapes.size()==source.get_blend_shape_count()*count*(ps+ns))
		for pose: int in range(source.get_blend_shape_count()): streams.append(shapes.slice(pose*count*(ps+ns),(pose+1)*count*(ps+ns)))
	var replacements: Array = []
	for stream: PackedByteArray in streams:
		var positions := PackedByteArray()
		var normals := PackedByteArray()
		for old: int in unique:
			positions.append_array(stream.slice(old*ps,(old+1)*ps))
			normals.append_array(stream.slice(count*ps+old*ns,count*ps+(old+1)*ns))
		positions.append_array(normals)
		replacements.append(positions)
	packet.vertex_data=replacements[0]
	packet.vertex_count=unique.size()
	var attrs := PackedByteArray()
	var source_attrs: PackedByteArray = packet.get("attribute_data",PackedByteArray())
	for old: int in unique:
		if ats: attrs.append_array(source_attrs.slice(old*ats,(old+1)*ats))
	if ats: packet.attribute_data=attrs
	var stride: int = 2 if unique.size()<=65536 else 4
	var indices := PackedByteArray()
	indices.resize(corners.size()*stride)
	for corner: int in range(corners.size()):
		if stride==2: indices.encode_u16(corner*stride,remap[corners[corner]])
		else: indices.encode_u32(corner*stride,remap[corners[corner]])
	packet.index_data=indices
	packet.index_count=corners.size()
	packet.erase("lods")
	packet.erase("blend_shapes")
	if morph:
		var combined := PackedByteArray()
		for at: int in range(1,replacements.size()): combined.append_array(replacements[at])
		packet.blend_shapes=combined
	return packet

func split_driver(source: ArrayMesh) -> Dictionary:
	var active: Array = []
	var fixed: Array = []
	var report: Array = []
	var fixed_material: Material
	for surface: int in range(source.get_surface_count()):
		var packet: Dictionary = source.get("_surfaces")[surface]
		var count: int = packet.vertex_count
		var format: int = source.surface_get_format(surface)
		var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var raw: PackedByteArray = packet.vertex_data
		var poses: PackedByteArray = packet.blend_shapes
		var invariant: Array[bool] = []
		var static_vertices: int = 0
		for vertex: int in range(count):
			var same: bool = true
			for pose: int in range(source.get_blend_shape_count()):
				var start: int = pose*count*(ps+ns)
				if poses.slice(start+vertex*ps,start+(vertex+1)*ps)!=raw.slice(vertex*ps,(vertex+1)*ps): same=false; break
				if poses.slice(start+count*ps+vertex*ns,start+count*ps+(vertex+1)*ns)!=raw.slice(count*ps+vertex*ns,count*ps+(vertex+1)*ns): same=false; break
			invariant.append(same)
			if same: static_vertices+=1
		var indices: PackedInt32Array = source.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		var moving_corners := PackedInt32Array()
		var fixed_corners := PackedInt32Array()
		for at: int in range(0,indices.size(),3):
			var frozen: bool = invariant[indices[at]] and invariant[indices[at+1]] and invariant[indices[at+2]]
			for offset: int in range(3):
				if frozen: fixed_corners.append(indices[at+offset])
				else: moving_corners.append(indices[at+offset])
		active.append(rebuild_packet(source,surface,moving_corners,true))
		if not fixed_corners.is_empty():
			fixed.append(rebuild_packet(source,surface,fixed_corners,false))
			fixed_material=source.surface_get_material(surface)
		report.append({"role":source.surface_get_material(surface).resource_name,"vertices":count,"static_vertices":static_vertices,"static_triangles":fixed_corners.size()/3,"dynamic_triangles":moving_corners.size()/3})
	var dynamic := ArrayMesh.new()
	dynamic.blend_shape_mode=source.blend_shape_mode
	for pose: int in range(source.get_blend_shape_count()): dynamic.add_blend_shape(source.get_blend_shape_name(pose))
	dynamic.set("_surfaces",active)
	dynamic.custom_aabb=source.get_aabb()
	var static_mesh := ArrayMesh.new()
	static_mesh.set("_surfaces",fixed)
	static_mesh.custom_aabb=source.get_aabb()
	assert(source.get_faces().size()==dynamic.get_faces().size()+static_mesh.get_faces().size(),"split retains every driver triangle")
	return {"dynamic":dynamic,"static":static_mesh,"material":fixed_material,"surface_report":report,"before_bytes":payload(source),"after_bytes":payload(dynamic)+payload(static_mesh)}
