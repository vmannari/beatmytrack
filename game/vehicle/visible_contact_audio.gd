class_name VisibleContactAudio
extends RefCounted
## Presentation contact only. The canonical circle/forces/records are untouched.
var outline := PackedVector2Array()
var touching: bool = false
var sounded: bool = false
var cue_requested: bool = false
var normal := Vector2.ZERO
const MAX_PROBES: int = 128

func configure(car: Node3D) -> void:
	var points := PackedVector2Array()
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: Node in car.find_children("*","MeshInstance3D",true,false):
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
	for index: int in range(outline.size()-1):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[index+1]
		var steps: int = maxi(1,ceili(a.distance_to(b)/maxf(.10,track.cell_size*.5)))
		for step: int in range(steps+1):
			count += 1
			if count>MAX_PROBES: break
			var local: Vector2 = a.lerp(b,float(step)/steps)
			var point: Vector2 = state.position+right*local.x+forward*local.y
			if track.cell_at(point,state.track_elevated)==4:
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
			if track.cell_at(center+direction*track.cell_size,state.track_elevated)==4: continue
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

func duplicate_physical(impulse: Vector2) -> bool:
	return touching and sounded and impulse.normalized().dot(normal)>.65
