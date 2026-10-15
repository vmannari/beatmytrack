extends SceneTree
## Dispatch actual viewport input through the app and Garage gesture owners.
var checks: int = 0
var failures: int = 0
var app: Node
var page: GaragePage
var output: String = "res://../docs/evidence/garage-swipe-scroll-2026-10-14"
var baseline: bool = false

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	while page != null and page._menu_motion != null: await process_frame
	for frame: int in range(6): await process_frame
func touch(position: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)
func drag(position: Vector2, relative: Vector2 = Vector2.ZERO, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event,true)
func mouse(position: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT, emulated: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	if emulated: event.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(event,true)
func swipe(scroll: ScrollContainer, dy: float, start: Vector2 = Vector2.INF) -> void:
	if start == Vector2.INF: start = scroll.get_global_rect().get_center()
	touch(start,true)
	for step: int in range(1,5):
		drag(start+Vector2(0,dy*step/4.0),Vector2(0,dy/4.0))
		await process_frame
	touch(start+Vector2(0,dy),false)
	await settle()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)
func scroll_checks(scroll: ScrollContainer, label: String, save: bool = false) -> void:
	root.gui_release_focus()
	scroll.scroll_vertical = 0
	await settle()
	var livery: Dictionary = page.draft.duplicate(true)
	var kits: Dictionary = page.kit_draft.duplicate(true)
	var settings: Dictionary = page.records.settings.duplicate(true)
	print("SCROLL_FIXTURE %s viewport=%s list=%s range=%s page=%s"%[label,root.get_visible_rect(),scroll.get_global_rect(),scroll.get_v_scroll_bar().max_value,scroll.get_v_scroll_bar().page])
	var tiles: Array[Node] = scroll.find_children("*","LiveryTile",true,false)
	if tiles.is_empty(): tiles = scroll.find_children("*","BaseButton",true,false)
	var first: BaseButton = tiles[0]
	var point: Vector2 = first.get_global_rect().intersection(scroll.get_global_rect()).get_center()
	if save: await capture(label+"-top")
	await swipe(scroll,-100,point)
	check(scroll.scroll_vertical>=90,label+" upward swipe starting on a card scrolls down")
	check(page.draft==livery and page.kit_draft==kits and page.records.settings==settings,label+" drag does not select or save")
	await swipe(scroll,70)
	check(scroll.scroll_vertical<=40,label+" downward swipe scrolls back up")
	await swipe(scroll,-10000)
	var maximum: int = roundi(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
	check(maximum>0 and absi(scroll.scroll_vertical-maximum)<=1,label+" full swipe reaches last choices and clamps")
	if save: await capture(label+"-bottom")
	await swipe(scroll,10000)
	check(scroll.scroll_vertical==0,label+" top clamps")
	check(page.draft==livery and page.kit_draft==kits and page.records.settings==settings,label+" repeated edge swipes retain local choices")

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
		if arg=="--baseline": baseline = true
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var folder: String = "res://../build/garage-swipe-scroll/session-"+TrackLibrary.unique_id()
	folder = ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	await settle()
	var showroom: CarShowroom = page.showroom
	var car: CarVisual = showroom.car
	var camera: Transform3D = showroom.camera.transform
	var condition: Dictionary = showroom.weathering.snapshot().duplicate(true)
	await scroll_checks(page.livery_menu.pattern_scroll,"patterns-1280",true)
	page._show_section("tuning")
	await settle()
	await scroll_checks(page.kit_scroll,"tuning-hood-1280",true)
	if not baseline:
		for category: String in ["aero","rims","body"]:
			page._select_kit_category(category)
			await settle()
			await scroll_checks(page.kit_scroll,"tuning-"+category)
		var card: BaseButton = page.kit_cards.get_child(1)
		var point: Vector2 = card.get_global_rect().get_center()
		touch(point,true)
		touch(point,false)
		await settle()
		check(page.kit_draft.body==VehicleCustomisation.OPTIONS.body[1][0],"tuning touch tap still selects and saves")
		check(VehicleCustomisation.for_car(page.records.settings,"compact")==page.kit_draft,"kit touch selection persists locally")
		page._set_customise_tab("livery")
		await settle()
		var scroll: ScrollContainer = page.livery_menu.pattern_scroll
		scroll.scroll_vertical = 0
		await settle()
		var tile: BaseButton = page.livery_menu.pattern_tiles[1]
		point = tile.get_global_rect().get_center()
		var taps: Array[int] = [0]
		tile.pressed.connect(func() -> void: taps[0]+=1)
		# Match the phone's emulated mouse before/after its touch stream.
		mouse(point,true,MOUSE_BUTTON_LEFT,true)
		touch(point,true)
		drag(point+Vector2(0,-80))
		mouse(point+Vector2(0,-80),false,MOUSE_BUTTON_LEFT,true)
		touch(point+Vector2(0,-80),false)
		await settle()
		check(taps[0]==0 and scroll.scroll_vertical>=70,"parallel emulated mouse cannot select during swipe")
		scroll.scroll_vertical = 0
		await settle()
		point = tile.get_global_rect().get_center()
		touch(point,true)
		touch(point,false,true)
		check(taps[0]==0,"canceled touch does not select")
		touch(point,true)
		drag(point+Vector2(30,0))
		touch(point,false)
		check(taps[0]==0,"horizontal movement and return cannot become a tap")
		touch(point,true)
		touch(point+Vector2(10,0),true,false,1)
		touch(point+Vector2(10,0),false,false,1)
		touch(point,false)
		check(taps[0]==0,"second finger rejects selection")
		mouse(point,true,MOUSE_BUTTON_LEFT,true)
		touch(point,true)
		mouse(point,false,MOUSE_BUTTON_LEFT,true)
		touch(point,false)
		await settle()
		check(taps[0]==1 and page.draft.pattern==LiveryCatalog.patterns[0].id,"touch plus emulated mouse selects once")
		check(VehicleLivery.for_car(page.records.settings,"compact")==page.draft,"livery tap persists locally")
		mouse(point,true)
		var move := InputEventMouseMotion.new()
		move.position = point+Vector2(0,-75)
		move.relative = Vector2(0,-75)
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(move,true)
		mouse(move.position,false)
		await settle()
		check(taps[0]==1 and scroll.scroll_vertical>=65,"desktop drag scrolls without selecting")
		var before_wheel: int = scroll.scroll_vertical
		mouse(scroll.get_global_rect().get_center(),true,MOUSE_BUTTON_WHEEL_DOWN)
		mouse(scroll.get_global_rect().get_center(),false,MOUSE_BUTTON_WHEEL_DOWN)
		await settle()
		check(scroll.scroll_vertical>before_wheel,"desktop wheel remains available")
		scroll.scroll_vertical = 0
		await settle()
		point = tile.get_global_rect().get_center()
		mouse(point,true)
		mouse(point,false)
		await settle()
		check(taps[0]==2,"desktop click selects once")
		scroll.scroll_vertical = 0
		await settle()
		var scrollbar: VScrollBar = scroll.get_v_scroll_bar()
		point = scrollbar.get_global_rect().position+Vector2(scrollbar.size.x*0.5,scrollbar.size.y*0.04)
		move = InputEventMouseMotion.new()
		move.position = point
		root.push_input(move,true)
		await process_frame
		mouse(point,true)
		await process_frame
		move = InputEventMouseMotion.new()
		move.position = point+Vector2(0,100)
		move.relative = Vector2(0,100)
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(move,true)
		await process_frame
		mouse(move.position,false)
		await settle()
		check(scroll.scroll_vertical>0,"native scrollbar remains interactive")
		scroll.scroll_vertical = 0
		await settle()
		point = tile.get_global_rect().get_center()
		touch(point,true)
		page._set_customise_tab("colours")
		await settle()
		page._set_customise_tab("livery")
		await settle()
		touch(point,false)
		check(taps[0]==2,"hidden cached tab cancels pending tap")
		root.size = Vector2i(960,540)
		root.content_scale_size = root.size
		await settle()
		await scroll_checks(scroll,"patterns-960",true)
		page._set_customise_tab("colours")
		await settle()
		var colour_scroll: ScrollContainer = page.livery_menu._content.find_children("*","ScrollContainer",true,false)[0]
		await scroll_checks(colour_scroll,"colours-960")
		var picker: ColorPickerButton = page.pickers[page._colour_slot]
		colour_scroll.ensure_control_visible(picker)
		await settle()
		point = picker.get_global_rect().get_center()
		mouse(point,true)
		mouse(point,false)
		await settle()
		check(picker.get_popup().visible,"custom colour popup keeps native click")
		picker.get_popup().hide()
		await settle()
		page._set_customise_tab("stickers")
		await settle()
		for surface: String in ["hood","roof"]:
			page._choose_sticker_surface(surface)
			for category: String in ["emblems","sponsors"]:
				page.livery_menu._choose_sticker_category(category)
				await settle()
				var sticker_scroll: ScrollContainer = page.livery_menu._content.find_children("*","ScrollContainer",true,false)[0]
				await scroll_checks(sticker_scroll,"stickers-"+surface+"-"+category,true)
		var sticker_scroll: ScrollContainer = page.livery_menu._content.find_children("*","ScrollContainer",true,false)[0]
		var sticker: LiveryTile = page.livery_menu.sticker_tiles.values()[0]
		sticker_scroll.ensure_control_visible(sticker)
		await settle()
		point = sticker.get_global_rect().intersection(sticker_scroll.get_global_rect()).get_center()
		touch(point,true)
		touch(point,false)
		await settle()
		check(page.draft.stickers.roof.id==str(sticker.name).trim_prefix("Sticker_"),"sticker tap selects after scrolling")
		var place: BaseButton = page.livery_menu.active_control("PlaceSticker")
		sticker_scroll.ensure_control_visible(place)
		await settle()
		point = place.get_global_rect().get_center()
		touch(point,true)
		touch(point,false)
		await settle()
		check(page._sticker_editing and is_instance_valid(page._sticker_board),"scrollable Place sticker opens dedicated editor")
		var board: StickerPlacement = page._sticker_board
		point = board.global_position+board.panel_rect().get_center()
		touch(point,true)
		drag(point+Vector2(0,20))
		touch(point+Vector2(0,20),false)
		await settle()
		check(page.draft.stickers.roof.y>0.5 and VehicleLivery.for_car(page.records.settings,"compact").stickers.roof==page.draft.stickers.roof,"placement drag still moves and saves sticker")
		page._show_section("tuning")
		await settle()
		await scroll_checks(page.kit_scroll,"tuning-960",true)
		var last: Control = page.kit_cards.get_child(page.kit_cards.get_child_count()-1)
		last.grab_focus()
		await settle()
		check(page.kit_scroll.get_global_rect().encloses(last.get_global_rect()),"keyboard focus still reveals last kit")
		check(CompactKitThumbnail.images.size()<=16,"sixteen-photo cache bound retained")
	check(page.showroom==showroom and showroom.car==car and showroom.camera.transform==camera,"swipes and tabs retain actual car and camera")
	check(showroom.weathering.snapshot()==condition,"swipes retain exact local condition")
	app.queue_free()
	await process_frame
	print("GARAGE_SWIPE_SCROLL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
