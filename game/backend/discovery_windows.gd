extends Node
## V3 cursor windows reserve adjacent cursor coordinates for bounded refetches.
## Presentation uses actual entries only. Eviction rebases fetch coordinates.
signal changed
var client: Node
var query: Dictionary = {}
var query_key: String = ""
var origin: String = ""
var generation: int = 0
var total: int = -1 # Local window extent; never an exact remote count.
var snapshot: String = ""
var cursor: String = ""
var pages: Dictionary = {}
var loading: bool = false
var error: String = ""
var desired_index: int = 0
var _visible_count: int = 0
var locate_version: String = ""
var last_used: int = 0
var cache_directory: String = ""
var coordinate_shift: int = 0
var has_more: bool = false
var retry_at_msec: int = 0
var failure_count: int = 0
var snapshot_cache = preload("res://backend/menu_snapshot_cache.gd").new()
var preview_dictionary = preload("res://backend/preview_dictionary.gd").new()
const PAGE_SIZE: int = 20
const MAX_PAGES: int = 13

func scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id",""))+"/discovery-v3"

static func payload(filters: Dictionary, favorites: Array = [], raced: Array = []) -> Dictionary:
	return preload("res://backend/discovery_filters.gd").payload(filters,favorites,raced)

func windowed() -> bool:
	return true

func begin(filters: Dictionary, favorites: Array = [], raced: Array = [], fresh: bool = false) -> void:
	var body: Dictionary = payload(filters,favorites,raced)
	if body.feed == "daily" and int(client.get("_capabilities").get("discovery_daily_version",0)) < 1:
		body.feed = "recommended"
	var key: String = JSON.stringify(body)
	var same_query: bool = key == query_key and origin == scope()
	if same_query and Time.get_ticks_msec() < retry_at_msec: return
	if not same_query:
		retry_at_msec = 0
		failure_count = 0
	if not fresh and key == query_key and origin == scope():
		if loading: return
		if total >= 0 and error.is_empty() and Time.get_ticks_msec()-last_used < 60000:
			request_visible(desired_index)
			return
	generation += 1
	client.cancel_public_reads(get_instance_id())
	query = body
	query_key = key
	origin = scope()
	_reset_window()
	snapshot_cache.max_entries = 3
	snapshot_cache.max_age_seconds = 86400
	snapshot_cache.configure(cache_directory.path_join(scope().sha256_text()+".json") if not cache_directory.is_empty() else "",scope())
	if not fresh and locate_version.is_empty():
		var cached: Dictionary = snapshot_cache.read(key)
		if _valid_page(cached):
			_install(0,cached)
			cursor = "" # Cached cards are a preview; establish a fresh server view.
	await _fetch(0,fresh)

func _reset_window() -> void:
	total = -1
	snapshot = ""
	cursor = ""
	pages.clear()
	loading = false
	error = ""
	desired_index = 0
	_visible_count = 0
	coordinate_shift = 0
	has_more = false

func _fetch(page_number: int, _fresh: bool = false) -> void:
	if loading or query.is_empty() or Time.get_ticks_msec() < retry_at_msec: return
	var body: Dictionary = {}
	var numbers: Array = pages.keys()
	if not cursor.is_empty():
		var target: String = ""
		if pages.has(page_number): target = str(pages[page_number].cursor)
		elif not numbers.is_empty() and page_number == int(numbers.max())+1: target = str(pages[int(numbers.max())].next)
		elif not numbers.is_empty() and page_number == int(numbers.min())-1: target = str(pages[int(numbers.min())].previous)
		if target.is_empty(): return
		body.cursor = target
	else:
		body.query = query.duplicate(true)
		if not locate_version.is_empty(): body.locate_version = locate_version
	var preview_capability: Variant = client.get("_capabilities")
	var reusable_previews: bool = preview_capability is Dictionary and int(preview_capability.get("discovery_preview_version",0)) == 1
	if reusable_previews:
		preview_dictionary.configure(cache_directory.path_join("previews") if not cache_directory.is_empty() else "",scope())
		body.preview_cache = true
		body.known_previews = preview_dictionary.known() if page_number == 0 or pages.has(page_number) else []
	loading = true
	var serial: int = generation
	changed.emit()
	var result: Dictionary = await client.request_discovery(body,get_instance_id())
	if serial != generation or origin != scope(): return
	loading = false
	if not result.ok:
		_failed(result)
		changed.emit()
		return
	var data: Dictionary = result.data
	if reusable_previews and not preview_dictionary.restore(data):
		# A corrupt/evicted presentation cache cannot make cards unreachable.
		loading = true
		body.known_previews = []
		result = await client.request_discovery(body,get_instance_id())
		if serial != generation or origin != scope(): return
		loading = false
		if not result.get("ok",false) or not result.get("data") is Dictionary or not preview_dictionary.restore(result.data):
			_failed({"status":0})
			changed.emit()
			return
		data = result.data
	if not _valid_page(data):
		_failed({"status":0})
		error = "Could not load this track page. Refresh to retry."
		changed.emit()
		return
	if cursor.is_empty(): pages.clear()
	_install(page_number,data)
	error = ""
	retry_at_msec = 0
	failure_count = 0
	locate_version = ""
	last_used = Time.get_ticks_msec()
	if page_number == 0 and data.get("previous_cursor") == null:
		snapshot_cache.remember(query_key,data)
	changed.emit()
	if _visible_count > 0: _prefetch_visible.call_deferred(serial)

func _install(number: int, data: Dictionary) -> void:
	cursor = str(data.page_cursor)
	snapshot = cursor
	pages[number] = {"items":data.items.duplicate(true),"cursor":cursor,
		"next":"" if data.next_cursor == null else str(data.next_cursor),
		"previous":"" if data.previous_cursor == null else str(data.previous_cursor),
		"used":Time.get_ticks_msec()}
	while pages.size() > MAX_PAGES:
		var keys: Array = pages.keys()
		var remove: int = int(keys.min()) if number > int(keys.min()) else int(keys.max())
		pages.erase(remove)
	var numbers: Array = pages.keys()
	var low: int = int(numbers.min())
	var target: int = 0 if str(pages[low].previous).is_empty() else 1
	var shift: int = target-low
	var remapped: Dictionary = {}
	for old_number: int in numbers:
		var new_number: int = old_number+shift
		var item: Dictionary = pages[old_number]
		for index: int in range(item.items.size()): item.items[index].discovery_index = new_number*PAGE_SIZE+index
		remapped[new_number] = item
	pages = remapped
	coordinate_shift += shift*PAGE_SIZE
	desired_index = maxi(0,desired_index+shift*PAGE_SIZE)
	var high: int = int(pages.keys().max())
	has_more = not str(pages[high].next).is_empty()
	total = (high+1)*PAGE_SIZE+PAGE_SIZE if has_more else high*PAGE_SIZE+pages[high].items.size()

func _valid_page(data: Dictionary) -> bool:
	if data.get("schema","") != "bmt-discovery-page-v3" or not data.get("items") is Array or data.items.size() > PAGE_SIZE: return false
	if data.get("total") != null or not data.get("has_more") is bool or str(data.get("page_cursor","")).is_empty(): return false
	for field: String in ["next_cursor","previous_cursor"]:
		if data.get(field) != null and (not data[field] is String or str(data[field]).length() > 400): return false
	if bool(data.has_more) != (data.next_cursor != null): return false
	var seen: Dictionary = {}
	for item: Variant in data.items:
		if not item is Dictionary or str(item.get("version_id","")).length() != 36 or str(item.get("content_hash","")).length() != 64 or not item.get("points") is Array: return false
		if not item.get("track_id") is String or str(item.track_id).is_empty() or not item.get("name") is String or not item.get("creator") is String: return false
		if seen.has(item.track_id): return false
		seen[item.track_id] = true
	return true

func _error_message(result: Dictionary) -> String:
	var status: int = int(result.get("status",0))
	if status == 410: return "Refresh tracks to continue this expired list."
	if status == 426: return "Update the game to load tracks."
	if status == 409: return "This track is still updating or is no longer available. Refresh to retry."
	if status == 429 or status == 503: return "Track search is busy. Retry or narrow your filters."
	return "Could not load tracks. Retry when connected."

func _failed(result: Dictionary) -> void:
	error = _error_message(result)
	failure_count = mini(6,failure_count+1)
	var delay_seconds: int = maxi(int(result.get("retry_after",0)),mini(30,1 << (failure_count-1)))
	retry_at_msec = Time.get_ticks_msec()+delay_seconds*1000+randi_range(0,250)

func request_visible(index: int, visible_count: int = 0) -> void:
	desired_index = clampi(index,0,maxi(0,total-1))
	_visible_count = clampi(visible_count,0,PAGE_SIZE*3)
	if loading or total < 0 or not error.is_empty(): return
	if _visible_count > 0:
		_prefetch_visible(generation)
		return
	var number: int = desired_index/PAGE_SIZE
	if not pages.has(number):
		_fetch(number)
		return
	pages[number].used = Time.get_ticks_msec()
	var high: int = int(pages.keys().max())
	var low: int = int(pages.keys().min())
	if number == high and desired_index%PAGE_SIZE >= 8 and not str(pages[high].next).is_empty(): _fetch(high+1)
	elif number == low and low > 0 and desired_index%PAGE_SIZE < 3 and not str(pages[low].previous).is_empty(): _fetch(low-1)

func _prefetch_visible(serial: int) -> void:
	if serial != generation or _visible_count <= 0 or loading or total < 0 or not error.is_empty() or pages.is_empty(): return
	var low: int = int(pages.keys().min())
	var high: int = int(pages.keys().max())
	var reserve: int = clampi(_visible_count*2,PAGE_SIZE,PAGE_SIZE*3)
	# Keep two viewports ahead, including when a wide grid fills several pages.
	# Completion revisits the latest demand; there is only one owned HTTP read.
	if desired_index < low*PAGE_SIZE+reserve and not str(pages[low].previous).is_empty(): _fetch(low-1)
	elif desired_index+_visible_count+reserve >= (high+1)*PAGE_SIZE and not str(pages[high].next).is_empty(): _fetch(high+1)

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var numbers: Array = pages.keys()
	numbers.sort()
	for number: int in numbers:
		for item: Dictionary in pages[number].items: result.append(item)
	return result

func entry_at(index: int) -> Dictionary:
	if index < 0: return {}
	var number: int = index/PAGE_SIZE
	if not pages.has(number): return {}
	var offset: int = index%PAGE_SIZE
	return pages[number].items[offset] if offset < pages[number].items.size() else {}

func unavailable_slot(index: int) -> bool:
	return index >= 0 and pages.has(index/PAGE_SIZE) and entry_at(index).is_empty()

func status_text() -> String:
	var prefix: String = "Daily picks & more · " if query.get("feed","") == "daily" else ""
	return prefix+"%d tracks loaded%s" % [entries().size()," · more available" if has_more else ""]

func random_entry(exclude: String) -> Dictionary:
	if loading or Time.get_ticks_msec() < retry_at_msec: return {}
	var serial: int = generation
	var body: Dictionary = {"cursor":cursor} if not cursor.is_empty() else {"query":query.duplicate(true)}
	body.exclude = exclude.trim_prefix("cloud_")
	var response: Dictionary = await client.request_discovery(body,get_instance_id(),true)
	if serial != generation or origin != scope(): return {}
	if not response.ok:
		_failed(response)
		changed.emit()
		return {}
	if not response.data.get("items") is Array or response.data.items.is_empty(): return {}
	var chosen: Dictionary = response.data.items[0]
	if str(chosen.get("version_id","")).length() != 36: return {}
	retry_at_msec = 0
	failure_count = 0
	generation += 1
	client.cancel_public_reads(get_instance_id())
	_reset_window()
	locate_version = str(chosen.version_id)
	var anchor_serial: int = generation
	await _fetch(0)
	if anchor_serial != generation or origin != scope() or not error.is_empty(): return {}
	for item: Dictionary in entries():
		if item.version_id == chosen.version_id: return item
	return {}

func _exit_tree() -> void:
	generation += 1
	if is_instance_valid(client): client.cancel_public_reads(get_instance_id())
