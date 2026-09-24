class_name ControlLayout
extends RefCounted
## Positions describe travel within the safe driving area, never physical pixels.
const METHODS: Array[String] = ["buttons", "horizontal", "joystick"]
const KEYS: Array[String] = ["buttons", "horizontal", "joystick", "accelerator", "brake"]

static func preset(left: bool = false, legacy_scale: float = 1.0) -> Dictionary:
	var result: Dictionary = {"version":1,"steering_type":"buttons"}
	for key: String in KEYS:
		var x: float = 0.01 if key in METHODS else (0.98 if key == "accelerator" else 0.79)
		result[key] = {"x":1.0-x if left else x,"y":1.0,"scale":legacy_scale,"opacity":1.0}
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("steering_type") not in METHODS: return false
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
	return saved.duplicate(true) if valid(saved) else preset(bool(settings.get("left_handed",false)),float(settings.get("touch_scale",1.0)))

static func extent(key: String, scale_value: float) -> Vector2:
	return (Vector2(292,192) if key == "buttons" else Vector2(244,112) if key == "horizontal" else Vector2(156,156) if key == "joystick" else Vector2(168,208) if key == "accelerator" else Vector2(156,176))*scale_value

static func rect(config: Dictionary, key: String, area: Rect2) -> Rect2:
	var item: Dictionary = config[key]
	var dimensions: Vector2 = extent(key,float(item.scale)).min(area.size)
	return Rect2(area.position + (area.size-dimensions)*Vector2(item.x,item.y),dimensions)

static func move(config: Dictionary, key: String, top_left: Vector2, area: Rect2) -> void:
	var travel: Vector2 = (area.size-rect(config,key,area).size).max(Vector2.ONE)
	var normalized: Vector2 = ((top_left-area.position)/travel).clamp(Vector2.ZERO,Vector2.ONE)
	config[key].x = normalized.x
	config[key].y = normalized.y
