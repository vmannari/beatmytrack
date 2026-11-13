extends RefCounted
## One untimed opening lap, then one independently judged lap per cutoff.
const PERCENTILES: Array[int] = [75,60,50,40,30,20,10,5,1]
const LAPS: int = 10
var limits: Array[float] = []
var checked_laps: int = 0
var passed: int = 0
var eliminated: bool = false
var complete: bool = false

func configure(data: Dictionary, version: String, vehicle: String) -> bool:
	limits.clear()
	reset()
	if data.get("policy") != "daily-flying-elimination-v1" or str(data.get("version_id","")) != version or str(data.get("vehicle_id","")) != vehicle: return false
	if int(data.get("tick_rate",0)) != 120 or int(data.get("population",0)) <= 0: return false
	var rows: Variant = data.get("cutoffs",[])
	if not rows is Array or rows.size() != PERCENTILES.size(): return false
	var previous: float = INF
	var prepared: Array[float] = []
	for index: int in range(rows.size()):
		if not rows[index] is Dictionary: return false
		var row: Dictionary = rows[index]
		var ticks: float = float(row.get("lap_ticks",0))
		if int(row.get("percentile",0)) != PERCENTILES[index] or not is_finite(ticks) or ticks <= 0 or ticks > 216000 or ticks != floor(ticks) or ticks > previous: return false
		prepared.append(ticks/120.0)
		previous = ticks
	limits = prepared
	return true

func reset() -> void:
	checked_laps = 0
	passed = 0
	eliminated = false
	complete = false

func observe(session: TrackSession) -> void:
	# Rebuild after an authorised rewind, using the restored completed laps.
	if session.lap_times.size() < checked_laps: reset()
	if eliminated or complete or limits.size() != PERCENTILES.size(): return
	while checked_laps < session.lap_times.size():
		var index: int = checked_laps
		checked_laps += 1
		if index == 0: continue
		if session.lap_times[index] > limits[index-1] + 0.000000001:
			eliminated = true
			session.finished = true
			return
		passed += 1
		if passed == PERCENTILES.size():
			complete = true
			session.finished = true
			return

static func time_text(seconds: float) -> String:
	var ms: int = roundi(seconds*1000.0)
	return "%d:%02d.%03d" % [ms/60000,(ms/1000)%60,ms%1000]
