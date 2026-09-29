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
var last_error: String = ""
var root_override: String = ""
var catalog_url: String = ""

func cache_root() -> String:
	return (root_override if not root_override.is_empty() else "user://cloud").path_join(str(client._base_url).sha256_text())

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 8388608: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

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
	catalog_url = str(client._base_url)
	entries.clear()
	var cached: Variant = _read(cache_root().path_join("index.json")).get("entries",[])
	if cached is Array:
		for item: Variant in cached:
			if item is Dictionary and _valid_entry(item): entries.append(item)
	status = "Cached cloud catalog · refresh to check for updates"

func _valid_entry(item: Dictionary) -> bool:
	var version: String = str(item.get("version_id",""))
	var hash_value: String = str(item.get("content_hash",""))
	return version.length() == 36 and version.replace("-","").is_valid_hex_number(false) and hash_value.length() == 64 and hash_value.is_valid_hex_number(false) and item.get("points") is Array

func refresh() -> void:
	if refreshing: return
	if catalog_url != str(client._base_url): load_cached()
	refreshing = true
	status = "Refreshing cloud tracks…"
	changed.emit()
	var collected: Array[Dictionary] = []
	var offset: int = 0
	while true:
		var response: Dictionary = await client.request_api("/tracks?limit=100&offset=%d" % offset)
		if not response.ok:
			status = "Cloud unavailable · showing cached tracks · Refresh to retry"
			break
		var valid: bool = response.data.get("items") is Array
		if valid:
			for item: Variant in response.data.items:
				if not item is Dictionary or not _valid_entry(item):
					valid = false
					break
				collected.append(item)
		if not valid:
			status = "Invalid cloud catalog · keeping cached tracks"
			break
		var next_offset: Variant = response.data.get("next_offset")
		if next_offset == null:
			entries = collected
			status = "Cloud catalog up to date · tracks download when selected"
			if not _write(cache_root().path_join("index.json"),{"entries":entries}): status = "Cloud loaded · catalog could not be cached"
			break
		if int(next_offset) <= offset or int(next_offset) > 10000:
			status = "Cloud catalog exceeds this client's browsing limit"
			break
		offset = int(next_offset)
	refreshing = false
	changed.emit()

func add_to_catalog(catalog: TrackCatalog, discovery: TrackDiscoveryProvider = null) -> void:
	catalog.entries = catalog.entries.filter(func(item: Dictionary) -> bool: return item.source != "cloud")
	for item: Dictionary in entries:
		var entry: Dictionary = item.duplicate(true)
		entry.id = "cloud_"+str(item.version_id)
		entry.source = "cloud"
		entry.read_only = true
		entry.owned = str(item.get("creator_id","")) == str(client.player.get("id","")) and client.signed_in()
		entry.theme = TrackTheme.normalized(str(item.get("theme","pine")))
		entry.cache_path = cache_root().path_join(str(item.content_hash)+".json")
		catalog.entries.append(entry)
		if discovery != null:
			discovery.track_stats[entry.id] = {"score":float(item.rating_average) if item.rating_average != null else -1.0,"new":true}
	if discovery != null: discovery.available = true

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
	if not cached_document(entry).is_empty(): return true
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
	return true

static func compile_entry(entry: Dictionary) -> NativeTrack:
	var doc: Dictionary = cached_document(entry)
	if doc.is_empty(): return null
	var track: NativeTrack = TrackCompiler.compile(doc)
	if track != null:
		track.identity = str(entry.id)
		track.metadata["title"] = str(entry.name)
		track.metadata["cloud_version"] = str(entry.version_id)
		track.metadata["cloud_creator"] = str(entry.creator)
	return track

func ticket(track: NativeTrack) -> Dictionary:
	if not client.signed_in(): return {}
	var version: String = str(track.metadata.get("cloud_version",""))
	if version.is_empty(): return {}
	var response: Dictionary = await client.race_ticket(version,VehicleCatalog.selected,Client.new_idempotency_key())
	if not response.ok:
		last_error = str(response.error)
		return {}
	if str(response.data.manifest.track_content_hash) != track.content_hash:
		last_error = "Track differs from the server's race contract."
		return {}
	var manifest: Dictionary = response.data.manifest
	if str(manifest.physics_version) != VehicleSimulation.PHYSICS_VERSION or str(manifest.compiler_version) != TrackCompiler.VERSION or str(manifest.rules_key) != RaceRules.KEY:
		last_error = "The server requires a different game build."
		return {}
	var config: HandlingConfig = HandlingSelection.config()
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
	var fingerprint: String = TrackLibrary.draft_fingerprint(document)
	if not uploads.has(fingerprint):
		uploads[fingerprint] = Client.new_idempotency_key()
		if not _write(path,uploads): return {"ok":false,"error":"Could not save upload retry state"}
	return await client.upload_track(str(document.name),document,str(uploads[fingerprint]))

func outbox_path() -> String:
	return cache_root().path_join("players").path_join(str(client.player.get("id","")).sha256_text()).path_join("outbox.json")

func queue_run(ticket_data: Dictionary, frames: Array, publish_version: String = "") -> bool:
	if ticket_data.is_empty() or not client.signed_in(): return false
	var path: String = outbox_path()
	var box: Dictionary = _read(path)
	var jobs: Array = box.get("jobs",[])
	jobs = jobs.filter(func(job: Dictionary) -> bool: return not job.has("done"))
	jobs.append({"ticket":ticket_data.ticket_id,"frames":frames,"key":Client.new_idempotency_key(),"publish":publish_version,"publish_key":Client.new_idempotency_key()})
	var saved: bool = _write(path,{"jobs":jobs})
	if saved:
		status = "Race saved · upload pending"
		changed.emit()
	return saved

func _save_job(path: String, job: Dictionary) -> void:
	var latest: Array = _read(path).get("jobs",[])
	for index: int in range(latest.size()):
		if latest[index].key == job.key: latest[index] = job
	if not _write(path,{"jobs":latest}): status = "Upload state could not be saved · retry is safe"

func flush_outbox() -> void:
	if flushing or not client.signed_in(): return
	flushing = true
	var player_id: String = str(client.player.id)
	var path: String = outbox_path()
	var jobs: Array = _read(path).get("jobs",[])
	for job: Dictionary in jobs:
		if str(client.player.get("id","")) != player_id: break
		if job.has("done") or job.has("failure"): continue
		var response: Dictionary
		if not job.has("run_id"):
			response = await client.submit_run(str(job.ticket),job.frames,str(job.key))
			if not response.ok:
				if int(response.status) in [400,403,404,409,410,422]: job.failure = str(response.error)
				status = ("Score upload rejected: " if job.has("failure") else "Score upload pending: ")+str(response.error)
				_save_job(path,job)
				continue
			job.run_id = response.data.run_id
			job.erase("frames")
			_save_job(path,job)
		response = await client.request_api("/runs/"+str(job.run_id),HTTPClient.METHOD_GET,{},"",true)
		if not response.ok: continue
		if response.data.status == "verified":
			if not str(job.publish).is_empty():
				response = await client.request_api("/track-versions/"+str(job.publish)+"/publish",HTTPClient.METHOD_POST,{},str(job.publish_key),true)
				if not response.ok:
					status = "Publication pending: "+str(response.error)
					continue
			job.done = true
			status = "Race verified" + (" · track published to cloud" if not str(job.publish).is_empty() else " · leaderboard updated")
		elif response.data.status in ["rejected","failed"]:
			job.failure = str(response.data.failure_code)
			status = "Race verification rejected: "+str(job.failure)
		else: status = "Race uploaded · awaiting server verification"
		# Reload preserves races queued while an HTTP request was in flight.
		_save_job(path,job)
	flushing = false
	changed.emit()
