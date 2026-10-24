extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class CursorClient extends Client:
	signal release_read
	var requests: Array[Dictionary] = []
	var document: Dictionary
	var hash_value: String
	var views: Dictionary = {}
	var starts: Dictionary = {}
	var hold_once: bool = false
	var busy_once: bool = false
	var missing_card: int = -1
	func metadata(number: int) -> Dictionary:
		return {"track_id":"fixture-track-"+str(number),"version_id":"00000000-0000-4000-8000-"+str(number+1).pad_zeros(12),"content_hash":hash_value,"name":"Course %04d" % number,"creator":"Discovery Fixture","creator_id":"fixture-owner","theme":"pine","points":document.points,"rating_average":null,"rating_count":0,"verified_finishers":0,"published_at":5000-number}
	func request_discovery(body: Dictionary, _owner: int, random_choice: bool = false) -> Dictionary:
		requests.append(body.duplicate(true))
		if busy_once:
			busy_once = false
			await get_tree().process_frame
			return {"ok":false,"status":503,"data":{"detail":"DISCOVERY_QUERY_BUDGET"},"error":"busy"}
		var view: int
		var offset: int = 0
		if body.has("cursor"):
			view = int(str(body.cursor).get_slice(":",1))
			offset = int(str(body.cursor).get_slice(":",2))
		else:
			view = views.size()+1
			var numbers: Array[int] = []
			var q: Dictionary = body.get("query",{})
			for number: int in range(5000):
				if not str(q.get("search","")).is_empty() and not ("Course %04d" % number).contains(str(q.search)): continue
				if q.has("ids") and "fixture-track-"+str(number) not in q.ids: continue
				numbers.append(number)
			if not str(body.get("locate_version","")).is_empty():
				var target: int = int(str(body.locate_version).get_slice("-",4))-1
				offset = numbers.find(target)
				if offset < 0: return {"ok":false,"status":409,"data":{},"error":"unavailable"}
			views[view] = numbers
			starts[view] = offset
		var values: Array = views[view]
		var items: Array = []
		if random_choice:
			items.append(metadata(int(values[mini(4347,values.size()-1)])))
		else:
			for index: int in range(offset,mini(offset+20,values.size())):
				if int(values[index]) != missing_card: items.append(metadata(int(values[index])))
		var data: Dictionary = {"schema":"bmt-discovery-random-v3" if random_choice else "bmt-discovery-page-v3",
			"items":items,"total":null,"has_more":offset+20 < values.size(),"page_cursor":"v3:%d:%d" % [view,offset],
			"next_cursor":"v3:%d:%d" % [view,offset+20] if offset+20 < values.size() else null,
			"previous_cursor":"v3:%d:%d" % [view,maxi(int(starts[view]),offset-20)] if offset > int(starts[view]) else null,
			"expires_in":1800,"anchored":int(starts[view]) > 0}
		if hold_once:
			hold_once = false
			await release_read
		else: await get_tree().process_frame
		return {"ok":true,"status":200,"data":data,"error":""}
	func request_api(_path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return {"ok":false,"status":0,"data":{},"error":"offline fixture"}
	func request_public(_path: String, _owner: int) -> Dictionary:
		return {"ok":false,"status":0,"data":{},"error":"offline fixture"}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/discovery-indexed-2026-10-22")
	check(root.get_texture().get_image().save_png(folder.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"native capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	create_timer(90).timeout.connect(func() -> void: push_error("Discovery cursor deadline"); quit(1))
	var folder: String = ProjectSettings.globalize_path("res://../build/discovery-window-test-"+str(Time.get_ticks_usec()))
	var client := CursorClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":3}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	await cloud.query_discovery({"sort":"name"})
	var pages: Node = cloud.discovery_pages
	check(pages.has_method("windowed") and pages.total == 40 and cloud.entries.size() == 20,"first response uses a 40-slot local window and twenty cards")
	client.missing_card = 19
	await pages._fetch(0)
	check(cloud.entries.size() == 19 and pages.unavailable_slot(19) and not pages.unavailable_slot(20),"a removed card is a settled unavailable slot rather than an unfinished fetch")
	client.missing_card = -1
	await pages._fetch(0)
	for index: int in range(35):
		var high: int = int(pages.pages.keys().max())
		await pages._fetch(high+1)
		check(pages.pages.size() <= 13 and cloud.entries.size() <= 260 and pages.total <= 300,"forward browsing bounds cards and physical scroll coordinates")
	check(pages.coordinate_shift < 0,"long browsing rebases coordinates")
	var low: int = int(pages.pages.keys().min())
	var previous: String = str(pages.pages[low].previous)
	await pages._fetch(low-1)
	check(client.requests[-1].get("cursor","") == previous,"backward browsing reloads an evicted page through its cursor")
	check(client.requests.slice(1).all(func(body: Dictionary) -> bool: return body.has("cursor") and not body.has("query") and not body.has("offset")),"later requests carry only small cursor references")
	await cloud.query_discovery({"search":"4999","sort":"name"},[],[],true)
	check(cloud.entries.size() == 1 and cloud.entries[0].track_id == "fixture-track-4999" and pages.total == 1,"rare global search retains the sole result")
	await cloud.query_discovery({"sort":"name"},[],[],true)
	var chosen: Dictionary = await pages.random_entry("cloud_fixture-track-0")
	check(not chosen.is_empty() and chosen.track_id == "fixture-track-4347" and pages.entries()[0].track_id == chosen.track_id,"Random opens a bounded window at the exact chosen revision")
	var before: Array = pages.entries().duplicate(true)
	client.busy_once = true
	await pages._fetch(int(pages.pages.keys().max())+1)
	check(not pages.error.is_empty() and pages.entries() == before,"budget exhaustion retains cards and shows a retry state")
	await cloud.query_discovery({"sort":"name"},[],[],true)
	client.hold_once = true
	pages._fetch(1)
	client.player = {"id":"new-owner"}
	await cloud.query_discovery({"search":"4998","sort":"name"},[],[],true)
	client.release_read.emit()
	await process_frame
	check(pages.entries().size() == 1 and pages.entries()[0].track_id == "fixture-track-4998","late page cannot cross an account/query fence")
	client.player = {}
	await cloud.query_discovery({"sort":"name"},[],[],true)
	cloud._write(cloud.cache_root().path_join(client.hash_value+".json"),client.document)
	var library := TrackLibrary.new(folder.path_join("drafts"))
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	var entry: Dictionary = cloud.entry_from_metadata(client.metadata(0))
	check(await cloud.download(entry),"selected document keeps the existing immutable download path")
	var native_track: NativeTrack = cloud.compile_entry(entry)
	check(native_track != null,"selected cached track compiles")
	if native_track == null: quit(1); return
	catalog.remember_track(entry,native_track)
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.cloud = cloud
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.selected_track = native_track
	browser.state = {"sort":"name"}
	browser.size = root.get_visible_rect().size
	root.add_child(browser)
	for _frame: int in range(6): await process_frame
	check(browser.gallery_content.custom_minimum_size.x < 301*browser.tile_stride,"browser extent follows the local window")
	check(browser.count_label.text.contains("loaded") and not browser.count_label.text.contains("5000"),"browser labels loaded cards without inventing an exact total")
	await capture("window-list")
	browser._select(entry)
	for _frame: int in range(5): await process_frame
	await capture("window-gallery")
	check(not browser.race_button.disabled,"selected cached race remains available")
	# Exercise the real retained browser while pages are evicted and the local
	# coordinate system moves. Preserve the same card's column and screen row.
	root.size = Vector2i(1720,900)
	await process_frame
	browser.size = Vector2(1720,900)
	browser._set_list_open(true)
	for _frame: int in range(6): await process_frame
	check(20%browser._list_columns != 0,"rebase fixture uses a column count that does not divide twenty: %d / %s" % [browser._list_columns,str(browser.track_list.size)])
	for pass_number: int in range(18):
		while pages.loading: await process_frame
		var high: int = int(pages.pages.keys().max())
		var old_offset: int = browser._list_column_offset
		var old_shift: int = pages.coordinate_shift
		var anchor_index: int = maxi(0,(high-1)*20+5)
		var anchor_item: Dictionary = pages.entry_at(anchor_index)
		browser.track_list.scroll_vertical = int((anchor_index+old_offset)/browser._list_columns)*int(browser._list_stride.y)
		var old_y: int = browser.track_list.scroll_vertical
		await pages._fetch(high+1)
		var movement: int = pages.coordinate_shift-old_shift
		if movement != 0:
			var new_index: int = anchor_index+movement
			check(pages.entry_at(new_index).get("track_id","") == anchor_item.get("track_id","missing"),"eviction retains the exact visible card")
			check(posmod(anchor_index+old_offset,browser._list_columns) == posmod(new_index+browser._list_column_offset,browser._list_columns),"eviction preserves the card column")
			var expected_y: int = old_y+int((movement+browser._list_column_offset-old_offset)/browser._list_columns)*int(browser._list_stride.y)
			check(browser.track_list.scroll_vertical == expected_y,"eviction preserves the card screen row")
		await process_frame
	check(browser._window_shift < 0 and pages.total <= 300,"live browser follows rebased bounded extent")
	browser.page_preview = true
	while pages.loading: await process_frame
	await cloud.query_discovery({"sort":"name"},[],[],true)
	var drawer := preload("res://ui/track_search_drawer.gd").new()
	drawer.catalog = catalog
	drawer.discovery = TrackDiscoveryProvider.new()
	drawer.records = browser.records
	drawer.cloud = cloud
	root.add_child(drawer)
	drawer.draft = {"search":"4999","sort":"name"}
	drawer.show()
	await drawer._search_global()
	check(drawer.server_pages.has_method("windowed") and drawer.matches.size() == 1,"search drawer uses global v3 windows for a rare result")
	check(drawer.count_label.text.contains("loaded"),"search drawer does not claim a catalogue total")
	drawer.draft = {"search":"missing","sort":"name"}
	client.busy_once = true
	await drawer._search_global()
	check(drawer.count_label.text.contains("busy") and str(drawer.results.get_child(0).text).contains("busy"),"failed search shows retry instead of a false empty result: %s / %s" % [drawer.count_label.text,str(drawer.results.get_child(0).text)])
	drawer.queue_free()
	check(cloud.remember_publication(client.metadata(4321)),"accepted publication metadata is retained immediately")
	await cloud.query_discovery({"sort":"name"},[],[],true)
	check(pages.entries()[0].version_id == client.metadata(4321).version_id and cloud._publication_pin.is_empty(),"publication handoff opens an anchored v3 window at its exact revision")
	root.size = Vector2i(960,540)
	await process_frame
	browser.scale = Vector2(0.75,0.75)
	browser.size = Vector2(1280,720)
	browser.page_preview = false
	browser._cloud_changed()
	browser._set_list_open(true)
	browser.track_list.scroll_vertical = 0
	for _frame: int in range(8): await process_frame
	check(not browser._list_entry(0,true).is_empty(),"compact capture has the current anchored page loaded")
	await capture("window-compact")
	var original_index: String = cloud._index_path()
	client.player = {"id":"another-account"}
	cloud.load_cached()
	check(cloud._index_path() != original_index and cloud.entries.is_empty(),"another account cannot reopen a private filtered index")
	client.player = {}
	cloud.load_cached()
	check(not cloud.entries.is_empty() and cloud.entries[0].version_id == client.metadata(4321).version_id,"the original account retains its cached exact publication revision")
	browser.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	print("DISCOVERY_WINDOWS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
