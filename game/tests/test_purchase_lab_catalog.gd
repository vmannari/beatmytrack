extends SceneTree
## Actual local Race menu, downloads and contracts; no completed races or purchases.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("Catalog test deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/purchase-catalog-test-"+str(Time.get_ticks_usec()))
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(app.online.client.base_url().begins_with("http://127.0.0.1:"),"uses isolated loopback lab")
	var signed: Dictionary = await app.online.client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(signed.ok,"local development sign-in")
	await app.cloud.refresh(true)
	for _page: int in range(5):
		if app.cloud.next_cursor.is_empty(): break
		await app.cloud.refresh(true)
	check(app.cloud.entries.size() == 27,"all 27 approved public tracks are discoverable")
	for metadata: Dictionary in app.cloud.entries:
		var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
		var downloaded: bool = await app.cloud.download(entry)
		check(downloaded,"catalog track downloads with hash validation")
		if not downloaded: continue
		var track: NativeTrack = app.cloud.compile_entry(entry)
		check(track != null,"catalog track compiles")
		if track == null: continue
		var version: Dictionary = await app.online.client.request_api("/track-versions/"+str(metadata.version_id))
		check(version.ok and version.data.manifest.track_content_hash == track.content_hash,"native geometry matches backend")
		check(version.ok and version.data.manifest.rules_key == RaceRules.KEY and version.data.manifest.compiler_version == TrackCompiler.VERSION,"catalog matches current rules/compiler")
	app._show_screen("tracks")
	var browser: Node = app.root_ui.find_child("TrackBrowser",true,false)
	while browser != null and browser.loading: await process_frame
	check(browser != null and browser.matches.size() == 27,"Race menu contains all catalog cards")
	if browser != null and not browser.catalog.entries.is_empty():
		browser._select(browser.catalog.entries[0])
		while browser.selecting: await process_frame
		check(browser.selected_track != null and not browser.race_button.disabled,"selected track can be raced")
		var ticket: Dictionary = await app.cloud.ticket(browser.selected_track,false,"compact")
		check(not ticket.is_empty(),"selected track receives a real compatible race ticket")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var output: String = ProjectSettings.globalize_path("res://../docs/evidence/purchase-catalog-2026-10-07")
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join("race-menu.png")) == OK,"actual Race menu screenshot")
	print("PURCHASE_LAB_CATALOG: %d checks, %d failures; %d tracks" % [checks,failures,app.cloud.entries.size()])
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
