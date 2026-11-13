extends RefCounted
## Deduplicate complete encoded GPU vertices. Never decode/re-encode attributes.
## Ordered triangle corners, normal codes, colours, UVs and LODs remain exact.
static var enabled: bool = true

static func pack(source: ArrayMesh) -> ArrayMesh:
	var operation: Callable = pack_cooperative
	return operation.call(source,Callable())

static func pack_cooperative(source: ArrayMesh, cooperate: Callable = Callable()) -> ArrayMesh:
	if not enabled or source == null or source.get_blend_shape_count()!=0:return source
	var surfaces: Array=source.get("_surfaces").duplicate()
	var changed: bool=false
	for surface: int in range(surfaces.size()):
		var original: Dictionary=surfaces[surface]
		var count: int=int(original.vertex_count)
		var format: int=source.surface_get_format(surface)
		# Compressed position blocks have additional reconstruction state. Keep
		# those already compact meshes and skinned/blend-shape models unchanged.
		if count<32 or source.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES or format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES or format & Mesh.ARRAY_FORMAT_BONES:continue
		var position_stride: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
		var normal_stride: int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
		var attribute_stride: int=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var vertices: PackedByteArray=original.vertex_data
		var attributes: PackedByteArray=original.get("attribute_data",PackedByteArray())
		if vertices.size()!=count*(position_stride+normal_stride) or attributes.size()!=count*attribute_stride:continue
		var normal_offset: int=count*position_stride
		var remap:=PackedInt32Array();remap.resize(count)
		var unique:=PackedInt32Array()
		var keys: Dictionary={}
		for index: int in range(count):
			if index%1024==0 and cooperate.is_valid() and not await cooperate.call():return source
			var key: PackedByteArray=vertices.slice(index*position_stride,(index+1)*position_stride)
			if normal_stride:key.append_array(vertices.slice(normal_offset+index*normal_stride,normal_offset+(index+1)*normal_stride))
			if attribute_stride:key.append_array(attributes.slice(index*attribute_stride,(index+1)*attribute_stride))
			if keys.has(key):remap[index]=int(keys[key])
			else:
				remap[index]=unique.size();keys[key]=unique.size();unique.append(index)
		keys.clear()
		var source_indices: PackedByteArray=original.get("index_data",PackedByteArray())
		var corners: int=int(original.get("index_count",0))
		var old_stride: int=source_indices.size()/corners if corners>0 else (2 if count<=65536 else 4)
		if corners==0:corners=count
		var stride: int=2 if unique.size()<=65536 else 4
		var saved: int=(count-unique.size())*(position_stride+normal_stride+attribute_stride)-corners*stride+source_indices.size()
		if saved<=0:continue
		var packed_positions:=PackedByteArray();var packed_normals:=PackedByteArray();var packed_attributes:=PackedByteArray()
		for index: int in range(unique.size()):
			if index%1024==0 and cooperate.is_valid() and not await cooperate.call():return source
			var old: int=unique[index]
			packed_positions.append_array(vertices.slice(old*position_stride,(old+1)*position_stride))
			if normal_stride:packed_normals.append_array(vertices.slice(normal_offset+old*normal_stride,normal_offset+(old+1)*normal_stride))
			if attribute_stride:packed_attributes.append_array(attributes.slice(old*attribute_stride,(old+1)*attribute_stride))
		packed_positions.append_array(packed_normals)
		var indices:=PackedByteArray();indices.resize(corners*stride)
		for corner: int in range(corners):
			if corner%4096==0 and cooperate.is_valid() and not await cooperate.call():return source
			var old: int=corner if source_indices.is_empty() else source_indices.decode_u16(corner*old_stride) if old_stride==2 else source_indices.decode_u32(corner*old_stride)
			if stride==2:indices.encode_u16(corner*stride,remap[old])
			else:indices.encode_u32(corner*stride,remap[old])
		var packet: Dictionary=original.duplicate()
		packet.vertex_count=unique.size();packet.vertex_data=packed_positions
		if attribute_stride:packet.attribute_data=packed_attributes
		packet.index_count=corners;packet.index_data=indices;packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
		var levels: Array=original.get("lods",[]).duplicate()
		for level: int in range(1,levels.size(),2):
			var old: PackedByteArray=levels[level]
			var replacement:=PackedByteArray();replacement.resize(old.size()/old_stride*stride)
			for corner: int in range(old.size()/old_stride):
				var vertex: int=old.decode_u16(corner*old_stride) if old_stride==2 else old.decode_u32(corner*old_stride)
				if stride==2:replacement.encode_u16(corner*stride,remap[vertex])
				else:replacement.encode_u32(corner*stride,remap[vertex])
			levels[level]=replacement
		if not levels.is_empty():packet.lods=levels
		surfaces[surface]=packet;changed=true
	if not changed:return source
	var result:=ArrayMesh.new();result.set("_surfaces",surfaces)
	result.custom_aabb=source.custom_aabb;result.shadow_mesh=source.shadow_mesh
	for key: StringName in source.get_meta_list():result.set_meta(key,source.get_meta(key))
	if result.has_meta("scenery_lod_bytes"):
		var bytes: int=0
		for packet: Dictionary in surfaces:
			var levels: Array=packet.get("lods",[])
			for index: int in range(1,levels.size(),2):bytes+=levels[index].size()*4
		result.set_meta("scenery_lod_bytes",bytes)
	return result

static func with_detail(source: ArrayMesh, detail: ArrayMesh, metric: float) -> ArrayMesh:
	# Two authored samplings share one draw. Master indices retain the complete
	# original mesh; the additional vertices are referenced only by the far LOD.
	if source.get_surface_count()!=1 or detail.get_surface_count()!=1:return source
	var a: Dictionary=source.get("_surfaces")[0].duplicate()
	var b: Dictionary=detail.get("_surfaces")[0]
	var format: int=source.surface_get_format(0)
	if (format&~Mesh.ARRAY_FORMAT_INDEX)!=(detail.surface_get_format(0)&~Mesh.ARRAY_FORMAT_INDEX) or format&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:return source
	var count: int=int(a.vertex_count);var other: int=int(b.vertex_count);var total: int=count+other
	var ps: int=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var first: PackedByteArray=a.vertex_data;var second: PackedByteArray=b.vertex_data
	var vertices: PackedByteArray=first.slice(0,count*ps)
	vertices.append_array(second.slice(0,other*ps));vertices.append_array(first.slice(count*ps));vertices.append_array(second.slice(other*ps))
	var attrs: PackedByteArray=a.get("attribute_data",PackedByteArray()).duplicate();attrs.append_array(b.get("attribute_data",PackedByteArray()))
	var stride: int=2 if total<=65536 else 4
	var streams: Array=[]
	for spec: Array in [[a,count,0],[b,other,count]]:
		var packet: Dictionary=spec[0];var n: int=spec[1];var offset: int=spec[2]
		var raw: PackedByteArray=packet.get("index_data",PackedByteArray());var corners: int=int(packet.get("index_count",n))
		var old_stride: int=raw.size()/corners if not raw.is_empty() else 0
		var indices:=PackedByteArray();indices.resize(corners*stride)
		for corner: int in range(corners):
			var index: int=corner if raw.is_empty() else raw.decode_u16(corner*old_stride) if old_stride==2 else raw.decode_u32(corner*old_stride)
			if stride==2:indices.encode_u16(corner*stride,index+offset)
			else:indices.encode_u32(corner*stride,index+offset)
		streams.append(indices)
	a.vertex_count=total;a.vertex_data=vertices
	if not attrs.is_empty():a.attribute_data=attrs
	a.index_data=streams[0];a.index_count=streams[0].size()/stride;a.format=format|Mesh.ARRAY_FORMAT_INDEX
	a.lods=[metric,streams[1]];a.aabb=source.get_aabb().merge(detail.get_aabb())
	var result:=ArrayMesh.new();result.set("_surfaces",[a]);result.shadow_mesh=source.shadow_mesh;result.custom_aabb=source.custom_aabb
	for key: StringName in source.get_meta_list():result.set_meta(key,source.get_meta(key))
	result.set_meta("scenery_lod_bytes",streams[1].size()*4)
	# Tread and bead corners common to both samplings need only one raw vertex.
	return pack(result)
