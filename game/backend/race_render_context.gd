extends RefCounted
## Small presentation context, sampled outside canonical driving and never authority.
const FIELDS: Array[String] = ["schema_version","renderer","car_detail","viewport_width","viewport_height","scale_percent","frame_limit","vsync","refresh_hz"]
const RENDERERS: Array[String] = ["gl_compatibility","mobile","forward_plus","unknown"]
const DETAILS: Array[String] = ["full","simple","unknown"]
const VSYNC: Array[String] = ["disabled","enabled","adaptive","mailbox","unknown"]

static func capture(observer: Node, app: Node = null) -> Dictionary:
	var viewport: Viewport = observer.get_viewport()
	var size: Vector2 = viewport.get_texture().get_size() if viewport != null else Vector2.ZERO
	var renderer: String = RenderingServer.get_current_rendering_method()
	if renderer not in RENDERERS: renderer = "unknown"
	var detail: String = "unknown"
	var game: Node = app.get("game") if is_instance_valid(app) else null
	if is_instance_valid(game):
		var car: Node = game.get("car")
		if is_instance_valid(car): detail = "simple" if bool(car.get("simple_model")) else "full"
	var vsync: String = "unknown"
	var refresh: int = 0
	if DisplayServer.get_name() != "headless":
		var mode: int = DisplayServer.window_get_vsync_mode()
		if mode >= 0 and mode < 4: vsync = VSYNC[mode]
		var hz: float = DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
		if is_finite(hz) and hz > 0: refresh = clampi(roundi(hz),1,1000)
	return {"schema_version":1,"renderer":renderer,"car_detail":detail,"viewport_width":clampi(int(size.x),0,16384),"viewport_height":clampi(int(size.y),0,16384),"scale_percent":clampi(roundi(viewport.scaling_3d_scale*100.0),1,400) if viewport != null else 100,"frame_limit":clampi(Engine.max_fps,0,1000),"vsync":vsync,"refresh_hz":refresh}

static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != FIELDS.size() or not value.has_all(FIELDS): return {}
	if value.schema_version != 1 or value.renderer not in RENDERERS or value.car_detail not in DETAILS or value.vsync not in VSYNC: return {}
	var result: Dictionary = value.duplicate()
	for field: String in ["schema_version","viewport_width","viewport_height","scale_percent","frame_limit","refresh_hz"]:
		var number: Variant = value[field]
		var minimum: int = 1 if field in ["schema_version","scale_percent"] else 0
		var maximum: int = 1 if field == "schema_version" else 400 if field == "scale_percent" else 16384 if field.begins_with("viewport_") else 1000
		if not (number is int or number is float) or not is_finite(float(number)) or float(number) != float(int(number)) or number < minimum or number > maximum: return {}
		result[field] = int(number)
	return result
