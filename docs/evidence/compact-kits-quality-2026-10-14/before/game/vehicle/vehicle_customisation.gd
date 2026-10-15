class_name VehicleCustomisation
extends RefCounted
## Local cosmetic part IDs. Never included in simulation, tickets or PB keys.
const VERSION: int = 1
const CATEGORIES: Array[String] = ["hood", "aero", "rims", "body"]
const LABELS: Dictionary = {"hood":"Hood", "aero":"Rear aero", "rims":"Rims", "body":"Body kits"}
const OPTIONS: Dictionary = {
	"hood":[["stock","Original"],["louvres","Twin louvres"],["scoop","Rally scoop"],["dome","Power dome"],
		["extractor","Track extractor"],["cowl","Raised cowl"],["twin_scoop","Twin intakes"],["reverse","Reverse intake"],["ribs","Pressed ribs"],["vented","Vented dome"]],
	"aero":[["stock","Original"],["lip","Roof lip"],["ducktail","Ducktail"],["wing","GT wing"],
		["touring","Hatch sweep"],["pedestal","Low rear wing"],["swan","Swan neck"],["biwing","Rear twin blade"],["rallywing","Rally hoop"],["endurance","Endurance rear"],
		["whale","Whale tail"],["drag","Drag deck"],["splitwing","Split wing"]],
	"rims":[["stock","Original"],["five","Forged five"],["split","Split six"],["turbine","Turbine"],
		["mesh","Cross mesh"],["dish","Deep dish"],["rallydisc","Rally disc"],["six","Sport six"],["ten","Slim ten"],["tri","Tri spoke"]],
	"body":[["stock","Original"],["street","Street"],["rally","Rally"],["club","Club sport"],
		["heritage","Heritage"],["touring","Touring"],["wide","Wide arch"],["endurance","Endurance"],["gravel","Gravel"],["urban","Urban sport"]]}

static func defaults() -> Dictionary:
	return {"version":VERSION,"hood":"stock","aero":"stock","rims":"stock","body":"stock"}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5 or value.get("version") != VERSION: return false
	for category: String in CATEGORIES:
		if not value.get(category) is String: return false
		var found: bool = false
		for option: Array in OPTIONS[category]:
			if value[category] == option[0]: found = true
		if not found: return false
	return true

static func for_car(settings: Dictionary, id: String) -> Dictionary:
	var collection: Variant = settings.get("vehicle_customisation",{})
	var value: Variant = collection.get(id,{}) if collection is Dictionary else {}
	if id != "compact" or not valid(value): return defaults()
	var normalized: Dictionary = value.duplicate(true)
	normalized.version = VERSION
	return normalized

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 1: return false
	for id: Variant in value:
		if id != "compact" or not valid(value[id]): return false
	return true
