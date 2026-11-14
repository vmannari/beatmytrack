class_name VisibleContactAudio
extends RefCounted
## Presentation contact only. The canonical circle/forces/records are untouched.
var outline := PackedVector2Array()
var touching: bool = false
var sounded: bool = false
var cue_requested: bool = false
var normal := Vector2.ZERO
const MAX_PROBES: int = 128
const CACHE_BYTES: int = 1024 * 1024
const RETAINED_BYTES: int = 16 * 1024 * 1024
const MAX_ENTRIES: int = 8
static var prepared_outlines: Array[Dictionary] = []
static var cache_hits: int = 0
static var cache_misses: int = 0
static var surface_reads: int = 0

static func bytes_used() -> int:
	var total: int = 0
	for entry: Dictionary in prepared_outlines: total += int(entry.bytes)
	return total

static func _outline_bytes() -> int:
	var total: int = 0
	for entry: Dictionary in prepared_outlines: total += int(entry.get("outline_bytes",entry.bytes))
	return total

static func trim_cache(allowance: int = 0) -> void:
	while not prepared_outlines.is_empty() and bytes_used() > allowance: _remove_entry(0)

static func _remove_entry(index: int) -> void:
	var entry: Dictionary = prepared_outlines.pop_at(index)
	for mesh: Mesh in entry.get("meshes",[]):
		var retained: bool = prepared_outlines.any(func(other: Dictionary) -> bool: return mesh in other.get("meshes",[]))
		var changed: Callable = _mesh_changed.bind(mesh.get_instance_id())
		if not retained and mesh.changed.is_connected(changed): mesh.changed.disconnect(changed)

static func _mesh_changed(id: int) -> void:
	# Keep exact resource identity, never a vehicle-name approximation. An edit
	# to a retained resource invalidates every hull that consumed its vertices.
	for index: int in range(prepared_outlines.size()-1,-1,-1):
		for mesh: Mesh in prepared_outlines[index].get("meshes",[]):
			if mesh.get_instance_id() == id:
				_remove_entry(index)
				break

static func _mesh_bytes(mesh: Mesh, seen: Dictionary, decoded: Dictionary) -> int:
	if mesh == null or seen.has(mesh.get_instance_id()): return 0
	seen[mesh.get_instance_id()] = true
	# Conservative CPU/GPU stream estimate, including morphs, index/LOD
	# headroom and object/material overhead. Counts do not read Vulkan buffers.
	var bytes: int = 4096+mesh.get_surface_count()*4096
	if decoded.has(mesh.get_instance_id()):
		bytes += int(decoded[mesh.get_instance_id()])
	elif mesh is ArrayMesh:
		for surface: int in range(mesh.get_surface_count()):
			bytes += mesh.surface_get_array_len(surface)*192
			bytes += mesh.surface_get_array_index_len(surface)*16
	else:
		return RETAINED_BYTES+1
	if mesh is ArrayMesh:
		for surface: int in range(mesh.get_surface_count()):
			bytes += mesh.surface_get_array_len(surface)*80*mesh.get_blend_shape_count()
		bytes += _mesh_bytes(mesh.shadow_mesh,seen,decoded)
	return bytes

static func _array_bytes(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY: return value.size()
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY: return value.size()*4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY: return value.size()*8
		TYPE_PACKED_VECTOR3_ARRAY: return value.size()*12
		TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY: return value.size()*16
	return 0

func configure(car: Node3D, prepared: bool = false) -> void:
	var points := PackedVector2Array()
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var parts: Array = car.find_children("*","MeshInstance3D",true,false)
	var key: Array = [car.scale]
	if prepared:
		for node: MeshInstance3D in parts:
			if node.mesh != null: key.append([node.mesh.get_instance_id(),inverse*node.global_transform,node.mesh.get_surface_count(),node.mesh.get_aabb()])
		for index: int in range(prepared_outlines.size()):
			if prepared_outlines[index].key != key: continue
			var entry: Dictionary = prepared_outlines.pop_at(index); prepared_outlines.append(entry)
			outline = entry.outline
			cache_hits += 1
			reset()
			return
		cache_misses += 1
	var decoded: Dictionary = {}
	for node: Node in parts:
		var part: MeshInstance3D = node as MeshInstance3D
		if part.mesh==null: continue
		var transform: Transform3D = inverse*part.global_transform
		var counted: bool = decoded.has(part.mesh.get_instance_id())
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			surface_reads += 1
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if not counted:
				var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
				var retained: int = indices*8 # Additional LOD/index headroom.
				for attribute: Variant in arrays: retained += _array_bytes(attribute)*2
				decoded[part.mesh.get_instance_id()] = int(decoded.get(part.mesh.get_instance_id(),0))+retained
			for vertex: Vector3 in vertices:
				var local: Vector3 = transform*vertex
				points.append(Vector2(local.x*car.scale.x,-local.z*car.scale.z))
	outline = Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()
	if prepared:
		var bytes: int = var_to_bytes(key).size()+outline.size()*8+512
		if bytes <= CACHE_BYTES:
			var outline_bytes: int = bytes
			var meshes: Array[Mesh] = []
			var seen: Dictionary = {}
			for part: MeshInstance3D in parts:
				if part.mesh == null or part.mesh in meshes: continue
				meshes.append(part.mesh)
				bytes += _mesh_bytes(part.mesh,seen,decoded)
			if bytes <= RETAINED_BYTES:
				while not prepared_outlines.is_empty() and (prepared_outlines.size() >= MAX_ENTRIES or bytes_used()+bytes > RETAINED_BYTES or _outline_bytes()+outline_bytes > CACHE_BYTES): _remove_entry(0)
				# Mesh references keep the prepared scene's subresources alive after
				# race teardown, so the next load reuses the exact same mesh IDs.
				# No car nodes, poses, materials overrides or scene owners survive.
				prepared_outlines.append({"key":key,"outline":outline,"bytes":bytes,"outline_bytes":outline_bytes,"meshes":meshes})
				for mesh: Mesh in meshes:
					var changed: Callable = _mesh_changed.bind(mesh.get_instance_id())
					if not mesh.changed.is_connected(changed): mesh.changed.connect(changed)
	reset()

func reset() -> void:
	touching = false
	sounded = false
	cue_requested = false
	normal = Vector2.ZERO

func sample(state: VehicleState, track: NativeTrack, incoming: Vector2) -> Vector2:
	if track==null or outline.size()<3 or state.jump_height>0.0 or state.roll_ticks>0:
		reset()
		return Vector2.ZERO
	var found: bool = false
	var count: int = 0
	var contact_point := Vector2.ZERO
	var forward: Vector2 = state.forward()
	var right: Vector2 = state.right()
	var span_index: int = CreatorBridges.span_at(track.creator_bridges,state.position) if state.track_elevated else -1
	for index: int in range(outline.size()-1):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[index+1]
		var steps: int = maxi(1,ceili(a.distance_to(b)/maxf(.10,track.cell_size*.5)))
		# The next edge owns this edge's endpoint. Counting it twice exhausts
		# the bounded budget on detailed bodies before their full perimeter.
		for step: int in range(steps):
			count += 1
			if count>MAX_PROBES: break
			var local: Vector2 = a.lerp(b,float(step)/steps)
			var point: Vector2 = state.position+right*local.x+forward*local.y
			if _solid_at(state,track,point,span_index):
				found = true
				contact_point = point
				break
		if found or count>MAX_PROBES: break
	if not found:
		reset()
		return Vector2.ZERO
	var first: bool = not touching
	touching = true
	if first:
		# An occupied cell's nearest rectangle edge can be an internal edge.
		# Use only faces with clear neighboring material for audible incidence.
		var x: int = floori((contact_point.x+track.half_extent.x)/track.cell_size)
		var y: int = floori((track.half_extent.y-contact_point.y)/track.cell_size)
		var center := Vector2((float(x)+.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(float(y)+.5)*track.cell_size)
		var best: float = -INF
		normal = Vector2.ZERO
		for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			if _solid_at(state,track,center+direction*track.cell_size,span_index): continue
			var facing: float = -incoming.dot(direction)
			if facing>best:
				best = facing
				normal = direction
		# No exposed face means no trustworthy visual-only impact normal.
		# Let the canonical observer handle deep/startup overlap instead.
	var inward: float = maxf(0.0,-incoming.dot(normal))
	if not sounded and not cue_requested and inward>1.2 and inward/maxf(incoming.length(),.001)>.35:
		# A genuine current mesh/solid intersection, not predicted future impact.
		# A soft first touch can become meaningful during the same episode.
		# Attempt once, so a cooldown rejection cannot queue a stale later cue.
		cue_requested = true
		return normal*inward
	return Vector2.ZERO

func _solid_at(state: VehicleState, track: NativeTrack, point: Vector2, span_index: int) -> bool:
	if track.cell_at(point,state.track_elevated)!=4: return false
	var x: int = floori((point.x+track.half_extent.x)/track.cell_size)
	var y: int = floori((track.half_extent.y-point.y)/track.cell_size)
	var center := Vector2((x+.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+.5)*track.cell_size)
	if state.track_elevated and span_index>=0:
		# Match the resolver's supporting-span guard. A nearby disconnected
		# bridge rail cannot hit a car still leaving its own low ramp.
		return CreatorBridges.contains(track.creator_bridges[span_index],center) or CreatorBridges.shares_span(track.creator_bridges,state.position,center)
	if not state.track_elevated:
		for span: Dictionary in track.creator_bridges:
			var local: Vector2 = CreatorBridges.local_point(span,state.position)
			if local.x>=0.0 and local.x<=float(span.length): continue
			if absf(local.y)>float(span.width)*.5: continue
			var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
			if absf(state.forward().dot(axis))<=.75: continue
			# The visible nose/rear can already be on the sloping road while
			# the centre is outside its mouth. Its low underside is not a wall.
			var on_ramp: Vector2 = CreatorBridges.local_point(span,center)
			if on_ramp.x>=0.0 and on_ramp.x<=float(span.length) and absf(on_ramp.y)<=float(span.width)*.5 and track.cell_at(center,true)==0: return false
	return true

func duplicate_physical(impulse: Vector2) -> bool:
	return touching and sounded and impulse.normalized().dot(normal)>.65
