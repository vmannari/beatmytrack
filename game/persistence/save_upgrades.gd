extends RefCounted
## Input-only save upgrades. Live controls, paint and records accept current data.
## The caller validates the complete result and commits through its atomic save.
const MAX_TIME_MS: int = 2147483647

static func prepare(data: Variant) -> Dictionary:
	if not data is Dictionary or data.size() != 3 or not data.get("records") is Dictionary or not data.get("settings") is Dictionary: return {}
	if not _whole(data.get("schema"),1,2): return {}
	var pending: bool = int(data.schema) == 1 or data.settings.has("music_records")
	if data.settings.get("control_layout") is Dictionary and data.settings.control_layout.get("version") == 1: pending = true
	if data.settings.get("vehicle_liveries") is Dictionary:
		for value: Variant in data.settings.vehicle_liveries.values():
			if value is Dictionary and value.get("version") == 1: pending = true
	if data.settings.has("music_record"):
		var library = preload("res://soundtrack/record_library.gd")
		if data.settings.music_record != library.selected(data.settings).id: pending = true
	if not pending: return data
	var result: Dictionary = data.duplicate(true)
	if int(data.schema) == 1:
		for key: Variant in result.records:
			var value: Variant = result.records[key]
			if not value is Dictionary or value.size() != 2: return {}
			for field: String in ["race","flying"]:
				if not _number(value.get(field)) or float(value[field]) < 0.001 or float(value[field]) > float(MAX_TIME_MS)/1000.0: return {}
			result.records[key] = {"race_ms":roundi(float(value.race)*1000.0),"flying_ms":roundi(float(value.flying)*1000.0)}
	result.schema = 2
	var settings: Dictionary = result.settings
	if settings.get("control_layout") is Dictionary and settings.control_layout.get("version") == 1:
		settings.control_layout = upgrade_layout(settings.control_layout)
		if settings.control_layout.is_empty(): return {}
	if settings.get("vehicle_liveries") is Dictionary:
		for car: Variant in settings.vehicle_liveries:
			var value: Variant = settings.vehicle_liveries[car]
			if value is Dictionary and value.get("version") == 1:
				var upgraded: Dictionary = upgrade_livery(value,str(car))
				if upgraded.is_empty(): return {}
				settings.vehicle_liveries[car] = upgraded
	if settings.has("music_records"):
		if not _old_music_collection(settings.music_records): return {}
		settings.erase("music_records")
	if settings.has("music_record"):
		var selected: Variant = settings.music_record
		if not selected is String: return {}
		var records = preload("res://soundtrack/record_library.gd")
		if not records.valid_id(selected) and not _old_music_id(selected): return {}
		settings.music_record = records.selected(settings).id
	return result

static func upgrade_livery(value: Dictionary, car: String) -> Dictionary:
	if car not in VehicleCatalog.IDS or value.size() != 2 or value.get("version") != 1: return {}
	var colors: Variant = value.get("colors")
	if not colors is Dictionary or colors.size() != 2: return {}
	for key: String in ["body","accent"]:
		if not VehicleLivery._color(colors.get(key)): return {}
	var result: Dictionary = VehicleLivery.defaults(car)
	result.colors.body = colors.body
	result.colors.accent = colors.accent
	return result

static func _valid_old_layout(value: Dictionary) -> bool:
	if value.get("version") != 1 or value.get("steering_type") not in ControlLayout.METHODS: return false
	for key: String in ["buttons","horizontal","joystick","accelerator","brake"]:
		if not value.get(key) is Dictionary: return false
		for field: String in ["x","y","scale","opacity"]:
			var number: Variant = value[key].get(field)
			if not _number(number): return false
			var low: float = 0.65 if field == "scale" else 0.2 if field == "opacity" else 0.0
			if float(number) < low or float(number) > (1.6 if field == "scale" else 1.0): return false
	return true

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _whole(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func upgrade_layout(saved: Dictionary) -> Dictionary:
	if saved.get("version") == 2: return saved.duplicate(true)
	if not _valid_old_layout(saved): return {}
	var result: Dictionary = ControlLayout.preset()
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
			ControlLayout.move(result, key, start + Vector2(offset, 0), area)
	return result

static func _old_music_id(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func _old_music_collection(value: Variant) -> bool:
	if not value is Array or value.size()>12: return false
	var ids: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size()!=3 or not _old_music_id(item.get("id")) or ids.has(item.id): return false
		if item.get("format") not in ["mp3","ogg","wav"]: return false
		var title: Variant = item.get("title")
		if not title is String or title.strip_edges().is_empty() or title.length()>64: return false
		for character: String in title:
			if character.unicode_at(0)<32: return false
		ids[item.id] = true
	return true

