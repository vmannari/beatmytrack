extends SceneTree
## Observe the real Garage from the click through the first newspaper draw.
const Fixture = preload("res://tests/test_garage_news.gd")
const News = preload("res://backend/news_client.gd")
var checks: int = 0
var failures: int = 0
var page: GaragePage
var output: String
var observed: Array[String] = []
var watching: bool = false
var observations: Array[Dictionary] = []

class UngatedNews extends News:
	func prepare_entry() -> bool: return true

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

func observe() -> void:
	if not watching or not is_instance_valid(page): return
	var menu: Control = page.tools.find_child("GarageNewsMenu",true,false)
	if menu != null and menu.is_visible_in_tree() and menu._paper.get_global_rect().intersects(root.get_visible_rect()):
		var story: String = menu._selected_id
		if not story.is_empty() and (observed.is_empty() or observed.back() != story): observed.append(story)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func story(id: String, count: int) -> Dictionary:
	return {"id":id,"kind":"friend_track","actor_id":"bob","actor_name":"Bob","track_name":str(count)+" Circuit","version_id":"11111111-2222-4333-8444-555555555555","created_at":1792152000,"track_points":[[0,0],[20,0],[10,20]]}

func enter(service: Node, backend: Node, label: String) -> void:
	page.news_client = service
	backend.delay_reply = true
	observed.clear()
	watching = true
	page._navigate_section("news")
	check(page.section == "cars" and page.preview.visible,label+": current Garage remains until the entry read completes")
	await frames(30)
	check(not observed.has("stale-story") and not observed.has("example-published"),label+": no temporary edition is drawn")
	await capture(label+"-pending")
	backend.delay_reply = false
	await settle()
	check(page.section == "news",label+": ready edition opens")
	check(observed == ["actual-story"],label+": the first and only automatically displayed story is the refreshed lead")
	observations.append({"case":label,"displayed_stories":observed.duplicate()})
	await capture(label+"-ready")
	watching = false
	page._show_section("cars")
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var ungated: bool = "--ungated-control" in OS.get_cmdline_user_args()
	var work: String = ProjectSettings.globalize_path("res://../build/news-entry-20261114/"+("ungated-" if ungated else "")+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(work)
	output = work
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(work.path_join("tracks"))
	app.records = LocalRecords.new(work.path_join("records.json"))
	app.cloud_root_override = work.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	GameSoundtrack.instance().music_enabled = false
	app._show_screen("garage")
	page = app._retained_garage
	if DisplayServer.get_name() == "headless": process_frame.connect(observe)
	else: RenderingServer.frame_post_draw.connect(observe)
	await settle()
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	backend.remote_items = [story("actual-story",2400)]
	var service: Node = UngatedNews.new() if ungated else News.new()
	service.client = backend
	service.read_state_path = work.path_join("read-state.cfg")
	root.add_child(service)
	service.identity_changed()
	service.feed_loaded = true
	service.items = [story("stale-story",1000)]
	service._fetched_at = -60001
	await enter(service,backend,"expired-story")
	service.items.clear()
	service.feed_loaded = true
	service._fetched_at = -60001
	await enter(service,backend,"expired-empty")
	service.items = [story("actual-story",2400)]
	service._fetched_at = Time.get_ticks_msec()
	var before: int = backend.calls.size()
	page._navigate_section("news")
	check(page.section == "news" and backend.calls.size() == before,"fresh cached edition opens immediately without a read")
	await settle()
	page._show_section("cars")
	await settle()
	service._fetched_at = -60001
	service.checked_day = -1
	backend.delay_refresh = true
	page._navigate_section("news")
	await frames(15)
	check(service.busy and page.section == "news","the received page opens while the daily POST is still pending")
	check(page.tools.find_child("GarageNewsMenu",true,false)._selected_id == "actual-story","slow daily demand does not substitute another story")
	backend.delay_refresh = false
	await settle()
	page._show_section("cars")
	await settle()
	service._fetched_at = -60001
	backend.delay_reply = true
	before = backend.calls.size()
	service.refresh()
	page._navigate_section("news")
	page._navigate_section("news")
	await frames(4)
	check(backend.calls.size() == before+1,"rapid entries reuse an account read already in flight")
	backend.delay_reply = false
	await settle()
	check(page.section == "news" and backend.calls.size() == before+1,"only the latest entry opens and adds no duplicate read")
	page._show_section("cars")
	await settle()
	backend.delay_reply = true
	service._fetched_at = Time.get_ticks_msec()
	service.refresh(true)
	page._navigate_section("news")
	await frames(4)
	check(page.section == "cars","entry waits for an in-flight feed read even when the prior cache is recent")
	backend.delay_reply = false
	await settle()
	check(page.section == "news","the in-flight fresh-cache read opens its returned edition")
	page._show_section("cars")
	await settle()
	service._fetched_at = -60001
	backend.delay_reply = true
	page._navigate_section("news")
	await frames(4)
	page._navigate_section("trophies")
	backend.delay_reply = false
	await settle()
	check(page.section == "trophies","a late edition cannot override a newer navigation choice")
	page._show_section("cars")
	await settle()
	service._fetched_at = -60001
	backend.delay_reply = true
	page._navigate_section("news")
	await frames(4)
	page.hide()
	page.show()
	backend.delay_reply = false
	await settle()
	check(page.section == "cars","hiding and reopening cancels an unfinished newspaper entry")
	service._fetched_at = -60001
	backend.delay_reply = true
	page._navigate_section("news")
	await frames(4)
	backend.player.id = "another-account"
	service.identity_changed()
	backend.delay_reply = false
	await settle()
	check(page.section == "cars" and service.items.is_empty(),"account changes discard an old entry and its response")
	backend.signed = false
	before = backend.calls.size()
	page._navigate_section("news")
	check(page.section == "news" and backend.calls.size() == before,"guest entry opens immediately without transport")
	await settle()
	page._show_section("cars")
	await settle()
	backend.signed = true
	backend._capabilities.clear()
	page._navigate_section("news")
	check(page.section == "news" and backend.calls.size() == before,"unsupported server opens its local edition without transport")
	await settle()
	var receipt := FileAccess.open(output.path_join("observations.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify(observations,"\t"))
	receipt.close()
	app.queue_free()
	service.queue_free()
	backend.queue_free()
	await frames(15)
	print("NEWS ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
