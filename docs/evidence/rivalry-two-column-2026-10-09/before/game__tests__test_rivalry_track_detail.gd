extends SceneTree
## Isolated data/interaction checks and native captures for the track detail.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = "res://../docs/evidence/rivalry-track-detail-2026-10-09/ui"
const Standings = preload("res://ui/rivalry_track_standings.gd")

class GhostProbe extends Node:
	var model: WeeklyRivalry
	var driver: String
	func prefetch_ghost(_slot: int, value: String) -> void: driver = value
	func cached_ghost(_slot: int, value: String) -> Dictionary: return {"driver":value}

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func settle() -> void:
	for _frame: int in range(6): await process_frame

func capture(id: String, dimensions: Vector2i) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(id+"-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"save "+id)

func table() -> VBoxContainer: return app.root_ui.find_child("RivalryTrackStandings",true,false)

func check_rows() -> void:
	var list: VBoxContainer = table()
	check(list.rows.get_child_count() == app.rivalry.model.board(app.rivalry_track).size(),"every driver remains in the ordered scrolling board")
	var shown: int = 0
	var bounds: Rect2 = list.scroll.get_global_rect()
	for row: Control in list.rows.get_children():
		if bounds.grow(0.5).encloses(row.get_global_rect()): shown += 1
		check(row.get_global_rect().end.x <= list.scroll.get_v_scroll_bar().get_global_rect().position.x-8,"row leaves the scrollbar gutter")
	check(shown == 8,"eight complete rows fit the initial viewport")
	check(list.more.text == "↓  6 more drivers","fourteen entrants expose the remaining six")
	check(bounds.position.y-(list.get_parent().get_child(1) as Control).get_global_rect().end.y <= 11,"standings begin directly below the rank")
	check(list.player != null and not list.sticky.visible,"visible player needs no duplicate pinned row")
	var own: Dictionary = WeeklyRivalry.self_row(app.rivalry.model.board(app.rivalry_track))
	for driver: Dictionary in app.rivalry.model.board(app.rivalry_track):
		var row: Control = list.rows.find_child("RivalryTrackDriver_"+str(driver.id),false,false)
		var expected: String = "—" if driver.id == WeeklyRivalry.SELF else "%+.3f" % ((int(driver.ms)-int(own.ms))/1000.0)
		check((row.find_child("Gap",true,false) as Label).text == expected,"signed millisecond gap uses the player's actual result")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = ProjectSettings.globalize_path(evidence)
	if DisplayServer.get_name() != "headless": DirAccess.make_dir_recursive_absolute(evidence)
	var folder: String = "user://rivalry_detail_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		var model := WeeklyRivalry.new(true)
		var countries: Array[String] = ["FI","AU","DE","ES","GB","US","FR","SE","CA","JP","IT","NO","NL","BR"]
		for track: Dictionary in model.tracks:
			for index: int in range(track.entries.size()):
				track.entries[index].country_code = countries[index]
				track.entries[index].driver_id = track.entries[index].id
		app.rivalry.model = model
		app.rivalry_section = "detail"
		app.rivalry_track = 1
		app.rivalry_ghost_choice = 0
		app._show_screen("rivalry")
		await settle()
		check_rows()
		var page: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
		var selector: OptionButton = page.find_child("RivalryGhostSelector",true,false)
		var target: Dictionary = model.closest_challenger(1)
		check(selector.selected == 0 and selector.get_item_text(0) == str(target.name)+" (#2)","leader defaults to the actual closest challenger's ghost")
		check((page.find_child("RivalryClosestChallengerTime",true,false) as Label).text == MenuStyle.time_text(int(target.ms)/1000.0),"challenger shows the actual best race time")
		check((page.find_child("RivalryClosestChallengerGap",true,false) as Label).text == "+0.080 behind you","challenger gap retains milliseconds")
		check(page.detail_route.show_race_markers and page.detail_route.fitted.size() > 2,"preview renders start and direction markers")
		var button: Button = page.find_child("RivalryStartRace",true,false)
		check(app.menu_body_slot.get_global_rect().grow(1).encloses(button.get_global_rect()),"dense rival panel keeps Race within its bounds")
		var list: VBoxContainer = table()
		var board_before: Array[Dictionary] = model.board(1)
		await capture("leader",dimensions)
		list.more.pressed.emit()
		await settle()
		check(list.scroll.scroll_vertical > 0 and list.sticky.visible,"more action scrolls and pins the player")
		check(absf(list.sticky.get_global_rect().position.y-list.scroll.get_global_rect().position.y) < 1,"player scrolling above the list sticks to the top")
		check((list.sticky.find_child("Time",true,false) as Label).text == (list.player.find_child("Time",true,false) as Label).text,"sticky time is the same weekly PB")
		await capture("leader-scrolled",dimensions)
		list.scroll.scroll_vertical = 60
		await settle()
		var wheel := InputEventMouseButton.new()
		wheel.position = list.sticky.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel,true)
		await settle()
		check(list.scroll.scroll_vertical > 60,"mouse wheel over the pinned player still scrolls the board")
		list.scroll.scroll_vertical = 0
		await settle()
		check(not list.sticky.visible,"scrolling back hides the duplicate player row")
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.pressed = true
		touch.position = list.scroll.get_global_rect().get_center()
		list.scroll._input(touch)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.position = touch.position-Vector2(0,90)
		list.scroll._input(drag)
		touch.pressed = false
		list.scroll._input(touch)
		await settle()
		check(list.scroll.scroll_vertical == 90 and list.scroll.pointer == -1,"touch drag scrolls the real board and releases its pointer")
		check(model.board(1) == board_before,"scrolling and sticky rows leave competitive data unchanged")
		app.rivalry_track = 2
		app._rivalry()
		await settle()
		check_rows()
		await capture("ranked",dimensions)
		model.submit(2,120.0) # A slower race cannot replace its best.
		for driver: Dictionary in model.tracks[2].entries:
			if driver.id == WeeklyRivalry.SELF: driver.ms = 120000
		app._rivalry()
		await settle()
		list = table()
		check(list.sticky.visible and absf(list.sticky.get_global_rect().end.y-list.scroll.get_global_rect().end.y) < 1,"offscreen lower-ranked player sticks to the bottom")
		await capture("last-player",dimensions)
		list.scroll.scroll_vertical = 100000
		await settle()
		check(not list.sticky.visible,"reaching the player's row removes its sticky copy")
		check(list.more.text == "↑  Back to top","end of board offers a useful return action")
		await capture("last-player-scrolled",dimensions)
		# Exact marker geometry follows the canonical start/direction without a race.
		page = app.root_ui.find_child("WeeklyRivalryPage",true,false)
		var document: Dictionary = model.tracks[2].document.duplicate(true)
		document.start_line = {"position":document.points[3].duplicate(),"heading":180.0}
		# Full documents arrive through JSON, with ordinary String keys.
		document = JSON.parse_string(JSON.stringify(document))
		page.apply_track_preview(document)
		await settle()
		var native: NativeTrack = TrackCompiler.compile(document)
		check(native != null and page.detail_route.race_route == native.route,"start-line relocation and reversal match the canonical route exactly")
		var outline := PackedVector2Array()
		for point: Array in model.tracks[2].document.points: outline.append(Vector2(point[0],point[1]))
		check(page.detail_route.route == outline,"markers preserve the original preview outline")
		# UI and race loading resolve the identical rival, including tied times.
		var real_client: Node = app.rivalry
		var probe := GhostProbe.new()
		probe.model = model
		app.rivalry = probe
		var ghost: Dictionary = app._rivalry_ghost(1,0)
		check(probe.driver == model.ghost_target(1,0).driver_id and ghost.driver == probe.driver,"race loading fetches the same challenger selected by the menu")
		app.rivalry = real_client
		probe.free()
		for driver: Dictionary in model.tracks[1].entries:
			if driver.id != WeeklyRivalry.SELF:
				driver.ms = 78500
				break
		check(int(model.closest_challenger(1).ms) == 78500,"tied rival is the closest challenger")
		app.rivalry_track = 1
		app._rivalry()
		await settle()
		check((app.root_ui.find_child("RivalryClosestChallengerGap",true,false) as Label).text == "Level with you","tie never claims a rival is behind")
		await capture("tied-lead",dimensions)
		for track: Dictionary in model.tracks:
			for driver: Dictionary in track.entries: driver.ms = null
		# Unranked boards are ordinary server projections, not sortable sample times.
		model.sample = false
		for track: Dictionary in model.tracks:
			track.available = false
			track.entry = {"track_id":"fixture","version_id":"fixture","name":track.name,"creator":"Beat my track","content_hash":"a".repeat(64),"points":track.document.points}
			for driver: Dictionary in track.entries: driver.rank = null
		app._rivalry()
		await settle()
		list = table()
		check(app.root_ui.find_child("RivalryClosestChallengerTime",true,false) == null,"no invented challenger before anyone records a time")
		selector = app.root_ui.find_child("RivalryGhostSelector",true,false)
		check(selector.selected == 3 and selector.is_item_disabled(0),"unrecorded rivals retain the No ghost fallback")
		for row: Control in list.rows.get_children():
			check((row.find_child("Time",true,false) as Label).text == "—" and (row.find_child("Gap",true,false) as Label).text == "—","missing times have no invented gaps")
		await capture("unranked",dimensions)
		for index: int in range(6):
			model.tracks[1].entries.append({"id":"extra_"+str(index),"name":"Additional driver "+str(index),"rank":null,"ms":null})
		app._rivalry()
		await settle()
		check(table().rows.get_child_count() == 20 and table().more.text == "↓  12 more drivers","the full twenty-driver field remains accessible")
		await capture("twenty-drivers",dimensions)
	app.queue_free()
	await settle()
	print("RIVALRY_TRACK_DETAIL_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
