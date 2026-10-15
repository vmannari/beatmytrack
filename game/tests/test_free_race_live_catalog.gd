extends SceneTree
## Explicit local-service acceptance: real public pages, native geometry and tickets.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: live catalog deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/free-race-live-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var local_service: bool = app.online.client.base_url() == "http://127.0.0.1:18181"
	check(local_service, "explicit local PC service only")
	if not local_service:
		print("FREE_RACE_LIVE: local service required; no credentials sent")
		quit(1)
		return
	app.online.client.session_path = ""
	var signed: Dictionary = await app.online.client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(signed.ok,"local development identity authenticates without saving a session")
	if not signed.ok:
		print("FREE_RACE_LIVE: sign-in failed; no catalog acceptance claimed")
		quit(1)
		return
	await app.cloud.query_discovery({},[],[],true)
	check(app.cloud.discovery_pages.total == 27,"public Free Race collection has all27 tracks")
	app._show_screen("tracks")
	var browser: Node = app.root_ui.find_child("TrackBrowser",true,false)
	check(browser != null,"actual Free Race browser opens")
	if browser == null:
		quit(1)
		return
	for index: int in range(30): await process_frame
	# Drive the real gallery's pagination wiring, without forcing a private fetch.
	browser.gallery.scroll_horizontal = 21*browser.tile_stride
	while not app.cloud.discovery_pages.pages.has(1) or app.cloud.discovery_pages.loading:
		await process_frame
	var entries: Array[Dictionary] = app.cloud.discovery_pages.entries()
	check(entries.size() == 27,"both20+7 pages load through the actual client")
	var ids: Dictionary = {}
	for metadata: Dictionary in entries:
		var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
		check(not ids.has(entry.track_id),"unique public track identity")
		ids[entry.track_id] = true
		var downloaded: bool = await app.cloud.download(entry)
		check(downloaded,"actual document passes download hash/schema validation")
		if not downloaded: continue
		var track: NativeTrack = app.cloud.compile_entry(entry)
		check(track != null,"actual downloaded route compiles")
		if track == null: continue
		var published: Dictionary = await app.online.client.request_api("/track-versions/"+str(entry.version_id))
		check(published.ok and published.data.manifest.track_content_hash == track.content_hash,"Windows native geometry matches published Linux pin")
		var ticket: Dictionary = await app.cloud.ticket(track,false,"compact")
		check(not ticket.is_empty(),"real compatible five-lap ticket for every public track")
		if ticket.is_empty(): print("TICKET_DETAIL: ",str(entry.name)," / ",str(app.cloud.last_error))
	app._show_screen("tracks")
	browser = app.root_ui.find_child("TrackBrowser",true,false)
	for index: int in range(30): await process_frame
	check(browser != null and browser.cloud.discovery_pages.total == 27,"actual Free Race browser retains27-track pagination")
	check(browser != null and browser.catalog.entries.size() == 27,"actual browser contains all loaded public entries")
	print("FREE_RACE_LIVE: %d checks, %d failures; %d tracks; no completed/submitted races" % [checks,failures,ids.size()])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
