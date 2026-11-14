extends SceneTree
## Compare spatial candidate rejection with an exhaustive intersection oracle.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 140112026
	for sample: int in range(40):
		var path := PackedVector2Array()
		for i: int in range(80):
			path.append(Vector2(rng.randf_range(-128,128),rng.randf_range(-128,128)).snapped(Vector2.ONE*0.125))
		var session := TrackSession.new()
		for i: int in range(40):
			session._centers.append(Vector2(rng.randi_range(-16,16)*8,rng.randi_range(-16,16)*8))
			session._directions.append(Vector2.from_angle(rng.randf_range(-PI,PI)))
			session._widths.append(Vector2(rng.randf_range(0,40),rng.randf_range(0,40)))
		var expected: PackedFloat64Array = reference_crossings(session,path)
		var actual: PackedFloat64Array = SplineGateCorridor._crossings(session,path)
		checks += 1
		if var_to_bytes(expected) != var_to_bytes(actual):
			failures += 1
			push_error("Indexed crossings differ for seed case "+str(sample))
	print("CHECKPOINT_SPATIAL_INDEX ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)

static func reference_crossings(session: RefCounted, path: PackedVector2Array) -> PackedFloat64Array:
	var events := PackedFloat64Array()
	for gate: int in range(session._centers.size()):
		var event: float = -1.0
		var nearest: float = INF
		var center: Vector2 = session._centers[gate]
		var direction: Vector2 = session._directions[gate]
		var normal: Vector2 = direction.orthogonal()
		var widths: Vector2 = session._widths[gate]
		var before: float = (path[0]-center).dot(direction)
		for i: int in range(path.size()-1):
			var after: float = (path[i+1]-center).dot(direction)
			var f: float = -before/(after-before) if before <= 0.0 and after > 0.0 else -1.0
			before = after
			if f < 0.0: continue
			var p: Vector2 = path[i].lerp(path[i+1],f)
			var lateral: float = (p-center).dot(normal)
			if lateral < -widths.x or lateral > widths.y: continue
			if p.distance_squared_to(center) < nearest:
				nearest = p.distance_squared_to(center); event = i+f
		events.append(event)
	return events
