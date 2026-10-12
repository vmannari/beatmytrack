extends SceneTree
## Result-board coherence, scrolling and native graphical reference evidence.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-track-results-2026-10-08/ui")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+description)

func fixture() -> Dictionary:
	var sample := WeeklyRivalry.new(true)
	var value: Dictionary = {"state":"active","group_id":"fixture","self_id":"driver_2","week":41,
		"ends_at":604800,"server_now":0,"vehicle_id":"compact","tracks":[],"standings":[],
		"points_policy":[30,26,23,20,18,16,14,12,10,8,6,4,2,1,1,1,1,1,1,1]}
	for driver: int in range(20):
		value.standings.append({"id":"driver_%d" % driver,"name":"Driver %d" % driver,"country_code":"FI",
			"rank":driver+1,"points":int(value.points_policy[driver])*5,"completed":5})
	for slot: int in range(5):
		var entries: Array = []
		var order: Array = [[0,2,1],[0,1,2],[2,1,0],[1,2,0],[1,0,2]][slot]
		for driver: int in range(20):
			var place: int = order.find(driver) if driver < 3 else driver
			entries.append({"id":"driver_%d" % driver,"name":"Driver %d" % driver,"country_code":"FI",
				"ticks":12000+place*120,"ms":100000+place*1000,"rank":place+1,"points":value.points_policy[place]})
		value.tracks.append({"board_id":"board_%d" % slot,"entries":entries,
			"entry":{"name":sample.tracks[slot].name,"theme":sample.tracks[slot].theme,"creator":"Beat my track",
			"track_id":"track_%d" % slot,"version_id":"version_%d" % slot,"content_hash":"a".repeat(64),"points":sample.tracks[slot].document.points}})
	for driver: Dictionary in value.standings:
		driver.points = 0
		for track: Dictionary in value.tracks:
			for row: Dictionary in track.entries:
				if row.id == driver.id: driver.points += int(row.points)
	value.standings.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.points) > int(b.points))
	for place: int in range(value.standings.size()): value.standings[place].rank = place+1
	return value

func run() -> void:
	var snapshot: Dictionary = fixture()
	var model := WeeklyRivalry.new()
	model.apply_snapshot(snapshot)
	var original: String = JSON.stringify([model.tracks,model.server_standings])
	model.preview_result(1,11940,99.5)
	var board: Array[Dictionary] = model.result_board(1)
	check(board.size() == 20 and board[0].id == WeeklyRivalry.SELF and board[0].rank == 1 and board[0].ms == 99500,"preview includes the new PB as the first of all twenty entrants")
	check(board[1].rank == 2 and board[2].rank == 3,"every displaced competitor receives the projected rank")
	check(model.last_result.overall_before.rank == 3 and model.last_result.overall_after.rank == 1,"weekly position change derives from all five real-shaped track boards")
	check(JSON.stringify([model.tracks,model.server_standings]) == original,"result table never mutates verified boards or weekly totals")
	check(model.result_board(0)[0].id != WeeklyRivalry.SELF,"a result cannot project onto a different circuit")
	var confirmed: Dictionary = model.last_result.duplicate(true)
	confirmed.erase("provisional")
	model.apply_outcome(confirmed,1)
	check(model.result_board(1)[0].ms == 99500,"confirmed result is visible before the full board refresh")
	model.preview_result(1,12120,101.0)
	board = model.result_board(1)
	check(board[1].rank == 2 and board[2].rank == 2 and board[1].ticks == board[2].ticks,"canonical tied times share the displayed rank")
	model.preview_result(1,13080,109.0)
	check(WeeklyRivalry.self_row(model.result_board(1)).ms == 102000,"a slower attempt keeps the player's weekly best in the table")
	model.last_result = {"ms":99000}
	check(JSON.stringify(model.result_board(1)) == JSON.stringify(model.board(1)),"a rejected or unavailable outcome displays only existing standings")
	var first: Dictionary = snapshot.duplicate(true)
	for track: Dictionary in first.tracks:
		for driver: Dictionary in track.entries:
			if driver.id == first.self_id:
				driver.ms = null; driver.ticks = null; driver.rank = null; driver.points = 0
	for driver: Dictionary in first.standings:
		if driver.id == first.self_id: driver.rank = null; driver.points = 0; driver.completed = 0
	model.apply_snapshot(first)
	model.preview_result(1,15000,125.0)
	check(WeeklyRivalry.self_row(model.result_board(1)).rank == 20,"a first finish inserts an unranked player correctly")
	if DisplayServer.get_name() != "headless": await visuals(snapshot,first)
	print("RIVALRY_RESULT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func settle() -> void:
	for frame: int in range(8): await process_frame

func capture(id: String, dimensions: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save "+id+" native capture")

func visuals(snapshot: Dictionary, first: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(evidence)
	OS.set_environment("BMT_API_URL","")
	var folder: String = "user://rivalry_result_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		app.rivalry.model.apply_snapshot(snapshot)
		app.rivalry.model.preview_result(1,11940,99.5)
		app.rivalry_track = 1
		app.rivalry_section = "result"
		app.rivalry_result_pending = true
		var route := PackedVector2Array()
		for point: Array in app.rivalry.model.tracks[1].document.points: route.append(Vector2(point[0],point[1]))
		var distance: float = 0.0
		for point: int in range(route.size()): distance += route[point].distance_to(route[(point+1)%route.size()])
		app.rivalry_race_details = {"previous":102.0,"clean":true,"laps":5,"distance_m":distance*5,"theme":"desert","route":route}
		app._show_screen("rivalry")
		await settle()
		var page: Control = app.root_ui.find_child("WeeklyRivalryPage",true,false)
		var table: ScrollContainer = page.find_child("RivalryResultStandingsScroll",true,false)
		var right: Control = page.find_child("RivalryResultStandings",true,false)
		var left: Control = page.find_child("RivalryResultDetails",true,false)
		var result_view: WeeklyRivalryResult = page.find_child("RivalryRaceResult",true,false)
		check(absf(left.size.x/(left.size.x+right.size.x)-0.37) < 0.025,"details and standings use the requested 37/63 balance")
		var visible: int = 0
		for row: Control in result_view.rows.get_children():
			if table.get_global_rect().grow(0.5).encloses(row.get_global_rect()): visible += 1
		check(visible == 8,"exactly eight complete driver rows are visible immediately")
		if visible != 8:
			print("ROW_LAYOUT: visible=%d scroll=%s rows=%s first=%s eighth=%s" % [visible,table.get_global_rect(),result_view.rows.get_global_rect(),result_view.rows.get_child(0).get_global_rect(),result_view.rows.get_child(7).get_global_rect()])
		check(page.find_child("RivalryResultDriver_you",true,false) != null,"the player has a dedicated highlighted row")
		check((page.find_child("RivalryResultGap_driver_0",true,false) as Label).text == "+0.500","competitor gap compares to the player's listed time")
		check(page.find_child("RivalryResultNewPB",true,false) != null and (page.find_child("RivalryResultImprovement",true,false) as Label).text == "-2.500 s","PB badge and improvement use the previous personal record")
		check(has_text(page,"5 LAPS") and has_text(page,"DAYLIGHT") and has_text(page,"PACKED SAND"),"facts show the actual five-lap daylight sand configuration")
		check((page.find_child("RivalryResultPoints",true,false) as Label).text == "+7 pts","result summary uses the model's actual weekly points delta")
		check(page.find_child("RivalryResultProvisional",true,false) != null,"verification appears as a small provisional status")
		check(not has_text(page,"EXPECTED TRACK POSITION") and not has_text(page,"Your best result counts. Race again anytime."),"large position panel and redundant explanations are removed")
		var gap: Control = page.find_child("RivalryResultGap_you",true,false)
		var legend: Control = page.find_child("RivalryResultColumn_GAP",true,false)
		check(gap.get_global_rect().end.x <= table.get_v_scroll_bar().get_global_rect().position.x-12.0,"gap leaves a clear scrollbar gutter")
		check(absf(gap.get_global_rect().end.x-legend.get_global_rect().end.x) < 1.0,"gap header and values align")
		var again: Button = page.find_child("RivalryRaceAgain",true,false)
		var back: Button = page.find_child("RivalryResultHome",true,false)
		check(absf(again.global_position.y-back.global_position.y) < 1 and again.get_global_rect().end.x < back.global_position.x,"actions share a horizontal bottom-right row")
		check(root.get_visible_rect().encloses(back.get_global_rect()) and root.get_visible_rect().encloses(again.get_global_rect()) and again.size.y >= 48,"both actions remain visible touch targets")
		var clicks: Array[String] = []
		result_view.retry_requested.connect(func() -> void: clicks.append("retry"))
		result_view.home_requested.connect(func() -> void: clicks.append("home"))
		# Avoid launching a backend race: exercise native pointer dispatch through
		# an isolated view with the app's navigation handlers disconnected.
		for connection: Dictionary in result_view.retry_requested.get_connections():
			if connection.callable.get_object() == page: result_view.retry_requested.disconnect(connection.callable)
		for connection: Dictionary in result_view.home_requested.get_connections():
			if connection.callable.get_object() == page: result_view.home_requested.disconnect(connection.callable)
		await tap(again.get_global_rect().get_center())
		await tap(back.get_global_rect().get_center())
		check(clicks == ["retry","home"],"viewport touches reach both action buttons")
		await capture("provisional",dimensions)
		# Native touch dragging must reach the scroll content, including over rows.
		await drag(table.get_global_rect().get_center(),Vector2(0,-160))
		check(table.scroll_vertical > 0,"touch swiping scrolls the player list")
		var before_wheel: int = table.scroll_vertical
		var wheel := InputEventMouseButton.new()
		wheel.position = table.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await settle()
		check(table.scroll_vertical > before_wheel,"desktop wheel scrolling remains available")
		table.scroll_vertical = 10000
		await settle()
		var last: Control = page.find_child("RivalryResultDriver_driver_19",true,false)
		check(table.get_global_rect().grow(1).encloses(last.get_global_rect()),"scrolling reaches the last entrant")
		await capture("scrolled",dimensions)
		var outcome: Dictionary = app.rivalry.model.last_result.duplicate(true)
		outcome.erase("provisional")
		app.rivalry.model.apply_outcome(outcome,1)
		app.rivalry_result_pending = false
		app._rivalry()
		await settle()
		check(app.root_ui.find_child("RivalryResultProvisional",true,false) == null,"confirmation removes provisional status without a board-refresh wait")
		await capture("confirmed",dimensions)
		app.rivalry.model.apply_snapshot(first)
		app.rivalry.model.preview_result(1,15000,125.0)
		app.rivalry_race_details.previous = 0.0
		app.rivalry_result_pending = true
		app._rivalry()
		await settle()
		check(app.root_ui.find_child("RivalryResultPrevious",true,false) == null and app.root_ui.find_child("RivalryResultNewPB",true,false) != null,"first PB shows no invented previous time")
		var first_table: ScrollContainer = app.root_ui.find_child("RivalryResultStandingsScroll",true,false)
		var first_player: Control = app.root_ui.find_child("RivalryResultDriver_you",true,false)
		check(first_table.get_global_rect().grow(1).encloses(first_player.get_global_rect()),"a low-ranked player is revealed inside the initial scroll viewport")
		await capture("first-finish",dimensions)
		app.rivalry.model.apply_snapshot(snapshot)
		app.rivalry.model.preview_result(1,13080,109.0)
		app.rivalry_race_details.previous = 102.0
		app._rivalry()
		await settle()
		check(app.root_ui.find_child("RivalryResultNewPB",true,false) == null,"slower race never claims a new personal best")
		check((app.root_ui.find_child("RivalryResultGap_driver_0",true,false) as Label).text == "-2.000","faster rivals have negative gaps to the player's weekly best")
		await capture("slower",dimensions)
		app.rivalry.model.last_result = {"ms":109000}
		app.rivalry.error = "This race was not verified. Your weekly best is unchanged."
		app.rivalry_result_pending = false
		app._rivalry()
		await settle()
		check((app.root_ui.find_child("RivalryResultPoints",true,false) as Label).text == "— pts","rejection does not invent an awarded points value")
		await capture("rejected",dimensions)
		app.rivalry.error = ""
	await result_flow(snapshot)
	app.queue_free()
	await process_frame

func result_flow(snapshot: Dictionary) -> void:
	root.size = Vector2i(1280,720)
	app.rivalry.model.apply_snapshot(snapshot)
	app.rivalry_track = 1
	var track: NativeTrack = app.selected_track
	# Disposable normal-game session fixture; no network ticket or upload.
	track.metadata.cloud_version = "rivalry-result-flow-fixture"
	await app._start_race(track,false,true,{"fixture":true})
	var game: Node = app.game
	game.set_physics_process(false)
	game.paused = true
	game.attempt_practice = false
	var previous_laps: Array[float] = [22.0,22.0,22.0,22.0,22.0]
	check(app.records.record(track,game.handling,110.0,previous_laps) == OK,"isolated app flow stores its previous personal best")
	var completed := TrackSession.new()
	completed.completed_laps = 5
	completed.elapsed_ticks = 13080
	completed.lap_start_time = 109.0
	completed.lap_times.assign([22.0,22.0,22.0,22.0,21.0])
	completed.finished = true
	game.track_session = completed
	game.race_completed.emit()
	await settle()
	var normal: RaceResults = app.root_ui.find_child("RaceResults",true,false)
	check(normal != null and app.rivalry_section == "race_results" and app.root_ui.find_child("RivalryRaceResult",true,false) == null,"normal PB and lap summary remains first")
	check(app.rivalry_race_details.previous == 110.0 and app.rivalry_race_details.laps == 5,"completion captures pre-save personal best and actual completed laps")
	check(is_equal_approx(float(app.rivalry_race_details.distance_m),track.route_length*5),"completion captures the native route's actual total race distance")
	await capture("normal-results-first",Vector2i(1280,720))
	normal.continue_requested.emit()
	await settle()
	check(app.rivalry_section == "result" and app.root_ui.find_child("RivalryRaceResult",true,false) != null,"Continue opens the new competition screen")
	check((app.root_ui.find_child("RivalryResultImprovement",true,false) as Label).text == "-1.000 s","rivalry feedback retains the real pre-save personal-best improvement")
	await capture("app-flow",Vector2i(1280,720))

func tap(position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func drag(position: Vector2, motion: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = position
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	for step: int in range(1,9):
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = position+motion*step/8.0
		move.relative = motion/8.0
		root.push_input(move,true)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = position+motion
	up.pressed = false
	root.push_input(up,true)
	await settle()

func has_text(node: Node, text: String) -> bool:
	if node is Label and node.text == text: return true
	for child: Node in node.get_children():
		if has_text(child,text): return true
	return false
