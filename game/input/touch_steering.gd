class_name TouchSteering
extends RefCounted
## Presentation-only relative touch axes; the canonical DriveFrame stays unchanged.
const FULL_TRAVEL_RATIO: float = 0.25
const DEAD_ZONE_RATIO: float = 0.12

static func axis(displacement: float, travel: float) -> float:
	var distance: float = maxf(travel,1.0)
	var dead_zone: float = distance*DEAD_ZONE_RATIO
	return signf(displacement)*clampf((absf(displacement)-dead_zone)/(distance-dead_zone),0.0,1.0)

static func sample(point: Vector2, origin: Vector2, rect: Rect2) -> float:
	# Vertical drift never reduces horizontal steering, including joystick artwork.
	return axis(point.x-origin.x,rect.size.x*FULL_TRAVEL_RATIO)
