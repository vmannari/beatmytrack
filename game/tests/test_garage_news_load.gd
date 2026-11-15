extends SceneTree
## Measure the actual optional view without preloading its scripts through fixtures.
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String
var building: bool = false
var built_cars: int = 0
var built_during_entrance: bool = false
var clicked: int = 0
var first_draw: int = 0
var measurements: Array[Dictionary] = []

class Backend extends Node:
	var safety: Node
	var player: Dictionary = {"id":"alice"}
	var _capabilities: Dictionary = {"garage_news_version":1}
	var calls: int = 0
	func signed_in() -> bool: return true
	func base_url() -> String: return "https://fixture.invalid"
	func server_now() -> int: return 1792152000
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls += 1
		await get_tree().process_frame
		return {"ok":true,"data":{"items":[],"next_cursor":"","refreshing":false,"checked_day":server_now()/86400}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func frames(count: int = 8) -> void:
	for tick: int in range(count): await frame()

func settle() -> void:
	await frames()
	while page._menu_motion != null: await frame()
	await frames()

func track(node: Node) -> void:
	if building and node.name == "NewsLiveryCar":
		built_cars += 1
		built_during_entrance = built_during_entrance or page._menu_motion != null

func draw() -> void:
	if not building or first_draw != 0 or page.section != "news": return
	var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	if menu != null and menu.find_child("LeadStory",true,false) != null: first_draw = Time.get_ticks_usec()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func wait_photo() -> Node:
	var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		var view: Node = menu.find_child("NewsLiveryCar",true,false)
		if view != null and view.presentation_ready: return view
		await frame()
	return null

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var variant: String = "baseline" if "--baseline" in OS.get_cmdline_user_args() else "final"
	output = ProjectSettings.globalize_path("res://../build/news-load-20261114/"+variant+"-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(output)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(output.path_join("tracks"))
	app.records = LocalRecords.new(output.path_join("records.json"))
	app.cloud_root_override = output.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app._show_screen("garage")
	page = app._retained_garage
	await settle()
	check(page.rail.find_child("NewsWaiting",true,false) == null,"News uses the ordinary sidebar icon without a spinner")
	var backend := Backend.new()
	var ranking_loaded: bool = ResourceLoader.has_cached("res://ui/garage_news_ranking.gd")
	root.add_child(backend)
	var service: Node = load("res://backend/news_client.gd").new()
	service.client = backend
	service.read_state_path = output.path_join("read-state.cfg")
	root.add_child(service)
	service.identity_changed()
	service.checked_day = backend.server_now()/86400
	page.news_client = service
	node_added.connect(track)
	if DisplayServer.get_name() == "headless": process_frame.connect(draw)
	else: RenderingServer.frame_post_draw.connect(draw)
	for visit: int in range(1 if "--diagnose-first" in OS.get_cmdline_user_args() else 3):
		service.items = [{"id":"own-car","kind":"milestone","count":2400,"track_name":"Underpass","created_at":1792152000}]
		service._fetched_at = Time.get_ticks_msec()
		built_cars = 0
		built_during_entrance = false
		first_draw = 0
		building = true
		clicked = Time.get_ticks_usec()
		page._navigate_section("news")
		var returned: int = Time.get_ticks_usec()
		check(page.tools.find_child("LeadStory",true,false) != null,"lead controls exist when entry returns")
		check(built_cars == 0,"entry does not synchronously construct the car photograph")
		await settle()
		var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
		var view: Node = menu.find_child("NewsLiveryCar",true,false)
		var deadline: int = Time.get_ticks_msec()+20000
		while (view == null or not view.presentation_ready) and Time.get_ticks_msec() < deadline:
			await frame()
			view = menu.find_child("NewsLiveryCar",true,false)
		check(view != null and view.presentation_ready and built_cars == 1,"one actual photograph finishes after the controls are available")
		check(not built_during_entrance,"photograph preparation leaves the paper entrance free to animate")
		if view == null or not view.presentation_ready or built_cars != 1:
			print("PHOTO_DIAGNOSTIC ",JSON.stringify({"built":built_cars,"view":view != null,"active":menu._active(),"pending":menu._pending_photo.size(),"scheduled":menu._photo_scheduled,"model_ready":view.car.model_ready if view != null else false,"stage":view.car._model_stage if view != null else "none","yields":view.car.model_yields if view != null else 0}))
		check(menu._selected_id == "own-car" and backend.calls == 0,"cached entry keeps the exact story without transport")
		check(ResourceLoader.has_cached("res://ui/garage_news_ranking.gd") == ranking_loaded,"Headlines does not import the optional Ranking view")
		measurements.append({"visit":visit,"entry_call_ms":(returned-clicked)/1000.0,"first_lead_draw_ms":(first_draw-clicked)/1000.0,"car_builds":built_cars,"ranking_loaded_before":ranking_loaded,"ranking_loaded_after":ResourceLoader.has_cached("res://ui/garage_news_ranking.gd")})
		if visit == 0: await capture("loaded-paper")
		if "--diagnose-first" in OS.get_cmdline_user_args():
			print("NEWS LOAD FIRST DIAGNOSTIC: ",JSON.stringify(measurements))
			quit(1 if failures else 0)
			return
		building = false
		page._show_section("cars")
		await settle()
	built_cars = 0
	building = true
	service._fetched_at = Time.get_ticks_msec()
	page._navigate_section("news")
	page._navigate_section("cars")
	await settle()
	check(built_cars == 0,"leaving before the first paper draw cancels its photograph")
	building = false
	var paint: Dictionary = VehicleLivery.defaults("compact")
	service.items = [{"id":"painted-car","kind":"world_record","actor_id":"bob","actor_name":"Bob","vehicle_id":"compact","appearance":{"vehicle_id":"compact","livery":paint,"customisation":VehicleCustomisation.defaults()},"metric":"race","time_ticks":12000,"tick_rate":120,"track_name":"Underpass"}]
	service._fetched_at = Time.get_ticks_msec()
	built_cars = 0
	building = true
	page._navigate_section("news")
	service.items[0].appearance.livery.colors.body = "d32535"
	service.changed.emit()
	await settle()
	var latest: Node = await wait_photo()
	check(latest != null and latest.car.livery.colors.body == "d32535" and built_cars == 1,"a story update before the first draw builds only the latest appearance")
	await capture("latest-appearance")
	building = false
	page._show_section("cars")
	await settle()
	service._fetched_at = Time.get_ticks_msec()
	built_cars = 0
	building = true
	page._navigate_section("news")
	page.hide()
	await frames(4)
	check(built_cars == 0,"hidden paper does not begin a deferred photograph")
	page.show()
	await settle()
	latest = await wait_photo()
	check(latest != null and latest.car.livery.colors.body == "d32535" and built_cars == 1,"showing the paper resumes its current appearance exactly once")
	building = false
	page._show_section("cars")
	await settle()
	service._fetched_at = Time.get_ticks_msec()
	built_cars = 0
	building = true
	page._navigate_section("news")
	backend.player.id = "another-account"
	backend._capabilities.clear()
	service.identity_changed()
	await settle()
	check(built_cars == 0,"account change discards a queued photograph before it is constructed")
	building = false
	var receipt := FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify(measurements,"\t"))
	receipt.close()
	app.queue_free()
	service.queue_free()
	backend.queue_free()
	await frames(15)
	print("NEWS LOAD: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(measurements)])
	quit(1 if failures else 0)
