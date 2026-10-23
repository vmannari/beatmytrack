extends RefCounted
## Stable cosmetic IDs and proposed earned-coin prices. Stock/paint/stickers stay free.
const MAX_COINS: int = 2147483647

static func items() -> Dictionary:
	var result: Dictionary = {}
	for pattern: Dictionary in LiveryCatalog.patterns: result["livery/"+str(pattern.id)] = 500
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			if option[0] != "stock": result["kit/compact/"+category+"/"+str(option[0])] = 750
	return result

static func free_item(id: String) -> bool:
	if id == "livery/plain": return true
	for category: String in VehicleCustomisation.CATEGORIES:
		if id == "kit/compact/"+category+"/stock": return true
	return false

static func valid_owned(value: Variant) -> bool:
	if not value is Array or value.size() > items().size(): return false
	var known: Dictionary = items()
	var seen: Dictionary = {}
	for id: Variant in value:
		if not id is String or not known.has(id) or seen.has(id): return false
		seen[id] = true
	return true

static func whole(value: Variant, limit: int = MAX_COINS) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= limit and float(value) == floorf(float(value))

static func valid_guest(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not whole(value.get("version"),1) or int(value.version) != 1: return false
	return whole(value.get("balance")) and valid_owned(value.get("owned")) and whole(value.get("sequence"))

static func valid_wallet(value: Variant) -> bool:
	if not value is Dictionary or not whole(value.get("schema"),1) or int(value.schema) != 1 or not whole(value.get("balance")) or not whole(value.get("revision")) or not valid_owned(value.get("owned")): return false
	if not value.get("prices") is Dictionary or value.prices.size() > 256: return false
	for id: Variant in value.prices:
		if not id is String or not whole(value.prices[id],1000000) or value.prices[id] == 0: return false
	return true

static func legacy(settings: Dictionary) -> Array:
	var result: Array = []
	for car: String in VehicleCatalog.IDS:
		var pattern: String = str(VehicleLivery.for_car(settings,car).pattern)
		if pattern != "plain" and "livery/"+pattern not in result: result.append("livery/"+pattern)
	var kits: Dictionary = VehicleCustomisation.for_car(settings,"compact")
	for category: String in VehicleCustomisation.CATEGORIES:
		if kits[category] != "stock": result.append("kit/compact/"+category+"/"+str(kits[category]))
	return result
