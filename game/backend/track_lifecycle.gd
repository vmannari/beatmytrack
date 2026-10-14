class_name TrackLifecycle
extends Node
## Drafts and creator lap evidence are local. Only explicit Publish sends content.
## Durable publication retries never run inside a canonical simulation step.
signal changed
var cloud: Node
var library: TrackLibrary
var records: LocalRecords
var busy: bool = false
var last_error: String = ""
var _pending: Dictionary = {}
var legacy_directories: Array[String] = []
var _retry_deadlines: Dictionary = {}
var _batch_deadlines: Dictionary = {}
var _batch_failed_deadlines: Dictionary = {}

func _wait_root() -> String:
	return _root().path_join(".publication-waits")

func _valid_batch_wait(saved: Dictionary, owner_scope: String) -> bool:
	if saved.get("schema") != "publication-retry-1" or saved.get("scope") != owner_scope or not saved.get("nonce") is String or str(saved.nonce).is_empty() or str(saved.nonce).length() > 128: return false
	for field: String in ["delay","server_at"]:
		var value: Variant = saved.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)) or value < 0: return false
	return int(saved.delay) <= 3600

func _batch_ready() -> bool:
	var owner_scope: String = scope()
	if Time.get_ticks_msec() < int(_batch_failed_deadlines.get(owner_scope,0)): return false
	_batch_failed_deadlines.erase(owner_scope)
	var paths: Array[String] = []
	var legacy: String = _root().path_join("publication-retry.json")
	if FileAccess.file_exists(legacy) or FileAccess.file_exists(legacy+".tmp"): paths.append(legacy)
	var seen: Dictionary = {}
	for filename: String in DirAccess.get_files_at(_wait_root()) if DirAccess.dir_exists_absolute(_wait_root()) else PackedStringArray():
		var base: String = filename.trim_suffix(".tmp")
		if not base.ends_with(".wait.json") or seen.has(base): continue
		seen[base] = true
		paths.append(_wait_root().path_join(base))
	var ready: bool = true
	for path: String in paths:
		if not _wait_ready(path,owner_scope,path == legacy): ready = false
	return ready

func _wait_ready(path: String, owner_scope: String, legacy: bool) -> bool:
	var saved: Dictionary = cloud._read(path)
	# Legacy writes reused a global temporary name. New writes are immutable and
	# have one unique filename per pause, so peers cannot overwrite each other.
	if FileAccess.file_exists(path+".tmp") and (legacy or not _valid_batch_wait(saved,owner_scope)):
		saved = cloud._read(path+".tmp")
	if not _valid_batch_wait(saved,owner_scope):
		# Another reader can retire this unique nonce between enumeration and
		# opening it. Absence is not a corrupt journal or a reason to pause.
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".tmp"): return true
		last_error = "Publication recovery data needs repair; original files are preserved."
		return false
	var marker: String = str(saved.nonce)
	var hash: String = marker.sha256_text()
	if not legacy and path.get_file() != hash+".wait.json": return false
	var receipt_path: String = _wait_root().path_join(hash+".done.json")
	var receipt: Dictionary = cloud._read(receipt_path)
	var key: String = owner_scope+"/"+marker
	if receipt.get("schema") == "publication-wait-done-1" and receipt.get("scope") == owner_scope and receipt.get("nonce") == marker:
		if not legacy: _retire_wait(path,receipt_path)
		_batch_deadlines.erase(key)
		return true
	if not _batch_deadlines.has(key):
		var delay: int = clampi(int(saved.delay),0,3600)
		if cloud.client.server_now() > 0 and int(saved.server_at) > 0:
			delay = clampi(int(saved.server_at)-cloud.client.server_now(),0,delay)
		_batch_deadlines[key] = Time.get_ticks_msec()+delay*1000
	var elapsed: bool = Time.get_ticks_msec() >= int(_batch_deadlines[key])
	if cloud.client.server_now() > 0 and int(saved.server_at) > 0 and cloud.client.server_now() >= int(saved.server_at): elapsed = true
	if not elapsed: return false
	# The receipt belongs to this immutable nonce, never a newer peer pause.
	# Keeping legacy receipts prevents a clockless restart reviving the old wait.
	if not cloud._write(receipt_path,{"schema":"publication-wait-done-1","scope":owner_scope,"nonce":marker}): return false
	if not legacy: _retire_wait(path,receipt_path)
	_batch_deadlines.erase(key)
	return true

func _retire_wait(path: String, receipt_path: String) -> void:
	# Unique filenames are never reused by a newer pause. This cannot erase a
	# peer's subsequent 429; a durable completion remains until deletion succeeds.
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".tmp"):
		for suffix: String in ["", ".tmp"]:
			if FileAccess.file_exists(receipt_path+suffix): DirAccess.remove_absolute(receipt_path+suffix)

func _pause_batch(response: Dictionary) -> void:
	var status: int = int(response.get("status",0))
	if status not in [429,502,503,504]: return
	var delay: int = clampi(maxi(60 if status == 429 else 15,int(response.get("retry_after",0))),1,3600)
	var marker: String = TrackLibrary.unique_id()
	_batch_deadlines[scope()+"/"+marker] = Time.get_ticks_msec()+delay*1000
	if not cloud._write(_wait_root().path_join(marker.sha256_text()+".wait.json"),{"schema":"publication-retry-1","scope":scope(),"nonce":marker,"delay":delay,"server_at":cloud.client.server_now()+delay if cloud.client.server_now() > 0 else 0}):
		var path: String = _wait_root().path_join(marker.sha256_text()+".wait.json")
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".tmp"): _batch_deadlines.erase(scope()+"/"+marker)
		_batch_failed_deadlines[scope()] = maxi(int(_batch_failed_deadlines.get(scope(),0)),Time.get_ticks_msec()+delay*1000)
		last_error = "Could not save publication retry state. Free storage and retry."

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
	for job: Dictionary in jobs():
		if job.get("authoring_id") == id and job.has("publication_id") and job.get("state") not in ["published","failed"]:
			last_error = "This track is already being published. Wait for publication to finish before removing its recovery files."
			return false
	var path: String = _archive_path(id)
	if not FileAccess.file_exists(path) and not cloud._write(path,{"id":id,"scope":scope(),"local_only":true}):
		last_error = "Deletion could not be saved. Free storage and retry; the draft is preserved."
		return false
	_pending.erase(id)
	return true

func _read(path: String) -> Dictionary:
	return _read_job(path,cloud._read)

static func _read_job(path: String, reader: Callable) -> Dictionary:
	var existed: bool = false
	for candidate: String in [path,path+".bak",path+".tmp"]:
		existed = existed or FileAccess.file_exists(candidate)
		var value: Dictionary = reader.call(candidate)
		if value.get("schema") != "track-lifecycle-1": continue
		var complete: bool = true
		for field: String in ["scope","library_directory","fingerprint","upload_key","publish_key","ticket_key","state"]:
			if not value.get(field) is String: complete = false
		if not (value.get("created_at") is int or value.get("created_at") is float): complete = false
		if value.has("publication_retry_key"):
			complete = complete and value.publication_retry_key is String
			if complete: complete = not value.publication_retry_key.is_empty() and value.publication_retry_key.length() <= 128
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
	if not new_proof and previous.get("publish_requested",false): value.publish_requested = true
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
	# Kept as a local compatibility hook for older editor callers. A Save never
	# schedules uploads, head reads, server restoration or archive commands.
	if not document.is_empty(): _pending.erase(str(document.get("id","")))

func stage(document: Dictionary, frames: Array = [], vehicle: String = "compact", source: TrackLibrary = null, owner_scope: String = "", race_proof: Dictionary = {}) -> Dictionary:
	if not TrackDocument.validate(document,false).is_empty():
		last_error = "This draft could not be saved on this device."
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
			last_error = "Track recovery data needs repair; the original files are preserved."
			return {}
		var sequence: int = int(counter.get("value",0))+1
		var latest: Dictionary = counter.get("latest",{})
		var predecessor: String = str(latest.get(str(document.id),""))
		latest[str(document.id)] = TrackLibrary.draft_fingerprint(document)
		if not cloud._write(counter_path,{"value":sequence,"latest":latest}):
			last_error = "Could not save local track recovery state. Free storage and retry."
			return {}
		job = {"schema":"track-lifecycle-1","scope":operation_scope,"library_directory":storage.directory,
			"document":document.duplicate(true),"fingerprint":TrackLibrary.draft_fingerprint(document),
			"sequence":sequence,
			"upload_key":cloud.client.new_operation_key(),"publish_key":cloud.client.new_operation_key(),
			"ticket_key":cloud.client.new_operation_key(),"state":"saved","created_at":int(Time.get_unix_time_from_system())}
		job.authoring_id = str(document.id)
		job.predecessor = predecessor
	if not frames.is_empty() and race_proof.is_empty():
		last_error = "The completed creator lap has no trajectory evidence. Complete a fresh local test lap."
		return {}
	var new_proof: bool = not race_proof.is_empty() and job.get("state") not in ["ready","publishing","queued","verifying","finishing","published"]
	if new_proof:
		var samples: Variant = race_proof.get("samples")
		if not samples is Array or samples.size() < 2 or not samples[-1] is Array or samples[-1].is_empty():
			last_error = "The completed creator lap has no complete trajectory. Complete a fresh local test lap."
			return {}
		var finished_tick: Variant = samples[-1][0]
		if not (finished_tick is int or finished_tick is float) or not is_finite(float(finished_tick)) or float(finished_tick) != float(int(finished_tick)) or int(finished_tick) <= 0 or int(finished_tick) > 216000 or (not frames.is_empty() and frames.size() != int(finished_tick)):
			last_error = "The completed creator lap has an inconsistent finish time. Complete a fresh local test lap."
			return {}
		var contract: Dictionary = _contract(document,vehicle)
		var keep_ticket: bool = job.has("ticket") and job.get("contract") == contract and job.get("vehicle") == vehicle
		# Acceptance needs only elapsed ticks and the bounded trajectory. Control
		# frames remain a live local diagnostic; no duplicate full replay journal.
		var recording: Dictionary = {"input_count":int(finished_tick)}
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
		job.state = "local_ready"
		job.upload_key = cloud.client.new_operation_key()
		for field: String in ["publication_id","publication_upload_attempted","publish_requested","publish_workflow","remote","retry_at"]: job.erase(field)
	if not _save(path,job,new_proof): return {}
	if new_proof and not cloud._write(path+".bak",job):
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
	var job: Dictionary = status_for(document)
	return job.has("proof_file") and job.get("state","") in ["local_ready","ready","saved","draft","invalid","failed"] and not job.get("publish_requested",false)

static func ready_to_publish_fingerprint(fingerprint: String, workflow_directory: String) -> bool:
	if fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(false): return false
	var job: Dictionary = _read_job(workflow_directory.path_join(fingerprint+".job.json"),preload("res://backend/cloud_tracks.gd")._read_file)
	return job.has("proof_file") and job.get("state","") in ["local_ready","ready","saved","draft","invalid","failed"] and not job.get("publish_requested",false)

func can_retry(document: Dictionary) -> bool:
	var job: Dictionary = status_for(document)
	return job.has("publication_id") and bool(job.get("remote",{}).get("retryable",false))

func caption(document: Dictionary) -> String:
	var job: Dictionary = status_for(document)
	if job.has("_read_error"): return "Track recovery data needs repair; original files are preserved."
	if job.has("failure"): return str(job.failure)
	if job.is_empty(): return "Saved on this device"
	return {"saved":"Saved on this device", "local_ready":"Test lap saved · ready to publish",
		"ready":"Test lap saved · ready to publish", "draft":"Saved on this device",
		"publishing":"Publishing…", "queued":"Publication queued…", "verifying":"Checking publication…",
		"finishing":"Published · finishing download…", "published":"Published"}.get(str(job.get("state","")),"Saved on this device")

func process_jobs() -> void:
	if busy or cloud == null or library == null or not cloud.client.signed_in(): return
	if not _batch_ready(): return
	busy = true
	last_error = ""
	var owner_scope: String = scope()
	for job: Dictionary in jobs():
		if scope() != owner_scope: break
		if not _batch_ready(): break
		if job.get("state") == "published":
			_retire_published(str(job._path),job)
			continue
		if job.get("state") == "finishing" and job.has("receipt"):
			if not _job_ready(job): continue
			_delay_job(job,15)
			_save(str(job._path),job)
			await _finalize(str(job._path),job,owner_scope)
			continue
		# Historical autosync journals are preserved, never resumed as uploads.
		if not job.get("publish_requested",false) or int(job.get("publish_workflow",0)) != 2: continue
		if job.has("failure") or not _job_ready(job): continue
		if job.has("document") and not _archived(str(job.document.id)):
			await _advance(str(job._path),job,owner_scope)
	busy = false
	changed.emit()

func _advance(path: String, job: Dictionary, owner_scope: String) -> void:
	job.erase("_path")
	if job.scope != scope() or owner_scope != scope(): return
	if not job.get("publish_requested",false) or int(job.get("publish_workflow",0)) != 2: return
	if not job.get("document") is Dictionary or _archived(str(job.document.id),path.get_base_dir()): return
	var state_data: Dictionary = {}
	if not job.has("publication_id"):
		var recording: Dictionary = cloud._read(path.get_base_dir().path_join(str(job.get("proof_file",""))))
		var input_count: Variant = recording.get("input_count",recording.get("frames",[]).size())
		if not (input_count is int or input_count is float) or not is_finite(float(input_count)) or float(input_count) != float(int(input_count)) or int(input_count) <= 0:
			job.failure = "The saved creator lap is incomplete. Complete a fresh local test lap."
			_save(path,job)
			return
		var replay: Dictionary = cloud.client._pack_trajectory(int(input_count),recording.get("race_proof",{}),[])
		if replay.is_empty():
			job.failure = "The saved creator trajectory is incomplete. Complete a fresh local test lap."
			_save(path,job)
			return
		replay.erase("rewinds")
		job.state = "publishing"
		job.publication_upload_attempted = true
		if not _save(path,job): return
		var response: Dictionary = await cloud.client.request_api("/publications",HTTPClient.METHOD_POST,
			{"name":job.document.name,"document":job.document,"vehicle_id":job.vehicle,"contract":job.contract,"replay":replay},str(job.upload_key),true)
		if scope() != owner_scope or _archived(str(job.document.id),path.get_base_dir()): return
		if not response.ok:
			last_error = str(response.error)
			_pause_batch(response)
			if int(response.status) in [400,403,409,410,413,422] or str(response.get("error","")) == "REQUEST_TOO_LARGE": job.failure = "Publication needs attention: "+last_error
			else: _delay_job(job,maxi(15,int(response.get("retry_after",0))),true)
			_save(path,job)
			return
		if not response.data.get("publication_id") is String:
			last_error = "Publication returned an incomplete receipt. Its saved request will retry."
			_delay_job(job,15,true)
			_save(path,job)
			return
		job.publication_id = response.data.publication_id
		job.remote = response.data
		if not _save(path,job): return
		state_data = response.data
	else:
		var status: Dictionary = await cloud.client.request_api("/me/publications/"+str(job.publication_id),HTTPClient.METHOD_GET,{},"",true)
		if scope() != owner_scope or _archived(str(job.document.id),path.get_base_dir()): return
		if not status.ok:
			_pause_batch(status)
			_delay_job(job,maxi(15,int(status.get("retry_after",0))),true)
			_save(path,job)
			return
		state_data = status.data
	if state_data.get("state") not in ["queued","verifying","published","failed"]:
		_delay_job(job,15,true)
		_save(path,job)
		return
	var previous_state: String = str(job.state)
	job.remote = state_data
	job.state = str(state_data.get("state","queued"))
	if job.state == "published":
		if not state_data.get("receipt") is Dictionary:
			job.state = previous_state
			_delay_job(job,15,true)
			_save(path,job)
			return
		job.receipt = state_data.receipt
		job.track_id = str(job.receipt.get("track_id",""))
		job.version_id = str(job.receipt.get("version_id",""))
		job.state = "finishing"
		if _save(path,job): await _finalize(path,job,owner_scope)
		return
	if job.state == "failed":
		job.failure = "No publishing slots left. Add slots, then Retry. Your track remains saved." if state_data.get("failure_code") == "NO_PUBLISHING_SLOTS" else "Complete a fresh test lap before publishing this revision." if state_data.get("failure_code") == "invalid_creator_proof" else str(state_data.get("detail","Publication verification failed"))
		last_error = job.failure
	elif job.state in ["queued","verifying"]:
		_delay_job(job,maxi(1,ceili(float(state_data.get("poll_after_ms",2500))/1000.0)))
	_save(path,job)

func _job_ready(job: Dictionary) -> bool:
	var key: String = str(job.upload_key)
	if not _retry_deadlines.has(key):
		var seconds: int = clampi(int(job.get("retry_delay",0)),0,3600)
		# Legacy publication waits used the device wall clock. Bound them after
		# restart; a wrong phone clock must never strand a saved publication.
		if not job.has("retry_delay") and job.has("retry_at"):
			seconds = clampi(int(job.retry_at)-int(Time.get_unix_time_from_system()),0,600)
		if cloud.client.server_now() > 0 and int(job.get("retry_server_at",0)) > 0:
			seconds = clampi(int(job.retry_server_at)-cloud.client.server_now(),0,seconds)
		_retry_deadlines[key] = Time.get_ticks_msec()+seconds*1000
	return Time.get_ticks_msec() >= int(_retry_deadlines[key])

func _delay_job(job: Dictionary, seconds: int, failed: bool = false) -> void:
	var streak: int = mini(6,int(job.get("retry_streak",0))+1) if failed else 0
	job.retry_streak = streak
	job.retry_delay = maxi(seconds,mini(600,15*int(pow(2,streak-1)))) if failed else seconds
	job.retry_server_at = cloud.client.server_now()+int(job.retry_delay) if cloud.client.server_now() > 0 else 0
	job.erase("retry_at")
	_retry_deadlines[str(job.upload_key)] = Time.get_ticks_msec()+int(job.retry_delay)*1000

func prepare_test(document: Dictionary) -> Dictionary:
	# Editing, guest/offline testing and saved lap capture have no network path.
	if not TrackDocument.validate(document).is_empty() or TrackCompiler.compile(document) == null:
		last_error = "Repair this track before completing a publication test lap."
		return {}
	last_error = ""
	return document.duplicate(true)

func request_publish(document: Dictionary) -> bool:
	if not cloud.client.signed_in():
		last_error = "Sign in to publish. Your draft and test lap remain on this device."
		return false
	if not _batch_ready(): return false
	var path: String = _path(document)
	var job: Dictionary = _read(path)
	if job.get("state") in ["finishing","published"]: return true
	if not job.has("proof_file") or not job.has("contract"):
		last_error = "Complete a local creator test lap for this exact revision before publishing."
		return false
	var owner_scope: String = scope()
	var compatible: Dictionary = await cloud.client.request_api("/bootstrap")
	if owner_scope != scope(): return false
	if not compatible.ok or int(compatible.data.get("publication_workflow_version",0)) != 2:
		last_error = "The backend needs the local-draft publication update. Your draft and test lap remain saved on this device."
		return false
	job.publish_requested = true
	job.publish_workflow = 2
	# A local draft has no backend deadline. Timestamp the operation at its
	# first authorized handoff; uncertain/retried attempts retain their key.
	if not job.get("publication_upload_attempted",false) and not job.has("publication_id"):
		job.upload_key = cloud.client.new_operation_key()
	job.erase("failure")
	job.erase("retry_at")
	job.erase("retry_delay")
	_retry_deadlines.erase(str(job.upload_key))
	if not _save(path,job): return false
	await process_jobs()
	return true

func retry(document: Dictionary) -> void:
	if not _batch_ready(): return
	var path: String = _path(document)
	var job: Dictionary = _read(path)
	if not job.has("publication_id") or not can_retry(document): return
	var owner_scope: String = scope()
	# Save the retry operation before delivery. A lost reply or app restart
	# reuses this key; the immutable publication upload keeps its own identity.
	if not job.has("publication_retry_key"):
		job.publication_retry_key = cloud.client.new_operation_key()
		if not _save(path,job): return
	var response: Dictionary = await cloud.client.request_api("/me/publications/"+str(job.publication_id)+"/retry",
		HTTPClient.METHOD_POST,{},str(job.publication_retry_key),true)
	if scope() != owner_scope: return
	if not response.ok:
		_pause_batch(response)
		return
	job.remote = response.data
	job.erase("publication_retry_key")
	job.erase("failure")
	job.erase("retry_at")
	job.erase("retry_delay")
	_retry_deadlines.erase(str(job.upload_key))
	job.state = str(response.data.get("state","queued"))
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
