extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class LostResponseClient extends Client:
	var lose_publication: bool = false
	var switch_after_publication: bool = false
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		var response: Dictionary = await super.request_api(path,method,body,key,authenticated)
		if lose_publication and path.ends_with("/publish") and response.ok:
			lose_publication = false
			return {"ok":false,"status":0,"error":"simulated lost response"}
		if switch_after_publication and path.ends_with("/publish") and response.ok:
			switch_after_publication = false
			player = {"id":"another-account"}
		return response

class FailingCacheCloud extends Cloud:
	var block_index: bool = false
	func _write(path: String, value: Dictionary) -> bool:
		if block_index and path.ends_with("/index.json"): return false
		return super._write(path,value)

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

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
	var driver := RouteDriver.new()
	var frames: Array = []
	for tick: int in range(24000):
		var input: DriveFrame = driver.sample(simulation.state,track,simulation.config)
		frames.append([input.steer,input.throttle,input.brake])
		var before: Vector2 = simulation.state.position
		simulation.step(input,track)
		session.advance(track,before,simulation.state.position,simulation.state.route_index,simulation.state.track_elevated)
		if session.finished: break
	check(session.finished,"canonical input proof completes one ordered lap")
	return frames

func until_ready(flow: TrackLifecycle, document: Dictionary) -> void:
	for attempt: int in range(100):
		await flow.process_jobs()
		if flow.ready_to_publish(document): return
		if flow.status_for(document).has("failure"):
			print(flow.caption(document))
			break
		await create_timer(0.2).timeout
	check(false,"saved creator proof becomes server verified")

func capture(node: Control, name: String) -> void:
	if OS.get_environment("BMT_CAPTURE_CLOUD").is_empty() or DisplayServer.get_name() == "headless": return
	root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("BMT_CAPTURE_CLOUD")
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name)
	node.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(110).timeout.connect(func() -> void: print("FAIL: lifecycle deadline exceeded"); quit(1))
	var client := LostResponseClient.new()
	root.add_child(client)
	client.configure(OS.get_environment("BMT_API_URL"))
	var login: Dictionary = await client.development_login("lifecycle-creator","Lifecycle Creator",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"creator signs in")
	var cloud := FailingCacheCloud.new()
	cloud.client = client
	cloud.root_override = "user://lifecycle_tests_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var library := TrackLibrary.new(cloud.root_override.path_join("drafts"))
	library.owner_name = "Lifecycle Creator"
	var records := LocalRecords.new(cloud.root_override.path_join("records.json"))
	var flow: TrackLifecycle = controller(cloud,library,records)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var doc: Dictionary = fixture.document.duplicate(true)
	doc.creator = library.owner_name
	check(library.save_document(doc) == OK and library.save_wip(doc) == OK,"original and autosave are durable")
	var exact: Dictionary = await flow.prepare_test(doc)
	check(not exact.is_empty(),"test downloads exact validated backend revision")
	if exact.is_empty(): print(flow.last_error); quit(1); return
	doc = exact
	var frames: Array = proof(doc)
	var staged: Dictionary = flow.stage(doc,frames)
	check(not staged.is_empty() and FileAccess.file_exists(str(staged.path).get_base_dir().path_join(staged.job.proof_file)),"completed proof saved before ticket or network upload")
	check(not flow.ready_to_publish(doc),"local completed test does not unlock Publish")
	var guest_library := TrackLibrary.new(cloud.root_override.path_join("guest-drafts"))
	var guest_doc: Dictionary = doc.duplicate(true)
	guest_doc.id = "guest_pending"
	guest_doc.creator = "Guest"
	check(guest_library.save_wip(guest_doc) == OK,"guest authoring remains recoverable before adoption")
	var adoption := preload("res://ui/draft_browser.gd").new()
	adoption.library = library
	adoption.guest_library = guest_library
	adoption.lifecycle = flow
	root.add_child(adoption)
	check(adoption.entries.size() == 2 and adoption.entries[-1].get("guest",false),"signed-in creator can explicitly adopt saved Guest work")
	adoption.queue_free()
	await process_frame
	check(cloud._write(str(staged.path),{"interrupted":true}),"inject interrupted journal primary")
	check(flow.status_for(doc).get("proof_file") == staged.job.proof_file,"recovery journal retains exact completed proof")
	var recovered_library := TrackLibrary.new(cloud.root_override.path_join("restored-drafts"))
	var recovering: TrackLifecycle = controller(cloud,recovered_library,records)
	await recovering.process_jobs()
	check(not recovered_library.load_wip(str(doc.id)).is_empty(),"private backend master restores after reinstall")
	recovering.queue_free()
	flow.queue_free()
	await process_frame
	flow = controller(cloud,library,records)
	await until_ready(flow,doc)
	var ready: Dictionary = flow.status_for(doc)
	var public_before: Dictionary = await client.request_api("/tracks")
	check(public_before.data.items.is_empty(),"verified private revision is not auto-published")
	var draft_menu := preload("res://ui/draft_browser.gd").new()
	draft_menu.library = library
	draft_menu.lifecycle = flow
	await capture(draft_menu,"creator-verified")
	var changed: Dictionary = doc.duplicate(true)
	changed.name = "Newer pending edit"
	check(library.save_wip(changed) == OK,"newer local edit saved while old revision is ready")
	records.settings = {"favorites":["creator_"+str(doc.id),"cloud_"+str(ready.version_id)],"last_track":"creator_"+str(doc.id)}
	check(records.save_records() == OK,"pre-migration references saved")
	client.lose_publication = true
	check(await flow.request_publish(doc),"publication intent persisted before lost response")
	check(flow.status_for(doc).get("state") == "publishing","lost response leaves recoverable publication phase")
	flow.queue_free()
	await process_frame
	flow = controller(cloud,library,records)
	cloud.block_index = true
	await flow.process_jobs()
	check(flow.status_for(doc).get("state") == "finishing" and not library.load_document(str(doc.id)).is_empty(),"cache-index write failure keeps local source and recoverable receipt")
	cloud.block_index = false
	await flow.process_jobs()
	check(flow.status_for(doc).get("state") == "published","restart discovers committed publication and finishes cleanup")
	check(library.load_document(str(doc.id)).is_empty(),"published local original removed")
	check(library.load_wip(str(doc.id)).get("name") == changed.name,"newer unpublished edit survives cleanup")
	check(not flow.status_for(doc).has("document"),"published journal retains receipt without local master")
	check(not FileAccess.file_exists(str(staged.path).get_base_dir().path_join(staged.job.proof_file)),"acknowledged proof retired after successful handoff")
	cloud.migrate_record_identities(records)
	var identity: String = "cloud_"+str(ready.track_id)
	check(records.settings.favorites == [identity] and records.settings.last_track == identity,"favorites and selection migrate to stable backend track ID")
	await cloud.refresh(true)
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	check(catalog.entries.size() == 1 and catalog.entries[0].id == identity,"one stable catalog identity after publication")
	var entry: Dictionary = catalog.entries[0]
	check(not cloud.cached_document(entry).is_empty(),"publication retrieves verified disposable backend cache")
	var offline := Cloud.new()
	offline.client = client
	offline.root_override = cloud.root_override
	root.add_child(offline)
	offline.load_cached()
	check(offline.entries.size() == 1 and offline.compile_entry(entry) != null,"cached publication races after controller restart")
	var browser := TrackBrowser.new()
	browser.library = library
	browser.records = records
	browser.catalog = catalog
	browser.cloud = cloud
	browser.state = {}
	browser.selected_track = cloud.compile_entry(entry)
	browser.builtin_ids = BuiltinTracks.ids()
	await capture(browser,"race-backend-catalog")
	var private_again: Dictionary = await client.request_api("/tracks",HTTPClient.METHOD_POST,{"name":changed.name,"document":changed,"authoring_id":doc.id,"defer_validation":true},client.new_idempotency_key(),true)
	check(private_again.ok and private_again.data.track_id == ready.track_id and private_again.data.version_id != ready.version_id,"edits keep track UID and create immutable revisions")
	catalog.remember_track(entry,cloud.compile_entry(entry))
	var revised: Dictionary = await flow.prepare_test(changed)
	check(not revised.is_empty(),"edited revision retrieves its own canonical contract")
	if revised.is_empty(): print(flow.last_error); quit(1); return
	var revised_stage: Dictionary = flow.stage(revised,proof(revised))
	check(not revised_stage.is_empty(),"new revision retains its own completed proof")
	await until_ready(flow,revised)
	var original_player: Dictionary = client.player.duplicate(true)
	client.switch_after_publication = true
	check(await flow.request_publish(revised),"verified new revision publishes under the original logical track")
	check(flow._read(str(revised_stage.path)).get("state") == "publishing" and not library.load_wip(str(revised.id)).is_empty(),"account scope change prevents applying publication cleanup to current storage")
	client.player = original_player
	await flow.process_jobs()
	check(flow.status_for(revised).get("state") == "published","original account recovers its acknowledged publication")
	cloud.add_to_catalog(catalog)
	check(catalog.entries.size() == 1 and catalog.entries[0].id == identity and catalog.entries[0].version_id == private_again.data.version_id,"new publication replaces one card while retaining its UID")
	check(catalog.cached_track(catalog.entries[0]) == null,"compiled cache invalidates the previous immutable version")
	var original_share: Dictionary = await client.request_api("/track-versions/"+str(ready.version_id)+"/document")
	check(original_share.ok and original_share.data.name == doc.name,"old immutable share link retains its original document")
	var hidden: Dictionary = await client.request_api("/tracks/"+str(ready.track_id)+"/hide",HTTPClient.METHOD_POST,{},client.new_idempotency_key(),true)
	check(hidden.ok,"owner hides test publication")
	await cloud.refresh(true)
	check(cloud.entries.is_empty(),"complete server snapshot removes hidden catalog entries")
	print("TRACK_LIFECYCLE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
