extends SceneTree
## Real app navigation, one shared HTTP pick, production download/race/return.
var checks: int = 0
var failures: int = 0
var app: Node

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	if app.menu_page_motion != null: app._finish_menu_page_slide()
	for _frame: int in range(5): await process_frame

func loaded(page: Node) -> void:
	var began: int = Time.get_ticks_msec()
	while page._busy and Time.get_ticks_msec()-began < 15000: await process_frame
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://../docs/evidence/track-of-day-2026-10-25")
	check(root.get_texture().get_image().save_png(directory.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"capture "+label)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: native Track of the Day deadline"); quit(1))
	root.size = Vector2i(1280,720)
	OS.set_environment("BMT_API_URL",OS.get_environment("BMT_TOTD_API_URL"))
	var directory: String = "user://track_of_day_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await settle()
	var browser: Node = app.content.find_child("TrackBrowser",true,false)
	check(browser != null and browser.find_child("Mode_sun",true,false) != null,"Free Race has daily mode")
	(browser.find_child("Mode_sun",true,false) as Button).pressed.emit()
	await settle()
	var page: Node = app.content.find_child("TrackOfDayPage",true,false)
	check(page != null and app.screen == "daily" and app.race_area_mode == "daily","daily mode opens real page")
	await loaded(page)
	check(not page.entry.is_empty(),"backend daily track loaded")
	if page.entry.is_empty():
		print("Track of the Day: %d checks, %d failures" % [checks,failures]); quit(1); return
	check(str(page.entry.version_id) == OS.get_environment("BMT_TOTD_VERSION"),"same immutable pick as backend")
	check(not page._race.disabled,"daily race is available")
	check(int(app.online.client._capabilities.get("track_of_day_version",0)) == 1,"bootstrap capability")
	var original: String = str(page.entry.version_id)
	await page.refresh()
	check(str(page.entry.version_id) == original,"refresh retains same daily pick")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var rail: Control = page.find_child("RaceModes",true,false)
		check(rail.get_global_rect().end.y <= root.get_visible_rect().end.y+1,"four race destinations fit visible canvas "+str(dimensions))
		check(page._race.get_combined_minimum_size().y >= 48,"race touch target "+str(dimensions))
		var scroll: ScrollContainer = page.find_child("DailyScroll",true,false)
		scroll.scroll_vertical = 0
		await capture("daily-"+str(dimensions.x)+"x"+str(dimensions.y))
		scroll.scroll_vertical = 9999
		await settle()
		check(scroll.get_global_rect().intersects(page._race.get_global_rect()),"race action reachable by scroll "+str(dimensions))
	root.size = Vector2i(1280,720)
	await settle()
	# Expiring a displayed selection triggers a fresh authoritative read.
	page._ends_at = page._server_now
	page._process(0.0)
	await loaded(page)
	check(page._ends_at > page._server_now and str(page.entry.version_id) == original,"midnight refresh replaces expired presentation")
	# Exercise the real car picker and normal race pipeline using the pinned revision.
	var cars: OptionButton = page.find_child("DailyCar",true,false)
	cars.item_selected.emit(VehicleCatalog.IDS.find("compact"))
	check(VehicleCatalog.selected == "compact","daily car picker uses ordinary selection")
	page._request_race()
	var began: int = Time.get_ticks_msec()
	while (app.game == null or app.cloud_starting) and Time.get_ticks_msec()-began < 90000: await process_frame
	check(app.game != null,"daily action starts actual Game")
	if app.game != null:
		check(str(app.game.native_track.metadata.get("cloud_version","")) == original,"Game uses selected daily revision")
		app._leave_race()
		await settle()
		check(app.screen == "daily","leaving race returns to daily mode")
	app._request_race_mode("challenges")
	await settle()
	var challenge_page: Node = app.content.find_child("ChallengesPage",true,false)
	check(challenge_page != null and challenge_page.find_child("Mode_sun",true,false) != null,"Challenges has daily destination")
	(challenge_page.find_child("Mode_sun",true,false) as Button).pressed.emit()
	await settle()
	page = app.content.find_child("TrackOfDayPage",true,false)
	await loaded(page)
	check(app.screen == "daily" and str(page.entry.version_id) == original,"Challenges rail opens same daily pick")
	app.rivalry.model = WeeklyRivalry.new(true)
	app._request_race_mode("rivalry")
	await settle()
	var rivalry_page: Node = app.content.find_child("WeeklyRivalryPage",true,false)
	check(rivalry_page != null and rivalry_page.find_child("Mode_sun",true,false) != null,"Rivalry has daily destination")
	(rivalry_page.find_child("Mode_sun",true,false) as Button).pressed.emit()
	await settle()
	page = app.content.find_child("TrackOfDayPage",true,false)
	await loaded(page)
	check(app.screen == "daily" and str(page.entry.version_id) == original,"Rivalry rail opens same daily pick")
	app._request_race_mode("free")
	await settle()
	check(app.screen == "tracks" and app.race_area_mode == "free","Free Race navigation retained")
	app.queue_free()
	await process_frame
	print("Track of the Day: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
