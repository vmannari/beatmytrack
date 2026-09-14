class_name VehicleState
extends RefCounted
## Planar (x,y) -> world (x,0,-y). Heading 0 is +y; positive turns right.

var jump_height: float = 0.0
var jump_velocity: float = 0.0
var jump_cooldown: int = 0
var loose_tyres: Array = []
var light_props: Array = []
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var heading: float = 0.0
var yaw_rate: float = 0.0
var steering: float = 0.0
var grip: float = 1.0
var reverse_wait: float = 0.0
var tick: int = 0
var collision_count: int = 0
var route_index: int = -1
var track_elevated: bool = false
var tire_dirt: float = 0.0 # 0 clean, 1 fully coated; persists after leaving loose ground.


func forward() -> Vector2:
	return Vector2(sin(heading), cos(heading))


func right() -> Vector2:
	return Vector2(cos(heading), -sin(heading))


func slip_angle() -> float:
	if velocity.length_squared() < 0.25:
		return 0.0
	# Reverse uses its own travel-facing frame, not a spurious 180-degree slide.
	return atan2(velocity.dot(right()), maxf(absf(velocity.dot(forward())), 0.5))


func snapshot() -> Array:
	var result: Array = [position.x, position.y, velocity.x, velocity.y, heading, yaw_rate,
		steering, grip, reverse_wait, tick, collision_count, route_index, track_elevated, tire_dirt]
	result.append(loose_tyres.duplicate(true))
	result.append([jump_height,jump_velocity,jump_cooldown])
	result.append(light_props.duplicate(true))
	return result
