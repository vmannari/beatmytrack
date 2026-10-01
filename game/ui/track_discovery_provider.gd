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

func query(catalog: TrackCatalog, state: Dictionary, favorites: Array, ratings: Dictionary = {}, raced_tracks: Array = [], now_seconds: int = -1) -> Array[Dictionary]:
	var now: int = int(Time.get_unix_time_from_system()) if now_seconds < 0 else now_seconds
	var local_state: Dictionary = state.duplicate(true)
	local_state.sort = "name"
	var result: Array[Dictionary] = catalog.query(local_state,favorites)
	var search: String = str(state.get("search","")).strip_edges().to_lower()
	var feed: String = str(state.get("feed","recommended"))
	result = result.filter(func(entry: Dictionary) -> bool:
		var search_text: String = str(entry.name)+" "+str(entry.creator)
		if int(state.get("search_kind",0)) == 1: search_text = str(entry.name)
		if int(state.get("search_kind",0)) == 2: search_text = str(entry.creator)
		if not search.is_empty() and not search_text.to_lower().contains(search): return false
		if float(state.get("minimum_rating",0.0)) > 0.0 and rating_for(entry,ratings)+0.000001 < float(state.minimum_rating): return false
		var age_days: int = int(state.get("age_days",0))
		if age_days > 0:
			var created: int = creation_time(entry)
			if created <= 0 or created > now or created < now-age_days*86400: return false
		var history: String = str(state.get("race_history","any"))
		if history == "raced" and str(entry.id) not in raced_tracks: return false
		if history == "unraced" and str(entry.id) in raced_tracks: return false
		var count_filter: String = str(state.get("race_count","any"))
		if count_filter != "any":
			var races: int = int(track_stats.get(entry.id,{}).get("plays",-1))
			if races < 0: return false
			if count_filter == "low" and races >= 10: return false
			if count_filter == "medium" and (races < 10 or races >= 50): return false
			if count_filter == "high" and races < 50: return false
		if state.get("section","all") != "all" or feed == "recommended": return true
		if not available: return false
		var stats: Dictionary = track_stats.get(entry.id,{})
		if feed == "rivals": return is_rival(stats.get("rival",{}))
		return bool(stats.get({"trending":"trending","friends":"friend_created","new":"new"}.get(feed,""),false)))
	var sort_key: String = str(state.get("sort","name"))
	if feed == "new" and state.get("section","all") == "all":
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if a.get("published_at",0) != b.get("published_at",0): return int(a.get("published_at",0)) > int(b.get("published_at",0))
			return str(a.id) < str(b.id))
		return result
	if sort_key in ["score","plays"]:
		result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var first: float = rating_for(a,ratings) if sort_key == "score" else float(track_stats.get(a.id,{}).get(sort_key,-1))
			var second: float = rating_for(b,ratings) if sort_key == "score" else float(track_stats.get(b.id,{}).get(sort_key,-1))
			if first != second: return first > second
			var comparison: int = str(a.name).naturalnocasecmp_to(str(b.name))
			return str(a.id) < str(b.id) if comparison == 0 else comparison < 0)
	return result

func rating_for(entry: Dictionary, local_ratings: Dictionary) -> float:
	if entry.get("source") == "cloud":
		return float(entry.rating_average) if entry.get("rating_average") != null else -1.0
	return float(local_ratings.get(str(entry.id),track_stats.get(entry.id,{}).get("score",-1.0)))

static func creation_time(entry: Dictionary) -> int:
	var value: Variant = entry.get("created_at",0)
	if value is int or value is float: return int(value)
	if value is String and value.length() >= 19:
		return int(Time.get_unix_time_from_datetime_string(value.left(19)))
	return 0
