extends SceneTree
const Previous = preload("res://tests/test_daily_medal_page.gd")
const Card = preload("res://ui/daily_result_card.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var output: String

class Feed extends Previous.Feed:
	var guest: bool = false
	var fail: bool = false
	func signed_in() -> bool: return not guest
	func request_api(path: String, method: int, body: Dictionary, key: String, auth: bool) -> Dictionary:
		var response: Dictionary = await super.request_api(path,method,body,key,auth)
		if path == "/track-of-the-day": return response
		if fail: return {"ok":false,"status":500}
		var candidate: int = 0
		for item: String in path.get_slice("?",1).split("&"):
			if item.begins_with("lap_ticks="): candidate = int(item.get_slice("=",1))
		response.data.items = []
		for index: int in range(6):
			response.data.items.append({"player_id":"opponent-"+str(index),"display_name":["Ari Vale T0103-001","NordicLine","ApexWolf","LateBraker","Nico","Slipstream"][index],"country_code":["FI","SE","DE","GB","FR","NL"][index],"rank":index+1,"time_ticks":3324+index*60 if candidate == 0 else candidate+(index-3)*60+1})
		return response

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	if app != null and app.menu_page_motion != null: app._finish_menu_page_slide()
	for frame: int in range(12): await process_frame

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png")) == OK,"capture "+id)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Daily redesign deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_DAILY_CARD_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	TranslationServer.set_locale("en")
	var directory: String = "user://daily_card_"+TrackLibrary.unique_id()
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
	var service := Feed.new()
	root.add_child(service)
	page.client = service
	await page.refresh()
	await settle()
	var card: Node = page._race_panel
	check(service.calls[-1].contains("limit=6"),"unplayed card requests six real competitors")
	check(card._heading.text == "Chase the podium","approved modest title")
	check(card._medals.get_child_count() == 4,"all four award shapes remain visible")
	check(card._rows.get_child_count() == 7,"six competitors plus unplayed self")
	check(not card._time.visible and not card._position.visible,"unplayed dash and extra status removed")
	check(card._target.text == "1:30.000","target keeps the exact cutoff")
	check(card._rows.find_child("DailyNearbySelf",true,false).find_child("DailyNearbyTime",true,false).text == "—","unplayed self has no invented time")
	for medal: Node in card._medals.get_children():
		check(not medal.earned and medal.card_display,"unearned card medal is a silhouette")
	for label: Label in page.find_children("*","Label",true,false):
		check(label.text != "One track. Everyone. A new pick every day.","removed subtitle remains absent")
	for dimensions: Vector2i in [Vector2i(1628,966),Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		var scroll: Control = page.find_child("DailyScroll",true,false)
		print("DAILY_CARD_LAYOUT ",dimensions," card=",card.size," list=",card._rows_scroll.size," rows=",card._rows.size," title=",card._heading.size," medals=",card._medals.size," target=",card._target_row.size," header=",card._standings_header.size)
		check(scroll.get_global_rect().encloses(card.race_button.get_global_rect()),"Race stays visible "+str(dimensions))
		check(card._standings_header.get_global_rect().position.y-card._target_row.get_global_rect().end.y >= 16,"target and standings have breathing room "+str(dimensions))
		check(card._rows_scroll.get_global_rect().position.y-card._standings_header.get_global_rect().end.y >= 8,"heading and players have breathing room "+str(dimensions))
		check(card._rows_scroll.size.y >= card._rows.size.y,"all seven rows visible "+str(dimensions))
		check(not page._hero.get_rect().intersects(card.get_rect()),"panels do not overlap "+str(dimensions))
		await capture("unplayed-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		card._render()
		await settle()
		check(card._heading.text == tr("Chase the podium") and (locale == "en" or card._heading.text != "Chase the podium"),"title translated "+locale)
		check(card._target_caption.text == tr("Target"),"target caption translated "+locale)
		check(card._heading.size.x <= card.size.x-30,"translated title fits "+locale)
		check(page.find_child("DailyScroll",true,false).get_global_rect().encloses(card.race_button.get_global_rect()),"translated Race fits "+locale)
		check(card._rows_scroll.size.y >= card._rows.size.y,"all seven translated rows visible "+locale)
		for medal: Control in card._medals.get_children():
			var label: Label = medal.find_child("DailyMedalLabel",false,false)
			check(label.get_minimum_size().x <= medal.size.x,"medal label fits "+locale)
		if locale in ["fi","de","ja"]: await capture("locale-"+locale)
	TranslationServer.set_locale("en")
	GameText.refresh(self)
	for passed: int in [1,4,6,9]:
		card.result = {"passed":passed,"best_ms":72480}
		card._render()
		await settle()
		var tier: int = Previous.Progress.tier(passed)
		for index: int in range(4): check(card._medals.get_child(index).earned == (index < tier),"only reached medals light up "+str(passed))
		check(card._target_row.visible == (passed < 9),"Elite has no fictional next target")
		await capture("earned-"+str(tier))
	# Refresh actual saved progress, exercising request size, candidate and expiry fences.
	var saved := Previous.new()
	saved.fixture(app.records,Previous.DAY,4)
	saved.free()
	card.refresh()
	await settle()
	check(service.calls[-1].contains("limit=7") and service.calls[-1].contains("lap_ticks=8698"),"played card asks for six neighbours and exact candidate")
	check(card._rows.get_child_count() == 7 and card._rows.find_child("DailyNearbySelf",true,false).find_child("DailyNearbyTime",true,false).text == "1:12.480","exact local milliseconds remain visible in expanded rows")
	check(card._valid(card.summary),"six-item response passes scope and cutoff validation")
	var wrong: Dictionary = card.summary.duplicate(true)
	wrong.vehicle_id = "kart"
	check(not card._valid(wrong),"expanded response still rejects wrong car")
	wrong = card.summary.duplicate(true)
	wrong.items.append(wrong.items[0].duplicate())
	check(not card._valid(wrong),"oversized responses remain rejected")
	card.summary = {}
	card._loading = false
	card._failed = true
	card._render()
	await settle()
	check(card._retry.visible and card._time.visible,"offline failure keeps best lap and retry")
	await capture("offline")
	service.guest = true
	card.result = {}
	card.summary = wrong.duplicate(true)
	card.summary.items.resize(6)
	card._render()
	check(card._rows.get_child_count() == 6 and card._rows.find_child("DailyNearbySelf",true,false) == null,"guests never get an invented self row")
	app.root_ui.hide()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(390,844)
	var narrow := preload("res://ui/track_of_day_page.gd").new()
	narrow.client = service
	narrow.cloud = app.cloud
	narrow.records = app.records
	narrow.page_preview = true
	root.add_child(narrow)
	MenuStyle.fill(narrow)
	await narrow.refresh()
	for locale: String in ["en","de","fi","ja"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		narrow._race_panel._render()
		await settle()
		check(narrow._race_panel.get_global_rect().end.x <= 390,"portrait card fits "+locale)
		narrow.find_child("DailyScroll",true,false).scroll_vertical = 9999
		await settle()
		check(root.get_visible_rect().intersects(narrow._race.get_global_rect()),"portrait Race reachable "+locale)
		await capture("portrait-"+locale)
	app.queue_free()
	narrow.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_CARD_REDESIGN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
