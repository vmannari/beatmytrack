class_name PlaygroundData
extends Resource
## Visual and collision builders consume the same authored geometry.

@export var identity: String = "handling-yard-v1"
@export var half_extent: Vector2 = Vector2(48.0, 60.0)
@export var spawn: Vector2 = Vector2(0.0, -35.0)
@export var spawn_heading: float = 0.0
# Vector3 uses x,y as planar centre and z as radius. Stable array collision order.
@export var islands: Array[Vector3] = [Vector3(-23.0, 10.0, 5.0), Vector3(23.0, 10.0, 5.0)]


func surface_factors(_state: VehicleState) -> Vector2:
	return Vector2(1.0, 0.0)


func tire_pickup(_state: VehicleState) -> float:
	return 0.0 # Clean paved yard; native surfaces override this material property.


func resolve(state: VehicleState, from: Vector2, config: HandlingConfig) -> void:
	# Swept circle against circle: even injected high-speed steps cannot tunnel.
	for island: Vector3 in islands:
		var center := Vector2(island.x, island.y)
		var radius: float = island.z + config.collision_radius
		var movement: Vector2 = state.position - from
		var offset: Vector2 = from - center
		var hit: bool = false
		if offset.length_squared() < radius * radius:
			var normal: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.RIGHT
			state.position = center + normal * (radius + 0.001)
			_bounce(state, normal, config)
			continue
		var a: float = movement.length_squared()
		if a > 0.000001:
			var b: float = 2.0 * offset.dot(movement)
			var c: float = offset.length_squared() - radius * radius
			var discriminant: float = b * b - 4.0 * a * c
			if discriminant >= 0.0:
				var fraction: float = (-b - sqrt(discriminant)) / (2.0 * a)
				if fraction >= 0.0 and fraction <= 1.0:
					state.position = from + movement * fraction
					hit = true
		if hit:
			var normal: Vector2 = (state.position - center).normalized()
			state.position += normal * 0.001
			_bounce(state, normal, config)
	# Small inward separation avoids float32 Vector2 rounding outside the boundary.
	var limit: Vector2 = half_extent - Vector2.ONE * (config.collision_radius + 0.001)
	if absf(state.position.x) > limit.x:
		var side: float = signf(state.position.x)
		state.position.x = side * limit.x
		_bounce(state, Vector2(-side, 0.0), config)
	if absf(state.position.y) > limit.y:
		var side: float = signf(state.position.y)
		state.position.y = side * limit.y
		_bounce(state, Vector2(0.0, -side), config)


func _bounce(state: VehicleState, normal: Vector2, config: HandlingConfig) -> void:
	var inward_speed: float = state.velocity.dot(normal)
	if inward_speed >= 0.0:
		return
	var energy: float = config.mass * state.velocity.length_squared() + config.rotational_inertia * state.yaw_rate * state.yaw_rate
	# The circle collider has no contact lever arm. Approximate front/rear
	# leverage from the body axes: oblique hits turn it, centred hits do not.
	var turn: float = -normal.dot(state.forward()) * normal.dot(state.right()) * -inward_speed * config.collision_turn_strength
	var tangent: Vector2 = state.velocity - normal * inward_speed
	# Small inward speeds are sustained rubbing, not a fresh crash. Preserve
	# tangential travel and gently steer the chassis parallel to the barrier.
	var impact: float = smoothstep(0.0, config.wall_slide_speed, -inward_speed)
	state.velocity = tangent * sqrt(1.0 - config.collision_energy_loss * impact) - normal * inward_speed * config.restitution * impact
	var alignment_yaw: float = -normal.dot(state.forward()) * normal.dot(state.right()) * config.wall_alignment_rate
	var contact_yaw: float = lerpf(state.yaw_rate, alignment_yaw, 0.25)
	var rotation_budget: float = maxf(0.0, energy - config.mass * state.velocity.length_squared())
	var yaw_limit: float = minf(config.maximum_yaw_rate, sqrt(rotation_budget / config.rotational_inertia))
	state.yaw_rate = clampf(lerpf(contact_yaw, state.yaw_rate * (1.0 - config.collision_energy_loss) + turn, impact), -yaw_limit, yaw_limit)
	state.collision_count += 1


func step_props(_state: VehicleState, _from: Vector2, _config: HandlingConfig, _step_seconds: float) -> void:
	pass


func launch_jump(_state: VehicleState, _previous: Vector2) -> void:
	pass


func tire_fluids(_state: VehicleState) -> Vector2:
	return Vector2.ZERO
