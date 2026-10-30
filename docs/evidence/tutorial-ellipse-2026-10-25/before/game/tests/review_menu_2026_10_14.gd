extends SceneTree
## Read-only production-code audit probes. Network and saves are isolated.
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}
var output: String
var folder: String

class ProbeApp extends "res://core/app.gd":
	var preparation_ms: Array[float] = []
	func _prepare_menu_neighbors_frame(generation: int) -> void:
		var began: int = Time.get_ticks_usec()
		super._prepare_menu_neighbors_frame(generation)
		preparation_ms.append((Time.get_ticks_usec()-began)/1000.0)

class StoreService extends "res://backend/backend_client.gd":
	var paths: Array[String] = []
	func signed_in() -> bool: return true
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		paths.append(path)
		return {"ok":true,"data":{"products":[]},"error":""}

class DelayedService extends Node:
	signal release
	var player: Dictionary = {"id":"audit-fixture"}
	var paths: Array[String] = []
	func base_url() -> String: return "http://audit.invalid"
	func signed_in() -> bool: return true
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		paths.append(path)
		await release
		return {"ok":true,"data":{"items":[],"next_cursor":""},"error":""}

class Browser extends TrackBrowser:
	func _load_catalog() -> void: loading = false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 6) -> void:
	for _index: int in range(count): await process_frame

func count_type(node: Node, type_name: String) -> int:
	var result: int = 1 if node.is_class(type_name) else 0
	for child: Node in node.get_children(): result += count_type(child,type_name)
	return result

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_MENU_REVIEW_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../docs/evidence/menu-review-2026-10-14/probe.json")
	folder = "user://menu_review_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	var app := ProbeApp.new()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var old_client: Node = app.online.client
	var store := StoreService.new()
	app.add_child(store)
	app.online.client = store
	app.race_area_mode = "free"
	app._show_screen("tracks")
	await frames()
	var hidden_store: Control = app.menu_neighbors[3].body.find_child("StorePage",true,false)
	report.passive_store = {"paths":store.paths.duplicate(),"store_visible":hidden_store.is_visible_in_tree(),"screen":app.screen,"prepared_pages":app.menu_neighbors.size(),"nodes":count_type(app.root_ui,"Node"),"subviewports":count_type(app.root_ui,"SubViewport"),"mesh_nodes":count_type(app.root_ui,"MeshInstance3D")}
	check(store.paths.count("/store/products") == 1 and store.paths.count("/me/entitlements") == 1 and not hidden_store.is_visible_in_tree(),"offscreen store performs both reads")
	for _index: int in range(2):
		app._show_screen("settings")
		await frames(3)
		app._show_screen("tracks")
		await create_timer(0.45).timeout
		await frames()
	report.passive_store.paths_after_two_settings_roundtrips = store.paths.duplicate()
	report.neighbor_preparation_ms = app.preparation_ms.duplicate()
	check(store.paths.count("/store/products") == 3,"settings round trips repeat passive Store reads")
	app.online.client = old_client
	app._navigate_menu_page("garage")
	await create_timer(0.45).timeout
	await frames()
	var garage: GaragePage = app.content.find_child("GaragePage",true,false)
	await probe_washing(garage)
	app.rivalry.model = WeeklyRivalry.new(true)
	app._show_screen("rivalry")
	await create_timer(0.45).timeout
	await frames()
	var original: Node = app.content.find_child("WeeklyRivalryPage",true,false)
	var original_id: int = original.get_instance_id()
	var began: int = Time.get_ticks_usec()
	app.rivalry.changed.emit()
	var new_page: Node = app.content.find_child("WeeklyRivalryPage",true,false)
	report.rivalry_unchanged_signal = {"dispatch_ms":(Time.get_ticks_usec()-began)/1000.0,"replaced_page":new_page.get_instance_id()!=original_id,"old_page_queued":original.is_queued_for_deletion()}
	check(report.rivalry_unchanged_signal.replaced_page,"unchanged rivalry signal replaces the whole page")
	var delayed := DelayedService.new()
	app.add_child(delayed)
	app.challenges.client = delayed
	app.challenges.reset()
	app._show_screen("challenges")
	app.challenges.refresh()
	var challenge_page: ChallengesPage = app.content.find_child("ChallengesPage",true,false)
	var sent: Button = challenge_page.find_child("ChallengeTab_sent",true,false)
	check(not sent.disabled and app.challenges.busy,"folder remains clickable while refresh is in flight")
	sent.pressed.emit()
	delayed.release.emit()
	await frames()
	challenge_page = app.content.find_child("ChallengesPage",true,false)
	report.challenge_folder_race = {"paths":delayed.paths,"client_folder":app.challenges.folder,"client_busy":app.challenges.busy,"page_folder":challenge_page.folder,"page_busy":challenge_page.busy}
	check(delayed.paths.size()==1 and app.challenges.folder=="sent" and not app.challenges.busy and challenge_page.folder=="received" and challenge_page.busy,"folder switch is dropped and rendered busy state is never cleared")
	app.queue_free()
	await frames(2)
	await probe_worker_departure()
	probe_cache()
	report.checks = checks
	report.failures = failures
	report.renderer = RenderingServer.get_current_rendering_method()
	report.display = DisplayServer.get_name()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MENU_REVIEW ",JSON.stringify(report))
	quit(1 if failures else 0)

func probe_washing(garage: GaragePage) -> void:
	garage._show_section("care")
	await create_timer(0.4).timeout
	await frames()
	var view: CarShowroom = garage.showroom
	view.set_process(false)
	view.elevation = 0.93
	view._orbit()
	var pixel: Vector2 = view.camera.unproject_position(view.car.to_global(Vector3(0,0.9,-1.2)*HandlingConfig.BODY_SCALE))
	var point: Vector2 = pixel*view.size/Vector2(view.showroom_viewport.size)
	var began: int = Time.get_ticks_usec()
	var hit: Variant = view.pick_body_point(point)
	var cold_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var samples: Array[float] = []
	for _index: int in range(12):
		began = Time.get_ticks_usec()
		view.pick_body_point(point)
		samples.append((Time.get_ticks_usec()-began)/1000.0)
	var vertices: int = 0
	for entry: Dictionary in view.pick_meshes: vertices += entry.faces.size()
	view.set_wash_mode(true)
	view.washing = true
	view.wash_previous = point-Vector2(384,0)
	view.wash_pointer = point
	began = Time.get_ticks_usec()
	view._process(1.0/60.0)
	var fast_ms: float = (Time.get_ticks_usec()-began)/1000.0
	view.wash_previous = point
	began = Time.get_ticks_usec()
	view._process(1.0/60.0)
	var stationary_ms: float = (Time.get_ticks_usec()-began)/1000.0
	view.washing = false
	report.washing = {"hit":hit!=null,"cold_pick_ms":cold_ms,"warm_pick_ms":samples,"cached_meshes":view.pick_meshes.size(),"cached_triangle_vertices":vertices,"uncompressed_face_bytes":vertices*12,"fast_32_step_process_ms":fast_ms,"stationary_process_ms":stationary_ms}
	check(hit!=null and vertices>0,"washing probe hits the actual native compact")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var draws: Array[int] = [view.showroom_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)]
		for reflection: SubViewport in view.reflections.views: draws.append(reflection.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		report.garage_idle_draw_calls = draws
	view.set_process(true)

func probe_worker_departure() -> void:
	var source: Dictionary = TrackDocument.create_default()
	source.id = "review_local_track"
	source.name = "Review local track"
	source.pieces = [RoadPieces.create("curve",Vector2(-10,-8)),RoadPieces.create("straight",Vector2(6,8),90)]
	var library := TrackLibrary.new(folder.path_join("local"))
	check(library.save_document(source)==OK,"isolated local track saved")
	var browser := Browser.new()
	browser.library = library
	browser.records = LocalRecords.new(folder.path_join("unused.json"))
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	browser.state = {"section":"all","page":0}
	root.add_child(browser)
	await frames(2)
	var entry: Dictionary = TrackCatalog.local_metadata(source)
	browser._select(entry)
	var running: bool = browser._resolve_thread!=null
	var began: int = Time.get_ticks_usec()
	root.remove_child(browser)
	report.browser_departure = {"worker_pending":running,"remove_child_ms":(Time.get_ticks_usec()-began)/1000.0}
	check(running,"real local compilation was pending at departure")
	browser.queue_free()
	await frames(2)

func probe_cache() -> void:
	var provider := TrackDiscoveryProvider.new()
	var cache = preload("res://backend/menu_snapshot_cache.gd").new()
	cache.configure(folder.path_join("cache.json"),"audit")
	var raw: Array = []
	for index: int in range(16): raw.append({"from_ticks":index*100,"to_ticks_exclusive":(index+1)*100,"count":index+1})
	var value: Dictionary = {"race":{"bins":raw},"best_lap":{"bins":raw},"friends":[]}
	for index: int in range(20): value.friends.append({"player":"Audit fixture %d"%index,"race_ms":100000+index})
	var samples: Array[float] = []
	for index: int in range(40):
		provider.remember_record("rules-%d"%index,value)
		var began: int = Time.get_ticks_usec()
		cache.remember("entry-%d"%index,value)
		samples.append((Time.get_ticks_usec()-began)/1000.0)
	report.cache = {"ram_records_after_40":provider.records_by_rules_key.size(),"disk_entries_after_40":cache.entries.size(),"whole_file_bytes":FileAccess.get_file_as_bytes(cache.path).size(),"remember_ms":samples,"writes":samples.size()}
	check(provider.records_by_rules_key.size()==40 and cache.entries.size()==32,"RAM read-model grows beyond the disk limit")
