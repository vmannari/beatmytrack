extends SceneTree
## Read-only live catalog acceptance in isolated records/cache, no saved login.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var expected_path: String = ProjectSettings.globalize_path("res://../docs/evidence/gcp-track-retention-2026-10-06/expected-catalog.json")
	if not FileAccess.file_exists(expected_path):
		push_error("Prepare the live migration integrity receipt before this opt-in check.")
		quit(1)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	var folder: String = ProjectSettings.globalize_path("res://../build/cloud-retention-check-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(app.online.client.base_url() == "https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app", "installed app reaches retained cloud origin")
	check(not app.online.client.signed_in(), "diagnostic has no saved account")
	await app.cloud.refresh(true)
	for page: int in range(5):
		if app.cloud.next_cursor.is_empty(): break
		await app.cloud.refresh(true)
	check(app.cloud.entries.size() == expected.tracks.size(), "all retained logical tracks load through normal pagination")
	var by_id: Dictionary = {}
	for row: Dictionary in app.cloud.entries: by_id[str(row.track_id)] = row
	for old: Dictionary in expected.tracks:
		var found: bool = by_id.has(str(old.track_id))
		check(found, "retained logical ID is discoverable")
		if not found: continue
		var metadata: Dictionary = by_id[str(old.track_id)]
		check(metadata.name == old.name and metadata.creator == "Beat my track" and metadata.content_hash == old.content_hash, "original name, attribution and immutable document retained")
		var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
		var downloaded: bool = await app.cloud.download(entry)
		check(downloaded, "retained document downloads with hash validation")
		if not downloaded: continue
		var track: NativeTrack = app.cloud.compile_entry(entry)
		check(track != null, "retained document compiles in installed Windows game")
		if track == null: continue
		var version: Dictionary = await app.online.client.request_api("/track-versions/" + str(metadata.version_id))
		check(version.ok and str(version.data.manifest.track_content_hash) == track.content_hash, "compiled geometry matches the cloud canonical head")
		check(version.ok and version.data.manifest.physics_version == VehicleSimulation.PHYSICS_VERSION and version.data.manifest.rules_key == RaceRules.KEY, "cloud head matches current physics and lap rules")
		check(version.ok and version.data.manifest.compiler_version == TrackCompiler.VERSION, "cloud head matches the current track compiler")
		await process_frame
	if OS.has_environment("BMT_STAGING_CONTRACT_TICKETS"):
		var key: String = OS.get_environment("BMT_DEV_AUTH_KEY")
		check(not key.is_empty(), "opt-in ticket acceptance has its development key")
		var login: Dictionary = await app.online.client.development_login("cloud-test-observer", "cloud-test-observer", key)
		check(login.ok, "isolated existing development observer signs in")
		if login.ok:
			for metadata: Dictionary in app.cloud.entries:
				if str(metadata.name).to_lower() != "blind spot": continue
				var track: NativeTrack = app.cloud.compile_entry(app.cloud.entry_from_metadata(metadata))
				var ticket: Dictionary = await app.cloud.ticket(track, false, "compact")
				check(not ticket.is_empty(), "Blind spot passes the real client online race-contract checks: " + app.cloud.last_error)
				break
			var logout: Dictionary = await app.online.client.logout()
			check(logout.ok and not app.online.client.signed_in(), "diagnostic observer logs out without retaining a session")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		app._show_screen("tracks")
		var browser: Node = app.root_ui.find_child("TrackBrowser", true, false)
		while browser != null and browser.loading: await process_frame
		if browser != null and not browser.catalog.entries.is_empty():
			browser._select(browser.catalog.entries[0])
			while browser.selecting: await process_frame
			check(browser.selected_track != null and not browser.race_button.disabled, "restored cloud track can be selected for racing")
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(expected_path.get_base_dir().path_join("race-catalog.png")) == OK, "actual restored cloud Race screenshot saved")
	print("Retained cloud catalog: %d checks, %d failures; %d tracks" % [checks, failures, app.cloud.entries.size()])
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
