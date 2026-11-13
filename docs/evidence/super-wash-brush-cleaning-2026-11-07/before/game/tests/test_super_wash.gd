extends SceneTree
## Real Garage controls and models; only isolated local cosmetic saves.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/super-wash-2026-10-28"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	await create_timer(GaragePage.MENU_MOVE_SECONDS+0.1).timeout
	for index: int in range(5): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func check_wash_layout(page: GaragePage) -> void:
	var dock: HBoxContainer = page.preview.get_node("GarageWashTools")
	var status: Rect2 = page._wash_status_panel.get_global_rect()
	var row: Rect2 = dock.get_global_rect()
	check(dock.get_child_count() == 3,"three adjacent wash options")
	check(absf(row.position.x-status.position.x) <= 1.0 and absf(row.end.x-status.end.x) <= 1.0,"wash row shares both cleanliness-label edges")
	check(row.position.y >= status.end.y,"wash options stay below cleanliness label")
	check(page.preview.get_global_rect().encloses(row),"wash row fits showroom")
	check(not page.actions.has_node("GarageSuperWash"),"Super Wash has moved out of bottom actions")
	var expected: Array[String] = ["GarageWashMitt","GarageWashHose","GarageSuperWash"]
	for index: int in range(expected.size()):
		var choice: Button = dock.get_child(index)
		check(choice.name == expected[index],"wash option order "+str(index))
		check(absf(choice.size.x-(dock.size.x-20.0)/3.0) <= 1.0,"equal wash option widths")
		var title: Label = choice.title
		check(title.get_theme_font("font").get_string_size(GameText.message(title.text),HORIZONTAL_ALIGNMENT_LEFT,-1,title.get_theme_font_size("font_size")).x <= title.size.x+1.0,"wash caption fits "+str(choice.name))
	check(not dock.get_node("GarageSuperWash").toggle_mode,"instant action is separate from manual-tool selection")

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_SUPER_WASH_OUTPUT") if OS.has_environment("BMT_SUPER_WASH_OUTPUT") else output
	output = output.path_join(DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var directory: String = "user://super_wash_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var seed := VehicleWeathering.new()
	var dirty: Dictionary = seed.snapshot()
	for field: String in ["dirt","snow","slow_dirt","slow_snow","mud","smudge","wetness"]: dirty[field] = 0.95
	var ages := PackedByteArray()
	ages.resize(VehicleCondition.CELLS)
	ages.fill(255)
	dirty.grime_age = Marshalls.raw_to_base64(ages)
	dirty.grime_elapsed = 2.0
	dirty.slow_recoat = 0.01
	for id: String in VehicleCatalog.IDS:
		check(VehicleCondition.save(records,id,dirty) == OK,id+" seed dirty local state")
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var page := GaragePage.new()
	page.records = records
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		page.open_car(index)
		page._show_section("care")
		await settle()
		var button: Button = page.preview.get_node("GarageWashTools/GarageSuperWash")
		check(button.accessibility_name == "Super Wash" and button.is_visible_in_tree(),id+" exposes Super Wash in Wash")
		check_wash_layout(page)
		check(root.get_visible_rect().encloses(button.get_global_rect()),id+" action fits")
		var paint: Dictionary = page.showroom.livery.duplicate(true)
		var parts: Dictionary = page.showroom.customisation.duplicate(true)
		var others: Dictionary = records.settings.vehicle_conditions.duplicate(true)
		others.erase(id)
		page._toggle_wash()
		page.showroom.washing = true
		page.showroom.wash_pointer_valid = true
		page.showroom.touches[0] = Vector2(20,20)
		await capture(id+"-dirty")
		await click(button)
		await settle()
		var clean: Dictionary = page.showroom.weathering.snapshot()
		for field: String in ["dirt","snow","slow_dirt","slow_snow","mud","smudge","wetness","slow_recoat","grime_elapsed"]:
			check(float(clean[field]) == 0.0,id+" clears "+field)
		for field: String in ["wash","slow_wash","grime_age"]:
			var bytes: PackedByteArray = Marshalls.base64_to_raw(clean[field])
			check(bytes.size() == VehicleCondition.CELLS and bytes.count(0) == bytes.size(),id+" resets every "+field+" voxel")
		check(not page.showroom.weathering.installed,id+" restores clean original materials")
		check(not page.showroom.wash_mode and not page.showroom.washing and not page.showroom.wash_pointer_valid and page.showroom.touches.is_empty(),id+" ends active wash gestures")
		check(page.wash_button.text == "Wash",id+" manual wash can restart")
		check(page._wash_status.text == "Shiny. For now.",id+" immediately displays top cleanliness grade")
		check(not page._workshop_wash_required,id+" immediately permits customisation")
		check(not button.button_pressed,id+" instant action does not remain selected")
		check(page.showroom.livery == paint and page.showroom.customisation == parts,id+" retains paint and parts")
		check(VehicleCondition.read(records,id) == clean,id+" persists full clean state")
		var after_others: Dictionary = records.settings.vehicle_conditions.duplicate(true)
		after_others.erase(id)
		check(after_others == others,id+" leaves all other cars exact")
		await capture(id+"-clean")
		var revision: int = AchievementProgress.read(records).revision
		await click(button)
		check(VehicleCondition.read(records,id) == clean and AchievementProgress.read(records).revision == revision,id+" repeated clean action is a no-op")
		var reopened := LocalRecords.new(records.path)
		reopened.load_records()
		check(VehicleCondition.read(reopened,id) == clean,id+" stays clean after local reload")
	# A newer local race condition must be cleaned intentionally, rather than
	# being restored by the stale-page protection after the button is pressed.
	check(VehicleCondition.save(records,page.vehicle_id,dirty) == OK,"newer race wear saved")
	page._super_wash()
	check(VehicleCondition.read(records,page.vehicle_id).dirt == 0.0,"Super Wash includes newer local wear")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check_wash_layout(page)
		for action: Control in page.actions.get_children():
			check(root.get_visible_rect().encloses(action.get_global_rect()),"all wash actions fit "+str(dimensions))
		await capture("clean-"+str(dimensions.x))
	page._show_section("cars")
	await settle()
	var saved: Dictionary = records.settings.vehicle_conditions.duplicate(true)
	page._super_wash()
	check(records.settings.vehicle_conditions == saved,"stale action outside Wash is ignored")
	page._show_section("care")
	await settle()
	page.hide()
	page._super_wash()
	check(records.settings.vehicle_conditions == saved,"hidden Garage action is ignored")
	page.queue_free()
	await process_frame
	print("SUPER_WASH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
