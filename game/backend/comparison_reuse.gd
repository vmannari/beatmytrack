extends RefCounted
## Private presentation freshness; never authorizes results, scoring or rewards.
const LEGACY_SECONDS: int = 600
const MAX_SECONDS: int = 3600

static func ticks(value: Variant) -> int:
	return int(value) if value is int or value is float else 0

static func fresh(value: Dictionary, clock: int = -1) -> bool:
	if clock < 0: clock = int(Time.get_unix_time_from_system())
	var received: int = int(value.get("_fetched_at",0))
	if received <= 0 or clock < received or clock-received >= MAX_SECONDS: return false
	var packet: Dictionary = value.get("packet",{})
	if packet.is_empty(): return false
	if not packet.has("freshness"): return clock-received < LEGACY_SECONDS
	var freshness: Variant = packet.freshness
	if not freshness is Dictionary: return false
	for field: String in ["generated_at","expires_at"]:
		var number: Variant = freshness.get(field)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)): return false
	var generated: int = int(freshness.generated_at)
	var expires: int = int(freshness.expires_at)
	return generated > 0 and generated <= clock and expires > generated and clock < expires

static func matches(value: Dictionary, race_ticks: int, lap_ticks: int) -> bool:
	if not fresh(value): return false
	for pair: Array in [["race",race_ticks],["best_lap",lap_ticks]]:
		var wanted: int = pair[1]
		if wanted <= 0: continue
		var metric: Dictionary = value.packet.get(pair[0],{})
		var position: Variant = metric.get("comparison")
		if position is Dictionary and int(position.get("candidate_ticks",-1)) == wanted: continue
		if position == null and ticks(metric.get("own_best_ticks")) == wanted and int(metric.get("opponent_count",1)) == 0: continue
		var requested: Array = value.get("_candidate_ticks",[])
		if position == null and int(metric.get("opponent_count",1)) == 0 and requested.size() == 2 and int(requested[0 if pair[0] == "race" else 1]) == wanted: continue
		return false
	return true

static func same_bests(value: Dictionary, bests: Array) -> bool:
	if bests.is_empty(): return true
	var previous: Array = value.get("_best_ticks",[])
	if previous.size() != 2:
		previous = [value.packet.race.get("own_best_ticks",0),value.packet.best_lap.get("own_best_ticks",0)]
	return ticks(previous[0]) == ticks(bests[0]) and ticks(previous[1]) == ticks(bests[1])

static func frame_query(packet: Dictionary) -> String:
	var result: String = ""
	for pair: Array in [["race","race"],["best_lap","lap"]]:
		var bins: Array = packet.get(pair[0],{}).get("bins",[])
		if not bins.is_empty(): result += "&%s_from_ticks=%d&%s_to_ticks=%d" % [pair[1],int(bins[0].from_ticks),pair[1],int(bins[-1].to_ticks_exclusive)]
	return result

static func contains_candidates(packet: Dictionary, race_ticks: int, lap_ticks: int) -> bool:
	for pair: Array in [["race",race_ticks],["best_lap",lap_ticks]]:
		if int(pair[1]) <= 0: continue
		var bins: Array = packet.get(pair[0],{}).get("bins",[])
		if bins.is_empty() or int(pair[1]) < int(bins[0].from_ticks) or int(pair[1]) >= int(bins[-1].to_ticks_exclusive): return false
	return true

static func merge_overlay(packet: Dictionary, retained: Dictionary) -> Dictionary:
	if packet.get("schema","") != "bmt-comparison-overlay-v1": return packet
	if str(packet.get("histogram_key","")).is_empty() or packet.histogram_key != retained.get("histogram_key") or packet.get("board_id") != retained.get("board_id"): return {}
	var result: Dictionary = packet.duplicate(true)
	result.erase("schema")
	for metric: String in ["race","best_lap"]:
		if not result.get(metric) is Dictionary or not retained.get(metric,{}).get("bins") is Array: return {}
		result[metric].bins = retained[metric].bins.duplicate(true)
	return result
