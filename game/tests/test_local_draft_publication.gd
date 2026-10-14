extends SceneTree
## Real local draft/proof journals with counted network attempts and owner fences.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class CountingClient extends Client:
	var requests: Array[Dictionary] = []
	var fail_upload: bool = false
	var switch_on_bootstrap: bool = false
	var remote_state: String = "queued"
	var remote_failure: String = ""
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		requests.append({"path":path,"method":method,"body":body.duplicate(true),"key":key,"authenticated":authenticated})
		if path == "/bootstrap":
			if switch_on_bootstrap: player = {"id":"other-player"}
			return {"ok":true,"status":200,"data":{"publication_workflow_version":2}}
		if path == "/publications":
			if fail_upload:
				fail_upload = false
				return {"ok":false,"status":0,"error":"lost publication response"}
			return {"ok":true,"status":202,"data":{"publication_id":"00000000-0000-4000-8000-000000000001","state":"queued"}}
		if path.ends_with("/retry"):
			remote_state = "queued"
			return {"ok":true,"status":200,"data":{"state":"queued","retryable":false}}
		if path.begins_with("/me/publications/"):
			return {"ok":true,"status":200,"data":{"state":remote_state,"retryable":remote_state == "failed","detail":remote_failure}}
		return {"ok":false,"status":500,"error":"Unexpected network request: "+path}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func controller(client: Node, label: String) -> TrackLifecycle:
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join(label)
	root.add_child(cloud)
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = TrackLibrary.new(cloud.root_override.path_join("drafts"))
	flow.records = LocalRecords.new(cloud.root_override.path_join("records.json"))
	root.add_child(flow)
	return flow

func run() -> void:
	create_timer(50).timeout.connect(func() -> void: print("FAIL: local publication test deadline"); quit(1))
	folder = ProjectSettings.globalize_path("res://../build/local-publication-tests-"+str(Time.get_ticks_usec()))
	var client := CountingClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client.player = {"id":"fixture-owner"}
	client._access_token = "isolated-fixture"
	var flow: TrackLifecycle = controller(client,"owner")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	var document: Dictionary = fixture.document.duplicate(true)
	document.name = "Local creator loop"
	document.creator = "Fixture Owner"
	check(flow.library.save_document(document) == OK and flow.library.save_wip(document) == OK,"draft and autosave remain local")
	flow.defer_sync(document)
	await flow.process_jobs()
	check(client.requests.is_empty(),"Save and idle processing issue zero network requests")
	var exact: Dictionary = await flow.prepare_test(document)
	check(exact == document and client.requests.is_empty(),"Test uses exact local document with zero server reads or uploads")
	var track: NativeTrack = TrackCompiler.compile(document)
	track.spawn = Vector2(document.start_line.position[0],document.start_line.position[1])
	track.spawn_heading = PI*0.5-deg_to_rad(float(document.start_line.heading))
	var simulation := VehicleSimulation.new(VehicleCatalog.config("compact"))
	simulation.reset(track.spawn,track.spawn_heading)
	var witness := TrackSession.new(120,1)
	var trajectory = preload("res://backend/race_proof.gd").new()
	trajectory.capture(simulation.state,witness,true)
	var driver := RouteDriver.new()
	var frames: Array = []
	for tick: int in range(24000):
		var input: DriveFrame = driver.sample(simulation.state,track,simulation.config)
		frames.append([input.steer,input.throttle,input.brake])
		var before: Vector2 = simulation.state.position
		simulation.step(input,track)
		witness.advance(track,before,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated)
		trajectory.capture(simulation.state,witness)
		if witness.finished: break
	check(witness.finished,"actual local controls complete one ordered creator lap")
	var proof: Dictionary = trajectory.recording(witness)
	var staged: Dictionary = flow.stage(document,frames,"compact",null,"",proof)
	check(not staged.is_empty() and flow.ready_to_publish(document),"completed local trajectory unlocks explicit Publish")
	await flow.process_jobs()
	check(client.requests.is_empty(),"completed local test and idle processing issue zero network requests")
	var previous_proof: Dictionary = flow.cloud._read(str(staged.path).get_base_dir().path_join(str(staged.job.proof_file)))
	flow.queue_free()
	await process_frame
	flow = controller(client,"owner")
	check(flow.ready_to_publish(document),"completed creator lap survives controller restart without reracing")
	var local_before_publish: Dictionary = flow.status_for(document)
	var original_local_key: String = str(local_before_publish.upload_key)
	client.fail_upload = true
	check(await flow.request_publish(document),"explicit Publish durably retains intent before a lost response")
	var attempts: Array[Dictionary] = client.requests.filter(func(row: Dictionary) -> bool: return row.path == "/publications")
	check(attempts.size() == 1 and attempts[0].authenticated,"explicit Publish alone sends authenticated authoring content")
	check(attempts[0].key != original_local_key and flow.status_for(document).get("publication_upload_attempted",false),"first Publish creates and persists a fresh operation identity before transport")
	check(attempts[0].body.replay.schema == "bmt-trajectory-v1" and not attempts[0].body.replay.has("frames") and not attempts[0].body.replay.has("ghost"),"publication sends a single trajectory package without controls or required ghost")
	var saved_samples: Array = previous_proof.race_proof.samples
	var wire_samples: Array = attempts[0].body.replay.race_proof.samples
	var exact_samples: bool = wire_samples.size() == saved_samples.size()
	for index: int in range(mini(wire_samples.size(),saved_samples.size())):
		exact_samples = exact_samples and wire_samples[index] == [int(saved_samples[index][0]),saved_samples[index][1],saved_samples[index][2],int(saved_samples[index][6])]
	check(attempts[0].body.replay.input_count == frames.size() and exact_samples,"publication retains every exact saved trajectory point and tick count")
	check(not previous_proof.has("frames") and int(previous_proof.input_count) == frames.size(),"durable creator proof stores bounded trajectory and ticks without a duplicate control replay")
	var job: Dictionary = flow.status_for(document)
	job.erase("retry_at")
	job.erase("retry_delay")
	flow._retry_deadlines.erase(str(job.upload_key))
	check(flow._save(str(staged.path),job),"isolated retry fence reset")
	await flow.process_jobs()
	attempts = client.requests.filter(func(row: Dictionary) -> bool: return row.path == "/publications")
	check(attempts.size() == 2 and attempts[0].key == attempts[1].key and attempts[0].body == attempts[1].body,"lost response retries exact package and permanent operation identity")
	check(flow.status_for(document).state == "queued" and flow.status_for(document).has("publication_id"),"acknowledged intent is retained before status polling")
	check(flow.cloud._read(str(staged.path).get_base_dir().path_join(str(staged.job.proof_file))) == previous_proof,"retries preserve the original local recording")
	client.remote_state = "failed"
	client.remote_failure = "NO_PUBLISHING_SLOTS"
	var reads_before: int = client.requests.size()
	await flow.process_jobs()
	check(client.requests.size() == reads_before,"pending publication obeys server polling cadence instead of every idle tick")
	flow._retry_deadlines[str(flow.status_for(document).upload_key)] = 0 # Advance the monotonic polling deadline.
	await flow.process_jobs()
	check(flow.can_retry(document) and flow.status_for(document).state == "failed","slot/infrastructure rejection exposes an explicit publication retry: "+JSON.stringify(flow.status_for(document).get("remote",{})))
	await flow.retry(document)
	check(flow.status_for(document).state == "queued","retry reuses server publication identity")
	var old: Dictionary = document.duplicate(true)
	old.id = "legacy_autosync"
	var legacy: Dictionary = flow.stage(old)
	legacy.job.state = "syncing"
	legacy.job.upload_attempted = true
	check(flow._save(str(legacy.path),legacy.job),"historical autosync journal remains intact")
	var count_before: int = client.requests.size()
	# Stop the explicit test intent from polling, then check old autosync only.
	job = flow.status_for(document)
	job.failure = "isolated held intent"
	flow._save(str(staged.path),job)
	await flow.process_jobs()
	check(client.requests.size() == count_before,"historical autosync journals do not upload or restore private remote heads")
	var deleted: Dictionary = document.duplicate(true)
	deleted.id = "local_deleted"
	check(flow.library.save_wip(deleted) == OK and flow.archive_draft(str(deleted.id)),"deletion receipt remains on device")
	await flow.process_jobs()
	check(client.requests.size() == count_before,"local draft deletion sends no archive command")
	check(flow.stage(deleted).is_empty(),"local deletion fences stale completion callbacks")
	var guest := CountingClient.new()
	root.add_child(guest)
	guest.configure("http://127.0.0.1:1")
	var guest_flow: TrackLifecycle = controller(guest,"guest")
	check(await guest_flow.prepare_test(document) == document and guest.requests.is_empty(),"guest/offline Practice uses the local track")
	check(not guest_flow.stage(document,[],"compact",null,"",proof).is_empty(),"guest completed creator lap is durably local without copying control frames")
	check(not await guest_flow.request_publish(document) and guest.requests.is_empty(),"guest Publish requires sign-in without uploading a draft")
	var fenced: Dictionary = document.duplicate(true)
	fenced.id = "owner_fenced"
	check(not flow.stage(fenced,frames,"compact",null,"",proof).is_empty(),"fenced creator recording saved locally")
	client.switch_on_bootstrap = true
	check(not await flow.request_publish(fenced),"account change during capability read cannot upload another account's draft")
	check(client.requests.all(func(row: Dictionary) -> bool: return row.path == "/bootstrap" or row.path == "/publications" or row.path.begins_with("/me/publications/")),"network surface contains publication processing only")
	print("LOCAL_DRAFT_PUBLICATION_TEST ",JSON.stringify({"checks":checks,"failures":failures,"creator_ticks":frames.size(),"samples":proof.samples.size()}))
	quit(1 if failures else 0)
