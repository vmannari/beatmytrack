extends "res://tests/test_achievement_detail.gd"
## Fit every real objective, including rarity, and inspect actual scrollbar gaps.
var layout_metrics: Array[Dictionary] = []

func measure(id: String, should_fit: bool) -> void:
	album._show_achievement(id)
	await settle()
	var sheet: PanelContainer = album._sheet_panel
	var viewport: ScrollContainer = album.find_child("AchievementDetailScroll",true,false)
	var bar: VScrollBar = viewport.get_v_scroll_bar()
	var overflow: float = maxf(0,bar.max_value-bar.page)
	check(root.get_visible_rect().encloses(sheet.get_global_rect()),"sheet contained "+id+" "+str(root.size))
	check(sheet.size.x <= 640 and sheet.size.y <= root.size.y-32,"bounded sheet "+id+" "+str(root.size))
	check(album.find_child("AchievementFeature",true,false).size.y >= 52,"fixed footer touch target "+id)
	if should_fit:
		check(not bar.is_visible_in_tree() and overflow <= 0.01,"no scrollbar or hidden overflow "+id+" "+str(root.size)+" overflow="+str(overflow))
		check(viewport.get_global_rect().encloses(album.detail.get_global_rect()),"all detail rows visible "+id+" "+str(root.size))
	elif bar.is_visible_in_tree():
		var bar_rect: Rect2 = bar.get_global_rect()
		var content_rect: Rect2 = viewport.get_global_rect()
		check(bar_rect.size.x >= 8 and bar_rect.size.y >= 24,"scrollbar has visible width and height "+id)
		check(sheet.get_global_rect().end.x-bar_rect.end.x >= 24,"scrollbar inset from sheet edge "+id)
		check(content_rect.encloses(bar_rect),"scrollbar stays inside viewport "+id)
		check(album.detail.get_global_rect().end.x <= bar_rect.position.x-12,"content-to-scrollbar gutter "+id)
		var header: Control = album.find_child("AchievementDetailClose",true,false)
		var footer: Control = album.find_child("AchievementFeature",true,false)
		check(bar_rect.position.y-header.get_global_rect().end.y >= 18,"scrollbar top padding "+id)
		check(footer.get_global_rect().position.y-bar_rect.end.y >= 18,"scrollbar bottom padding "+id)
		if DisplayServer.get_name() != "headless":
			var pixels: Image = root.get_texture().get_image()
			var thumb_pixel: Color = pixels.get_pixelv(Vector2i(bar_rect.get_center()))
			var panel_pixel: Color = pixels.get_pixelv(Vector2i(bar_rect.end.x+3,bar_rect.get_center().y))
			check(absf(thumb_pixel.r-panel_pixel.r)+absf(thumb_pixel.g-panel_pixel.g)+absf(thumb_pixel.b-panel_pixel.b) > 0.05,"scrollbar is visibly rendered "+id)
	var rect: Rect2 = bar.get_global_rect()
	layout_metrics.append({"id":id,"viewport":[root.size.x,root.size.y],"sheet":[sheet.size.x,sheet.size.y],"overflow":overflow,"scrollbar":bar.is_visible_in_tree(),"bar_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})

func run() -> void:
	output = "res://../docs/evidence/achievement-detail-fit-2026-10-22/headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
		if arg == "--baseline": baseline = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	var folder: String = "user://achievement_fit_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	records.settings.achievements = earned_state("local",true)
	var backend := preload("res://tests/test_achievements.gd").Backend.new()
	backend.data = {"schema":1,"states":{"race":earned_state("race",true),"creator":earned_state("creator",true)},"rarity":{"eligible":100,"minimum":100,"unlocks":{"races/4":12}}}
	root.add_child(backend)
	service = Service.new()
	service.records = records
	service.client = backend
	service.directory = folder.path_join("cache")
	root.add_child(service)
	service.sync_identity()
	await service.refresh()
	album = preload("res://ui/achievements_menu.gd").new()
	album.service = service
	root.add_child(album)
	MenuStyle.fill(album)
	await settle()
	var requests: int = backend.calls.size()
	if baseline:
		await measure("rivalry_wins",true)
		capture("rarity-1280")
		root.size = Vector2i(740,360)
		root.content_scale_size = root.size
		await settle()
		await measure("washes",false)
		capture("short-740")
	else:
		for dimensions: Vector2i in [Vector2i(854,480),Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800),Vector2i(1560,720)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			await settle()
			for f: Dictionary in AchievementProgress.catalog().families:
				await measure(str(f.id),true)
				if f.id == "rivalry_wins": capture("rarity-"+str(dimensions.x)+"x"+str(dimensions.y))
			var toolbar: Control = album.find_child("AchievementToolbar",true,false)
			check(toolbar.get_child_count() == 3 and toolbar.get_child(0).name == "AchievementTitle" and toolbar.get_child(1).name == "AchievementSummary" and toolbar.get_child(2).name == "AchievementClose","header contains only title, count and close "+str(dimensions))
		root.size = Vector2i(740,360)
		root.content_scale_size = root.size
		await settle()
		await measure("washes",false)
		var viewport: ScrollContainer = album.find_child("AchievementDetailScroll",true,false)
		check(viewport.get_v_scroll_bar().is_visible_in_tree(),"short viewport retains usable scrolling")
		capture("short-740")
		# Touch owns the detail scroll while the collection underneath stays still.
		var initial_collection: int = album.scroll.scroll_vertical
		var point: Vector2 = viewport.get_global_rect().position+Vector2(30,25)
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = point
		down.pressed = true
		root.push_input(down,true)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point-Vector2(0,70)
		drag.relative = Vector2(0,-70)
		root.push_input(drag,true)
		down.position = drag.position
		down.pressed = false
		root.push_input(down,true)
		await settle()
		check(viewport.scroll_vertical > 0,"short sheet scrolls with real touch")
		check(album.scroll.scroll_vertical == initial_collection,"scroll gesture leaves collection still")
		capture("short-scrolled-740")
		# Resize the same modal back to a normal screen; the bar and offset clear.
		root.size = Vector2i(1280,720)
		root.content_scale_size = root.size
		await settle()
		check(not viewport.get_v_scroll_bar().is_visible_in_tree() and viewport.scroll_vertical == 0,"resize restores fully visible content")
		check(backend.calls.size() == requests,"layout and scrolling make no backend requests")
	var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(layout_metrics,"  "))
	album._close_sheet()
	print("ACHIEVEMENT_DETAIL_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
