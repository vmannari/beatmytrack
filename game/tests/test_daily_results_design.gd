extends SceneTree
const Results = preload("res://ui/daily_elimination_results.gd")
const Rules = preload("res://race/daily_elimination.gd")
const DAY: int = 20759
var checks: int = 0
var failures: int = 0
var service: Service
var output: String

class Service extends Node:
	signal identity_changed
	signal released
	signal race_verified
	var player: Dictionary = {"id":"owner","display_name":"Ville","country_code":"FI"}
	var authenticated: bool = true
	var pending: bool = false
	var response: Dictionary = {}
	var calls: Array[String] = []
	var canceled: Array[int] = []
	func signed_in() -> bool: return authenticated
	func base_url() -> String: return "http://daily-results.invalid"
	func cancel_public_reads(owner: int) -> void: canceled.append(owner)
	func request_public(path: String, _owner: int) -> Dictionary: return await request_api(path,0,{},"",false)
	func request_api(path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		calls.append(path)
		var captured: Dictionary = response.duplicate(true)
		if "/lap-standings?" in path and "around=true" not in path and captured.get("ok",false) and captured.get("data",{}).get("comparison") is Dictionary:
			# Full pages return original verified ranks; nearby rows include the candidate.
			for item: Dictionary in captured.data.items:
				if int(item.time_ticks) > int(captured.data.comparison.candidate_ticks): item.rank = int(item.rank)-1
		if pending: await released
		return captured

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for frame: int in range(10): await process_frame

func fixture() -> Dictionary:
	return {"ok":true,"status":200,"data":{"day":DAY,"version_id":"daily-results","vehicle_id":"compact",
		"ends_at":(DAY+1)*86400,"server_now":DAY*86400+3600,"tick_rate":120,"population":1284,
		"comparison":{"position":8,"population":1284,"candidate_ticks":2499,"top_percent":1},
		"items":[{"player_id":"mika","display_name":"Mika","country_code":"SE","rank":7,"time_ticks":2495,"gap_ticks":0},
			{"player_id":"antti","display_name":"Antti","country_code":"FR","rank":9,"time_ticks":2507,"gap_ticks":12}]}}

func make_result(passed: int = 9) -> Control:
	var result := Results.new()
	result.rules = Rules.new()
	result.rules.passed = passed
	result.rules.complete = passed == 9
	result.rules.eliminated = passed < 9
	result.session = TrackSession.new(120,10)
	result.session.lap_times.assign([10.0,22.261,25.032,25.460,20.823,24.349,25.383,21.168,28.292,26.207])
	if passed < 9: result.session.lap_times.resize(passed+2)
	result.client = service
	result.cloud = service
	result.day = DAY
	result.version = "daily-results"
	result.vehicle = "compact"
	result.track_name = "Lantern Village"
	return result

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"native capture "+name)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("Daily results deadline"); quit(1))
	root.gui_embed_subwindows = true
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	output = OS.get_environment("BMT_DAILY_RESULTS_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	service = Service.new()
	root.add_child(service)
	service.response = fixture()
	var result: Control = make_result()
	root.add_child(result)
	await settle()
	var board: Node = result.find_child("DailyResultsStandings",true,false)
	check(board._rows.get_child_count() == 3,"nearby rows include the completed attempt")
	check(board._position.text == "#8 / 1284","attempt comparison supplies the position")
	check(result.find_child("DailyResultBestLap",true,false).text == "0:20.823","opening lap excluded from displayed best")
	var own: Node = board.find_child("DailyResultStandingSelf",true,false)
	check(own.get_child(0).get_child(2).text == "0:20.823","self row preserves exact milliseconds rather than rounded ticks")
	check(own.find_child("PlayerCountryFlag",true,false).get_meta("country_code") == "FI","attempt row uses the signed-in player's country")
	check(board._rows.get_child(0).find_child("PlayerCountryFlag",true,false).get_meta("country_code") == "SE","nearby driver uses service country metadata")
	check(board._rows.get_child(2).find_child("PlayerCountryFlag",true,false).get_meta("country_code") == "FR","second nearby driver retains its own country")
	check("vehicle_id=compact" in service.calls.back() and "lap_ticks=2499" in service.calls.back(),"comparison pins the raced car and this attempt")
	var rail: Node = result.find_child("DailyStageRail",true,false)
	check(rail.get_child_count() == 9,"exactly nine stage segments")
	for index: int in range(9):
		var medal: Node = rail.get_child(index).get_child(0).get_child(0)
		check(medal.tier == [1,0,0,2,0,3,0,0,4][index],"medals at stages 1, 4, 6, 9")
	var actions := {"retry":false,"back":false}
	result.retry_requested.connect(func() -> void: actions.retry = true)
	result.return_requested.connect(func() -> void: actions.back = true)
	result.find_child("DailyRetryRace",true,false).pressed.emit()
	result.find_child("DailyReturn",true,false).pressed.emit()
	check(actions.retry and actions.back,"native retry and return signals retained")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540),Vector2i(844,390),Vector2i(390,844)]:
		root.size = extent
		await settle()
		var grid: Control = result.find_child("DailyLapGrid",true,false)
		check(grid.get_global_rect().end.x <= extent.x,"lap grid fits "+str(extent))
		check(result.find_child("DailyResultsStandings",true,false).get_global_rect().end.x <= extent.x,"standings fit "+str(extent))
		for id: String in ["DailyReturn","DailyRetryRace"]:
			var button: Control = result.find_child(id,true,false)
			check(button.get_global_rect().end.y <= extent.y and button.get_global_rect().end.x <= extent.x,"persistent action fits "+str(extent))
		var back: Control = result.find_child("DailyReturn",true,false)
		var retry: Control = result.find_child("DailyRetryRace",true,false)
		check(back.text == "Back" and is_equal_approx(retry.position.x-back.get_rect().end.x,12.0),"Back sits directly beside Race again "+str(extent))
		await capture("elite-%dx%d" % [extent.x,extent.y])
	root.size = Vector2i(1280,720)
	await settle()
	result.find_child("DailyResultsStandingsButton",true,false).pressed.emit()
	await settle()
	check(result.get_node_or_null("DailyStandings") != null,"View full standings opens real dialog")
	var dialog: Node = result.get_node("DailyStandings")
	check(dialog._rows.get_child_count() == 3 and dialog._rows.get_child(0).find_child("PlayerCountryFlag",true,false).get_meta("country_code") == "SE","full standings retain competitors and insert the completed attempt")
	check(dialog._rows.get_child(1).name == "DailySelfRow" and dialog._rows.get_child(2).get_child(0).get_child(0).text == "9","full board keeps candidate rank and shifts slower competitors")
	check(dialog._own.find_child("DailyComparisonPosition",true,false).text == "#8 / 1284","full board pins the same comparison position")
	check(dialog._rows.get_child(1).get_child(0).get_child(2).text == "0:20.823","full board preserves exact attempt milliseconds")
	check("lap_ticks=2499" in service.calls.back(),"full standings query includes the raced lap")
	await capture("full-standings-flags")
	dialog._select_vehicle(1)
	await settle()
	check(dialog._candidate == 0.0 and "lap_ticks" not in service.calls.back(),"another car cannot inherit the raced lap")
	dialog._select_vehicle(0)
	await settle()
	check(dialog._candidate == 20.823,"returning to the raced car restores the attempt")
	service.player = {"id":"another-account"}
	service.identity_changed.emit()
	await settle()
	check(dialog._candidate == 0.0,"account switch removes the private attempt")
	service.player = {"id":"owner","display_name":"Ville","country_code":"FI"}
	service.identity_changed.emit()
	await settle()
	result.get_node("DailyStandings").queue_free()
	await settle()
	service.response = {"ok":false,"status":503}
	board.refresh()
	await settle()
	check(board._rows.get_child_count() == 0 and board._refresh.visible,"failed read clears standings and offers retry")
	await capture("standings-error")
	service.response = fixture()
	board._refresh.pressed.emit()
	await settle()
	check(board._rows.get_child_count() == 3,"retry recovers inline standings")
	var invalid: Dictionary = fixture()
	invalid.data.comparison.candidate_ticks = 2400
	service.response = invalid
	board.refresh()
	await settle()
	check(board._rows.get_child_count() == 0 and board._position.text == "—","wrong candidate cannot replace attempt rank")
	for field: String in ["vehicle_id","version_id","day","ends_at"]:
		invalid = fixture()
		invalid.data[field] = -1 if field in ["day","ends_at"] else "wrong"
		service.response = invalid
		board.refresh()
		await settle()
		check(board._rows.get_child_count() == 0,"reject mismatched scope "+field)
	service.pending = true
	service.response = fixture()
	board.refresh()
	await settle()
	check(board._rows.get_child_count() == 0 and board._busy,"loading does not retain old rows")
	service.player = {"id":"new-account"}
	service.authenticated = false
	service.response = {"ok":false,"status":503}
	service.identity_changed.emit()
	service.released.emit()
	await settle()
	check(board._rows.get_child_count() == 0 and board._refresh.visible,"old account response cannot repaint guest board")
	service.pending = false
	service.response = fixture()
	board.refresh()
	await settle()
	check(board._rows.get_child_count() == 3,"guest can compare this lap without uploading it")
	check(board.find_child("DailyResultStandingSelf",true,false).find_child("PlayerCountryFlag",true,false).get_meta("country_code") == "","guest has neutral country rather than a borrowed flag")
	service.response = fixture()
	service.response.data.items.append({"player_id":"owner","display_name":"Older PB","rank":1,"time_ticks":2300})
	service.authenticated = true
	service.player = {"id":"owner"}
	board.refresh()
	await settle()
	check(board._rows.get_child_count() == 3,"older own PB cannot duplicate or replace current attempt")
	board._server_now = (DAY+1)*86400
	board._process(0.0)
	check(board._expired and board._rows.get_child_count() == 0 and board._view.disabled,"midnight removes stale standings")
	await capture("standings-expired")
	result.queue_free()
	await settle()
	check(not service.canceled.is_empty(),"closing cancels owned public reads")
	for passed: int in [0,1,4,6]:
		service.response = {"ok":false,"status":503}
		result = make_result(passed)
		root.add_child(result)
		await settle()
		check(result.find_child("DailyLapGrid",true,false).get_child_count() == passed+1,"eliminated attempt includes failed flying lap")
		await capture("stages-%d" % passed)
		result.queue_free()
		await settle()
	# Real translations exercise minimum widths, action labels and fallback glyphs.
	for locale: String in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]:
		TranslationServer.set_locale(locale)
		result = make_result()
		root.add_child(result)
		for extent: Vector2i in [Vector2i(390,844),Vector2i(960,540),Vector2i(1280,720)]:
			root.size = extent
			await settle()
			check(result.find_child("DailyLapGrid",true,false).get_global_rect().end.x <= extent.x,"translated grid fits "+locale+str(extent))
			check(result.find_child("DailyRetryRace",true,false).get_global_rect().end.x <= extent.x,"translated actions fit "+locale+str(extent))
			check(result.find_child("DailyResultsStandings",true,false).get_global_rect().end.x <= extent.x,"translated standings fit "+locale+str(extent))
		result.queue_free()
		await settle()
	TranslationServer.set_locale("en")
	service.queue_free()
	await settle()
	print("DAILY_RESULTS_DESIGN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
