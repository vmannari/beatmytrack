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
static var prepared_outlines: Array[Dictionary] = []

func configure(car: Node3D, prepared: bool = false) -> void:
	var points := PackedVector2Array()
	var inverse: Transform3D = car.global_transform.affine_inverse()
	var parts: Array = car.find_children("*","MeshInstance3D",true,false)
	var key: Array = [car.scale]
	if prepared:
		for node: MeshInstance3D in parts:
			if node.mesh != null: key.append([node.mesh.get_instance_id(),inverse*node.global_transform])
		for index: int in range(prepared_outlines.size()):
			if prepared_outlines[index].key != key: continue
			var entry: Dictionary = prepared_outlines.pop_at(index); prepared_outlines.append(entry)
			outline = entry.outline
			reset()
			return
	for node: Node in parts:
		var part: MeshInstance3D = node as MeshInstance3D
		if part.mesh==null: continue
		var transform: Transform3D = inverse*part.global_transform
		for surface: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var local: Vector3 = transform*vertex
				points.append(Vector2(local.x*car.scale.x,-local.z*car.scale.z))
	outline = Geometry2D.convex_hull(points) if points.size()>2 else PackedVector2Array()
	if prepared:
		var bytes: int = var_to_bytes(key).size()+outline.size()*8+512
		if bytes <= CACHE_BYTES:
			var total: int = bytes
			for entry: Dictionary in prepared_outlines: total += int(entry.bytes)
			while not prepared_outlines.is_empty() and (prepared_outlines.size() >= 8 or total > CACHE_BYTES): total -= int(prepared_outlines.pop_front().bytes)
			prepared_outlines.append({"key":key,"outline":outline,"bytes":bytes})
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
		for step: int in range(steps+1):
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
