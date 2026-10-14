extends SceneTree
## Actual HTTP publication pipeline; disposable server and local game folders.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var completed_proof: Dictionary = {}

class LostResponseClient extends Client:
	var lose_publication: bool = false
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		var response: Dictionary = await super.request_api(path,method,body,key,authenticated)
		if lose_publication and path == "/publications" and response.ok:
			lose_publication = false
			return {"ok":false,"status":0,"error":"simulated lost publication response"}
		return response

class FailingCacheCloud extends Cloud:
	var block_index: bool = false
	func _write(path: String, value: Dictionary) -> bool:
		if block_index and path.ends_with("/index.json"): return false
		return super._write(path,value)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func controller(cloud: Node, library: TrackLibrary, records: LocalRecords) -> TrackLifecycle:
	var flow := TrackLifecycle.new()
	flow.cloud = cloud
	flow.library = library
	flow.records = records
	root.add_child(flow)
	return flow

func proof(document: Dictionary) -> Array:
	var track: NativeTrack = TrackCompiler.compile(document)
	track.spawn = Vector2(document.start_line.position[0],document.start_line.position[1])
	track.spawn_heading = PI*0.5-deg_to_rad(float(document.start_line.heading))
	var simulation := VehicleSimulation.new(VehicleCatalog.config("compact"))
	simulation.reset(track.spawn,track.spawn_heading)
	var session := TrackSession.new(120,1)
	var trajectory = preload("res://backend/race_proof.gd").new()
	trajectory.capture(simulation.state,session,true)
	var driver := RouteDriver.new()
	var frames: Array = []
	for tick: int in range(24000):
		var input: DriveFrame = driver.sample(simulation.state,track,simulation.config)
		frames.append([input.steer,input.throttle,input.brake])
		var before: Vector2 = simulation.state.position
		simulation.step(input,track)
		session.advance(track,before,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated)
		trajectory.capture(simulation.state,session)
		if session.finished: break
	check(session.finished,"local creator proof completes one ordered lap")
	completed_proof = trajectory.recording(session)
	return frames

func until_terminal(flow: TrackLifecycle, document: Dictionary, expected: String) -> void:
	for attempt: int in range(120):
		await flow.process_jobs()
		var state: Dictionary = flow.status_for(document)
		if state.get("state") == expected: return
		if state.get("state") == "failed":
			print(flow.caption(document))
			break
		await create_timer(0.1).timeout
	check(false,"publication reaches "+expected)

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: print("FAIL: publication HTTP deadline"); quit(1))
	var client := LostResponseClient.new()
	root.add_child(client)
	client.configure(OS.get_environment("BMT_API_URL"))
	var bootstrap: Dictionary = await client.request_api("/bootstrap")
	check(bootstrap.ok and int(bootstrap.data.get("publication_workflow_version",0)) == 2 and bootstrap.data.get("local_drafts_only",false),"server advertises explicit local-draft publication")
	var login: Dictionary = await client.development_login("published-only-creator","Local Creator",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"creator signs in")
	var cloud := FailingCacheCloud.new()
	cloud.client = client
	cloud.root_override = ProjectSettings.globalize_path("res://../build/published-only-http-"+str(Time.get_ticks_usec()))
	root.add_child(cloud)
	var library := TrackLibrary.new(cloud.root_override.path_join("drafts"))
	library.owner_name = "Local Creator"
	var records := LocalRecords.new(cloud.root_override.path_join("records.json"))
	var flow: TrackLifecycle = controller(cloud,library,records)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var document: Dictionary = fixture.document.duplicate(true)
	document.creator = library.owner_name
	check(library.save_document(document) == OK and library.save_wip(document) == OK,"original and autosave are durable on device")
	var exact: Dictionary = await flow.prepare_test(document)
	check(exact == document,"creator tests exact local document")
	var frames: Array = proof(document)
	var staged: Dictionary = flow.stage(document,frames,"compact",null,"",completed_proof)
	check(not staged.is_empty() and flow.ready_to_publish(document),"actual completed local lap unlocks Publish")
	await flow.process_jobs()
	var owned: Dictionary = await client.request_api("/me/tracks?heads=true",HTTPClient.METHOD_GET,{},"",true)
	var public_before: Dictionary = await client.request_api("/tracks")
	check(owned.ok and owned.data.items.is_empty() and public_before.ok and public_before.data.items.is_empty(),"saving and testing create no server track inventory")
	var legacy: Dictionary = await client.request_api("/tracks",HTTPClient.METHOD_POST,{"name":document.name,"document":document},client.new_operation_key(),true)
	check(not legacy.ok and int(legacy.status) == 410,"old clients cannot autosync drafts")
	var changed: Dictionary = document.duplicate(true)
	changed.name = "Newer local edit"
	check(library.save_wip(changed) == OK,"newer unpublished local edit saved")
	records.settings = {"favorites":["creator_"+str(document.id)],"last_track":"creator_"+str(document.id)}
	check(records.save_records() == OK,"local favourites saved")
	client.lose_publication = true
	check(await flow.request_publish(document),"publication intent survives lost accepted response")
	check(flow.status_for(document).state == "publishing","lost response keeps durable request")
	flow.queue_free()
	await process_frame
	flow = controller(cloud,library,records)
	var job: Dictionary = flow.status_for(document)
	job.erase("retry_at")
	flow._save(str(staged.path),job)
	cloud.block_index = true
	for attempt: int in range(120):
		await flow.process_jobs()
		if flow.status_for(document).get("state") == "finishing": break
		if flow.status_for(document).has("failure"): print(flow.caption(document)); break
		await create_timer(0.1).timeout
	check(flow.status_for(document).get("state") == "finishing" and not library.load_document(str(document.id)).is_empty(),"server verified publication keeps local source during cache failure")
	cloud.block_index = false
	await until_terminal(flow,document,"published")
	var receipt: Dictionary = flow.status_for(document).get("receipt",{})
	check(receipt.get("state") == "published" and int(receipt.get("manifest",{}).get("laps",0)) == 5,"published race contract has five ordinary laps")
	check(library.load_document(str(document.id)).is_empty() and library.load_wip(str(document.id)).name == changed.name,"handoff retires exact original while preserving newer draft")
	check(not FileAccess.file_exists(str(staged.path).get_base_dir().path_join(str(staged.job.proof_file))),"acknowledged creator evidence is retired after publication download")
	check(records.settings.favorites == ["cloud_"+str(receipt.track_id)] and records.settings.last_track == "cloud_"+str(receipt.track_id),"selection and favourite bind to stable published track")
	var slots: Dictionary = await client.request_api("/me/entitlements",HTTPClient.METHOD_GET,{},"",true)
	check(slots.ok and int(slots.data.publishing_slots) == 0,"lost-response retries consume the initial slot exactly once")
	await cloud.refresh(true)
	check(cloud.entries.size() == 1 and cloud.compile_entry(cloud.entry_from_metadata(cloud.entries[0])) != null,"published backend cache remains raceable")
	var restored_library := TrackLibrary.new(cloud.root_override.path_join("restored-empty"))
	var restored: TrackLifecycle = controller(cloud,restored_library,records)
	await restored.process_jobs()
	check(restored_library.editable_entries().is_empty(),"controller reinstall does not retrieve private drafts from server")
	var revised_frames: Array = proof(changed)
	check(not flow.stage(changed,revised_frames,"compact",null,"",completed_proof).is_empty(),"new local revision has its own exact saved creator lap")
	check(await flow.request_publish(changed),"second explicit Publish sends only the revised track")
	await until_terminal(flow,changed,"failed")
	check(flow.status_for(changed).get("remote",{}).get("failure_code") == "NO_PUBLISHING_SLOTS" and not library.load_wip(str(changed.id)).is_empty(),"insufficient slots preserve local draft and verified request")
	var adapter := preload("res://platform/purchase_simulator.gd").new()
	adapter.client = client
	root.add_child(adapter)
	var purchased: Dictionary = await adapter.purchase("creator_slot_1","approved")
	check(purchased.ok,"configured development purchase provides a slot")
	await flow.retry(changed)
	await until_terminal(flow,changed,"published")
	var second: Dictionary = flow.status_for(changed).get("receipt",{})
	check(second.get("track_id") == receipt.track_id and int(second.get("version",0)) == 2,"published revision keeps track identity after atomic slot retry")
	owned = await client.request_api("/me/tracks?heads=true",HTTPClient.METHOD_GET,{},"",true)
	check(owned.ok and owned.data.items.size() == 1 and owned.data.items[0].state == "published", "owned head feed includes only the newest published version")
	print("PUBLISHED_ONLY_HTTP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
