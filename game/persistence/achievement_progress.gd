class_name AchievementProgress
extends RefCounted
## Profile-only presentation progress. Never enters canonical state or uploads.
static var _catalog: Dictionary = {}
const BIOMES: Array[String] = ["pine","desert","winter","storm","night_city"]
const MAX_VALUE: int = 9007199254740991

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://persistence/achievement_catalog.json"))
	return _catalog

static func empty() -> Dictionary:
	return {"metrics":{},"unlocked":{},"featured":[],"revision":0,"tracks":[]}

static func read(records: LocalRecords) -> Dictionary:
	return records.settings.get("achievements",empty()).duplicate(true) if records != null else empty()

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() not in [4,5]: return false
	if value.size() == 5:
		if not value.get("tracks") is Array or value.tracks.size() > 1000: return false
		var unique: Dictionary = {}
		for track: Variant in value.tracks:
			if not track is String or track.is_empty() or track.length() > 128 or unique.has(track): return false
			unique[track] = true
	if not value.get("metrics") is Dictionary or value.metrics.size() > 80: return false
	if not value.get("unlocked") is Dictionary or value.unlocked.size() > 130: return false
	if not value.get("featured") is Array or value.featured.size() > 5: return false
	if not whole(value.get("revision")): return false
	var metrics: Array[String] = ["clean_streak","pb_streak","customised_mask","car_mask","clean_car_mask"]
	var keys: Array[String] = []
	var ids: Array[String] = []
	for family: Dictionary in catalog().families:
		ids.append(family.id)
		metrics.append(family.metric)
		for i: int in range(family.tiers.size()): keys.append(family.id+"/"+str(i+1))
	for biome: String in BIOMES: metrics.append_array(["race_"+biome,"clean_"+biome])
	for car: String in VehicleCatalog.IDS: metrics.append_array(["cars_"+car,"clean_car_"+car])
	for key: Variant in value.metrics:
		if key not in metrics or not whole(value.metrics[key]): return false
	for key: Variant in value.unlocked:
		if key not in keys or not whole(value.unlocked[key]): return false
	var seen: Array = []
	for id: Variant in value.featured:
		if id not in ids or id in seen: return false
		seen.append(id)
	return true

static func whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_VALUE and float(value) == floorf(float(value))

static func normalized(value: Dictionary) -> Dictionary:
	var data: Dictionary = value.duplicate(true)
	data.revision = int(data.revision)
	for key: String in data.metrics: data.metrics[key] = int(data.metrics[key])
	for key: String in data.unlocked: data.unlocked[key] = int(data.unlocked[key])
	return data

static func update(records: LocalRecords, data: Dictionary) -> void:
	for family: Dictionary in catalog().families:
		if family.scope == "creator" or family.category in ["Rivalry","Social"]: continue
		for i: int in range(family.tiers.size()):
			var key: String = family.id+"/"+str(i+1)
			if float(data.metrics.get(family.metric,0)) >= float(family.tiers[i]) and not data.unlocked.has(key):
				data.unlocked[key] = int(Time.get_unix_time_from_system())
	data.revision = mini(int(data.revision)+1,MAX_VALUE)
	records.settings.achievements = data

static func bump(metrics: Dictionary, key: String, amount: int = 1) -> void:
	metrics[key] = mini(int(metrics.get(key,0))+amount,MAX_VALUE)

static func bits(mask: int) -> int:
	var result: int = 0
	for i: int in range(5): result += (mask >> i) & 1
	return result

static func race(records: LocalRecords, track: NativeTrack, vehicle: String, laps: Array[float], facts: Dictionary) -> void:
	if not facts.get("complete",false) or laps.size() != RaceRules.LAPS: return
	var data: Dictionary = read(records)
	var m: Dictionary = data.metrics
	bump(m,"races")
	bump(m,"distance_m",roundi(track.route_length*laps.size()))
	var identity: String = str(track.metadata.get("cloud_track_id",track.identity))
	if not data.has("tracks"): data.tracks = []
	if data.tracks.size() < 1000 and identity not in data.tracks:
		data.tracks.append(identity)
		m.tracks = data.tracks.size()
	var theme: String = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	bump(m,"race_"+theme)
	var car: int = VehicleCatalog.IDS.find(vehicle)
	if car >= 0: m.car_mask = int(m.get("car_mask",0)) | (1 << car)
	m.cars = bits(int(m.get("car_mask",0)))
	m.biomes = 0
	m.clean_biomes = 0
	var pb: bool = float(facts.get("previous",0)) > 0 and float(facts.total) < float(facts.previous)
	if pb: bump(m,"race_pb")
	if float(facts.get("previous_lap",0)) > 0 and float(facts.flying) < float(facts.previous_lap): bump(m,"lap_pb")
	m.pb_streak = int(m.get("pb_streak",0))+1 if pb else 0
	m.pb_streak_best = maxi(int(m.get("pb_streak_best",0)),int(m.pb_streak))
	var clean: bool = facts.get("incident_free",false)
	m.clean_streak = int(m.get("clean_streak",0))+1 if clean else 0
	m.clean_streak_best = maxi(int(m.get("clean_streak_best",0)),int(m.clean_streak))
	if clean:
		bump(m,"clean")
		bump(m,"clean_"+theme)
		if car >= 0: m.clean_car_mask = int(m.get("clean_car_mask",0)) | (1 << car)
	m.clean_cars = bits(int(m.get("clean_car_mask",0)))
	for biome: String in BIOMES:
		m.biomes += int(m.get("race_"+biome,0) > 0)
		m.clean_biomes += int(m.get("clean_"+biome,0) > 0)
	var average: float = 0.0
	for lap: float in laps: average += lap/laps.size()
	var spread: float = 0.0
	for lap: float in laps: spread = maxf(spread,absf(lap-average)/maxf(average,0.001))
	if spread <= 0.02: bump(m,"precision")
	if clean and spread <= 0.01: m.perfectionist = 1
	update(records,data)

static func customise(records: LocalRecords, vehicle: String) -> void:
	var data: Dictionary = read(records)
	var index: int = VehicleCatalog.IDS.find(vehicle)
	if index < 0: return
	data.metrics.customised_mask = int(data.metrics.get("customised_mask",0)) | (1 << index)
	data.metrics.customised = bits(int(data.metrics.customised_mask))
	update(records,data)

static func wash(records: LocalRecords) -> void:
	var data: Dictionary = read(records)
	bump(data.metrics,"washes")
	update(records,data)

static func tier(family: Dictionary, state: Dictionary) -> int:
	var result: int = 0
	for i: int in range(family.tiers.size()):
		if state.get("unlocked",{}).has(family.id+"/"+str(i+1)): result = i+1
	return result
