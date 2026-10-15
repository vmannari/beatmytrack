class_name TrackDiscoveryProvider
extends RefCounted
## Read-model boundary. A future adapter hydrates snapshots outside simulation,
## then emits changed on the main thread. Missing data is never fabricated.
signal changed
var available: bool = false
var track_stats: Dictionary = {}
var records_by_rules_key: Dictionary = {}
const MAX_RECORDS: int = 32
const MAX_RECORD_BYTES: int = 2097152
var _record_sizes: Dictionary = {}
var _record_bytes: int = 0
var _pinned_record: String = ""
var snapshot_cache = preload("res://backend/menu_snapshot_cache.gd").new()
var comparisons = preload("res://backend/comparison_preloader.gd").new()

func configure_cache(path: String, scope: String) -> void:
	if not snapshot_cache.scope.is_empty() and snapshot_cache.scope != scope:
		records_by_rules_key.clear()
		_record_sizes.clear()
		_record_bytes = 0
		_pinned_record = ""
	snapshot_cache.configure(path,scope)
	if is_instance_valid(comparisons.client): comparisons.configure(comparisons.client,path+".comparisons.json" if not path.is_empty() else "",scope)

func prime_comparisons(client: Node, entries: Array, vehicle: String) -> void:
	comparisons.configure(client,snapshot_cache.path+".comparisons.json" if not snapshot_cache.path.is_empty() else "",snapshot_cache.scope)
	comparisons.prime(entries,vehicle)

func remember_record(rules_key: String, snapshot: Dictionary) -> void:
	_remember_ram(rules_key,snapshot)
	if snapshot.get("comparison_scope","") == "all" and int(snapshot.get("comparison_bins",0)) == RaceComplete.COMPARISON_BINS:
		var saved: Dictionary = snapshot.duplicate(true)
		for metric: String in ["race","lap"]:
			for marker: Dictionary in saved.get(metric+"_distribution",{}).get("markers",[]): marker.erase("color")
		snapshot_cache.remember(rules_key,saved)

func record_snapshot(rules_key: String) -> Dictionary:
	if not records_by_rules_key.has(rules_key):
		var cached: Dictionary = snapshot_cache.read(rules_key)
		if not cached.is_empty():
			# JSON numbers lose the typed GDScript array contract at rest.
			for metric: String in ["race","lap"]:
				var distribution: Dictionary = cached.get(metric+"_distribution",{})
				var counts: Array[int] = []
				for count: Variant in distribution.get("bins",[]): counts.append(int(count))
				distribution.bins = counts
				var edges: Array[float] = []
				for edge: Variant in distribution.get("edges_ms",[]): edges.append(float(edge))
				distribution.edges_ms = edges
			_remember_ram(rules_key,cached)
	if records_by_rules_key.has(rules_key):
		var value: Dictionary = records_by_rules_key[rules_key]
		records_by_rules_key.erase(rules_key)
		records_by_rules_key[rules_key] = value
	return records_by_rules_key.get(rules_key,{}).duplicate(true)

func pin_record(rules_key: String) -> void:
	_pinned_record = rules_key

func _remember_ram(key: String, value: Dictionary) -> void:
	var bytes: int = var_to_bytes(value).size()
	_record_bytes -= int(_record_sizes.get(key,0))
	records_by_rules_key.erase(key)
	_record_sizes.erase(key)
	if bytes > MAX_RECORD_BYTES: return
	records_by_rules_key[key] = value.duplicate(true)
	_record_sizes[key] = bytes
	_record_bytes += bytes
	while records_by_rules_key.size() > MAX_RECORDS or _record_bytes > MAX_RECORD_BYTES:
		var oldest: String = records_by_rules_key.keys()[0]
		if oldest == _pinned_record and records_by_rules_key.size() > 1: oldest = records_by_rules_key.keys()[1]
		_record_bytes -= int(_record_sizes[oldest])
		_record_sizes.erase(oldest)
		records_by_rules_key.erase(oldest)

static func is_rival(value: Dictionary) -> bool:
	if bool(value.get("time_beaten",false)): return true
	var previous: float = float(value.get("previous_top_percent",-1))
	var current: float = float(value.get("current_top_percent",-1))
	return previous >= 0 and current >= 0 and ceili(current/10.0) > ceili(previous/10.0)

func query(catalog: TrackCatalog, state: Dictionary, favorites: Array, ratings: Dictionary = {}, raced_tracks: Array = [], now_seconds: int = -1) -> Array[Dictionary]:
	if catalog.server_ordered:
		var ordered: Array[Dictionary] = catalog.entries.filter(func(entry: Dictionary) -> bool: return entry.has("discovery_index"))
		ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.discovery_index) < int(b.discovery_index))
		return ordered
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
