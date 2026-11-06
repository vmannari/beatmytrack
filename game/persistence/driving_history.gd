extends RefCounted
## Completed local races, committed atomically with their personal bests.
## No retrospective allocation of old aggregate distance to individual cars.
const MAX_TRACKS: int = 1000

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1: return false
	if not AchievementProgress.whole(value.version): return false
	if not value.get("cars") is Dictionary or value.cars.size() > VehicleCatalog.ALL_IDS.size(): return false
	if not value.get("tracks") is Dictionary or value.tracks.size() > MAX_TRACKS: return false
	for id: Variant in value.cars:
		var car: Variant = value.cars[id]
		if id not in VehicleCatalog.ALL_IDS or not car is Dictionary or car.size() != 2: return false
		if not AchievementProgress.whole(car.get("races")) or not AchievementProgress.whole(car.get("distance_m")): return false
	for id: Variant in value.tracks:
		if not id is String or id.is_empty() or id.length() > 128 or not AchievementProgress.whole(value.tracks[id]): return false
	return true

static func record(records: LocalRecords, track: NativeTrack, vehicle: String) -> void:
	if vehicle not in VehicleCatalog.ALL_IDS: return
	var data: Dictionary = records.settings.get("driving_history",{"version":1,"cars":{},"tracks":{}}).duplicate(true)
	var car: Dictionary = data.cars.get(vehicle,{"races":0,"distance_m":0})
	AchievementProgress.bump(car,"races")
	AchievementProgress.bump(car,"distance_m",maxi(0,roundi(track.route_length*RaceRules.LAPS)))
	data.cars[vehicle] = car
	var id: String = track.identity
	if not id.is_empty() and id.length() <= 128 and (data.tracks.has(id) or data.tracks.size() < MAX_TRACKS):
		AchievementProgress.bump(data.tracks,id)
	records.settings.driving_history = data
