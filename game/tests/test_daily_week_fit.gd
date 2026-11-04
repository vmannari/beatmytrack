extends SceneTree
const Progress = preload("res://persistence/daily_progress.gd")
const Rules = preload("res://race/daily_elimination.gd")
const LIMITS: Array[float] = [90,84,80,75,74,72,71,70,68]
const DAY: int = 20757
const VERSION: String = "00000000-0000-0000-0000-000000000002"
var checks: int = 0
var failures: int = 0
var app: Node
var page: Node
var service: Feed

class Feed extends Node:
	signal released
	var player: Dictionary = {"id":"local-player","display_name":"Ville"}
	var pending: bool = false
	var calls: Array[String] = []
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://daily-medal.invalid"
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(path: String, _owner: int) -> Dictionary: return await request_api(path,0,{},"",false)
	func request_api(path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		calls.append(path)
		var now: int = DAY*86400+3600
		var response: Dictionary = {"ok":true,"data":{"day":DAY,"server_now":now,"ends_at":(DAY+1)*86400}}
		if path == "/track-of-the-day":
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/creator_tracks/lantern_village.json"))
			response.data.track = {"track_id":"00000000-0000-0000-0000-000000000001","version_id":VERSION,"content_hash":"a".repeat(64),"name":document.name,"creator":document.creator,"theme":"pine","points":document.points,"rating_average":4.7,"rating_count":128}
			return response
		var car: String = "compact"
		var ticks: int = 8698
		for item: String in path.get_slice("?",1).split("&"):
			if item.begins_with("vehicle_id="): car = item.get_slice("=",1)
			if item.begins_with("lap_ticks="): ticks = int(item.get_slice("=",1))
		var position: int = 8 if ticks < 8160 else 180 if ticks < 8640 else 287 if ticks < 8880 else 900
		response.data.merge({"version_id":VERSION,"vehicle_id":car,"tick_rate":120,"population":1284,"cutoffs":[],"comparison":{"position":position,"population":1284,"top_percent":ceili(float(position)*100/1284),"candidate_ticks":ticks},"player":null,"next_cursor":null,"items":[{"player_id":"mika","display_name":"Mika","rank":position-1,"time_ticks":ticks-35,"gap_ticks":100},{"player_id":"antti","display_name":"Antti","rank":position+1,"time_ticks":ticks+42,"gap_ticks":177}]})
		for index: int in range(9): response.data.cutoffs.append({"percentile":Rules.PERCENTILES[index],"lap_ticks":roundi(LIMITS[index]*120)})
		if pending: await released
		return response

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture(records: LocalRecords, day: int, passed: int, vehicle: String = "compact") -> void:
	var session := TrackSession.new(120,10)
	var rules := Rules.new()
	rules.limits = LIMITS.duplicate()
	var times: Array[float] = [150]
	for index: int in range(passed): times.append(72.480 if index == 2 and passed == 4 else LIMITS[index]-0.4)
	if passed < 9: times.append(LIMITS[passed]+10)
	for lap: float in times:
		session.lap_times.append(lap)
		session.completed_laps += 1
		rules.observe(session)
	check(rules.passed == passed and session.finished,"fixture clears the specified stages")
	check(Progress.commit(records,day,VERSION,vehicle,session,rules),"daily medal commits")

func settle() -> void:
	for frame: int in range(10): await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/daily-week-fit-2026-11-02/")
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Daily medal page deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	TranslationServer.set_locale("en")
	for pair: Array in [[0,0],[1,1],[3,1],[4,2],[5,2],[6,3],[8,3],[9,4]]:
		check(Progress.tier(pair[0]) == pair[1],"exact medal stage boundary "+str(pair[0]))
	var directory: String = "user://daily_medal_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var monday: int = DAY-posmod(DAY+3,7)
	fixture(app.records,monday,6)
	fixture(app.records,monday+2,4)
	fixture(app.records,monday+3,6)
	fixture(app.records,monday+4,4)
	fixture(app.records,DAY,4)
	fixture(app.records,DAY,1,"kart")
	fixture(app.records,DAY,6,"forklift")
	var entries: Dictionary = Progress.load_entries(app.records)
	check(Progress.week(entries,DAY,"compact") == [3,0,2,3,2,2,-1],"weekly medals use UTC Monday and preserve unplayed/future days")
	check(Progress.week(entries,DAY,"electric") == [0,0,0,0,0,0,-1],"weekly medals remain car specific")
	var foreign := LocalRecords.new(directory.path_join("other-account.json"))
	check(Progress.load_entries(foreign).is_empty(),"account storage does not leak awards")
	var invalid := LocalRecords.new(directory.path_join("invalid.json"))
	var io = preload("res://backend/atomic_json.gd")
	io.write(invalid.path+".daily.json",{"schema":99,"entries":{}})
	var broken_before: String = FileAccess.get_file_as_string(invalid.path+".daily.json")
	var invalid_session := TrackSession.new(120,10)
	invalid_session.lap_times.assign([0.01,100.0])
	invalid_session.finished = true
	var invalid_rules := Rules.new()
	check(not Progress.commit(invalid,DAY,VERSION,"compact",invalid_session,invalid_rules),"unknown save schema cannot be overwritten or reported as saved")
	check(FileAccess.get_file_as_string(invalid.path+".daily.json") == broken_before,"failed save preserves previous data")
	app._show_screen("daily")
	await settle()
	page = app.content.find_child("TrackOfDayPage",true,false)
	service = Feed.new()
	root.add_child(service)
	page.client = service
	for connection: Dictionary in page.race_requested.get_connections(): page.race_requested.disconnect(connection.callable)
	await page.refresh()
	await settle()
	var card: Node = page._race_panel
	check(card.result.passed == 4 and card._medals.get_child(1).selected and card._medals.get_child(1).earned,"page restores earned silver from passed stage 40")
	check(card._time.text == "1:12.480" and card._target.text == "1:12.000" and card._target.tooltip_text.begins_with("0.480"),"best flying lap and exact gold gap match the reference behavior")
	check(card._rows.get_child_count() == 3 and card._rows.find_child("DailyNearbySelf",true,false) != null,"nearby flying-lap standings highlight the player")
	check(card.race_button.text == "Race again","returning player has race again action")
	for size: Vector2i in [Vector2i(2538,1147),Vector2i(1440,900),Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = size
		await settle()
		check(page._stage.get_global_rect().encloses(page._week_strip.get_global_rect()),"weekly card fits fully within the daily event")
		check(not page._hero.get_rect().intersects(card.get_rect()),"feature and result card do not overlap")
		check(page.find_child("DailyScroll",true,false).get_global_rect().encloses(page._race.get_global_rect()),"race action fits without scrolling")
		if size.y >= 720:
			var viewport_bottom: float = page.find_child("DailyScroll",true,false).get_global_rect().end.y
			check(absf(page._stage.get_global_rect().end.y-viewport_bottom) < 2.0,"daily event fills the available height at "+str(size))
		await capture("silver-%dx%d" % [size.x,size.y])
	root.size = Vector2i(1280,720)
	await settle()
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		card._render()
		await settle()
		check(page.find_child("DailyScroll",true,false).get_global_rect().encloses(page._race.get_global_rect()),"translated desktop race action fits: "+locale)
	TranslationServer.set_locale("en")
	GameText.refresh(self)
	card._render()
	for vehicle: String in ["kart","forklift"]:
		app._select_header_vehicle(VehicleCatalog.IDS.find(vehicle))
		await settle()
		check(card._medals.get_child(0 if vehicle == "kart" else 2).selected,"car-specific medal displays "+vehicle)
		await capture("bronze" if vehicle == "kart" else "gold")
	app._select_header_vehicle(0)
	await settle()
	card.standings_button.pressed.emit()
	await settle()
	var dialog: Node = page._standings
	check(dialog != null and dialog.flying_laps and not dialog.busy and dialog._rows.get_child_count() == 2,"view all opens flying-lap standings")
	check(service.calls[-1].contains("/lap-standings?"),"view all requests the same lap metric")
	dialog._select_vehicle(2)
	await settle()
	check(card.vehicle == "forklift" and page._week_strip.vehicle == "forklift","standings car changes update the result card and weekly medals")
	dialog.queue_free()
	app._select_header_vehicle(0)
	await settle()
	check(card.vehicle == "compact" and card.result.passed == 4,"header car selection restores the correct saved result")
	fixture(app.records,DAY,1)
	check(Progress.best(Progress.load_entries(app.records),DAY,VERSION,"compact").passed == 4,"a worse retry never removes a medal")
	fixture(app.records,DAY,9)
	card.refresh()
	page._update_week()
	await settle()
	check(card._medals.get_child(3).tier == 4 and card._medals.get_child(3).selected and card._medals.get_child_count() == 4,"top one percent has a separate platinum laurel award")
	await capture("elite")
	card.vehicle = "electric"
	card.refresh()
	await settle()
	check(card.result.is_empty() and card._time.text == "—" and not card._medals.get_child(0).earned,"changing car cannot show another car's medal or result")
	await capture("no-result")
	service.pending = true
	card.vehicle = "compact"
	card.refresh()
	card.vehicle = "electric"
	card.refresh()
	service.pending = false
	service.released.emit()
	await settle()
	check(card.summary.vehicle_id == "electric" and card.result.is_empty(),"late old-car response cannot restore stale results")
	app.root_ui.hide()
	var narrow := preload("res://ui/track_of_day_page.gd").new()
	narrow.client = service
	narrow.cloud = app.cloud
	narrow.records = app.records
	narrow.page_preview = true
	root.add_child(narrow)
	MenuStyle.fill(narrow)
	await narrow.refresh()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(390,844)
	for locale: String in ["en","de","fi","fr","ja","ko"]:
		TranslationServer.set_locale(locale)
		GameText.refresh(self)
		narrow._race_panel._render()
		await settle()
		var narrow_card: Node = narrow._race_panel
		check(narrow_card.get_global_rect().end.x <= root.get_visible_rect().end.x,"narrow translated result card fits: "+locale)
		(narrow.find_child("DailyScroll",true,false) as ScrollContainer).scroll_vertical = 9999
		await settle()
		check(narrow.find_child("DailyScroll",true,false).get_global_rect().intersects(narrow._race.get_global_rect()),"narrow race action is reachable")
		await capture("portrait-"+locale)
	TranslationServer.set_locale("en")
	app.queue_free()
	narrow.queue_free()
	service.queue_free()
	await process_frame
	print("DAILY_MEDAL_PAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

