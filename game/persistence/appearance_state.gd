extends RefCounted
## The acknowledged server values live in the same atomic save as local edits.
const KEY: String = "vehicle_appearance_sync"

static func car(settings: Dictionary, id: String) -> Dictionary:
	return normalized_car({"vehicle_id":id,"livery":VehicleLivery.for_car(settings,id),"customisation":VehicleCustomisation.for_car(settings,id)})

static func normalized_car(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.livery.version = VehicleLivery.VERSION
	result.customisation.version = VehicleCustomisation.VERSION
	for panel: String in VehicleLivery.SURFACES:
		for field: String in ["x","y","size","rotation"]:
			result.livery.stickers[panel][field] = float(result.livery.stickers[panel][field])
	return result

static func normalized_collection(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in value: result[id] = normalized_car(value[id])
	return result

static func authored(settings: Dictionary, id: String) -> bool:
	return settings.get("vehicle_liveries",{}).has(id) or settings.get("vehicle_customisation",{}).has(id)

static func valid_car(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or value.get("vehicle_id") not in VehicleCatalog.ALL_IDS: return false
	if not VehicleLivery.valid(value.get("livery")) or value.livery.version != VehicleLivery.VERSION: return false
	if not VehicleCustomisation.valid(value.get("customisation"),str(value.vehicle_id)): return false
	if not VehicleCustomisation.supported(str(value.vehicle_id)):
		for category: String in VehicleCustomisation.CATEGORIES:
			if value.customisation[category] != "stock": return false
	return true

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > VehicleCatalog.ALL_IDS.size(): return false
	for id: Variant in value:
		if not id is String or not valid_car(value[id]) or value[id].vehicle_id != id: return false
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not valid_collection(value.get("baseline")): return false
	for key: Variant in value:
		if key not in ["version","baseline","pending","rejected"]: return false
	if value.has("pending") and not valid_collection(value.pending): return false
	var rejected: Variant = value.get("rejected",{})
	if not rejected is Dictionary or rejected.size() > VehicleCatalog.ALL_IDS.size(): return false
	for id: Variant in rejected:
		if id not in VehicleCatalog.ALL_IDS or not rejected[id] is String or rejected[id].length() != 64: return false
		for letter: String in rejected[id]:
			if not letter in "0123456789abcdef": return false
	return true

static func baseline(settings: Dictionary) -> Dictionary:
	return normalized_collection(settings.get(KEY,{}).get("baseline",{}))

static func pending(settings: Dictionary) -> Dictionary:
	return normalized_collection(settings.get(KEY,{}).get("pending",{}))

static func apply(settings: Dictionary, value: Dictionary) -> void:
	var id: String = value.vehicle_id
	var liveries: Dictionary = settings.get("vehicle_liveries",{}).duplicate(true)
	liveries[id] = value.livery.duplicate(true)
	settings.vehicle_liveries = liveries
	if VehicleCustomisation.supported(id):
		var parts: Dictionary = settings.get("vehicle_customisation",{}).duplicate(true)
		parts[id] = value.customisation.duplicate(true)
		settings.vehicle_customisation = parts
