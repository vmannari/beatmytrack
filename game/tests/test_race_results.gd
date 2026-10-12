extends SceneTree
## Real AI race plus isolated integration/capture fixtures; never reads owner records.
var checks: int = 0
var failures: int = 0
var capture: bool = false
var app: Node

class StandingsClient extends Node:
	var own: Variant = {"rank":2,"time_ticks":120}
	var tests_available: bool = false
	var paths: Array[String] = []
	var hold: bool = false
	var fail: bool = false
	var position: int = 2
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return tests_available
	func request_api(path: String, _method: int = HTTPClient.METHOD_GET, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold: await get_tree().process_frame
		if fail: return {"ok":false,"status":503,"data":{}}
		if path.contains("/results-comparison"):
			var race: Dictionary = {"board_id":"test-board","metric":"race","population":100,"minimum_ticks":100,"maximum_ticks":140,"own_best_ticks":120 if own != null else null,"bins":[{"from_ticks":100,"to_ticks_exclusive":120,"count":25},{"from_ticks":120,"to_ticks_exclusive":140,"count":45},{"from_ticks":140,"to_ticks_exclusive":160,"count":30}],"comparison":{"position":position,"population":101,"top_percent":20}}
			var lap: Dictionary = {"board_id":"test-board","metric":"best_lap","population":100,"minimum_ticks":1800,"maximum_ticks":2160,"bins":[{"from_ticks":1800,"to_ticks_exclusive":1921,"count":25},{"from_ticks":1921,"to_ticks_exclusive":2042,"count":45},{"from_ticks":2042,"to_ticks_exclusive":2163,"count":30}],"comparison":{"position":position,"population":101,"top_percent":20}}
			return {"ok":true,"data":{"board_id":"test-board","population_scope":"all","race":race,"best_lap":lap}}
		if path.contains("/histogram"):
			if path.contains("metric=best_lap"):
				return {"ok":true,"data":{"metric":"best_lap","test_population":path.contains("/dev/"),"population":100,"minimum_ticks":1800,"maximum_ticks":2160,"bins":[{"from_ticks":1800,"to_ticks_exclusive":1921,"count":25},{"from_ticks":1921,"to_ticks_exclusive":2042,"count":45},{"from_ticks":2042,"to_ticks_exclusive":2163,"count":30}]}}
			return {"ok":true,"data":{"population":3,"minimum_ticks":100,"maximum_ticks":140,"bins":[{"from_ticks":100,"to_ticks_exclusive":120,"count":1},{"from_ticks":120,"to_ticks_exclusive":140,"count":1},{"from_ticks":140,"to_ticks_exclusive":160,"count":1}]}}
		if path.ends_with("/around-me"):
			return {"ok":true,"data":{"population":3,"player":own,"faster_than_percent":50.0 if own != null else null}}
		return {"ok":true,"data":{"board_id":"test-board","population":3}}

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for i: int in range(5): await process_frame

func run() -> void:
	test_rewards()
	test_incidents()
	test_sector_leaders()
	test_lap_personal_best()
	await test_single_lap_pb()
	await test_completion_distributions()
	await test_histogram_tails()
	var interpolation: Dictionary = {"samples":[{"progress":0.0,"elapsed":0.0,"speed":10.0},{"progress":0.5,"elapsed":4.0,"speed":20.0},{"progress":1.0,"elapsed":10.0,"speed":30.0}]}
	check(is_equal_approx(LapTelemetry.at(interpolation,0.75),7.0),"time interpolation uses normalized distance")
	check(is_equal_approx(LapTelemetry.at(interpolation,0.25,"speed"),15.0),"speed interpolation uses normalized distance")
	var explicit: Array[Dictionary] = LapTelemetry.sectors(interpolation,PackedFloat32Array([0,0.25,0.75,1]))
	check(is_equal_approx(explicit[1].time,5.0),"future explicit sector boundaries use same interface")
	var stalled := LapTelemetry.new()
	stalled.begin(Vector2.ZERO)
	var stalled_session := TrackSession.new()
	var stalled_track := NativeTrack.new()
	stalled_track.route_length = 100.0
	for tick: int in range(30000):
		stalled_session.elapsed_ticks = tick
		stalled.observe(stalled_session,stalled_track,Vector2.ZERO,0.0,false)
	check(stalled.samples.size() < LapTelemetry.MAX_SAMPLES and stalled.stride > 6,"very long stalled lap decimates without unbounded memory")
	var directory: String = "user://results_test_"+TrackLibrary.unique_id()
	var library := TrackLibrary.new(directory)
	for i: int in range(3):
		var doc: Dictionary = TrackDocument.create_default()
		doc.id = "results_fixture_"+str(i)
		doc.name = ["Harbor Loop","Pine Ridge","Storm Run"][i]
		doc.theme = ["coast","pine","storm"][i]
		check(library.save_document(doc) == OK,"save isolated recommendation track")
	app = load("res://core/app.tscn").instantiate()
	app.set("library",library)
	app.set("records",LocalRecords.new(directory.path_join("records.json")))
	root.add_child(app)
	while not app.startup_complete: await process_frame
	# This local recommendation fixture must not inherit the owner's public cloud cache.
	app.cloud.root_override = directory.path_join("cloud")
	app.cloud.load_cached()
	# Signed-in storage topology: empty private library, existing circuits shared.
	app.library = TrackLibrary.new(directory.path_join("private_tracks"))
	app.track_catalog = null
	await settle()
	var race_doc: Dictionary = TrackDocument.create_default()
	race_doc.name = "Crescent Run"
	race_doc.points = [[-80.0,-25.0],[-65.0,5.0],[-45.0,15.0],[-25.0,12.0],[-5.0,45.0],[25.0,40.0],[40.0,5.0],[70.0,-5.0],[80.0,-25.0],[40.0,-45.0],[10.0,-35.0],[-30.0,-45.0]]
	race_doc.widths = []
	race_doc.corners = []
	for point: Array in race_doc.points:
		race_doc.widths.append(10.0)
		race_doc.corners.append("smooth")
	race_doc.layout = TrackDocument.road_layout(race_doc)
	var track: NativeTrack = TrackCompiler.compile(race_doc)
	check(track != null,"arbitrary curved creator track compiles")
	track.metadata.cloud_version = "isolated-results-fixture"
	await app._start_race(track,false,true)
	var game: Node = app.get("game")
	track.metadata.erase("cloud_version")
	game.set("rating_records",app.records)
	game.set_physics_process(false)
	game.set("countdown_ticks",0)
	game.set("ai_enabled",true)
	game.call("_physics_process",1.0/120.0)
	check((game.get("track_session") as TrackSession).elapsed_ticks == 1,"normal race observes telemetry outside canonical step")
	# Fast headless driving; identical simulator/session, no presentation overhead.
	var sim: VehicleSimulation = game.get("sim")
	var session: TrackSession = game.get("track_session")
	var telemetry: LapTelemetry = game.get("lap_telemetry")
	var driver := RouteDriver.new()
	for i: int in range(120*300):
		var before: Vector2 = sim.state.position
		sim.step(driver.sample(sim.state,track,game.get("handling")),track)
		session.advance(track,before,sim.state.position,sim.state.route_index,sim.state.track_elevated)
		telemetry.observe(session,track,sim.state.position,sim.state.velocity.length(),false)
		if session.finished: break
	check(session.finished and telemetry.completed.size() == 5,"actual AI driving produces five completed telemetry laps")
	if not session.finished:
		print("RESULTS_TESTS: ",checks," checks, ",failures," failures")
		quit(1)
		return
	for lap: Dictionary in telemetry.completed:
		check(lap.samples.size() > 10 and lap.samples.size() <= LapTelemetry.MAX_SAMPLES+1,"bounded real telemetry")
		check(is_equal_approx(float(lap.samples[0].progress),0) and is_equal_approx(float(lap.samples[-1].progress),1),"lap boundaries cover normalized distance")
		var last: float = -1.0
		var monotonic: bool = true
		for p: Dictionary in lap.samples:
			monotonic = monotonic and float(p.progress) >= last
			last = float(p.progress)
		check(monotonic,"interpolation domain is monotonic")
		var sectors: Array[Dictionary] = LapTelemetry.sectors(lap)
		check(absf(float(sectors[0].time)+float(sectors[1].time)+float(sectors[2].time)-float(lap.duration)) < 0.001,"automatic sector times sum to measured lap duration")
	var result: RaceResultData = RaceResultData.build(track,session.lap_times,telemetry,false)
	check(result.route.size() == 361 and result.route[0].distance_to(track.finish_center) < 1.0,"route is aligned to actual start line")
	check(result.fastest >= 0,"valid race has fastest lap")
	var shortcut_telemetry := LapTelemetry.new()
	shortcut_telemetry.begin(track.finish_center)
	var shortcut_session := TrackSession.new(120,1)
	shortcut_session.shortcut_count = 1
	shortcut_session.completed_laps = 1
	shortcut_session.lap_start_time = 10.0
	shortcut_session.lap_times = [10.0]
	shortcut_telemetry.observe(shortcut_session,track,track.finish_center,20.0,false)
	check(shortcut_telemetry.completed[0].valid,"shortcut does not invalidate completed-lap telemetry")
	var invalid: LapTelemetry = LapTelemetry.new()
	invalid.completed = telemetry.completed.duplicate(true)
	for lap: Dictionary in invalid.completed: lap.valid = false
	check(RaceResultData.build(track,session.lap_times,invalid,false).fastest == -1,"invalid laps never establish fastest reference")
	session.finished = false
	game.set("paused",false)
	game.set("attempt_practice",false)
	game.call("toggle_pause")
	check(bool(game.get("paused")) and not bool(game.get("attempt_practice")),"pausing a race keeps it record-eligible")
	game.call("toggle_pause")
	check(not bool(game.get("paused")) and not bool(game.get("attempt_practice")),"resuming keeps the race record-eligible")
	session.finished = true
	session.shortcut_count = 1
	var ui: Control = app.get("root_ui")
	var store: LocalRecords = app.get("records")
	game.call("_begin_finish")
	var cues: Control = game.get("race_cues")
	check(not cues.rating_panel.visible,"inline rating initially hidden")
	for tick: int in range(89): game.call("_physics_process",1.0/120.0)
	check(not cues.rating_panel.visible,"inline rating waits 0.75 seconds")
	game.call("_physics_process",1.0/120.0)
	check(cues.rating_panel.visible and not ui.visible,"rating appears on track beneath finish sign")
	for tick: int in range(150): game.call("_physics_process",1.0/120.0)
	check(not bool(game.get("paused")),"unrated finish waits past automatic transition")
	await create_timer(0.3).timeout
	await screenshot("track-rating-on-finish")
	(cues.rating_panel.find_child("SkipRating",true,false) as Button).pressed.emit()
	await settle()
	check(store.settings.get("track_ratings",{}).is_empty(),"Skip leaves track unrated")
	check(ui.visible,"Skip continues to results")
	ui.hide()
	(game.get("hud") as PlaygroundHUD).show()
	game.set("paused",false)
	# This fixture begins another attempt on the same Game, as a real retry does.
	app.set("_result_game_id",0)
	game.call("_begin_finish")
	for tick: int in range(90): game.call("_physics_process",1.0/120.0)
	check(cues.rating_panel.visible,"skipped track can be offered again")
	(cues.rating_panel.find_child("Rate4",true,false) as Button).pressed.emit()
	await settle()
	check(ui.visible and not cues.rating_panel.visible,"rating immediately continues to normal results")
	var confirmed: TrackRating = cues.rating_panel.find_child("TrackRating",true,false)
	for i: int in range(5):
		check(confirmed.stars[i].icon == MenuIcon.texture("star_filled" if i < 4 else "star"),"saved local rating fills exactly the selected stars")
		check(confirmed.stars[i].icon_alignment == HORIZONTAL_ALIGNMENT_CENTER and confirmed.stars[i].vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER,"rating icon is centered on both axes")
	confirmed.choose(1)
	# The hidden completed prompt no longer accepts a second rating selection.
	check(confirmed.value() == 4,"completed rating prevents another selection")
	var confirmation_tap := InputEventScreenTouch.new()
	confirmation_tap.pressed = true
	game.call("_unhandled_input",confirmation_tap)
	check(ui.visible,"normal results remain available after rating")
	await screenshot("track-rating-immediate-results")
	var restored := LocalRecords.new(store.path)
	restored.load_records()
	check(int(restored.settings.track_ratings.get(track.identity,0)) == 4,"track rating survives reload")
	check(int(restored.settings.track_ratings.get("another_track",0)) == 0,"rating belongs to specific track")
	game.set("paused",false)
	game.call("_begin_finish")
	check(not bool(game.get("finish_rating_pending")),"already rated track suppresses inline rating")
	for tick: int in range(216): game.call("_physics_process",1.0/120.0)
	await settle()
	check(bool(game.get("paused")),"rated track automatically continues")
	check(ui.find_child("TrackRatingPrompt",true,false) == null,"results never opens a rating popup")
	var panel: RaceResults = ui.find_child("RaceResults",true,false)
	check(panel != null and panel.selected_lap == result.fastest,"integrated screen selects fastest lap")
	check((app.get("records") as LocalRecords).best_for(track,game.get("handling")) == roundi(session.race_time_seconds()*1000.0)/1000.0,"paused race with shortcut history records its actual total")
	check(panel.total == session.race_time_seconds() and panel.laps == session.lap_times,"summary and lap rows receive actual completed times")
	check(panel.find_child("ResultDelta",true,false) != null and panel.find_child("RaceAchievement",true,false) != null,"race time includes direct PB comparison and one earned achievement")
	check(panel.find_child("ResultsActions",true,false).get_child_count() == 2,"results have only two bottom actions")
	check(panel.map.mode == "Time diff" and panel.mode_buttons[0].text == "Track" and panel.mode_buttons[2].text == "Speed","analysis starts with Track in requested order")
	var single_catalog := TrackCatalog.new(library)
	single_catalog.entries = []
	check(RaceRecommendations.suggest(single_catalog,track).is_empty(),"empty catalog has no invented recommendations")
	check(not panel.sector_table.visible and panel.sector_rows.get_child_count() == 12,"sector detail is populated but hidden by default")
	var race_average: String = panel.average_label.text
	panel.select_lap(0)
	check(panel.average_label.text == race_average, "race average remains stable when inspecting another lap")
	var measured: Array[Dictionary] = LapTelemetry.sectors(result.laps[0],result.sector_boundaries)
	var best_sectors: Array[Dictionary] = LapTelemetry.sectors(result.laps[result.fastest],result.sector_boundaries)
	check((panel.sector_rows.get_child(4) as Label).text == "%.2f s" % measured[0].time,"table updates time when lap changes")
	check((panel.sector_rows.get_child(5) as Label).text == "%+.3f" % (float(measured[0].time)-float(best_sectors[0].time)),"table delta uses fastest valid lap sector")
	panel.select_lap(result.fastest)
	panel.select_mode("Time diff")
	check(not panel.sector_table.visible,"sector table hidden outside sectors mode")
	check(panel.map._segment_color(0.5,0,1).is_equal_approx(Color("9bb6c5")),"fastest lap compares neutral against itself")
	panel.select_lap(0)
	var first_lap_sectors: Array[Dictionary] = LapTelemetry.sectors(result.laps[0],result.sector_boundaries)
	for i: int in range(first_lap_sectors.size()):
		var sector_delta: float = float(first_lap_sectors[i].time)-float(best_sectors[i].time)
		var expected_color := Color("ed8056") if sector_delta > 0.0005 else (Color("55dbaa") if sector_delta < -0.0005 else Color("9bb6c5"))
		check(panel.map._sector_color(i).is_equal_approx(expected_color),"sector route colour %d uses delta against fastest lap" % (i+1))
		var table_title := panel.sector_rows.get_child(3+i*3) as Label
		check(table_title.get_theme_color("font_color").is_equal_approx(expected_color),"sector table colour %d matches route delta colour" % (i+1))
	panel.select_mode("Speed")
	# Explicit incident display fixture, separate from the real AI race captures.
	var incident_lap: Dictionary = panel.map.lap.duplicate(true)
	incident_lap.events = [{"kind":"collision","position":result.route[60]}, {"kind":"off_track","position":result.route[220]+Vector2(12,12)}]
	panel.map.show_lap(incident_lap, panel.map.reference)
	await screenshot("incident-markers-1280x720")
	panel.select_lap(result.fastest)
	panel.select_mode("Track")
	await screenshot("track-default-1280x720")
	panel.select_mode("Speed")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = size
		await settle()
		for mode: String in ["Track", "Sectors", "Speed"]:
			panel.select_mode(mode)
			await settle()
			var fixed_map: Rect2 = panel.map.get_global_rect()
			var fixed_route: PackedVector2Array = panel.map.fitted.duplicate()
			var fixed_strip: Rect2 = panel.find_child("LapTimesStrip",true,false).get_global_rect()
			for lap_index: int in range(panel.lap_buttons.size()):
				var pointer := InputEventMouseMotion.new()
				pointer.position = panel.lap_buttons[lap_index].get_global_rect().get_center()
				root.push_input(pointer,true)
				panel.select_lap(lap_index)
				await settle()
				check(panel.map.get_global_rect().is_equal_approx(fixed_map), "map rectangle fixed across lap hover/selection: "+mode)
				check(panel.map.fitted == fixed_route, "route pixels fixed across lap hover/selection: "+mode)
				check(panel.find_child("LapTimesStrip",true,false).get_global_rect().is_equal_approx(fixed_strip), "lap strip and separator stay fixed: "+mode)
				check((panel.lap_buttons[lap_index].get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom == 0, "lap selection has no bottom border")
		panel.select_lap(result.fastest)
		panel.select_mode("Speed")
		await settle()
		var viewport: Rect2 = (app.get("root_ui") as Control).get_global_rect()
		check(viewport.encloses(panel.get_global_rect()),"results fit viewport "+str(size))
		check(is_equal_approx(panel.mode_buttons[0].size.x,panel.mode_buttons[1].size.x) and is_equal_approx(panel.mode_buttons[1].size.x,panel.mode_buttons[2].size.x),"analysis buttons equal width "+str(size))
		check(panel.map.size.x > 350 and panel.map.size.y >= 200,"map has usable area "+str(size))
		for button: Button in panel.lap_buttons:
			check(button.get_global_rect().size.y >= 61,"lap touch target")
			check((button.get_parent() as HBoxContainer).get_global_rect().encloses(button.get_global_rect()),"all five laps visible without scrolling")
		await tap(panel.lap_buttons[1].get_global_rect().get_center())
		check(panel.selected_lap == 1,"lap tap updates selection")
		panel.lap_buttons[result.fastest].pressed.emit()
		await tap(panel.map.global_position+panel.map.fitted[90])
		var drag := InputEventScreenDrag.new()
		drag.position = panel.map.global_position+panel.map.fitted[92]
		root.push_input(drag,true)
		check(panel.map.selected_point >= 0,"route touch picks telemetry point")
		await screenshot("speed-"+str(size.x)+"x"+str(size.y))
		panel.lap_buttons[0].pressed.emit()
		panel.mode_buttons[0].pressed.emit()
		check(panel.map.mode == "Time diff","time comparison mode hooked")
		check(panel.map._segment_color(0.99,0,1).r > panel.map._segment_color(0.99,0,1).g,"slower lap finish is colored as time lost")
		await screenshot("time-diff-"+str(size.x)+"x"+str(size.y))
		panel.mode_buttons[1].pressed.emit()
		check(panel.sector_table.visible, "Sectors mode exposes detailed data")
		await screenshot("sectors-"+str(size.x)+"x"+str(size.y))
		panel.select_mode("Speed")
	# Show both rated and unrated recommendation states in the isolated UI fixture.
	single_catalog.add_local("results_fixture_0")
	store.settings.track_ratings[str(single_catalog.entries[0].id)] = 4
	panel.next_button.pressed.emit()
	var animated_page: RaceComplete = (app.get("root_ui") as Node).find_child("RaceComplete",true,false)
	animated_page.reward_reveal.pause()
	await settle()
	check(animated_page.reward_panels.size() == 2,"only completion and clean rewards appear; ineligible rows omitted")
	check(animated_page.reward_panels[0].modulate.a == 0 and animated_page.reward_total.text == "+ 0","reward reveal begins hidden with zero total")
	animated_page.reward_reveal.custom_step(0.40)
	check(animated_page.revealed_count == 1 and animated_page.reward_panels[1].modulate.a == 0,"reward rows reveal sequentially")
	await screenshot("reward-reveal-first")
	animated_page.reward_reveal.custom_step(10.0)
	check(animated_page.revealed_count == 2 and animated_page.reward_total.text == "+ 250","reveal total finishes at eligible sum")
	check(animated_page.reward_panels[1].modulate.a == 1,"last reward finishes visible")
	var page: Control = (app.get("root_ui") as Node).find_child("RaceComplete",true,false)
	check(page != null and page.visible and not panel.visible,"Continue opens Race Complete")
	check(app.get("game") == game,"Continue preserves completed race without starting another")
	check((page as RaceComplete).recommendations.size() == 3,"Race Complete recommends real local tracks")
	check((page as RaceComplete).recommendations.all(func(item: Dictionary) -> bool: return item.entry.source == "builtin" or (item.entry.get("read_only",false) and item.entry.library_directory == library.directory)), "cold results catalog recommends shared circuits from original directory")
	var rating_row: TrackRating = page.find_child("TrackRating",true,false)
	check(rating_row.value() == 4,"standings show stored personal rating")
	rating_row.stars[2].pressed.emit()
	restored.load_records()
	check(int(restored.settings.track_ratings.get(track.identity,0)) == 3,"standings edits persist")
	for page_size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = page_size
		await settle()
		check((app.get("root_ui") as Control).get_global_rect().encloses(page.get_global_rect()),"Race Complete fits "+str(page_size))
		await screenshot("race-complete-"+str(page_size.x)+"x"+str(page_size.y))
	(page as RaceComplete).cards[2].pressed.emit()
	check((page as RaceComplete).race_button.text.contains(str((page as RaceComplete).recommendations[2].name).to_upper()),"recommendation selects primary race action")
	(page.find_child("BackToResults",true,false) as Button).pressed.emit()
	await settle()
	check(panel.visible and panel.selected_lap == 0,"back preserves results and selected lap")
	(panel.find_child("RetryRace",true,false) as Button).pressed.emit()
	check(not (app.get("root_ui") as Control).visible and (game.get("lap_telemetry") as LapTelemetry).completed.is_empty(),"retry resets telemetry and returns to race")
	app.call("_results")
	await settle()
	panel = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	check(panel.result.laps.is_empty() and panel.average_label.text == "\u2014","empty result shows no fabricated telemetry")
	panel.next_button.pressed.emit()
	await settle()
	page = (app.get("root_ui") as Node).find_child("RaceComplete",true,false)
	(page.find_child("ChooseTrack",true,false) as Button).pressed.emit()
	await settle()
	check(app.get("game") == null and app.get("screen") == "tracks","placeholder track action returns to selection")
	await app.call("_start_race",track,false)
	(app.get("game") as Node).set_physics_process(false)
	app.call("_results")
	await settle()
	panel = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	panel.next_button.pressed.emit()
	await settle()
	var complete_page: RaceComplete = (app.get("root_ui") as Node).find_child("RaceComplete",true,false)
	var shared_index: int = -1
	for index: int in range(complete_page.recommendations.size()):
		if complete_page.recommendations[index].entry.get("read_only",false): shared_index = index
	check(shared_index >= 0, "shared recommendation is available to launch")
	complete_page.cards[maxi(0, shared_index)].pressed.emit()
	check(complete_page.recommendations.any(func(item: Dictionary) -> bool: return item.entry.get("read_only",false)), "results reuse shared circuits after opening Play")
	var recommended_id: String = complete_page.recommendations[maxi(0, shared_index)].entry.id
	complete_page.race_button.pressed.emit()
	for frame: int in range(600):
		await process_frame
		var launched: Node = app.get("game")
		if launched != null and (launched.get("native_track") as NativeTrack).identity == recommended_id: break
	await settle()
	var recommended_game: Node = app.get("game")
	recommended_game.set_physics_process(false)
	check((recommended_game.get("native_track") as NativeTrack).identity == recommended_id,"primary action launches selected recommendation")
	check((recommended_game.get("track_session") as TrackSession).target_laps == 5,"recommended race retains five laps")
	app.call("_results")
	await settle()
	panel = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	panel.next_button.pressed.emit()
	await settle()
	complete_page = (app.get("root_ui") as Node).find_child("RaceComplete",true,false)
	(complete_page.find_child("MainMenu",true,false) as Button).pressed.emit()
	await settle()
	check(app.get("game") == null and app.get("screen") == "tracks","Main Menu leaves race and opens Race discovery")
	app.queue_free()
	await settle()
	print("RESULTS_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func test_rewards() -> void:
	check(RaceRewardPreview.tier(50) == 50 and RaceRewardPreview.tier(25) == 100 and RaceRewardPreview.tier(10) == 200 and RaceRewardPreview.tier(1) == 500,"requested percentile tier boundaries")
	check(RaceRewardPreview.tier(51) == 0 and RaceRewardPreview.tier(-1) == 0,"no award outside known qualifying tiers")
	check(RaceRewardPreview.improved_tier(9,200) == 0,"improving within same tier cannot farm reward")
	check(RaceRewardPreview.improved_tier(25,200) == 0,"regressing tier cannot farm reward")
	check(RaceRewardPreview.improved_tier(10,50) == 200,"jump awards highest newly crossed tier only")
	check(RaceRewardPreview.improved_tier(1,500) == 0,"repeating top one percent earns no tier reward")
	var facts: Dictionary = {"complete":true,"total":90.0,"previous":100.0,"flying":17.0,"previous_lap":18.0,"incident_free":true}
	var rows: Array[Dictionary] = RaceRewardPreview.build(facts)
	check(rows.size() == 9 and RaceRewardPreview.total(rows) == 450,"completion, two new PBs and clean; consistency excluded")
	facts.incident_free = false
	check(RaceRewardPreview.total(RaceRewardPreview.build(facts)) == 250,"collision or off-track blocks clean reward")
	facts.complete = false
	check(RaceRewardPreview.total(RaceRewardPreview.build(facts)) == 0,"incomplete/practice result cannot qualify")

func test_histogram_tails() -> void:
	var bins: Array = [1,0,0,0,3,10,25,40,30,12,4,0,0,0,0,0,0,1]
	var original: Array = bins.duplicate()
	check(TrackDistribution.display_window(bins) == Vector2i(4,10), "sparse long tails cropped around core population")
	check(bins == original, "view cropping preserves original counts")
	check(TrackDistribution.display_window([0,0,1,0,0]) == Vector2i(2,2), "single sample centers without empty tail bins")
	check(TrackDistribution.display_window([1,0,0,1]) == Vector2i(0,3), "two samples are not treated as statistical outliers")
	check(TrackDistribution.display_window([0,3,0,0,0,0,1]) == Vector2i(1,1), "isolated outlier trimmed from tied small sample")
	check(TrackDistribution.display_window([1,2,3,2,1]) == Vector2i(0,4), "ordinary short distribution retains its full range")
	check(TrackDistribution.display_window([]) == Vector2i(0,0), "empty chart range is safe")
	if not capture: return
	var fixture := VBoxContainer.new()
	fixture.position = Vector2(40,30)
	fixture.size = Vector2(1100,620)
	root.add_child(fixture)
	fixture.add_child(MenuStyle.label("HISTOGRAM TAILS / SYNTHETIC TEST FIXTURE",24))
	for marker: int in [7,17]:
		var chart := TrackDistribution.new()
		chart.custom_minimum_size = Vector2(1000,260)
		chart.snapshot = {"bins":bins,"min_ms":50000,"max_ms":220000,"player_bin":marker}
		fixture.add_child(chart)
	await screenshot("histogram-tail-fixture")
	fixture.free()

func test_completion_distributions() -> void:
	var distribution: Dictionary = RaceComplete._local_distribution([10.0001,10.0004],10.0004)
	check(distribution.bins[0] == 2 and distribution.player_bin == 0, "equal displayed times share a histogram bin")
	check(RaceComplete._local_distribution([],0).is_empty(), "no invented histogram for missing local samples")
	var source := RaceResults.new()
	source.laps = [20.0,17.0,18.0]
	source.clean = true
	source.total = 55.0
	root.add_child(source)
	var client := StandingsClient.new()
	root.add_child(client)
	var page := RaceComplete.new()
	page.results = source
	page.facts = {"flying":17.0}
	page.cloud_client = client
	root.add_child(page)
	page.cloud_version = "test-version"
	await page._refresh_rank()
	check(page.race_chart.snapshot.bins == [25,45,30], "verified histogram uses exact server counts")
	check(is_equal_approx(page.race_chart.snapshot.min_ms,100000.0/120.0), "histogram converts canonical ticks to milliseconds")
	check(page.global_rank.text == "POSITION 2" and page.race_context.text.is_empty(), "position uses the comparison field without diagnostic labels")
	check(page.lap_chart.snapshot.bins == [25,45,30] and page.lap_population.text == "POSITION 2", "best-lap chart loads every driver's PB rather than this race's flying laps")
	check(client.paths.any(func(path: String) -> bool: return path.contains("bins=16")), "results requests finer sixteen-bin comparisons")
	check(page.race_chart.snapshot.markers.size() == 2 and page.race_chart.snapshot.markers[0].value_ms == 55000, "server comparison retains this race and the local personal-best markers")
	check(page.race_chart.snapshot.markers[1].value_ms == 1000, "verified personal best from another device updates the best marker")
	var geometry: Dictionary = TrackDistribution.comparison_geometry(page.race_chart.snapshot,400)
	check(geometry.outside[0] == 1 and geometry.marker_x[0] > 8 and geometry.marker_x[0] < 392, "current race outside the field has a visible edge marker")
	client.own = null
	await page._refresh_rank()
	check(page.race_chart.snapshot.bins == [25,45,30] and page.global_rank.text == "POSITION 2", "pending upload compares the current result with the same field")
	check(client.paths[-1].contains("race_from_ticks=100") and client.paths[-1].contains("race_to_ticks=160") and client.paths[-1].contains("lap_from_ticks=1800") and client.paths[-1].contains("lap_to_ticks=2163"),"results pins both displayed bin domains on refresh")
	client.tests_available = true
	page.comparison_scope = "all"
	await page._refresh_rank()
	check(page.race_chart.snapshot.markers.size() == 2, "test population replacement retains both personal markers")
	check(page.lap_context.text.is_empty() and page.lap_chart.snapshot.bins == [25,45,30], "combined comparison retains lap counts without diagnostic captions")
	check(page.lap_chart.snapshot.edges_ms.size() == 4, "test lap histogram retains the exact server bin edges")
	page.results.previous = 52.0
	page.results.best = 52.0
	var separate: Array[Dictionary] = page._comparison_markers("RACE TIME")
	check(separate[0].value_ms == 55000 and separate[1].value_ms == 52000, "slower current race and faster personal best have independent markers")
	var tail_snapshot: Dictionary = {"bins":[10,20,30,25,15],"min_ms":97000.0,"max_ms":110000.0,"markers":separate}
	geometry = TrackDistribution.comparison_geometry(tail_snapshot,400)
	check(geometry.outside == [-1,-1] and geometry.low > 90000, "faster personal markers do not squeeze the comparison bars")
	check(tail_snapshot.bins == [10,20,30,25,15], "markers never add samples to the driver population")
	var race_before: Dictionary = page.race_chart.snapshot.duplicate(true)
	var lap_before: Dictionary = page.lap_chart.snapshot.duplicate(true)
	client.hold = true
	page.call_deferred("_refresh_rank")
	await settle()
	check(page.standings_busy and page.race_chart.snapshot == race_before and page.lap_chart.snapshot == lap_before,"pending network refresh never switches to a local or public chart")
	client.hold = false
	await settle()
	check(page.race_chart.snapshot == race_before and page.lap_chart.snapshot == lap_before,"identical refresh leaves both chart domains and counts stable")
	client.fail = true
	await page._refresh_rank()
	check(page.race_chart.snapshot == race_before and page.lap_chart.snapshot == lap_before,"transient failure preserves the complete last comparison")
	client.fail = false
	client.position = 20
	await page._refresh_rank()
	check(page.global_rank.text == "TOP 20%" and page.lap_population.text == "TOP 20%","outside the top ten shows percentile for each metric")
	check(client.paths.all(func(path: String) -> bool: return path.contains("/results-comparison")),"all result refreshes use one atomic endpoint")
	check(client.paths.all(func(path: String) -> bool: return not path.contains("test_population")),"result requests never offer separate driver-source modes")
	var invalid: Dictionary = page.last_comparison.duplicate(true)
	invalid.best_lap.board_id = "unrelated-board"
	race_before = page.race_chart.snapshot.duplicate(true)
	lap_before = page.lap_chart.snapshot.duplicate(true)
	check(not page._apply_comparison(invalid) and page.race_chart.snapshot == race_before and page.lap_chart.snapshot == lap_before,"mixed-board packet is rejected before either chart changes")
	invalid = page.last_comparison.duplicate(true)
	invalid.population_scope = "public"
	check(not page._apply_comparison(invalid),"refresh cannot substitute a split population for the unified field")
	invalid = page.last_comparison.duplicate(true)
	invalid.best_lap.bins[0].count = 999
	check(not page._apply_comparison(invalid) and page.race_chart.snapshot == race_before,"incomplete or contradictory lap counts cannot partially replace the race chart")
	check(RaceComplete._position_text({"position":10,"population":100,"top_percent":10}) == "POSITION 10","top-ten boundary displays position")
	check(RaceComplete._position_text({"position":11,"population":10000,"top_percent":1}) == "TOP 1%","top-one-percent remains possible outside the top ten")
	check(RaceComplete._position_text({"position":1,"population":1,"top_percent":100}).is_empty(),"solo population never displays rank one of one")
	page.free()
	client.free()
	source.free()

func test_single_lap_pb() -> void:
	for prior: float in [0.0, 21.0, 17.0, 16.0]:
		var panel := RaceResults.new()
		panel.theme = MenuStyle.theme()
		panel.clean = true
		panel.circuit = "Single PB regression"
		panel.vehicle_name = "Compact"
		panel.laps = [20.0, 19.0, 17.0, 18.0, 17.0]
		panel.total = 91.0
		panel.set_meta("reward_facts", {"previous_lap":prior})
		root.add_child(panel)
		var count: int = 0
		for index: int in range(panel.laps.size()):
			var expected: bool = index == 2 and (prior == 0.0 or prior > 17.0)
			check(panel._is_lap_pb(index) == expected, "only one best lap qualifies, including ties and first race")
			check(panel.lap_buttons[index].text.contains("Personal best") == expected, "strip only labels the single record holder")
			check(not panel.lap_buttons[index].text.contains("LAP PB"), "no secondary record claims for superseded laps")
			panel.select_lap(index)
			check(panel.lap_heading.text.contains("PERSONAL BEST") == expected, "heading only labels the single record holder")
			if panel._is_lap_pb(index): count += 1
		check(count == (1 if prior == 0.0 or prior > 17.0 else 0), "exactly one new PB, or none if old record remains")
		if prior == 21.0:
			panel.select_lap(2)
			await screenshot("single-lap-pb-regression")
		panel.free()

func test_lap_personal_best() -> void:
	var panel := RaceResults.new()
	panel.clean = true
	panel.laps = [20.0, 17.0, 19.0]
	panel.set_meta("reward_facts", {"previous_lap":18.0})
	root.add_child(panel)
	check(panel.lap_buttons[1].text.contains("Personal best"), "fastest record lap says Personal best")
	check(panel.lap_heading.text.contains("PERSONAL BEST"), "selected record lap heading says Personal best")
	check(not panel._is_lap_pb(0) and not panel._is_lap_pb(2), "standing start and slower flying lap are not PBs")
	panel.set_meta("reward_facts", {"previous_lap":17.0})
	check(not panel._is_lap_pb(1), "matching a PB is not a new PB")
	panel.set_meta("reward_facts", {"previous_lap":0.0})
	check(panel._is_lap_pb(1), "first valid flying lap establishes a PB")
	panel.clean = false
	check(not panel._is_lap_pb(1), "practice cannot claim a lap PB")
	for button: Button in panel.mode_buttons:
		for state: String in ["normal", "pressed", "focus"]:
			check(button.get_theme_stylebox(state).get_content_margin(SIDE_LEFT) == button.get_theme_stylebox("hover").get_content_margin(SIDE_LEFT), "mode icon padding matches hover: "+state)
	panel.free()
	var view := LapRouteView.new()
	view.size = Vector2(700,300)
	view.route = PackedVector2Array([Vector2(-50,-50),Vector2(50,50)])
	view.framing_points = PackedVector2Array([Vector2(80,80)])
	view.show_lap({"events":[{"position":Vector2(80,80)}]}, {})
	var stable: PackedVector2Array = view.fitted.duplicate()
	view.show_lap({"events":[]}, {})
	check(view.fitted == stable, "switching incident and clean laps preserves race-wide fit")
	view.free()

func test_sector_leaders() -> void:
	var label := Rect2(Vector2(100,80),Vector2(84,36))
	for anchor: Vector2 in [Vector2(20,98),Vector2(220,98),Vector2(142,20),Vector2(142,180),Vector2(20,20)]:
		var endpoint: Vector2 = LapRouteView._leader_end(anchor,label)
		check(label.grow(0.01).has_point(endpoint) and not label.grow(-0.01).has_point(endpoint),"sector leader reaches label boundary")
		var inward: Vector2 = endpoint+(label.get_center()-endpoint).normalized()*0.5
		var outward: Vector2 = endpoint+(endpoint-label.get_center()).normalized()*0.5
		check(label.has_point(inward) and not label.has_point(outward),"sector leader stops at label edge without crossing text")
	var view := LapRouteView.new()
	view.size = Vector2(700,300)
	view.fitted = PackedVector2Array([Vector2(250,30),Vector2(260,40)])
	var legend: Rect2 = view._legend_rect()
	var placed: Rect2 = view._sector_label_rect(Vector2(250,30),[legend])
	check(not placed.grow(4).intersects(legend),"top sector label clears incident legend")
	check(legend.end.x < 220.0,"short Off track legend keeps compact exclusion zone")
	view.route = PackedVector2Array([Vector2(-100,-100),Vector2(-100,100),Vector2(100,100),Vector2(100,-100),Vector2(-100,-100)])
	view._fit()
	for point: Vector2 in view.fitted:
		check(point.x-11 > legend.end.x,"full route stroke stays outside incident legend gutter")
	view.free()

func test_incidents() -> void:
	var track := NativeTrack.new()
	track.grid_width = 20
	track.grid_height = 20
	track.cell_size = 1.0
	track.half_extent = Vector2(10,10)
	track.cells.resize(400)
	track.cells.fill(1)
	track.deck_cells = track.cells.duplicate()
	track.route_length = 100.0
	var state := VehicleState.new()
	var config := HandlingConfig.new()
	var session := TrackSession.new()
	var recorder := LapTelemetry.new()
	recorder.begin(state.position)
	var wheels: Array[int] = []
	for axle: float in [-0.5,0.5]:
		for side: float in [-0.5,0.5]:
			var p := Vector2(config.track_width*side,config.wheelbase*axle)
			wheels.append(floori(10-p.y)*20+floori(p.x+10))
	for count: int in range(1,5):
		track.cells[wheels[count-1]] = 0
		check(not LapTelemetry.fully_off_track(track,state,config),"any remaining on-road tyre prevents full excursion: "+str(count))
	track.cells.fill(1)
	check(LapTelemetry.fully_off_track(track,state,config),"four off-road tyres count")
	state.collision_count = 1
	session.elapsed_ticks = 1
	recorder.observe_incidents(session,track,state,config)
	for tick: int in range(2,40):
		session.elapsed_ticks = tick
		state.collision_count += 1
		recorder.observe_incidents(session,track,state,config)
	check(recorder.events.size() == 2,"sustained collision and excursion each produce one event between speed samples")
	track.cells.fill(0)
	recorder.observe_incidents(session,track,state,config)
	track.cells.fill(1)
	session.elapsed_ticks = 100
	state.collision_count += 1
	recorder.observe_incidents(session,track,state,config)
	check(recorder.events.size() == 4,"separate collision and re-excursion produce new markers")
	session.completed_laps = 1
	session.lap_start_time = 1.0
	session.lap_times = [1.0]
	recorder.observe(session,track,state.position,0.0,false)
	check(recorder.completed[0].events.size() == 4 and recorder.events.is_empty(),"events belong only to completed lap")
	state.track_elevated = true
	track.deck_cells.fill(0)
	check(not LapTelemetry.fully_off_track(track,state,config),"bridge deck prevents ground-level false marker")
	state.track_elevated = false
	state.jump_height = 1.0
	check(not LapTelemetry.fully_off_track(track,state,config),"airborne wheels do not create excursion")

func screenshot(label: String) -> void:
	if not capture: return
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(-100,-100)
	root.push_input(pointer,true)
	await settle()
	await RenderingServer.frame_post_draw
	var path: String = OS.get_environment("BMT_RESULTS_EVIDENCE")
	if path.is_empty(): path = ProjectSettings.globalize_path("res://../docs/evidence/race-results")
	DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path.path_join(label+".png")) == OK,"saved "+label)

func tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	root.push_input(up,true)
	await process_frame
