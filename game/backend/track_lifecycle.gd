class_name TrackLifecycle
extends Node
## Durable authoring operations. Never called from a canonical simulation step.
signal changed
var cloud: Node
var library: TrackLibrary
var records: LocalRecords
var busy: bool = false
var last_error: String = ""
var _pending: Dictionary = {}
var legacy_directories: Array[String] = []
var _restored_scope: String = ""
var _restore_offset: int = 0
var _restoring_scope: String = ""

func scope() -> String:
	return str(cloud.client._base_url)+"/"+str(cloud.client.player.get("id","guest"))

func _root() -> String:
	return library.directory.path_join(".workflow").path_join(scope().sha256_text())

func _path(document: Dictionary) -> String:
	return _root().path_join(TrackLibrary.draft_fingerprint(document)+".job.json")

func _archive_path(id: String, directory: String = "") -> String:
	return (_root() if directory.is_empty() else directory).path_join(id.sha256_text()+".archive.json")

func _archived(id: String, directory: String = "") -> bool:
	# Existence fails closed, including an interrupted/corrupt archive receipt.
	return FileAccess.file_exists(_archive_path(id,directory)) or FileAccess.file_exists(_archive_path(id,directory)+".tmp")

func archive_draft(id: String) -> bool:
	if not TrackDocument.valid_id(id): return false
	var path: String = _archive_path(id)
	if not FileAccess.file_exists(path) and not cloud._write(path,{"id":id,"scope":scope(),"key":cloud.client.new_operation_key(),"synced":false}):
		last_error = "Deletion could not be saved. Free storage and retry; the draft is preserved."
		return false
	_pending.erase(id)
	return true

func _flush_archives(owner_scope: String) -> void:
	if not DirAccess.dir_exists_absolute(_root()): return
	for filename: String in DirAccess.get_files_at(_root()):
		if not filename.ends_with(".archive.json"): continue
		var path: String = _root().path_join(filename)
		var intent: Dictionary = cloud._read(path)
		if intent.get("synced",false) or intent.get("scope") != owner_scope or not TrackDocument.valid_id(intent.get("id")) or not intent.get("key") is String: continue
		var response: Dictionary = await cloud.client.request_api("/me/drafts/"+str(intent.id).uri_encode()+"/archive",HTTPClient.METHOD_POST,{},str(intent.key),true)
		if scope() != owner_scope: return
		if response.ok:
			intent.synced = true
			cloud._write(path,intent)

func _read(path: String) -> Dictionary:
	var existed: bool = false
	for candidate: String in [path,path+".bak",path+".tmp"]:
		existed = existed or FileAccess.file_exists(candidate)
		var value: Dictionary = cloud._read(candidate)
		if value.get("schema") != "track-lifecycle-1": continue
		var complete: bool = true
		for field: String in ["scope","library_directory","fingerprint","upload_key","publish_key","ticket_key","state"]:
			if not value.get(field) is String: complete = false
		if not (value.get("created_at") is int or value.get("created_at") is float): complete = false
		if value.get("state") == "published":
			complete = complete and value.get("receipt") is Dictionary
		else:
			complete = complete and value.get("document") is Dictionary
			if complete: complete = TrackDocument.valid_id(value.document.get("id")) and value.document.get("name") is String
		if complete: return value
	return {"_read_error":true} if existed else {}

func _save(path: String, value: Dictionary, new_proof: bool = false) -> bool:
	if value.has("authoring_id") and _archived(str(value.authoring_id),path.get_base_dir()): return false
	var previous: Dictionary = cloud._read(path)
	if previous.get("publish_requested",false): value.publish_requested = true
	if not new_proof and previous.has("proof_file") and previous.get("proof_file") != value.get("proof_file"):
		for field: String in ["proof_file","vehicle","contract","ticket_key"]: value[field] = previous[field]
		value.erase("ticket")
		value.erase("failure")
		value.state = "saved"
	if previous.get("state") == "published":
		value.clear()
		value.merge(previous,true)
	if previous.get("schema") == "track-lifecycle-1" and not cloud._write(path+".bak",previous):
		last_error = "Could not preserve publication recovery state. Free storage and retry."
		return false
	if not cloud._write(path,value):
		last_error = "Could not save track recovery state. Free storage and retry."
		return false
	return true

func defer_sync(document: Dictionary) -> void:
	if document.is_empty() or _archived(str(document.id)): return
	_pending[str(document.id)] = {"document":document.duplicate(true),"scope":scope(),"library":library}

func stage(document: Dictionary, frames: Array = [], vehicle: String = "compact", source: TrackLibrary = null, owner_scope: String = "", race_proof: Dictionary = {}) -> Dictionary:
	if not TrackDocument.validate(document,false).is_empty():
		last_error = "This draft could not be saved for synchronization."
		return {}
	var storage: TrackLibrary = library if source == null else source
	var operation_scope: String = scope() if owner_scope.is_empty() else owner_scope
	var path: String = storage.directory.path_join(".workflow").path_join(operation_scope.sha256_text()).path_join(TrackLibrary.draft_fingerprint(document)+".job.json")
	if _archived(str(document.id),path.get_base_dir()):
		last_error = "This draft was deleted. Save a new track to continue."
		return {}
	var job: Dictionary = _read(path)
	if job.has("_read_error"):
		last_error = "Track recovery data needs repair; its original files were preserved."
		return {}
	if job.is_empty():
		var counter_path: String = path.get_base_dir().path_join("sequence.json")
		var counter: Dictionary = cloud._read(counter_path)
		if counter.has("_read_error"):
			last_error = "Track sync recovery data needs repair; the original files are preserved."
			return {}
		var sequence: int = int(counter.get("value",0))+1
		var latest: Dictionary = counter.get("latest",{})
		var predecessor: String = str(latest.get(str(document.id),""))
		latest[str(document.id)] = TrackLibrary.draft_fingerprint(document)
		if not cloud._write(counter_path,{"value":sequence,"latest":latest}):
			last_error = "Could not save track synchronization state. Free storage and retry."
			return {}
		var heads: Dictionary = cloud._read(path.get_base_dir().path_join("heads.json"))
		if heads.has("_read_error"):
			last_error = "Track sync recovery data needs repair; the original files are preserved."
			return {}
		job = {"schema":"track-lifecycle-1","scope":operation_scope,"library_directory":storage.directory,
			"document":document.duplicate(true),"fingerprint":TrackLibrary.draft_fingerprint(document),
			"sequence":sequence,"expected_head":str(heads.get(str(document.id),"new")),
			"upload_key":cloud.client.new_operation_key(),"publish_key":cloud.client.new_operation_key(),
			"ticket_key":cloud.client.new_operation_key(),"state":"saved","created_at":int(Time.get_unix_time_from_system())}
		job.authoring_id = str(document.id)
		job.predecessor = predecessor
	if not frames.is_empty() and job.get("state") not in ["ready","publishing","finishing","published"]:
		var contract: Dictionary = _contract(document,vehicle)
		var keep_ticket: bool = job.has("ticket") and job.get("contract") == contract and job.get("vehicle") == vehicle
		var recording: Dictionary = {"frames":frames}
		if not race_proof.is_empty(): recording.race_proof = race_proof
		var proof_name: String = job.fingerprint+"."+JSON.stringify(recording).sha256_text()+".proof.json"
		if not cloud._write(path.get_base_dir().path_join(proof_name),recording):
			last_error = "The completed test could not be saved. Free storage, then retry saving it."
			return {}
		job.proof_file = proof_name
		job.vehicle = vehicle
		job.contract = contract
		if not keep_ticket: job.erase("ticket")
		job.erase("failure")
		if not keep_ticket: job.ticket_key = cloud.client.new_operation_key()
		job.state = "saved"
	if not _save(path,job,not frames.is_empty()): return {}
	if not frames.is_empty() and not cloud._write(path+".bak",job):
		last_error = "The recording is saved, but recovery storage needs attention. Retry saving it."
		return {}
	if operation_scope == scope() and _pending.has(str(document.id)) and TrackLibrary.draft_fingerprint(_pending[str(document.id)].document) == TrackLibrary.draft_fingerprint(document):
		_pending.erase(str(document.id))
	changed.emit()
	return {"path":path,"job":job}

static func _contract(document: Dictionary, vehicle: String) -> Dictionary:
	var track: NativeTrack = TrackCompiler.compile(document)
	var config: HandlingConfig = VehicleCatalog.config(vehicle)
	var values: Dictionary = {}
	for property: Dictionary in config.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: values[str(property.name)] = config.get(str(property.name))
	var engine: Dictionary = Engine.get_version_info()
	var engine_version: String = "%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)]
	return {"physics_version":VehicleSimulation.PHYSICS_VERSION,"rules_key":RaceRules.KEY,"engine_version":engine_version,
		"tick_rate":VehicleSimulation.TICK_RATE,"track_schema":TrackDocument.SCHEMA,"replay_schema":"bmt-replay-v1",
		"verifier_version":"canonical-verifier-1",
		"compiler_version":TrackCompiler.VERSION,"track_content_hash":track.content_hash if track != null else "",
		"config_hash":JSON.stringify(values,"",true).sha256_text()}

func jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(_root()): return result
	var known: Dictionary = {}
	for filename: String in DirAccess.get_files_at(_root()):
		var base: String = filename.trim_suffix(".bak").trim_suffix(".tmp")
		if not base.ends_with(".job.json") or known.has(base): continue
		known[base] = true
		var path: String = _root().path_join(base)
		var job: Dictionary = _read(path)
		if job.get("scope") != scope(): continue
		job["_path"] = path
		result.append(job)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("sequence",0)) < int(b.get("sequence",0)) if a.has("sequence") or b.has("sequence") else int(a.created_at) < int(b.created_at))
	return result

func status_for(document: Dictionary) -> Dictionary:
	return _read(_path(document)) if not document.is_empty() else {}

func ready_to_publish(document: Dictionary) -> bool:
	return status_for(document).get("state","") == "ready"

func can_retry(document: Dictionary) -> bool:
	var job: Dictionary = status_for(document)
	if job.get("publication_error") == "NO_PUBLISHING_SLOTS": return true
	if not _own_predecessor(job).is_empty(): return true
	var remote: Dictionary = job.get("remote",{})
	if job.has("ticket"):
		var upload: Dictionary = cloud.upload_job(str(job.ticket.ticket_id))
		if upload.get("retryable",false): return true
	return bool(remote.get("validation",{}).get("retryable",false)) or (remote.get("proof") is Dictionary and bool(remote.proof.get("retryable",false)))

func _own_predecessor(job: Dictionary) -> Dictionary:
	if not "REVISION_CONFLICT" in str(job.get("failure","")) or not job.has("document"): return {}
	var candidate: Dictionary = {}
	for earlier: Dictionary in jobs():
		if earlier.get("authoring_id") != str(job.document.id) or not earlier.has("version_id") or int(earlier.get("sequence",0)) >= int(job.get("sequence",0)): continue
		if candidate.is_empty() or int(earlier.get("sequence",0)) > int(candidate.get("sequence",0)): candidate = earlier
	return candidate

func caption(document: Dictionary) -> String:
	var job: Dictionary = status_for(document)
	if job.has("_read_error"): return "Track recovery data needs repair; original files are preserved."
	if job.is_empty():
		var pending: Dictionary = _pending.get(str(document.get("id","")),{})
		return str(pending.failure) if pending.get("scope") == scope() and pending.has("failure") else "Saved on this device · waiting to sync"
	if job.has("failure"): return str(job.failure)
	return {"saved":"Saved on this device · waiting to sync","syncing":"Syncing draft…",
		"validating":"Draft backed up · validating…","draft":"Draft backed up · test required",
		"verifying":"Completed test saved · verifying…","ready":"Verified · ready to publish",
		"publishing":"Publishing…","finishing":"Published · finishing download and cleanup…",
		"published":"Published · available through the backend"}.get(str(job.get("state","")),"Track synchronization pending")

func process_jobs() -> void:
	if busy or cloud == null or library == null: return
	for item: Dictionary in _pending.values().duplicate():
		if item.scope == scope() and item.library == library:
			if stage(item.document).is_empty(): item.failure = last_error
	if not cloud.client.signed_in(): return
	busy = true
	last_error = ""
	var owner_scope: String = scope()
	await _flush_archives(owner_scope)
	if scope() != owner_scope:
		busy = false
		return
	if _restored_scope != owner_scope:
		await _restore_heads(owner_scope)
	var pending_jobs: Array[Dictionary] = jobs()
	var latest: Dictionary = {}
	for job: Dictionary in pending_jobs:
		if job.has("document"): latest[str(job.document.id)] = int(job.get("sequence",0))
	for job: Dictionary in pending_jobs:
		if scope() != owner_scope: break
		if job.has("document") and _archived(str(job.document.id)): continue
		if job.get("state") == "published":
			_retire_published(str(job._path),job)
			continue
		if job.has("failure"): continue
		if int(job.get("retry_at",0)) > int(Time.get_unix_time_from_system()): continue
		if not job.has("version_id") and not job.has("proof_file") and not job.get("upload_attempted",false) and int(job.get("sequence",0)) < int(latest.get(str(job.document.id),0)): continue
		await _advance(str(job._path),job,owner_scope)
	busy = false
	changed.emit()

func _advance(path: String, job: Dictionary, owner_scope: String) -> void:
	job.erase("_path")
	if job.scope != scope() or owner_scope != scope(): return
	if not job.get("document") is Dictionary: return
	if _archived(str(job.document.get("id","")),path.get_base_dir()): return
	if not job.has("version_id"):
		job.state = "syncing"
		if not _save(path,job): return
		var body: Dictionary = {"name":job.document.name,"document":job.document,"authoring_id":job.document.id,"defer_validation":true}
		var heads: Dictionary = cloud._read(path.get_base_dir().path_join("heads.json"))
		if not job.has("expected_head"):
			job.expected_head = str(heads.get(str(job.document.id),""))
			if not _save(path,job): return
		if not job.get("upload_attempted",false):
			var predecessor: String = str(job.get("predecessor",""))
			var visited: Dictionary = {}
			while predecessor.length() == 64 and predecessor.is_valid_hex_number(false) and not visited.has(predecessor):
				visited[predecessor] = true
				var earlier: Dictionary = _read(path.get_base_dir().path_join(predecessor+".job.json"))
				if earlier.get("scope") != owner_scope or earlier.get("authoring_id") != str(job.document.id): break
				if earlier.has("version_id"):
					if earlier.get("upload_attempted",false) and str(earlier.get("expected_head","")) == str(job.expected_head): job.expected_head = str(earlier.version_id)
					break
				if earlier.get("upload_attempted",false): return # Its response/retry establishes the head first.
				predecessor = str(earlier.get("predecessor",""))
			job.upload_attempted = true
			if not _save(path,job): return
		if not str(job.expected_head).is_empty(): body.expected_head_revision_id = job.expected_head
		var response: Dictionary = await cloud.client.request_api("/tracks",HTTPClient.METHOD_POST,body,str(job.upload_key),true)
		if scope() != owner_scope: return
		if _archived(str(job.document.id),path.get_base_dir()): return
		if not response.ok:
			last_error = str(response.error)
			if int(response.status) in [400,403,409,422]: job.failure = "Draft sync needs attention: "+last_error
			else: job.retry_at = int(Time.get_unix_time_from_system())+maxi(15,int(response.get("retry_after",0)))
			_save(path,job)
			return
		job.version_id = str(response.data.version_id)
		job.track_id = str(response.data.track_id)
		if not _save(path,job): return
		heads[str(job.document.id)] = job.version_id
		cloud._write(path.get_base_dir().path_join("heads.json"),heads)
	var status: Dictionary = await cloud.client.request_api("/me/track-versions/"+str(job.version_id),HTTPClient.METHOD_GET,{},"",true)
	if scope() != owner_scope or not status.ok: return
	if _archived(str(job.document.id),path.get_base_dir()): return
	job.remote = status.data
	if status.data.state == "published":
		job.receipt = status.data
		job.state = "finishing"
		if _save(path,job): await _finalize(path,job,owner_scope)
		return
	if status.data.state == "validating":
		job.state = "validating"
		if status.data.validation.get("status") == "failed": job.failure = str(status.data.validation.detail)
		_save(path,job)
		return
	if status.data.state == "invalid":
		job.state = "invalid"
		job.failure = "Edit this draft: "+str(status.data.validation.get("detail","Track validation failed"))
		_save(path,job)
		return
	if status.data.state == "tested":
		job.state = "ready"
		job.erase("failure")
	elif job.has("proof_file"):
		job.state = "verifying"
		if not job.has("ticket"):
			var config: Dictionary = status.data.manifest.get("vehicles",{}).get(str(job.vehicle),{})
			for field: String in ["engine_version","verifier_version","physics_version","rules_key","compiler_version","track_content_hash","tick_rate","track_schema","replay_schema"]:
				if job.contract.get(field) != status.data.manifest.get(field):
					job.failure = "This saved test requires a different track or game build. Its recording is preserved."
					_save(path,job)
					return
			if job.contract.config_hash != config.get("config_hash"):
				job.failure = "This saved test requires its original vehicle handling. Its recording is preserved."
				_save(path,job)
				return
			var issued: Dictionary = await cloud.client.race_ticket(str(job.version_id),str(job.vehicle),str(job.ticket_key),"creator_test")
			if scope() != owner_scope or not issued.ok: return
			job.ticket = issued.data
			if not _save(path,job): return
		var replay: Dictionary = cloud._read(path.get_base_dir().path_join(str(job.proof_file)))
		if replay.has("race_proof"): job.ticket["_race_proof"] = replay.race_proof
		if not replay.get("frames") is Array or not await cloud.queue_run_async(job.ticket,replay.frames):
			last_error = "The completed test is saved but could not be queued. Retry after freeing storage."
			return
		await cloud.flush_outbox()
		if scope() != owner_scope: return
		var upload: Dictionary = cloud.upload_job(str(job.ticket.ticket_id))
		if upload.has("failure"):
			if not upload.has("run_id") and int(upload.get("rejection_status",0)) == 410:
				job.erase("ticket")
				job.ticket_key = cloud.client.new_operation_key()
			else: job.failure = "Test verification needs attention: "+str(upload.failure)
	else:
		job.state = "draft"
	if not _save(path,job): return
	if job.get("publish_requested",false) and job.state == "ready":
		job.state = "publishing"
		if not _save(path,job): return
		var published: Dictionary = await cloud.client.request_api("/track-versions/"+str(job.version_id)+"/publish",
			HTTPClient.METHOD_POST,{},str(job.publish_key),true)
		if scope() != owner_scope: return
		if not published.ok:
			if published.get("error") == "NO_PUBLISHING_SLOTS":
				job.state = "ready"
				job.publication_error = "NO_PUBLISHING_SLOTS"
				job.failure = "No publishing slots left. Add slots, then Retry. Your verified draft is saved."
				last_error = job.failure
				_save(path,job)
			return
		job.receipt = published.data
		job.state = "finishing"
		if _save(path,job): await _finalize(path,job,owner_scope)

func prepare_test(document: Dictionary) -> Dictionary:
	if not cloud.client.signed_in(): return document
	var original_scope: String = scope()
	var compatible: Dictionary = await cloud.client.request_api("/manifest")
	if original_scope != scope(): return {}
	if not compatible.ok:
		last_error = "Backend unavailable · test recording will be saved for later verification."
		return document
	var local: Dictionary = _contract(document,VehicleCatalog.selected)
	for field: String in ["engine_version","physics_version","rules_key","compiler_version","tick_rate","track_schema"]:
		if compatible.data.get(field) != local.get(field):
			last_error = "The backend requires a different game build. Update the backend before testing for publication."
			return {}
	var staged: Dictionary = stage(document)
	if staged.is_empty(): return {}
	var owner_scope: String = scope()
	for attempt: int in range(15):
		await _advance(str(staged.path),_read(str(staged.path)),owner_scope)
		if scope() != owner_scope: return {}
		var job: Dictionary = _read(str(staged.path))
		if job.has("failure"):
			last_error = str(job.failure)
			return {}
		if job.get("state") in ["draft","ready"]:
			var response: Dictionary = await cloud.client.request_api("/me/track-versions/"+str(job.version_id)+"/document",HTTPClient.METHOD_GET,{},"",true)
			if scope() != owner_scope or not response.ok: return {}
			if str(response.get("body","")).sha256_text() != str(job.remote.content_hash) or not TrackDocument.validate(response.data).is_empty():
				last_error = "The backend draft failed its integrity check."
				return {}
			var exact_stage: Dictionary = stage(response.data)
			if exact_stage.is_empty(): return {}
			var exact_job: Dictionary = exact_stage.job
			exact_job.version_id = job.version_id
			exact_job.track_id = job.track_id
			exact_job.contract = _contract(response.data,VehicleCatalog.selected)
			exact_job.vehicle = VehicleCatalog.selected
			var issued: Dictionary = await cloud.client.race_ticket(str(job.version_id),str(exact_job.vehicle),str(exact_job.ticket_key),"creator_test")
			if scope() != owner_scope or not issued.ok:
				last_error = str(issued.get("error","Test contract unavailable"))
				return {}
			exact_job.ticket = issued.data
			if not _save(str(exact_stage.path),exact_job): return {}
			return response.data
		await get_tree().create_timer(0.2).timeout
	last_error = "Your draft is saved. Validation is still pending; retry Test when the backend is ready."
	return {}

func request_publish(document: Dictionary) -> bool:
	var path: String = _path(document)
	var job: Dictionary = _read(path)
	if job.get("state") not in ["ready","finishing","published"]:
		last_error = "Wait for this exact revision's server-verified test before publishing."
		return false
	job.publish_requested = true
	if not _save(path,job): return false
	await process_jobs()
	return true

func retry(document: Dictionary) -> void:
	var path: String = _path(document)
	var job: Dictionary = _read(path)
	if job.is_empty() or job.has("_read_error"): return
	var owner_scope: String = scope()
	var retried: bool = false
	var predecessor: Dictionary = _own_predecessor(job)
	if job.get("publication_error") == "NO_PUBLISHING_SLOTS":
		job.erase("publication_error")
		retried = true
	elif not predecessor.is_empty():
		var head: Dictionary = await cloud.client.request_api("/me/drafts/"+str(document.id).uri_encode()+"/head?upload_key="+str(predecessor.upload_key).uri_encode(),HTTPClient.METHOD_GET,{},"",true)
		if scope() != owner_scope: return
		if not head.ok or str(head.data.version_id) != str(predecessor.version_id) or str(head.data.get("acknowledged_upload_version_id","")) != str(predecessor.version_id):
			job.failure = "REVISION_CONFLICT: another device changed this draft. Save as a new track to preserve both versions." if head.ok else "REVISION_CONFLICT: could not confirm your previous upload. Retry when connected; your snapshot is preserved."
			_save(path,job)
			changed.emit()
			return
		job.expected_head = str(predecessor.version_id)
		job.upload_key = cloud.client.new_operation_key() # A changed request must have a fresh operation identity.
		job.upload_attempted = true
		retried = true
	elif job.has("version_id") and job.get("remote",{}).get("validation",{}).get("retryable",false):
		var response: Dictionary = await cloud.client.request_api("/me/track-versions/"+str(job.version_id)+"/retry-validation",HTTPClient.METHOD_POST,{},cloud.client.new_operation_key(),true)
		retried = response.ok
	elif job.has("ticket"):
		retried = await cloud.retry_upload(str(job.ticket.ticket_id))
	if scope() != owner_scope or not retried: return
	job.erase("failure")
	if _save(path,job): await process_jobs()

func _finalize(path: String, job: Dictionary, owner_scope: String) -> void:
	var entry: Dictionary = cloud.entry_from_metadata(job.receipt)
	if not await cloud.download(entry) or scope() != owner_scope: return
	if _archived(str(job.document.id),path.get_base_dir()): return
	var downloaded: Dictionary = cloud.cached_document(entry)
	var track: NativeTrack = cloud.compile_entry(entry)
	if track == null:
		last_error = "Published track is safe on the backend; its cache needs rebuilding."
		return
	var source := TrackLibrary.new(str(job.library_directory))
	if not source.commit_backend_binding(job.document,job.receipt,str(cloud.client._base_url)): return
	if not cloud.remember_publication(job.receipt):
		last_error = "Published track is safe on the backend; cache indexing will retry after storage is available."
		return
	var source_records: LocalRecords = records if library.directory == source.directory else null
	if source_records == null:
		var record_path: String = "user://local_records.json" if source.directory == "user://tracks" else source.directory.get_base_dir().path_join("records.json")
		if FileAccess.file_exists(record_path):
			source_records = LocalRecords.new(record_path)
			source_records.load_records()
	if source_records != null:
		var old: String = "creator_"+str(job.document.id)
		for key: String in ["favorites","raced_tracks"]:
			var values: Array = source_records.settings.get(key,[]).duplicate()
			if old in values:
				values.erase(old)
				if entry.id not in values: values.append(entry.id)
				source_records.settings[key] = values
		if source_records.settings.get("last_track") == old: source_records.settings.last_track = entry.id
		if cloud.migrate_record_identities(source_records) != OK: return
	if source.cleanup_backend_publication(job.document,downloaded) != OK:
		last_error = "Published · local cleanup will retry: "+source.last_error
		return
	library.revision += 1
	job.state = "published"
	job.erase("document")
	job.erase("remote")
	if _save(path,job): _retire_published(path,job)
	changed.emit()

func _retire_published(path: String, job: Dictionary) -> void:
	# A committed publication receipt replaces authoring payloads and test data.
	cloud._write(path+".bak",job)
	var proof: String = str(job.get("proof_file",""))
	if not proof.is_empty() and proof == proof.get_file() and proof.ends_with(".proof.json"):
		var target: String = path.get_base_dir().path_join(proof)
		if FileAccess.file_exists(target): DirAccess.remove_absolute(target)

func _restore_heads(owner_scope: String) -> void:
	if _restoring_scope != owner_scope:
		_restoring_scope = owner_scope
		_restore_offset = 0
	var storage: TrackLibrary = library
	var response: Dictionary = await cloud.client.request_api("/me/tracks?heads=true&limit=100&offset="+str(_restore_offset),HTTPClient.METHOD_GET,{},"",true)
	if scope() != owner_scope or storage != library or not response.ok: return
	var heads_path: String = _root().path_join("heads.json")
	var heads: Dictionary = cloud._read(heads_path)
	if heads.has("_read_error"):
		last_error = "Track sync recovery data needs repair; the original files are preserved."
		return
	for remote: Dictionary in response.data.items:
		var exact: Dictionary = await cloud.client.request_api("/me/track-versions/"+str(remote.version_id)+"/document",HTTPClient.METHOD_GET,{},"",true)
		if scope() != owner_scope or storage != library: return
		if not exact.ok or str(exact.get("body","")).sha256_text() != str(remote.content_hash): return
		var doc: Dictionary = exact.data
		if not TrackDocument.validate(doc,false).is_empty(): continue
		if _archived(str(doc.id)): continue
		heads[str(doc.id)] = str(remote.version_id)
		if remote.state == "published":
			var candidates: Array[String] = legacy_directories.duplicate()
			if storage.directory not in candidates: candidates.append(storage.directory)
			for directory: String in candidates:
				var source := TrackLibrary.new(directory)
				var original: Dictionary = source.load_document(str(doc.id))
				if original.is_empty(): original = source.load_wip(str(doc.id))
				if original.is_empty() or not TrackLibrary.authoring_equivalent(original,doc): continue
				var staged: Dictionary = stage(original,[],"compact",source,owner_scope)
				if staged.is_empty(): continue
				var job: Dictionary = staged.job
				job.version_id = remote.version_id
				job.track_id = remote.track_id
				job.receipt = remote
				job.state = "finishing"
				if _save(str(staged.path),job): await _finalize(str(staged.path),job,owner_scope)
		elif storage.load_document(str(doc.id)).is_empty() and storage.load_wip(str(doc.id)).is_empty():
			# Reinstall recovery uses the backend master; pending local edits win.
			if storage.save_wip(doc) != OK: return
			var staged: Dictionary = stage(doc)
			if not staged.is_empty():
				staged.job.version_id = remote.version_id
				staged.job.track_id = remote.track_id
				_save(str(staged.path),staged.job)
	if not cloud._write(heads_path,heads): return
	var next: Variant = response.data.get("next_offset")
	if next == null:
		_restored_scope = owner_scope
		_restore_offset = 0
	else: _restore_offset = int(next)
