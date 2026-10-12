extends SceneTree
## Opt-in public staging read with isolated records/cache and real menu captures.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/discovery-paging-2026-10-07")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run() -> void:
	var origin: String = OS.get_environment("BMT_STAGING_API_URL")
	if origin.is_empty(): push_error("Explicit staging origin required"); quit(1); return
	OS.set_environment("BMT_API_URL",origin)
	root.size = Vector2i(1280,720)
	create_timer(90).timeout.connect(func() -> void: push_error("Live discovery deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/discovery-live-"+str(Time.get_ticks_usec()))
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("drafts"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.client.signed_in(),"public diagnostic has no saved player session")
	check(app.cloud.paged_discovery_available(),"live bootstrap enables discovery protocol two")
	await app.cloud.query_discovery({"feed":"new"},[],[],true)
	var pages: Node = app.cloud.discovery_pages
	check(pages.total >= 28 and app.cloud.entries.size() <= 20,"live first page exposes global count with bounded previews")
	while app.cloud.entries.size() < pages.total:
		await app.cloud.load_more()
		if pages.loading: await process_frame
		if not pages.error.is_empty(): break
	check(app.cloud.entries.size() == pages.total,"normal Load more reaches every current public track")
	var matches: Array = app.cloud.entries.filter(func(item: Dictionary) -> bool: return item.name == "Star" and item.track_id == "3fe3be78-8db0-4404-81fe-9a25742f6cd1")
	check(matches.size() == 1,"published Star appears exactly once")
	if matches.is_empty(): quit(1); return
	var metadata: Dictionary = matches[0]
	check(await app.cloud.download(app.cloud.entry_from_metadata(metadata)),"Star downloads through ordinary document/hash validation")
	app._open_published_track(metadata)
	var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	var deadline: int = Time.get_ticks_msec()+15000
	while (browser.loading or browser.selecting or browser.selected_track.identity != "cloud_"+str(metadata.track_id)) and Time.get_ticks_msec() < deadline: await process_frame
	for _frame: int in range(5): await process_frame
	check(browser.selected_track.identity == "cloud_"+str(metadata.track_id) and not browser.race_button.disabled,"actual Star is selected and ready in Free Race")
	check(browser.grid.get_child_count() <= 12,"actual menu bounds active cards")
	check(browser.grid.get_children().all(func(node: Node) -> bool: return node.size.y <= 140.0),"actual card names and creators fit inside carousel")
	await capture("live-star-desktop")
	browser.search_dialog.open_for(browser.state,browser.find_child("RaceSearch",true,false))
	browser.search_dialog.edit.text = "Star"
	browser.search_dialog.edit.text_changed.emit("Star")
	await create_timer(0.6).timeout
	deadline = Time.get_ticks_msec()+15000
	while (not is_instance_valid(browser.search_dialog.server_pages) or browser.search_dialog.server_pages.loading) and Time.get_ticks_msec() < deadline: await process_frame
	check(browser.search_dialog.matches.any(func(item: Dictionary) -> bool: return item.track_id == metadata.track_id),"live global search finds Star")
	await capture("live-global-search")
	browser.search_dialog.close()
	browser.filter_dialog.open_for(browser.state,browser.filter_button)
	check(not browser.filter_dialog.find_child("Choice_feed_popular",true,false).disabled,"live menu enables Popular")
	await capture("live-filter-drawer")
	browser.filter_dialog.close()
	root.size = Vector2i(960,540)
	for _frame: int in range(5): await process_frame
	await browser._reveal_track("cloud_"+str(metadata.track_id))
	await capture("live-star-compact")
	print("LIVE_DISCOVERY: %d checks, %d failures; %d public tracks" % [checks,failures,pages.total])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
