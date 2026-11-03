extends SceneTree

var checks := 0
var failures := 0
class FixtureEconomy extends Node:
	signal changed
	var scope := "forklift-fixture"
	var busy := false
	var pending := {}
	var status := ""
	var locked := false
	func authenticated() -> bool: return false
	func owns(id: String) -> bool: return not locked or preload("res://persistence/cosmetic_catalog.gd").free_item(id)
	func balance() -> int: return 0
	func price(_id: String) -> int: return 750
	func refresh() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for i: int in range(20): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var output: String = "res://../docs/evidence/forklift-cabin-kits-2026-11-02/garage"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	VehicleCatalog.selected = "forklift"
	var folder := "res://../build/forklift-crash-test/"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	var holder := MarginContainer.new()
	holder.theme = MenuStyle.theme()
	root.add_child(holder)
	MenuStyle.fill(holder)
	var economy := FixtureEconomy.new()
	root.add_child(economy)
	var page := GaragePage.new()
	page.records = records
	page.economy = economy
	holder.add_child(page)
	MenuStyle.fill(page)
	print("FORKLIFT_TEST_OPEN")
	page.open_car(VehicleCatalog.IDS.find("forklift"))
	await settle()
	print("FORKLIFT_TEST_CUSTOMISE")
	page._show_section("customise")
	await settle()
	check(page.section == "customise", "enters forklift customisation")
	print("FORKLIFT_TEST_TUNING")
	page._show_section("tuning")
	await settle()
	check(page.showroom.car.editable_kits,"editable forklift")
	var original: CarVisual = page.showroom.car
	for category: String in VehicleCustomisation.CATEGORIES:
		print("FORKLIFT_TEST_CATEGORY "+category)
		page._select_kit_category(category)
		await settle()
		check(page.kit_cards.get_child_count() == 14,"fourteen choices "+category)
		for choice: Array in VehicleCustomisation.options(category,"forklift"):
			print("FORKLIFT_TEST_PREVIEW "+category+"/"+str(choice[0]))
			page._preview_kit(category,choice[0])
			await settle()
			while page.showroom.kit_transition != null or (page.showroom.camera_motion != null and page.showroom.camera_motion.is_running()): await process_frame
			await settle()
			check(page.showroom.car.customisation[category] == choice[0],"preview "+category+"/"+str(choice[0]))
			check(page.showroom.car == original,"retains showroom car")
			if DisplayServer.get_name() != "headless":
				check(root.get_texture().get_image().save_png(output.path_join(category+"-"+str(choice[0])+".png")) == OK,"capture preview")
		page._equip_cosmetic_preview()
		await settle()
		var reopened := LocalRecords.new(records.path)
		reopened.load_records()
		check(VehicleCustomisation.for_car(reopened.settings,"forklift")[category] == VehicleCustomisation.options(category,"forklift")[-1][0],"equip and disk reload "+category)
	var equipped: Dictionary = page.kit_draft.duplicate(true)
	var appearance: Dictionary = preload("res://persistence/appearance_state.gd").car(records.settings,"forklift")
	check(preload("res://persistence/appearance_state.gd").valid_car(appearance),"appearance accepts all four fitted parts")
	var restored: Dictionary = {}
	preload("res://persistence/appearance_state.gd").apply(restored,appearance)
	check(VehicleCustomisation.for_car(restored,"forklift") == equipped,"appearance sync retains four kits")
	economy.locked = true
	page._preview_kit("body","fork_canopy")
	page._equip_cosmetic_preview()
	await settle()
	check(is_instance_valid(page._purchase_dialog),"unowned cabin requests purchase")
	if is_instance_valid(page._purchase_dialog):
		check(page._purchase_dialog.item_id == "kit/forklift/body/fork_canopy","correct cabin ownership item")
		page._purchase_dialog.cancel_button.pressed.emit()
		await settle()
	check(page.kit_draft == equipped,"purchase cancellation retains equipped parts")
	economy.locked = false
	page._cancel_cosmetic_preview()
	await settle()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = records
	game.vehicle_id = "forklift"
	game.initial_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	game.production_mode = true
	root.add_child(game)
	while game.car == null or not game.car.model_ready: await process_frame
	game.set_physics_process(false)
	check(game.car.customisation == equipped,"actual race loads equipped forklift parts")
	check(game.handling.snapshot() == VehicleCatalog.config("forklift").snapshot(),"kits preserve forklift handling")
	game.ghost_mode = "race"
	game.ghost_bests.race = {}
	game._prepare_personal_ghost()
	check(game.personal_ghost != null and game.personal_ghost.mesh != null,"ghost retains fitted forklift geometry")
	game.free()
	page._reset_kits()
	await settle()
	check(page.kit_draft == VehicleCustomisation.defaults(),"reset restores Original")
	holder.free()
	economy.free()
	await process_frame
	print("FORKLIFT_GARAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
