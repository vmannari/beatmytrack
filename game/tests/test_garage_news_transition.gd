extends "res://tests/test_garage_news_entry.gd"
## Draw-frame observations of feedback, paper motion and retained article work.
var sampling: bool = false
var samples: Array[Dictionary] = []
var leads: Array[int] = []
var cars: Array[int] = []
var timings: Dictionary = {}
var built_leads: Array[int] = []
var built_cars: Array[int] = []
var tracking_builds: bool = false
var original_heading: Rect2
var heading_stable: bool = true

func track_build(node: Node) -> void:
	if not tracking_builds: return
	if node.name == "LeadStory": built_leads.append(node.get_instance_id())
	if node.name == "NewsLiveryCar": built_cars.append(node.get_instance_id())

func sample() -> void:
	if not sampling or page.section != "news": return
	var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	if menu == null: return
	if page._menu_motion != null and page.preview.visible and not page.heading.get_global_rect().is_equal_approx(original_heading): heading_stable = false
	var lead: Node = menu.find_child("LeadStory",true,false)
	if lead != null and not leads.has(lead.get_instance_id()): leads.append(lead.get_instance_id())
	var car: Node = menu.find_child("NewsLiveryCar",true,false)
	if car != null and not cars.has(car.get_instance_id()): cars.append(car.get_instance_id())
	samples.append({"alpha":page.tools_panel.modulate.a,"offset":page.tools_panel.position.x-page._slot_rect(page.main).position.x,"preview":page.preview.visible,"motion":page._menu_motion != null,"story":menu._selected_id,"car_exists":car != null,"car_ready":car != null and car.presentation_ready})

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var suffix: String = "baseline" if "--baseline" in OS.get_cmdline_user_args() else "final"
	output = ProjectSettings.globalize_path("res://../build/news-transition-20261114/"+suffix+"-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name())
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
	if DisplayServer.get_name() == "headless": process_frame.connect(sample)
	else: RenderingServer.frame_post_draw.connect(sample)
	node_added.connect(track_build)
	await settle()
	var original_car: Node = page.showroom.car
	var original_view: SubViewport = page.showroom.showroom_viewport
	original_heading = page.heading.get_global_rect()
	var backend := Fixture.Backend.new()
	root.add_child(backend)
	backend.remote_items = [story("actual-story",2400)]
	backend.delay_reply = true
	backend.delay_refresh = true
	var service := News.new()
	service.client = backend
	service.read_state_path = output.path_join("read-state.cfg")
	root.add_child(service)
	service.identity_changed()
	service.items = [story("stale-story",1000)]
	service.feed_loaded = true
	page.news_client = service
	var clicked: int = Time.get_ticks_usec()
	page._navigate_section("news")
	var news_button: Button = page.rail.get_node("GarageNews")
	check(news_button.get_theme_stylebox("normal").bg_color == MenuStyle.ACCENT,"tap immediately highlights News while its read is pending")
	await frames(8)
	check(page.section == "cars" and page.preview.visible,"pending news keeps the current Garage responsive")
	await capture("pending-feedback")
	sampling = true
	tracking_builds = true
	backend.delay_reply = false
	var released: int = Time.get_ticks_usec()
	while page.section != "news" and Time.get_ticks_usec()-released < 5000000: await frame()
	check(page.section == "news","received edition starts its entrance")
	timings["response_to_commit_ms"] = (Time.get_ticks_usec()-released)/1000.0
	while page._menu_motion != null: await frame()
	timings["response_to_settled_ms"] = (Time.get_ticks_usec()-released)/1000.0
	timings["click_to_settled_ms"] = (Time.get_ticks_usec()-clicked)/1000.0
	await frames(5)
	sampling = false
	var visible_samples: Array = samples.filter(func(row: Dictionary) -> bool: return row.alpha > 0.01)
	check(not visible_samples.is_empty() and absf(visible_samples[0].offset) <= 32.0,"paper enters within a short distance of its final position")
	check(samples.any(func(row: Dictionary) -> bool: return row.alpha > 0.05 and row.alpha < 0.95),"paper eases into view instead of arriving as an opaque full-width slide")
	check(samples.any(func(row: Dictionary) -> bool: return row.motion and row.preview),"original Garage remains under the incoming paper")
	check(samples.all(func(row: Dictionary) -> bool: return row.story == "actual-story"),"entrance never exposes a temporary story")
	check(leads.size() == 1,"layout and entry status keep one lead article during the entrance")
	check(page.tools_panel.modulate.a == 1.0 and not page.preview.visible and not page.gallery.visible,"settled newspaper is opaque and suspends the showroom")
	check(page.showroom.car == original_car and page.showroom.showroom_viewport == original_view,"entrance retains the actual Garage resources")
	check(heading_stable,"the outgoing Garage title keeps its original position and width")
	var menu: Node = page.tools.find_child("GarageNewsMenu",true,false)
	var lead_id: int = menu.find_child("LeadStory",true,false).get_instance_id()
	backend.delay_refresh = false
	await frames(10)
	check(menu.find_child("LeadStory",true,false).get_instance_id() == lead_id,"daily POST completion updates status without rebuilding the article")
	check(backend.calls.size() == 2,"opening uses only the original GET and daily POST")
	check(built_leads.size() == 1,"entry and daily status construct only one article")
	await capture("settled-paper")
	var entrance_samples: Array = samples.duplicate(true)
	var entrance_builds: int = built_leads.size()
	tracking_builds = false
	page._show_section("cars")
	await settle()
	service.items = [{"id":"own-car","kind":"milestone","count":2400,"track_name":"Underpass","created_at":1792152000}]
	service._fetched_at = Time.get_ticks_msec()
	leads.clear()
	cars.clear()
	samples.clear()
	sampling = true
	tracking_builds = true
	built_leads.clear()
	built_cars.clear()
	var before: int = backend.calls.size()
	var cached_clicked: int = Time.get_ticks_usec()
	page._navigate_section("news")
	timings["cached_call_ms"] = (Time.get_ticks_usec()-cached_clicked)/1000.0
	check(page.section == "news" and backend.calls.size() == before,"fresh cache begins its entrance without a network delay")
	while page._menu_motion != null: await frame()
	await frames(10)
	sampling = false
	check(leads.size() == 1 and cars.size() == 1,"the own-car photograph is constructed once through the entrance")
	check(built_leads.size() == 1 and built_cars.size() == 1,"cached entry never builds discarded articles or car models")
	menu = page.tools.find_child("GarageNewsMenu",true,false)
	var car_view: Node = menu.find_child("NewsLiveryCar",true,false)
	var deadline: int = Time.get_ticks_msec()+20000
	while is_instance_valid(car_view) and not car_view.presentation_ready and Time.get_ticks_msec() < deadline: await frame()
	check(car_view != null and car_view.presentation_ready,"the actual fitted car photograph becomes ready")
	check(samples.all(func(row: Dictionary) -> bool: return not row.motion or not row.car_exists),"the actual car photograph starts after the paper entrance")
	await capture("own-car-ready")
	tracking_builds = false
	var cached_samples: Array = samples.duplicate(true)
	var cached_builds: Dictionary = {"articles":built_leads.size(),"cars":built_cars.size()}
	page._show_section("cars")
	await settle()
	page._navigate_section("news")
	await frame()
	var stalled_motion: Tween = page._menu_motion
	stalled_motion.pause()
	page._process(0.4)
	stalled_motion.custom_step(0.4)
	page._present_menu_layout()
	check(page.tools_panel.modulate.a > 0.05 and page.tools_panel.modulate.a < 0.95,"a 400 ms frame still presents an intermediate paper frame")
	page._navigate_section("cars")
	await settle()
	check(page.preview.visible and page.gallery.visible and page.preview.modulate.a == 1.0 and page.gallery.modulate.a == 1.0,"interruption restores the normal Garage opacity and layout")
	check(page._departures.is_empty(),"interruption frees outgoing controls")
	var receipt := FileAccess.open(output.path_join("motion.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"timings":timings,"entrance_samples":entrance_samples,"entrance_articles":entrance_builds,"cached_samples":cached_samples,"cached_builds":cached_builds},"\t"))
	receipt.close()
	if "--capture-motion" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		service.items = backend.remote_items.duplicate(true)
		service._fetched_at = Time.get_ticks_msec()
		page._navigate_section("news")
		await frame()
		var motion: Tween = page._menu_motion
		motion.pause()
		for step: int in range(13):
			await frame()
			await capture("motion-%02d" % step)
			if motion.is_valid():
				motion.set_speed_scale(1.0)
				motion.custom_step(0.022)
		await settle()
	app.queue_free()
	service.queue_free()
	backend.queue_free()
	await frames(15)
	print("NEWS TRANSITION: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(timings)])
	quit(1 if failures else 0)
