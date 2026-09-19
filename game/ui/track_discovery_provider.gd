class_name TrackDiscoveryProvider
extends RefCounted
## Read-model boundary. A future adapter hydrates snapshots outside simulation,
## then emits changed on the main thread. Missing data is never fabricated.
signal changed
var available: bool = false
var track_stats: Dictionary = {}
var records_by_rules_key: Dictionary = {}

func record_snapshot(rules_key: String) -> Dictionary:
	return records_by_rules_key.get(rules_key,{}).duplicate(true)

static func is_rival(value: Dictionary) -> bool:
	if bool(value.get("time_beaten",false)): return true
	var previous: float = float(value.get("previous_top_percent",-1))
	var current: float = float(value.get("current_top_percent",-1))
	return previous >= 0 and current >= 0 and ceili(current/10.0) > ceili(previous/10.0)

func query(catalog: TrackCatalog, state: Dictionary, favorites: Array) -> Array[Dictionary]:
	var local_state: Dictionary = state.duplicate(true)
	local_state.sort = "name"
	var result: Array[Dictionary] = catalog.query(local_state,favorites)
	var search: String = str(state.get("search","")).strip_edges().to_lower()
	var feed: String = str(state.get("feed","recommended"))
	result = result.filter(func(entry: Dictionary) -> bool:
		if not search.is_empty() and not (str(entry.name)+" "+str(entry.creator)).to_lower().contains(search): return false
		if state.get("section","all") != "all" or feed == "recommended": return true
		if not available: return false
		var stats: Dictionary = track_stats.get(entry.id,{})
		if feed == "rivals": return is_rival(stats.get("rival",{}))
		return bool(stats.get({"trending":"trending","friends":"friend_created","new":"new"}.get(feed,""),false)))
	var sort_key: String = str(state.get("sort","name"))
	if sort_key in ["score","plays"]:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var first: float = float(track_stats.get(a.id,{}).get(sort_key,-1))
			var second: float = float(track_stats.get(b.id,{}).get(sort_key,-1))
			if first != second: return first > second
			var comparison: int = str(a.name).naturalnocasecmp_to(str(b.name))
			return str(a.id) < str(b.id) if comparison == 0 else comparison < 0)
	return result
