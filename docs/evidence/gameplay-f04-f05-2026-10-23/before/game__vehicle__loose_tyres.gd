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
	# Reuse derived arrays/pairs while positions are unchanged. Every canonical
	# row is still checked, so rewind/restores and in-place mutations invalidate
	# the broadphase without storing caches in snapshots or changing pair order.
	var work: Dictionary = state.get_meta(&"tyre_work",{})
	var rebuild: bool = work.is_empty() or int(work.count) != count
	if rebuild:
		var point_buffer: Array[Vector2] = []
		var velocity_buffer: Array[Vector2] = []
		var friction_buffer: Array[float] = []
		var normal_buffer: Array[Vector2] = []
		var pair_buffer: Array[Vector2i] = []
		var delta_buffer: Array[Vector2] = []
		var pair_normal_buffer: Array[Vector2] = []
		var touching_buffer: Array[bool] = []
		var candidate_buffer: Array[int] = []
		point_buffer.resize(count); velocity_buffer.resize(count); friction_buffer.resize(count); normal_buffer.resize(count)
		work = {"count":count,"points":point_buffer,"velocities":velocity_buffer,"friction":friction_buffer,"normals":normal_buffer,"pairs":pair_buffer,"deltas":delta_buffer,"pair_normals":pair_normal_buffer,"touching":touching_buffer,"buckets":{},"candidates":candidate_buffer,"separated":true,"geometry_ready":false}
		state.set_meta(&"tyre_work",work)
	var points: Array[Vector2] = work.points
	var velocities: Array[Vector2] = work.velocities
	var friction: Array[float] = work.friction
	var buckets: Dictionary = work.buckets
	var pairs: Array[Vector2i] = work.pairs
	var solver_active: bool = false
	for index: int in range(count):
		var tyre: Array = state.loose_tyres[index]
		var p := Vector2(tyre[0],tyre[1])
		if p != points[index]: rebuild = true
		points[index] = p
		velocities[index] = Vector2(tyre[2],tyre[3]).limit_length(30)
		if velocities[index] != Vector2.ZERO: solver_active = true
		friction[index] = SLIDING_DECELERATION*step_seconds
	if rebuild:
		buckets.clear(); pairs.clear()
		work.geometry_ready = false
		work.separated = true
		for index: int in range(count):
			var p: Vector2 = points[index]
			var cell := Vector2i(floori(p.x/1.6),floori(p.y/1.6))
			# The original stable index and neighbour order is retained exactly.
			for y: int in range(-1,2):
				for x: int in range(-1,2):
					for other: int in buckets.get(cell+Vector2i(x,y),[]):
						if p.distance_squared_to(points[other]) <= 1.6*1.6:
							pairs.append(Vector2i(other,index))
							if (p-points[other]).length() < 1.0: work.separated = false
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(index)
	# Accumulated friction has one per-tick budget. Iteration transmits the car's
	# available force through a pile, including static friction at rest.
	# Positions do not change during the impulse solver. Compute its contact
	# geometry once, retaining the original index and impulse order.
	var car_normals: Array[Vector2] = work.normals
	car_normals.fill(Vector2.ZERO)
	var candidates: Array[int] = work.candidates
	candidates.clear()
	if not state.track_elevated:
		var reach: float = config.collision_radius+RADIUS+0.005+0.0001
		var low := Vector2i(((from.min(state.position)-Vector2.ONE*reach)/1.6).floor())
		var high := Vector2i(((from.max(state.position)+Vector2.ONE*reach)/1.6).floor())
		if (high.x-low.x+1)*(high.y-low.y+1) <= 64:
			for y: int in range(low.y,high.y+1):
				for x: int in range(low.x,high.x+1):
					for index: int in buckets.get(Vector2i(x,y),[]): candidates.append(index)
			candidates.sort()
		else:
			for index: int in range(count): candidates.append(index)
	for index: int in candidates:
		var point: Vector2 = points[index]
		var normal := Vector2.ZERO
		if not state.track_elevated:
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(point,from,state.position)
			var delta: Vector2 = point-near
			if delta.length() <= config.collision_radius+RADIUS+0.005:
				normal = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
		car_normals[index] = normal
		if normal != Vector2.ZERO: solver_active = true
	# Separated, stationary stacks cannot change this tick: the swept car test
	# above also excludes car separation. Keep overlapping piles on the complete
	# solver path, including sub-ULP overlaps, to preserve exact contact results.
	if not solver_active:
		if work.separated:
			for tyre: Array in state.loose_tyres:
				tyre[4] = fposmod(float(tyre[4]),TAU)
			return
	var pair_deltas: Array[Vector2] = work.deltas
	var pair_normals: Array[Vector2] = work.pair_normals
	var pair_touching: Array[bool] = work.touching
	if not work.geometry_ready:
		pair_deltas.resize(pairs.size()); pair_normals.resize(pairs.size()); pair_touching.resize(pairs.size())
		for pair_index: int in range(pairs.size()):
			var pair: Vector2i = pairs[pair_index]
			var delta: Vector2 = points[pair.y]-points[pair.x]
			pair_deltas[pair_index] = delta
			pair_normals[pair_index] = delta.normalized() if delta.length_squared()>0.000001 else Vector2.RIGHT
			pair_touching[pair_index] = delta.length() <= 1.005
		work.geometry_ready = true
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
