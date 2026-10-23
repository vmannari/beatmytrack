extends SceneTree
## Actual app input, bounded public pages and isolated player files.
const Paging = preload("res://tests/test_discovery_pages.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var browser: TrackBrowser
var client: ListClient
var output: String = "res://../docs/evidence/free-race-list-2026-10-17/headless"

class ListClient extends Paging.PagedClient:
	var track_total: int = 27
	var signed: bool = false
	var comparison_reads: int = 0
	func signed_in() -> bool: return signed
	func request_api(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", authenticated: bool = false) -> Dictionary:
		comparison_reads += 1
		return await super.request_api(path,method,body,key,authenticated)
	func metadata(number: int, index: int) -> Dictionary:
		var value: Dictionary = super.metadata(number,index)
		value.theme = ["pine","desert","winter","storm","night_city"][number%5]
		return value
	func request_discovery(body: Dictionary, owner: int, random_choice: bool = false) -> Dictionary:
		var value: Dictionary = await super.request_discovery(body,owner,random_choice)
		if not str(body.get("search","")).is_empty() or body.has("ids"): return value
		value.data.total = track_total
		value.data.items = value.data.items.filter(func(entry: Dictionary) -> bool: return entry.discovery_index < track_total)
		return value

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func frames(count: int = 8) -> void:
	for _frame: int in range(count): await process_frame
func settle() -> void:
	for _frame: int in range(120):
		await process_frame
		if not app.cloud.discovery_pages.loading and not browser.loading and not browser.selecting: break
	await frames()
func touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)
func tap(point: Vector2) -> void:
	touch(point,true)
	touch(point,false)
	await frames()
func swipe(point: Vector2, distance: Vector2) -> void:
	touch(point,true)
	for step: int in range(1,5):
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point+distance*step/4.0
		event.relative = distance/4.0
		root.push_input(event,true)
		await process_frame
	touch(point+distance,false)
	await settle()
func visible_card() -> TrackTile:
	for node: Node in browser.list_grid.get_children():
		if node is TrackTile and browser.track_list.get_global_rect().encloses(node.get_global_rect()): return node
	return null
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(120).timeout.connect(func() -> void: print("FAIL: free race list deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/free-race-list/session-"+TrackLibrary.unique_id())
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	client = ListClient.new()
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":2}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	root.add_child(client)
	app.cloud.client = client
	await app.cloud.query_discovery({"sort":"name"})
	app.cloud._write(app.cloud.cache_root().path_join(client.hash_value+".json"),client.document)
	var data: Array = []
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		# Preserve the game's 1280x720 design canvas on smaller physical windows.
		root.content_scale_size = Vector2i(1280,720) if dimensions.x < 1280 else dimensions
		app._show_screen("tracks")
		browser = app.root_ui.find_child("TrackBrowser",true,false)
		await settle()
		client.signed = true
		browser._show_detail()
		browser._render_tiles(true)
		await frames()
		check(client.comparison_reads == 0,"unselected list starts no detail comparison reads")
		client.signed = false
		check(browser.list_open and browser.track_list.is_visible_in_tree(),"Free Race opens full list "+str(dimensions))
		check(not browser.hero.is_visible_in_tree() and not browser.gallery.is_visible_in_tree() and not browser.race_button.is_visible_in_tree(),"detail and Race action wait for selection")
		check(browser._page_total() == 27 and browser.track_list.size.y > browser.size.y*0.8,"27 tracks use the available list area")
		check(browser._list_columns >= 3 and browser.list_grid.get_child_count() <= (ceili(browser.track_list.size.y/browser._list_stride.y)+3)*browser._list_columns,"responsive list has bounded controls")
		check(browser.list_grid.get_children().all(func(node: Node) -> bool: return node is TrackTile),"visible page boundaries are hydrated")
		check(browser.telemetry_exposures().size() > 0,"only visible list cards produce exposures")
		await capture("list-%dx%d"%[dimensions.x,dimensions.y])
		var original: NativeTrack = browser.selected_track
		var settings: Dictionary = browser.records.settings.duplicate(true)
		var first: TrackTile = visible_card()
		await swipe(first.get_global_rect().get_center(),Vector2(0,-160))
		check(browser.list_open and browser.track_list.scroll_vertical >= 150 and app.screen == "tracks","vertical card swipe scrolls without selecting or navigating")
		check(browser.selected_track == original and browser.records.settings == settings,"scrolling preserves the track and saved choices")
		var before: int = browser.track_list.scroll_vertical
		var wheel := InputEventMouseButton.new()
		wheel.position = browser.track_list.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await frames()
		check(browser.track_list.scroll_vertical > before,"mouse wheel scrolls the full list vertically")
		browser.track_list.scroll_vertical = before
		await swipe(browser.track_list.get_global_rect().get_center(),Vector2(-90,0))
		check(browser.list_open and app.screen == "tracks" and browser.track_list.scroll_vertical == before,"horizontal stroke on the list never selects or changes page")
		first = visible_card()
		var favorite: Button = first.get_node("ToggleFavorite")
		var identity: String = str(first.entry.id)
		await tap(favorite.get_global_rect().get_center())
		check(browser.list_open and identity in browser.records.settings.favorites,"list star saves favorite without opening detail")
		first = visible_card()
		identity = str(first.entry.id)
		before = browser.track_list.scroll_vertical
		await tap(first.get_global_rect().get_center())
		await settle()
		check(not browser.list_open and browser.hero.is_visible_in_tree() and browser.gallery.is_visible_in_tree() and browser.race_button.is_visible_in_tree(),"card tap opens the current detail and carousel")
		check(browser.selected_track.identity == identity,"detail belongs to the selected card")
		var close: Button = browser.hero.find_child("CloseTrackView",true,false)
		favorite = browser.hero.find_child("HeroFavorite",true,false)
		check(close != null and favorite.get_global_rect().position.y >= close.get_global_rect().end.y+7,"X sits above the lowered favorite star")
		check(close.get_global_rect().encloses(Rect2(close.get_global_rect().position,Vector2(48,48))),"X retains a full touch target")
		await capture("detail-%dx%d"%[dimensions.x,dimensions.y])
		await tap(favorite.get_global_rect().get_center())
		check(not browser.list_open,"detail favorite keeps the track view open")
		close = browser.hero.find_child("CloseTrackView",true,false)
		await tap(close.get_global_rect().get_center())
		if not browser.list_open or browser.track_list.scroll_vertical != before:
			print("RETURN_DIAGNOSTIC size=",dimensions," open=",browser.list_open," scroll=",browser.track_list.scroll_vertical," expected=",before," close=",close.get_global_rect()," hero=",browser.hero.get_global_rect()," viewport=",root.get_visible_rect())
		check(browser.list_open and browser.track_list.scroll_vertical == before,"X restores the same list scroll position")
		await capture("returned-%dx%d"%[dimensions.x,dimensions.y])
		var list_point: Vector2 = browser.track_list.get_global_rect().get_center()
		touch(list_point,true)
		touch(list_point,false,true)
		await frames()
		check(browser.list_open,"canceled list touch does not open a track")
		(browser.find_child("RaceFilters",true,false) as Button).pressed.emit()
		check(browser.filter_dialog.visible and not browser.track_list.is_processing_input(),"filter drawer blocks list input")
		browser.filter_dialog.close()
		check(browser.track_list.is_processing_input(),"closing filters restores list scrolling")
		(browser.find_child("RaceSearch",true,false) as Button).pressed.emit()
		check(browser.search_dialog.visible and not browser.track_list.is_processing_input(),"search drawer blocks list input")
		browser.search_dialog.close()
		data.append({"size":str(dimensions),"columns":browser._list_columns,"list":str(browser.track_list.size),"controls":browser.list_grid.get_child_count()})
	# Reach distant pages without creating thousands of cards or loading documents.
	client.track_total = 5000
	await app.cloud.query_discovery({"sort":"name"},[],[],true)
	await settle()
	browser.track_list.scroll_vertical = int(4250/browser._list_columns)*int(browser._list_stride.y)
	await settle()
	check(browser.list_open and browser.list_grid.get_children().all(func(node: Node) -> bool: return node is TrackTile),"deep list scrolling hydrates every visible card")
	check(int(browser.list_grid.get_child(0).get_meta("catalog_index")) > 4200 and browser.list_grid.get_child_count() <= 60,"5000-track list keeps a bounded distant window")
	check(app.cloud.discovery_pages.pages.size() <= 15 and client.requests.size() < 30,"scrolling fetches nearby pages within the existing cache bound")
	await capture("deep-list")
	await first_visible_detail_return()
	await settle()
	check(browser.list_open,"late detail work cannot reopen a closed view")
	var requests_before: int = client.requests.size()
	app.cloud.discovery_pages.pages.clear()
	app.cloud.discovery_pages.error = "Could not load tracks. Retry when connected."
	browser._refresh()
	await frames(24)
	check(client.requests.size() == requests_before,"failed list pages wait for explicit refresh without repeated reads")
	await capture("unavailable-list")
	# Empty results retain filters/search and a useful state inside the list.
	app.cloud.discovery_pages.error = ""
	browser.state.theme = "coast"
	app.cloud.discovery_pages.total = 0
	app.cloud.discovery_pages.pages.clear()
	browser._refresh()
	await frames()
	check(browser.list_open and browser.list_grid.find_child("TrackListEmptyState",true,false) != null,"empty result uses list space and keeps navigation available")
	await capture("empty-list")
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"layouts":data,"page_requests":client.requests.size()}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FREE_RACE_LIST ",JSON.stringify(report))
	app.queue_free()
	client.queue_free()
	await frames()
	quit(1 if failures else 0)

func first_visible_detail_return() -> void:
	var card: TrackTile = visible_card()
	if card == null: check(false,"distant card is visible"); return
	browser._select(card.entry)
	await settle()
	check(browser.grid.get_children().any(func(node: Node) -> bool: return node is TrackTile and node.selected and browser.gallery.get_global_rect().encloses(node.get_global_rect())),"opening a distant card reveals its complete card in the retained carousel")
	browser._close_track_view()
