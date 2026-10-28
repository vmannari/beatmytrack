extends SceneTree
## Actual browser + owned, delayed HTTP fixtures; no service or player writes.
const CursorFixture = preload("res://tests/test_discovery_windows.gd")
const PageFixture = preload("res://tests/test_discovery_pages.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var output: String = ProjectSettings.globalize_path("res://../docs/evidence/free-race-preload-2026-10-23/captures")

class SlowCursor extends CursorFixture.CursorClient:
	var block_reads: bool = false
	func request_discovery(body: Dictionary, owner: int, random_choice: bool = false) -> Dictionary:
		if block_reads: hold_once = true
		return await super.request_discovery(body,owner,random_choice)

class SlowPage extends PageFixture.PagedClient:
	var block_reads: bool = false
	func request_discovery(body: Dictionary, owner: int, random_choice: bool = false) -> Dictionary:
		if block_reads: hold_once = true
		return await super.request_discovery(body,owner,random_choice)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func frames(count: int = 8) -> void:
	for _frame: int in range(count): await process_frame
func settle(window: Node) -> void:
	for _frame: int in range(100):
		await process_frame
		if not window.loading:
			await frames(3)
			if not window.loading: return
	check(false,"bounded preload finishes")
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"capture "+label)
func card_checks(browser: TrackBrowser, label: String) -> void:
	check(browser._page_total() == browser.matches.size(),label+": extent contains only actual cards")
	check(browser.list_grid.get_children().all(func(child: Node) -> bool: return child is TrackTile or (child is Control and not child is Label and int(child.get_meta("catalog_index",-1)) < browser._list_column_offset)),label+": list has no unloaded placeholders")
	check(browser.grid.get_children().all(func(child: Node) -> bool: return child is TrackTile),label+": carousel has no unloaded placeholders")
	var expected: float = maxf(1,ceilf(float(browser.matches.size()+browser._list_column_offset)/browser._list_columns)*browser._list_stride.y-12)
	check(is_equal_approx(browser.list_content.custom_minimum_size.y,expected),label+": list ends at its final loaded row")
	check(browser.gallery_content.custom_minimum_size.x == maxi(1,browser.matches.size()*browser.tile_stride-12),label+": carousel ends at its final loaded card")

func run() -> void:
	root.theme = MenuStyle.theme()
	create_timer(120).timeout.connect(func() -> void: push_error("Preload test deadline"); quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	for protocol: int in [3]: await protocol_checks(protocol)
	print("FREE_RACE_PRELOAD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func protocol_checks(protocol: int) -> void:
	var folder: String = ProjectSettings.globalize_path("res://../build/free-race-preload-%d-%d" % [protocol,Time.get_ticks_usec()])
	var client: Node = SlowCursor.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":protocol}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/ellipse.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	await cloud.query_discovery({"sort":"name"})
	var window: Node = cloud.discovery_pages
	cloud._write(cloud.cache_root().path_join(client.hash_value+".json"),client.document)
	var library := TrackLibrary.new(folder.path_join("drafts"))
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	var entry: Dictionary = cloud.entry_from_metadata(client.metadata(0))
	check(await cloud.download(entry),"fixture uses existing exact document cache")
	var track: NativeTrack = cloud.compile_entry(entry)
	check(track != null,"fixture compiles through normal validation")
	if track == null: quit(1); return
	catalog.remember_track(entry,track)
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.cloud = cloud
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.selected_track = track
	browser.state = {"sort":"name"}
	browser.page_preview = true
	root.add_child(browser)
	for dimensions: Vector2i in [Vector2i(1720,900),Vector2i(960,540),Vector2i(390,844),Vector2i(844,390)]:
		var label: String = "v%d-%dx%d" % [protocol,dimensions.x,dimensions.y]
		browser.page_preview = true
		await cloud.query_discovery({"sort":"name"},[],[],true)
		root.size = dimensions
		root.content_scale_size = dimensions
		browser.size = dimensions
		browser._set_list_open(true)
		client.block_reads = true
		browser.page_preview = false
		browser._cloud_changed()
		await frames()
		check(window.loading and cloud.entries.size() == 20,label+": preload begins before the first page is exhausted")
		card_checks(browser,label+" pending")
		browser.track_list.scroll_vertical = 1000000
		await frames()
		card_checks(browser,label+" pending end")
		check(browser.track_list.scroll_vertical <= maxi(0,ceili(browser.list_content.custom_minimum_size.y-browser.track_list.size.y)),label+": delayed network clamps at loaded end")
		await capture(label+"-pending-end")
		client.block_reads = false
		client.release_read.emit()
		await settle(window)
		var visible: int = ceili(browser.track_list.size.y/browser._list_stride.y)*browser._list_columns
		var first: int = int(browser.track_list.scroll_vertical/browser._list_stride.y)*browser._list_columns
		check(browser.matches.size() >= first+visible+mini(60,maxi(20,visible*2)),label+": completion fills the viewport reserve without another scroll")
		check(browser.matches.size() <= 160,label+": stationary view does not drain the catalogue")
		var request_count: int = client.requests.size()
		await frames(12)
		check(client.requests.size() == request_count,label+": background requests stop when the reserve is full")
		card_checks(browser,label+" loaded")
		await capture(label+"-loaded")
		browser._set_list_open(false)
		browser._render_tiles(true)
		await frames()
		card_checks(browser,label+" carousel")
		await capture(label+"-carousel")
		browser._set_list_open(true)
		await settle(window)
	if protocol == 3:
		browser.page_preview = true
		client.missing_card = 19
		await cloud.query_discovery({"sort":"name"},[],[],true)
		client.block_reads = true
		browser.page_preview = false
		browser._cloud_changed()
		await frames()
		check(browser.matches.size() == 19,"authority-filtered page displays nineteen cards without a twentieth empty slot")
		card_checks(browser,"sparse page")
		client.block_reads = false
		client.release_read.emit()
		await settle(window)
		client.missing_card = -1
		# Failure keeps the loaded end and pauses automatic retries.
		client.busy_once = true
		await window._fetch(int(window.pages.keys().max())+1)
		var failed_reads: int = client.requests.size()
		browser.track_list.scroll_vertical = 1000000
		browser._render_list(true)
		await frames()
		check(not window.error.is_empty() and client.requests.size() == failed_reads,"failed page retains cards and does not retry on scroll")
		card_checks(browser,"failed page")
		await capture("v3-failed-page")
		window.retry_at_msec = 0
	# A terminal search shrinks to exactly one actual card in both protocols.
	browser.page_preview = true
	await cloud.query_discovery({"search":"4999","sort":"name"},[],[],true)
	browser.page_preview = false
	browser._cloud_changed()
	await frames()
	check(browser.matches.size() == 1 and not window.loading,"terminal search ends without extra reads")
	card_checks(browser,"terminal search")
	browser.queue_free()
	cloud.queue_free()
	client.queue_free()
	await frames()
