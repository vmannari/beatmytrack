extends Node
## Network/cache work lives outside canonical simulation. Public cache is server scoped;
## durable submissions are additionally scoped to the authenticated player.
signal changed
const Client = preload("res://backend/backend_client.gd")
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
var _snapshot_entries: Array[Dictionary] = []
const MAX_CATALOG_ENTRIES: int = 1000
var _recovered_outboxes: Dictionary = {}
var _pending_iterators: Dictionary = {}
const MAX_FLUSH_JOBS: int = 16

func _pending_marker(path: String) -> String:
	return path.get_base_dir().get_base_dir().path_join("pending").path_join(path.get_file())

func _save_pending_job(path: String, job: Dictionary) -> bool:
	var active: bool = not job.has("done") and not job.has("failure")
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
				if not value is Dictionary or (not value.has("done") and not value.has("failure")): result.append(filename)
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
				if job.has("done") or job.has("failure"): DirAccess.remove_absolute(pending.path_join(filename))
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
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: return {"_read_error":true}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {"_read_error":true}
	var value: Variant = json.data
	return value if value is Dictionary else {"_read_error":true}

func _write(path: String, value: Dictionary) -> bool:
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
	catalog_url = str(client.base_url())
	next_cursor = ""
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
	if refreshing: return
	if not force and Time.get_ticks_msec()-last_refresh_msec < 60000: return
	last_refresh_msec = Time.get_ticks_msec()
	if catalog_url != str(client.base_url()): load_cached()
	refreshing = true
	status = "Refreshing cloud tracks…"
	changed.emit()
	var collected: Array[Dictionary] = entries.duplicate(true)
	if next_cursor.is_empty(): _snapshot_entries.clear()
	for page: int in range(3):
		var response: Dictionary = await client.request_api("/tracks?limit=100"+("&cursor="+next_cursor.uri_encode() if not next_cursor.is_empty() else ""))
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
	_remember_aliases()
	changed.emit()

func search(filters: Dictionary) -> void:
	_search_serial += 1
	var serial: int = _search_serial
	var query: String = str(filters.get("search",""))
	var kind: String = ["search","q","creator"][clampi(int(filters.get("search_kind",0)),0,2)]
	var path: String = "/tracks?limit=100&"+kind+"="+query.uri_encode()
	var theme: String = str(filters.get("theme","all"))
	if theme != "all": path += "&theme="+theme.uri_encode()
	path += "&minimum_rating="+str(float(filters.get("minimum_rating",0.0)))
	var response: Dictionary = await client.request_public(path,get_instance_id())
	if serial != _search_serial or not response.ok or not response.data.get("items") is Array: return
	for item: Variant in response.data.items:
		if not item is Dictionary or not _valid_entry(item): return
	for item: Dictionary in response.data.items:
		entries = entries.filter(func(old: Dictionary) -> bool: return old.track_id != item.track_id)
		entries.append(item)
	while entries.size() > MAX_CATALOG_ENTRIES: entries.pop_front()
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
	return _write(directory.path_join(identity.sha256_text()+".json"),metadata) and _write(directory.path_join(("cloud_"+str(metadata.version_id)).sha256_text()+".json"),{"alias":identity})

func add_to_catalog(catalog: TrackCatalog, discovery: TrackDiscoveryProvider = null, retained: Array = []) -> void:
	catalog.entries = catalog.entries.filter(func(item: Dictionary) -> bool: return item.source != "cloud")
	var available: Array[Dictionary] = entries.duplicate()
	var known: Dictionary = {}
	for item: Dictionary in available: known["cloud_"+str(item.track_id)] = true
	for identity: Variant in retained:
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
	if discovery != null: discovery.available = true

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
	entries = entries.filter(func(old: Dictionary) -> bool: return str(old.track_id) != str(metadata.track_id))
	entries.append(metadata.duplicate(true))
	while entries.size() > MAX_CATALOG_ENTRIES: entries.pop_front()
	if not _write(cache_root().path_join("index.json"),{"entries":entries}): return false
	_remember_aliases()
	changed.emit()
	return true

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
	local.settings.last_track = aliases.get(last,last)
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
	var track: NativeTrack = TrackCompiler.compile(doc)
	if track != null:
		track.identity = str(entry.id)
		track.metadata["title"] = str(entry.name)
		track.metadata["cloud_version"] = str(entry.version_id)
		track.metadata["cloud_track_id"] = str(entry.track_id)
		track.metadata["cloud_creator"] = str(entry.creator)
	return track

func ticket(track: NativeTrack, creator_test: bool = false, vehicle_id: String = "", attempt_handling: HandlingConfig = null) -> Dictionary:
	if not client.signed_in(): return {}
	var version: String = str(track.metadata.get("cloud_version",""))
	if version.is_empty(): return {}
	var selected_vehicle: String = VehicleCatalog.selected if vehicle_id.is_empty() else vehicle_id
	var response: Dictionary = await client.race_ticket(version,selected_vehicle,Client.new_idempotency_key(),"creator_test" if creator_test else "race")
	if not response.ok:
		last_error = str(response.error)
		return {}
	if str(response.data.manifest.track_content_hash) != track.content_hash:
		last_error = "Track differs from the server's race contract."
		return {}
	var manifest: Dictionary = response.data.manifest
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
	return response.data

func upload_draft(document: Dictionary) -> Dictionary:
	var path: String = outbox_path().get_base_dir().path_join("uploads.json")
	var uploads: Dictionary = _read(path)
	if uploads.has("_read_error"): return {"ok":false,"error":"Upload retry state needs recovery; original data was preserved"}
	var fingerprint: String = TrackLibrary.draft_fingerprint(document)
	if not uploads.has(fingerprint):
		uploads[fingerprint] = Client.new_idempotency_key()
		if not _write(path,uploads): return {"ok":false,"error":"Could not save upload retry state"}
	return await client.upload_track(str(document.name),document,str(uploads[fingerprint]))

func outbox_path() -> String:
	return cache_root().path_join("players").path_join(str(client.player.get("id","")).sha256_text()).path_join("outbox.json")

func queue_run(ticket_data: Dictionary, frames: Array, publish_version: String = "", rewinds: Array = []) -> bool:
	if ticket_data.is_empty(): return false
	var owner: String = str(ticket_data.get("_owner_id",client.player.get("id","")))
	var origin: String = str(ticket_data.get("_origin",client.base_url()))
	if owner.is_empty() or origin.is_empty(): return false
	if frames.is_empty():
		last_error = "This test has no recorded inputs. Complete a new test drive."
		return false
	var root_path: String = (root_override if not root_override.is_empty() else "user://cloud").path_join(origin.sha256_text())
	var directory: String = root_path.path_join("players").path_join(owner.sha256_text()).path_join("runs")
	var name: String = str(ticket_data.ticket_id).sha256_text()
	var path: String = directory.path_join(name+".job.json")
	var existing: Dictionary = _read(path)
	var replay_hash: String = JSON.stringify({"frames":frames,"rewinds":rewinds}).sha256_text()
	if existing.has("_read_error"):
		last_error = "Saved upload state needs recovery; existing data was preserved."
		return false
	if not existing.is_empty():
		if str(existing.get("replay_hash","")) != replay_hash: return false
		if existing.has("run_id"): return true
		return _replay_integrity(directory.path_join(name+".replay.json"),replay_hash)
	var saved: bool = _write(directory.path_join(name+".replay.json"),{"frames":frames,"rewinds":rewinds})
	if saved:
		saved = _save_pending_job(path,{"ticket":ticket_data.ticket_id,"replay":name+".replay.json","replay_hash":replay_hash,"key":Client.new_idempotency_key(),"publish":publish_version,"publish_key":Client.new_idempotency_key()})
	if not saved: last_error = "The race could not be saved. Free storage and retry."
	if saved:
		status = "Race saved · upload pending"
		changed.emit()
	return saved

func _replay_integrity(path: String, expected_hash: String) -> bool:
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

func retry_upload(ticket_id: String) -> bool:
	var owner: String = str(client.player.get("id",""))
	var origin: String = str(client.base_url())
	var job: Dictionary = upload_job(ticket_id)
	if job.is_empty() or not job.has("run_id"): return false
	var response: Dictionary = await client.request_api("/runs/"+str(job.run_id)+"/retry",HTTPClient.METHOD_POST,{},client.new_idempotency_key(),true)
	if str(client.player.get("id","")) != owner or str(client.base_url()) != origin or not response.ok: return false
	job.erase("failure")
	return _save_pending_job(str(job._path),job)

func flush_outbox() -> void:
	if flushing or not client.signed_in(): return
	flushing = true
	if not _migrate_outbox():
		flushing = false
		changed.emit()
		return
	var player_id: String = str(client.player.id)
	var origin: String = str(client._base_url)
	var directory: String = outbox_path().get_base_dir().path_join("runs")
	if not await _recover_pending(directory) or str(client.player.get("id","")) != player_id or str(client._base_url) != origin:
		flushing = false
		return
	var jobs: Array[Dictionary] = _pending_jobs(directory)
	var connection_checked: bool = false
	var connection_failed: bool = false
	for job: Dictionary in jobs:
		var path: String = str(job._path)
		job.erase("_path")
		if str(client.player.get("id","")) != player_id: break
		if job.has("done") or job.has("failure"): continue
		if int(job.get("retry_at",0)) > int(Time.get_unix_time_from_system()): continue
		var response: Dictionary
		if not job.has("run_id"):
			var replay_path: String = path.get_base_dir().path_join(str(job.get("replay","")))
			if not _replay_integrity(replay_path,str(job.get("replay_hash",""))):
				status = "Replay needs recovery; its files were preserved."
				continue
			var replay: Dictionary = _read(replay_path)
			if not replay.get("frames") is Array:
				status = "Replay needs recovery; its files were preserved."
				continue
			response = await client.submit_run(str(job.ticket),replay.frames,str(job.key),replay.get("rewinds",[]))
			connection_checked = true
			if str(client.player.get("id","")) != player_id or str(client._base_url) != origin: break
			if not response.ok:
				connection_failed = connection_failed or str(response.get("error","")) == "NETWORK_ERROR" or int(response.get("status",0)) >= 500
				job.retry_at = int(Time.get_unix_time_from_system())+maxi(15,int(response.get("retry_after",0)))
				if int(response.status) in [400,403,404,409,410,422]:
					job.failure = str(response.error)
					job.rejection_status = int(response.status)
				status = ("Score upload rejected: " if job.has("failure") else "Score upload pending: ")+str(response.error)
				_save_job(path,job)
				continue
			job.run_id = response.data.run_id
			_save_job(path,job)
		response = await client.request_api("/runs/"+str(job.run_id),HTTPClient.METHOD_GET,{},"",true)
		connection_checked = true
		if str(client.player.get("id","")) != player_id or str(client._base_url) != origin: break
		if not response.ok:
			connection_failed = connection_failed or str(response.get("error","")) == "NETWORK_ERROR" or int(response.get("status",0)) >= 500
			job.retry_at = int(Time.get_unix_time_from_system())+maxi(15,int(response.get("retry_after",0)))
			_save_job(path,job)
			continue
		if response.data.status == "verified":
			if not str(job.publish).is_empty():
				response = await client.request_api("/track-versions/"+str(job.publish)+"/publish",HTTPClient.METHOD_POST,{},str(job.publish_key),true)
				if str(client.player.get("id","")) != player_id or str(client._base_url) != origin: break
				if not response.ok:
					status = "Publication pending: "+str(response.error)
					continue
			job.done = true
			status = "Race verified" + (" · track published to cloud" if not str(job.publish).is_empty() else " · leaderboard updated")
		elif response.data.status in ["rejected","failed"]:
			job.failure = str(response.data.failure_code)
			job.retryable = bool(response.data.get("retryable",false))
			status = _upload_failure_message(str(job.failure))
		else: status = "Race uploaded · awaiting server verification"
		# Reload preserves races queued while an HTTP request was in flight.
		_save_job(path,job)
		if job.get("done",false) and _read(path).get("done",false): _retire_replay(job)
	flushing = false
	if connection_checked: run_connection_failed = connection_failed
	changed.emit()
