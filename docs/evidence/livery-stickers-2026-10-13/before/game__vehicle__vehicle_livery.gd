class_name VehicleLivery
extends RefCounted
## Versioned cosmetic colors. Independent of handling, tickets and PB keys.
const VERSION: int = 1
const SLOTS: Array[String] = ["body", "accent"]

static func defaults(id: String) -> Dictionary:
	return {"version":VERSION, "colors":{
		"body":str({"compact":"30627d", "pickup":"944638", "classic":"739181", "formula":"c8ad58", "kart":"b96d43"}.get(id,"30627d")),
		"accent":"e0d5b5" if id == "compact" else "d9d0b7"}}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2 or value.get("version") != VERSION: return false
	var colors: Variant = value.get("colors")
	if not colors is Dictionary or colors.size() != SLOTS.size(): return false
	for slot: String in SLOTS:
		var color: Variant = colors.get(slot)
		if not color is String or color.length() != 6: return false
		for character: String in color:
			if character not in "0123456789abcdef": return false
	return true

static func for_car(settings: Dictionary, id: String) -> Dictionary:
	var value: Variant = settings.get("vehicle_liveries", {}).get(id, {})
	return value.duplicate(true) if valid(value) else defaults(id)

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > VehicleCatalog.IDS.size(): return false
	for id: Variant in value:
		if not id is String or id not in VehicleCatalog.IDS or not valid(value[id]): return false
	return true
