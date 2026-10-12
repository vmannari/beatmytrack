extends "res://tests/test_startup_histogram.gd"
const Preloader = preload("res://backend/comparison_preloader.gd")
const Paging = preload("res://tests/test_discovery_pages.gd")
const RealCloud = preload("res://backend/cloud_tracks.gd")
var foreground_value: Dictionary = {}
var foreground_ready: bool = false

class WindowService extends StartupService:
	var held_versions: Array[String] = []
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		var version: String = path.get_slice("/",2)
		while version in held_versions: await get_tree().process_frame
		await get_tree().process_frame
		return {"ok":true,"data":packet.duplicate(true),"error":""}

class MetadataCloud extends StartupCloud:
	signal release_download
	var downloads: int = 0
	var last_error: String = "Held metadata fixture"
	var ready_versions: Array[String] = []
	func load_more() -> void: pass
	func download(entry: Dictionary) -> bool:
		downloads += 1
		await release_download
		return str(entry.get("version_id","")) in ready_versions

class FarPagedClient extends Paging.PagedClient:
	var comparison_paths: Array[String] = []
	var packet: Dictionary = {}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		comparison_paths.append(path)
		await get_tree().process_frame
		return {"ok":true,"status":200,"data":packet.duplicate(true),"error":""}
	func request_public(_path: String, _owner: int) -> Dictionary:
		await get_tree().process_frame
		return {"ok":true,"data":{"items":[]},"error":""}

func foreground(preloader: RefCounted, version: String) -> void:
	foreground_value = await preloader.fetch(version,"compact")
	foreground_ready = true

func fetch_into(preloader: RefCounted, version: String, reply: Dictionary) -> void:
	reply.value = await preloader.fetch(version,"compact")
	reply.ready = true

func wait_frames(count: int = 8) -> void:
	for frame: int in range(count): await process_frame

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../build/carousel-histograms/fixture-"+TrackLibrary.unique_id())
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/carousel-histograms-2026-10-10")
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json")).packet
	var service := WindowService.new()
	service.packet = packet
	service.hold_board = false
	service.held_versions = ["window-version-0","window-version-1"]
	root.add_child(service)
	var preloader := Preloader.new()
	preloader.configure(service,"","window/account")
	var first: Array = []
	var distant: Array = []
	for index: int in range(6):
		first.append({"version_id":"window-version-%d" % index})
		distant.append({"version_id":"window-version-%d" % (40+index)})
	preloader.prime(first,"compact")
	check(preloader._active == 2,"two initial background comparisons are held")
	preloader.prime(distant,"compact")
	check(preloader._queue.size() == 6 and preloader._queue.all(func(job: Dictionary) -> bool: return job.version in distant.map(func(entry: Dictionary) -> String: return entry.version_id)),"far window replaces old queued speculation instead of dropping new tracks")
	var start: int = Time.get_ticks_usec()
	foreground(preloader,"window-version-45")
	await wait_frames()
	check(foreground_ready and foreground_value.has("packet"),"selected distant histogram completes while old background requests stay held")
	check(preloader._active == 2 and preloader._foreground_active == 0,"foreground completion preserves ownership of held background slots")
	print("CAROUSEL_PRIORITY distant_ready_ms=",(Time.get_ticks_usec()-start)/1000.0," old_background_held=",service.held_versions.size())
	service.held_versions.clear()
	await wait_frames(12)
	service.held_versions = ["blocked-foreground"]
	var older: Dictionary = {"ready":false}
	var newer: Dictionary = {"ready":false}
	fetch_into(preloader,"blocked-foreground",older)
	fetch_into(preloader,"newer-selected",newer)
	await wait_frames()
	check(newer.ready and not older.ready,"a newer selection uses free capacity while an older foreground reply is held")
	service.held_versions.clear()
	await wait_frames()
	var doc: Dictionary = TrackDocument.create_default()
	var track: NativeTrack = TrackCompiler.compile(doc)
	track.metadata.cloud_version = "window-version-0"
	track.metadata.title = "Window 00"
	var cloud := MetadataCloud.new()
	cloud.client = service
	for index: int in range(50): cloud.entries.append({"id":"window-track-%d" % index,"source":"cloud","version_id":"window-version-%d" % index,"name":"Window %02d" % index,"creator":"Beat my track","theme":"pine","points":doc.points})
	var ready_doc: Dictionary = doc.duplicate(true)
	ready_doc.id = "window_ready_42"
	ready_doc.name = "Window 42"
	var body: String = JSON.stringify(ready_doc)
	var path: String = folder.path_join("window-42.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(body);file.close()
	cloud.entries[42].cache_path = path
	cloud.entries[42].content_hash = body.sha256_text()
	cloud.entries[42].track_id = "window-track-42"
	cloud.ready_versions = ["window-version-42"]
	cloud.entries[0].id = track.identity
	root.add_child(cloud)
	var browser := TrackBrowser.new()
	browser.library = TrackLibrary.new(folder.path_join("tracks"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.catalog.indexed_revision = browser.library.revision
	browser.catalog.entries.assign(cloud.entries)
	browser.selected_track = track
	browser.cloud = cloud
	browser.state = {"sort":"name"}
	root.add_child(browser)
	MenuStyle.fill(browser)
	browser.offset_top = 112
	browser.offset_bottom = -16
	await wait_frames()
	service.paths.clear()
	browser.gallery.scroll_horizontal = int(browser.tile_stride*40)
	browser._render_tiles(true)
	await wait_frames(16)
	check(service.paths.any(func(path: String) -> bool: return path.contains("window-version-40") and path.contains("results-comparison")),"scrolling a far card into view warms its histogram before clicking")
	var before: int = service.paths.size()
	for frame: int in range(12): browser._render_tiles(); await process_frame
	check(service.paths.size() == before,"same visible window does not poll or restart its preload")
	browser._select(cloud.entries[42])
	await wait_frames()
	check(cloud.downloads == 0 and not browser.selecting and browser.selected_track.metadata.get("metadata_only",false) and browser.selected_track.cells.is_empty() and browser._resolve_thread == null,"selecting a cloud card performs no document download or geometry compilation")
	var chart: TrackDistribution = browser.find_child("RaceDistribution",true,false)
	check(chart != null and chart.is_visible_in_tree() and chart.snapshot.bins.size() == 16 and browser._detail_state[1] == "preview:window-version-42","distant histogram displays before document download or geometry compilation")
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == "WINDOW 42","metadata histogram belongs to the newly selected hero")
	check(not browser.race_button.disabled and browser.race_button.text == "RACE WINDOW 42" and browser.selected_track.identity == "window-track-42","Race targets the selected metadata identity for pinned preparation")
	check(not texts(browser).contains("Loading..."),"normal far-track browsing has no loading caption")
	await create_timer(0.45).timeout # Capture the completed section transition while download stays held.
	await capture("far-track-before-geometry")
	cloud.release_download.emit()
	for frame: int in range(180):
		await process_frame
		if not browser.selecting: break
	check(not browser.selecting and browser.selected_track.metadata.cloud_version == "window-version-42" and not browser.race_button.disabled,"metadata Race action remains available without preparing geometry")
	check(browser.find_child("RaceDistribution",true,false).visible,"metadata comparison survives the handoff to compiled geometry")
	browser._select(cloud.entries[45])
	await wait_frames()
	browser._select(cloud.entries[46])
	await wait_frames()
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == "WINDOW 46" and not browser.race_button.disabled and browser.selected_track.identity == "window-track-46" and cloud.downloads == 0,"rapid far selections remain metadata only and retain the latest Race target")
	cloud.release_download.emit()
	await wait_frames()
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == "WINDOW 46","late earlier document replies cannot restore the previous hero")
	browser.queue_free();cloud.queue_free();service.queue_free()
	await process_frame
	await paged_window(packet)
	print("CAROUSEL_HISTOGRAMS checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func paged_window(packet: Dictionary) -> void:
	var client := FarPagedClient.new()
	client.packet = packet
	client.document = TrackDocument.create_default()
	client.hash_value = JSON.stringify(client.document).sha256_text()
	root.add_child(client)
	client.configure("http://127.0.0.1:18181")
	client._access_token = "fictional-access"
	client.player = {"id":"fictional-player"}
	client._capabilities = {"discovery_paging_version":2}
	var cloud := RealCloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("paged-cloud")
	root.add_child(cloud)
	await cloud.query_discovery({"sort":"name"})
	var initial: NativeTrack = TrackCompiler.compile(client.document)
	initial.identity = "cloud_fixture-track-0"
	initial.metadata.cloud_version = cloud.discovery_pages.entry_at(0).version_id
	var browser := TrackBrowser.new()
	browser.library = TrackLibrary.new(folder.path_join("paged-tracks"))
	browser.records = LocalRecords.new(folder.path_join("paged-records.json"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.selected_track = initial
	browser.cloud = cloud
	browser.state = {"sort":"name"}
	root.add_child(browser)
	MenuStyle.fill(browser)
	await wait_frames(12)
	client.comparison_paths.clear()
	browser.gallery.scroll_horizontal = int(browser.tile_stride*40)
	browser._render_tiles(true)
	await wait_frames(40)
	var entry: Dictionary = cloud.discovery_pages.entry_at(40)
	check(not entry.is_empty(),"distant page metadata arrives at its actual carousel index")
	check(client.comparison_paths.any(func(path: String) -> bool: return path.contains(str(entry.get("version_id","missing"))) and path.contains("results-comparison")),"real paged carousel warms farther histograms when page metadata arrives")
	check(cloud.discovery_pages.pages.size() <= 15 and cloud.entries.size() <= 300,"comparison warming does not drain the 5000-track catalog")
	var before: int = client.comparison_paths.size()
	for repeat: int in range(12): browser._render_tiles(); await process_frame
	check(client.comparison_paths.size() == before,"stationary paged viewport does not re-request comparisons")
	browser.queue_free();cloud.queue_free()
	await wait_frames()
	client.queue_free()
	await process_frame
