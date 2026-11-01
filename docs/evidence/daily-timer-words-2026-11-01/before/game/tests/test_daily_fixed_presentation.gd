extends SceneTree
const Previous = preload("res://tests/test_daily_medal_page.gd")
const Rules = preload("res://race/daily_elimination.gd")
var checks: int = 0
var failures: int = 0
var app: Node

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for frame: int in range(5): await process_frame

func clock_text(value: String) -> String:
	var pattern := RegEx.create_from_string("[0-9]{2}:[0-9]{2}(:[0-9]{2})?")
	var found: RegExMatch = pattern.search(value)
	return found.get_string() if found != null else ""

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/daily-fixed-limits-2026-11-01")
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"capture "+name)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Daily fixed presentation deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var directory: String = "user://daily_fixed_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("daily")
	await settle()
	var page: Node = app.content.find_child("TrackOfDayPage",true,false)
	var service: Node = Previous.Feed.new()
	root.add_child(service)
	page.client = service
	await page.refresh()
	await settle()
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		await settle()
		var width: float = page._countdown_panel.size.x
		for remaining: int in [86399,43200,3599,3598,1800,61,60,59,1]:
			page._server_now = page._ends_at-remaining
			page._sample_msec = Time.get_ticks_msec()
			page._last_minute = -1
			page._process(0.0)
			await settle()
			check(is_equal_approx(page._countdown_panel.size.x,width),"countdown width stays fixed: "+locale+" "+str(remaining))
			var expected: String = "%02d:%02d" % [remaining/3600,(remaining/60)%60]
			check(clock_text(page._countdown.text) == expected,"countdown contains hours and minutes only: "+locale)
	TranslationServer.set_locale("en")
	GameText.refresh(self)
	page._server_now = page._ends_at-(4*3600+31*60+57)
	page._sample_msec = Time.get_ticks_msec()
	page._last_minute = -1
	page._process(0.0)
	await settle()
	await capture("fixed-hours-minutes")
	var card: Node = page._race_panel
	card.result = {"passed":4,"best_ms":70000}
	card._render()
	check(not card._gap.text.contains("%") and not card._target.text.contains("%"),"result-card stage hint omits percentage limits")
	card.result = {"passed":9,"best_ms":67600}
	card._render()
	check(card._gap.text == "Elite earned","Elite recognition has no cutoff label")
	app.root_ui.hide()
	root.content_scale_size = Vector2i.ZERO
	for completed: bool in [false,true]:
		var rules := Rules.new()
		rules.passed = 9 if completed else 4
		rules.complete = completed
		rules.eliminated = not completed
		for index: int in range(9): rules.limits.append(30-index)
		var session := TrackSession.new(120,10)
		session.lap_times.append(100)
		for index: int in range(9 if completed else 5): session.lap_times.append(30-index)
		session.finished = true
		var result := preload("res://ui/daily_elimination_results.gd").new()
		result.rules = rules
		result.session = session
		root.add_child(result)
		for size: Vector2i in [Vector2i(960,540),Vector2i(390,844)]:
			root.size = size
			await settle()
			var grid: GridContainer = result.find_child("DailyLapGrid",true,false)
			check(grid.columns == 2 and grid.get_child_count() == 2+(session.lap_times.size()-1)*2,"results contain only flying-lap numbers and times")
			for label: Node in result.find_children("*","Label",true,false): check(not label.text.contains("%") and label.text != "Limit","post-race results do not expose cutoff percentages or limits")
			await capture(("complete" if completed else "eliminated")+"-%dx%d" % [size.x,size.y])
		result.queue_free()
		await process_frame
	app.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_FIXED_PRESENTATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
