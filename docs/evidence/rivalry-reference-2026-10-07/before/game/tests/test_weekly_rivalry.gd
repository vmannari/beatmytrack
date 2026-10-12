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
	if node is Control and node.name == "RivalryDataNotice":
		check(app.menu_body_slot.get_global_rect().grow(1).encloses(node.get_global_rect()),"rivalry status notice fits "+str(app.rivalry_section)+" "+str(node.get_global_rect())+" within "+str(app.menu_body_slot.get_global_rect()))
	if node is Button and node.is_visible_in_tree():
		var rectangle: Rect2 = node.get_global_rect()
		check(bounds.grow(1).encloses(rectangle),str(node.name)+" stays inside the viewport")
		check(rectangle.size.y >= 48,str(node.name)+" retains a touch target")
	for child: Node in node.get_children(): inspect(child,bounds)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	folder = "user://weekly_rivalry_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-hub-2026-10-07/ui")
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
		await capture("overview",dimensions)
		for slot: int in range(5):
			var choose: Button = app.root_ui.find_child("SelectRivalryTrack_"+str(slot),true,false)
			var race: Button = app.root_ui.find_child("RivalryRaceTrack_"+str(slot),true,false)
			check(choose != null and race != null,"overview exposes every circuit and its direct Race action")
			check(app.menu_body_slot.get_global_rect().encloses(choose.get_global_rect()),"all five circuits are visible immediately")
			choose.pressed.emit()
			var page: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
			check(page.selected == slot and page.race_selection.text.contains(str(page.model.tracks[slot].name).to_upper()),"selecting a circuit updates the main Race action")
			var launch: Array[int] = []
			page.race_requested.connect(func(index: int, _ghost: int) -> void: launch.append(index))
			race.pressed.emit()
			check(launch.back() == slot,"each overview Race action launches its own circuit")
		(app.root_ui.find_child("RivalryTab_tracks",true,false) as Button).pressed.emit()
		await settle()
		(app.root_ui.find_child("OpenRivalryTrack_2",true,false) as Button).pressed.emit()
		await settle()
		check(app.rivalry_section == "detail" and app.rivalry_track == 2,"track details retain their selected circuit")
		app.rivalry_track = 2
		app._rivalry()
		await settle()
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		await capture("track-detail",dimensions)
		(app.root_ui.find_child("RivalryBackToTracks",true,false) as Button).pressed.emit()
		await settle()
		check(app.rivalry_section == "tracks","drill-down returns directly to Tracks")
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
		await capture("tracks",dimensions)
		(app.root_ui.find_child("RivalryTab_standings",true,false) as Button).pressed.emit()
		await settle()
		check(app.rivalry_section == "standings","persistent navigation opens Standings")
		await capture("standings",dimensions)
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
		app.rivalry_section = "standings"
		app._rivalry()
		await settle()
		check(app.root_ui.find_child("RivalryStandingsScroll",true,false) != null,"20 real entrants remain accessible in scrolling standings")
		inspect(app.root_ui,Rect2(Vector2.ZERO,root.get_visible_rect().size))
	app.queue_free()
	await process_frame
	print("WEEKLY_RIVALRY_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
