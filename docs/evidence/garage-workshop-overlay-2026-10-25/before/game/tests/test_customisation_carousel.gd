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
	while page._menu_motion != null or (page.showroom.camera_motion != null and page.showroom.camera_motion.is_running()): await process_frame
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
	print("PARTS_STAGE: new page")
	page = GaragePage.new()
	page.records = LocalRecords.new("user://customisation_carousel_"+TrackLibrary.unique_id()+".json")
	page.economy = shop
	print("PARTS_STAGE: attach page")
	host.add_child(page)
	print("PARTS_STAGE: page attached")
	MenuStyle.fill(page)
	page.offset_left = 20
	page.offset_right = -20
	page.offset_top = 112
	page.offset_bottom = -20
	page.open_car(0)
	print("PARTS_STAGE: open parts")
	page._show_section("tuning")
	print("PARTS_STAGE: parts opened")
	await settle()
	print("PARTS_STAGE: initial layout settled")
	var original: Dictionary = page.records.settings.duplicate(true)
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var camera: Transform3D = page.showroom.camera.transform
	for category: String in VehicleCustomisation.CATEGORIES:
		print("PARTS_STAGE: category "+category)
		page._select_kit_category(category)
		await settle()
		for index: int in range(1,VehicleCustomisation.OPTIONS[category].size()):
			var option: Array = VehicleCustomisation.OPTIONS[category][index]
			page.kit_cards.get_child(index).pressed.emit()
			check(page.showroom.customisation[category] == option[0],"unowned preview visible "+category+"/"+str(option[0]))
			check(page.kit_draft[category] == "stock" and page.records.settings == original,"preview leaves equipped/save exact "+category+str(index))
			check(shop.purchases == 0 and page._purchase_dialog == null,"browse never purchases or opens confirmation")
			check(not page._part_highlight.meshes.is_empty(),"selected native part highlighted "+category)
		await settle()
		check(page.showroom.car == car and page.showroom.showroom_viewport == viewport,"preview retains actual car and viewport "+category)
		check(page._customisation_camera.focused_category == category and not page.showroom.camera.transform.is_equal_approx(camera),"main Garage camera focuses on "+category)
		var target_pixel: Vector2 = page.showroom.camera.unproject_position(page._customisation_camera.target)
		check(target_pixel.distance_to(Vector2(page.showroom.showroom_viewport.size)*0.5) < 3.0,"selected part is centered in the Garage "+category)
		await capture("focus-"+category)
		var focus_distance: float = page.showroom.camera.global_position.distance_to(page._customisation_camera.target)
		page.showroom.rotate_view(Vector2(12,4))
		page.showroom.zoom_by(0.85)
		var moved_target: Vector2 = page.showroom.camera.unproject_position(page._customisation_camera.target)
		check(moved_target.distance_to(Vector2(page.showroom.showroom_viewport.size)*0.5)<3.0,"dragging keeps the selected part centered "+category)
		check(page.showroom.camera.global_position.distance_to(page._customisation_camera.target)<focus_distance,"zoom controls stay close to the selected part "+category)
		page._preview_kit(category,"stock")
		check(page.showroom.customisation[category] == "stock" and page.records.settings == original,"original option previews without saving "+category)
		page.kit_shelf.cancel.pressed.emit()
		check(page.showroom.customisation == page.kit_draft and page._part_highlight.meshes.is_empty(),"cancel restores part and highlight "+category)
		check(page.showroom.camera.transform.is_equal_approx(camera),"cancel restores the exact preceding Garage camera "+category)
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
		check(page._workshop_tabs.visible,"Workshop side submenu groups the car tasks")
		check(page._workshop_tabs.get_global_rect().end.x <= page.preview.global_position.x,"Workshop submenu stays left of the car")
		check(absf(page.preview.global_position.y-page.tools_panel.global_position.y)<1,"no navigation row above the car")
		check(not page.kit_shelf.photo.visible and page.kit_shelf.detail_viewport == null,"Garage view replaces the separate detail photo")
		check(page.kit_scroll.size.y > page.kit_shelf.size.y*0.45,"parts use most of the Customise card")
		check(page.kit_cards.columns == 2 and page.kit_cards.get_child(0).size.y >= 156,"large parts cards fill two columns")
		check(page.kit_shelf.cancel.text == "Cancel preview" and page.kit_shelf.cancel.visible,"preview has a named cancellation action")
		check(page.kit_shelf.cancel.size.x>=52,"cancel retains its touch target")
		await capture("kits-"+str(dimensions.x))
		await gesture(page.kit_scroll,shop)
		var last: Control = page.kit_cards.get_child(page.kit_cards.get_child_count()-1)
		last.grab_focus()
		await settle()
		check(page.kit_scroll.get_global_rect().encloses(last.get_global_rect()),"keyboard reveals last full card "+str(dimensions)+" viewport="+str(page.kit_scroll.get_global_rect())+" card="+str(last.get_global_rect()))
		var maximum: int = maxi(0,roundi(page.kit_scroll.get_v_scroll_bar().max_value-page.kit_scroll.get_v_scroll_bar().page))
		page.kit_scroll.scroll_vertical = maximum
		await settle()
		check(page.kit_scroll.scroll_vertical == maximum,"catalogue reaches its last row")
		page._show_section("customise")
		page._set_customise_tab("livery")
		await settle()
		page.livery_menu.pattern_tiles[2].pressed.emit()
		await settle()
		check(page.tools_panel.get_global_rect().encloses(page.livery_menu.pattern_shelf.equip.get_global_rect()),"pattern equip fits "+str(dimensions))
		await capture("patterns-"+str(dimensions.x))
	page._set_customise_tab("colours")
	page._preview_color(Color(str(page.draft.colors.body)),"body")
	await settle()
	check(page._customisation_camera.focused_category == "body","paint selection focuses on the body")
	page._set_customise_tab("stickers")
	page._choose_sticker_surface("roof")
	await settle()
	check(page._customisation_camera.focused_category == "roof","roof sticker selection focuses on the roof")
	page.hide()
	check(page._customisation_camera.focused_category.is_empty(),"leaving Garage releases the focused camera")
	check(page._cosmetic_preview.is_empty() and page.showroom.livery == page.draft,"hiding discards unsaved preview")
	host.queue_free()
	await process_frame
	await reference_states()
	await actual_app()
	print("CUSTOMISATION_CAROUSEL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func reference_states() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var scene := Control.new()
	root.add_child(scene)
	MenuStyle.fill(scene)
	var shop := Shop.new()
	shop.owned.append("kit/compact/hood/scoop")
	scene.add_child(shop)
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.pattern = "apex_twin"
	paint.colors = {"body":"a44844","accent":"efe5cf","detail":"c78e4c"}
	page = GaragePage.new()
	page.records = LocalRecords.new("user://reference_painted_"+TrackLibrary.unique_id()+".json")
	page.records.settings.vehicle_liveries = {"compact":paint}
	page.economy = shop
	scene.add_child(page)
	MenuStyle.fill(page)
	page.offset_left = 20
	page.offset_right = -20
	page.offset_top = 112
	page.offset_bottom = -20
	page.open_car(0)
	page._show_section("tuning")
	await settle()
	var actual_car: CarVisual = page.showroom.car
	var actual_camera: Transform3D = page.showroom.camera.transform
	var saved: Dictionary = page.records.settings.duplicate(true)
	await photos_settled()
	check(not page.kit_shelf.equip.visible and not page.kit_shelf.cancel.visible and not page.kit_shelf.state.visible,"equipped item has no disabled action or repeated status")
	check(page.showroom.car==actual_car and page.showroom.camera.transform==actual_camera and page.records.settings==saved,"option photography preserves actual car/camera/save")
	for index: int in range(page.kit_cards.get_child_count()):
		var card: CompactKitThumbnail = page.kit_cards.get_child(index)
		check(card.get_meta("photo_livery")==paint,"thumbnail uses the car's exact paint "+str(index))
		check(card.get_meta("photo_parts").hood==VehicleCustomisation.OPTIONS.hood[index][0],"thumbnail uses the correct candidate part "+str(index))
		check(card.viewport==null,"photography does not create a world per option")
		if DisplayServer.get_name() != "headless":
			var pixels: Image = card.image.texture.get_image()
			var red: int = 0
			for y: int in range(0,pixels.get_height(),4):
				for x: int in range(0,pixels.get_width(),4):
					var colour: Color = pixels.get_pixel(x,y)
					if colour.r>0.15 and colour.r>colour.g*1.15 and colour.r>colour.b*1.15: red += 1
			check(red>pixels.get_width()*pixels.get_height()/16*0.05,"rendered red-paint pixels replace blue stock photo "+str(index))
	var renderer: Node = page.kit_photos
	check(renderer.peak_worlds<=1 and renderer.active_worlds==0 and renderer.viewport==null,"one temporary photo studio releases after preparation")
	var prepared: int = renderer.rendered
	page._build_kit_cards()
	await photos_settled()
	check(renderer.rendered==prepared,"identical appearance reuses cached photos without rendering")
	check(CompactKitThumbnail.images.size()<=16,"painted photos share the sixteen-image bound")
	var first_key: String = page.kit_cards.get_child(1).cache_key
	var green: Dictionary = paint.duplicate(true)
	green.colors.body = "397654"
	page.records.settings.vehicle_liveries.compact = green
	page.refresh_cosmetics()
	await photos_settled()
	check(page.kit_cards.get_child(1).cache_key!=first_key and page.kit_cards.get_child(1).get_meta("photo_livery")==green,"paint refresh invalidates the old photo key")
	if DisplayServer.get_name()!="headless":
		var pixels: Image = page.kit_cards.get_child(1).image.texture.get_image()
		var green_pixels: int = 0
		for y: int in range(0,pixels.get_height(),4):
			for x: int in range(0,pixels.get_width(),4):
				var colour: Color = pixels.get_pixel(x,y)
				if colour.g>0.15 and colour.g>colour.r*1.15 and colour.g>colour.b*1.15: green_pixels += 1
		check(green_pixels>pixels.get_width()*pixels.get_height()/16*0.05,"paint refresh changes the actual rendered thumbnail pixels")
	page.records.settings.vehicle_liveries.compact = paint
	page.refresh_cosmetics()
	await photos_settled()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		page._cancel_cosmetic_preview()
		await settle()
		await capture("reference-equipped-"+str(dimensions.x))
		await capture_panel("panel-equipped-"+str(dimensions.x))
		page._preview_kit("hood","louvres")
		await settle()
		check(page.kit_shelf.equip.visible and page.kit_shelf.equip.text.contains("750"),"unowned preview retains explicit priced equip")
		check(page.tools_panel.get_global_rect().encloses(page.kit_shelf.cancel.get_global_rect()),"cancel remains inside short/tall workbench")
		await capture_panel("panel-unowned-"+str(dimensions.x))
		page._preview_kit("hood","scoop")
		await settle()
		check(page.kit_shelf.equip.text=="Equip" and shop.purchases==0,"owned preview has an equip action without purchasing")
		await capture_panel("panel-owned-"+str(dimensions.x))
	scene.queue_free()
	await process_frame

func photos_settled() -> void:
	for tick: int in range(180):
		if not page.kit_photos.busy: break
		await process_frame
	check(not page.kit_photos.busy,"bounded photo work settles")
	await settle()

func capture_panel(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var image: Image = root.get_texture().get_image().get_region(Rect2i(page.tools_panel.get_global_rect()))
	check(image.save_png(output.path_join(label+".png"))==OK,"panel capture "+label)

func gesture(scroll: ScrollContainer, shop: Shop) -> void:
	var preview: Dictionary = page._cosmetic_preview.duplicate(true)
	var purchases: int = shop.purchases
	scroll.scroll_vertical = 0
	await settle()
	var start: Vector2 = scroll.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 7
	down.position = start
	down.pressed = true
	scroll._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = start-Vector2(0,85)
	scroll._input(drag)
	check(scroll.dragged and scroll.scroll_vertical>0,"touch swipe moves the parts catalogue")
	down.position = drag.position
	down.pressed = false
	scroll._input(down)
	await settle()
	check(page._cosmetic_preview == preview and shop.purchases == purchases,"swipe release cannot select or buy a card")

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
		check(absf(page._preview_column.global_position.y-page.tools_panel.global_position.y)<1,"actual App Workshop column and workbench align at the top")
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
	var directory: String = output.path_join("focus-motion")
	DirAccess.make_dir_recursive_absolute(directory)
	for segment: int in range(2):
		var category: String = "rims" if segment == 0 else "aero"
		page._select_kit_category(category)
		page._preview_kit(category,str(VehicleCustomisation.OPTIONS[category][1][0]))
		for frame: int in range(16):
			await create_timer(1.0/30.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("frame-%02d.png" % (segment*16+frame)))
