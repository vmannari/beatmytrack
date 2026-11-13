class_name LiveryCatalog
extends RefCounted
## Original editable vector art; shared textures are loaded on demand.
const ROOT: String = "res://assets/liveries/"
static var patterns: Array = (preload("res://assets/liveries/catalog.json") as JSON).data
static var stickers: Array = (preload("res://assets/liveries/stickers.json") as JSON).data
static var textures: Dictionary = {}
static var mask_order: Array[String] = []

static func pattern_index(id: String) -> int:
	for index: int in range(patterns.size()):
		if patterns[index].id == id: return index
	return -1

static func sticker_index(id: String) -> int:
	for index: int in range(stickers.size()):
		if stickers[index].id == id: return index
	return -1

static func texture(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load(ROOT + file + ".svg")
		if pattern_index(file) >= 0:
			mask_order.append(file)
			if mask_order.size() > 4: textures.erase(mask_order.pop_front())
	return textures[file]

static func has_roof(id: String) -> bool:
	return VehicleCatalog.model_id(id) in ["compact", "pickup", "classic", "electric", "hovercraft"]

static func sticker_label(id: String, panel: String) -> String:
	return "Rear" if id == "forklift" and panel == "hood" else panel.capitalize()

static func projection(id: String) -> Dictionary:
	id = VehicleCatalog.model_id(id)
	return {
		"hovercraft": {"bounds":Vector3(2.32,1.42,4.26), "hood":Vector4(-0.36,-1.78,0.72,0.60), "roof":Vector4(-0.17,-0.25,0.34,0.68), "levels":Vector2(0.75,1.03)},
		"electric": {"bounds":Vector3(1.92,1.52,4.60), "hood":Vector4(-0.69,-2.04,1.38,1.03), "roof":Vector4(-0.61,-0.34,1.22,1.00), "levels":Vector2(0.94,1.48)},
		"compact": {"bounds":Vector3(1.76,1.52,4.18), "hood":Vector4(-0.69,-1.96,1.38,0.88), "roof":Vector4(-0.56,-0.32,1.12,1.38), "levels":Vector2(0.90,1.43)},
		"pickup": {"bounds":Vector3(2.04,1.95,5.40), "hood":Vector4(-0.85,-2.48,1.70,1.27), "roof":Vector4(-0.68,-0.65,1.36,0.83), "levels":Vector2(1.24,1.88)},
		"classic": {"bounds":Vector3(1.82,1.36,4.20), "hood":Vector4(-0.60,-1.85,1.20,1.03), "roof":Vector4(-0.53,-0.18,1.06,0.63), "levels":Vector2(0.77,1.29)},
		"formula": {"bounds":Vector3(1.83,0.86,4.58), "hood":Vector4(-0.24,-1.78,0.48,1.30), "roof":Vector4(0,0,1,1), "levels":Vector2(0.46,10)},
		"kart": {"bounds":Vector3(1.52,0.65,2.70), "hood":Vector4(-0.48,-1.29,0.96,0.42), "roof":Vector4(0,0,1,1), "levels":Vector2(0.36,10)},
		# The existing primary sticker slot maps onto rear X/-Y, between the lamps.
		"forklift": {"bounds":Vector3(1.88,2.89,4.24), "hood":Vector4(-0.39,-1.24,0.78,0.44), "roof":Vector4(0,0,1,1), "levels":Vector2(1.54,10)}
	}.get(id, {})
