class_name ControlLayout
extends RefCounted
## Positions describe travel within the safe driving area, never physical pixels.
const METHODS: Array[String] = ["buttons", "horizontal", "joystick"]
const KEYS: Array[String] = ["steer_left", "steer_right", "horizontal", "joystick", "accelerator", "brake", "handbrake"]
const TITLES: Dictionary = {"steer_left":"Steer left", "steer_right":"Steer right", "horizontal":"Analog slider", "joystick":"Analog joystick", "accelerator":"Accelerator", "brake":"Brake", "handbrake":"Handbrake"}

static func preset(left: bool = false, scale_value: float = 1.0) -> Dictionary:
	var result: Dictionary = {"version":2,"steering_type":"buttons"}
	var positions: Dictionary = {"steer_left":0.01, "steer_right":0.16, "horizontal":0.01, "joystick":0.01, "handbrake":0.61, "brake":0.75, "accelerator":0.98}
	if left:
		positions.steer_left = 0.16
		positions.steer_right = 0.01
	for key: String in KEYS:
		var x: float = positions[key]
		result[key] = {"x":1.0-x if left else x,"y":1.0,"scale":scale_value,"opacity":1.0}
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 2 or value.get("steering_type") not in METHODS: return false
	for key: String in KEYS:
		if not value.get(key) is Dictionary: return false
		for field: String in ["x","y","scale","opacity"]:
			var number: Variant = value[key].get(field)
			if not (number is float or number is int) or not is_finite(float(number)): return false
			var minimum: float = 0.65 if field == "scale" else (0.2 if field == "opacity" else 0.0)
			var maximum: float = 1.6 if field == "scale" else 1.0
			if float(number) < minimum or float(number) > maximum: return false
	return true

static func from_settings(settings: Dictionary) -> Dictionary:
	var saved: Variant = settings.get("control_layout")
	if valid(saved): return saved.duplicate(true)
	return preset(bool(settings.get("left_handed",false)),float(settings.get("touch_scale",1.0)))

static func active_keys(config: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	if config.steering_type == "buttons": keys.append_array(["steer_left", "steer_right"])
	else: keys.append(str(config.steering_type))
	keys.append("handbrake")
	# Analog modes share one vertical gas/brake axis at the saved accelerator position.
	# Keep the separate brake preferences for switching back to buttons.
	if config.steering_type == "buttons": keys.append("brake")
	keys.append("accelerator")
	return keys

static func extent(key: String, scale_value: float) -> Vector2:
	var dimensions: Vector2 = Vector2(146,192) if key in ["steer_left", "steer_right"] else Vector2(244,112) if key == "horizontal" else Vector2(156,156) if key == "joystick" else Vector2(168,208) if key == "accelerator" else Vector2(128,176)
	return dimensions * scale_value

static func rect(config: Dictionary, key: String, area: Rect2) -> Rect2:
	var item: Dictionary = config[key]
	var dimensions: Vector2 = extent(key,float(item.scale)).min(area.size)
	return Rect2(area.position + (area.size-dimensions)*Vector2(item.x,item.y),dimensions)

static func move(config: Dictionary, key: String, top_left: Vector2, area: Rect2) -> void:
	var travel: Vector2 = (area.size-rect(config,key,area).size).max(Vector2.ONE)
	var normalized: Vector2 = ((top_left-area.position)/travel).clamp(Vector2.ZERO,Vector2.ONE)
	config[key].x = normalized.x
	config[key].y = normalized.y
