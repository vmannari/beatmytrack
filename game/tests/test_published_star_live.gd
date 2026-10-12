extends SceneTree
## Opt-in, read-only live discovery and native Race capture; no player login.
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
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/published-track-2026-10-07")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run() -> void:
	var origin: String = OS.get_environment("BMT_STAGING_API_URL")
	if origin.is_empty(): push_error("Explicit BMT_STAGING_API_URL required for opt-in public read"); quit(1); return
	OS.set_environment("BMT_API_URL",origin)
	root.size = Vector2i(1280,720)
	create_timer(90).timeout.connect(func() -> void: push_error("Live discovery deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/published-star-live-"+str(Time.get_ticks_usec()))
	var app: Node = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.client.signed_in(),"isolated diagnostic has no saved login")
	await app.cloud.refresh(true)
	for _page: int in range(5):
		if app.cloud.next_cursor.is_empty(): break
		await app.cloud.refresh(true)
	var found: Array = app.cloud.entries.filter(func(item: Dictionary) -> bool: return item.name == "Star" and item.track_id == "3fe3be78-8db0-4404-81fe-9a25742f6cd1")
	check(found.size() == 1,"actual published Star is in public Free Race catalog")
	if found.is_empty(): app.queue_free(); quit(1); return
	var metadata: Dictionary = found[0]
	check(metadata.state == "published" and not metadata.hidden and metadata.creator == "Ville","real publication is public with correct creator")
	var entry: Dictionary = app.cloud.entry_from_metadata(metadata)
	check(await app.cloud.download(entry),"Star downloads with normal hash/document validation")
	# Reproduce the previous post-publication navigation: retain the local draft
	# selection and merely open Race, leaving Star beyond the initial carousel.
	app.selected_track = TrackCompiler.compile(app.cloud.cached_document(entry))
	app.browser_state.clear()
	app._show_screen("tracks")
	var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
	while browser.loading: await process_frame
	check(browser.grid.get_node_or_null("Track_"+str(entry.id)) == null,"prior return behavior leaves Star outside the initial virtual card window")
	await capture("star-before-return")
	# The actual navigation used by the corrected publication handler.
	app.browser_state = {"section":"favorites","search":"missing","theme":"desert","minimum_rating":4.5}
	app.race_area_mode = "rivalry"
	app._open_published_track(metadata)
	browser = app.root_ui.find_child("TrackBrowser",true,false)
	var deadline: int = Time.get_ticks_msec()+20000
	while (browser.loading or browser.selecting or browser.selected_track.identity != entry.id) and Time.get_ticks_msec() < deadline: await process_frame
	for _frame: int in range(5): await process_frame
	check(app.race_area_mode == "free" and browser.matches.size() == app.cloud.entries.size(),"publication opens Free Race with no excluding filters")
	check(browser.selected_track.identity == entry.id and not browser.race_button.disabled,"actual Star selected with Race enabled")
	var card: Control = browser.grid.get_node_or_null("Track_"+str(entry.id))
	check(card != null and card.get_global_rect().intersection(browser.gallery.get_global_rect()).size.x >= card.size.x-1,"Star card is fully visible in desktop carousel")
	await capture("star-free-race-desktop")
	root.size = Vector2i(960,540)
	for _frame: int in range(5): await process_frame
	await browser._reveal_track(str(entry.id))
	card = browser.grid.get_node_or_null("Track_"+str(entry.id))
	check(card != null and card.get_global_rect().intersection(browser.gallery.get_global_rect()).size.x >= card.size.x-1,"Star card remains fully visible at compact landscape size")
	await capture("star-free-race-compact")
	print("PUBLISHED_STAR_LIVE: %d checks, %d failures; %d actual public tracks" % [checks,failures,app.cloud.entries.size()])
	app.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
