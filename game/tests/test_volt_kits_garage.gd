extends "res://tests/test_kart_kits.gd"
## Actual Garage preview/equip/reload and race construction for Volt kits.

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	VehicleCatalog.selected="electric"
	var folder: String="res://../build/volt-kits/local/"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var records:=LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	var holder:=MarginContainer.new()
	holder.theme=MenuStyle.theme()
	root.add_child(holder)
	MenuStyle.fill(holder)
	var economy:=FixtureEconomy.new()
	root.add_child(economy)
	page=GaragePage.new()
	page.records=records
	page.economy=economy
	holder.add_child(page)
	MenuStyle.fill(page)
	page.open_car(VehicleCatalog.IDS.find("electric"))
	page._show_section("tuning")
	await settle()
	while not page.showroom.showroom_ready: await process_frame
	check(page.showroom.car.editable_kits,"Volt Garage has editable kit frames")
	var original_car: CarVisual=page.showroom.car
	var captures: String="res://../tmp/volt-kit-garage-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	for category: String in VehicleCustomisation.CATEGORIES:
		page._select_kit_category(category)
		await settle()
		check(page.kit_cards.get_child_count()==16,"16 choices visible "+category)
		for index: int in [1,8,15]:
			var value: String=VehicleCustomisation.options(category,"electric")[index][0]
			var before: Dictionary=page.kit_draft.duplicate(true)
			page._preview_kit(category,value)
			await settle()
			check(page.showroom.car.customisation[category]==value and page.kit_draft==before,"preview without saving "+category+"/"+value)
			page._equip_cosmetic_preview()
			await settle()
			var reopened:=LocalRecords.new(records.path)
			reopened.load_records()
			check(page.kit_draft[category]==value and VehicleCustomisation.for_car(reopened.settings,"electric")==page.kit_draft,"equip and reload "+category+"/"+value)
			check(page.showroom.car==original_car,"part changes retain showroom car")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(captures.path_join(category+".png"))==OK,"capture Volt tuning "+category)
	var equipped: Dictionary=page.kit_draft.duplicate(true)
	var appearance: Dictionary=preload("res://persistence/appearance_state.gd").car(records.settings,"electric")
	check(preload("res://persistence/appearance_state.gd").valid_car(appearance),"fitted Volt appearance accepted")
	var restored: Dictionary={}
	preload("res://persistence/appearance_state.gd").apply(restored,appearance)
	check(VehicleCustomisation.for_car(restored,"electric")==equipped,"appearance sync keeps all four kits")
	economy.locked=true
	page._preview_kit("body","volt_sport")
	page._equip_cosmetic_preview()
	await settle()
	check(is_instance_valid(page._purchase_dialog),"unowned Volt part opens purchase confirmation")
	if is_instance_valid(page._purchase_dialog):
		check(page._purchase_dialog.item_id=="kit/electric/body/volt_sport","purchase uses the selected Volt item")
		page._purchase_dialog.cancel_button.pressed.emit()
		await settle()
	check(page.kit_draft==equipped,"cancelled purchase preserves the equipped parts")
	economy.locked=false
	page._cancel_cosmetic_preview()
	var game: Node=load("res://core/game.tscn").instantiate()
	game.preference_records=records
	game.vehicle_id="electric"
	game.initial_track=NativeTrack.read("res://resources/tracks/ellipse.json")
	game.production_mode=true
	root.add_child(game)
	while game.car==null or not game.car.model_ready: await process_frame
	game.set_physics_process(false)
	check(game.car.customisation==equipped,"actual race loads equipped Volt parts")
	check(game.handling.snapshot()==VehicleCatalog.config("electric").snapshot(),"kits preserve Volt handling")
	game.ghost_mode="race"
	game.ghost_bests.race={}
	game._prepare_personal_ghost()
	check(game.personal_ghost!=null and game.personal_ghost.mesh!=null,"race ghost retains the fitted Volt geometry")
	game.free()
	page._reset_kits()
	await settle()
	check(page.kit_draft==VehicleCustomisation.defaults(),"reset restores originals")
	print("VOLT_KITS_GARAGE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
