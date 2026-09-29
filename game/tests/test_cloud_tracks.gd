extends SceneTree
const Cloud = preload("res://backend/cloud_tracks.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0

class ReplayInput extends DriverInput:
	var frames: Array = []
	var cursor: int = 0
	func sample() -> DriveFrame:
		var frame := DriveFrame.new()
		if cursor < frames.size():
			frame.steer = int(frames[cursor][0])
			frame.throttle = int(frames[cursor][1])
			frame.brake = int(frames[cursor][2])
			cursor += 1
		return frame

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func settle(cloud: Node) -> void:
	for attempt: int in range(100):
		await cloud.flush_outbox()
		var jobs: Array = cloud._read(cloud.outbox_path()).get("jobs",[])
		if not jobs.is_empty() and (jobs[-1].has("done") or jobs[-1].has("failure")): return
		await create_timer(0.2).timeout
	check(false,"verification completes before deadline: "+cloud.status)

func capture(filename: String) -> void:
	var output: String = OS.get_environment("BMT_CAPTURE_CLOUD")
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(filename+".png")) == OK,"screenshot "+filename)

func run() -> void:
	var client := Client.new()
	root.add_child(client)
	client.configure(OS.get_environment("BMT_API_URL"))
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = "user://cloud_tests_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BMT_CLOUD_FIXTURE")))
	var login: Dictionary = await client.development_login("cloud-creator","Cloud Creator",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"creator signs in")
	var uploaded: Dictionary = await cloud.upload_draft(fixture.document)
	check(uploaded.ok,"native client uploads validated draft")
	if not uploaded.ok:
		print(uploaded)
		quit(1)
		return
	var version: String = uploaded.data.version_id
	var repeated: Dictionary = await cloud.upload_draft(fixture.document)
	check(repeated.ok and repeated.data.version_id == version,"repeat upload uses durable idempotency key")
	var ticket: Dictionary = await client.race_ticket(version,"compact",Client.new_idempotency_key())
	check(ticket.ok,"creator gets server contract")
	check(cloud.queue_run(ticket.data,fixture.replay.frames,version),"publication replay durably queued")
	await settle(cloud)
	await cloud.refresh()
	check(cloud.entries.size() == 1,"verified publication enters cloud discovery")
	var searched: Dictionary = await client.request_api("/tracks?q=oval&creator=Cloud%20Creator")
	check(searched.ok and searched.data.items.size() == 1,"server combines name and creator search")
	if cloud.entries.is_empty():
		print(cloud.status)
		quit(1)
		return
	var source := TrackLibrary.new(cloud.root_override.path_join("drafts"))
	var catalog := TrackCatalog.new(source)
	var discovery := TrackDiscoveryProvider.new()
	cloud.add_to_catalog(catalog,discovery)
	var entry: Dictionary = catalog.entries[0]
	check(catalog.query({"section":"saved"},[]).size() == 1,"My tracks includes owned cloud versions")
	check(not FileAccess.file_exists(entry.cache_path),"browsing downloads metadata only")
	check(await cloud.download(entry),"selected track downloads and passes content hash")
	var track: NativeTrack = catalog.resolve(entry)
	check(track != null and track.identity == entry.id,"immutable cloud identity survives compilation")
	check(track.content_hash == ticket.data.manifest.track_content_hash,"downloaded document matches pinned race hash")
	check(discovery.query(catalog,{"search":"cloud creator","search_kind":2},[]).size() == 1,"creator search uses server-stamped author")
	check(discovery.query(catalog,{"search":"cloud creator","search_kind":1},[]).is_empty(),"name-only search excludes creator matches")
	check(discovery.query(catalog,{"theme":"winter"},[]).is_empty(),"biome filter")
	check(discovery.query(catalog,{"section":"favorites"},[entry.id]).size() == 1,"favorites find immutable versions")
	var creator_vote: Dictionary = await client.rate_track(version,5,Client.new_idempotency_key())
	check(not creator_vote.ok and creator_vote.status == 403,"self-rating rejected")
	var creator_outbox: String = cloud.outbox_path()
	await client.logout()
	await client.development_login("cloud-racer","Cloud Racer",OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(cloud.outbox_path() != creator_outbox,"outbox separated by account")
	var premature: Dictionary = await client.rate_track(version,5,Client.new_idempotency_key())
	check(not premature.ok and premature.status == 403,"unverified rating rejected")
	var race: Dictionary = await cloud.ticket(track)
	check(not race.is_empty(),"cloud race gets compatible contract")
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.resume_client = client
	game.resume_ticket_id = str(race.ticket_id)
	root.add_child(game)
	game.set_physics_process(false)
	var input := ReplayInput.new()
	input.frames = fixture.replay.frames
	game.driver = input
	game._physics_process(1.0/120.0)
	check(game.online_frames.is_empty(),"countdown excluded from replay")
	game.countdown_ticks = 0
	game.paused = true
	game._physics_process(1.0/120.0)
	check(game.online_frames.is_empty(),"pause excluded from replay")
	game.paused = false
	for tick: int in range(3600): game._physics_process(1.0/120.0)
	await game.open_rewind()
	check(game.rewind_panel != null and not game.rewind_panel.confirm.disabled,"signed-in daily resume offered")
	game.preview_rewind(0)
	var resumed_tick: int = game.sim.state.tick
	await game.confirm_rewind()
	check(game.online_rewinds.size() == 1 and resumed_tick == 1200,"actual server authorizes full twenty-second rewind")
	input.cursor = resumed_tick
	for tick: int in range(resumed_tick,fixture.replay.frames.size()): game._physics_process(1.0/120.0)
	check(game.track_session.finished and game.track_session.elapsed_ticks == 12757,"actual game race matches canonical verifier timing")
	check(game.online_frames.size() == fixture.replay.frames.size()+2400,"audit includes original and resumed input segments")
	check(cloud.queue_run(race,game.online_frames,"",game.online_rewinds),"actual game replay persisted")
	game.restart()
	check(game.online_frames.is_empty(),"retry resets captured inputs")
	game.queue_free()
	await process_frame
	# Simulate controller restart before upload; use the same durable player/server scope.
	var restored := Cloud.new()
	restored.client = client
	restored.root_override = cloud.root_override
	root.add_child(restored)
	await settle(restored)
	check(restored._read(restored.outbox_path()).jobs[-1].get("done",false),"rewind replay survives outbox reload and earns a verified leaderboard result")
	var board: Dictionary = await client.request_api("/track-versions/"+version+"/leaderboard?vehicle_id=compact&limit=1")
	check(board.ok and board.data.population == 2 and board.data.items.size() == 1 and board.data.next_offset == 1,"verified scores paginated per vehicle")
	var other: Dictionary = await client.request_api("/track-versions/"+version+"/leaderboard?vehicle_id=kart")
	check(other.ok and other.data.population == 0,"vehicle boards remain isolated")
	var vote: Dictionary = await client.rate_track(version,4,Client.new_idempotency_key())
	check(vote.ok and vote.data.rating_count == 1,"qualified cloud rating saved")
	var change: Dictionary = await client.rate_track(version,5,Client.new_idempotency_key())
	check(change.ok and change.data.rating_count == 1 and change.data.rating_average == 5,"changing vote preserves one vote per account")
	await cloud.refresh()
	cloud.add_to_catalog(catalog,discovery)
	check(catalog.entries[0].rating_average == 5,"aggregate rating refreshed from backend")
	var recovered := Cloud.new()
	recovered.client = client
	recovered.root_override = cloud.root_override
	root.add_child(recovered)
	recovered.load_cached()
	check(recovered.entries.size() == 1,"catalog survives restart")
	var before_url: String = client._base_url
	client._base_url = "http://127.0.0.1:1"
	check(await cloud.download(entry),"cached track works without network")
	client._base_url = before_url
	var file := FileAccess.open(entry.cache_path,FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	check(Cloud.cached_document(entry).is_empty(),"corrupt cached document rejected")
	check(await cloud.download(entry),"corrupt cache repaired from backend")
	var browser := TrackBrowser.new()
	browser.library = source
	browser.records = LocalRecords.new(cloud.root_override.path_join("records.json"))
	browser.catalog = catalog
	browser.discovery = discovery
	browser.cloud = cloud
	browser.state = {}
	browser.selected_track = track
	browser.builtin_ids = BuiltinTracks.ids()
	root.size = Vector2i(1280,720)
	root.add_child(browser)
	browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	while browser.loading or cloud.refreshing: await process_frame
	await browser._load_cloud_detail(track)
	while client._busy: await process_frame
	var rating: TrackRating = browser.find_child("TrackRating",true,false)
	check(rating.value() == 5 and not rating.locked,"rating control restores server vote and eligibility")
	await rating.choose(4)
	while cloud.refreshing: await process_frame
	check(rating.value() == 4 and cloud.entries[0].rating_average == 4,"rating interaction refreshes public aggregate")
	await rating.choose(5)
	while cloud.refreshing: await process_frame
	check(browser.matches.size() == 2,"menu combines installed starter and cloud catalog")
	await capture("cloud-library")
	browser._open_scores()
	await create_timer(0.4).timeout
	await capture("cloud-scores")
	browser.queue_free()
	await process_frame
	var app: Node = preload("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(cloud.root_override.path_join("app/records.json"))
	app.library = TrackLibrary.new(cloud.root_override.path_join("app/tracks"))
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await app.online.client.development_login("cloud-racer","Cloud Racer",OS.get_environment("BMT_DEV_AUTH_KEY"))
	app._account_changed()
	app.cloud.root_override = cloud.root_override
	app.cloud.load_cached()
	app.selected_track = track
	app._show_screen("tracks")
	var integrated: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	while integrated.loading or app.cloud.refreshing: await process_frame
	await integrated._load_cloud_detail(track)
	while app.online.client._busy: await process_frame
	check(integrated.matches.size() == 2,"real app connects cloud catalog to Play")
	await capture("cloud-menu-1280")
	root.size = Vector2i(960,540)
	await process_frame
	await process_frame
	check(integrated.race_button.get_global_rect().end.y <= root.get_visible_rect().end.y+1,"Race action fits compact viewport: button="+str(integrated.race_button.get_global_rect())+" viewport="+str(root.get_visible_rect()))
	await capture("cloud-menu-960")
	await app._start_race(track,false)
	game = app.game
	game.set_physics_process(false)
	input = ReplayInput.new()
	input.frames = fixture.replay.frames
	game.driver = input
	game.countdown_ticks = 0
	for tick: int in range(fixture.replay.frames.size()): game._physics_process(1.0/120.0)
	app._results()
	await settle(app.cloud)
	check(app.cloud._read(app.cloud.outbox_path()).jobs[-1].get("done",false),"actual app results queues and verifies completed race")
	var results: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	app._results_continue(results,results.get_parent())
	await process_frame
	var completion: RaceComplete = app.root_ui.find_child("RaceComplete",true,false)
	while completion.standings_busy or app.online.client._busy: await process_frame
	check(completion.global_rank.text.begins_with("RANK"),"results continuation displays server rank")
	await capture("cloud-results-960")
	app.queue_free()
	await process_frame
	cloud.queue_free()
	restored.queue_free()
	recovered.queue_free()
	client.queue_free()
	await process_frame
	print("Cloud tracks: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
