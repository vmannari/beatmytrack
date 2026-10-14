extends Node
## Network/cache work lives outside canonical simulation. Public cache is server scoped;
## durable submissions are additionally scoped to the authenticated player.
signal changed
const Client = preload("res://backend/backend_client.gd")
const PREPARED_TRACKS = preload("res://backend/prepared_track_cache.gd")
var client: Node
var entries: Array[Dictionary] = []
var status: String = "Cloud tracks have not been refreshed."
var refreshing: bool = false
var flushing: bool = false
var run_connection_failed: bool = false
var last_error: String = ""
var root_override: String = ""
var catalog_url: String = ""
var next_cursor: String = ""
var last_refresh_msec: int = -60000
var _search_serial: int = 0
var _search_filters: Dictionary = {}
var _search_cursor: String = ""
var _search_loading: bool = false
var _snapshot_entries: Array[Dictionary] = []
var _catalog_serial: int = 0
const MAX_CATALOG_ENTRIES: int = 1000
var discovery_pages: Node
var _discovery_filters: Dictionary = {}
var _discovery_favorites: Array = []
var _discovery_raced: Array = []
var _publication_pin: Dictionary = {}
var _recovered_outboxes: Dictionary = {}
var _pending_iterators: Dictionary = {}
var result_saves: Node
var _retry_deadlines: Dictionary = {}
var _write_deadlines: Dictionary = {}
var _flush_deadlines: Dictionary = {}
const MAX_FLUSH_JOBS: int = 16

func _ready() -> void:
	_ensure_result_saves()

func _ensure_result_saves() -> void:
	if is_instance_valid(result_saves): return
	result_saves = preload("res://backend/result_save_queue.gd").new()
	result_saves.sink = queue_run_async
	add_child(result_saves)
	result_saves.changed.connect(changed.emit)
	result_saves.saved.connect(func(_id: String) -> void: flush_outbox())

func enqueue_completed(ticket_data: Dictionary, frames: Array, publish: String = "", rewinds: Array = []) -> bool:
	_ensure_result_saves()
	var captured: Dictionary = ticket_data.duplicate(true)
	captured["_owner_id"] = str(ticket_data.get("_owner_id",client.player.get("id","")))
	captured["_origin"] = str(ticket_data.get("_origin",client.base_url()))
	if not captured.has("_submit_key"): captured["_submit_key"] = client.new_operation_key()
	captured.erase("_publish_key")
	return result_saves.enqueue(captured,frames,publish,rewinds)

static func _pending_marker(path: String) -> String:
	return path.get_base_dir().get_base_dir().path_join("pending").path_join(path.get_file())

func _save_pending_job(path: String, job: Dictionary) -> bool:
	var active: bool = not job.has("done") and (not job.has("failure") or (job.get("retryable",false) and job.get("failure","") == "verifier_unavailable"))
	# Write the work marker first so a crash cannot strand a durable replay.
	if active and not _write(_pending_marker(path),{"job":path.get_file()}): return false
	if not _write(path,job): return false
	if not active and FileAccess.file_exists(_pending_marker(path)): DirAccess.remove_absolute(_pending_marker(path))
	return true

static func _discover_pending(directory: String) -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(directory): return result
	var access: DirAccess = DirAccess.open(directory)
	if access == null: return result
	access.list_dir_begin()
	var filename: String = access.get_next()
	while not filename.is_empty():
		if filename.ends_with(".job.json"):
			var file := FileAccess.open(directory.path_join(filename),FileAccess.READ)
			if file != null and file.get_length() <= 8388608:
				var value: Variant = JSON.parse_string(file.get_as_text())
				if not value is Dictionary or (not value.has("done") and (not value.has("failure") or (value.get("retryable",false) and value.get("failure","") == "verifier_unavailable"))): result.append(filename)
			else: result.append(filename)
		filename = access.get_next()
	access.list_dir_end()
	return result

func _recover_pending(directory: String) -> bool:
	if _recovered_outboxes.has(directory): return true
	var thread := Thread.new()
	if thread.start(_discover_pending.bind(directory)) != OK: return false
	while thread.is_alive(): await get_tree().process_frame
	var filenames: Array[String] = thread.wait_to_finish()
	var count: int = 0
	for filename: String in filenames:
		if not _write(_pending_marker(directory.path_join(filename)),{"job":filename}): return false
		count += 1
		if count % MAX_FLUSH_JOBS == 0: await get_tree().process_frame
	_recovered_outboxes[directory] = true
	return true

func _pending_jobs(directory: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: String = directory.get_base_dir().path_join("pending")
	if not DirAccess.dir_exists_absolute(pending): return result
	if not _pending_iterators.has(pending):
		var opened := DirAccess.open(pending)
		if opened == null: return result
		opened.list_dir_begin()
		_pending_iterators[pending] = opened
	var access: DirAccess = _pending_iterators[pending]
	var filename: String = ""
	var inspected: int = 0
	while inspected < MAX_FLUSH_JOBS:
		filename = access.get_next()
		if filename.is_empty(): break
		if filename.ends_with(".job.json"):
			inspected += 1
			var job: Dictionary = _read_upload_job(directory.path_join(filename))
			if not job.is_empty():
				if job.has("done") or (job.has("failure") and not job.get("retryable",false)): DirAccess.remove_absolute(pending.path_join(filename))
				else: result.append(job)
	if filename.is_empty():
		access.list_dir_end()
		_pending_iterators.erase(pending)
	return result

func _read_upload_job(path: String) -> Dictionary:
	var job: Dictionary = _read(path)
	var ticket_id: String = str(job.get("ticket",""))
	if job.has("_read_error") or ticket_id.is_empty() or path.get_file() != ticket_id.sha256_text()+".job.json" or not job.get("key") is String or (job.has("replay") and str(job.replay) != ticket_id.sha256_text()+".replay.json"):
		status = "An upload needs recovery; its files were preserved."
		return {}
	job["_path"] = path
	return job

func upload_job(ticket_id: String) -> Dictionary:
	var path: String = outbox_path().get_base_dir().path_join("runs").path_join(ticket_id.sha256_text()+".job.json")
	return _read_upload_job(path) if FileAccess.file_exists(path) else {}

static func _history_names(directory: String, page: int) -> PackedStringArray:
	var files: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()
	var jobs := PackedStringArray()
	for filename: String in files:
		if filename.ends_with(".job.json"): jobs.append(filename)
	jobs.sort()
	return jobs.slice(page*100,mini(jobs.size(),(page+1)*100))

func upload_history(page: int = 0) -> Array[Dictionary]:
	var directory: String = outbox_path().get_base_dir().path_join("runs")
	var thread := Thread.new()
	var result: Array[Dictionary] = []
	if thread.start(_history_names.bind(directory,maxi(0,page))) != OK: return result
	while thread.is_alive(): await get_tree().process_frame
	var files: PackedStringArray = thread.wait_to_finish()
	var count: int = 0
	for filename: String in files:
		var job: Dictionary = _read_upload_job(directory.path_join(filename))
		if not job.is_empty(): result.append(job)
		count += 1
		if count % MAX_FLUSH_JOBS == 0: await get_tree().process_frame
	return result

func cache_root() -> String:
	return (root_override if not root_override.is_empty() else "user://cloud").path_join(str(client.base_url()).sha256_text())

func _read(path: String) -> Dictionary:
	return _read_file(path)

static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: return {"_read_error":true}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {"_read_error":true}
	var value: Variant = json.data
	return value if value is Dictionary else {"_read_error":true}

func _write(path: String, value: Dictionary) -> bool:
	return _write_file(path,value)

static func _write_file(path: String, value: Dictionary) -> bool:
	var encoded: String = JSON.stringify(value)
	if encoded.to_utf8_buffer().size() > 8388608: return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(encoded)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path+".tmp",path) == OK

func load_cached() -> void:
	if is_instance_valid(discovery_pages):
		discovery_pages.generation += 1
		discovery_pages.query_key = ""
		discovery_pages.total = -1
		discovery_pages.pages.clear()
		client.cancel_public_reads(discovery_pages.get_instance_id())
	_publication_pin.clear()
	_catalog_serial += 1
	_search_serial += 1
	catalog_url = str(client.base_url())
	next_cursor = ""
	_search_cursor = ""
	_search_filters.clear()
	_search_loading = false
	_snapshot_entries.clear()
	last_refresh_msec = -60000
	entries.clear()
	var cached: Variant = _read(cache_root().path_join("index.json")).get("entries",[])
	var aliases: Dictionary = _read(cache_root().path_join("aliases.json"))
	if cached is Array:
		for item: Variant in cached:
			if item is Dictionary and _valid_entry(item):
				if not aliases.has("_read_error"): aliases["cloud_"+str(item.version_id)] = "cloud_"+str(item.track_id)
				if FileAccess.file_exists(cache_root().path_join(str(item.content_hash)+".json")): _retain_metadata(item)
				if entries.size() < MAX_CATALOG_ENTRIES: entries.append(item)
	if not aliases.has("_read_error"): _write(cache_root().path_join("aliases.json"),aliases)
	_remember_aliases() # Preserve legacy version IDs before a refresh replaces them.
	status = "Cached cloud catalog · refresh to check for updates"

func _valid_entry(item: Dictionary) -> bool:
	var version: String = str(item.get("version_id",""))
	var hash_value: String = str(item.get("content_hash",""))
	return version.length() == 36 and version.replace("-","").is_valid_hex_number(false) and hash_value.length() == 64 and hash_value.is_valid_hex_number(false) and item.get("points") is Array

func refresh(force: bool = false) -> void:
	if paged_discovery_available():
		await query_discovery(_discovery_filters,_discovery_favorites,_discovery_raced,force)
		return
	if refreshing: return
	if not force and Time.get_ticks_msec()-last_refresh_msec < 60000: return
	last_refresh_msec = Time.get_ticks_msec()
	if catalog_url != str(client.base_url()): load_cached()
	refreshing = true
	var serial: int = _catalog_serial
	status = "Refreshing cloud tracks…"
	changed.emit()
	var collected: Array[Dictionary] = entries.duplicate(true)
	if next_cursor.is_empty(): _snapshot_entries.clear()
	for page: int in range(1):
		var response: Dictionary = await client.request_api("/tracks?limit=20"+("&cursor="+next_cursor.uri_encode() if not next_cursor.is_empty() else ""))
		if serial != _catalog_serial or catalog_url != str(client.base_url()): break
		if not response.ok:
			status = "Cloud unavailable · showing cached tracks · Refresh to retry"
			break
		var valid: bool = response.data.get("items") is Array
		if valid:
			for item: Variant in response.data.items:
				if not item is Dictionary or not _valid_entry(item):
					valid = false
					break
				collected = collected.filter(func(old: Dictionary) -> bool: return old.track_id != item.track_id)
				collected.append(item)
				while collected.size() > MAX_CATALOG_ENTRIES: collected.pop_front()
		if not valid:
			status = "Invalid cloud catalog · keeping cached tracks"
			break
		for item: Dictionary in response.data.items:
			_snapshot_entries = _snapshot_entries.filter(func(old: Dictionary) -> bool: return old.track_id != item.track_id)
			_snapshot_entries.append(item)
			while _snapshot_entries.size() > MAX_CATALOG_ENTRIES: _snapshot_entries.pop_front()
		entries = collected
		while entries.size() > MAX_CATALOG_ENTRIES: entries.pop_front()
		var cursor: Variant = response.data.get("next_cursor")
		next_cursor = "" if cursor == null else str(cursor)
		if not _write(cache_root().path_join("index.json"),{"entries":entries}): status = "Cloud loaded · catalog could not be cached"
		changed.emit() # Keep usable progress if a later page fails.
		if next_cursor.is_empty():
			entries = _snapshot_entries.duplicate(true)
			status = "Cloud catalog up to date · tracks download when selected"
			if not _write(cache_root().path_join("index.json"),{"entries":entries}): status = "Cloud loaded · catalog could not be cached"
			break
		status = "Cloud tracks loaded · more will load on the next refresh"
	refreshing = false
	if serial != _catalog_serial or catalog_url != str(client.base_url()):
		refresh.call_deferred(true)
		return
	_remember_aliases()
	changed.emit()

func load_more() -> void:
	if paged_discovery_available():
		_ensure_discovery_pages()
		var numbers: Array = discovery_pages.pages.keys()
		var page: int = 0 if numbers.is_empty() else int(numbers.max())+1
		if page*20 < int(discovery_pages.total): await discovery_pages._fetch(page)
		return
	if refreshing or _search_loading: return
	if not _search_filters.is_empty():
		if not _search_cursor.is_empty(): search(_search_filters,true)
	elif not next_cursor.is_empty(): refresh(true)

func search(filters: Dictionary, append: bool = false) -> void:
	if paged_discovery_available():
		if append: await load_more()
		else: await query_discovery(filters,_discovery_favorites,_discovery_raced)
		return
	_search_loading = true
	_search_filters = filters.duplicate(true)
	if not append: _search_cursor = ""
	_search_serial += 1
	var serial: int = _search_serial
	var query: String = str(filters.get("search",""))
	var kind: String = ["search","q","creator"][clampi(int(filters.get("search_kind",0)),0,2)]
	var path: String = "/tracks?limit=20&"+kind+"="+query.uri_encode()
	if append: path += "&cursor="+_search_cursor.uri_encode()
	var theme: String = str(filters.get("theme","all"))
	if theme != "all": path += "&theme="+theme.uri_encode()
	path += "&minimum_rating="+str(float(filters.get("minimum_rating",0.0)))
	var response: Dictionary = await client.request_public(path,get_instance_id())
	if serial != _search_serial: return
	_search_loading = false
	if not response.ok or not response.data.get("items") is Array: return
	for item: Variant in response.data.items:
		if not item is Dictionary or not _valid_entry(item): return
	for item: Dictionary in response.data.items:
		entries = entries.filter(func(old: Dictionary) -> bool: return old.track_id != item.track_id)
		entries.append(item)
	while entries.size() > MAX_CATALOG_ENTRIES: entries.pop_front()
	_search_cursor = "" if response.data.get("next_cursor") == null else str(response.data.next_cursor)
	_write(cache_root().path_join("index.json"),{"entries":entries})
	status = "Cloud matches loaded"+(" · narrow your search for more" if response.data.get("next_cursor") != null else "")
	changed.emit()

func retained_entry(identity: String) -> Dictionary:
	var value: Dictionary = _read(cache_root().path_join("retained").path_join(identity.sha256_text()+".json"))
	if value.get("alias") is String:
		value = _read(cache_root().path_join("retained").path_join(str(value.alias).sha256_text()+".json"))
	return entry_from_metadata(value) if _valid_entry(value) else {}

func _retain_metadata(metadata: Dictionary) -> bool:
	var directory: String = cache_root().path_join("retained")
	var identity: String = "cloud_"+str(metadata.track_id)
	if metadata.get("_compiled_source_hash","") != metadata.get("content_hash",""):
		for field: String in ["_compiled_hash","_compiled_version","_compiled_engine","_compiled_source_hash"]: metadata.erase(field)
	var previous: Dictionary = _read(directory.path_join(identity.sha256_text()+".json"))
	if previous.get("version_id","") == metadata.get("version_id","") and previous.get("content_hash","") == metadata.get("content_hash",""):
		for key: String in ["_compiled_hash","_compiled_version","_compiled_engine","_compiled_source_hash"]:
			if not metadata.has(key) and previous.has(key): metadata[key] = previous[key]
	return _write(directory.path_join(identity.sha256_text()+".json"),metadata) and _write(directory.path_join(("cloud_"+str(metadata.version_id)).sha256_text()+".json"),{"alias":identity})

static func metadata_track(entry: Dictionary) -> NativeTrack:
	# Presentation only; _start_race must hydrate this before any simulation.
	var track := NativeTrack.new()
	track.identity = str(entry.id)
	track.metadata = {"metadata_only":true,"cloud_entry":entry.duplicate(true),"cloud_version":str(entry.version_id),"cloud_track_id":str(entry.get("track_id","")),"title":str(entry.name),"theme":str(entry.get("theme","pine")),"cloud_creator":str(entry.get("creator",""))}
	for point: Array in entry.get("points",[]): track.route.append(Vector2(point[0],point[1]))
	track._build_route_distance()
	var hint: String = str(entry.get("_compiled_hash",""))
	if hint.length() == 64 and hint.is_valid_hex_number() and entry.get("_compiled_source_hash","") == entry.get("content_hash","") and entry.get("_compiled_version","") == TrackCompiler.VERSION and entry.get("_compiled_engine","") == Engine.get_version_info().string:
		track.content_hash = hint
	return track

func presentation_track(entry: Dictionary) -> NativeTrack:
	var retained: Dictionary = retained_entry(str(entry.id))
	if retained.get("version_id","") == entry.get("version_id","") and retained.get("content_hash","") == entry.get("content_hash",""):
		for field: String in ["_compiled_hash","_compiled_version","_compiled_engine","_compiled_source_hash"]:
			if retained.has(field): entry[field] = retained[field]
	return metadata_track(entry)

func remember_compiled_entry(entry: Dictionary, track: NativeTrack) -> void:
	var metadata: Dictionary = entry.duplicate(true)
	metadata._compiled_hash = track.content_hash
	metadata._compiled_source_hash = entry.content_hash
	metadata._compiled_version = TrackCompiler.VERSION
	metadata._compiled_engine = Engine.get_version_info().string
	_retain_metadata(metadata)

func add_to_catalog(catalog: TrackCatalog, discovery: TrackDiscoveryProvider = null, retained: Array = []) -> void:
	catalog.server_ordered = paged_discovery_available() and is_instance_valid(discovery_pages) and discovery_pages.total >= 0
	catalog.entries = catalog.entries.filter(func(item: Dictionary) -> bool: return item.source != "cloud")
	var available: Array[Dictionary] = entries.duplicate()
	var known: Dictionary = {}
	for item: Dictionary in available: known["cloud_"+str(item.track_id)] = true
	for identity: Variant in retained:
		if catalog.server_ordered: break # Collections are queried globally; do not scan every favorite file per page.
		if known.has(str(identity)): continue
		var saved: Dictionary = retained_entry(str(identity))
		if saved.is_empty() or known.has(str(saved.id)): continue
		available.append(saved)
		known[str(saved.id)] = true
	for item: Dictionary in available:
		var entry: Dictionary = item.duplicate(true)
		entry.id = "cloud_"+str(item.track_id)
		entry.source = "cloud"
		entry.read_only = true
		entry.owned = str(item.get("creator_id","")) == str(client.player.get("id","")) and client.signed_in()
		entry.theme = TrackTheme.normalized(str(item.get("theme","pine")))
		entry.cache_path = cache_root().path_join(str(item.content_hash)+".json")
		catalog.entries.append(entry)
		if discovery != null:
			discovery.track_stats[entry.id] = {"score":float(item.rating_average) if item.rating_average != null else -1.0,"new":true}
			if item.has("verified_finishers"): discovery.track_stats[entry.id].plays = int(item.verified_finishers)
	if discovery != null: discovery.available = true
	if discovery != null and catalog.server_ordered:
		var active: Dictionary = {}
		for entry: Dictionary in catalog.entries: active[str(entry.id)] = true
		for identity: Variant in discovery.track_stats.keys():
			if str(identity).begins_with("cloud_") and not active.has(str(identity)): discovery.track_stats.erase(identity)

func entry_from_metadata(metadata: Dictionary) -> Dictionary:
	var entry: Dictionary = metadata.duplicate(true)
	entry.id = "cloud_"+str(entry.track_id)
	entry.source = "cloud"
	entry.read_only = true
	entry.owned = str(entry.get("creator_id","")) == str(client.player.get("id","")) and client.signed_in()
	entry.cache_path = cache_root().path_join(str(entry.content_hash)+".json")
	entry.theme = TrackTheme.normalized(str(entry.get("theme","pine")))
	return entry

func remember_publication(metadata: Dictionary) -> bool:
	if not _retain_metadata(metadata): return false
	_publication_pin = metadata.duplicate(true)
	_publication_pin.discovery_index = 0
	if is_instance_valid(discovery_pages):
		discovery_pages.generation += 1
		discovery_pages.query_key = ""
		discovery_pages.total = -1
		discovery_pages.pages.clear()
		client.cancel_public_reads(discovery_pages.get_instance_id())
	# An older paginated snapshot cannot contain this newly committed revision.
	# Fence outstanding reads and start the next refresh at the newest page.
	_catalog_serial += 1
	next_cursor = ""
	_snapshot_entries.clear()
	last_refresh_msec = -60000
	_search_serial += 1
	_search_filters.clear()
	_search_cursor = ""
	_search_loading = false
	entries = entries.filter(func(old: Dictionary) -> bool: return str(old.track_id) != str(metadata.track_id))
	entries.append(metadata.duplicate(true))
	while entries.size() > MAX_CATALOG_ENTRIES: entries.pop_front()
	if not _write(cache_root().path_join("index.json"),{"entries":entries}): return false
	_remember_aliases()
	changed.emit()
	return true

func paged_discovery_available() -> bool:
	return client != null and int(client.get("_capabilities").get("discovery_paging_version",0)) >= 2

func _ensure_discovery_pages() -> void:
	if is_instance_valid(discovery_pages): return
	discovery_pages = preload("res://backend/discovery_pages.gd").new()
	discovery_pages.client = client
	discovery_pages.cache_directory = cache_root().path_join("discovery")
	add_child(discovery_pages)
	discovery_pages.changed.connect(_discovery_changed)

func query_discovery(filters: Dictionary, favorites: Array = [], raced: Array = [], fresh: bool = false) -> void:
	_discovery_filters = filters.duplicate(true)
	_discovery_favorites = favorites.duplicate()
	_discovery_raced = raced.duplicate()
	if not paged_discovery_available():
		await search(filters)
		return
	_ensure_discovery_pages()
	discovery_pages.cache_directory = cache_root().path_join("discovery")
	if not _publication_pin.is_empty(): discovery_pages.locate_version = str(_publication_pin.version_id)
	await discovery_pages.begin(filters,favorites,raced,fresh or not _publication_pin.is_empty())

func _discovery_changed() -> void:
	var loaded: Array[Dictionary] = discovery_pages.entries()
	# The older public index is also useful on the first upgraded app launch.
	# Never carry its cards into a filtered query or a confirmed empty response.
	if not (loaded.is_empty() and discovery_pages.loading and discovery_pages.total < 0 and discovery_pages.query == discovery_pages.payload({})):
		entries = loaded
	if not _publication_pin.is_empty():
		if not discovery_pages.loading and discovery_pages.total >= 0 and discovery_pages.error.is_empty(): _publication_pin.clear()
		else: entries.append(_publication_pin)
	refreshing = discovery_pages.loading
	status = discovery_pages.error if not discovery_pages.error.is_empty() else ("Loading tracks…" if refreshing else "%d tracks" % maxi(0,int(discovery_pages.total)))
	if not refreshing and discovery_pages.total >= 0:
		# Persist only the first page for fast reopening; distant pages are reloadable.
		if discovery_pages.pages.has(0): _write(cache_root().path_join("index.json"),{"entries":discovery_pages.pages[0].items})
	changed.emit()

func _remember_aliases() -> void:
	var path: String = cache_root().path_join("aliases.json")
	var aliases: Dictionary = _read(path)
	if aliases.has("_read_error"): return
	for entry: Dictionary in entries: aliases["cloud_"+str(entry.version_id)] = "cloud_"+str(entry.track_id)
	_write(path,aliases)

func migrate_record_identities(local: LocalRecords) -> Error:
	var aliases: Dictionary = _read(cache_root().path_join("aliases.json"))
	if aliases.has("_read_error"): return ERR_FILE_CORRUPT
	for entry: Dictionary in entries: aliases["cloud_"+str(entry.version_id)] = "cloud_"+str(entry.track_id)
	for key: String in ["favorites","raced_tracks"]:
		var values: Array = []
		for identity: Variant in local.settings.get(key,[]):
			var stable: String = str(aliases.get(str(identity),identity))
			if stable not in values: values.append(stable)
		local.settings[key] = values
	var last: String = str(local.settings.get("last_track",""))
	if not last.is_empty(): local.settings.last_track = aliases.get(last,last)
	else: local.settings.erase("last_track")
	return local.save_records()

static func cached_document(entry: Dictionary) -> Dictionary:
	var path: String = str(entry.get("cache_path",""))
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > TrackDocument.MAX_BYTES: return {}
	var body: String = file.get_as_text()
	if body.sha256_text() != str(entry.content_hash): return {}
	var doc: Variant = JSON.parse_string(body)
	if not doc is Dictionary or not TrackDocument.validate(doc).is_empty(): return {}
	return doc

func download(entry: Dictionary) -> bool:
	if not cached_document(entry).is_empty(): return _retain_metadata(entry)
	var response: Dictionary = await client.request_api("/track-versions/"+str(entry.version_id).uri_encode()+"/document")
	if not response.ok:
		last_error = "This track is not cached. Connect and retry. " + str(response.error)
		return false
	var body: String = str(response.get("body",""))
	if body.to_utf8_buffer().size() > TrackDocument.MAX_BYTES or body.sha256_text() != str(entry.content_hash) or not TrackDocument.validate(response.data).is_empty():
		last_error = "Downloaded track failed its integrity check."
		return false
	var path: String = str(entry.cache_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		last_error = "Not enough writable storage to cache this track."
		return false
	file.store_string(body)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(path+".tmp",path) != OK:
		last_error = "The downloaded track could not be saved."
		return false
	return _retain_metadata(entry)

static func compile_entry(entry: Dictionary) -> NativeTrack:
	var doc: Dictionary = cached_document(entry)
	if doc.is_empty(): return null
	var key: Array = [str(entry.get("cache_path","")),str(entry.content_hash),TrackCompiler.VERSION]
	var track: NativeTrack = PREPARED_TRACKS.restore(key)
	if track == null:
		track = TrackCompiler.compile(doc)
		if track != null: PREPARED_TRACKS.remember(key,track)
	if track != null:
		track.identity = str(entry.id)
		track.metadata["title"] = str(entry.name)
		track.metadata["cloud_version"] = str(entry.version_id)
		track.metadata["cloud_track_id"] = str(entry.track_id)
		track.metadata["cloud_creator"] = str(entry.creator)
		track.metadata["cloud_creator_id"] = str(entry.get("creator_id",""))
	return track

func ticket(track: NativeTrack, creator_test: bool = false, vehicle_id: String = "", attempt_handling: HandlingConfig = null, issued: Dictionary = {}) -> Dictionary:
	_ensure_result_saves()
	if not result_saves.can_start_attempt():
		last_error = "Previous results are waiting for storage. Free space or race offline."
		return {}
	if not client.signed_in(): return {}
	var version: String = str(track.metadata.get("cloud_version",""))
	if version.is_empty(): return {}
	var selected_vehicle: String = VehicleCatalog.selected if vehicle_id.is_empty() else vehicle_id
	var response: Dictionary = {"ok":true,"data":issued} if not issued.is_empty() else await client.race_ticket(version,selected_vehicle,client.new_operation_key(),"creator_test" if creator_test else "race")
	if not response.ok:
		last_error = str(response.error)
		return {}
	var manifest: Dictionary = response.data.manifest
	# Compiler identity also changes the native track hash. Explain this first,
	# rather than misreporting a client/server rollout gap as a corrupt track.
	var compiler: String = str(manifest.get("compiler_version",""))
	if compiler != TrackCompiler.VERSION:
		var local_revision: int = int(TrackCompiler.VERSION.get_slice("-",2))
		var server_revision: int = int(compiler.get_slice("-",2))
		var numbered_compiler: bool = compiler.begins_with("creator-compiler-") and compiler.trim_prefix("creator-compiler-").is_valid_int()
		if numbered_compiler and server_revision < local_revision:
			last_error = "This game update needs a matching server update before online racing is available."
		elif numbered_compiler and server_revision > local_revision:
			last_error = "The server requires a newer game version. Update the game to race online."
		else:
			last_error = "The game and server versions do not match. Online racing is unavailable until they are updated."
		return {}
	if str(response.data.manifest.track_content_hash) != track.content_hash:
		last_error = "Track differs from the server's race contract."
		return {}
	var engine: Dictionary = Engine.get_version_info()
	var engine_version: String = "%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)]
	if str(manifest.get("engine_version","")) != engine_version or int(manifest.get("tick_rate",0)) != VehicleSimulation.TICK_RATE or manifest.get("track_schema") != TrackDocument.SCHEMA or manifest.get("replay_schema") != "bmt-replay-v1" or manifest.get("verifier_version") != "canonical-verifier-1":
		last_error = "The server requires a different verification contract. Update the game or backend."
		return {}
	if str(manifest.physics_version) != VehicleSimulation.PHYSICS_VERSION or str(manifest.compiler_version) != TrackCompiler.VERSION or str(manifest.rules_key) != RaceRules.KEY:
		last_error = "The server requires a different game build."
		return {}
	var config: HandlingConfig = attempt_handling if attempt_handling != null else VehicleCatalog.config(selected_vehicle) if creator_test or not vehicle_id.is_empty() else HandlingSelection.config()
	var values: Dictionary = {}
	for property: Dictionary in config.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: values[str(property.name)] = config.get(str(property.name))
	if str(manifest.config_hash) != JSON.stringify(values,"",true).sha256_text():
		last_error = "Selected handling differs from the server's race rules."
		return {}
	response.data["_submit_key"] = client.new_operation_key()
	return response.data

func upload_draft(_document: Dictionary) -> Dictionary:
	# Deprecated adapter kept to fail closed for old callers. The exact local
	# document and creator trajectory leave the device only through Publish.
	return {"ok":false,"status":410,"error":"LOCAL_DRAFTS_ONLY","data":{}}

func outbox_path() -> String:
	return cache_root().path_join("players").path_join(str(client.player.get("id","")).sha256_text()).path_join("outbox.json")

static func _save_pending_job_files(path: String, job: Dictionary) -> bool:
	if not _write_file(_pending_marker(path),{"job":path.get_file()}): return false
	return _write_file(path,job)

static func _queue_run_io(ticket_data: Dictionary, frames: Array, _publish_version: String, rewinds: Array, root_path: String, owner: String) -> bool:
	if frames.is_empty():
		return false
	var directory: String = root_path.path_join("players").path_join(owner.sha256_text()).path_join("runs")
	var name: String = str(ticket_data.ticket_id).sha256_text()
	var path: String = directory.path_join(name+".job.json")
	var existing: Dictionary = _read_file(path)
	var recording: Dictionary = {"frames":frames,"rewinds":rewinds}
	if ticket_data.has("_race_proof"): recording.race_proof = ticket_data._race_proof
	if ticket_data.has("_race_ghost"): recording.ghost = ticket_data._race_ghost
	var replay_hash: String = JSON.stringify(recording).sha256_text()
	if existing.has("_read_error"):
		return false
	if not existing.is_empty():
		if str(existing.get("replay_hash","")) != replay_hash: return false
		if existing.has("run_id"): return true
		return _replay_integrity(directory.path_join(name+".replay.json"),replay_hash)
	var saved: bool = _write_file(directory.path_join(name+".replay.json"),recording)
	if saved:
		saved = _save_pending_job_files(path,{"ticket":ticket_data.ticket_id,"replay":name+".replay.json","replay_hash":replay_hash,"key":ticket_data.get("_submit_key",Client.new_idempotency_key()),"publish":""})
	return saved

func queue_run(ticket_data: Dictionary, frames: Array, publish_version: String = "", rewinds: Array = []) -> bool:
	# Synchronous compatibility for small local diagnostics. The runtime uses
	# queue_run_async so replay hashing, encoding and atomic writes yield frames.
	var owner: String = str(ticket_data.get("_owner_id",client.player.get("id","")))
	var origin: String = str(ticket_data.get("_origin",client.base_url()))
	if ticket_data.is_empty() or owner.is_empty() or origin.is_empty(): return false
	var root_path: String = (root_override if not root_override.is_empty() else "user://cloud").path_join(origin.sha256_text())
	var saved: bool = _queue_run_io(ticket_data,frames,publish_version,rewinds,root_path,owner)
	if saved: changed.emit()
	else: last_error = "The race could not be saved. Free storage and retry."
	return saved

func queue_run_async(ticket_data: Dictionary, frames: Array, publish_version: String = "", rewinds: Array = []) -> bool:
	var owner: String = str(ticket_data.get("_owner_id",client.player.get("id","")))
	var origin: String = str(ticket_data.get("_origin",client.base_url()))
	if ticket_data.is_empty() or owner.is_empty() or origin.is_empty(): return false
	var root_path: String = (root_override if not root_override.is_empty() else "user://cloud").path_join(origin.sha256_text())
	var saved: Variant = await client._background(_queue_run_io.bind(ticket_data,frames,publish_version,rewinds,root_path,owner))
	if saved == true: changed.emit()
	else: last_error = "The race could not be saved. Free storage and retry."
	return saved == true

static func _load_replay(path: String, expected_hash: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: return {}
	var source: String = file.get_as_text()
	if source.sha256_text() != expected_hash: return {}
	var result: Variant = JSON.parse_string(source)
	return result if result is Dictionary else {}

static func _replay_integrity(path: String, expected_hash: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	return file != null and file.get_length() <= 8388608 and file.get_as_text().sha256_text() == expected_hash

func show_uploads(parent: Node, page: int = 0) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Race uploads"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600,280)
	dialog.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var jobs: Array[Dictionary] = await upload_history(page)
	if not is_instance_valid(parent) or owner != str(client.player.get("id","")) or origin != str(client.base_url()):
		dialog.free()
		return
	_ensure_result_saves()
	for id: String in result_saves.jobs.keys():
		var entry: Dictionary = result_saves.jobs[id]
		if str(entry.ticket.get("_owner_id","")) != owner or str(entry.ticket.get("_origin","")) != origin: continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(entry.error) if not str(entry.error).is_empty() else "Saving recorded result…"
		label.custom_minimum_size.x = 380
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		row.add_child(MenuStyle.button("Retry saving",func() -> void: result_saves.retry(id)))
		list.add_child(row)
	for job: Dictionary in jobs:
		if job.get("dismissed",false): continue
		var row := HBoxContainer.new()
		list.add_child(row)
		var label := Label.new()
		label.text = "Verified" if job.has("done") else _upload_failure_message(str(job.failure)) if job.has("failure") else "Saved · waiting for verification"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 380
		row.add_child(label)
		if job.get("failure","") in ["verifier_unavailable","build_mismatch"] and job.has("run_id"):
			var retry := Button.new()
			retry.text = "Retry"
			retry.pressed.connect(func() -> void:
				retry.disabled = true
				var retried: bool = await retry_upload(str(job.ticket))
				if is_instance_valid(label): label.text = "Saved · waiting for verification" if retried else "Retry unavailable · try again later"
				if is_instance_valid(retry): retry.disabled = false)
			row.add_child(retry)
		if job.get("retryable",false):
			var retry := Button.new()
			retry.text = "Retry"
			retry.pressed.connect(func() -> void:
				retry.disabled = true
				await retry_upload(str(job.ticket))
				await flush_outbox()
				dialog.queue_free()
				show_uploads(parent))
			row.add_child(retry)
		if job.has("done") or job.has("failure"):
			var ticket_id: String = str(job.ticket)
			var button := Button.new()
			button.text = "Dismiss"
			button.pressed.connect(func() -> void:
				if dismiss_upload(ticket_id): row.queue_free())
			row.add_child(button)
	if list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No race uploads waiting."
		list.add_child(empty)
	if page > 0 or jobs.size() == 100:
		var paging := HBoxContainer.new()
		list.add_child(paging)
		if page > 0: paging.add_child(MenuStyle.button("Previous",func() -> void: dialog.queue_free(); show_uploads(parent,page-1)))
		if jobs.size() == 100: paging.add_child(MenuStyle.button("Next",func() -> void: dialog.queue_free(); show_uploads(parent,page+1)))
	parent.add_child(dialog)
	preload("res://ui/popup_style.gd").watch(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(660,360))

func _upload_failure_message(code: String) -> String:
	match code:
		"invalid_replay": return "Server replay could not verify this finish. Update/restart the game and race again."
		"verifier_unavailable": return "Verification unavailable · retry later"
		"build_mismatch": return "Verification requires the original game build"
		"Run ticket expired": return "Race ticket expired"
		_: return "Race verification failed"

func _save_job(path: String, job: Dictionary) -> void:
	if not _save_pending_job(path,job): status = "Upload state could not be saved · retry is safe"

func _migrate_outbox() -> bool:
	var path: String = outbox_path()
	var legacy: Dictionary = _read(path)
	if legacy.has("_read_error"):
		status = "Previous uploads need recovery; the original file was preserved."
		return false
	if not legacy.get("jobs",[]) is Array:
		status = "Previous uploads need recovery; the original file was preserved."
		return false
	for value: Variant in legacy.get("jobs",[]):
		if not value is Dictionary or not value.get("ticket") is String or not value.get("key") is String:
			status = "Previous uploads need recovery; the original file was preserved."
			return false
	for old: Dictionary in legacy.get("jobs",[]):
		var name: String = str(old.ticket).sha256_text()
		var directory: String = path.get_base_dir().path_join("runs")
		var target: String = directory.path_join(name+".job.json")
		if FileAccess.file_exists(target): continue
		var job: Dictionary = old.duplicate(true)
		if job.has("frames"):
			job.replay_hash = JSON.stringify({"frames":job.frames,"rewinds":job.get("rewinds",[])}).sha256_text()
			job.replay = name+".replay.json"
			if not _write(directory.path_join(job.replay),{"frames":job.frames,"rewinds":job.get("rewinds",[])}): return false
			job.erase("frames")
			job.erase("rewinds")
		if not _save_pending_job(target,job): return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".migrated"): return false
		return DirAccess.rename_absolute(path,path+".migrated") == OK
	return true

func upload_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory: String = outbox_path().get_base_dir().path_join("runs")
	var files: PackedStringArray = DirAccess.get_files_at(directory) if DirAccess.dir_exists_absolute(directory) else PackedStringArray()
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".job.json"): continue
		var job: Dictionary = _read_upload_job(directory.path_join(filename))
		if job.is_empty(): continue
		result.append(job)
	return result

func dismiss_upload(ticket_id: String) -> bool:
	var job: Dictionary = upload_job(ticket_id)
	if job.is_empty() or not (job.has("done") or job.has("failure")): return false
	job.dismissed = true
	_save_job(str(job._path),job)
	var saved: bool = bool(_read(str(job._path)).get("dismissed",false))
	if saved: _retire_replay(job)
	return saved

func _retire_replay(job: Dictionary) -> void:
	# The ticket digest determines the only removable file, never a saved path.
	var path: String = outbox_path().get_base_dir().path_join("runs").path_join(str(job.ticket).sha256_text()+".replay.json")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _job_ready(job: Dictionary) -> bool:
	var id: String = str(job.ticket)
	if not _retry_deadlines.has(id):
		# Ignore legacy phone-wall-clock deadlines. New saved waits are bounded;
		# corrected server time can shorten them after a restart.
		var wait_seconds: int = clampi(int(job.get("retry_delay",0)),0,3600)
		var epoch: int = int(job.get("retry_server_at",0))
		if epoch > 0 and client.server_now() > 0: wait_seconds = clampi(epoch-client.server_now(),0,wait_seconds)
		_retry_deadlines[id] = Time.get_ticks_msec()+wait_seconds*1000
	return Time.get_ticks_msec() >= int(_retry_deadlines[id])

func _delay_job(job: Dictionary, seconds: int, failed: bool = false) -> void:
	var streak: int = int(job.get("retry_streak",0))+1 if failed else 0
	job.retry_streak = mini(streak,6)
	var bound: int = maxi(seconds,mini(600,15*int(pow(2,mini(streak,5))))) if failed else seconds
	var jitter: int = int(Crypto.new().generate_random_bytes(1)[0])%maxi(1,bound/3+1)
	job.retry_delay = maxi(seconds,mini(600,bound+jitter))
	job.retry_server_at = client.server_now()+int(job.retry_delay) if client.server_now() > 0 else 0
	job.erase("retry_at")
	_retry_deadlines[str(job.ticket)] = Time.get_ticks_msec()+int(job.retry_delay)*1000

func retry_upload(ticket_id: String) -> bool:
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var job: Dictionary = upload_job(ticket_id)
	if job.is_empty(): return false
	if job.has("run_id"):
		if not job.has("retry_key"):
			job.retry_key = client.new_operation_key()
			if not _save_pending_job(str(job._path),job): return false
		var response: Dictionary = await client.request_api("/runs/"+str(job.run_id)+"/retry",HTTPClient.METHOD_POST,{},str(job.retry_key),true)
		if str(client.player.get("id","")) != owner or client.base_url() != origin or not response.ok: return false
		job.erase("retry_key")
	elif job.get("failure","") not in ["INVALID_RESPONSE","TRANSPORT_UNSUPPORTED","REQUEST_START_FAILED"]:
		return false # Do not change expired or invalid operation identities.
	job.erase("failure")
	job.erase("retryable")
	job.retry_delay = 0
	_retry_deadlines[ticket_id] = 0
	return _save_pending_job(str(job._path),job)

func _submit_saved(job: Dictionary, path: String) -> Dictionary:
	var loaded: Variant = await client._background(_load_replay.bind(path.get_base_dir().path_join(str(job.get("replay",""))),str(job.get("replay_hash",""))))
	if not loaded is Dictionary or not loaded.get("frames") is Array:
		return {"ok":false,"status":422,"error":"REPLAY_RECOVERY_REQUIRED","data":{}}
	return await client.submit_run(str(job.ticket),loaded.frames,str(job.key),loaded.get("rewinds",[]),loaded.get("race_proof",{}),loaded.get("ghost",{}))

func flush_outbox() -> void:
	if flushing or not client.signed_in(): return
	flushing = true
	await _flush_jobs()
	flushing = false
	changed.emit()

func _flush_jobs() -> void:
	if not _migrate_outbox(): return
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var request_scope: String = origin+"/"+owner
	if Time.get_ticks_msec() < int(_flush_deadlines.get(request_scope,0)): return
	var directory: String = outbox_path().get_base_dir().path_join("runs")
	if not await _recover_pending(directory) or str(client.player.get("id","")) != owner or client.base_url() != origin: return
	var jobs: Array[Dictionary] = _pending_jobs(directory)
	var polled: Dictionary = {}
	var ids := PackedStringArray()
	for job: Dictionary in jobs:
		if job.has("run_id") and not job.has("failure") and _job_ready(job): ids.append("ids="+str(job.run_id).uri_encode())
	var batch: Dictionary = {}
	if not ids.is_empty() and bool(client._capabilities.get("batch_run_status",false)):
		batch = await client.request_api("/runs/status?"+"&".join(ids),HTTPClient.METHOD_GET,{},"",true)
		if str(client.player.get("id","")) != owner or client.base_url() != origin: return
		if int(batch.get("status",0)) == 429:
			_pause_flush(request_scope,batch)
			return
		if batch.ok and batch.data.get("items") is Array:
			for item: Variant in batch.data.items:
				if Client.valid_run(item): polled[str(item.run_id)] = item
	var checked: bool = false
	var unavailable: bool = false
	for job: Dictionary in jobs:
		var path: String = str(job._path)
		job.erase("_path")
		if str(client.player.get("id","")) != owner or client.base_url() != origin: break
		if job.has("done") or not _job_ready(job): continue
		if job.has("failure"):
			if job.get("failure","") != "verifier_unavailable" or not job.get("retryable",false): continue
			if not _reserve_background_write(request_scope): continue
			if not job.has("retry_key"):
				job.retry_key = client.new_operation_key()
				_save_job(path,job)
			var retried: Dictionary = await client.request_api("/runs/"+str(job.run_id)+"/retry",HTTPClient.METHOD_POST,{},str(job.retry_key),true)
			if str(client.player.get("id","")) != owner or client.base_url() != origin: break
			if not retried.ok:
				_delay_job(job,maxi(30,int(retried.get("retry_after",0))),true)
				if str(retried.get("error","")) in ["CONTRACT_UNSUPPORTED","INVALID_REPLAY"]: job.retryable = false
				_save_job(path,job)
				if int(retried.get("status",0)) == 429:
					_pause_flush(request_scope,retried)
					return
				continue
			job.erase("failure")
			job.erase("retry_key")
			_save_job(path,job)
		var response: Dictionary = {}
		if not job.has("run_id"):
			if not _reserve_background_write(request_scope): continue
			response = await _submit_saved(job,path)
			checked = true
			if str(client.player.get("id","")) != owner or client.base_url() != origin: break
			if response.ok and not Client.valid_run(response.get("data")): response = {"ok":false,"status":502,"error":"INVALID_RESPONSE","data":{}}
			if not response.ok:
				unavailable = unavailable or int(response.get("status",0)) >= 500 or response.get("error") == "NETWORK_ERROR"
				_delay_job(job,maxi(15,int(response.get("retry_after",0))),true)
				if int(response.get("status",0)) in [400,403,404,409,410,422]:
					job.failure = str(response.error)
					job.rejection_status = int(response.status)
				status = "Score upload pending: "+str(response.get("error","Unavailable"))
				_save_job(path,job)
				if int(response.get("status",0)) == 429:
					_pause_flush(request_scope,response)
					return
				continue
			job.run_id = response.data.run_id
			_save_job(path,job)
		if polled.has(str(job.run_id)): response = {"ok":true,"status":200,"data":polled[str(job.run_id)]}
		elif not batch.is_empty() and not batch.ok: response = batch
		elif response.is_empty(): response = await client.request_api("/runs/"+str(job.run_id),HTTPClient.METHOD_GET,{},"",true)
		checked = true
		if str(client.player.get("id","")) != owner or client.base_url() != origin: break
		if not response.ok and int(response.get("status",0)) == 404:
			if not _reserve_background_write(request_scope):
				_delay_job(job,5)
				_save_job(path,job)
				continue
			# Reconcile the original ticket/key/content. Never mint a replacement attempt.
			var recovered: Dictionary = await _submit_saved(job,path)
			if str(client.player.get("id","")) != owner or client.base_url() != origin: break
			if recovered.ok and Client.valid_run(recovered.get("data")):
				if str(recovered.data.run_id) == str(job.run_id): job.missing_checks = int(job.get("missing_checks",0))+1
				else: job.missing_checks = 0
				job.run_id = recovered.data.run_id
				response = recovered
				if int(job.get("missing_checks",0)) >= 3:
					job.failure = "RESTORE_RECOVERY_REQUIRED"
			else:
				response = recovered
				if int(recovered.get("status",0)) in [403,404,409,410,422]: job.failure = str(recovered.error)
		if response.ok and not Client.valid_run(response.get("data")): response = {"ok":false,"status":502,"error":"INVALID_RESPONSE","data":{}}
		if not response.ok:
			unavailable = unavailable or int(response.get("status",0)) >= 500 or response.get("error") == "NETWORK_ERROR"
			_delay_job(job,maxi(15,int(response.get("retry_after",0))),true)
			_save_job(path,job)
			if int(response.get("status",0)) == 429:
				_pause_flush(request_scope,response)
				return
			continue
		if response.data.status == "verified":
			if not str(job.get("publish","")).is_empty():
				# Preserve the recorded race and obsolete metadata; accepted race
				# retries cannot create a publication as an implicit side effect.
				job.publication_requires_explicit_request = true
			job.done = true
			status = "Race verified"
		elif response.data.status in ["rejected","failed"]:
			job.failure = str(response.data.get("failure_code","verification_failed"))
			job.retryable = bool(response.data.get("retryable",false))
			_delay_job(job,30,true)
			status = _upload_failure_message(str(job.failure))
		else:
			_delay_job(job,1 if int(response.data.get("poll_after_ms",2500)) <= 1000 else 3)
			status = "Race uploaded ? awaiting server verification"
		_save_job(path,job)
		if job.get("done",false) and _read(path).get("done",false): _retire_replay(job)
	if checked: run_connection_failed = unavailable

func _reserve_background_write(request_scope: String) -> bool:
	if Time.get_ticks_msec() < int(_write_deadlines.get(request_scope,0)): return false
	# Result uploads cost four units. Leave room in the shared account budget
	# for actual race starts, resume operations and player actions.
	_write_deadlines[request_scope] = Time.get_ticks_msec()+5000
	return true

func _pause_flush(request_scope: String, response: Dictionary) -> void:
	# A rate limit applies to the account, so stop the whole batch rather than
	# sending every remaining saved job into the same exhausted budget.
	_flush_deadlines[request_scope] = Time.get_ticks_msec()+maxi(60,int(response.get("retry_after",0)))*1000
