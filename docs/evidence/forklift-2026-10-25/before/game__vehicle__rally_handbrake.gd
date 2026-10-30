class_name RallyHandbrake
extends RefCounted
## Original planar axle model; CMR sources establish driving behavior, not equations.

const ROTATION_INERTIA_SCALE: float = 1.35 # Slower rear-lock rotation gives time to release/correct.

static func forces(config: HandlingConfig, longitudinal: float, lateral: float, yaw: float, steering: float, grip: float, brake: float, recovery: float, dt: float) -> Vector3:
	var arm: float = config.wheelbase * 0.5
	var front_velocity := Vector2(lateral + yaw * arm, longitudinal)
	var rear_velocity := Vector2(lateral - yaw * arm, longitudinal)
	var front_side := Vector2(cos(steering), -sin(steering))
	var effective_mass: float = 1.0 / (1.0 / config.mass + arm * arm / config.rotational_inertia)
	var stiffness: float = minf(config.mass * config.lateral_response * 0.5, effective_mass / dt)
	var front_capacity: float = config.mass * config.lateral_grip * config.front_grip * grip * 0.5
	var rear_capacity: float = config.mass * config.lateral_grip * config.rear_grip * grip * 0.5
	var front_force: Vector2 = front_side * clampf(-front_velocity.dot(front_side) * stiffness, -front_capacity, front_capacity)
	var rear_lateral: float = lerpf(1.0, 0.35, recovery)
	var rear_rolling := Vector2(clampf(-rear_velocity.x * stiffness, -rear_capacity * rear_lateral, rear_capacity * rear_lateral),0)
	# The friction vector of a locked tire shares its budget between braking
	# and sideways resistance; rear wheels roll again immediately on release.
	var rear_locked: Vector2 = -rear_velocity.normalized() * minf(rear_capacity * 0.45, rear_velocity.length() * effective_mass / dt)
	var rear_force: Vector2 = rear_rolling.lerp(rear_locked,brake)
	var acceleration: Vector2 = (front_force + rear_force) / config.mass
	var torque: float = (front_force.x - rear_force.x) * arm
	return Vector3(acceleration.x,acceleration.y,torque / (config.rotational_inertia * ROTATION_INERTIA_SCALE))


const BACKWARD_CATCH_RATE: float = 12.0 # Dissipative assistance during the existing rear-grip recovery.

static func catch_backward(speed: float, recovery: float, grip: float, dt: float) -> float:
	return speed * exp(-BACKWARD_CATCH_RATE * recovery * clampf(grip,0.0,1.0) * dt)
