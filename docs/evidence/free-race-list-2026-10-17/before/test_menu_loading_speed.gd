extends SceneTree
## Delayed menu reads, app-restart caches and account/population fences.
const RivalryClient = preload("res://backend/weekly_rivalry_client.gd")
const CacheIO = preload("res://backend/atomic_json.gd")
var checks: int = 0
var failures: int = 0
var folder: String
var evidence: String

class Browser extends TrackBrowser:
	func _load_catalog() -> void:
		loading = false
		_show_detail()

class Service extends Node:
	var player: Dictionary = {"id":"you"}
	var packet: Dictionary = {}
	var membership: Dictionary = {}
	var paths: Array[String] = []
	var hold_board: bool = true
	var hold_comparison: bool = true
	var hold_rivalry: bool = true
	var development: bool = false
	var origin: String = "http://menu-speed-fixture"
	func base_url() -> String: return origin
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return development
	func cancel_public_reads(_owner: int) -> void: pass
	func new_operation_key() -> String: return "fixture-key"
	func request_public(path: String, _owner: int) -> Dictionary:
		paths.append(path)
		while hold_board: await get_tree().process_frame
		return {"ok":true,"data":{"items":[{"rank":1,"display_name":"Fixture leader","time_ticks":10000}]},"error":""}
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		if path.contains("results-comparison"):
			while hold_comparison: await get_tree().process_frame
			return {"ok":true,"data":packet,"error":""}
		while hold_rivalry: await get_tree().process_frame
		return {"ok":true,"data":membership,"error":""}

class Cloud extends Node:
	signal changed
	var client: Node
	var entries: Array[Dictionary] = []
	var status: String = ""
	var refreshing: bool = false
	var discovery_pages: Node
	func paged_discovery_available() -> bool: return false

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for _frame: int in range(6): await process_frame
func texts(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child: Node in node.get_children(): result += "\n"+texts(child)
	return result
func capture(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"capture "+label)

func membership() -> Dictionary:
	var sample := WeeklyRivalry.new(true)
	var now: int = int(Time.get_unix_time_from_system())
	var value: Dictionary = {"state":"active","group_id":"fixture-group","self_id":"you","week":41,"vehicle_id":"compact",
		"server_now":now,"ends_at":now+3600,"test_population":false,"standings":sample.standing(),"tracks":[]}
	for slot: int in range(5):
		var track: Dictionary = sample.tracks[slot]
		value.tracks.append({"board_id":"board_"+str(slot),"entries":sample.board(slot),
			"entry":{"name":track.name,"theme":track.theme,"creator":"Beat my track","track_id":"track_"+str(slot),
				"version_id":"version_"+str(slot),"content_hash":"a".repeat(64),"points":track.document.points}})
	return value

func adapter(service: Service) -> Node:
	var value := RivalryClient.new()
	value.client = service
	value.cache_directory = folder.path_join("rivalry")
	root.add_child(value)
	return value

func run() -> void:
	folder = "user://menu_speed_"+TrackLibrary.unique_id()
	evidence = OS.get_environment("BMT_MENU_SPEED_EVIDENCE")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	VehicleCatalog.selected = "compact"
	var service := Service.new()
	service.packet = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/histogram-grid-2026-10-09/verified-silmukka-histograms.json")).packet
	service.membership = membership()
	root.add_child(service)
	var cloud := Cloud.new()
	cloud.client = service
	root.add_child(cloud)
	var document: Dictionary = TrackDocument.create_default()
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "menu-speed-fixture"
	track.metadata.title = "Immediate hero"
	var browser := Browser.new()
	browser.name = "SpeedBrowser"
	browser.theme = MenuStyle.theme()
	browser.library = TrackLibrary.new(folder.path_join("tracks"))
	browser.catalog = TrackCatalog.new(browser.library)
	browser.catalog.entries.append({"id":track.identity,"source":"cloud","version_id":track.metadata.cloud_version,"name":"Immediate hero","creator":"Beat my track","theme":"pine","points":document.points})
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.records.records[browser.records.key_for(track,HandlingSelection.config())] = {"race_ms":86130,"flying_ms":15881}
	browser.discovery.configure_cache(folder.path_join("discovery.json"),"fixture/account-a")
	browser.selected_track = track
	browser.cloud = cloud
	browser.state = {}
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var began: int = Time.get_ticks_usec()
	root.add_child(browser)
	var hero_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(browser.hero.find_child("HeroTrackTitle",true,false) != null,"first menu frame draws the hero with both network reads held")
	check(not browser.race_button.disabled,"optional data never holds an available track's race action")
	check(not texts(browser).contains("No times yet"),"unknown records never masquerade as empty data")
	MenuStyle.fill(browser)
	browser.offset_top = 112
	browser.offset_bottom = -16
	# Startup itself must hydrate the restored selection, without a tile event.
	check(service.paths.size() == 2,"leaderboard and histogram requests start in parallel")
	check(service.paths.any(func(path: String) -> bool: return path.contains("results-comparison")),"held leaderboard never postpones histogram request")
	await settle()
	await capture("free-race-first-frame")
	service.hold_comparison = false
	await settle()
	var key: String = browser.records.key_for(track,HandlingSelection.config())
	check(browser._comparison_ready(browser.discovery.record_snapshot(key)),"histograms finish while the unrelated leaderboard remains held")
	check((browser.find_child("RaceDistribution",true,false) as TrackDistribution).visible,"ready histogram appears immediately")
	check(not texts(browser).contains("Loading...") and not browser.discovery.record_snapshot(key).has("friends"),"ordinary pending scores stay quiet without inventing a completed field")
	await capture("histogram-before-leaderboard")
	service.hold_board = false
	await settle()
	check(texts(browser).contains("Fixture leader"),"independent leaderboard read merges without losing histograms")
	check(browser._comparison_ready(browser.discovery.record_snapshot(key)),"score list never overwrites a completed comparison")
	var reopened := TrackDiscoveryProvider.new()
	began = Time.get_ticks_usec()
	reopened.configure_cache(folder.path_join("discovery.json"),"fixture/account-a")
	var restored: Dictionary = reopened.record_snapshot(key)
	var histogram_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(browser._comparison_ready(restored),"a fresh app provider restores both histograms from disk")
	check(restored.race_distribution.bins == browser.discovery.record_snapshot(key).race_distribution.bins,"restart preserves every real server count")
	check(not restored.race_distribution.markers[0].has("color"),"cached player marker has a safe default color after JSON round trip")
	reopened.configure_cache(folder.path_join("discovery.json"),"fixture/account-b")
	check(reopened.record_snapshot(key).is_empty(),"another account never sees cached own times or distributions")
	check(reopened.record_snapshot("different-pinned-rules").is_empty(),"pinned rules remain part of the distribution identity")
	browser.queue_free()
	await process_frame
	var first: Node = adapter(service)
	first.refresh(false)
	check(first.busy and first.model.tracks.is_empty(),"genuinely cold membership stays unresolved until server confirms it")
	service.hold_rivalry = false
	await settle()
	check(first.has_snapshot() and first.model.tracks.size() == 5,"confirmed membership is persisted")
	var prior_requests: int = service.paths.size()
	first.refresh(false)
	first.refresh(false)
	check(service.paths.size() == prior_requests,"repeat menu entry coalesces fresh membership reads")
	first.queue_free()
	await process_frame
	service.hold_rivalry = true
	var restarted: Node = adapter(service)
	began = Time.get_ticks_usec()
	restarted.refresh(false)
	var rivalry_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(restarted.has_snapshot() and restarted.model.tracks.size() == 5 and restarted.busy,"restart has a populated rivalry before background refresh finishes")
	check(restarted.cached_snapshot,"restored membership is explicitly presentation-only")
	prior_requests = service.paths.size()
	check((await restarted.ticket(0)).is_empty() and service.paths.size() == prior_requests,"cached membership cannot issue a race ticket")
	var page := WeeklyRivalryPage.new()
	page.theme = MenuStyle.theme()
	page.model = restarted.model
	page.signed_in = true
	page.busy = true
	root.add_child(page)
	MenuStyle.fill(page)
	check(page.find_child("RivalryTracksPanel",true,false) != null and page.find_child("RivalryLoading",true,false) == null,"first cached rivalry frame contains its five tracks and standings")
	await settle()
	await capture("rivalry-restored-before-network")
	page.queue_free()
	service.hold_rivalry = false
	await settle()
	check(not restarted.cached_snapshot and not restarted.busy,"fresh server response releases cached membership gates")
	var saved_path: String = restarted.snapshot_cache.path
	var saved_scope: String = restarted.snapshot_cache.scope
	restarted.queue_free()
	await process_frame
	service.hold_rivalry = true
	service.player.id = "different-account"
	var different: Node = adapter(service)
	different.refresh(false)
	check(different.model.tracks.is_empty() and not different.cached_snapshot,"account switch fences the cached championship")
	service.hold_rivalry = false
	await settle()
	different.queue_free()
	await process_frame
	service.player.id = "you"
	service.development = true
	service.hold_rivalry = true
	var development: Node = adapter(service)
	development.refresh(false)
	check(development.model.tracks.is_empty() and not development.cached_snapshot,"artificial and public membership caches remain separate")
	service.hold_rivalry = false
	await settle()
	development.queue_free()
	await process_frame
	service.development = false
	var expired: Dictionary = service.membership.duplicate(true)
	expired.ends_at = expired.server_now
	CacheIO.write(saved_path,{"schema":"menu-snapshots-v1","scope":saved_scope,"entries":{"current":{"saved_at":int(Time.get_unix_time_from_system()),"data":{"snapshot":expired,"received_at":int(Time.get_unix_time_from_system())}}}})
	var ended: Node = adapter(service)
	ended._restore_snapshot()
	check(ended.model.tracks.is_empty(),"previous week's active membership is never revived from disk")
	ended.queue_free()
	await process_frame
	CacheIO.write(saved_path,{"schema":"wrong-schema","scope":saved_scope,"entries":{}})
	var broken: Node = adapter(service)
	broken._restore_snapshot()
	check(broken.model.tracks.is_empty(),"incompatible cache fails open to normal server loading")
	broken.queue_free()
	cloud.queue_free()
	service.queue_free()
	await process_frame
	var report: Dictionary = {"hero_ready_ms":hero_ms,"histogram_disk_restore_ms":histogram_ms,"rivalry_disk_restore_ms":rivalry_ms,"checks":checks,"failures":failures,"real_network":false}
	print("MENU_SPEED_TIMING "+JSON.stringify(report))
	if not evidence.is_empty(): CacheIO.write(evidence.path_join("client-timing.json"),report)
	print("MENU_LOADING_SPEED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
