extends SceneTree
## Selected-icon motion, interruption/lifetime guards and actual dropdown saving.
const Profile = preload("res://ui/profile_car.gd")
const Icons = preload("res://ui/header_car_icons.gd")
var checks: int = 0
var failures: int = 0
var pictures: Dictionary = {}
var presented_samples: Array[Dictionary] = []
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 4) -> void:
	for _frame: int in range(count): await process_frame

func choose(icon: Control, vehicle: String) -> void:
	VehicleCatalog.selected = vehicle
	icon.refresh()

func settled(icon: Control, vehicle: String) -> bool:
	return icon.preview.texture == Icons.texture(vehicle) and icon._change == null and icon._outgoing == null and icon.preview.modulate == Color.WHITE and icon.preview.position == Vector2.ZERO

func picture_bounds(icon: Control, label: String) -> void:
	var valid: bool = true
	for child: Node in icon.get_children():
		if not child is TextureRect: continue
		# Observe the image rectangles, independently of the outer retained slot.
		valid = valid and child.size.is_equal_approx(icon.size)
		valid = valid and child.position.is_equal_approx(Vector2.ZERO)
	check(valid,"both pictures stay in the same fixed rectangle: "+label)
	if icon._change == null:
		check(icon.preview.get_rect().is_equal_approx(Rect2(Vector2.ZERO,icon.size)),"settled picture fills its exact slot: "+label)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	pictures[label] = root.get_texture().get_image()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	var destination: String = OS.get_environment("BMT_HEADER_ICON_OUTPUT")
	if destination.is_empty(): destination = "res://../docs/evidence/header-car-icon-transition-2026-10-26"
	output = ProjectSettings.globalize_path(destination.path_join(RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(output)
	VehicleCatalog.selected = "compact"
	var icon: Control = Profile.new()
	icon.size = Vector2(88,56)
	root.add_child(icon)
	await frames()
	check(settled(icon,"compact"),"first attachment immediately shows the selected picture")
	var preview: TextureRect = icon.preview
	# Reproduce the viewport-sized intermediate rectangle used while reparenting.
	for extent: Vector2 in [Vector2(1280,720),Vector2(88,56),Vector2(240,64),Vector2(88,56)]:
		icon.size = extent
		await frames(2)
		picture_bounds(icon,"parent resize "+str(extent))
	for vehicle: String in VehicleCatalog.IDS:
		if vehicle == "compact": continue
		var previous: Texture2D = preview.texture
		choose(icon,vehicle)
		check(icon._outgoing != null and icon._outgoing.texture == previous,"retain outgoing picture: "+vehicle)
		check(preview.texture == Icons.texture(vehicle) and preview.modulate.a == 0.0,"new picture begins transparent: "+vehicle)
		var current: Tween = icon._change
		icon.refresh()
		check(icon._change == current,"unchanged refresh does not restart: "+vehicle)
		await create_timer(0.07).timeout
		check(preview.modulate.a > 0.0 and preview.modulate.a < 1.0 and preview.position == Vector2.ZERO,"visible stationary intermediate blend: "+vehicle)
		picture_bounds(icon,"mid-change "+vehicle)
		await create_timer(0.25).timeout
		check(settled(icon,vehicle) and icon.get_child_count() == 1,"exact endpoint and cleanup: "+vehicle)
		picture_bounds(icon,"settled "+vehicle)
	check(icon.preview == preview,"all changes retain the original picture control")
	choose(icon,"compact")
	await create_timer(0.04).timeout
	choose(icon,"pickup")
	choose(icon,"classic")
	choose(icon,"forklift")
	var peak: int = 0
	for _frame: int in range(70):
		peak = maxi(peak,icon.get_child_count())
		await process_frame
	check(peak == 2 and settled(icon,"forklift"),"rapid changes coalesce to latest with at most two pictures")
	choose(icon,"electric")
	choose(icon,"kart")
	icon.hide()
	check(settled(icon,"kart"),"hiding cancels motion and resolves latest selection")
	icon.show()
	choose(icon,"formula")
	icon.size = Vector2(96,64)
	check(settled(icon,"formula"),"resize clears offsets and temporary pictures")
	picture_bounds(icon,"resize during motion")
	choose(icon,"pickup")
	root.remove_child(icon)
	check(settled(icon,"pickup"),"detaching stops the transition")
	root.add_child(icon)
	await frames()
	check(settled(icon,"pickup"),"reattachment preserves the selected endpoint")
	picture_bounds(icon,"reattachment")
	choose(icon,"electric")
	var removed: WeakRef = weakref(icon)
	icon.queue_free()
	await frames()
	check(removed.get_ref() == null,"free during motion leaves no retained widget")
	check(root.find_children("*","SubViewport",true,false).is_empty(),"icon motion creates no rendering viewports")
	await app_review()
	for label: String in pictures:
		check(pictures[label].save_png(output.path_join(label+".png")) == OK,"save native frame: "+label)
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"native_frames":pictures.keys(),"duration":Profile.CHANGE_SECONDS,"presented_samples":presented_samples},"\t"))
	report.close()
	print("HEADER_ICON_TRANSITION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func app_review() -> void:
	VehicleCatalog.selected = "compact"
	var app: Node = load("res://core/app.gd").new()
	var folder: String = "user://header-icon-transition-"+TrackLibrary.unique_id()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await frames(12)
	var icon: Control = app.account_button.get_node("MenuProfileCar")
	var picker: MenuButton = app.account_button.get_node("MenuCarPicker")
	var popup: PopupMenu = picker.get_popup()
	var bounds: Rect2 = icon.get_global_rect()
	await click(root.get_final_transform()*picker.get_global_rect().get_center())
	await create_timer(0.26).timeout
	check(popup.visible and popup.item_count == 6,"actual header opens six alternatives")
	await capture("dropdown-before-selection")
	await frames(8)
	for _step: int in range(popup.item_count-1): await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(VehicleCatalog.selected == "electric" and not popup.visible,"native keyboard choice immediately selects the actual car")
	check(icon._change != null,"native choice starts the header picture transition")
	await capture("keyboard-change-start")
	await create_timer(0.07).timeout
	await capture("keyboard-change-middle")
	await create_timer(0.28).timeout
	await capture("keyboard-change-finished")
	check(settled(icon,"electric") and icon.get_global_rect() == bounds,"header finishes on Electric without changing layout")
	var saved := LocalRecords.new(app.records.path)
	saved.load_records()
	check(saved.settings.get("selected_car") == "electric","animation preserves saved keyboard selection")
	for extent: Vector2i in [Vector2i(960,540),Vector2i(1720,900)]:
		root.size = extent
		await frames(10)
		app._select_header_vehicle(VehicleCatalog.IDS.find("forklift" if extent.x == 960 else "classic"))
		await capture("change-%d-start" % extent.x)
		await create_timer(0.07).timeout
		await capture("change-%d-middle" % extent.x)
		await create_timer(0.28).timeout
		await capture("change-%d-finished" % extent.x)
		check(settled(icon,VehicleCatalog.selected),"actual header settles at width %d" % extent.x)
	root.size = Vector2i(1280,720)
	await frames(10)
	picker.show_popup()
	await create_timer(0.26).timeout
	var panel: StyleBox = popup.get_theme_stylebox("panel")
	var row_height: float = (popup.size.y-panel.get_minimum_size().y)/popup.item_count
	await click(root.get_final_transform()*(Vector2(popup.position)+Vector2(80,panel.get_content_margin(SIDE_TOP)+row_height*0.5)))
	check(VehicleCatalog.selected == "compact" and not popup.visible,"native mouse choice selects Compact")
	await create_timer(0.28).timeout
	check(settled(icon,"compact"),"mouse choice finishes on Compact")
	saved.load_records()
	check(saved.settings.get("selected_car") == "compact","animation preserves saved mouse selection")
	await presented_fade_review(app,icon)
	app._select_header_vehicle(VehicleCatalog.IDS.find("electric"))
	app._show_screen("settings")
	await frames(12)
	check(app._retained_profile_car == icon and settled(icon,"electric"),"navigation retains the widget and resolves interrupted motion")
	await navigation_fit_review(app,icon)
	var old: WeakRef = weakref(icon)
	app.records = LocalRecords.new(folder.path_join("other-records.json"))
	app._show_screen("tracks")
	await frames()
	check(old.get_ref() == null and app._retained_profile_car.records == app.records,"another records owner releases the previous icon")
	app.queue_free()
	await frames(8)

func presented_fade_review(app: Node, icon: Control) -> void:
	if DisplayServer.get_name()=="headless": return # Equipped capture needs a renderer.
	# Use the real equipped-image capture, then switch back to its warm cache.
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "c82e37"
	paint.pattern = str(LiveryCatalog.patterns[3].id)
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "cowl"
	parts.aero = "splitwing"
	app.records.settings.vehicle_liveries = {"compact":paint}
	app.records.settings.vehicle_customisation = {"compact":parts}
	check(app.records.save_records()==OK,"save equipped fade fixture")
	var deadline: int = Time.get_ticks_msec()+60000
	while not app.header_car_cache.idle() and Time.get_ticks_msec()<deadline: await process_frame
	await create_timer(0.4).timeout
	var equipped: Texture2D = Icons.texture("compact",app.records)
	check(equipped!=Icons.texture("compact"),"fade fixture uses the actual equipped livery and kit cache")
	app._select_header_vehicle(VehicleCatalog.IDS.find("electric"))
	await create_timer(0.4).timeout
	var captures: int = app.header_car_cache.captures
	app._select_header_vehicle(VehicleCatalog.IDS.find("compact"))
	await capture("equipped-fade-start")
	# A cold image/driver/IO stall must not consume every visible blend frame.
	OS.delay_msec(350)
	var intermediate: int = 0
	for index: int in range(7):
		if DisplayServer.get_name()=="headless": await process_frame
		else: await RenderingServer.frame_post_draw
		var alpha: float = icon.preview.modulate.a
		if alpha>=0.05 and alpha<=0.85 and is_instance_valid(icon._outgoing) and icon._outgoing.modulate.a>=0.15: intermediate += 1
		presented_samples.append({"frame":index,"incoming_alpha":alpha,"outgoing_alpha":icon._outgoing.modulate.a if is_instance_valid(icon._outgoing) else 0.0,"blending":icon._change!=null})
		if index==1: pictures["equipped-fade-middle"] = root.get_texture().get_image()
	check(intermediate>=3,"slow frame retains at least three clearly visible intermediate crossfade frames")
	await create_timer(0.4).timeout
	check(icon.preview.texture==equipped and icon._change==null and icon._outgoing==null and icon.preview.modulate==Color.WHITE,"equipped image reaches its exact endpoint after a slow frame")
	check(app.header_car_cache.captures==captures,"crossfade reuses equipped pictures without another model capture")
	check(icon.preview.position==Vector2.ZERO,"equipped picture stays stationary throughout the fade")
	await capture("equipped-fade-finished")
	# Keep the original navigation fixture's stock-picture endpoint assertions.
	app.records.settings.vehicle_liveries.clear()
	app.records.settings.vehicle_customisation.clear()
	check(app.records.save_records()==OK,"restore isolated stock appearance after fade review")
	await create_timer(0.7).timeout

func navigation_fit_review(app: Node, icon: Control) -> void:
	for extent: Vector2i in [Vector2i(960,540),Vector2i(1411,877),Vector2i(1720,900)]:
		root.size = extent
		await frames(8)
		for vehicle: String in VehicleCatalog.IDS:
			app._select_header_vehicle(VehicleCatalog.IDS.find(vehicle))
			# Resizing and navigation may interrupt any stage of the crossfade.
			await frames(2)
			for destination: String in ["biome","profile","biome","settings","biome"]:
				app._show_screen(destination)
				await frames(2)
				check(app._retained_profile_car == icon,"retained identity: %s/%s/%d" % [vehicle,destination,extent.x])
				check(icon.size.is_equal_approx(Vector2(88,56)) and app.account_button.get_global_rect().encloses(icon.get_global_rect()),"outer slot fits the account button: %s/%s/%d" % [vehicle,destination,extent.x])
				picture_bounds(icon,"%s/%s/%d" % [vehicle,destination,extent.x])
			await create_timer(0.26).timeout
			picture_bounds(icon,"settled Create %s/%d" % [vehicle,extent.x])
			if vehicle == "electric": await capture("create-electric-%d" % extent.x)
