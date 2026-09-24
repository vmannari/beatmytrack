class_name TouchSteering
extends RefCounted
## UI-only adapters. Future tilt sources can submit the same normalized command.
static func sample(method: String, point: Vector2, rect: Rect2) -> float:
	var radius: float = rect.size.x*0.4
	var value: float = clampf((point.x-rect.get_center().x)/maxf(radius,1.0),-1.0,1.0)
	if method == "joystick":
		value = ((point-rect.get_center())/maxf(radius,1.0)).limit_length(1.0).x
		if absf(value) < 0.08: return 0.0
	return value
