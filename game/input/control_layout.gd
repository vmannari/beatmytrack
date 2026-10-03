class_name ControlLayout
extends RefCounted
## Positions describe travel within the safe driving area, never physical pixels.
const METHODS: Array[String] = ["buttons", "horizontal", "joystick"]
const KEYS: Array[String] = ["steer_left", "steer_right", "horizontal", "joystick", "accelerator", "brake", "handbrake"]
const LEGACY_KEYS: Array[String] = ["buttons", "horizontal", "joystick", "accelerator", "brake"]
const TITLES: Dictionary = {"steer_left":"Steer left", "steer_right":"Steer right", "horizontal":"Analog slider", "joystick":"Analog joystick", "accelerator":"Accelerator", "brake":"Brake", "handbrake":"Handbrake"}

static func preset(left: bool = false, legacy_scale: float = 1.0) -> Dictionary:
	var result: Dictionary = {"version":2,"steering_type":"buttons"}
	var positions: Dictionary = {"steer_left":0.01, "steer_right":0.16, "horizontal":0.01, "joystick":0.01, "handbrake":0.61, "brake":0.75, "accelerator":0.98}
	if left:
		positions.steer_left = 0.16
		positions.steer_right = 0.01
	for key: String in KEYS:
		var x: float = positions[key]
		result[key] = {"x":1.0-x if left else x,"y":1.0,"scale":legacy_scale,"opacity":1.0}
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or (value.get("version") != 1 and value.get("version") != 2) or value.get("steering_type") not in METHODS: return false
	var keys: Array[String] = LEGACY_KEYS if value.version == 1 else KEYS
	for key: String in keys:
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
	if valid(saved): return upgrade(saved)
	return preset(bool(settings.get("left_handed",false)),float(settings.get("touch_scale",1.0)))

static func upgrade(saved: Dictionary) -> Dictionary:
	if saved.version == 2: return saved.duplicate(true)
	var result: Dictionary = preset()
	result.steering_type = saved.steering_type
	for key: String in ["horizontal", "joystick", "accelerator"]: result[key] = saved[key].duplicate(true)
	# Split grouped v1 regions in the original 1280x720 logical safe area.
	var area := Rect2(Vector2.ZERO, Vector2(1248, 520))
	for group: String in ["buttons", "brake"]:
		var old: Dictionary = saved[group]
		var extent_old: Vector2 = (Vector2(292,192) if group == "buttons" else Vector2(268,176)) * float(old.scale)
		var start: Vector2 = (area.size - extent_old) * Vector2(old.x, old.y)
		var split: Array[String] = []
		split.assign(["steer_left", "steer_right"] if group == "buttons" else ["handbrake", "brake"])
		for index: int in range(2):
			var key: String = split[index]
			result[key].scale = old.scale
			result[key].opacity = old.opacity
			var offset: float = (146.0 if group == "buttons" else 140.0) * float(old.scale) * index
			move(result, key, start + Vector2(offset, 0), area)
	return result

static func active_keys(config: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	if config.steering_type == "buttons": keys.append_array(["steer_left", "steer_right"])
	else: keys.append(str(config.steering_type))
	keys.append_array(["handbrake", "brake", "accelerator"])
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
