extends SceneTree
## Real resolver lifetimes, exact wash coverage, scoped IO/network and native draws.
const Cache = preload("res://backend/menu_snapshot_cache.gd")
const Writer = preload("res://backend/menu_snapshot_writer.gd")
const Work = preload("res://editor/work_job.gd")
const Store = preload("res://ui/store_page.gd")
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}
var output: String
var folder: String

class ReferenceWeathering extends "res://tests/fixtures/menu_medium_weathering_before.gd":
	var mask_uploads: int = 0
	func wash(point: Vector3, seconds: float) -> void:
		var before: Image = wash_image
		super.wash(point,seconds)
		if wash_image!=before: mask_uploads += 2

class Service extends Node:
	var player: Dictionary = {"id":"medium-a"}
	var paths: Array[String] = []
	var held: bool = false
	func base_url() -> String: return "http://menu-medium.invalid/"+str(get_instance_id())
	func signed_in() -> bool: return true
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while held: await get_tree().process_frame
		await get_tree().process_frame
		if path=="/store/products": return {"ok":true,"data":{"products":[{"id":"creator_slot_1","title":"One slot","price_eur":"1.00","enabled":true}]}}
		return {"ok":true,"data":{"publishing_slots":2,"ad_free_until":0,"max_rewinds_per_race":3,"server_now":1,"ad_free":false,"ad_free_forever":false,"free_rewinds":false,"purchase_simulation":false,"store_available":true}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 4) -> void:
	for _index: int in range(count):
		await process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func drain_writer() -> void:
	var limit: int = Time.get_ticks_msec()+10000
	while not Writer.idle() and Time.get_ticks_msec()<limit: await process_frame
	check(Writer.idle(),"ordered snapshot writer completes without a UI join")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	folder = "user://menu_medium_"+TrackLibrary.unique_id()
	output = OS.get_environment("BMT_MENU_MEDIUM_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../docs/evidence/menu-medium-fixes-2026-10-15/headless")
	DirAccess.make_dir_recursive_absolute(output)
	await test_caches()
	await test_store()
	await test_worker()
	await test_washing()
	await test_app_and_rendering()
	await drain_writer()
	report.merge({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method()})
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MENU_MEDIUM ",JSON.stringify(report))
	quit(1 if failures else 0)

func test_caches() -> void:
	var cache = Cache.new()
	cache.configure(folder.path_join("snapshots.json"),"scope-a")
	var writer: Node = Writer.shared()
	var before: int = writer.completed_writes
	var began: int = Time.get_ticks_usec()
	for index: int in range(40): cache.remember("key-%d"%index,{"value":index,"bins":range(16)})
	var queued_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(writer.completed_writes==before and writer.pending.size()==1,"forty synchronous updates queue one snapshot and perform no synchronous disk writes")
	check(cache.entries.size()==32 and cache.read("key-39").value==39,"RAM is immediate and retains the original persistent entry bound")
	var replacement = Cache.new()
	replacement.configure(cache.path,cache.scope)
	check(replacement.read("key-39").value==39,"another cache can hydrate the latest queued snapshot before disk completion")
	await drain_writer()
	check(writer.completed_writes==before+1,"forty updates coalesce into one atomic background write")
	var saved: Dictionary = Cache.IO.read(cache.path)
	check(saved.scope=="scope-a" and saved.entries.size()==32 and saved.entries["key-39"].data.value==39,"background disk snapshot contains the last complete ordered value")
	before = writer.completed_writes
	for _index: int in range(20): cache.remember("key-39",{"value":39,"bins":range(16)})
	cache.forget("not-present")
	await drain_writer()
	check(writer.completed_writes==before,"unchanged values and absent removals do not rewrite disk")
	cache.entries["key-39"].saved_at = int(Time.get_unix_time_from_system())-2
	cache.remember("key-39",{"value":39,"bins":range(16)})
	check(cache.entries["key-39"].saved_at==int(Time.get_unix_time_from_system()) and writer.pending.is_empty(),"identical replies refresh RAM age across seconds without a disk write")
	cache._last_write_requested -= 61
	cache.entries["key-39"].saved_at -= 2
	cache.remember("key-39",{"value":39,"bins":range(16)})
	await drain_writer()
	check(writer.completed_writes==before+1,"identical replies checkpoint their timestamp within one minute")
	cache.remember("old",{"value":1})
	cache.configure(cache.path,"scope-b")
	cache.remember("new",{"value":2})
	await drain_writer()
	saved = Cache.IO.read(cache.path)
	check(saved.scope=="scope-b" and saved.entries.has("new") and not saved.entries.has("old"),"same-path account replacement cannot be overwritten by a queued old scope")
	var provider := TrackDiscoveryProvider.new()
	provider.pin_record("selected")
	provider.remember_record("selected",{"value":-1})
	for index: int in range(40): provider.remember_record(str(index),{"value":index})
	check(provider.records_by_rules_key.size()==provider.MAX_RECORDS and provider.record_snapshot("selected").value==-1,"RAM record LRU stays bounded while retaining the selected record")
	check(provider.record_snapshot("0").is_empty() and provider.record_snapshot("39").value==39,"record LRU evicts old entries and keeps recent values")
	provider.remember_record("large-a",{"data":"x".repeat(1100000)})
	provider.remember_record("large-b",{"data":"y".repeat(1100000)})
	check(provider._record_bytes<=provider.MAX_RECORD_BYTES and provider.record_snapshot("selected").value==-1,"RAM record byte budget is enforced alongside the selected pin")
	provider.remember_record("oversized",{"data":"z".repeat(provider.MAX_RECORD_BYTES+1)})
	check(not provider.records_by_rules_key.has("oversized"),"a single oversized record cannot bypass the RAM byte budget")
	provider.configure_cache(folder.path_join("records.json"),"first")
	provider.configure_cache(folder.path_join("records-b.json"),"second")
	check(provider.records_by_rules_key.is_empty() and provider._record_bytes==0,"scope replacement clears record values and byte accounting")
	report.caches = {"forty_enqueue_ms":queued_ms,"coalesced_writes":1,"max_entries":provider.MAX_RECORDS,"max_bytes":provider.MAX_RECORD_BYTES}

func test_store() -> void:
	var service := Service.new()
	root.add_child(service)
	var a: Node = Store.new()
	var b: Node = Store.new()
	for page: Node in [a,b]:
		page.client = service
		page.page_preview = true
		root.add_child(page)
	await frames()
	check(service.paths.is_empty(),"passive Store neighbors make no service calls")
	service.held = true
	a.activate()
	b.activate()
	check(service.paths==["/store/products"],"two simultaneous openings coalesce their product request")
	service.held = false
	while a.working or b.working: await process_frame
	check(service.paths==["/store/products","/me/entitlements"] and a.products.size()==1 and b.products.size()==1,"open Stores share one scoped products/access refresh")
	var card: Node = a.grid.get_child(0)
	a.activate()
	check(service.paths.size()==2 and a.grid.get_child(0)==card,"fresh Store reactivation retains controls and skips redundant requests")
	var cached: Node = Store.new()
	cached.client = service
	cached.page_preview = true
	root.add_child(cached)
	check(cached.products.size()==1 and service.paths.size()==2,"rebuilt passive Store previews display scoped cached products without service calls")
	var cached_card: Node = cached.grid.get_child(0)
	cached.activate()
	check(cached.grid.get_child(0)==cached_card and service.paths.size()==2,"opening a cached passive Store retains its prepared product controls")
	cached.queue_free()
	await a.refresh()
	check(service.paths.size()==4,"explicit Refresh bypasses the access TTL")
	service.player.id = "medium-b"
	a.activate()
	while a.working: await process_frame
	check(service.paths.size()==6,"a new account cannot reuse another account's Store access")
	service.held = true
	a.refresh()
	service.player.id = "medium-c"
	service.held = false
	while a.working: await process_frame
	check(a.entitlements.is_empty(),"a delayed previous-account Store reply cannot enable checkout")
	report.store = {"calls":service.paths.duplicate(),"hidden_calls":0}
	a.queue_free()
	b.queue_free()
	service.queue_free()
	await frames()

static func blocked(cancelled: Callable, gate: Semaphore) -> bool:
	gate.wait()
	return cancelled.call()

func test_worker() -> void:
	var browser := TrackBrowser.new()
	browser.library = TrackLibrary.new(folder.path_join("tracks"))
	browser.records = LocalRecords.new(folder.path_join("records.json"))
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	browser.state = {"section":"all","page":0}
	root.add_child(browser)
	await frames(2)
	var source: Dictionary = TrackDocument.create_default()
	source.id = "medium_local"
	var saved: Error = browser.library.save_document(source)
	check(saved==OK,"real local compiler fixture is saved")
	if saved!=OK:
		browser.queue_free()
		return
	browser._select(TrackCatalog.local_metadata(source))
	var actual: RefCounted = browser._resolve_job
	check(actual!=null,"local selection uses an independently owned compile job")
	check(actual._work.get_object()==browser.get_script(),"compiler callable owns a script resource rather than the departing browser")
	root.remove_child(browser)
	check(actual.cancelled() and browser._resolve_job==null,"real local resolver is cancelled on browser departure")
	browser.queue_free()
	while not actual.done: await process_frame
	var gate := Semaphore.new()
	var job: RefCounted = Work.start(blocked.bind(gate),self)
	var owner := TrackBrowser.new()
	owner.library = TrackLibrary.new(folder.path_join("empty"))
	owner.records = LocalRecords.new(folder.path_join("empty-records.json"))
	owner.selected_track = browser.selected_track if is_instance_valid(browser) else NativeTrack.read("res://resources/tracks/starter_circuit.json")
	owner.state = {"section":"all","page":0}
	root.add_child(owner)
	owner.set_process(false)
	owner._resolve_job = job
	var began: int = Time.get_ticks_usec()
	root.remove_child(owner)
	var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
	check(job.cancelled() and not job.done,"UI departure returns while an independently blocked worker remains alive")
	gate.post()
	while not job.done: await process_frame
	check(job.result==true,"tree-owned reaper retires the cancelled worker after it exits")
	owner.queue_free()
	report.worker = {"blocked_departure_ms":elapsed,"real_job_cancelled":actual.cancelled()}

func brute_pick(view: CarShowroom, location: Vector2, meshes: Array[Dictionary]) -> Dictionary:
	var pixel: Vector2 = location*Vector2(view.showroom_viewport.size)/view.size
	var origin: Vector3 = view.camera.project_ray_origin(pixel)
	var direction: Vector3 = view.camera.project_ray_normal(pixel)
	var nearest: float = INF
	var result: Dictionary = {}
	for entry: Dictionary in meshes:
		var node: MeshInstance3D = entry.node
		var inverse: Transform3D = node.global_transform.affine_inverse()
		var start: Vector3 = inverse*origin
		var ray: Vector3 = (inverse.basis*direction).normalized()
		if not (entry.bounds as AABB).intersects_ray(start,ray): continue
		var faces: PackedVector3Array = entry.faces
		for index: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(start,ray,faces[index],faces[index+1],faces[index+2])
			if hit==null: continue
			var world: Vector3 = node.global_transform*(hit as Vector3)
			var distance: float = origin.distance_squared_to(world)
			if distance>=nearest: continue
			nearest = distance
			var normal: Vector3 = (node.global_transform.basis.inverse().transposed()*(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index])).normalized()
			if normal.dot(direction)>0: normal = -normal
			result = {"point":view.weathering.wash_point(node,hit),"position":world,"normal":normal}
	return result

func test_washing() -> void:
	var timings: Array[Dictionary] = []
	for variant: String in ["compact","pickup","classic","formula","kart","compact_fitted"]:
		var id: String = "compact" if variant=="compact_fitted" else variant
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.garage_mode = true
		root.add_child(view)
		view.size = Vector2(800,500)
		view.set_process(false)
		await frames(2)
		if variant=="compact_fitted":
			var parts: Dictionary = {"version":1,"hood":"scoop","aero":"wing","rims":"five","body":"street"}
			view.apply_customisation(parts)
			check(view.car.customisation==parts and view.pick_meshes.all(func(entry: Dictionary) -> bool: return is_instance_valid(entry.node)),"fitted kit replacement prepares current mesh acceleration and releases old pick entries")
		check(not view.pick_meshes.is_empty() and not view.pick_meshes[0].has("faces"),id+" has prepared native BVHs before its first wash contact")
		var meshes: Array[Dictionary] = []
		for entry: Dictionary in view.pick_meshes: meshes.append({"node":entry.node,"faces":entry.node.mesh.get_faces(),"bounds":entry.bounds})
		var points: Array[Vector2] = []
		for x: float in [-0.45,0.0,0.45]:
			for z: float in [-1.0,0.0,1.0]:
				points.append(view.camera.unproject_position(view.car.body.global_transform*Vector3(x,0.7,z))*view.size/Vector2(view.showroom_viewport.size))
		for wheel: Node3D in view.car.rolling_wheels:
			wheel.rotation.x += 0.4
			points.append(view.camera.unproject_position(wheel.global_position)*view.size/Vector2(view.showroom_viewport.size))
		var new_us: int = 0
		var old_us: int = 0
		for point: Vector2 in points:
			var began: int = Time.get_ticks_usec()
			var current: Dictionary = view.pick_body_surface(point)
			new_us += Time.get_ticks_usec()-began
			began = Time.get_ticks_usec()
			var original: Dictionary = brute_pick(view,point,meshes)
			old_us += Time.get_ticks_usec()-began
			check(current.is_empty()==original.is_empty(),id+" BVH preserves exact hit/miss coverage")
			if not current.is_empty() and not original.is_empty():
				check(current.point.distance_to(original.point)<0.00002 and current.position.distance_to(original.position)<0.00002,id+" BVH preserves nearest point and wash-space mapping")
				check(current.normal.dot(original.normal)>0.9999,id+" BVH preserves oriented contact normals")
		var original := ReferenceWeathering.new()
		original.configure(view.car,"pine",VehicleCatalog.config(id))
		# Compare the batch operation with exactly the same saved wash volume.
		# Re-deriving it after showroom rotation introduces float roundoff.
		original.bounds = view.weathering.bounds
		original.restore({"dirt":0.8,"slow_dirt":0.6})
		view.weathering.restore(original.snapshot())
		view.weathering.begin_wash_batch()
		for index: int in range(32):
			var point := Vector3(sin(index*0.2)*0.3,0.6,cos(index*0.2)*0.3)
			original.wash(point,0.003125)
			view.weathering.wash(point,0.003125)
		check(view.weathering.snapshot()==original.snapshot(),id+" mid-batch persistence sees exact current wash bytes")
		view.weathering.end_wash_batch()
		check(view.weathering.snapshot()==original.snapshot(),id+" committed batch preserves all saved wash bytes")
		check(view.weathering._scrub_fraction==original._scrub_fraction,id+" batching preserves primary fractional resistance")
		check(view.weathering._slow_scrub_fraction==original._slow_scrub_fraction,id+" batching preserves slow fractional resistance")
		check(original.mask_uploads==64 and view.weathering.wash_mask_uploads==2,id+" uploads the two original masks once per 32-sample frame")
		var start: Vector2 = points[4]
		view.set_wash_mode(true)
		view.washing = true
		view.wash_previous = start
		view.wash_pointer = start+Vector2(384,0)
		var uploads: int = view.weathering.wash_mask_uploads
		var began: int = Time.get_ticks_usec()
		view._process(1.0/60.0)
		var swipe_us: int = Time.get_ticks_usec()-began
		for index: int in range(32):
			var contact: Dictionary = brute_pick(view,start+Vector2(12.0*(index+1),0),meshes)
			if not contact.is_empty(): original.wash(contact.point,1.0/60.0/32.0)
		check(view.weathering.snapshot()==original.snapshot(),variant+" actual 32-step input frame preserves original picked wash coverage")
		check(view.weathering.wash_mask_uploads-uploads<=2,variant+" actual input frame submits at most two mask uploads")
		timings.append({"vehicle":variant,"rays":points.size(),"native_bvh_us":new_us,"original_face_loop_us":old_us,"actual_32_step_frame_us":swipe_us})
		view.queue_free()
		await frames(2)
	report.washing = timings

func test_app_and_rendering() -> void:
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("app-tracks"))
	app.records = LocalRecords.new(folder.path_join("app-records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app.rivalry.model = WeeklyRivalry.new(true)
	app._show_screen("rivalry")
	await frames(8)
	var hidden_store: Node
	for neighbor: Dictionary in app.menu_neighbors.values():
		if neighbor.screen=="store": hidden_store = neighbor.content.find_child("StorePage",true,false)
	check(hidden_store!=null and hidden_store.page_preview and hidden_store.status.text.is_empty(),"actual app neighbor preparation leaves the unopened Store passive")
	var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
	var car: Node = page.find_child("RivalryPodiumCar_1",true,false)
	var row: Button = page.track_rows[0]
	row.grab_focus()
	var offset: int = page.standings_scroll.scroll_vertical
	var builds: int = page.content_builds
	var began: int = Time.get_ticks_usec()
	app._rivalry_changed()
	var unchanged_ms: float = (Time.get_ticks_usec()-began)/1000.0
	app.rivalry.busy = true
	app._rivalry_changed()
	app.rivalry.error = "Offline fixture"
	app.rivalry.busy = false
	app._rivalry_changed()
	check(app.content.find_child("WeeklyRivalryPage",true,false)==page and page.content_builds==builds,"unchanged and busy/error-only Rivalry notifications retain the page content")
	check(page.find_child("RivalryPodiumCar_1",true,false)==car and not car.is_queued_for_deletion(),"status changes retain native customised podium cars")
	check(page.standings_scroll.scroll_vertical==offset and get_root().gui_get_focus_owner()==row,"status changes preserve Rivalry focus and scroll")
	check((page.find_child("RivalryStatusMessage",true,false) as Label).text=="Offline fixture","retained Rivalry status reflects a new error")
	app.rivalry.error = ""
	app._rivalry_changed()
	check((page.find_child("RivalryStatusMessage",true,false) as Label).text!="Offline fixture","Rivalry clears an obsolete error without rebuilding")
	app.rivalry.model.tracks[0].entry = {"download_url":"https://offline.invalid/new-capability"}
	app.rivalry.model.remaining_seconds -= 5
	app._rivalry_changed()
	check(page.content_builds==builds and page.find_child("RivalryPodiumCar_1",true,false)==car,"clock/network metadata refreshes do not rebuild unchanged presentation")
	app.rivalry.model.server_standings = app.rivalry.model.standing().duplicate(true)
	app.rivalry.model.server_standings[0].points += 1
	app._rivalry_changed()
	check(page.content_builds==builds and page.find_child("RivalryPodiumCar_1",true,false)==car and page.track_rows[0]==row,"score-only refreshes update rows while retaining native podiums and track controls")
	check((page.find_child("RivalryPodiumPoints_1",true,false) as Label).text==str(int(app.rivalry.model.standing()[0].points))+" pts","retained podium points reflect actual newer standings")
	app.rivalry.model.tracks[0].name = "Changed actual track"
	app._rivalry_changed()
	check(app.content.find_child("WeeklyRivalryPage",true,false)==page and page.content_builds==builds+1,"actual content changes update the retained page")
	app._show_screen("garage")
	await create_timer(0.7).timeout
	await frames(8)
	var view: CarShowroom = app._retained_garage.showroom
	var requests: int = view.render_requests
	await frames(8)
	check(view.render_requests==requests,"settled clean Garage submits no repeated native redraw requests")
	if DisplayServer.get_name()!="headless":
		report.idle_update_modes = [view.showroom_viewport.render_target_update_mode,view.reflections.views[0].render_target_update_mode,view.reflections.views[1].render_target_update_mode]
		check(view.showroom_viewport.render_target_update_mode in [SubViewport.UPDATE_DISABLED,SubViewport.UPDATE_ONCE] and view.reflections.views.all(func(v: SubViewport) -> bool: return v.render_target_update_mode in [SubViewport.UPDATE_DISABLED,SubViewport.UPDATE_ONCE]),"settled main view and both reflection targets use completed one-shot images")
		var retained: Image = view.showroom_viewport.get_texture().get_image()
		var idle_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		retained.save_png(output.path_join("garage-retained.png"))
		view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		for capture: SubViewport in view.reflections.views: capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await frames(5)
		var continuous: Image = view.showroom_viewport.get_texture().get_image()
		var continuous_draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		report.native_draws = {"idle_total":idle_draws,"original_continuous_total":continuous_draws}
		check(continuous_draws>idle_draws,"native render counters confirm settled Garage passes are no longer submitted")
		continuous.save_png(output.path_join("garage-original-continuous.png"))
		check(retained.get_data()==continuous.get_data(),"retained idle image matches the original continuous renderer byte-for-byte")
		view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		for capture: SubViewport in view.reflections.views: capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var before: PackedByteArray = retained.get_data()
		view.rotate_view(Vector2(24,-6))
		await frames(5)
		check(view.showroom_viewport.get_texture().get_image().get_data()!=before,"camera/turntable input immediately refreshes native pixels")
	requests = view.render_requests
	GameSoundtrack.instance().music_enabled = true
	GameSoundtrack.instance().show_menu()
	await frames(6)
	if DisplayServer.get_name()!="headless": check(view.render_requests>requests,"the original playing LP keeps the native scene animated")
	else: check(view.render_requests==requests,"headless silent playback does not create false animation work")
	GameSoundtrack.instance().music_enabled = false
	await frames(5)
	requests = view.render_requests
	await frames(5)
	check(view.render_requests==requests,"stopping the LP settles native rendering again")
	view.weathering.restore({"snow":0.5,"slow_snow":0.2})
	requests = view.render_requests
	await frames(4)
	check(view.render_requests>requests,"snow melt remains animated with retained rendering")
	report.rivalry = {"unchanged_dispatch_ms":unchanged_ms,"unchanged_content_builds":builds}
	report.rendering = {"idle_redraw_requests":0,"playing_lp_checked":DisplayServer.get_name()!="headless"}
	app.queue_free()
	await frames(4)
