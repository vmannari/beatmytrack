extends "res://tests/test_rivalry_awards.gd"
## Matched active/completed renders must keep the actual weekly components in place.
const RankingFixture = preload("res://tests/test_ranking_newspaper.gd")
var before_mode: bool = false

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	before_mode = "--weekly-before" in OS.get_cmdline_user_args()
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-weekly-continuity-2026-10-26/after")
	if before_mode:
		var script: GDScript = load("res://ui/weekly_rivalry_page.gd")
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-weekly-continuity-2026-10-26/before/weekly_rivalry_page.gd")
		check(script.reload() == OK,"original page reloads only into this isolated process")
		evidence = evidence.get_base_dir().path_join("before/ui")
	if RenderingServer.get_current_rendering_method() == "mobile": evidence += "/mobile"
	DirAccess.make_dir_recursive_absolute(evidence)
	var folder: String = "user://weekly_continuity_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	for dimensions: Vector2i in [Vector2i(1280,1024),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(2023,871),Vector2i(1938,1282)]:
		root.size = dimensions
		var original: Dictionary = awarded_snapshot("champion")
		original.state = "active"
		await show_week(original)
		var active: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		var geometry: Dictionary = weekly_geometry(active)
		if DisplayServer.get_name() != "headless": await capture("active",dimensions)
		for kind: String in ["champion","perfect","middle","unranked","tied"]:
			var snapshot: Dictionary = awarded_snapshot(kind)
			var state: String = JSON.stringify(snapshot)
			await show_week(snapshot)
			var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
			check(JSON.stringify(snapshot) == state,"completed presentation cannot change the input scores")
			check_card_bounds(page,"%s %dx%d" % [kind,dimensions.x,dimensions.y])
			if page.find_child("RivalryPodium",true,false) != null:
				check_continuity(page,geometry,"%s %s" % [kind,str(dimensions)])
				check_finished_state(page,kind)
			if DisplayServer.get_name() != "headless": await capture(kind,dimensions)
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		if page.find_child("RivalryPodium",true,false) != null:
			var old_scroll: ScrollContainer = page.standings_scroll
			page.error = "Could not continue. Try again."
			page.busy = true
			page.refresh_presentation()
			await settle()
			check(page.standings_scroll == old_scroll,"in-place errors retain the actual weekly list")
			check((page.find_child("RivalryNextWeek",true,false) as Button).disabled and (page.find_child("RivalryShareResults",true,false) as Button).disabled,"busy state guards both real footer actions")
			check((page.find_child("RivalryStatusMessage",true,false) as Label).text == page.error,"Continue failure is actionable in the original weekly hint position")
			check_card_bounds(page,"error "+str(dimensions))
			page.error = ""
			page.busy = false
			page.refresh_presentation()
			await settle()
			check(not (page.find_child("RivalryStatusMessage",true,false) as Control).visible,"clearing error removes the redundant context")
	# Circuit results retain their ranking facts in the existing track panel.
	var backend := RankingFixture.Backend.new()
	root.add_child(backend)
	for locale: String in ["en","de","fi","ja"]:
		TranslationServer.set_locale(locale)
		root.size = Vector2i(1280,720)
		await show_week(awarded_snapshot("champion"))
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		page.model.world_circuit = {"week_start":backend.week}
		page.circuit_mode = true
		page.safety_client = backend
		page.refresh_presentation()
		await settle()
		check_card_bounds(page,locale+" Circuit")
		var change: Control = page.find_child("WorldRankingWeekChange",true,false)
		check(change != null,"Circuit finale retains its actual ranking result")
		if change != null:
			check((page.find_child("RivalryTracksPanel",true,false) as Control).get_global_rect().encloses(change.get_global_rect()),locale+" ranking result stays inside the shared track card")
		if DisplayServer.get_name() != "headless": await capture("circuit-"+locale,Vector2i(1280,720))
	TranslationServer.set_locale("en")
	backend.queue_free()
	app.queue_free()
	await process_frame
	print("RIVALRY_WEEKLY_CONTINUITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func show_week(snapshot: Dictionary) -> void:
	app.rivalry.model.apply_snapshot(snapshot)
	app.rivalry.snapshot_scope = app.rivalry.scope()
	app.rivalry.busy = false
	app.rivalry.cached_snapshot = false
	app.rivalry.error = ""
	app.rivalry_section = "overview"
	app._show_screen("rivalry")
	await settle()
	await dismiss_weekly_summary()

func weekly_geometry(page: Control) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ["RivalryPodium","RivalryDriversPanel","RivalryTracksPanel","RivalrySectionNavigation"]:
		var node: Control = page.find_child(id,true,false)
		result[id] = node.get_global_rect()
	var clock: Control = page.find_child("RivalryWeekAndClock",true,false)
	result.clock_right = clock.get_global_rect().end.x
	result.clock_top = clock.global_position.y
	return result

func check_continuity(page: WeeklyRivalryPage, original: Dictionary, context: String) -> void:
	for id: String in ["RivalryPodium","RivalryDriversPanel","RivalryTracksPanel","RivalrySectionNavigation"]:
		var node: Control = page.find_child(id,true,false)
		var actual: Rect2 = node.get_global_rect()
		var expected: Rect2 = original[id]
		check(actual.position.distance_to(expected.position) <= 1.0 and actual.size.distance_to(expected.size) <= 1.0,context+" keeps the weekly "+id+" in the same place and size")
	var podium: Control = page.find_child("RivalryPodium",true,false)
	var standings: Control = page.find_child("RivalryDriversPanel",true,false)
	var tracks: Control = page.find_child("RivalryTracksPanel",true,false)
	check(podium.get_global_rect().end.x <= tracks.global_position.x,"podium remains on the left of the tracks")
	check(podium.get_global_rect().end.y <= standings.global_position.y,"standings remain beneath the podium")
	var clock: Control = page.find_child("RivalryWeekAndClock",true,false)
	check(absf(clock.get_global_rect().end.x-float(original.clock_right)) <= 1 and absf(clock.global_position.y-float(original.clock_top)) <= 1,"week status keeps its normal top-right anchor")
	for row: Button in page.track_rows:
		var normal: StyleBoxFlat = row.get_theme_stylebox("normal")
		check(normal.bg_color.a == 0.0 and normal.border_width_bottom == 1,"finished tracks retain the normal open divider rows")
		check(row.size.y >= 54,"all five normal weekly track targets remain usable")
	var scrolls: Array[Node] = page.find_children("*","ScrollContainer",true,false)
	check(scrolls.size() == 1 and scrolls[0] == page.standings_scroll,"only the original weekly standings list scrolls")

func check_finished_state(page: WeeklyRivalryPage, kind: String) -> void:
	var summary: Dictionary = page.model.finale_summary()
	var badge: Label = page.find_child("RivalryPositionSummary",true,false)
	var expected: String = GameText.message("PERFECT\nWEEK").replace("\n"," ") if kind == "perfect" else GameText.message(summary.title)
	check(badge != null and badge.text == expected,"result uses the existing title badge with actual earned state")
	check((page.find_child("RivalryTracksLeading",true,false) as Label).text == GameText.message("%d / 5 WON") % int(summary.wins),"finished track count uses contested victories")
	for index: int in range(5):
		check(not page._track_views[index].target.visible,"completed tracks cannot invite another race target")
		check(page._track_views[index].delta.text == GameText.message("POINTS")+" "+str(int(page.model.track_summary(index).own.get("points",0))),"finished row shows actual points in the existing status field")
		var own: Dictionary = page.model.track_summary(index).own
		check(page._track_views[index].time.text == ("—" if own.get("ms") == null else MenuStyle.time_text(float(own.ms)/1000.0)),"finished row shows the player's verified time and never substitutes a leader time")
	var share: Button = page.find_child("RivalryShareResults",true,false)
	var next: Button = page.find_child("RivalryNextWeek",true,false)
	check(not share.disabled and not next.disabled,"completed authoritative actions are available")
	check(share.size.y >= 52 and next.size.y >= 52,"completed actions retain normal touch targets")
