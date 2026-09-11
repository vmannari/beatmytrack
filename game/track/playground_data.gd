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
	var tangent: Vector2 = state.velocity - normal * inward_speed
	state.velocity = tangent * sqrt(1.0 - config.collision_energy_loss) - normal * inward_speed * config.restitution
	state.yaw_rate *= 1.0 - config.collision_energy_loss
	state.collision_count += 1
