extends SceneTree
## Real virtual carousel over 5,000 server-shaped records; fixture metadata only.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class PagedClient extends Client:
	signal release_read
	var requests: Array[Dictionary] = []
	var document: Dictionary
	var hash_value: String
	var hold_once: bool = false
	var invalid_once: bool = false
	func metadata(number: int, index: int) -> Dictionary:
		return {"track_id":"fixture-track-"+str(number),"version_id":"00000000-0000-4000-8000-"+str(number+1).pad_zeros(12),"content_hash":hash_value,"name":"Course %04d" % number,"creator":"Discovery Fixture","creator_id":"fixture-owner","theme":"pine","points":document.points,"rating_average":null,"rating_count":0,"verified_finishers":0,"discovery_index":index,"published_at":5000-number}
	func request_discovery(body: Dictionary, _owner: int, random_choice: bool = false) -> Dictionary:
		requests.append(body.duplicate(true))
		var numbers: Array[int] = []
		for number: int in range(5000):
			var search: String = str(body.get("search",""))
			if not search.is_empty() and not ("Course %04d" % number).contains(search): continue
			if body.has("ids") and "fixture-track-"+str(number) not in body.ids: continue
			numbers.append(number)
		var offset: int = int(body.get("offset",0))
		if random_choice: offset = mini(4347,maxi(0,numbers.size()-1))
		var items: Array = []
		for index: int in range(offset,mini(offset+(1 if random_choice else 20),numbers.size())): items.append(metadata(numbers[index],index))
		var data: Dictionary = {"items":items,"total":numbers.size(),"offset":offset,"snapshot":"11111111-1111-4111-8111-111111111111","page_cursor":"opaque-fixture-snapshot","next_cursor":"opaque-fixture-snapshot" if offset+20 < numbers.size() else null}
		if invalid_once: invalid_once = false; data.items = [{"wrong":"response"}]
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

func settle(pages: Node) -> void:
	for _frame: int in range(60):
		await process_frame
		if not pages.loading: break
	for _frame: int in range(3): await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/discovery-paging-2026-10-07")
	DirAccess.make_dir_recursive_absolute(output)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	create_timer(90).timeout.connect(func() -> void: push_error("Discovery page deadline"); quit(1))
	folder = ProjectSettings.globalize_path("res://../build/discovery-page-test-"+str(Time.get_ticks_usec()))
	var client := PagedClient.new()
	root.add_child(client)
	client.configure("http://127.0.0.1:1")
	client._capabilities = {"discovery_paging_version":2}
	client.document = TrackDocument.from_builtin(NativeTrack.read("res://resources/tracks/starter_circuit.json"))
	client.hash_value = JSON.stringify(client.document).sha256_text()
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	cloud.load_cached()
	await cloud.query_discovery({"sort":"name"})
	var pages: Node = cloud.discovery_pages
	print("DISCOVERY_INITIAL: total=",pages.total," entries=",cloud.entries.size()," error=",pages.error," requests=",client.requests.size())
	check(pages.total == 5000 and cloud.entries.size() == 20,"first page exposes total without fetching entire catalog")
	var started: int = Time.get_ticks_usec()
	for number: int in range(1,250):
		pages.desired_index = number*20
		await pages._fetch(number)
		check(pages.pages.size() <= 15 and cloud.entries.size() <= 300,"preview cache remains bounded while reaching each page")
	check(pages.entry_at(4999).track_id == "fixture-track-4999","last of 5000 tracks remains reachable")
	check(not pages.pages.has(0),"distant first-page payload is evicted")
	pages.request_visible(0)
	await settle(pages)
	check(pages.entry_at(0).track_id == "fixture-track-0" and pages.pages.size() <= 15,"scrolling back reloads first page at its original position")
	print("DISCOVERY_5000_PAGING_MS: ",(Time.get_ticks_usec()-started)/1000.0)
	await cloud.query_discovery({"search":"4999","sort":"name"})
	check(pages.total == 1 and cloud.entries[0].track_id == "fixture-track-4999","global search finds a track beyond every cached window")
	await cloud.query_discovery({"section":"favorites"},["cloud_fixture-track-4998"])
	check(pages.total == 1 and cloud.entries[0].track_id == "fixture-track-4998","favorites fetch exact IDs independently of community cache")
	client.hold_once = true
	cloud.query_discovery({"search":"1000"})
	await process_frame
	await cloud.query_discovery({"search":"2000"})
	client.release_read.emit()
	await process_frame
	check(pages.total == 1 and cloud.entries[0].track_id == "fixture-track-2000","late previous query cannot overwrite current search")
	await cloud.query_discovery({"sort":"name"})
	client.invalid_once = true
	pages.desired_index = 20
	await pages._fetch(1)
	check(not pages.error.is_empty() and pages.entry_at(0).track_id == "fixture-track-0","invalid next page preserves usable loaded page")
	await cloud.query_discovery({"sort":"name"},[],[],true)
	check(client.requests[-1].get("fresh",false) and int(client.requests[-1].offset) == 0,"Refresh starts a new first page")
	cloud._write(cloud.cache_root().path_join(client.hash_value+".json"),client.document)
	var library := TrackLibrary.new(folder.path_join("drafts"))
	var catalog := TrackCatalog.new(library)
	cloud.add_to_catalog(catalog)
	var entry: Dictionary = cloud.entry_from_metadata(client.metadata(0,0))
	check(await cloud.download(entry),"selected fixture uses normal retained publication metadata")
	var native_track: NativeTrack = cloud.compile_entry(entry)
	check(native_track != null,"fixture selected track compiles through normal cache validation")
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
	var first_id: String = str(browser.grid.get_child(0).entry.id)
	pages.desired_index = 20
	await pages._fetch(1)
	await settle(pages)
	check(browser.grid.get_child_count() <= 12 and str(browser.grid.get_child(0).entry.id) == first_id,"appending server page keeps first visible card stable and bounds controls")
	check(browser.grid.get_children().all(func(node: Node) -> bool: return node.size.y <= 140.0),"paged card footers remain inside the carousel height")
	check(browser.gallery_content.custom_minimum_size.x >= 5000*browser.tile_stride-12,"virtual scrollbar covers full global results")
	await capture("default-discovery")
	browser.gallery.scroll_horizontal = 4250*browser.tile_stride
	browser._render_tiles(true)
	await settle(pages)
	check(browser.grid.get_child_count() <= 12 and browser.grid.get_children().all(func(node: Node) -> bool: return node is TrackTile),"deep scrolling loads every visible card across page boundary")
	check(not browser.race_button.disabled,"evicting selected track's preview does not disable its cached race")
	await capture("deep-discovery")
	browser.search_dialog.open_for(browser.state,browser.find_child("RaceSearch",true,false))
	browser.search_dialog.edit.text = "4999"
	browser.search_dialog.edit.text_changed.emit("4999")
	await create_timer(0.35).timeout
	for _frame: int in range(5): await process_frame
	check(browser.search_dialog.matches.size() == 1 and browser.search_dialog.matches[0].track_id == "fixture-track-4999","search drawer performs debounced global lookup")
	check(pages.total == 5000,"live search preview leaves active carousel query unchanged")
	await capture("global-search")
	browser.search_dialog._apply()
	await settle(pages)
	check(pages.total == 1 and browser.matches[0].track_id == "fixture-track-4999","applying search switches carousel to complete global result set")
	browser.filter_dialog.open_for(browser.state,browser.filter_button)
	check(browser.filter_dialog.find_child("Choice_feed_new",true,false) != null and browser.filter_dialog.find_child("Choice_feed_popular",true,false) != null,"feed controls expose New and Popular")
	await capture("discovery-filters")
	browser.filter_dialog.close()
	root.size = Vector2i(960,540)
	browser.size = root.get_visible_rect().size
	for _frame: int in range(5): await process_frame
	await capture("compact-discovery")
	browser.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	await process_frame
	print("DISCOVERY_PAGE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
