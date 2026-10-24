extends SceneTree
## Isolated real-HTTP daily feed, full search and native Free Race presentation.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var folder: String = OS.get_environment("BMT_DAILY_EVIDENCE_DIR")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	create_timer(80).timeout.connect(func() -> void: push_error("Daily selection HTTP deadline"); quit(1))
	var filters = preload("res://backend/discovery_filters.gd")
	check(filters.payload({}).feed == "daily","ordinary Free Race requests daily selection")
	for state: Dictionary in [{"search":"Circuit"},{"sort":"name"},{"theme":"pine"},{"section":"favorites"},{"race_history":"unraced"},{"feed":"popular"},{"age_days":7},{"minimum_rating":4.0},{"race_count":"low"}]:
		check(filters.payload(state).feed != "daily","explicit search or filters reach the full catalogue: "+str(state))
	var client := preload("res://backend/backend_client.gd").new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_DAILY_API_URL")) == OK,"isolated local HTTP origin")
	var boot: Dictionary = await client.request_api("/bootstrap")
	check(boot.ok and int(client._capabilities.get("discovery_daily_version",0)) == 1,"real bootstrap advertises daily selection")
	var folder: String = ProjectSettings.globalize_path("res://../build/daily-native-"+str(Time.get_ticks_usec()))
	var cloud := preload("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	await cloud.query_discovery({},[],[],true)
	var pages: Node = cloud.discovery_pages
	check(pages.query.feed == "daily" and pages.error.is_empty(),"real default query loads the daily publication")
	while cloud.entries.size() < 100 and pages.has_more and pages.error.is_empty():
		if pages.loading: await process_frame
		else: await cloud.load_more()
	check(cloud.entries.size() == 100 and pages.has_more,"daily hundred retain a continuation cursor")
	var selected: Array = cloud.entries.map(func(item: Dictionary) -> String: return str(item.track_id))
	check(not selected.has(OS.get_environment("BMT_DAILY_MISSING_ID")),"search fixture is outside the daily selection")
	var random: Dictionary = await pages.random_entry("")
	check(not random.is_empty() and selected.has(str(random.track_id)),"Random chooses within daily picks")
	check(pages.query.feed == "daily" and pages.error.is_empty(),"Random anchors the same daily feed")
	await cloud.query_discovery({},[],[],true)
	while cloud.entries.size() < 100 and pages.has_more and pages.error.is_empty():
		if pages.loading: await process_frame
		else: await cloud.load_more()
	var entry: Dictionary = cloud.entry_from_metadata(cloud.entries[0])
	check(await cloud.download(entry),"actual immutable track document downloads")
	var native: NativeTrack = cloud.compile_entry(entry)
	check(native != null,"actual selected track compiles for native presentation")
	if native == null: quit(1); return
	var library := TrackLibrary.new(folder.path_join("drafts"))
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	catalog.remember_track(entry,native)
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.cloud = cloud
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.selected_track = native
	browser.state = {}
	browser.size = Vector2(1280,720)
	root.add_child(browser)
	for _frame: int in range(12): await process_frame
	var ready_deadline: int = Time.get_ticks_msec()+10000
	while (pages.loading or cloud.refreshing) and Time.get_ticks_msec() < ready_deadline: await process_frame
	for _frame: int in range(3): await process_frame
	check(browser.count_label.text.contains("Daily picks"),"Free Race identifies the daily selection")
	await capture("daily-free-race")
	# Exercise the actual list's scroll-driven preload across the hundred boundary.
	browser.track_list.scroll_vertical = int(95/browser._list_columns)*int(browser._list_stride.y)
	var continuation_deadline: int = Time.get_ticks_msec()+10000
	while (cloud.entries.size() <= 100 or pages.loading) and Time.get_ticks_msec() < continuation_deadline: await process_frame
	check(cloud.entries.size() > 100 and pages.error.is_empty(),"scrolling the actual Free Race list loads beyond the daily hundred")
	var extended: Array = cloud.entries.map(func(item: Dictionary) -> String: return str(item.track_id))
	check(extended.slice(0,100) == selected,"continuation retains the original hundred in their exact order")
	var unique: Dictionary = {}
	for identity: String in extended: unique[identity] = true
	check(unique.size() == extended.size(),"continuation does not repeat curated tracks")
	check(browser.list_grid.get_child_count() < 100,"continued scrolling keeps bounded native card controls")
	await capture("continuation-after-100")
	while pages.has_more and pages.error.is_empty():
		if pages.loading: await process_frame
		else: await cloud.load_more()
	check(cloud.entries.size() == 180 and not pages.has_more,"continued browsing reaches the actual catalogue end")
	check(cloud.entries.any(func(item: Dictionary) -> bool: return str(item.track_id) == OS.get_environment("BMT_DAILY_MISSING_ID")),"a track outside the daily selection is also reachable by scrolling")
	browser.search_dialog.open_for(browser.state,browser.find_child("RaceSearch",true,false))
	browser.search_dialog.edit.text = OS.get_environment("BMT_DAILY_MISSING_NAME")
	browser.search_dialog.edit.text_changed.emit(browser.search_dialog.edit.text)
	await create_timer(0.6).timeout
	var deadline: int = Time.get_ticks_msec()+10000
	while (not is_instance_valid(browser.search_dialog.server_pages) or browser.search_dialog.server_pages.loading) and Time.get_ticks_msec() < deadline: await process_frame
	check(browser.search_dialog.matches.any(func(item: Dictionary) -> bool: return str(item.track_id) == OS.get_environment("BMT_DAILY_MISSING_ID")),"actual Search drawer finds a track outside the daily picks")
	await capture("full-catalogue-search")
	browser.search_dialog.close()
	root.size = Vector2i(960,540)
	browser.scale = Vector2(0.75,0.75)
	browser.size = Vector2(1280,720)
	for _frame: int in range(8): await process_frame
	await capture("daily-compact")
	browser.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	print("DAILY_TRACK_SELECTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
