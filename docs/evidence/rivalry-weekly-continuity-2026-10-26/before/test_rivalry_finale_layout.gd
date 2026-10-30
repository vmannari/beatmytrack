extends "res://tests/test_rivalry_awards.gd"
## Actual menu hierarchy: fixed page, complete track results, one scrolling list.
const RankingFixture = preload("res://tests/test_ranking_newspaper.gd")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-finale-composition-2026-10-26/ui")
	if "--composition-before" in OS.get_cmdline_user_args():
		var script: GDScript = load("res://ui/weekly_rivalry_finale.gd")
		script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-finale-composition-2026-10-26/before/weekly_rivalry_finale.gd")
		check(script.reload() == OK,"original composition loads only into this isolated process")
		evidence = evidence.get_base_dir().path_join("before/ui")
	if RenderingServer.get_current_rendering_method() == "mobile": evidence += "/mobile"
	DirAccess.make_dir_recursive_absolute(evidence)
	var folder: String = "user://finale_layout_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var dimensions_to_check: Array[Vector2i] = [Vector2i(1280,1024),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(1919,1017),Vector2i(2023,871)]
	if "--ranking-only" in OS.get_cmdline_user_args(): dimensions_to_check = []
	for dimensions: Vector2i in dimensions_to_check:
		root.size = dimensions
		for kind: String in ["champion","perfect","unranked"]:
			app.rivalry.model.apply_snapshot(awarded_snapshot(kind))
			app.rivalry.snapshot_scope = app.rivalry.scope()
			app.rivalry.busy = false
			app.rivalry_section = "overview"
			app._show_screen("rivalry")
			await settle()
			var ceremony: Control = app.content.find_child("WeeklyRivalryFinale",true,false)
			var context: String = "%s %dx%d" % [kind,dimensions.x,dimensions.y]
			check_card_bounds(ceremony,context)
			check_composition(ceremony,context)
			print("FINALE_LAYOUT ",context," root=",app.root_ui.size," content=",app.content.size," page=",ceremony.size," min=",ceremony.get_combined_minimum_size()," hero=",ceremony.hero.size," columns=",ceremony.columns.size," columns_min=",ceremony.columns.get_combined_minimum_size())
			check(app.root_ui.get_global_rect().encloses(ceremony.actions.get_global_rect()),context+" actions fit in the screen")
			check(app.menu_body_slot.get_global_rect().encloses(ceremony.actions.get_global_rect()),context+" bottom actions clear the actual menu clipping boundary")
			for row: Button in ceremony.track_buttons:
				check(ceremony.columns.get_global_rect().encloses(row.get_global_rect()),context+" every track row fits without scrolling")
			var visible_scrolls: int = 0
			for scroll: ScrollContainer in ceremony.find_children("*","ScrollContainer",true,false):
				if scroll.get_v_scroll_bar().is_visible_in_tree():
					visible_scrolls += 1
					check(scroll == ceremony.standings_scroll,context+" only standings can display a scrollbar")
			check(visible_scrolls == 1,context+" the full driver field has one scrollable list")
			if DisplayServer.get_name() != "headless": await capture(kind,dimensions)
			if kind == "champion" and dimensions == Vector2i(1280,720):
				var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
				page.error = "Could not continue. Try again."
				page.refresh_presentation()
				await settle()
				check_error_bounds(ceremony,context)
				page.error = ""
				page.refresh_presentation()
				await settle()
	# Exercise ranking text and translated headers in the same production shell.
	var backend := RankingFixture.Backend.new()
	root.add_child(backend)
	for locale: String in ["en","de","fi","ja"]:
		TranslationServer.set_locale(locale)
		root.size = Vector2i(1280,720)
		app.rivalry.model.apply_snapshot(awarded_snapshot("champion"))
		app.rivalry_section = "overview"
		app._show_screen("rivalry")
		await settle()
		var page: WeeklyRivalryPage = app.content.find_child("WeeklyRivalryPage",true,false)
		page.model.world_circuit = {"week_start":backend.week}
		page.safety_client = backend
		page.refresh_presentation()
		await settle()
		var ceremony: Control = page.find_child("WeeklyRivalryFinale",true,false)
		print("RANKING_LAYOUT ",locale," root=",app.root_ui.size," content=",app.content.size," page=",ceremony.size," hero=",ceremony.hero.size," columns=",ceremony.columns.size," columns_min=",ceremony.columns.get_combined_minimum_size()," right=",ceremony.find_child("RivalryFinaleRightColumn",true,false).get_combined_minimum_size())
		check_card_bounds(ceremony,locale+" ranking finale")
		check(app.root_ui.get_global_rect().encloses(ceremony.actions.get_global_rect()),locale+" ranking finale actions fit")
		check(app.menu_body_slot.get_global_rect().encloses(ceremony.actions.get_global_rect()),locale+" ranking actions clear the clipping boundary")
		var ranking: Control = ceremony.find_child("RivalryWorldRankingChange",true,false)
		check(ceremony.columns.get_global_rect().encloses(ranking.get_global_rect()),locale+" ranking summary fits")
		# An in-place status refresh must reveal an actionable error without
		# restoring the redundant points-ahead/completion message afterwards.
		page.error = "Could not continue. Try again."
		page.refresh_presentation()
		await settle()
		ceremony = page.find_child("WeeklyRivalryFinale",true,false)
		check(ceremony.find_child("RivalryStatusMessage",true,false).is_visible_in_tree(),locale+" refreshed error is visible")
		check(app.root_ui.get_global_rect().encloses(ceremony.actions.get_global_rect()),locale+" error state actions fit")
		check(app.menu_body_slot.get_global_rect().encloses(ceremony.actions.get_global_rect()),locale+" error actions clear the clipping boundary")
		check_error_bounds(ceremony,locale+" ranking error")
		page.error = ""
		page.refresh_presentation()
		await settle()
		check(not ceremony.find_child("RivalryStatusMessage",true,false).is_visible_in_tree(),locale+" clearing error removes the context label")
		if DisplayServer.get_name() != "headless": await capture("ranking-"+locale,Vector2i(1280,720))
	TranslationServer.set_locale("en")
	backend.queue_free()
	app.queue_free()
	await process_frame
	print("RIVALRY_FINALE_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check_composition(ceremony: Control, context: String) -> void:
	var tracks: Control = ceremony.find_child("RivalryTracksPanel",true,false)
	var standings: Control = ceremony.find_child("RivalryDriversPanel",true,false)
	var highlights: Control = ceremony.find_child("RivalryWeeklyHighlights",true,false)
	check(tracks.is_ancestor_of(highlights),context+" highlights occupy the track-results footer")
	check(absf(tracks.get_global_rect().position.y-standings.get_global_rect().position.y) < 1,context+" result panels share their top edge")
	check(absf(tracks.get_global_rect().end.y-standings.get_global_rect().end.y) < 1,context+" standings use the complete results height")
	check(ceremony.hero.size.y <= 104,context+" championship summary remains a compact strip")
	check(ceremony.vehicle.size.y >= 84,context+" car has a readable dedicated preview")
	check(ceremony.find_child("RivalrySummaryBand",true,false) != null,context+" score metrics form one aligned group")
	var rows: Control = ceremony.standings_scroll.get_child(0)
	var row_height: float = rows.get_child(0).size.y
	check(ceremony.standings_scroll.size.y >= row_height*8+7*4,context+" standings show at least eight complete rows")
	for row: Button in ceremony.track_buttons:
		var thumbnail: Control = row.find_child("RivalryFinalThumbnail_*",true,false)
		check(thumbnail.size.y <= 44,context+" route thumbnail stays proportional in taller rows")
		check(row.get_global_rect().encloses(thumbnail.get_global_rect()),context+" route thumbnail stays inside its track action")
		for label: Label in row.find_children("*","Label",true,false):
			check(label.text not in ["TIME","GAP TO 2ND","POINTS"],context+" track column headings are shared above the table")

func check_error_bounds(ceremony: Control, context: String) -> void:
	var message: Control = ceremony.find_child("RivalryStatusMessage",true,false)
	check(ceremony.hero.get_global_rect().encloses(message.get_global_rect()),context+" actionable error fits the summary strip")
	check(not ceremony.metrics.get_global_rect().intersects(message.get_global_rect()),context+" error clears the score metrics")
	check(app.menu_body_slot.get_global_rect().encloses(ceremony.actions.get_global_rect()),context+" error keeps bottom actions visible")
