extends RefCounted
## Remove only zero-area or fully enclosed triangles from static workshop parts.
## Visible surfaces and their encoded vertex attributes are never resampled.
static var enabled: bool = true
const MARGIN: float = 0.00001
const OPAQUE_SHADERS: Array[String] = [
	"res://ui/garage_surface_finish.gdshader", "res://ui/garage_timber.gdshader",
	"res://ui/garage_audio_wood.gdshader", "res://ui/garage_display_backing.gdshader",
	"res://ui/garage_display_stone.gdshader",
]
var solids: Array[Dictionary] = []
var hidden_triangles: int = 0
var degenerate_triangles: int = 0

static func opaque(material: Material) -> bool:
	if material == null or material.next_pass != null: return false
	if material is BaseMaterial3D:
		return (material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			and not material.grow and not material.no_depth_test
			and not material.proximity_fade_enabled
			and material.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_DISABLED
			and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
			and material.cull_mode != BaseMaterial3D.CULL_FRONT)
	if material is ShaderMaterial and material.shader != null and material.shader.resource_path in OPAQUE_SHADERS:
		# Unknown or newly transparent/deforming finishes cannot act as solids.
		var code: String = material.shader.code
		var assignment := RegEx.new()
		assignment.compile("\\b(VERTEX|POSITION|DEPTH)(\\.[xyzwrgba]+)?\\s*([+*/-]?=)")
		return not code.contains("ALPHA") and not code.contains("discard") and not code.contains("cull_front") and not code.contains("depth_draw_never") and not code.contains("skip_vertex_transform") and assignment.search(code) == null
	return false

func gather(root: Node3D, box_meshes: Dictionary) -> void:
	if not enabled: return
	var sizes: Dictionary = {}
	for size: Vector3 in box_meshes: sizes[box_meshes[size]] = size
	_gather(root, Transform3D.IDENTITY, sizes)

func _gather(node: Node3D, transform: Transform3D, sizes: Dictionary) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		if not child.visible: continue
		# These independently animated/cutaway groups are never occluders.
		if child.name in ["GarageRoof", "GarageVinyl", "GarageRecordSleeves"]: continue
		var local: Transform3D = transform * child.transform
		if child is MeshInstance3D:
			if not sizes.has(child.mesh) or not child.visible or not opaque(child.material_override): continue
			var half: Vector3 = sizes[child.mesh] * 0.5
			var bevel: float = minf(0.025, minf(half.x, minf(half.y, half.z)) * 0.18)
			# The shrunken core lies strictly inside every bevel plane. No face
			# touching an exposed edge or coplanar with a neighbour is removed.
			var core: Vector3 = half - Vector3.ONE * (bevel + MARGIN)
			if core.x <= 0 or core.y <= 0 or core.z <= 0: continue
			solids.append({"node":child,"inverse":local.affine_inverse(),"core":core,"bounds":local * AABB(-core,core*2.0)})
		else: _gather(child, local, sizes)

static func inside(point: Vector3, core: Vector3) -> bool:
	var absolute: Vector3 = point.abs()
	return absolute.x < core.x and absolute.y < core.y and absolute.z < core.z

func clean(part: MeshInstance3D, transform: Transform3D) -> Mesh:
	var source: Mesh = part.mesh
	if enabled and source is CylinderMesh and opaque(part.material_override):
		var cylinder: ArrayMesh = compact_cylinder_caps(source)
		if cylinder != null: source=cylinder
	if not enabled or not source is ArrayMesh or source.get_surface_count() != 1 or source.get_blend_shape_count() != 0 or not opaque(part.material_override): return source
	if source.surface_get_format(0) & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES): return source
	# The workshop generates fresh LODs after batching. Existing levels require
	# their own visibility proof and must never be silently retained or dropped.
	if not (source.get("_surfaces")[0] as Dictionary).get("lods",[]).is_empty(): return source
	var candidates: Array[Dictionary] = []
	var bounds: AABB = transform * source.get_aabb()
	for solid: Dictionary in solids:
		if solid.node != part and bounds.intersects(solid.bounds):
			candidates.append({"transform":solid.inverse * transform,"core":solid.core})
	var packets: Array = source.get("_surfaces").duplicate()
	var changed: bool = false
	for surface: int in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for i: int in range(vertices.size()): indices[i] = i
		var kept := PackedInt32Array()
		for offset: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[offset]]
			var b: Vector3 = vertices[indices[offset+1]]
			var c: Vector3 = vertices[indices[offset+2]]
			if a == b or b == c or c == a:
				degenerate_triangles += 1
				continue
			var covered: bool = false
			for solid: Dictionary in candidates:
				var local: Transform3D = solid.transform
				if inside(local*a,solid.core) and inside(local*b,solid.core) and inside(local*c,solid.core):
					covered = true
					break
			if covered: hidden_triangles += 1
			else: kept.append_array(indices.slice(offset,offset+3))
		if kept.size() == indices.size(): continue
		# A fully enclosed part can disappear, but SurfaceTool still needs a
		# valid nonempty surface when material batching visits that source.
		if kept.is_empty(): return null
		var packet: Dictionary = packets[surface].duplicate()
		packets[surface] = compact(packet, kept)
		changed = true
	if not changed: return source
	var result := ArrayMesh.new()
	result.set("_surfaces",packets)
	result.custom_aabb = source.custom_aabb
	result.shadow_mesh = source.shadow_mesh
	for key: StringName in source.get_meta_list(): result.set_meta(key,source.get_meta(key))
	return preload("res://rendering/mesh_vertex_packing.gd").pack(result)

static func compact_cylinder_caps(source: CylinderMesh) -> ArrayMesh:
	# Planar cap fans need no centre vertex. Retain their exact boundary,
	# normals and UVs; four triangles disappear from each closed cylinder.
	if not source.cap_top or not source.cap_bottom or source.top_radius<=0 or source.top_radius!=source.bottom_radius: return null
	var arrays: Array=source.surface_get_arrays(0)
	var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var kept:=PackedInt32Array()
	var caps: Dictionary={-1:[],1:[]}
	for offset: int in range(0,indices.size(),3):
		var direction: int=1 if normals[indices[offset]].y>0 else -1
		var cap: bool=true
		for corner: int in range(3):
			var index: int=indices[offset+corner]
			cap=cap and normals[index].dot(Vector3.UP*direction)>0.9999 and is_equal_approx(positions[index].y,source.height*0.5*direction)
		if not cap:
			kept.append_array(indices.slice(offset,offset+3))
			continue
		for corner: int in range(3):
			var index: int=indices[offset+corner]
			if Vector2(positions[index].x,positions[index].z).length_squared()<0.000000000001: continue
			var duplicate: bool=false
			for previous: int in caps[direction]:
				if positions[index].distance_squared_to(positions[previous])<0.000000000001: duplicate=true;break
			if not duplicate: caps[direction].append(index)
	for direction: int in [-1,1]:
		var boundary: Array=caps[direction]
		if boundary.size()!=source.radial_segments: return null
		boundary.sort_custom(func(a: int,b: int) -> bool: return atan2(positions[a].x,positions[a].z)<atan2(positions[b].x,positions[b].z))
		for at: int in range(1,boundary.size()-1):
			var a: int=boundary[0]
			var b: int=boundary[at]
			var c: int=boundary[at+1]
			if (positions[b]-positions[a]).cross(positions[c]-positions[a]).dot(Vector3.UP*direction)>0:
				kept.append_array(PackedInt32Array([a,c,b]))
			else: kept.append_array(PackedInt32Array([a,b,c]))
	arrays[Mesh.ARRAY_INDEX]=kept
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.surface_set_material(0,source.surface_get_material(0))
	# Primitive bounds can differ by a float rounding unit from the identical
	# generated positions. Keep the original culling bounds as well.
	var packets: Array=result.get("_surfaces")
	packets[0].aabb=source.get_aabb()
	var bounded:=ArrayMesh.new()
	bounded.set("_surfaces",packets)
	bounded.custom_aabb=source.get_aabb()
	return bounded

static func compact(packet: Dictionary, indices: PackedInt32Array) -> Dictionary:
	# Copy complete encoded records; never round normals/UVs through a decoder.
	var count: int = packet.vertex_count
	var format: int = packet.format
	var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var used := PackedByteArray()
	used.resize(count)
	for index: int in indices: used[index] = 1
	var remap := PackedInt32Array()
	remap.resize(count)
	var positions := PackedByteArray()
	var normals := PackedByteArray()
	var attributes := PackedByteArray()
	var raw: PackedByteArray = packet.vertex_data
	var attrs: PackedByteArray = packet.get("attribute_data",PackedByteArray())
	var retained: int = 0
	for index: int in range(count):
		if not used[index]: continue
		remap[index] = retained
		retained += 1
		positions.append_array(raw.slice(index*ps,(index+1)*ps))
		normals.append_array(raw.slice(count*ps+index*ns,count*ps+(index+1)*ns))
		if ats: attributes.append_array(attrs.slice(index*ats,(index+1)*ats))
	positions.append_array(normals)
	packet.vertex_count = retained
	packet.vertex_data = positions
	if ats: packet.attribute_data = attributes
	var stride: int = 2 if retained <= 65536 else 4
	var encoded := PackedByteArray()
	encoded.resize(indices.size()*stride)
	for i: int in range(indices.size()):
		if stride == 2: encoded.encode_u16(i*stride,remap[indices[i]])
		else: encoded.encode_u32(i*stride,remap[indices[i]])
	packet.index_count = indices.size()
	packet.index_data = encoded
	packet.format = format | Mesh.ARRAY_FORMAT_INDEX
	return packet
