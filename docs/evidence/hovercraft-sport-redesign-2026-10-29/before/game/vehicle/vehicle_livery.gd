class_name VehicleLivery
extends RefCounted
## Current local cosmetic data. File upgrades live at the persistence boundary.
const VERSION: int = 2
const SLOTS: Array[String] = ["body", "accent", "detail"]
const SURFACES: Array[String] = ["hood", "roof"]
# Read-only compatibility for saved and server-acknowledged appearances.
# Retired designs have no artwork or selectable catalogue entries.
const RETIRED_STICKERS: Array[String] = [
	"zelvora","vorqen","talvexa","orynth","keldrift","velqor",
	"myrvanta","quorven","draxelle","selyth","auvrion","rhexori"]

static func empty_sticker() -> Dictionary:
	return {"id":"none", "x":0.5, "y":0.5, "size":0.62, "rotation":0.0}

static func defaults(id: String) -> Dictionary:
	return {"version":VERSION, "colors":{
		"body":str({"compact":"30627d", "pickup":"944638", "classic":"739181", "formula":"c8ad58", "kart":"b96d43", "forklift":"d5a62d", "electric":"638d86", "hovercraft":"698d87"}.get(id,"30627d")),
		"accent":"e0d5b5" if id == "compact" else "263c43" if id == "electric" else "d9d0b7", "detail":"9ba8ab" if id == "electric" else "c78e4c"},
		"pattern":"plain", "stickers":{"hood":empty_sticker(), "roof":empty_sticker()}}

static func _color(value: Variant) -> bool:
	if not value is String or value.length() != 6: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("version") != VERSION or value.size() != 4: return false
	var colors: Variant = value.get("colors")
	if not colors is Dictionary or colors.size() != SLOTS.size(): return false
	for slot: String in SLOTS:
		if not _color(colors.get(slot)): return false
	if not value.get("pattern") is String: return false
	if value.pattern != "plain" and LiveryCatalog.pattern_index(value.pattern) < 0: return false
	var stickers: Variant = value.get("stickers")
	if not stickers is Dictionary or stickers.size() != 2: return false
	for surface: String in SURFACES:
		var sticker: Variant = stickers.get(surface)
		if not sticker is Dictionary or sticker.size() != 5 or not sticker.get("id") is String: return false
		if sticker.id != "none" and LiveryCatalog.sticker_index(sticker.id) < 0 and sticker.id not in RETIRED_STICKERS: return false
		if not _number(sticker.get("x"),0,1) or not _number(sticker.get("y"),0,1): return false
		if not _number(sticker.get("size"),0.2,0.95) or not _number(sticker.get("rotation"),-180,180): return false
	return true

static func normalize(value: Dictionary, id: String) -> Dictionary:
	if not valid(value): return defaults(id)
	var current: Dictionary = value.duplicate(true)
	current.version = VERSION
	for surface: String in SURFACES:
		if current.stickers[surface].id in RETIRED_STICKERS:
			current.stickers[surface].id = "none"
	return current

static func for_car(settings: Dictionary, id: String) -> Dictionary:
	var value: Variant = settings.get("vehicle_liveries", {}).get(id, {})
	return normalize(value, id) if value is Dictionary else defaults(id)

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > VehicleCatalog.ALL_IDS.size(): return false
	for id: Variant in value:
		if not id is String or id not in VehicleCatalog.ALL_IDS or not valid(value[id]): return false
	return true

static func decorated(value: Dictionary, id: String) -> bool:
	return value.get("pattern", "plain") != "plain" or value.stickers.hood.id != "none" or (LiveryCatalog.has_roof(id) and value.stickers.roof.id != "none")
