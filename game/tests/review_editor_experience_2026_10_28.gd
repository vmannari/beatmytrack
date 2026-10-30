extends "res://tests/review_track_editor_2026_10_28.gd"
## Native UX walkthrough and asset inspection; production UI/builders are unchanged.
var journal: Dictionary = {}

func source_hashes() -> Dictionary:
	var result: Dictionary = super.source_hashes()
	for path: String in ["editor/editor_history.gd","editor/editor_detail.gd"]: result[path] = FileAccess.get_sha256("res://"+path)
	return result

func record(key: String, values: Dictionary) -> void:
	journal[key] = values
	print("EDITOR_EXPERIENCE ",key," ",JSON.stringify(values))

func button_named(name_value: String) -> BaseButton:
	return app.root_ui.find_child(name_value,true,false) as BaseButton

func selection_probe() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank(); canvas.mode = "objects"
	canvas.document.objects = [{"kind":"cone","position":[0.0,0.0],"rotation":0.0},{"kind":"cone","position":[4.0,0.0],"rotation":0.0}]
	root.add_child(canvas); canvas.size = Vector2(1280,720)
	canvas.zoom = 6.0/maxf(0.01,minf(canvas.size.x/110.0,canvas.size.y/90.0))
	var point: Vector2 = canvas.to_screen(Vector2.ZERO)
	var event := InputEventScreenTouch.new(); event.index = 11; event.position = point; event.pressed = true
	canvas._gui_input(event)
	record("selection_neighbour",{"tap_target":0,"selected":canvas.selected_object,"scale":canvas.scale_factor(),
		"target_distance_px":0.0,"neighbour_distance_px":canvas.to_screen(Vector2(4,0)).distance_to(point)})
	event.pressed = false; canvas._gui_input(event); canvas.queue_free(); await process_frame

func atlas() -> void:
	root.size = Vector2i(1360,800); root.content_scale_size = root.size
	var entries: Array = []
	for asset: Array in CreatorCatalog.ASSETS:
		for kind: String in asset[3]:
			var biome: String = "pine"
			for candidate: String in TrackTheme.IDS:
				if CreatorCatalog.available(kind,candidate): biome = candidate; break
			entries.append({"kind":kind,"biome":biome})
	var completed: int = 0
	for start: int in range(0,entries.size(),24):
		var backdrop := ColorRect.new(); backdrop.color = Color("131f25"); backdrop.size = Vector2(root.size)
		root.add_child(backdrop)
		var title: Label = MenuStyle.label("Current production object previews / page %d / enlarged 2x" % (start/24+1),24)
		title.position = Vector2(20,12); backdrop.add_child(title)
		var tiles: Array[ObjectThumbnail] = []
		for index: int in range(start,mini(start+24,entries.size())):
			var entry: Dictionary = entries[index]
			var tile: ObjectThumbnail = ObjectThumbnail.make(entry.kind,CreatorCatalog.label(entry.kind),false,func() -> void: pass,entry.biome) as ObjectThumbnail
			tile.position = Vector2(20+((index-start)%6)*220,58+((index-start)/6)*174)
			tile.scale = Vector2(2,2); backdrop.add_child(tile); tiles.append(tile)
		var deadline: int = Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<deadline:
			var pending: bool = false
			for tile: ObjectThumbnail in tiles:
				if tile._image.texture == null or tile._viewport != null: pending = true
			if not pending: break
			await process_frame
		for tile: ObjectThumbnail in tiles:
			if tile._image.texture == null or tile._viewport != null: failures += 1
			else: completed += 1
		await frames(3)
		if root.get_texture().get_image().save_png(folder+"/atlas-%02d.png" % (start/24+1)) != OK: failures += 1
		backdrop.queue_free(); await process_frame
	record("atlas",{"variants":entries.size(),"completed":completed,"capture_failures":failures})

func stage(theme: String, kinds: Array, label: String) -> void:
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "experience_"+theme; doc.name = label
	doc.theme = theme; doc["automatic_scenery"] = false
	for index: int in range(kinds.size()):
		var object: Dictionary = {"kind":kinds[index],"position":[-30.0+(index%4)*20.0,18.0-(index/4)*18.0],"rotation":0.0}
		if kinds[index] == "jump": object.jump_profile = JumpProfiles.default_for(theme)
		doc.objects.append(object)
	await show(doc)
	app.canvas.zoom = 10.0/maxf(0.01,minf(app.canvas.size.x/110.0,app.canvas.size.y/90.0))
	app.canvas.pan = Vector2.ZERO; app.canvas.queue_redraw(); app._editor_category("objects")
	await shot("objects-"+theme+"-"+label.to_snake_case())
	record("objects-"+theme+"-"+label.to_snake_case(),{"kinds":kinds,"pixels_per_metre":app.canvas.scale_factor(),"reduced_detail":app.editor_world._detail.reduced})

func walkthrough() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder+"/disposable-storage"); app.records = LocalRecords.new(folder+"/disposable-storage/records.json")
	app.cloud_root_override = folder+"/disposable-storage/cloud"; root.add_child(app)
	while not app.startup_complete: await process_frame
	app.library.owner_name = "Review driver"
	var blank: Dictionary = TrackDocument.create_blank(); blank.id = "experience_blank"
	await show(blank); await shot("01-first-entry")
	app.canvas.choose_piece("curve"); await shot("02-first-curve")
	record("first_curve",{"hint_visible":app.editor_status.is_visible_in_tree(),"hint_text":app.editor_status.text,
		"pending":not app.canvas.ghost.is_empty(),"test_disabled":app.test_button.disabled})
	await show(circuit()); app._editor_category("objects"); app.object_browser.category = "Nature"; app.object_browser.refresh()
	await shot("03-nature-palette")
	app.object_browser._activate_asset("tree")
	await frames(2)
	var size_field: OptionButton = app.object_browser.options.find_child("ObjectSize",true,false) as OptionButton
	if size_field != null: size_field.select(2); size_field.item_selected.emit(2)
	var scale_before: float = app.canvas.stamp_scale
	app.object_browser.options.hide(); app.object_browser._activate_asset("tree")
	record("reopen_object_options",{"scale_before":scale_before,"scale_after":app.canvas.stamp_scale,"popup_open":app.object_browser.options.visible})
	await shot("04-options-reset-size"); app.object_browser.options.hide()
	app.object_browser._activate_asset("rock"); app.object_browser._activate_asset("rock")
	var variant: OptionButton = app.object_browser.options.find_child("ObjectVariant",true,false) as OptionButton
	if variant != null: variant.select(1); variant.item_selected.emit(1)
	var kind_before: String = app.canvas.stamp_kind
	app.object_browser.options.hide(); app.object_browser._activate_asset("rock")
	record("reopen_variant_options",{"kind_before":kind_before,"kind_after":app.canvas.stamp_kind,"popup_open":app.object_browser.options.visible})
	await shot("05-family-variant-reset"); app.object_browser.options.hide()
	app.object_browser.category = "Barriers"; app.object_browser.page = 0; app.object_browser.refresh()
	app.object_browser._activate_asset("guardrail"); app.object_browser._activate_asset("guardrail")
	var placement: BaseButton = app.object_browser.options.find_child("Placement_curve",true,false) as BaseButton
	if placement != null: placement.pressed.emit()
	var placement_before: String = app.object_browser.placement
	app.object_browser.options.hide(); app.object_browser._activate_asset("guardrail")
	record("reopen_placement_options",{"placement_before":placement_before,"placement_after":app.object_browser.placement,"canvas_mode":app.canvas.mode})
	await shot("06-run-mode-reset"); app.object_browser.options.hide()
	app._editor_category("paint"); app.canvas.paint_mode = "area"; app._build_editor_tools(); await shot("07-surface-discovery")
	app._editor_category("road"); app.canvas.selected_piece = 1; app._build_editor_tools(); await shot("08-hairpin-selection")
	await stage("pine",["tree","broadleaf","bush","grass_clump","flowers","pebbles","rock","boulder","slate","log","cliff"],"Nature inspection")
	await stage("pine",["guardrail","barrier","fence","wire_fence","tyre_stack","tyre_wall","cone","chevron","braking_board","gantry","jump","speed_bump"],"Trackside inspection")
	await stage("storm",["container","shed","hut","grandstand","parked_car","van","car_wreck","crate","barrel","hay_bale","pallet"],"Props and buildings inspection")
	await stage("desert",["egypt_pyramid","egypt_obelisk","egypt_column","egypt_column_broken","egypt_wall","rock","boulder","slate"],"Desert inspection")
	await stage("winter",["igloo","snow_castle","snowman","snow_lantern","ice_lantern","ice_compact"],"Winter inspection")
	await stage("night_city",["firefly_bush","burning_barrel","burning_car","lantern_post","neon_arrow","light","abandoned_warehouse"],"Night authoring inspection")
	if app.editor_world.has_method("set_race_lighting_preview"):
		app.editor_world.set_race_lighting_preview(true); await frames(5); await shot("objects-night-race-preview")
	var dense: Dictionary = TrackDocument.create_blank(); dense.id = "experience_dense"; dense.name = "Dense mixed scenery"; dense["automatic_scenery"] = false
	var types: Array[String] = ["parked_car","container","crate","barrel","tree","rock","hut","cone"]
	for index: int in range(32): dense.objects.append({"kind":types[index%types.size()],"position":[-35.0+(index%8)*10.0,18.0-(index/8)*12.0],"rotation":0.0})
	await show(dense); app._editor_category("objects"); app.canvas.zoom = 6.0/maxf(0.01,minf(app.canvas.size.x/110.0,app.canvas.size.y/90.0)); app.canvas.pan = Vector2.ZERO
	await frames(8); await shot("09-dense-normal-overview")
	record("dense_default",{"reduced":app.editor_world._detail.reduced,"scale":app.canvas.scale_factor(),"objects":32})
	app.editor_world._detail.enabled = false; await frames(8); await shot("10-dense-full-comparison")
	app.queue_free(); await frames(3)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	folder = ProjectSettings.globalize_path("res://../docs/evidence/editor-experience-2026-10-28/")+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(folder)
	source_before = source_hashes()
	if "--selection" in OS.get_cmdline_user_args(): await selection_probe()
	elif "--atlas" in OS.get_cmdline_user_args(): await atlas()
	else: await walkthrough()
	var suffix: String = "selection" if "--selection" in OS.get_cmdline_user_args() else "atlas" if "--atlas" in OS.get_cmdline_user_args() else "walkthrough"
	var file := FileAccess.open(folder+"/"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"journal":journal,"observations":observations,
		"source_before":source_before,"source_after":source_hashes()},"\t")); file.close()
	print("EDITOR_EXPERIENCE_COMPLETE ",suffix," failures=",failures)
	quit(1 if failures else 0)
