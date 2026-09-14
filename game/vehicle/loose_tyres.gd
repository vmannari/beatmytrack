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
	for iteration: int in range(16):
		for index: int in range(count):
			var speed: float = velocities[index].length()
			var reduction: float = minf(speed,friction[index])
			velocities[index] = velocities[index].move_toward(Vector2.ZERO,reduction)
			friction[index] -= reduction
			if state.track_elevated: continue
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(points[index],from,state.position)
			var delta: Vector2 = points[index]-near
			if delta.length() > config.collision_radius+RADIUS+0.005: continue
			var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
			var approach: float = (state.velocity-velocities[index]).dot(normal)
			if approach > 0:
				var impulse: float = approach/(1.0/config.mass+1.0/MASS)
				state.velocity -= normal*impulse/config.mass
				velocities[index] += normal*impulse/MASS
				if iteration == 0: state.collision_count += 1
		for pair: Vector2i in pairs:
			var delta: Vector2 = points[pair.y]-points[pair.x]
			var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else Vector2.RIGHT
			if delta.length()>1.005 and (delta+(velocities[pair.y]-velocities[pair.x])*step_seconds).length()>1.0: continue
			var approach: float = (velocities[pair.x]-velocities[pair.y]).dot(normal)
			if approach > 0:
				velocities[pair.x] -= normal*approach*0.5
				velocities[pair.y] += normal*approach*0.5
	for index: int in range(count):
		var tyre: Array = state.loose_tyres[index]
		var p: Vector2 = points[index]
		var velocity: Vector2 = velocities[index]
		var motion: Vector2 = velocity*step_seconds
		var steps: int = maxi(1,ceili(motion.length()/0.2))
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
			var ca: Vector3 = contact_test.call(pa-correction,RADIUS,false)
			var cb: Vector3 = contact_test.call(pb+correction,RADIUS,false)
			if ca.z<=0: pa -= correction
			if cb.z<=0: pb += correction
			a[0]=pa.x; a[1]=pa.y; b[0]=pb.x; b[1]=pb.y
		if state.track_elevated: continue
		for tyre: Array in state.loose_tyres:
			var p := Vector2(tyre[0],tyre[1])
			var delta: Vector2 = p-state.position
			var contact: float = config.collision_radius+RADIUS
			if delta.length()<contact:
				var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
				state.position = p-normal*contact
