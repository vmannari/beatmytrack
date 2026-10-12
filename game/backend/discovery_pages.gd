extends Node
## A query owns its order/cursors. Only nearby preview pages stay in memory;
## absolute positions survive eviction, so previous pages can be fetched again.
signal changed
var client: Node
var query: Dictionary = {}
var query_key: String = ""
var origin: String = ""
var generation: int = 0
var total: int = -1
var snapshot: String = ""
var cursor: String = ""
var pages: Dictionary = {}
var loading: bool = false
var error: String = ""
var desired_index: int = 0
var locate_version: String = ""
var last_used: int = 0
var cache_directory: String = ""
var snapshot_cache = preload("res://backend/menu_snapshot_cache.gd").new()
var _initial_refresh: bool = false
const PAGE_SIZE: int = 20
const MAX_PAGES: int = 15

func scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id",""))

static func ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if str(value).begins_with("cloud_"): result.append(str(value).trim_prefix("cloud_"))
	result.sort()
	return result

static func payload(filters: Dictionary, favorites: Array = [], raced: Array = []) -> Dictionary:
	var body: Dictionary = {"search":str(filters.get("search","")),"search_kind":int(filters.get("search_kind",0)),
		"theme":str(filters.get("theme","all")),"minimum_rating":float(filters.get("minimum_rating",0.0)),
		"age_days":int(filters.get("age_days",0)),"race_count":str(filters.get("race_count","any")),
		"race_history":str(filters.get("race_history","any")),"section":str(filters.get("section","all")),
		"feed":str(filters.get("feed","recommended")),"sort":str(filters.get("sort","recommended"))}
	if body.feed not in ["recommended","new","popular","trending","rated"]: body.feed = "recommended"
	if body.sort not in ["recommended","name","creator","score","plays","new"]: body.sort = "recommended"
	if body.section == "favorites": body.ids = ids(favorites)
	if body.race_history != "any": body.raced_ids = ids(raced)
	return body

func begin(filters: Dictionary, favorites: Array = [], raced: Array = [], fresh: bool = false) -> void:
	var body: Dictionary = payload(filters,favorites,raced)
	var key: String = JSON.stringify(body)
	if not fresh and key == query_key and origin == scope() and loading: return
	if not fresh and key == query_key and origin == scope() and total >= 0 and Time.get_ticks_msec()-last_used < 60000:
		request_visible(desired_index)
		return
	generation += 1
	client.cancel_public_reads(get_instance_id())
	query = body
	query_key = key
	origin = scope()
	total = -1
	snapshot = ""
	cursor = ""
	pages.clear()
	loading = false
	error = ""
	desired_index = 0
	_initial_refresh = true
	snapshot_cache.max_entries = 3
	snapshot_cache.max_age_seconds = 86400
	snapshot_cache.configure(cache_directory.path_join(scope().sha256_text()+".json") if not cache_directory.is_empty() else "",scope())
	if not fresh and locate_version.is_empty():
		var cached: Dictionary = snapshot_cache.read(key)
		if _valid_page(cached,0):
			total = int(cached.total)
			pages[0] = {"items":cached.items,"used":Time.get_ticks_msec()}
			last_used = -60000
	await _fetch(0,fresh)

func _fetch(page_number: int, fresh: bool = false) -> void:
	if loading or query.is_empty(): return
	loading = true
	var serial: int = generation
	var body: Dictionary = query.duplicate(true)
	body.offset = page_number*PAGE_SIZE
	if not _initial_refresh and not snapshot.is_empty(): body.cursor = _cursor_at(body.offset)
	if fresh: body.fresh = true
	var locating: bool = _initial_refresh and not locate_version.is_empty()
	if locating: body.locate_version = locate_version
	changed.emit()
	var result: Dictionary = await client.request_discovery(body,get_instance_id())
	if serial != generation or origin != scope(): return
	loading = false
	if not result.ok:
		error = "Refresh tracks to continue this expired list." if int(result.get("status",0)) == 410 else "Could not load tracks. Retry when connected."
		changed.emit()
		return
	var data: Dictionary = result.data
	var effective_page: int = int(data.get("offset",-1))/PAGE_SIZE if locating else page_number
	if not _valid_page(data,effective_page):
		error = "Invalid track page. Refresh to retry."
		changed.emit()
		return
	total = int(data.total)
	if _initial_refresh: pages.clear()
	_initial_refresh = false
	snapshot = str(data.snapshot)
	cursor = str(data.get("page_cursor",""))
	pages[effective_page] = {"items":data.items,"used":Time.get_ticks_msec()}
	if effective_page == 0: snapshot_cache.remember(query_key,data)
	if locating:
		desired_index = effective_page*PAGE_SIZE
		locate_version = ""
	while pages.size() > MAX_PAGES:
		var oldest: int = -1
		for number: int in pages:
			if oldest < 0 or int(pages[number].used) < int(pages[oldest].used): oldest = number
		pages.erase(oldest)
	error = ""
	last_used = Time.get_ticks_msec()
	changed.emit()
	# A fast swipe can change the requested page while the HTTP read is pending.
	var wanted: int = maxi(0,desired_index/PAGE_SIZE)
	if wanted != effective_page and wanted*PAGE_SIZE < total and not pages.has(wanted): _fetch.call_deferred(wanted)

func _cursor_at(_offset: int) -> String:
	# The opaque server token binds the query/snapshot; offset is a separate input.
	return cursor

func _valid_page(data: Dictionary, page_number: int) -> bool:
	if not data.get("items") is Array or data.items.size() > PAGE_SIZE or not data.get("total") is float and not data.get("total") is int: return false
	if int(data.total) < 0 or float(data.total) != float(int(data.total)) or int(data.get("offset",-1)) != page_number*PAGE_SIZE or str(data.get("snapshot","")).length() != 36: return false
	var seen: Dictionary = {}
	for item: Variant in data.items:
		if not item is Dictionary or str(item.get("version_id","")).length() != 36 or str(item.get("content_hash","")).length() != 64 or not item.get("points") is Array: return false
		if not item.get("track_id") is String or str(item.track_id).is_empty() or not item.get("name") is String or not item.get("creator") is String: return false
		var index: int = int(item.get("discovery_index",-1))
		if index < page_number*PAGE_SIZE or index >= mini(int(data.total),(page_number+1)*PAGE_SIZE): return false
		if seen.has(str(item.track_id)) or seen.has(index): return false
		seen[str(item.track_id)] = true
		seen[index] = true
	return true

func request_visible(index: int) -> void:
	desired_index = maxi(0,index)
	if loading or total < 0 or desired_index >= total: return
	var number: int = desired_index/PAGE_SIZE
	if not pages.has(number): _fetch(number); return
	pages[number].used = Time.get_ticks_msec()
	# One-page prefetch; never drain the whole community catalog.
	if desired_index%PAGE_SIZE >= 8 and (number+1)*PAGE_SIZE < total and not pages.has(number+1): _fetch(number+1)

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var numbers: Array = pages.keys()
	numbers.sort()
	for number: int in numbers:
		for item: Dictionary in pages[number].items: result.append(item)
	return result

func entry_at(index: int) -> Dictionary:
	var number: int = index/PAGE_SIZE
	if not pages.has(number): return {}
	for item: Dictionary in pages[number].items:
		if int(item.discovery_index) == index: return item
	return {}

func random_entry(exclude: String) -> Dictionary:
	var serial: int = generation
	var body: Dictionary = query.duplicate(true)
	if not snapshot.is_empty(): body.cursor = _cursor_at(0)
	body.exclude = exclude.trim_prefix("cloud_")
	var response: Dictionary = await client.request_discovery(body,get_instance_id(),true)
	if serial != generation or origin != scope() or not response.ok or not response.data.get("items") is Array or response.data.items.is_empty(): return {}
	return response.data.items[0]

func _exit_tree() -> void:
	generation += 1
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())
