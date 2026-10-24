extends "res://tests/test_rivalry_result.gd"
## Native painted clearance, drag targets and actual Settings/Rivalry builders.
const BACKGROUND := Color("08131b")

func frames() -> void:
	for _frame: int in range(8): await process_frame

func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event,true)

func move(point: Vector2, dragging: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	root.push_input(event,true)

func inspect_bar(bar: ScrollBar, vertical: bool) -> void:
	var axis: String = "vertical" if vertical else "horizontal"
	check(bar.visible,"overflow exposes "+axis+" scrollbar")
	check((bar.size.x if vertical else bar.size.y) >= 24,"native "+axis+" drag lane stays usable")
	if DisplayServer.get_name() != "headless":
		move(Vector2(620,20))
		await frames()
		await RenderingServer.frame_post_draw
		var pixels: Image = root.get_texture().get_image()
		var bounds: Rect2 = bar.get_global_rect()
		var first: int = -1
		var last: int = -1
		var extent: int = roundi(bounds.size.x if vertical else bounds.size.y)
		for cross: int in range(extent):
			var location: Vector2 = Vector2(bounds.position.x+cross,bounds.get_center().y) if vertical else Vector2(bounds.get_center().x,bounds.position.y+cross)
			var colour: Color = pixels.get_pixelv(Vector2i(location))
			if absf(colour.r-BACKGROUND.r)+absf(colour.g-BACKGROUND.g)+absf(colour.b-BACKGROUND.b) > 0.08:
				if first < 0: first = cross
				last = cross
		check(first >= 8 and extent-1-last >= 8,"painted "+axis+" thumb has padding on both sides")
		check(last-first+1 >= 2 and last-first+1 <= 6,"painted "+axis+" thumb stays slim and visible")
	var centre: Vector2 = bar.get_global_rect().get_center()
	var before: float = bar.value
	pointer(centre,true)
	move(centre+(Vector2(0,30) if vertical else Vector2(30,0)),true)
	pointer(centre+(Vector2(0,30) if vertical else Vector2(30,0)),false)
	await frames()
	check(bar.value > before,"native "+axis+" thumb remains draggable")

func run() -> void:
	create_timer(100).timeout.connect(func() -> void: print("FAIL: scrollbar style deadline"); quit(1))
	OS.set_environment("BMT_API_URL","")
	evidence = OS.get_environment("BMT_SCROLLBAR_EVIDENCE_DIR")
	if evidence.is_empty(): evidence = ProjectSettings.globalize_path("res://../build/scrollbar-style")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(640,360)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	var backdrop := ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	MenuStyle.fill(backdrop)
	var vertical := ScrollContainer.new()
	vertical.position = Vector2(24,24)
	vertical.size = Vector2(280,230)
	vertical.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(vertical)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertical.add_child(rows)
	for index: int in range(20): rows.add_child(MenuStyle.button("Offer "+str(index+1),func() -> void: pass))
	var horizontal := ScrollContainer.new()
	horizontal.position = Vector2(24,280)
	horizontal.size = Vector2(570,76)
	horizontal.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(horizontal)
	var columns := HBoxContainer.new()
	horizontal.add_child(columns)
	for index: int in range(20): columns.add_child(MenuStyle.button("Choice "+str(index+1),func() -> void: pass))
	await frames()
	for bar: ScrollBar in [vertical.get_v_scroll_bar(),horizontal.get_h_scroll_bar()]: bar.value = (bar.max_value-bar.page)*0.5
	await frames()
	await capture("native-lanes",root.size)
	await inspect_bar(vertical.get_v_scroll_bar(),true)
	await inspect_bar(horizontal.get_h_scroll_bar(),false)
	for axis: String in ["VScrollBar","HScrollBar"]:
		var menu_thumb: StyleBoxFlat = MenuStyle.theme().get_stylebox("grabber",axis)
		var hud_thumb: StyleBoxFlat = RaceHUDStyle.theme().get_stylebox("grabber",axis)
		check(menu_thumb.bg_color == hud_thumb.bg_color,"race HUD shares "+axis+" styling")
		check(menu_thumb.bg_color.a < MenuStyle.theme().get_stylebox("grabber_highlight",axis).bg_color.a,"hover clarifies "+axis+" thumb")
	for row: Node in rows.get_children().slice(1): rows.remove_child(row); row.queue_free()
	await frames()
	check(not vertical.get_v_scroll_bar().visible,"short content hides its scrollbar")
	check(is_equal_approx(rows.size.x,vertical.size.x),"short content does not reserve an unnecessary lane")
	vertical.queue_free()
	horizontal.queue_free()
	await frames()
	# These production builders inherit the theme without per-list decoration.
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var records := LocalRecords.new("user://scrollbar-fixture/records.json")
	var settings := SettingsPage.new()
	settings.records = records
	root.add_child(settings)
	MenuStyle.fill(settings)
	await frames()
	var category: ScrollContainer = settings.find_child("SettingsCategoryScroll",true,false)
	check(category.get_v_scroll_bar().get_theme_stylebox("grabber") == MenuStyle.theme().get_stylebox("grabber","VScrollBar"),"Settings inherits the shared thumb")
	await capture("settings",root.size)
	settings.queue_free()
	await frames()
	var model := WeeklyRivalry.new()
	model.apply_snapshot(fixture())
	var rivalry := WeeklyRivalryPage.new()
	rivalry.model = model
	root.add_child(rivalry)
	MenuStyle.fill(rivalry)
	await frames()
	var bar: VScrollBar = rivalry.standings_scroll.get_v_scroll_bar()
	check(not bar.has_theme_stylebox_override("grabber"),"Rivalry uses shared styling")
	check(rivalry._driver_rows.get_global_rect().end.x <= bar.get_global_rect().position.x-12,"Rivalry retains its content gutter")
	await capture("rivalry",root.size)
	rivalry.queue_free()
	backdrop.queue_free()
	await frames()
	var report := FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()},"\t"))
	report.close()
	print("SCROLLBAR_STYLE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
