extends RefCounted
## Account-scoped cosmetic daily results; ordinary five-lap records remain independent.
const IO = preload("res://backend/atomic_json.gd")
const MAX_BYTES: int = 524288
const MAX_ENTRIES: int = 512
const PERCENTILES: Array[int] = [75,60,50,40,30,20,10,5,1]
const TITLES: Array[String] = ["No medal yet","Bronze","Silver","Gold","Elite"]

static func tier(passed: int) -> int:
	if passed >= 9: return 4
	if passed >= 6: return 3
	if passed >= 4: return 2
	return 1 if passed >= 1 else 0

static func contract(vehicle: String) -> String:
	return (str(Engine.get_version_info().hash)+VehicleSimulation.PHYSICS_VERSION+RaceRules.KEY+TrackCompiler.VERSION+JSON.stringify(VehicleCatalog.config(vehicle).snapshot(),"",true)).sha256_text()

static func identity(day: int, version: String, vehicle: String) -> String:
	return (str(day)+"/"+version+"/"+vehicle+"/"+contract(vehicle)).sha256_text()

static func load_entries(records: LocalRecords) -> Dictionary:
	if records == null: return {}
	var document: Dictionary = IO.read(records.path+".daily.json",MAX_BYTES)
	if document.get("schema") != 1 or not document.get("entries") is Dictionary or document.entries.size() > MAX_ENTRIES: return {}
	var result: Dictionary = {}
	for key: Variant in document.entries:
		var row: Variant = document.entries[key]
		if key is String and key.length() == 64 and valid(row): result[key] = row.duplicate(true)
	return result

static func valid(row: Variant) -> bool:
	if not row is Dictionary: return false
	for field: String in ["day","passed","best_ms"]:
		var value: Variant = row.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)): return false
	return int(row.day) >= 0 and int(row.passed) >= 0 and int(row.passed) <= 9 and int(row.best_ms) > 0 and int(row.best_ms) <= 1800000 and row.get("version") is String and row.get("vehicle") in VehicleCatalog.ALL_IDS

static func best(entries: Dictionary, day: int, version: String, vehicle: String) -> Dictionary:
	return entries.get(identity(day,version,vehicle),{}).duplicate(true)

static func commit(records: LocalRecords, day: int, version: String, vehicle: String, session: TrackSession, rules: RefCounted) -> bool:
	if records == null or day < 0 or version.is_empty() or session.lap_times.size() < 2 or not session.finished: return false
	var previous_document: Dictionary = IO.read(records.path+".daily.json",MAX_BYTES)
	if not previous_document.is_empty() and (previous_document.get("schema") != 1 or not previous_document.get("entries") is Dictionary): return false
	if previous_document.get("entries",{}).size() > MAX_ENTRIES: return false
	var fastest: float = INF
	for index: int in range(1,session.lap_times.size()): fastest = minf(fastest,session.lap_times[index])
	if not is_finite(fastest) or fastest <= 0: return false
	var entries: Dictionary = load_entries(records)
	var key: String = identity(day,version,vehicle)
	var previous: Dictionary = entries.get(key,{})
	entries[key] = {"day":day,"version":version,"vehicle":vehicle,"passed":maxi(int(previous.get("passed",0)),rules.passed),"best_ms":mini(int(previous.get("best_ms",1800000)),roundi(fastest*1000))}
	if not valid(entries[key]): return false
	# Keep five weeks for every car; never let history grow with repeated attempts.
	for old: String in entries.keys():
		if int(entries[old].day) < day-35: entries.erase(old)
	if entries.size() > MAX_ENTRIES: return false
	return IO.write(records.path+".daily.json",{"schema":1,"entries":entries},MAX_BYTES)

static func week(entries: Dictionary, day: int, vehicle: String) -> Array[int]:
	var monday: int = day-posmod(day+3,7)
	var result: Array[int] = []
	for offset: int in range(7):
		var award: int = -1 if monday+offset > day else 0
		for row: Dictionary in entries.values():
			if int(row.day) == monday+offset and row.vehicle == vehicle: award = maxi(award,tier(int(row.passed)))
		result.append(award)
	return result
