extends SceneTree
## Uses the installed PC configuration, with no injected URL/key or Google verifier.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + description)

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/track-restoration-2026-10-03")
	DirAccess.make_dir_recursive_absolute(folder)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(filename + ".png")) == OK, "capture " + filename)

func run() -> void:
	check(not OS.has_environment("BMT_API_URL") and not OS.has_environment("BMT_DEV_AUTH_KEY"), "test uses installed config, not environment overrides")
	var folder: String = "user://pc_account_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("account")
	await app.online.refresh_options()
	check(app.online.capabilities.get("service", "") == "beat-my-track", "connects to game backend")
	if failures == 0:
		await capture("pc-options")
		await app.online.sign_in_developer()
		check(app.online.client.signed_in(), "PC Development login succeeds")
		check(app.online.player_name() == "Beat my track", "fixed developer name")
		var player_id: String = str(app.online.client.player.get("id", ""))
		await capture("pc-developer")
		app._show_screen("tracks")
		var browser: Node = app.root_ui.find_child("TrackBrowser",true,false)
		while browser.loading: await process_frame
		check(not app.cloud.entries.is_empty(), "published server catalog is available")
		check(app.cloud.entries.all(func(metadata: Dictionary) -> bool: return app.track_catalog.entries.any(func(visible: Dictionary) -> bool: return visible.id == "cloud_"+str(metadata.track_id))), "every server publication appears in Race")
		check(app.track_catalog.entries.all(func(entry: Dictionary) -> bool: return entry.source == "cloud" and entry.creator == "Beat my track"), "Race uses server publications and the requested creator attribution")
		if not app.track_catalog.entries.is_empty():
			browser._select(app.track_catalog.entries[0])
			while browser.selecting: await process_frame
			check(browser.selected_track.metadata.has("cloud_version") and not browser.race_button.disabled, "a restored backend track can be selected for driving")
			await create_timer(0.6).timeout
		await capture("pc-existing-tracks")
		app._show_screen("account")
		await app.online.sign_out()
		check(not app.online.client.signed_in(), "sign out succeeds")
		await app.online.sign_in_developer()
		check(str(app.online.client.player.get("id", "")) == player_id, "same durable account on repeat login")
		await app.online.sign_out()
	app.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("PC_ACCOUNT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
