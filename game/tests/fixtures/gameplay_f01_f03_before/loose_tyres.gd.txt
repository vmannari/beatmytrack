class_name LooseTyres
extends RefCounted
## Deterministic planar tyre stacks. State belongs to each run, never to track data.
const RADIUS: float = 0.5
const MASS: float = 400.0 # Effective contact mass for a resistant tyre stack.
const SLIDING_DECELERATION: float = 24.0

static func positions(document: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for object: Dictionary in document.get("objects",[]):
		if object.kind not in ["tyre_wall","tyre_stack"]: continue
		var center := Vector2(object.position[0],object.position[1])
		var count: int = 1 if object.kind == "tyre_stack" else 6
		for i: int in range(count): result.append(center+Vector2(i-(count-1)*0.5,0).rotated(deg_to_rad(float(object.rotation))))
	return result

static func step(state: VehicleState, origins: PackedVector2Array, contact_test: Callable, from: Vector2, config: HandlingConfig, step_seconds: float) -> void:
	if origins.is_empty(): return
	if state.loose_tyres.is_empty():
		for p: Vector2 in origins: state.loose_tyres.append([p.x,p.y,0.0,0.0,0.0])
	var count: int = state.loose_tyres.size()
	var points: Array[Vector2] = []
	var velocities: Array[Vector2] = []
	var friction: Array[float] = []
	var buckets: Dictionary = {}
	var pairs: Array[Vector2i] = []
	for index: int in range(count):
		var tyre: Array = state.loose_tyres[index]
		var p := Vector2(tyre[0],tyre[1])
		points.append(p)
		velocities.append(Vector2(tyre[2],tyre[3]).limit_length(30))
		friction.append(SLIDING_DECELERATION*step_seconds)
		var cell := Vector2i(floori(p.x/1.6),floori(p.y/1.6))
		# Stable indices and fixed neighbour order, independent of dictionary iteration.
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				for other: int in buckets.get(cell+Vector2i(x,y),[]):
					if p.distance_squared_to(points[other]) <= 1.6*1.6:
						pairs.append(Vector2i(other,index))
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(index)
	# Accumulated friction has one per-tick budget. Iteration transmits the car's
	# available force through a pile, including static friction at rest.
	# Positions do not change during the impulse solver. Compute its contact
	# geometry once, retaining the original index and impulse order.
	var car_normals: Array[Vector2] = []
	var solver_active: bool = false
	for index: int in range(count):
		var point: Vector2 = points[index]
		var normal := Vector2.ZERO
		if not state.track_elevated:
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(point,from,state.position)
			var delta: Vector2 = point-near
			if delta.length() <= config.collision_radius+RADIUS+0.005:
				normal = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
		car_normals.append(normal)
		if normal != Vector2.ZERO or velocities[index] != Vector2.ZERO: solver_active = true
	# Separated, stationary stacks cannot change this tick: the swept car test
	# above also excludes car separation. Keep overlapping piles on the complete
	# solver path, including sub-ULP overlaps, to preserve exact contact results.
	if not solver_active:
		var separated: bool = true
		for pair: Vector2i in pairs:
			if (points[pair.y]-points[pair.x]).length() < 1.0:
				separated = false
				break
		if separated:
			for tyre: Array in state.loose_tyres:
				tyre[4] = fposmod(float(tyre[4]),TAU)
			return
	var pair_deltas: Array[Vector2] = []
	var pair_normals: Array[Vector2] = []
	var pair_touching: Array[bool] = []
	for pair: Vector2i in pairs:
		var delta: Vector2 = points[pair.y]-points[pair.x]
		pair_deltas.append(delta)
		pair_normals.append(delta.normalized() if delta.length_squared()>0.000001 else Vector2.RIGHT)
		pair_touching.append(delta.length() <= 1.005)
	for iteration: int in range(16 if solver_active else 0):
		for index: int in range(count):
			if velocities[index] == Vector2.ZERO and car_normals[index] == Vector2.ZERO:
				continue
			var speed: float = velocities[index].length()
			var reduction: float = minf(speed,friction[index])
			velocities[index] = velocities[index].move_toward(Vector2.ZERO,reduction)
			friction[index] -= reduction
			var normal: Vector2 = car_normals[index]
			if normal == Vector2.ZERO: continue
			var approach: float = (state.velocity-velocities[index]).dot(normal)
			if approach > 0:
				var impulse: float = approach/(1.0/config.mass+1.0/MASS)
				state.velocity -= normal*impulse/config.mass
				state.collision_impulse -= normal*impulse/config.mass
				velocities[index] += normal*impulse/MASS
				if iteration == 0: state.collision_count += 1
		for pair_index: int in range(pairs.size()):
			var pair: Vector2i = pairs[pair_index]
			if velocities[pair.x] == Vector2.ZERO and velocities[pair.y] == Vector2.ZERO:
				continue
			var normal: Vector2 = pair_normals[pair_index]
			if not pair_touching[pair_index] and (pair_deltas[pair_index]+(velocities[pair.y]-velocities[pair.x])*step_seconds).length()>1.0: continue
			var approach: float = (velocities[pair.x]-velocities[pair.y]).dot(normal)
			if approach > 0:
				velocities[pair.x] -= normal*approach*0.5
				velocities[pair.y] += normal*approach*0.5
	for index: int in range(count):
		var tyre: Array = state.loose_tyres[index]
		var p: Vector2 = points[index]
		var velocity: Vector2 = velocities[index]
		var motion: Vector2 = velocity*step_seconds
		# A stationary tyre's world contact can only assign its already-zero
		# velocity. Avoid that query; car/pile separation below still runs.
		var steps: int = 0 if velocity == Vector2.ZERO else maxi(1,ceili(motion.length()/0.2))
		for i: int in range(steps):
			var candidate: Vector2 = p+motion/steps
			var collision: Vector3 = contact_test.call(candidate,RADIUS,false)
			if collision.z > 0:
				velocity = Vector2.ZERO
				break
			p = candidate
		if not state.track_elevated:
			var delta: Vector2 = p-state.position
			var contact: float = config.collision_radius+RADIUS
			if delta.length()<contact:
				var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
				state.position = p-normal*contact
		tyre[0] = p.x; tyre[1] = p.y
		tyre[2] = velocity.x; tyre[3] = velocity.y
		tyre[4] = fposmod(float(tyre[4])+velocity.length()*step_seconds/RADIUS,TAU)
	# Remove small integration overlaps so an arriving stack cannot sink into a pile.
	for iteration: int in range(4):
		for pair: Vector2i in pairs:
			var a: Array = state.loose_tyres[pair.x]
			var b: Array = state.loose_tyres[pair.y]
			var pa := Vector2(a[0],a[1])
			var pb := Vector2(b[0],b[1])
			var delta: Vector2 = pb-pa
			if delta.length()>=1.0: continue
			var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else Vector2.RIGHT
			var correction: Vector2 = normal*(1.0-delta.length())*0.5
			var next_a: Vector2 = pa-correction
			var next_b: Vector2 = pb+correction
			# Settled piles can retain sub-ULP overlaps: these proposed corrections
			# round to the same position. A world query cannot change their result.
			if next_a != pa and Vector3(contact_test.call(next_a,RADIUS,false)).z<=0: pa = next_a
			if next_b != pb and Vector3(contact_test.call(next_b,RADIUS,false)).z<=0: pb = next_b
			a[0]=pa.x; a[1]=pa.y; b[0]=pb.x; b[1]=pb.y
		if state.track_elevated: continue
		for tyre: Array in state.loose_tyres:
			var p := Vector2(tyre[0],tyre[1])
			var delta: Vector2 = p-state.position
			var contact: float = config.collision_radius+RADIUS
			if delta.length()<contact:
				var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
				state.position = p-normal*contact
