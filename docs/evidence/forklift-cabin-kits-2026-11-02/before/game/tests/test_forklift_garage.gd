extends SceneTree

var checks := 0
var failures := 0
class FixtureEconomy extends Node:
	signal changed
	var scope := "forklift-fixture"
	var busy := false
	var pending := {}
	var status := ""
	func authenticated() -> bool: return false
	func owns(_id: String) -> bool: return true
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
	for category: String in VehicleCustomisation.CATEGORIES:
		print("FORKLIFT_TEST_CATEGORY "+category)
		page._select_kit_category(category)
		await settle()
		check(page.kit_cards.get_child_count() == 4,"four choices "+category)
		for choice: Array in VehicleCustomisation.options(category,"forklift"):
			print("FORKLIFT_TEST_PREVIEW "+category+"/"+str(choice[0]))
			page._preview_kit(category,choice[0])
			await settle()
			check(page.showroom.car.customisation[category] == choice[0],"preview "+category+"/"+str(choice[0]))
	page._cancel_cosmetic_preview()
	await settle()
	holder.free()
	economy.free()
	await process_frame
	print("FORKLIFT_GARAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
