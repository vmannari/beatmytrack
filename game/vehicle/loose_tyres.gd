class_name LooseTyres
extends RefCounted
## Deterministic planar tyre stacks. State belongs to each run, never to track data.
const RADIUS: float = 0.5
const MASS: float = 260.0 # Effective contact mass for a resistant tyre stack.
const SLIDING_DECELERATION: float = 24.0

static func positions(document: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for object: Dictionary in document.get("objects",[]):
		if object.kind != "tyre_wall": continue
		var center := Vector2(object.position[0],object.position[1])
		for i: int in range(6): result.append(center+Vector2(i-2.5,0).rotated(deg_to_rad(float(object.rotation))))
	return result

static func step(state: VehicleState, origins: PackedVector2Array, contact_test: Callable, from: Vector2, config: HandlingConfig, step_seconds: float) -> void:
	if origins.is_empty(): return
	if state.loose_tyres.is_empty():
		for p: Vector2 in origins: state.loose_tyres.append([p.x,p.y,0.0,0.0,0.0])
	for tyre: Array in state.loose_tyres:
		var p := Vector2(tyre[0],tyre[1])
		var velocity := Vector2(tyre[2],tyre[3])
		if not state.track_elevated:
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(p,from,state.position)
			var delta: Vector2 = p-near
			var contact: float = config.collision_radius+RADIUS
			if delta.length_squared() < contact*contact:
				var normal: Vector2 = delta.normalized() if delta.length_squared() > 0.000001 else state.forward()
				var approach: float = (state.velocity-velocity).dot(normal)
				if approach > 0:
					var impulse: float = approach*1.1/(1.0/config.mass+1.0/MASS)
					state.velocity -= normal*impulse/config.mass
					velocity += normal*impulse/MASS
					state.collision_count += 1
		velocity = velocity.limit_length(30).move_toward(Vector2.ZERO,SLIDING_DECELERATION*step_seconds)
		var motion: Vector2 = velocity*step_seconds
		var steps: int = maxi(1,ceili(motion.length()/0.2))
		for i: int in range(steps):
			var candidate: Vector2 = p+motion/steps
			var collision: Vector3 = contact_test.call(candidate,RADIUS,false)
			if collision.z > 0:
				var normal := Vector2(collision.x,collision.y)
				velocity = velocity.bounce(normal)*0.25 if normal.length_squared() > 0.5 else Vector2.ZERO
				break
			p = candidate
		tyre[0] = p.x; tyre[1] = p.y
		tyre[2] = velocity.x; tyre[3] = velocity.y
		tyre[4] = fposmod(float(tyre[4])+velocity.length()*step_seconds/RADIUS,TAU)
