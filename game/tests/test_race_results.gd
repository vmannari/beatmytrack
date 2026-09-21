extends SceneTree
## Real AI race plus isolated integration/capture fixtures; never reads owner records.
var checks: int = 0
var failures: int = 0
var capture: bool = false
var app: Node

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
	app.call("_start_race",track,false)
	var game: Node = app.get("game")
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
		session.advance(track,before,sim.state.position,sim.state.route_index)
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
	var invalid: LapTelemetry = LapTelemetry.new()
	invalid.completed = telemetry.completed.duplicate(true)
	for lap: Dictionary in invalid.completed: lap.valid = false
	check(RaceResultData.build(track,session.lap_times,invalid,false).fastest == -1,"invalid laps never establish fastest reference")
	game.set("paused",true)
	game.emit_signal("race_completed")
	await settle()
	var panel: RaceResults = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	check(panel != null and panel.selected_lap == result.fastest,"integrated screen selects fastest lap")
	check((app.get("records") as LocalRecords).best_for(track,game.get("handling")) == roundi(session.race_time_seconds()*1000.0)/1000.0,"actual race total is recorded under current track and handling")
	check(panel.total == session.race_time_seconds() and panel.laps == session.lap_times,"summary and lap rows receive actual completed times")
	check(panel.recommendations.size() == 3,"three real local recommendations")
	var single_catalog := TrackCatalog.new(library)
	single_catalog.entries = []
	check(RaceRecommendations.suggest(single_catalog,track).is_empty(),"empty catalog has no invented recommendations")
	panel.select_lap(result.fastest)
	panel.select_mode("Time diff")
	check(panel.map._segment_color(0.5,0,1).is_equal_approx(Color("9bb6c5")),"fastest lap compares neutral against itself")
	panel.select_mode("Speed")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = size
		await settle()
		var viewport: Rect2 = (app.get("root_ui") as Control).get_global_rect()
		check(viewport.encloses(panel.get_global_rect()),"results fit viewport "+str(size))
		check(panel.map.size.x > 350 and panel.map.size.y >= 200,"map has usable area "+str(size))
		for button: Button in panel.lap_buttons:
			check(button.get_global_rect().size.y >= 48,"lap touch target")
			check(button.get_global_rect().end.y <= panel.map.get_global_rect().end.y+70,"all five laps visible without scrolling")
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
		panel.mode_buttons[1].pressed.emit()
		check(panel.map.mode == "Time diff","time comparison mode hooked")
		check(panel.map._segment_color(0.99,0,1).r > panel.map._segment_color(0.99,0,1).g,"slower lap finish is colored as time lost")
		await screenshot("time-diff-"+str(size.x)+"x"+str(size.y))
		panel.mode_buttons[2].pressed.emit()
		await screenshot("sectors-"+str(size.x)+"x"+str(size.y))
		panel.select_mode("Speed")
	panel.recommendation_buttons[2].pressed.emit()
	check(panel.next_subtitle.text.contains(panel.recommendations[2].name),"recommendation changes primary action")
	var next_id: String = panel.recommendations[2].entry.id
	panel.next_button.pressed.emit()
	await settle()
	var next_game: Node = app.get("game")
	next_game.set_physics_process(false)
	check((next_game.get("native_track") as NativeTrack).identity == next_id,"Next Race launches selected track")
	check((next_game.get("track_session") as TrackSession).target_laps == 5,"recommendation retains five-lap rule")
	app.call("_results")
	await settle()
	panel = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	panel._open_analysis()
	check(panel.analysis_dialog.visible,"analysis hook opens explanatory destination")
	check(panel.result.laps.is_empty() and panel.average_label.text == "—","empty result shows no fabricated telemetry")
	panel.analysis_dialog.hide()
	panel.retry_requested.emit()
	check(not (app.get("root_ui") as Control).visible and (next_game.get("lap_telemetry") as LapTelemetry).completed.is_empty(),"retry resets telemetry and returns to race")
	app.call("_results")
	await settle()
	panel = (app.get("root_ui") as Node).find_child("RaceResults",true,false)
	panel.return_requested.emit()
	await settle()
	check(app.get("game") == null and app.get("screen") == "tracks","Tracks returns to selection")
	app.queue_free()
	await settle()
	print("RESULTS_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func screenshot(label: String) -> void:
	if not capture: return
	var pointer := InputEventMouseMotion.new()
	pointer.position = Vector2(-100,-100)
	root.push_input(pointer,true)
	await settle()
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../docs/evidence/race-results")
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
