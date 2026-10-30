extends "res://tests/test_rivalry_awards.gd"
## Actual menu hierarchy: fixed page, complete track results, one scrolling list.
const RankingFixture = preload("res://tests/test_ranking_newspaper.gd")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-finale-layout-2026-10-26/layout")
	if RenderingServer.get_current_rendering_method() == "mobile": evidence += "/mobile"
	DirAccess.make_dir_recursive_absolute(evidence)
	var folder: String = "user://finale_layout_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var dimensions_to_check: Array[Vector2i] = [Vector2i(1280,1024),Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720),Vector2i(1919,1017)]
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
			print("FINALE_LAYOUT ",context," root=",app.root_ui.size," content=",app.content.size," page=",ceremony.size," min=",ceremony.get_combined_minimum_size()," hero=",ceremony.hero.size," columns=",ceremony.columns.size," columns_min=",ceremony.columns.get_combined_minimum_size())
			check(app.root_ui.get_global_rect().encloses(ceremony.actions.get_global_rect()),context+" actions fit in the screen")
			for row: Button in ceremony.track_buttons:
				check(ceremony.columns.get_global_rect().encloses(row.get_global_rect()),context+" every track row fits without scrolling")
			var visible_scrolls: int = 0
			for scroll: ScrollContainer in ceremony.find_children("*","ScrollContainer",true,false):
				if scroll.get_v_scroll_bar().is_visible_in_tree():
					visible_scrolls += 1
					check(scroll == ceremony.standings_scroll,context+" only standings can display a scrollbar")
			check(visible_scrolls == 1,context+" the full driver field has one scrollable list")
			if DisplayServer.get_name() != "headless": await capture(kind,dimensions)
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
