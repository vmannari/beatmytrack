class_name SceneryMeshLods
extends RefCounted
## Offline-authored corner maps; no mesh simplifier is used at runtime.
const VERSION: String = "scenery-lods-1"
const KINDS: Array[String] = ["ice_compact","snow_castle","container"]
const ROOT: String = "res://assets/scenery_lods_v1/"
const ERROR: float = 0.028

static func signature(mesh: ArrayMesh) -> String:
	var arrays: Array = mesh.surface_get_arrays(0)
	# Paint may change. Geometry, normals, ordering and hidden-face ownership may not.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],mesh.get_meta("prop_hidden_triangles",PackedInt32Array())]))
	return digest.finish().hex_encode()

static func prepare_source(mesh: ArrayMesh, kind: String) -> void:
	if kind=="tree" and mesh.has_meta("tree_far_dropped"):
		var corners: PackedInt32Array=tree_corners(mesh)
		mesh.set_meta("scenery_lod_plan",{"corners":corners,"count":mesh.surface_get_array_len(0)})
		mesh.set_meta("scenery_lod_plan_bytes",corners.size()*4+256)
		return
	if kind not in KINDS: return
	var path: String = ROOT+kind+".res"
	if not ResourceLoader.exists(path): return
	var asset: Resource = load(path)
	if asset == null or asset.get_meta("version","") != VERSION or asset.get_meta("kind","") != kind: return
	if asset.get_meta("signature","") != signature(mesh): return
	var corners: PackedInt32Array = asset.get_meta("corners",PackedInt32Array())
	var count: int = mesh.surface_get_array_len(0)
	if corners.is_empty() or corners.size()%3 != 0 or corners.size() >= count or int(asset.get_meta("corner_count",0)) != count: return
	for corner: int in corners:
		if corner < 0 or corner >= count: return
	mesh.set_meta("scenery_lod_plan",{"corners":corners,"count":count})
	mesh.set_meta("scenery_lod_plan_bytes",corners.size()*4+256)

static func tree_corners(mesh: ArrayMesh) -> PackedInt32Array:
	var excluded: Dictionary={}
	for triangle: int in mesh.get_meta("tree_far_dropped",PackedInt32Array()):excluded[triangle]=true
	for triangle: int in mesh.get_meta("prop_hidden_triangles",PackedInt32Array()):excluded[triangle]=true
	var corners:=PackedInt32Array()
	for corner: int in range(mesh.surface_get_array_len(0)):
		if not excluded.has(corner/3):corners.append(corner)
	return corners

static func append_plan(tool: SurfaceTool, mesh: ArrayMesh, offset: int, pose: Transform3D) -> void:
	if not tool.get_meta("scenery_lods_enabled",false) or not mesh.has_meta("scenery_lod_plan"): return
	var plan: Dictionary = mesh.get_meta("scenery_lod_plan")
	var scale: Vector3 = pose.basis.get_scale().abs()
	var plans: Array = tool.get_meta("scenery_lod_plans",[])
	plans.append({"start":offset,"end":offset+int(plan.count),"corners":plan.corners,"error":ERROR*maxf(scale.x,maxf(scale.y,scale.z))})
	tool.set_meta("scenery_lod_plans",plans)

static func _range(indices: PackedInt32Array, start: int, end: int, hidden: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	var cursor: int = start
	for index: int in range(hidden.bsearch(start/3),hidden.bsearch(end/3)):
		var at: int = hidden[index]*3
		if at > cursor: result.append_array(indices.slice(cursor,at))
		cursor = at+3
	if cursor < end: result.append_array(indices.slice(cursor,end))
	return result

static func apply(tool: SurfaceTool, source: ArrayMesh) -> ArrayMesh:
	var plans: Array = tool.get_meta("scenery_lod_plans",[])
	if plans.is_empty(): return source
	var arrays: Array = tool.commit_to_arrays()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
		for index: int in range(indices.size()): indices[index] = index
	var hidden: PackedInt32Array = tool.get_meta("prop_hidden_triangles",PackedInt32Array()).duplicate(); hidden.sort()
	var ends: PackedInt32Array = tool.get_meta("spatial_object_ends",PackedInt32Array())
	var lod_ends: PackedInt32Array = ends.duplicate()
	for index: int in range(ends.size()): lod_ends[index] -= hidden.bsearch(ends[index]/3)*3
	var reduced := PackedInt32Array()
	var cursor: int = 0
	var error: float = 0.0
	for plan: Dictionary in plans:
		if plan.start < cursor or plan.end > indices.size(): return source
		reduced.append_array(_range(indices,cursor,plan.start,hidden))
		for corner: int in plan.corners: reduced.append(indices[int(plan.start)+corner])
		var removed: int = _range(indices,plan.start,plan.end,hidden).size()-plan.corners.size()
		for index: int in range(ends.size()):
			if ends[index] > plan.start and ends[index] < plan.end: return source
			if ends[index] >= plan.end: lod_ends[index] -= removed
		cursor = plan.end; error = maxf(error,float(plan.error))
	reduced.append_array(_range(indices,cursor,indices.size(),hidden))
	var result: ArrayMesh = attach(source,{error:reduced})
	if not lod_ends.is_empty(): result.set_meta("scenery_lod_object_ends",lod_ends)
	return result

static func attach(source: ArrayMesh, levels: Dictionary) -> ArrayMesh:
	if levels.is_empty(): return source
	var surfaces: Array = source.get("_surfaces").duplicate(true)
	var packet: Dictionary = surfaces[0]
	# Godot only retains LODs on indexed surfaces. Snow colouring is authored
	# before indexing, so give that source an exact sequential master first.
	if int(packet.get("index_count",0)) == 0:
		var count: int = int(packet.vertex_count)
		var index_stride: int = 2 if count <= 65536 else 4
		var sequential := PackedByteArray(); sequential.resize(count*index_stride)
		for corner: int in range(count):
			if index_stride == 2: sequential.encode_u16(corner*index_stride,corner)
			else: sequential.encode_u32(corner*index_stride,corner)
		packet.index_count = count; packet.index_data = sequential
		packet.format = int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
	var stride: int = packet.index_data.size()/int(packet.index_count) if int(packet.get("index_count",0)) > 0 else (2 if int(packet.vertex_count) <= 65536 else 4)
	var packed_levels: Array = []
	var bytes: int = 0
	for error: float in levels:
		var indices: PackedInt32Array = levels[error]
		var data := PackedByteArray(); data.resize(indices.size()*stride)
		for index: int in range(indices.size()):
			if stride == 2: data.encode_u16(index*stride,indices[index])
			else: data.encode_u32(index*stride,indices[index])
		packed_levels.append(error); packed_levels.append(data); bytes += data.size()*4
	packet.lods = packed_levels
	var result := ArrayMesh.new(); result.set("_surfaces",surfaces)
	result.custom_aabb = source.custom_aabb; result.shadow_mesh = source.shadow_mesh
	for key: StringName in source.get_meta_list(): result.set_meta(key,source.get_meta(key))
	result.set_meta("scenery_lod_bytes",bytes)
	return result

static func packets(mesh: ArrayMesh) -> Array:
	if not mesh.has_meta("scenery_lod_bytes"): return []
	var surface: Dictionary = mesh.get("_surfaces")[0]
	var stride: int = surface.index_data.size()/int(surface.index_count)
	var result: Array = []
	var levels: Array = surface.get("lods",[])
	for index: int in range(0,levels.size(),2):
		result.append({"error":levels[index],"data":levels[index+1],"stride":stride,"object_ends":mesh.get_meta("scenery_lod_object_ends",PackedInt32Array())})
	return result
