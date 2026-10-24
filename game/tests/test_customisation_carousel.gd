extends SceneTree
## Native preview/equip boundaries, carousel input and actual App captures.
var page: GaragePage
var checks: int = 0
var failures: int = 0
var output: String

class Shop extends Node:
	signal changed
	var scope: String = "fixture/alice"
	var status: String = ""
	var busy: bool = false
	var pending: Dictionary = {}
	var purchases: int = 0
	var owned: Array[String] = []
	func owns(id: String) -> bool: return id.ends_with("/stock") or id == "livery/plain" or id in owned
	func price(_id: String) -> int: return 750
	func caption(id: String) -> String: return "Owned" if owns(id) else "750 coins"
	func balance() -> int: return 3000
	func authenticated() -> bool: return true
	func refresh() -> void: pass
	func purchase(id: String) -> bool:
		purchases += 1
		await get_tree().create_timer(0.1).timeout
		owned.append(id)
		changed.emit()
		return true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	while page._menu_motion != null: await process_frame
	for frame: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/customisation-carousel-2026-10-24/native"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	VehicleCatalog.selected = "compact"
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	var shop := Shop.new()
	host.add_child(shop)
	page = GaragePage.new()
	page.records = LocalRecords.new("user://customisation_carousel_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	host.add_child(page)
	MenuStyle.fill(page)
	page.offset_left = 20
	page.offset_right = -20
	page.offset_top = 112
	page.offset_bottom = -20
	page.open_car(0)
	page._show_section("tuning")
	await settle()
	var original: Dictionary = page.records.settings.duplicate(true)
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var camera: Transform3D = page.showroom.camera.transform
	for category: String in VehicleCustomisation.CATEGORIES:
		page._select_kit_category(category)
		await settle()
		for index: int in range(1,VehicleCustomisation.OPTIONS[category].size()):
			var option: Array = VehicleCustomisation.OPTIONS[category][index]
			page.kit_cards.get_child(index).pressed.emit()
			check(page.showroom.customisation[category] == option[0],"unowned preview visible "+category+"/"+str(option[0]))
			check(page.kit_draft[category] == "stock" and page.records.settings == original,"preview leaves equipped/save exact "+category+str(index))
			check(shop.purchases == 0 and page._purchase_dialog == null,"browse never purchases or opens confirmation")
			check(not page._part_highlight.meshes.is_empty(),"selected native part highlighted "+category)
		check(page.showroom.car == car and page.showroom.showroom_viewport == viewport and page.showroom.camera.transform == camera,"preview retains car/viewport/camera "+category)
		page._preview_kit(category,"stock")
		check(page.showroom.customisation[category] == "stock" and page.records.settings == original,"original option previews without saving "+category)
		page.kit_shelf.cancel.pressed.emit()
		check(page.showroom.customisation == page.kit_draft and page._part_highlight.meshes.is_empty(),"cancel restores part and highlight "+category)
	check(CompactKitThumbnail.images.size()<=16,"sixteen-photo cache remains bounded")
	page._select_kit_category("hood")
	page._preview_kit("hood","louvres")
	page._equip_cosmetic_preview()
	check(page._purchase_dialog != null and shop.purchases == 0,"only explicit equip opens confirmation")
	page._purchase_dialog.hide()
	await process_frame
	check(page.showroom.customisation.hood == "louvres" and page.kit_draft.hood == "stock","declining purchase keeps a free preview")
	page._equip_cosmetic_preview()
	page._purchase_dialog.confirmed.emit()
	page._purchase_dialog.hide()
	page._cancel_cosmetic_preview()
	await create_timer(0.2).timeout
	check(shop.purchases == 1 and page.kit_draft.hood == "stock","late purchase response cannot equip cancelled preview")
	page._preview_kit("hood","louvres")
	page._equip_cosmetic_preview()
	check(page.kit_draft.hood == "louvres" and page._cosmetic_preview.is_empty(),"owned equip saves only after explicit action")
	page._preview_kit("hood","scoop")
	page._equip_cosmetic_preview()
	page._purchase_dialog.confirmed.emit()
	page._purchase_dialog.hide()
	await create_timer(0.2).timeout
	check(page.kit_draft.hood == "scoop" and shop.purchases == 2,"confirmed unlock equips the exact preview")
	var reload := LocalRecords.new(page.records.path)
	reload.load_records()
	check(VehicleCustomisation.for_car(reload.settings,"compact").hood == "scoop","explicit equip survives local reload")
	page._preview_kit("hood","louvres")
	page._equip_cosmetic_preview()
	page._preview_kit("hood","scoop")
	shop.scope = "fixture/bob"
	shop.changed.emit()
	check(page._cosmetic_preview.is_empty() and page.showroom.customisation.hood == "louvres","account switch restores equipped appearance")
	page._preview_kit("hood","dome")
	page._show_section("care")
	check(page.showroom.customisation.hood == "louvres" and page._part_highlight.meshes.is_empty(),"navigation discards preview and overlay")
	page._show_section("customise")
	await settle()
	var paint: Dictionary = page.draft.duplicate(true)
	var saved: Dictionary = page.records.settings.duplicate(true)
	page.livery_menu.pattern_tiles[2].pressed.emit()
	check(page.showroom.livery.pattern == page._preset_value(2).pattern and page.draft == paint and page.records.settings == saved,"unowned pattern previews without saving")
	check(page._purchase_dialog == null and shop.purchases == 2,"pattern browsing never purchases")
	page.livery_menu.pattern_shelf.cancel.pressed.emit()
	check(page.showroom.livery == paint,"cancel restores equipped paint exactly")
	page.livery_menu.pattern_tiles[3].pressed.emit()
	page._set_customise_tab("colours")
	check(page.showroom.livery == paint and page._cosmetic_preview.is_empty(),"changing paint tab discards pattern preview")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		page._show_section("tuning")
		await settle()
		page._select_kit_category("hood")
		page._preview_kit("hood","scoop")
		await settle()
		check(page.get_global_rect().encloses(page.tools_panel.get_global_rect()),"workbench fits "+str(dimensions))
		check(page.tools_panel.get_global_rect().encloses(page.kit_shelf.equip.get_global_rect()),"equip fits "+str(dimensions))
		check(page.tools_panel.get_global_rect().encloses(page.kit_scroll.get_global_rect()),"carousel fits "+str(dimensions))
		check(not page.actions.visible and page.actions.get_child_count() == 0,"customisation has no bottom buttons "+str(dimensions))
		check(not page._workshop_tabs.visible,"single navigation rail replaces the top workshop row")
		check(page.kit_shelf.photo.visible and page.kit_shelf.photo.size.y >= 64,"detail photo remains visible on short layouts")
		check(page.kit_shelf.cancel.text == "Cancel preview" and page.kit_shelf.cancel.visible,"preview has a named cancellation action")
		if dimensions.x == 1720:
			check(page.kit_scroll.size.x >= page.kit_cards.get_child(0).size.x*4+24,"four complete choices fit the large workbench")
		check(page.kit_shelf.cancel.size.x>=52 and page.kit_shelf._left.size.x>=52,"touch actions >=52")
		if DisplayServer.get_name() != "headless" and dimensions.y >= 650:
			check(page.kit_shelf.detail_viewport.find_world_3d() == page.showroom.showroom_viewport.find_world_3d(),"detail camera shares actual car world")
			var pixels: Image = page.kit_shelf.detail_viewport.get_texture().get_image()
			var colours: Dictionary = {}
			for y: int in range(12,pixels.get_height(),24):
				for x: int in range(12,pixels.get_width(),24): colours[pixels.get_pixel(x,y).to_html()] = true
			check(colours.size()>16,"detail camera renders real geometry")
			check(page.kit_shelf.detail_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS,"detail view renders only when changed")
		await capture("kits-"+str(dimensions.x))
		await gesture(page.kit_scroll,shop)
		var last: Control = page.kit_cards.get_child(page.kit_cards.get_child_count()-1)
		last.grab_focus()
		await settle()
		check(page.kit_scroll.get_global_rect().encloses(last.get_global_rect()),"keyboard reveals last full card "+str(dimensions))
		var maximum: int = maxi(0,roundi(page.kit_scroll.get_h_scroll_bar().max_value-page.kit_scroll.get_h_scroll_bar().page))
		page.kit_scroll.scroll_horizontal = maximum
		page.kit_scroll.settle_cards(1)
		check(absf(page.kit_scroll.overscroll_offset)>0,"end arrow gives bounded bounce")
		await create_timer(0.5).timeout
		check(is_zero_approx(page.kit_scroll.overscroll_offset) and page.kit_scroll.scroll_horizontal == maximum,"end animation settles at final option")
		page._show_section("customise")
		page._set_customise_tab("livery")
		await settle()
		page.livery_menu.pattern_tiles[2].pressed.emit()
		await settle()
		check(page.tools_panel.get_global_rect().encloses(page.livery_menu.pattern_shelf.equip.get_global_rect()),"pattern equip fits "+str(dimensions))
		await capture("patterns-"+str(dimensions.x))
	page.hide()
	check(page._cosmetic_preview.is_empty() and page.showroom.livery == page.draft,"hiding discards unsaved preview")
	host.queue_free()
	await process_frame
	await actual_app()
	print("CUSTOMISATION_CAROUSEL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func gesture(scroll: ScrollContainer, shop: Shop) -> void:
	var preview: Dictionary = page._cosmetic_preview.duplicate(true)
	var purchases: int = shop.purchases
	var start: Vector2 = scroll.get_global_rect().get_center()
	var old_scroll: int = scroll.scroll_horizontal
	var down := InputEventScreenTouch.new()
	down.index = 7
	down.position = start
	down.pressed = true
	scroll._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = start-Vector2(85,0)
	scroll._input(drag)
	check(scroll.dragging and scroll.scroll_horizontal>old_scroll,"touch swipe moves carousel")
	down.position = drag.position
	down.pressed = false
	scroll._input(down)
	await create_timer(0.45).timeout
	check(page._cosmetic_preview == preview and shop.purchases == purchases,"swipe release cannot select or buy a card")
	scroll.scroll_horizontal = 0
	scroll.settle_cards(-1)
	check(scroll.overscroll_offset>0,"first option gives start bounce")
	await create_timer(0.45).timeout
	check(is_zero_approx(scroll.overscroll_offset) and scroll.scroll_horizontal == 0,"start bounce settles exactly")

func actual_app() -> void:
	var directory: String = "user://carousel_app_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	page = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	await settle()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		page._show_section("tuning")
		await settle()
		page._preview_kit("hood","louvres")
		await settle()
		check(page.showroom.customisation.hood == "louvres" and page.kit_draft.hood == "stock","actual guest App freely previews unowned part")
		check(not page.actions.visible and page.actions.get_child_count() == 0,"actual App removes both bottom customisation buttons")
		check(root.get_visible_rect().encloses(page.tools_panel.get_global_rect()),"actual App workbench fits "+str(dimensions))
		check(absf(page.preview.position.y-page.tools_panel.position.y)<1,"actual App car and workbench align at the top")
		await capture("app-kits-"+str(dimensions.x))
		if dimensions.x == 1280:
			await record_motion()
			for category: String in ["aero","rims","body"]:
				page._select_kit_category(category)
				var option: String = str(VehicleCustomisation.OPTIONS[category][1][0])
				page._preview_kit(category,option)
				await settle()
				check(page.showroom.customisation[category] == option and page.kit_draft[category] == "stock","actual App freely previews "+category)
				await capture("app-part-"+category+"-1280")
			page._select_kit_category("hood")
		page._show_section("customise")
		page._preview_livery(2)
		await settle()
		await capture("app-patterns-"+str(dimensions.x))
	app.queue_free()
	await process_frame

func record_motion() -> void:
	if DisplayServer.get_name() == "headless": return
	var directory: String = output.path_join("carousel-motion")
	DirAccess.make_dir_recursive_absolute(directory)
	page.kit_scroll._stop_snap()
	page.kit_scroll.scroll_horizontal = 0
	for segment: int in range(2):
		page.kit_scroll.settle_cards(-1 if segment == 0 else 1)
		for frame: int in range(12):
			await create_timer(1.0/30.0).timeout
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image().get_region(Rect2i(page.tools_panel.get_global_rect()))
			image.save_png(directory.path_join("frame-%02d.png" % (segment*12+frame)))
