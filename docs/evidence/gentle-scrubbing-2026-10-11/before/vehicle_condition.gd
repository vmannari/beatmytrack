class_name VehicleCondition
extends RefCounted
## Local cosmetic data only. Never enters a race contract or upload.
const GRID: int = 16
const CELLS: int = GRID * GRID * GRID

static func read(records: LocalRecords, id: String) -> Dictionary:
	if records == null: return {}
	return records.settings.get("vehicle_conditions", {}).get(id, {}).duplicate(true)

static func save(records: LocalRecords, id: String, value: Dictionary) -> Error:
	if records == null: return OK
	if read(records, id) == value: return OK
	var collection: Dictionary = records.settings.get("vehicle_conditions", {}).duplicate(true)
	collection[id] = value.duplicate(true)
	records.settings.vehicle_conditions = collection
	return records.save_records()

static func valid_collection(value: Variant) -> bool:
	if not value is Dictionary or value.size() > VehicleCatalog.IDS.size(): return false
	for id: Variant in value:
		if id not in VehicleCatalog.IDS or not value[id] is Dictionary: return false
		var entry: Dictionary = value[id]
		if entry.size() not in [8, 11, 12] or entry.get("version") != 1: return false
		var fields: Array[String] = ["dirt", "snow", "wetness", "mud", "smudge"]
		if entry.size() >= 11: fields.append_array(["slow_dirt", "slow_snow"])
		for field: String in fields:
			var number: Variant = entry.get(field)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) < 0.0 or float(number) > 1.0: return false
		if not entry.get("color") is String or not Color.html_is_valid(entry.color): return false
		if not entry.get("wash") is String or entry.wash.length() > 5464 or Marshalls.base64_to_raw(entry.wash).size() != CELLS: return false
		if entry.size() >= 11 and (not entry.get("slow_wash") is String or entry.slow_wash.length() > 5464 or Marshalls.base64_to_raw(entry.slow_wash).size() != CELLS): return false
		if entry.size() == 12:
			var debt: Variant = entry.get("slow_recoat")
			if not (debt is int or debt is float) or not is_finite(float(debt)) or float(debt) < 0.0 or float(debt) > 0.02: return false
	return true
