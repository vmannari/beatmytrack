extends SceneTree
## Isolated menu evidence. Sample rivalry is never a shipping fallback.
var checks: int = 0
var failures: int = 0
var app: Node
var folder: String
var evidence: String
const Adapter = preload("res://backend/weekly_rivalry_client.gd")

func forming_snapshot(count: int = 20) -> Dictionary:
	var fixture := WeeklyRivalry.new(true)
	var drivers: Array = []
	for index: int in range(count):
		drivers.append({"id":"entrant_"+str(index),"name":"A driver with a long username" if index else "You","rank":null,"points":0,"completed":0})
	var value: Dictionary = {"state":"active","group_id":"group","self_id":"entrant_0","week":40,"ends_at":604800,"server_now":0,"placement":true,"group_forming":count < 10,"tracks":[],"standings":drivers}
	for index: int in range(5):
		var entries: Array = []
		for driver: Dictionary in drivers:
			var row: Dictionary = driver.duplicate()
			row.ms = null
			entries.append(row)
		value.tracks.append({"board_id":"board_"+str(index),"entries":entries,"entry":{"name":fixture.tracks[index].name,"creator":"Beat my track","track_id":"track_"+str(index),"version_id":"version_"+str(index),"content_hash":"a".repeat(64),"theme":fixture.tracks[index].theme,"points":fixture.tracks[index].document.points}})
	return value

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+text)

func settle() -> void:
	for _frame: int in range(5): await process_frame

func capture(id: String, dimensions: Vector2i) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save "+id+" screenshot")

func inspect(node: Node, bounds: Rect2) -> void:
	if node is Button and node.is_visible_in_tree():
		var rectangle: Rect2 = node.get_global_rect()
		check(bounds.grow(1).encloses(rectangle),str(node.name)+" stays inside the viewport")
		check(rectangle.size.y >= 48,str(node.name)+" retains a touch target")
	for child: Node in node.get_children(): inspect(child,bounds)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	folder = "user://weekly_rivalry_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-navigation-2026-10-09/ui")
	if DisplayServer.get_name() != "headless": DirAccess.make_dir_recursive_absolute(evidence)
	check(WeeklyRivalry.new().tracks.is_empty(),"shipping rivalry never seeds sample players")
	var fixture := WeeklyRivalry.new(true)
	check(fixture.board(2).size() == 14 and fixture.gaps(2).own.rank == 4,"concept has a bounded 14-driver field")
	check(fixture.gaps(1).own.rank == 1,"leading track uses a leading state")
	check(WeeklyRivalry.self_row(fixture.standing()).points == 113,"overall points equal the sum of track points")
	var result: Dictionary = fixture.submit(2,84.100)
	check(result.before.rank == 4 and result.after.rank == 3 and result.points_delta == 3,"PB improvement updates rank and points together")
	check(Adapter.valid_outcome(result) and not Adapter.valid_outcome({"improved":true}),"incomplete server results cannot enter result feedback")
	var unranked: Dictionary = forming_snapshot()
	check(Adapter.valid_snapshot(unranked),"a real field may have no times yet")
	var malformed: Dictionary = unranked.duplicate(true)
	malformed.tracks[0].erase("board_id")
	check(not Adapter.valid_snapshot(malformed),"missing pinned board rejects the whole snapshot")
	check(fixture.submit(2,90.0).points_delta == 0,"slower retry earns no rivalry points")
	fixture.completed = true
	check(fixture.submit(2,80.0).is_empty(),"complete week rejects further concept results")
	fixture.next_week()
	check(fixture.week == 28 and not fixture.completed,"continue resets only the concept fixture")
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		app._show_screen("tracks")
		await settle()
		var trophy: Button = app.root_ui.find_child("Mode_trophy",true,false)
		check(trophy != null and not trophy.disabled,"Free Race exposes enabled Weekly Rivalry trophy")
		trophy.pressed.emit()
		await settle()
		check(app.screen == "rivalry","trophy opens rivalry inside Race")
		check(app.root_ui.find_child("Tab_tracks",true,false) != null and app.root_ui.find_child("Tab_rivalry",true,false) == null,"rivalry adds no top-level tab")
		await capture("sign-in",dimensions)
		app.rivalry.model = WeeklyRivalry.new(true)
		app.rivalry.model.status = "active"
		app.rivalry.error = ""
		app.rivalry_section = "overview"
		app._rivalry()
		await settle()
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		var winner: Control = app.root_ui.find_child("RivalryPodium_1",true,false)
		var runner: Control = app.root_ui.find_child("RivalryPodium_2",true,false)
		check(winner.size.y > runner.size.y and winner.position.y < runner.position.y,"centre winner has a taller podium card")
		check(app.root_ui.find_child("RivalryPodiumCar_1",true,false) != null,"podium shows the fictional vehicle artwork")
		var left_panel: Control = app.root_ui.find_child("RivalryDriversPanel",true,false)
		var right_panel: Control = app.root_ui.find_child("RivalryTracksPanel",true,false)
		check(absf(left_panel.get_global_rect().end.y-right_panel.get_global_rect().end.y) < 1.0,"main panel bottom edges align")
		var player_points: Label = app.root_ui.find_child("RivalryPlayerPoints_you",true,false)
		check(player_points.text == str(int(WeeklyRivalry.self_row(app.rivalry.model.standing()).points)),"highlighted player row shows the model points")
		var player_row: Control = app.root_ui.find_child("Driver_you",true,false)
		var table_scroll: Control = app.root_ui.find_child("RivalryStandingsScroll",true,false)
		check(table_scroll.get_global_rect().grow(1).encloses(player_row.get_global_rect()),"the highlighted player row is visible within the standings viewport")
		var gap_header: Control = app.root_ui.find_child("RivalryColumn_GAP",true,false)
		var player_gap: Control = app.root_ui.find_child("RivalryPlayerGap_you",true,false)
		var bar: VScrollBar = (table_scroll as ScrollContainer).get_v_scroll_bar()
		check(player_gap.get_global_rect().end.x <= bar.get_global_rect().position.x-12.0,"gap values leave clear space before the scrollbar")
		check(gap_header.get_global_rect().end.x <= bar.get_global_rect().position.x-12.0,"gap heading stays clear of the scrollbar")
		check(absf(gap_header.get_global_rect().end.x-player_gap.get_global_rect().end.x) <= 1.0,"gap heading and values share their right edge")
		check(app.root_ui.find_child("RivalryDataNotice",true,false) == null,"no debug footer remains")
		check(app.root_ui.find_child("RivalryFloatingNavigation",true,false) == null,"overview needs no redundant section tabs")
		check(app.root_ui.find_child("RivalryStartRace",true,false) == null and app.root_ui.find_child("RivalryRaceSelected",true,false) == null,"race starts only from track details")
		var car_image: Image = WeeklyRivalryPage.COMPACT_ART.get_image()
		check(car_image.detect_alpha() != Image.ALPHA_NONE,"compact podium art keeps genuine alpha")
		await capture("overview",dimensions)
		for slot: int in range(5):
			var choose: Button = app.root_ui.find_child("SelectRivalryTrack_"+str(slot),true,false)
			var open: Button = app.root_ui.find_child("OpenRivalryTrack_"+str(slot),true,false)
			check(choose != null and open != null,"overview exposes every circuit and its detail action")
			check(app.menu_body_slot.get_global_rect().encloses(choose.get_global_rect()),"all five circuits are visible immediately")
			var overview: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
			var early_launch: Array[int] = []
			overview.race_requested.connect(func(index: int, _ghost: int) -> void: early_launch.append(index))
			choose.grab_focus()
			await settle()
			check(app.rivalry_section == "overview" and app.rivalry_track == slot,"keyboard focus remembers the track without opening it")
			choose.pressed.emit()
			await settle()
			check(app.rivalry_section == "detail" and app.rivalry_track == slot and early_launch.is_empty(),"selecting a track opens its details without starting a race")
			var page: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
			check(page.selected == slot and app.root_ui.find_child("RivalryFloatingNavigation",true,false) == null,"track detail keeps the chosen circuit without redundant tabs")
			var selector: OptionButton = app.root_ui.find_child("RivalryGhostSelector",true,false)
			selector.select(3)
			selector.item_selected.emit(3)
			var launch: Array[int] = []
			page.race_requested.connect(func(index: int, ghost: int) -> void: launch.append_array([index,ghost]))
			(app.root_ui.find_child("RivalryStartRace",true,false) as Button).pressed.emit()
			check(launch == [slot,3],"detail starts the chosen track with the selected ghost option")
			inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
			if slot == 2: await capture("track-detail",dimensions)
			(app.root_ui.find_child("RivalryBackToOverview",true,false) as Button).pressed.emit()
			await settle()
			check(app.rivalry_section == "overview" and app.rivalry_track == slot,"Back to Rivalry returns to the overview and remembers the track")
			(app.root_ui.find_child("OpenRivalryTrack_"+str(slot),true,false) as Button).pressed.emit()
			await settle()
			check(app.rivalry_section == "detail" and app.rivalry_track == slot,"the row arrow opens the same track details")
			(app.root_ui.find_child("RivalryBackToOverview",true,false) as Button).pressed.emit()
			await settle()
		app.rivalry.model.tracks[2].available = false
		app._rivalry()
		await settle()
		var unavailable: Button = app.root_ui.find_child("OpenRivalryTrack_2",true,false)
		check(not unavailable.disabled,"an unavailable track remains open for inspection")
		unavailable.pressed.emit()
		await settle()
		check((app.root_ui.find_child("RivalryStartRace",true,false) as Button).disabled,"track details retain the unavailable-race gate")
		app.rivalry.model.tracks[2].available = true
		app.rivalry.busy = true
		app._rivalry()
		await settle()
		check((app.root_ui.find_child("RivalryStartRace",true,false) as Button).disabled,"busy track details cannot issue another race")
		app.rivalry.busy = false
		app.rivalry.model.submit(2,84.100)
		app.rivalry_section = "result"
		app._rivalry()
		await settle()
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		await capture("race-result",dimensions)
		app.rivalry_result_pending = true
		app._rivalry()
		await settle()
		await capture("verification-pending",dimensions)
		app.rivalry_result_pending = false
		app.rivalry.model.completed = true
		app.rivalry_section = "overview"
		app._rivalry()
		await settle()
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		await capture("weekly-finale",dimensions)
		check(app.root_ui.find_child("RivalryPodium",true,false) != null,"weekly finale is an Overview state")
		(app.root_ui.find_child("SelectRivalryTrack_2",true,false) as Button).pressed.emit()
		await settle()
		check(app.rivalry_section == "detail" and (app.root_ui.find_child("RivalryStartRace",true,false) as Button).disabled,"completed-week rows open details but cannot start another race")
		(app.root_ui.find_child("RivalryBackToOverview",true,false) as Button).pressed.emit()
		await settle()
		(app.root_ui.find_child("Mode_flag",true,false) as Button).pressed.emit()
		await settle()
		check(app.screen == "tracks" and app.race_area_mode == "free","mode rail returns to Free Race")
		app.rivalry.model = WeeklyRivalry.new()
		app.rivalry.model.apply_snapshot(forming_snapshot(3))
		app.rivalry_section = "overview"
		app._show_screen("rivalry")
		await settle()
		check(app.rivalry.model.gaps(0).own.rank == null and app.rivalry.model.overall_gaps().behind.is_empty(),"uncompleted drivers do not produce invented position gaps")
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		await capture("forming-group",dimensions)
		app.rivalry_section = "detail"
		app._rivalry()
		await settle()
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		var selector: OptionButton = app.root_ui.find_child("RivalryGhostSelector",true,false)
		check(selector.selected == 3 and selector.is_item_disabled(0),"missing recordings start with No ghost")
		app.rivalry.model.apply_snapshot(unranked)
		app.rivalry_section = "overview"
		app._rivalry()
		await settle()
		check(app.root_ui.find_child("RivalryStandingsScroll",true,false) != null,"20 real entrants remain accessible in scrolling standings")
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
	app.queue_free()
	await process_frame
	print("WEEKLY_RIVALRY_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
